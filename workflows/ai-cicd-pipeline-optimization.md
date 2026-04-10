# AI 에이전트 CI/CD 파이프라인 자동 최적화 워크플로우

> AI 에이전트가 GitHub Actions 파이프라인의 병목을 분석하고 빌드 시간을 줄이는 워크플로우

## 개요

프로젝트가 커질수록 CI/CD 파이프라인은 느려집니다. 개발자들은 빌드 시간이 15분에서 30분으로 늘어나는 걸 보면서도, 무엇을 어떻게 최적화해야 할지 파악하기 어려워요.

이 워크플로우는 AI 에이전트를 활용해 파이프라인 실행 기록을 분석하고, 병목 단계를 자동으로 탐지하고, 최적화 코드를 직접 생성하는 과정을 다룹니다. 사람은 분석 결과와 제안을 검토하고 머지 여부만 결정하면 됩니다.

핵심은 **측정 → 분석 → 수정 → 검증** 사이클을 반복하는 것입니다. 감에 의존하는 최적화가 아니라, 실제 실행 데이터 기반으로 가장 효과가 큰 부분부터 고쳐나갑니다.

## 사전 준비

- GitHub Actions 파이프라인이 있는 레포
- GitHub CLI (`gh`) 설치 및 인증
- Claude Code 또는 AI 코딩 에이전트
- Python 3.8+ (분석 스크립트용)

## Step 1: 파이프라인 실행 데이터 수집

AI 에이전트에게 최적화를 맡기기 전에, 먼저 실행 기록을 수집합니다.

```bash
#!/bin/bash
# scripts/collect-pipeline-data.sh

REPO="owner/repo"
WORKFLOW_FILE="ci.yml"
DAYS_BACK=14

echo "최근 ${DAYS_BACK}일 워크플로우 실행 기록 수집 중..."

gh api \
  "repos/${REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=30" \
  --jq '.workflow_runs[] | {
    id: .id,
    status: .status,
    conclusion: .conclusion,
    run_started_at: .run_started_at,
    updated_at: .updated_at,
    head_branch: .head_branch
  }' > /tmp/pipeline-runs.json

echo "총 $(cat /tmp/pipeline-runs.json | python3 -c 'import sys,json; data=sys.stdin.read(); print(len([l for l in data.strip().split("\n") if l.strip().startswith("{")]))') 건 수집 완료"

# 각 실행의 잡별 소요 시간 수집
while IFS= read -r run; do
  RUN_ID=$(echo "$run" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
  gh api "repos/${REPO}/actions/runs/${RUN_ID}/jobs" \
    --jq '.jobs[] | {
      name: .name,
      started_at: .started_at,
      completed_at: .completed_at,
      status: .status,
      conclusion: .conclusion
    }' >> /tmp/pipeline-jobs.json
done < <(cat /tmp/pipeline-runs.json | python3 -c '
import sys, json
for line in sys.stdin:
  line = line.strip()
  if line.startswith("{") and line.endswith("}"):
    print(line)
')

echo "잡별 데이터 수집 완료: /tmp/pipeline-jobs.json"
```

## Step 2: AI 에이전트로 병목 분석

수집한 데이터를 바탕으로 AI 에이전트에게 분석을 요청합니다.

```bash
# Claude Code에 분석 요청
cat > /tmp/analyze-pipeline.md << 'EOF'
아래 GitHub Actions 파이프라인 실행 데이터를 분석해줘.

목표:
1. 평균 실행 시간이 가장 긴 잡 Top 5 파악
2. 각 잡에서 느린 단계(step) 식별
3. 병렬화 가능한 잡 조합 찾기
4. 캐시 미스로 인한 지연 패턴 탐지
5. 플레이키(flaky) 잡 탐지 (같은 잡이 반복 실패하는 경우)

데이터: /tmp/pipeline-jobs.json

결과를 다음 형식으로 정리해줘:
- 병목 잡 목록 (이름, 평균 시간, 최대 시간)
- 최적화 우선순위 (예상 절약 시간 기준)
- 즉시 적용 가능한 변경 사항 3개
EOF

claude --print < /tmp/analyze-pipeline.md
```

분석 결과 예시:

