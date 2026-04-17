# AI 생성 코드 신뢰 검증 파이프라인

> AI 에이전트가 작성한 코드를 프로덕션에 내보내기 전에 신뢰 수준을 체계적으로 검증하는 단계별 워크플로우

## 개요

AI 코딩 도구를 쓰다 보면 어느 순간 이런 생각이 들어요. "이 코드, 믿고 배포해도 되는 걸까?"

AI가 생성한 코드는 겉보기에는 깔끔하지만 실제로는 엣지 케이스를 빠뜨리거나, 레거시 패턴을 그대로 복사하거나, 프로젝트 컨벤션을 무시하는 경우가 있어요. 특히 팀 전체가 AI를 쓰는 환경에서는 검증 없이 AI 코드가 쌓이면 기술 부채가 눈덩이처럼 커질 수 있습니다.

이 워크플로우는 AI 생성 코드를 **탐지 → 정적 분석 → 동적 검증 → 리뷰 → 승인** 5단계로 나눠서 신뢰 검증 파이프라인을 구성하는 방법을 설명해요.

## 사전 준비

- Git 기반 프로젝트 (GitHub/GitLab)
- CI/CD 파이프라인 (GitHub Actions 권장)
- AI 코딩 도구 1개 이상 (Claude Code, Cursor, Copilot 등)
- 정적 분석 도구 (ESLint, Pylint, golangci-lint 등)

## 1단계: AI 코드 탐지

### AI 생성 코드 마킹 규칙 수립

AI가 생성한 코드를 추적하려면 먼저 팀이 공통 규칙을 정해야 해요.

**커밋 메시지 규칙:**
```
feat(auth): implement JWT refresh flow [ai-assisted]
fix(api): handle null response edge case [ai-generated]
```

**코드 내 마커 (선택):**
```python
# AI-ASSISTED: Claude Code 2026-04
def process_payment(amount: float, currency: str) -> dict:
    ...
```

### Git Hook으로 탐지 자동화

커밋 단계에서 AI 코드 마킹 여부를 체크하는 hook을 추가해요.

```bash
# .git/hooks/commit-msg
#!/bin/bash
COMMIT_MSG=$(cat "$1")

# AI 도구 사용 여부 확인 (선택적 정책)
if echo "$COMMIT_MSG" | grep -q "\[ai"; then
  echo "✓ AI 코드 마킹 확인됨"
fi

exit 0
```

### GitHub Actions로 AI 코드 비율 측정

```yaml
# .github/workflows/ai-code-audit.yml
name: AI Code Audit

on: [pull_request]

jobs:
  detect-ai-code:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Count AI-assisted commits
        run: |
          AI_COMMITS=$(git log origin/main..HEAD --oneline | grep -c "\[ai" || true)
          TOTAL_COMMITS=$(git log origin/main..HEAD --oneline | wc -l)
          echo "AI 관련 커밋: $AI_COMMITS / $TOTAL_COMMITS"
          echo "ai_commits=$AI_COMMITS" >> $GITHUB_OUTPUT
```

## 2단계: 정적 분석

### AI 코드 특화 린트 규칙

AI 에이전트가 자주 놓치는 패턴들을 별도 린트 규칙으로 잡아내요.

**TypeScript/JavaScript (ESLint):**
```json
{
  "rules": {
    "no-console": "error",
    "no-any": "error",
    "@typescript-eslint/explicit-return-type": "warn",
    "security/detect-object-injection": "error",
    "security/detect-non-literal-fs-filename": "error"
  }
}
```

**Python (pylint + bandit):**
```bash
# CI에서 실행
bandit -r . -ll -ii -x tests/  # 보안 취약점 스캔
pylint src/ --fail-under=8.0    # 코드 품질 기준치
```

**공통 체크 항목:**

| 점검 항목 | 이유 |
|----------|------|
| 하드코딩된 문자열 (URL, 키, 경로) | AI가 예시 값을 그대로 남기는 경우가 많음 |
| 미사용 import / 변수 | AI가 생성 후 정리를 안 하는 경우 |
| TODO/FIXME 주석 | AI가 "나중에 처리"로 남겨두는 부분 |
| 지나치게 긴 함수 (50줄 이상) | AI는 한 함수에 과도한 로직을 넣는 경향 |
| 에러 처리 누락 | 예외 케이스를 빠뜨리는 빈도가 높음 |

### 자동 보안 스캔

```yaml
# GitHub Actions에 추가
- name: Security scan
  run: |
    # 시크릿 노출 여부
    grep -rn "api_key\|secret\|password\|token" --include="*.py" --include="*.ts" \
      | grep -v ".env\|.example\|test\|spec\|mock" || true

    # SQL 인젝션 패턴 (Python)
    grep -rn 'execute.*%s\|execute.*format\|execute.*f"' --include="*.py" || true
```

## 3단계: 동적 검증

### AI 코드 테스트 커버리지 기준

AI가 작성한 코드는 테스트도 AI가 작성하는 경우가 많아요. 이 경우 "테스트가 있으니 괜찮다"는 착각에 빠지기 쉬워요. 실제로 의미 있는 커버리지인지 확인해야 해요.

