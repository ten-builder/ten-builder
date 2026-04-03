# AI PR 영향 범위(Blast Radius) 분석 가이드

> AI 에이전트가 생성한 PR의 실제 영향 범위를 자동 평가하고, 리스크 점수로 머지 판단을 최적화하는 실전 가이드

## 왜 Blast Radius 분석이 필요한가

AI 코딩 에이전트가 PR을 만들어주는 시대에요. 문제는 **AI가 만든 코드 변경이 어디까지 영향을 미치는지** 사람이 빠르게 판단하기 어렵다는 거예요.

한 파일만 바꿨는데 의존하는 모듈 10개가 깨질 수 있고, 타입 하나 수정했는데 전체 빌드가 실패할 수 있어요. 특히 AI 에이전트는 코드베이스 전체 맥락을 완벽히 이해하지 못한 채 변경을 제안하는 경우가 있어서, **변경의 파급 효과를 자동으로 측정하는 시스템**이 필수예요.

### 기존 코드 리뷰 vs Blast Radius 분석

| | 기존 코드 리뷰 | Blast Radius 분석 |
|---|---|---|
| 관점 | 변경된 코드 자체 | 변경이 미치는 전체 영향 |
| 범위 | diff 내부 | 의존성 그래프 전체 |
| 속도 | 리뷰어 역량에 의존 | 자동화 가능 |
| 판단 기준 | 주관적 경험 | 정량적 리스크 점수 |
| AI PR 대응 | 모든 PR 동일 취급 | 리스크 수준별 차등 프로세스 |

## 리스크 스코어링 모델

PR의 영향 범위를 0~100점으로 수치화해요. 점수가 높을수록 머지 전 더 신중한 검토가 필요해요.

### 5가지 리스크 축

```
총점 = (파일 영향도 × 0.25) + (의존성 깊이 × 0.25) + (변경 크기 × 0.2)
     + (핵심 경로 여부 × 0.2) + (테스트 커버리지 × 0.1)
```

| 축 | 측정 방법 | 점수 산정 |
|---|---|---|
| **파일 영향도** | 변경된 파일을 import하는 파일 수 | 0-2개: 10점, 3-5개: 30점, 6-10개: 60점, 11+: 90점 |
| **의존성 깊이** | 변경 → 최종 소비자까지 체인 길이 | depth 1: 10점, 2: 30점, 3: 60점, 4+: 90점 |
| **변경 크기** | 추가+삭제 라인 수 | ~50줄: 10점, ~200줄: 30점, ~500줄: 60점, 500+: 90점 |
| **핵심 경로** | 인증, 결제, DB 스키마 등 | 비핵심: 10점, 인접: 40점, 핵심: 80점, 인프라: 95점 |
| **테스트 커버리지** | 변경 파일의 테스트 존재 여부 | 전체 커버: 5점, 부분: 30점, 없음: 80점 |

### 리스크 등급과 대응

| 등급 | 점수 | 대응 |
|---|---|---|
| **Low** | 0-25 | 자동 머지 가능, CI 통과만 확인 |
| **Medium** | 26-50 | AI 리뷰 + 1명 수동 승인 |
| **High** | 51-75 | 2명 수동 리뷰 + 스테이징 테스트 |
| **Critical** | 76-100 | 팀 리뷰 필수 + 카나리 배포 |

## 의존성 그래프 분석

PR의 파급 효과를 정확히 측정하려면 코드베이스의 의존성 그래프를 먼저 구축해야 해요.

### Step 1: import 관계 추출

```bash
# TypeScript/JavaScript 프로젝트
npx madge --json src/ > dependency-graph.json

# Python 프로젝트
pip install pydeps
pydeps --no-show --cluster mypackage -o deps.json
```

### Step 2: 변경 파일의 역방향 의존성 찾기

```bash
# PR에서 변경된 파일 목록
CHANGED_FILES=$(gh pr diff $PR_NUMBER --name-only)

# 각 파일을 import하는 모든 파일 찾기 (역방향 추적)
for file in $CHANGED_FILES; do
  echo "=== $file ==="
  npx madge --depends "$file" src/
done
```

### Step 3: 영향 범위 시각화

```bash
# 변경 파일 기준 의존성 트리 (2단계까지)
npx madge --image impact.png --depends src/changed-file.ts src/

# 또는 AI에게 분석 요청
cat dependency-graph.json | \
  claude "이 의존성 그래프에서 $CHANGED_FILES 파일들이 변경되었을 때
         영향받는 모듈을 깊이 순서로 정리해줘"
```

## 자동화 파이프라인 구축

### GitHub Actions 설정

