# AI 에이전트 코드 품질 워크플로우 치트시트 2026

> AI 에이전트와 함께 코드 품질을 유지하면서 빠르게 개발하는 실전 패턴 — 품질 게이트 자동화, 리뷰 패턴, 테스트 커버리지 전략 한 페이지 정리

## AI 코드 리뷰 핵심 프롬프트

| 상황 | 프롬프트 패턴 |
|------|-------------|
| 전체 리뷰 | `변경된 코드를 리뷰해줘. 보안, 에러 처리, 타입 안전성, 성능 순서로 체크해줘` |
| 보안 집중 | `이 코드에서 OWASP Top 10 관점에서 위험한 패턴을 찾아줘` |
| 중복 탐지 | `이 파일에서 중복 로직을 찾고, 공통 함수로 추출할 수 있는 부분을 알려줘` |
| 커버리지 확인 | `이 함수의 엣지 케이스를 나열하고 누락된 테스트를 작성해줘` |
| 두 번째 의견 | `다른 AI 에이전트가 작성한 이 코드를 비판적으로 검토해줘. 놓친 문제를 찾아줘` |

## 품질 게이트 자동화 설정

### Pre-commit Hook (AI 통합)

```bash
# .git/hooks/pre-commit
#!/bin/bash

# 1. 정적 분석 (빠른 체크)
npm run lint --silent || exit 1
npx tsc --noEmit --silent || exit 1

# 2. AI 코드 리뷰 (변경된 파일만)
CHANGED=$(git diff --cached --name-only --diff-filter=ACM | grep '\.ts$')
if [ -n "$CHANGED" ]; then
  echo "$CHANGED" | xargs claude -p \
    "이 파일들의 변경사항을 리뷰해줘. 심각한 문제만 보고해줘. 문제 없으면 OK 출력" \
    | grep -i "error\|critical\|심각" && exit 1
fi

echo "품질 게이트 통과"
```

### CI 파이프라인 품질 게이트

```yaml
# .github/workflows/quality-gate.yml
name: Quality Gate

on: [pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: 린트 & 타입 체크
        run: |
          npm ci
          npm run lint
          npm run type-check

      - name: 테스트 + 커버리지
        run: |
          npm test -- --coverage --passWithNoTests
          # 커버리지 80% 미만이면 실패
          npx coverage-check --min 80

      - name: 보안 스캔
        run: npx audit-ci --moderate

      - name: AI 리뷰 요약 (PR 코멘트)
        uses: actions/github-script@v7
        with:
          script: |
            const diff = await exec('git diff origin/main...HEAD');
            // AI 리뷰 결과를 PR 코멘트로 등록
```

## 커버리지 유지 전략

| 상황 | AI 활용 패턴 |
|------|------------|
| 신규 기능 추가 | 구현 전에 먼저 "이 함수의 테스트 케이스를 작성해줘"로 테스트 먼저 |
| 커버리지 하락 | `커버리지 리포트를 보고 테스트가 필요한 라인을 찾아서 작성해줘` |
| 엣지 케이스 | `null, undefined, 빈 배열, 최대값 등 경계값 테스트를 추가해줘` |
| 레거시 코드 | `이 함수를 변경하기 전에 현재 동작을 검증하는 스냅샷 테스트를 만들어줘` |

## AI 코드 품질 유지 핵심 패턴

### 1. 리뷰 세션 분리

```bash
# 구현 세션과 리뷰 세션을 분리
# 세션 1: 구현
claude "사용자 인증 미들웨어를 구현해줘"

# 세션 2: 별도 컨텍스트에서 리뷰 (편향 없이)
claude "이 미들웨어 코드를 검토해줘: [코드 붙여넣기]
보안 취약점, 에러 처리 미흡, 성능 문제 중심으로 봐줘"
```

### 2. 점진적 품질 게이트

```
빠른 게이트 (로컬, 2초 이내)
└─ ESLint + Prettier
└─ TypeScript 컴파일

중간 게이트 (pre-push, 30초 이내)
└─ 단위 테스트
└─ AI 리뷰 (변경 파일만)

느린 게이트 (CI, 5분 이내)
└─ 통합 테스트
└─ 커버리지 체크
└─ 보안 스캔
└─ 성능 회귀 테스트
```

### 3. AI 코드 드리프트 방지

```bash
# 주기적으로 AI 생성 코드 일관성 체크
claude "프로젝트의 코딩 컨벤션(CLAUDE.md 기준)과 다르게 작성된 파일을 찾아줘.
불일치 파일 목록과 구체적인 이유를 알려줘"
```

## CLAUDE.md 품질 섹션 필수 항목

```markdown
## 코드 품질 규칙

### 금지 사항
- any 타입 사용 금지
- console.log 프로덕션 코드에 남기기 금지
- 테스트 없는 신규 함수 금지

### 필수 사항
- 함수별 JSDoc 주석
- 에러는 반드시 상위로 전파 또는 로깅
- 복잡도 10 이하 (eslint complexity 규칙 준수)

### 테스트 기준
- 신규 함수: 단위 테스트 필수
- 커버리지 목표: 80% 이상
- 엣지 케이스: null/undefined/빈값 항상 포함
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| AI가 테스트를 생략하고 구현만 함 | 프롬프트에 "테스트 코드도 함께" 명시 |
| 커버리지는 높은데 의미 없는 테스트 | "엣지 케이스와 실패 시나리오 위주로 테스트 작성해줘" |
| AI가 린트 에러를 무시하고 계속 진행 | CLAUDE.md에 "린트 에러 있으면 반드시 수정 후 다음 단계 진행" 추가 |
| 리뷰 없이 바로 머지 | PR 템플릿에 AI 리뷰 체크박스 추가 + 필수 항목으로 설정 |
| AI가 보안 취약점 코드를 생성 | 구현 후 반드시 "보안 관점에서 이 코드 검토해줘" 프롬프트 실행 |

## 팀 워크플로우 통합 체크리스트

- [ ] CLAUDE.md에 코드 품질 규칙 명시
- [ ] Pre-commit hook에 린트 + 타입 체크 설정
- [ ] CI에 커버리지 임계값(80%) 설정
- [ ] PR 템플릿에 "AI 리뷰 완료" 체크박스 추가
- [ ] 주 1회 AI 코드 드리프트 점검 스케줄 등록
- [ ] 보안 스캔(`npm audit`, Checkmarx 등) CI 통합
- [ ] 코드 리뷰 시 두 번째 AI 세션으로 교차 검토

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