```bash
# 커버리지 측정 + 기준치 강제
# Python
pytest --cov=src --cov-fail-under=80 --cov-report=term-missing

# TypeScript (Jest)
jest --coverage --coverageThreshold='{"global":{"branches":70,"functions":80,"lines":80}}'

# Go
go test ./... -cover -coverprofile=coverage.out
go tool cover -func=coverage.out | grep -E "total:|< 70"
```

### 엣지 케이스 검증 자동화

AI 에이전트에게 추가 테스트 케이스를 생성하게 합니다.

```bash
# Claude Code로 엣지 케이스 테스트 생성
claude "이 함수의 현재 테스트를 읽고, 빠진 엣지 케이스를 찾아서 테스트를 추가해줘:
- null/undefined 입력
- 빈 배열/문자열
- 음수, 0, 최대값
- 동시성 이슈 (async 코드의 경우)
- 네트워크/DB 실패 시나리오"
```

### 회귀 테스트 파이프라인

```yaml
# .github/workflows/regression.yml
name: Regression Tests

on:
  pull_request:
    paths:
      - 'src/**'

jobs:
  regression:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run regression suite
        run: |
          # 기존 동작 보장 테스트
          npm run test:regression

          # 성능 기준치 확인
          npm run test:performance -- --fail-if-slower=10%
```

## 4단계: 코드 리뷰

### AI 코드 리뷰 가이드

일반 코드 리뷰와 AI 생성 코드 리뷰는 다르게 접근해야 해요.

**일반 리뷰 vs AI 코드 리뷰:**

| 포인트 | 일반 코드 | AI 생성 코드 |
|--------|----------|------------|
| 로직 정확성 | 작성자 의도 확인 | 실제 요구사항과 대조 필수 |
| 패턴 일관성 | 팀 컨벤션 확인 | 프로젝트 패턴과 상이한지 특히 주의 |
| 에러 처리 | 빠진 케이스 확인 | AI 특유의 낙관적 에러 처리 패턴 주의 |
| 테스트 | 커버리지 확인 | 테스트가 실제로 의미 있는지 확인 |
| 의존성 | 불필요한 패키지 | AI가 추가한 새 패키지 라이선스/보안 확인 |

### 리뷰어 체크리스트 (PR 템플릿)

```markdown
## AI 코드 검증 체크리스트

### 기능 검증
- [ ] 요구사항과 실제 구현이 일치함
- [ ] 엣지 케이스가 처리되어 있음
- [ ] 에러 시나리오가 명확하게 처리됨

### 코드 품질
- [ ] 프로젝트 컨벤션 준수
- [ ] 불필요한 복잡도 없음
- [ ] 주석이 실제 코드와 일치함

### 보안
- [ ] 입력값 검증 있음
- [ ] 하드코딩된 시크릿 없음
- [ ] SQL 인젝션 / XSS 취약점 없음

### 테스트
- [ ] 테스트가 실제 동작을 검증함 (형식적인 테스트 아님)
- [ ] 커버리지 기준 통과
```

## 5단계: 신뢰 점수 집계 + 승인

### 신뢰 점수 산정

각 단계의 결과를 점수로 환산해서 PR 자동 코멘트로 남겨요.

```python
# scripts/trust-score.py
def calculate_trust_score(results: dict) -> int:
    score = 100

    # 정적 분석
    if results["lint_errors"] > 0:
        score -= min(results["lint_errors"] * 2, 20)
    if results["security_issues"] > 0:
        score -= results["security_issues"] * 10

    # 테스트
    coverage = results["test_coverage"]
    if coverage < 80:
        score -= (80 - coverage)

    # 리뷰
    if results["review_comments"] > 5:
        score -= 10

    return max(score, 0)

# 결과 예시
# 점수 90+ → 자동 승인 가능
# 점수 70-89 → 리뷰어 1명 필수
# 점수 70 미만 → 시니어 리뷰 + 수정 요청
```

### 배포 게이트 설정

```yaml
# .github/workflows/deploy-gate.yml
- name: Check trust score
  run: |
    SCORE=$(python3 scripts/trust-score.py)
    echo "신뢰 점수: $SCORE"

    if [ "$SCORE" -lt 70 ]; then
      echo "❌ 신뢰 점수 미달 ($SCORE/100) — 배포 차단"
      exit 1
    elif [ "$SCORE" -lt 90 ]; then
      echo "⚠️ 신뢰 점수 주의 ($SCORE/100) — 리뷰어 승인 필요"
    else
      echo "✅ 신뢰 점수 통과 ($SCORE/100)"
    fi
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 자동 승인 기준 | 90점 이상 | 팀 성숙도에 따라 조정 |
| 최소 커버리지 | 80% | 도메인별로 다르게 설정 가능 |
| 보안 스캔 엄격도 | medium | production 코드는 high 권장 |
| 리뷰어 수 | 1명 | 높은 위험 코드는 2명으로 설정 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 커버리지는 높은데 실제 버그가 나옴 | 테스트 케이스 품질 점검 — 어설션이 형식적이진 않은지 확인 |
| 린트 규칙이 너무 엄격해서 CI가 자주 실패 | 경고/에러 구분, 최소 기준 먼저 설정 후 점진적으로 강화 |
| AI 코드 탐지가 누락됨 | 커밋 메시지 규칙 자동화 (pre-commit hook 강제 적용) |
| 신뢰 점수가 들쑥날쑥 | 가중치 조정 후 팀이 납득하는 기준으로 보정 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