```yaml
name: PR Blast Radius Analysis
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  blast-radius:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get changed files
        id: changes
        run: |
          FILES=$(git diff --name-only origin/main...HEAD)
          echo "files<<EOF" >> $GITHUB_OUTPUT
          echo "$FILES" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Analyze dependencies
        id: deps
        run: |
          npm ci
          SCORE=0
          DETAILS=""

          for file in ${{ steps.changes.outputs.files }}; do
            # 역방향 의존성 수 계산
            DEP_COUNT=$(npx madge --depends "$file" src/ 2>/dev/null | wc -l)
            DETAILS="$DETAILS\n- $file: ${DEP_COUNT}개 파일이 의존"

            if [ "$DEP_COUNT" -gt 10 ]; then
              SCORE=$((SCORE + 90))
            elif [ "$DEP_COUNT" -gt 5 ]; then
              SCORE=$((SCORE + 60))
            elif [ "$DEP_COUNT" -gt 2 ]; then
              SCORE=$((SCORE + 30))
            else
              SCORE=$((SCORE + 10))
            fi
          done

          # 파일 수로 평균
          FILE_COUNT=$(echo "${{ steps.changes.outputs.files }}" | wc -w)
          AVG_SCORE=$((SCORE / FILE_COUNT))

          echo "score=$AVG_SCORE" >> $GITHUB_OUTPUT
          echo -e "$DETAILS" > /tmp/details.txt

      - name: Calculate diff size score
        id: size
        run: |
          ADDITIONS=$(git diff --stat origin/main...HEAD | tail -1 | grep -o '[0-9]* insertion' | grep -o '[0-9]*')
          DELETIONS=$(git diff --stat origin/main...HEAD | tail -1 | grep -o '[0-9]* deletion' | grep -o '[0-9]*')
          TOTAL=$((${ADDITIONS:-0} + ${DELETIONS:-0}))

          if [ "$TOTAL" -gt 500 ]; then
            echo "score=90" >> $GITHUB_OUTPUT
          elif [ "$TOTAL" -gt 200 ]; then
            echo "score=60" >> $GITHUB_OUTPUT
          elif [ "$TOTAL" -gt 50 ]; then
            echo "score=30" >> $GITHUB_OUTPUT
          else
            echo "score=10" >> $GITHUB_OUTPUT
          fi

      - name: Check critical paths
        id: critical
        run: |
          CRITICAL_PATTERNS="auth|payment|migration|schema|security|middleware"
          CHANGED="${{ steps.changes.outputs.files }}"

          if echo "$CHANGED" | grep -qiE "$CRITICAL_PATTERNS"; then
            echo "score=80" >> $GITHUB_OUTPUT
            echo "hit=true" >> $GITHUB_OUTPUT
          else
            echo "score=10" >> $GITHUB_OUTPUT
            echo "hit=false" >> $GITHUB_OUTPUT
          fi

      - name: Compute final risk score
        id: risk
        run: |
          DEP=${{ steps.deps.outputs.score }}
          SIZE=${{ steps.size.outputs.score }}
          CRIT=${{ steps.critical.outputs.score }}

          # 가중 평균
          FINAL=$(( (DEP * 25 + DEP * 25 + SIZE * 20 + CRIT * 20 + 30 * 10) / 100 ))

          if [ "$FINAL" -le 25 ]; then
            LABEL="low-risk"
            COLOR="0e8a16"
          elif [ "$FINAL" -le 50 ]; then
            LABEL="medium-risk"
            COLOR="fbca04"
          elif [ "$FINAL" -le 75 ]; then
            LABEL="high-risk"
            COLOR="e99695"
          else
            LABEL="critical-risk"
            COLOR="b60205"
          fi

          echo "score=$FINAL" >> $GITHUB_OUTPUT
          echo "label=$LABEL" >> $GITHUB_OUTPUT

      - name: Post PR comment
        uses: actions/github-script@v7
        with:
          script: |
            const score = ${{ steps.risk.outputs.score }};
            const label = '${{ steps.risk.outputs.label }}';
            const critHit = ${{ steps.critical.outputs.hit }};

            const emoji = score <= 25 ? '🟢' : score <= 50 ? '🟡' : score <= 75 ? '🟠' : '🔴';

            const body = `## ${emoji} Blast Radius: ${score}/100 (${label})

            | 축 | 점수 |
            |---|---|
            | 의존성 영향도 | ${{ steps.deps.outputs.score }} |
            | 변경 크기 | ${{ steps.size.outputs.score }} |
            | 핵심 경로 | ${{ steps.critical.outputs.score }} ${critHit ? '⚠️' : ''} |

            <details><summary>영향받는 파일 상세</summary>

            \`\`\`
            $(cat /tmp/details.txt)
            \`\`\`
            </details>`;

            github.rest.issues.createComment({
              ...context.repo,
              issue_number: context.issue.number,
              body
            });

            // 자동 라벨 부여
            github.rest.issues.addLabels({
              ...context.repo,
              issue_number: context.issue.number,
              labels: [label]
            });
```

## AI 에이전트와 함께 쓰는 리스크 분석 프롬프트

### PR diff 기반 영향 분석 프롬프트

```
다음 PR diff를 분석해서 blast radius를 평가해줘.

