# EP09: AI 코딩 거버넌스 실전 — 팀에 AI 코딩 도구를 안전하게 정착시키는 법

> 가이드라인 수립, 코드 리뷰 정책, 품질 기준까지 — 조직에서 AI 코딩을 체계적으로 운영하는 실전 데모

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- AI 코딩 도구 사용 가이드라인을 팀에 맞게 설계하기
- AI 생성 코드에 대한 리뷰 정책과 체크리스트 만들기
- 품질 기준을 정량화하고 CI/CD에 반영하기
- 실제 거버넌스 설정 파일과 GitHub Actions 워크플로우

## 왜 거버넌스가 필요한가

AI 코딩 도구를 팀에 도입하면 처음에는 생산성이 올라가요. 근데 몇 주가 지나면 이런 문제가 생기기 시작해요:

| 문제 | 원인 | 결과 |
|------|------|------|
| 코드 스타일 불일치 | 각자 다른 AI 설정 사용 | 리뷰 비용 증가 |
| 보안 취약점 유입 | AI가 검증 안 된 패키지 추가 | 프로덕션 사고 위험 |
| 테스트 커버리지 하락 | AI가 테스트 없이 기능만 추가 | 리그레션 빈발 |
| 라이선스 충돌 | AI가 GPL 코드 가져옴 | 법적 리스크 |
| 지식 의존도 편향 | AI에 과의존, 코드 이해도 하락 | 유지보수 난이도 상승 |

거버넌스는 이런 문제를 사전에 방지하는 구조예요. "AI를 못 쓰게 하자"가 아니라 "잘 쓰게 하자"라는 거예요.

## 거버넌스 3계층 모델

```
┌──────────────────────────────────────────┐
│  정책 계층 (Policy Layer)                 │
│  → "무엇을 허용하고 무엇을 금지하는가"     │
├──────────────────────────────────────────┤
│  프로세스 계층 (Process Layer)             │
│  → "어떻게 검증하고 승인하는가"            │
├──────────────────────────────────────────┤
│  도구 계층 (Tooling Layer)                │
│  → "자동으로 어떻게 강제하는가"            │
└──────────────────────────────────────────┘
```

이 세 계층이 맞물려야 거버넌스가 실제로 동작해요.

## 1단계: AI 코딩 정책 설계

### 사용 범위 정의

팀에서 먼저 정해야 할 건 "AI를 어디까지 쓸 건가"예요.

```yaml
# .ai-policy.yaml — 팀 AI 코딩 정책 정의 파일
version: "1.0"
last_updated: "2026-03-01"

usage_scope:
  allowed:
    - code_generation        # 새 코드 생성
    - test_generation        # 테스트 코드 생성
    - documentation          # 문서 작성
    - refactoring            # 리팩토링
    - debugging              # 디버깅 지원
    - code_review_assist     # 리뷰 보조
  
  restricted:               # 팀장 승인 필요
    - security_critical      # 인증/암호화 관련 코드
    - database_migration     # 스키마 변경
    - infrastructure         # 인프라 설정 (Terraform 등)
  
  prohibited:               # 사용 금지
    - api_key_handling       # API 키 직접 하드코딩
    - compliance_code        # 규제 관련 코드 (금융, 의료)
    - third_party_integration # 외부 서비스 연동 (검토 필수)

model_policy:
  approved_models:
    - claude-sonnet-4
    - claude-opus-4
    - gpt-4.1
  context_rules:
    - "프로덕션 DB 크레덴셜을 프롬프트에 포함 금지"
    - "고객 PII를 AI 입력으로 전달 금지"
    - "내부 API 스펙을 외부 모델에 전달 시 팀장 승인"
```

### 코드 리뷰 정책

AI 생성 코드는 일반 코드보다 더 꼼꼼히 봐야 해요. 이유는 단순해요 — 작성자가 모든 줄을 직접 이해하고 쓴 게 아니니까요.

```yaml
# .ai-review-policy.yaml
review_rules:
  ai_generated_code:
    min_reviewers: 2              # 최소 리뷰어 수
    require_author_explanation: true  # 작성자가 AI 코드 설명 필수
    mandatory_checks:
      - security_scan              # 보안 스캔 통과
      - lint_pass                  # 린트 통과
      - test_coverage_threshold    # 테스트 커버리지 80% 이상
      - dependency_audit           # 새 의존성 감사
    
  review_checklist:
    - "AI가 생성한 코드의 비즈니스 로직이 정확한가?"
    - "불필요한 추상화나 과도한 패턴이 없는가?"
    - "에러 핸들링이 프로덕션 수준인가?"
    - "새로 추가된 의존성이 라이선스 정책에 부합하는가?"
    - "하드코딩된 값이나 매직 넘버가 없는가?"
    - "테스트가 실제 엣지케이스를 커버하는가?"
```

