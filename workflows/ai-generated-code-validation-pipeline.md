# AI 생성 코드 검증 파이프라인 워크플로우

> 프로덕션 배포 전 AI 에이전트가 작성한 코드를 체계적으로 검증하는 파이프라인 — 자동 테스트, 코드 품질 검사, 보안 스캔, 사람 검수 게이트 통합

## 왜 이 파이프라인이 필요한가

2026년 기준, AI가 작성한 코드의 45%가 OWASP Top 10 취약점을 포함하고 있다는 조사 결과가 있어요. 에이전트가 자신 있게 생성한 코드라도 보안 로직이나 엣지케이스에서 허점이 생기기 쉽습니다.

AI 에이전트에게 코드 작성을 맡기면 속도는 빨라지지만, 검증을 사람이 직접 하면 속도 이점이 사라져요. 이 파이프라인은 **자동화된 검증**으로 AI의 속도를 유지하면서 **프로덕션 안전성**을 확보하는 방법을 다룹니다.

## 파이프라인 구조

```
AI 에이전트 코드 생성
        ↓
  [자동 검증 게이트 1]
  - 유닛/통합 테스트 실행
  - 린트 & 포맷 검사
        ↓
  [자동 검증 게이트 2]
  - 보안 취약점 스캔 (SAST)
  - 의존성 감사
        ↓
  [사람 검수 게이트]
  - AI 코드 표시 → 집중 리뷰
  - 아키텍처/비즈니스 로직 확인
        ↓
   프로덕션 배포
```

## 사전 준비

- GitHub Actions 또는 GitLab CI 환경
- `npm audit`, `pip-audit`, `cargo audit` 중 하나 이상
- SAST 도구: CodeQL (GitHub 무료), Semgrep (오픈소스)
- PR 라벨 설정 권한

---

## 설정

### Step 1: AI 코드 감지 레이블 설정

AI 에이전트가 생성한 PR은 자동으로 `ai-generated` 레이블을 붙이도록 설정해요.

`.github/PULL_REQUEST_TEMPLATE.md`에 추가:

```markdown
## 변경 사항

<!-- 변경 내용 설명 -->

## AI 작성 여부

- [ ] 이 PR의 코드 일부 또는 전부를 AI 에이전트가 작성했습니다

<!-- AI 작성 시 위 체크박스를 체크하면 자동으로 ai-generated 레이블이 붙고
     추가 검증 파이프라인이 활성화됩니다 -->
```

`.github/workflows/label-ai-code.yml`:

```yaml
name: AI Code Label

on:
  pull_request:
    types: [opened, edited]

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const body = context.payload.pull_request.body || '';
            const isAI = body.includes('[x] 이 PR의 코드 일부 또는 전부를 AI 에이전트가 작성했습니다');
            if (isAI) {
              await github.rest.issues.addLabels({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                labels: ['ai-generated']
              });
            }
```

### Step 2: 테스트 + 린트 게이트

`.github/workflows/ai-validation-gate1.yml`:

```yaml
name: AI Code Validation - Gate 1 (Tests & Lint)

on:
  pull_request:
    types: [labeled]

jobs:
  validate:
    if: contains(github.event.label.name, 'ai-generated')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test -- --coverage --coverageThreshold='{"global":{"lines":70}}'

      - name: Lint check
        run: npm run lint

      - name: Type check
        run: npm run typecheck

      - name: Comment coverage on PR
        uses: actions/github-script@v7
        if: always()
        with:
          script: |
            const fs = require('fs');
            // coverage-summary.json이 있으면 PR에 코멘트
            try {
              const summary = JSON.parse(fs.readFileSync('coverage/coverage-summary.json'));
              const lines = summary.total.lines.pct;
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: `## AI 코드 검증 게이트 1\n\n테스트 커버리지: **${lines}%**\n\n${lines >= 70 ? '✅ 게이트 통과' : '❌ 커버리지 부족 (최소 70%)'}`
              });
            } catch(e) {}
```

### Step 3: 보안 스캔 게이트

`.github/workflows/ai-validation-gate2.yml`:

```yaml
name: AI Code Validation - Gate 2 (Security)

on:
  pull_request:
    types: [labeled]

jobs:
  security:
    if: contains(github.event.label.name, 'ai-generated')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # CodeQL 분석
      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript, typescript
          queries: security-extended

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: /language:javascript

      # 의존성 보안 감사
      - name: Dependency audit
        run: |
          npm audit --audit-level=high
          echo "의존성 감사 완료"

      # Semgrep 추가 스캔 (선택)
      - name: Semgrep scan
        uses: semgrep/semgrep-action@v1
        with:
          config: |
            p/owasp-top-ten
            p/javascript
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}
```

### Step 4: 사람 검수 게이트 설정

`CODEOWNERS` 파일에 AI 생성 코드 경로별 필수 리뷰어 지정:

```
# AI 생성 코드는 시니어 엔지니어 리뷰 필수
/src/auth/**  @senior-team
/src/payment/** @senior-team
/src/api/**  @backend-team
```

`.github/branch-protection.json` (GitHub API로 설정):

```json
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 2,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "required_status_checks": {
    "contexts": [
      "AI Code Validation - Gate 1 (Tests & Lint)",
      "AI Code Validation - Gate 2 (Security)"
    ]
  }
}
```

---

## 사용 방법

### AI 에이전트 PR 생성 시

1. AI 에이전트가 코드 작성 완료 후 PR 초안 생성
2. PR 템플릿에서 AI 작성 체크박스 체크
3. 자동으로 게이트 1, 2 실행
4. 두 게이트 통과 후 사람 리뷰 요청

### 리뷰어 집중 확인 항목

AI 코드 리뷰 시 **사람만이 판단할 수 있는 영역**에 집중해요:

| 확인 항목 | 이유 |
|----------|------|
| 비즈니스 로직 정확성 | AI는 요구사항을 잘못 해석할 수 있음 |
| 엣지케이스 처리 | 명세되지 않은 케이스를 AI가 누락하기 쉬움 |
| 인증/인가 흐름 | 보안 게이트가 통과해도 로직 오류 가능 |
| 성능 영향 | N+1 쿼리, 메모리 누수 등 |
| 아키텍처 일관성 | 기존 패턴과 맞는지 확인 |

---

## 커스터마이징

| 설정 | 기본값 | 조정 기준 |
|------|--------|----------|
| 최소 테스트 커버리지 | 70% | 도메인 중요도에 따라 80~90%로 높임 |
| 필수 리뷰어 수 | 2명 | 소규모 팀이면 1명으로 조정 |
| Semgrep 룰셋 | owasp-top-ten | 언어/프레임워크 특화 룰 추가 |
| 보안 감사 레벨 | high | 금융/의료 도메인은 moderate로 낮춤 |

---

## 문제 해결

| 문제 | 해결 |
|------|------|
| 게이트가 레이블 없이 실행 안 됨 | PR에 `ai-generated` 레이블 수동 추가 |
| CodeQL 초기화 실패 | 언어 설정 확인 (`languages:` 필드) |
| 의존성 감사에서 false positive | `npm audit --ignore` 또는 `.npmrc`에 예외 추가 |
| 커버리지 부족으로 게이트 차단 | AI에게 누락된 테스트 추가 요청 후 재실행 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