[diff 내용]

분석 기준:
1. 변경된 파일을 직접 import하는 파일이 몇 개인지
2. 의존성 체인이 얼마나 깊은지 (depth)
3. 인증, 결제, DB 스키마 등 핵심 경로에 해당하는지
4. 테스트가 변경 범위를 커버하는지
5. 런타임에 영향을 줄 수 있는 breaking change가 있는지

출력 형식:
- 리스크 점수: N/100
- 등급: Low/Medium/High/Critical
- 영향받는 주요 모듈 목록
- 추천 액션 (자동 머지 / 수동 리뷰 / 스테이징 테스트 등)
```

### 핵심 경로 탐지 프롬프트

```
이 코드베이스에서 다음 디렉토리/파일 중 핵심 경로(critical path)에
해당하는 것을 분류해줘.

핵심 경로 기준:
- 인증/인가 (auth, session, token)
- 결제/과금 (payment, billing, subscription)
- 데이터 스키마 (migration, schema, model definition)
- 인프라 설정 (Dockerfile, CI config, deploy script)
- 보안 관련 (encryption, CORS, CSP, rate limit)

[파일 목록]
```

## 실전 시나리오별 대응

### 시나리오 1: AI가 유틸 함수를 수정한 PR

```
변경: utils/formatDate.ts
역방향 의존성: 23개 파일
리스크: High (의존성 영향도 90 × 0.25 = 22.5)
```

**대응:**
1. 기존 테스트 전부 실행 확인
2. 변경된 인터페이스가 있다면 → 모든 호출부 확인
3. 순수 함수면 → 입출력 테스트로 충분
4. 부수 효과가 있다면 → 통합 테스트 필수

### 시나리오 2: AI가 새 파일을 추가한 PR

```
변경: features/newDashboard/index.tsx (신규)
역방향 의존성: 0개
리스크: Low (10 × 0.25 = 2.5)
```

**대응:**
- 자동 머지 후보
- 기존 코드에 영향 없음
- 코드 품질만 체크

### 시나리오 3: AI가 DB 마이그레이션을 만든 PR

```
변경: migrations/20260403_add_column.sql
핵심 경로: DB 스키마 (95점)
리스크: Critical
```

**대응:**
1. 롤백 마이그레이션 존재 확인
2. 스테이징 환경에서 실행 테스트
3. 데이터 유실 가능성 체크
4. 팀 리뷰 필수

## 커스터마이징 포인트

### 프로젝트별 핵심 경로 설정

```yaml
# .github/blast-radius-config.yml
critical_paths:
  - pattern: "src/auth/**"
    weight: 95
    label: "인증"
  - pattern: "src/payment/**"
    weight: 95
    label: "결제"
  - pattern: "prisma/migrations/**"
    weight: 90
    label: "DB 스키마"
  - pattern: "*.config.*"
    weight: 70
    label: "설정"
  - pattern: "src/middleware/**"
    weight: 60
    label: "미들웨어"

thresholds:
  auto_merge: 25
  single_review: 50
  team_review: 75

ignore_patterns:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "docs/**"
  - "*.md"
```

### 리스크 기반 자동 라벨링

| 라벨 | 조건 | 자동 액션 |
|---|---|---|
| `auto-merge` | 점수 ≤ 25, CI 통과 | 자동 머지 |
| `needs-review` | 점수 26-50 | CODEOWNERS에 리뷰 요청 |
| `needs-staging` | 점수 51-75 | 스테이징 배포 트리거 |
| `needs-team-review` | 점수 76+ | 팀 채널에 알림 |

## 도구 조합 추천

| 목적 | 도구 | 비고 |
|---|---|---|
| 의존성 그래프 | madge, dependency-cruiser | JS/TS 프로젝트 |
| 의존성 그래프 | pydeps, import-linter | Python 프로젝트 |
| 변경 영향 분석 | ast-grep, semgrep | AST 기반 패턴 매칭 |
| 리스크 스코어링 | 커스텀 스크립트 + AI | 프로젝트별 조정 |
| PR 자동 라벨링 | GitHub Actions + actions-labeler | CI 통합 |
| 시각화 | madge --image, D3.js | 영향 범위 그래프 |

## 핵심 정리

- PR의 영향 범위를 **정량적으로 측정**하면 리뷰 효율이 올라가요
- AI 에이전트가 만든 PR일수록 blast radius 분석이 중요해요 — 사람이 직접 짠 코드보다 맥락 부족 가능성이 높기 때문
- **리스크 점수 기반으로 프로세스를 차등 적용**하면 저위험 PR은 빠르게, 고위험 PR은 신중하게 처리할 수 있어요
- 의존성 그래프 + 핵심 경로 + 변경 크기 세 가지만 체크해도 대부분의 리스크를 포착할 수 있어요
- GitHub Actions에 한 번 세팅해두면 모든 PR에 자동으로 적용돼요

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
