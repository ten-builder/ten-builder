# AI 에이전트 성능 회귀 테스트 자동화 플레이북

> 새 코드를 배포하기 전에 성능이 떨어지지 않았는지 AI 에이전트로 자동 검증하는 단계별 가이드 — k6 부하 테스트, Lighthouse CI, 임계값 기반 자동 롤백

## 소요 시간

초기 설정: 90~120분
이후 자동 실행

## 사전 준비

- Node.js 20+ 설치
- Docker (k6 실행 환경)
- GitHub Actions 또는 GitLab CI 설정
- `CLAUDE.md`에 성능 목표 기록

## 왜 성능 회귀 테스트인가

AI 에이전트가 코드를 생성할 때 기능은 정확하지만 성능에 부작용이 생기는 경우가 있어요. 예를 들어:

- 쿼리 최적화 없이 ORM 코드를 추가해 N+1 문제 발생
- 번들에 무거운 의존성을 포함해 초기 로딩 속도 저하
- 병렬 처리를 순차 처리로 변경해 응답 시간 증가

이 플레이북은 그런 상황을 PR 단계에서 자동으로 탐지하고, 기준치를 초과하면 배포를 차단하는 파이프라인을 만드는 방법을 다뤄요.

## Step 1: 성능 기준선(Baseline) 설정

먼저 현재 프로덕션의 성능 수치를 기록해요. AI 에이전트에게 이렇게 요청할 수 있어요:

```
현재 main 브랜치를 기준으로 k6 스모크 테스트를 실행하고
baseline.json에 응답 시간 p50, p95, p99 값을 저장해줘.
API 엔드포인트는 ./tests/endpoints.json 파일을 참조해.
```

기준선 파일 예시:

```json
// tests/perf/baseline.json
{
  "api_response_p95_ms": 250,
  "api_response_p99_ms": 500,
  "lighthouse_performance": 85,
  "lighthouse_lcp_ms": 2500,
  "bundle_size_kb": 320,
  "updated_at": "2026-06-09"
}
```

## Step 2: k6 부하 테스트 스크립트 작성

```javascript
// tests/perf/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const responseTime = new Trend('response_time');
const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 10 },  // 워밍업
    { duration: '60s', target: 50 },  // 기준 부하
    { duration: '30s', target: 0 },   // 쿨다운
  ],
  thresholds: {
    // 기준선 대비 20% 초과 시 실패
    'response_time': ['p(95)<300', 'p(99)<600'],
    'errors': ['rate<0.01'],
    'http_req_duration': ['p(95)<300'],
  },
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:3000';

  const res = http.get(`${baseUrl}/api/health`);
  responseTime.add(res.timings.duration);
  errorRate.add(res.status !== 200);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 300ms': (r) => r.timings.duration < 300,
  });

  sleep(1);
}
```

## Step 3: Lighthouse CI 설정

```javascript
// lighthouserc.js
module.exports = {
  ci: {
    collect: {
      numberOfRuns: 3,
      url: [
        'http://localhost:3000',
        'http://localhost:3000/dashboard',
      ],
    },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.80 }],
        'first-contentful-paint': ['warn', { maxNumericValue: 2000 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 3000 }],
        'total-blocking-time': ['error', { maxNumericValue: 300 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
      },
    },
    upload: {
      target: 'temporary-public-storage',
    },
  },
};
```

## Step 4: GitHub Actions 파이프라인 연결

```yaml
# .github/workflows/perf-regression.yml
name: Performance Regression Gate

on:
  pull_request:
    branches: [main]

jobs:
  perf-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Start application
        run: |
          npm ci
          npm run build
          npm start &
          npx wait-on http://localhost:3000 --timeout 60000

      - name: Run k6 load test
        uses: grafana/k6-action@v0.3.0
        with:
          filename: tests/perf/load-test.js
        env:
          BASE_URL: http://localhost:3000

      - name: Run Lighthouse CI
        run: |
          npm install -g @lhci/cli
          lhci autorun
        env:
          LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}

      - name: Compare with baseline
        run: node scripts/compare-baseline.js
        env:
          THRESHOLD_PERCENT: 20  # 20% 이상 저하 시 실패
```

## Step 5: 기준선 비교 스크립트

```javascript
// scripts/compare-baseline.js
const fs = require('fs');

const baseline = JSON.parse(fs.readFileSync('tests/perf/baseline.json'));
const current = JSON.parse(fs.readFileSync('tests/perf/current-results.json'));
const threshold = parseFloat(process.env.THRESHOLD_PERCENT || '20') / 100;

const checks = [
  {
    name: 'API p95 응답 시간',
    baseline: baseline.api_response_p95_ms,
    current: current.api_response_p95_ms,
    unit: 'ms',
    lowerIsBetter: true,
  },
  {
    name: 'Lighthouse 성능 점수',
    baseline: baseline.lighthouse_performance,
    current: current.lighthouse_performance,
    unit: '점',
    lowerIsBetter: false,
  },
];

let failed = false;
checks.forEach(({ name, baseline: b, current: c, unit, lowerIsBetter }) => {
  const change = lowerIsBetter
    ? (c - b) / b
    : (b - c) / b;

  if (change > threshold) {
    console.error(`FAIL ${name}: ${b}${unit} → ${c}${unit} (${(change * 100).toFixed(1)}% 저하)`);
    failed = true;
  } else {
    console.log(`PASS ${name}: ${b}${unit} → ${c}${unit}`);
  }
});

if (failed) process.exit(1);
```

## 체크리스트

- [ ] `baseline.json` 파일을 레포에 커밋
- [ ] k6 스크립트에 실제 API 엔드포인트 반영
- [ ] Lighthouse CI 임계값을 팀 기준에 맞게 조정
- [ ] GitHub Actions 워크플로우 활성화
- [ ] 처음 실행 시 false positive 여부 확인
- [ ] 알림 채널 설정 (Slack, Discord 등)

## 임계값 설정 기준

| 지표 | 권장 임계값 | 설명 |
|------|------------|------|
| API p95 응답 시간 | +20% | 소폭 증가 허용 |
| API 에러율 | +1%p | 거의 허용 안 함 |
| Lighthouse 성능 | -5점 | 80점 미만 차단 |
| LCP | +500ms | 3초 이상 차단 |
| 번들 크기 | +10% | 큰 의존성 추가 감지 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 로컬과 CI 결과 차이 | Docker 환경으로 통일 |
| 간헐적 실패 | 테스트를 3회 실행 후 중앙값 사용 |
| 기준선이 오래됨 | `main` 머지 시 자동 업데이트 워크플로우 추가 |
| k6 클라우드 비용 | OSS 버전으로 CI 내에서 실행 |

## 다음 단계

→ [AI 에이전트 CI/CD 파이프라인 자동 최적화 워크플로우](../workflows/ai-cicd-pipeline-optimization.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