## 2단계: 자동화된 품질 게이트

### GitHub Actions 워크플로우

정책을 문서로만 놔두면 지켜지지 않아요. CI에 넣어서 자동으로 강제해야 해요.

```yaml
# .github/workflows/ai-governance-check.yml
name: AI Governance Check

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  governance-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect AI Generated Code
        id: ai-detect
        run: |
          # PR diff에서 AI 생성 패턴 탐지
          DIFF=$(git diff origin/main...HEAD)
          
          # 새로 추가된 의존성 추출
          NEW_DEPS=$(echo "$DIFF" | grep -E '^\+.*"(dependencies|devDependencies)"' -A 50 | grep '^\+' | grep -v '^\+\+\+')
          echo "new_deps=$NEW_DEPS" >> $GITHUB_OUTPUT
          
          # 대규모 파일 변경 감지 (AI 생성 가능성 높음)
          LARGE_CHANGES=$(git diff --stat origin/main...HEAD | grep -E '\|\s+[0-9]{3,}')
          echo "large_changes=$LARGE_CHANGES" >> $GITHUB_OUTPUT

      - name: Security Scan
        run: |
          # 시크릿 스캔
          npx secretlint "**/*"
          
          # 의존성 취약점 체크
          npm audit --audit-level=high || true

      - name: License Check
        run: |
          # 새 의존성 라이선스 확인
          npx license-checker --production --failOn "GPL-2.0;GPL-3.0;AGPL-3.0"

      - name: Test Coverage Gate
        run: |
          npm test -- --coverage --coverageThreshold='{"global":{"branches":80,"functions":80,"lines":80}}'

      - name: Code Quality Metrics
        run: |
          # 복잡도 체크
          npx complexity-report --format json src/ > complexity.json
          
          # 평균 복잡도가 15 이상이면 경고
          AVG=$(jq '.summary.average.cyclomatic' complexity.json)
          if (( $(echo "$AVG > 15" | bc -l) )); then
            echo "::warning::평균 순환 복잡도가 높습니다: $AVG"
          fi
```

### 의존성 감사 자동화

```bash
#!/bin/bash
# scripts/audit-new-deps.sh
# PR에서 새로 추가된 의존성을 자동 감사

set -euo pipefail

echo "=== 의존성 감사 시작 ==="

# package.json 변경 감지
if git diff origin/main...HEAD -- package.json | grep -q '^\+'; then
  echo "새 의존성이 감지되었습니다."
  
  # 추가된 패키지 추출
  ADDED=$(git diff origin/main...HEAD -- package.json \
    | grep '^\+' | grep -v '^\+\+\+' \
    | grep -oP '"[^"]+": "\^?[0-9]' \
    | cut -d'"' -f2)
  
  for pkg in $ADDED; do
    echo "--- 감사 중: $pkg ---"
    
    # npm 정보 조회
    INFO=$(npm info "$pkg" --json 2>/dev/null)
    
    # 라이선스 확인
    LICENSE=$(echo "$INFO" | jq -r '.license // "UNKNOWN"')
    echo "  라이선스: $LICENSE"
    
    # 주간 다운로드 수 확인
    DOWNLOADS=$(echo "$INFO" | jq -r '.downloads // 0')
    echo "  주간 다운로드: $DOWNLOADS"
    
    # 마지막 업데이트 확인
    MODIFIED=$(echo "$INFO" | jq -r '.time.modified // "unknown"')
    echo "  마지막 업데이트: $MODIFIED"
    
    # 경고 조건
    if [[ "$LICENSE" == "UNKNOWN" || "$LICENSE" == "GPL"* ]]; then
      echo "  ⚠️ 라이선스 확인 필요"
    fi
  done
fi

echo "=== 의존성 감사 완료 ==="
```

## 3단계: 팀 가이드라인 문서

### CLAUDE.md 팀 표준 템플릿

팀원 모두가 같은 규칙으로 AI를 쓰게 하려면 공유 설정이 필요해요.