| 잡 이름 | 평균 시간 | 최대 시간 | 주요 원인 |
|---------|-----------|-----------|-----------|
| `test-unit` | 8분 23초 | 12분 1초 | 의존성 캐시 미스 |
| `build-prod` | 6분 45초 | 9분 12초 | Docker 레이어 미캐시 |
| `lint` | 3분 11초 | 5분 30초 | 병렬화 미적용 |
| `e2e-test` | 11분 02초 | 18분 44초 | 브라우저 설치 반복 |

## Step 3: 최적화 코드 자동 생성

병목이 파악되면 AI 에이전트에게 수정된 워크플로우 파일 생성을 요청합니다.

```yaml
# AI 에이전트가 생성한 최적화 예시: .github/workflows/ci-optimized.yml

name: CI (Optimized)

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # 잡 병렬화: lint와 typecheck를 동시 실행
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'           # 의존성 캐시 활성화
      - run: npm ci
      - run: npm run lint

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run typecheck

  test-unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      # 테스트를 4개 샤드로 분할하여 병렬 실행
      - run: npm test -- --shard=1/4

  # 빌드는 lint + typecheck 통과 후에만 실행
  build-prod:
    needs: [lint, typecheck, test-unit]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Docker 레이어 캐시
        uses: actions/cache@v4
        with:
          path: /tmp/.buildx-cache
          key: ${{ runner.os }}-buildx-${{ github.sha }}
          restore-keys: |
            ${{ runner.os }}-buildx-
      - run: npm ci
      - run: npm run build
```

## Step 4: 테스트 샤딩으로 병렬화

테스트가 느리다면 샤딩(sharding)으로 여러 러너에 분산합니다.

```yaml
# 테스트 샤딩 패턴
test:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      shard: [1, 2, 3, 4]    # 4개 러너에 분산

  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
    - run: npm ci
    - run: npm test -- --shard=${{ matrix.shard }}/4
```

테스트 500개 기준 기대 효과:

| 방식 | 소요 시간 |
|------|-----------|
| 순차 실행 | 8분 23초 |
| 2개 샤드 | 4분 30초 |
| 4개 샤드 | 2분 20초 |

## Step 5: 캐시 전략 점검

캐시 미스는 파이프라인에서 가장 흔한 병목 중 하나입니다.

```yaml
# 올바른 캐시 키 설계
- name: 의존성 캐시
  uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      node_modules
    # package-lock.json이 바뀔 때만 캐시 무효화
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-

# Docker 빌드 캐시
- name: Docker Buildx 캐시
  uses: actions/cache@v4
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-buildx-
```

AI 에이전트에게 현재 캐시 설정 진단 요청:

```bash
cat .github/workflows/ci.yml | claude --print \
  "이 워크플로우 파일의 캐시 설정을 분석해줘.
   캐시 키가 너무 자주 무효화되는 패턴이 있으면 지적하고,
   개선된 캐시 키를 제안해줘."
```

## Step 6: 변경 감지로 불필요한 잡 건너뛰기

변경된 파일에 따라 관련 잡만 실행하면 전체 시간을 줄일 수 있어요.

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      frontend: ${{ steps.filter.outputs.frontend }}
      backend: ${{ steps.filter.outputs.backend }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            frontend:
              - 'src/frontend/**'
              - 'package.json'
            backend:
              - 'src/backend/**'
              - 'requirements.txt'

  test-frontend:
    needs: changes
    if: needs.changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  test-backend:
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: pytest
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 샤드 수 | 4 | 테스트 병렬화 단위. 테스트 수 / 100 추천 |
| 캐시 TTL | 7일 | GitHub Actions 기본값, 별도 설정 불필요 |
| 변경 감지 경로 | 수동 설정 | 프로젝트 구조에 맞게 paths-filter 조정 |
| 잡 타임아웃 | 30분 | `timeout-minutes: 15`로 단축 권장 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 캐시가 항상 미스됨 | `key`에 너무 구체적인 값(예: 타임스탬프) 포함 여부 확인 |
| 샤딩 후 일부 테스트 누락 | 테스트 러너가 shard 파라미터를 지원하는지 확인 |
| 병렬 잡에서 포트 충돌 | 각 잡에 독립된 포트 범위 할당 |
| 변경 감지가 PR에서 미동작 | `pull_request` 이벤트에서 base 브랜치 지정 확인 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