```markdown
# CLAUDE.md — 팀 공유 표준

## 코딩 규칙
- TypeScript strict 모드 필수
- ESLint + Prettier 규칙 준수
- 함수 최대 50줄, 파일 최대 300줄
- 모든 public 함수에 JSDoc 주석

## 테스트 규칙
- 새 함수는 반드시 단위 테스트 작성
- 비즈니스 로직은 통합 테스트 필수
- 테스트 커버리지 80% 미만 커밋 금지

## 보안 규칙
- 환경 변수는 반드시 .env에서 로드
- SQL 쿼리는 파라미터 바인딩 필수
- 사용자 입력은 반드시 검증 후 사용
- JWT 시크릿은 최소 256비트

## AI 사용 규칙
- AI 생성 코드는 반드시 직접 이해 후 커밋
- 새 의존성 추가 시 팀 채널에 공유
- 보안 관련 코드는 AI 단독 생성 금지
```

### PR 템플릿

```markdown
<!-- .github/PULL_REQUEST_TEMPLATE/ai-assisted.md -->
## AI 도움 여부

- [ ] AI 코딩 도구를 사용했습니다
- 사용한 도구: (Claude Code / Cursor / Copilot / 기타)
- AI가 작성한 코드 비율: 약 ___%

## AI 코드 설명

> AI가 생성한 주요 코드 블록에 대한 작성자의 이해도를 설명해주세요.

1. **파일/함수명**: 
   - AI가 한 일:
   - 내가 확인/수정한 부분:

## 체크리스트

- [ ] AI 생성 코드를 한 줄씩 읽고 이해했습니다
- [ ] 보안 관련 코드에 AI를 단독 사용하지 않았습니다
- [ ] 새 의존성의 라이선스를 확인했습니다
- [ ] 테스트 커버리지가 80% 이상입니다
- [ ] 린트/타입 체크를 통과합니다
```

## 4단계: 품질 메트릭 대시보드

### 추적해야 할 핵심 지표

```typescript
// metrics/ai-governance-metrics.ts

interface GovernanceMetrics {
  // 코드 품질
  aiCodeAcceptanceRate: number;     // AI 코드 중 리뷰 통과 비율
  avgReviewRoundsAI: number;        // AI 코드 평균 리뷰 라운드
  avgReviewRoundsHuman: number;     // 수동 코드 평균 리뷰 라운드
  
  // 보안
  securityIssuesFromAI: number;     // AI 코드에서 발견된 보안 이슈
  dependencyVulnerabilities: number; // 의존성 취약점 수
  
  // 생산성
  prMergeTimeAI: number;            // AI 코드 PR 평균 머지 시간 (시간)
  prMergeTimeHuman: number;         // 수동 코드 PR 평균 머지 시간
  
  // 테스트
  testCoverageAI: number;           // AI 코드 테스트 커버리지
  testCoverageHuman: number;        // 수동 코드 테스트 커버리지
  bugRateAI: number;                // AI 코드 버그 발생률
  bugRateHuman: number;             // 수동 코드 버그 발생률
}

// 주간 리포트 생성
function generateWeeklyReport(metrics: GovernanceMetrics): string {
  const lines: string[] = [
    '# AI 거버넌스 주간 리포트',
    '',
    '## 코드 품질',
    `| 지표 | AI 코드 | 수동 코드 |`,
    `|------|---------|-----------|`,
    `| 리뷰 통과율 | ${metrics.aiCodeAcceptanceRate}% | - |`,
    `| 평균 리뷰 라운드 | ${metrics.avgReviewRoundsAI} | ${metrics.avgReviewRoundsHuman} |`,
    `| 테스트 커버리지 | ${metrics.testCoverageAI}% | ${metrics.testCoverageHuman}% |`,
    `| 버그 발생률 | ${metrics.bugRateAI}% | ${metrics.bugRateHuman}% |`,
    '',
    '## 보안',
    `- AI 코드 보안 이슈: ${metrics.securityIssuesFromAI}건`,
    `- 의존성 취약점: ${metrics.dependencyVulnerabilities}건`,
    '',
    '## 생산성',
    `| 지표 | AI 코드 | 수동 코드 |`,
    `|------|---------|-----------|`,
    `| PR 머지 시간 | ${metrics.prMergeTimeAI}h | ${metrics.prMergeTimeHuman}h |`,
  ];
  
  return lines.join('\n');
}
```

### 간단한 메트릭 수집 스크립트

```bash
#!/bin/bash
# scripts/collect-governance-metrics.sh
# GitHub API로 주간 거버넌스 메트릭 수집

REPO="your-org/your-repo"
SINCE=$(date -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ)

echo "=== AI 거버넌스 메트릭 수집 (최근 7일) ==="

# 전체 머지된 PR 수
TOTAL_PRS=$(gh api "repos/$REPO/pulls?state=closed&sort=updated&direction=desc&per_page=100" \
  --jq "[.[] | select(.merged_at > \"$SINCE\")] | length")
echo "머지된 PR: ${TOTAL_PRS}건"

# AI 태그가 붙은 PR 수
AI_PRS=$(gh api "repos/$REPO/pulls?state=closed&sort=updated&direction=desc&per_page=100" \
  --jq "[.[] | select(.merged_at > \"$SINCE\") | select(.labels[].name == \"ai-assisted\")] | length")
echo "AI 관련 PR: ${AI_PRS}건"

# 리뷰 라운드 평균
echo "평균 리뷰 라운드 계산 중..."
gh api "repos/$REPO/pulls?state=closed&sort=updated&direction=desc&per_page=20" \
  --jq '.[] | select(.merged_at != null) | "\(.number) \(.title)"' | head -10

echo "=== 수집 완료 ==="
```

## 5단계: 점진적 도입 로드맵

거버넌스를 한 번에 전부 적용하면 팀의 반발만 커져요. 단계적으로 넣는 게 중요해요.

| 주차 | 적용 항목 | 강제 여부 |
|------|-----------|-----------|
| 1-2주 | 사용 가이드라인 공유, CLAUDE.md 팀 표준 배포 | 권장 |
| 3-4주 | PR 템플릿 도입, AI 사용 체크리스트 | 권장 |
| 5-6주 | CI에 린트/테스트 커버리지 게이트 추가 | 필수 |
| 7-8주 | 의존성 감사 자동화, 보안 스캔 | 필수 |
| 9-10주 | 메트릭 대시보드 운영, 주간 리포트 | 필수 |
| 11-12주 | 분기 리뷰, 정책 업데이트 | 필수 |

## 따라하기

### Step 1: 정책 파일 생성

```bash
# 프로젝트 루트에 정책 파일 추가
touch .ai-policy.yaml
touch .ai-review-policy.yaml

# PR 템플릿 추가
mkdir -p .github/PULL_REQUEST_TEMPLATE
touch .github/PULL_REQUEST_TEMPLATE/ai-assisted.md
```

### Step 2: CI 워크플로우 추가

```bash
# GitHub Actions 워크플로우 추가
mkdir -p .github/workflows
cp ai-governance-check.yml .github/workflows/

# 의존성 감사 스크립트
mkdir -p scripts
cp audit-new-deps.sh scripts/
chmod +x scripts/audit-new-deps.sh
```

### Step 3: 팀 온보딩

```bash
# CLAUDE.md 팀 표준 배포
cp CLAUDE.md.team-standard ./CLAUDE.md

# 팀 채널에 가이드라인 공유
# → Slack/Discord에 정책 요약 포스팅
# → 팀 미팅에서 10분 데모
```

### Step 4: 메트릭 수집 시작

```bash
# 주간 메트릭 수집 크론 등록
crontab -e
# 0 9 * * MON /path/to/scripts/collect-governance-metrics.sh >> /var/log/governance.log
```

## 흔한 실수와 해결

| 실수 | 왜 문제인가 | 해결 |
|------|------------|------|
| 규칙만 많고 자동화 없음 | 아무도 안 지킴 | CI 게이트로 자동 강제 |
| 처음부터 전부 적용 | 팀 피로도 급증 | 4주 단위 점진 도입 |
| AI 사용 자체를 금지 | 생산성 이점 포기 | 범위 한정 + 리뷰 강화 |
| 메트릭 없이 운영 | 효과 측정 불가 | 주간 리포트 필수화 |
| 정책 업데이트 안 함 | 도구 발전 따라가지 못함 | 분기 1회 정책 리뷰 |

## 더 알아보기

- [가이드 38: AI 생성 코드 보안 거버넌스](../../guides/38-ai-code-security-governance.md)
- [워크플로우: AI 코드 거버넌스](../../workflows/ai-code-governance.md)
- [가이드 21: 팀 AI 도입 실전 가이드](../../guides/21-team-ai-adoption.md)
- [치트시트: AI 코드 리뷰 프롬프트 패턴](../../cheatsheets/ai-code-review-prompt-cheatsheet.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
