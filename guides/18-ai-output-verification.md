# 가이드 18: AI 출력물 검증 가이드

> AI가 만든 코드, 바로 커밋하지 마세요 — 코드 리뷰 체크리스트부터 자동 검증 파이프라인까지, 실전 검증 전략

## 소요 시간

15-25분

## 사전 준비

- AI 코딩 도구 사용 경험 (Claude Code, Cursor, Copilot 등)
- Git + PR 기반 워크플로우 이해
- 터미널 기본 사용법

## 왜 AI 출력물 검증이 필요한가요?

AI 코딩 도구가 하루가 다르게 발전하고 있지만, 2026년 현재 AI가 생성한 코드를 "믿고 쓰는 것"과 "검증하고 쓰는 것" 사이에는 품질 격차가 큽니다. 실제로 AI 코딩 에이전트가 만든 코드에서 자주 발견되는 문제들이 있어요:

- **컴파일은 되지만 의미가 틀린 코드** — 함수 시그니처는 맞는데 로직이 잘못된 경우
- **기존 코드와 스타일 불일치** — 프로젝트 컨벤션을 무시하고 자기만의 패턴 사용
- **에지 케이스 미처리** — 해피 패스만 구현하고 에러 핸들링을 건너뛰는 경우
- **불필요한 복잡성** — 단순한 문제를 과도하게 추상화하거나 패턴을 남용

검증은 "AI를 못 믿어서"가 아니라 **"AI를 잘 쓰기 위한"** 필수 과정이에요.

## AI 코드 검증 5단계 체크리스트

### Step 1: 의도 확인 — "내가 요청한 게 맞나?"

AI에게 태스크를 줬을 때 가장 먼저 확인할 것은 **요청과 결과의 일치 여부**예요.

```bash
# diff로 변경사항 확인
git diff --stat

# 변경된 파일 목록이 예상과 일치하는지 확인
git diff --name-only
```

| 체크 항목 | 확인 방법 |
|----------|----------|
| 요청한 파일만 수정됐는지 | `git diff --name-only`로 변경 파일 목록 확인 |
| 예상치 못한 파일 삭제가 없는지 | `git diff --stat`에서 deletion 확인 |
| 새로 생성된 파일이 적절한 위치인지 | 프로젝트 디렉토리 구조와 비교 |
| 설정 파일이 의도 없이 변경되지 않았는지 | `package.json`, `tsconfig.json` 등 변경 여부 확인 |

### Step 2: 기능 검증 — "실제로 동작하나?"

코드가 올바르게 작동하는지 직접 확인하는 단계예요.

```bash
# 타입 체크 (TypeScript)
npx tsc --noEmit

# 린트
npx eslint . --ext .ts,.tsx

# 유닛 테스트 실행
npm test

# 특정 파일만 테스트
npm test -- --grep "해당 기능"
```

**테스트가 없다면 직접 만들어 달라고 요청하세요:**

```
이 함수에 대한 유닛 테스트를 작성해줘.
해피 패스 2개, 에지 케이스 3개 포함해서.
```

### Step 3: 코드 품질 — "읽기 쉽고 유지보수 가능한가?"

AI가 생성한 코드가 기술적으로 맞더라도, 프로젝트의 기존 패턴과 어울려야 해요.

| 검증 항목 | 기준 |
|----------|------|
| 네이밍 컨벤션 | 프로젝트의 기존 패턴(camelCase, snake_case 등)과 일치 |
| 파일 구조 | 기존 모듈/컴포넌트 구조를 따르는지 |
| 에러 핸들링 | try-catch, 에러 타입 구분, 사용자 메시지 처리 |
| 로깅 | 프로젝트 로거 사용 여부, 로그 레벨 적절성 |
| 주석 | 불필요한 주석 없음, 복잡한 로직엔 설명 있음 |
| 중복 | 기존 유틸 함수가 있는데 새로 만들지 않았는지 |

```bash
# 중복 코드 탐지 (jscpd 사용)
npx jscpd --min-lines 5 --min-tokens 50 src/

# 복잡도 분석
npx es-complexity src/**/*.ts
```

### Step 4: 보안 점검 — "취약점은 없나?"

[가이드 16: AI 코딩 보안 가이드](./16-ai-coding-security.md)에서 자세히 다루고 있지만, 핵심만 빠르게 확인하세요.

```bash
# 시크릿 탐지
git diff | grep -iE "(api_key|secret|password|token|credential)" || echo "clean"

# 의존성 취약점 체크
npm audit
# 또는
pip audit
```

| 보안 체크 | 확인 포인트 |
|----------|-----------|
| 시크릿 노출 | API 키, 토큰이 하드코딩되지 않았는지 |
| 입력 검증 | 사용자 입력을 직접 쿼리/명령에 넣지 않는지 |
| 의존성 | 새로 추가된 패키지의 알려진 취약점 |
| 권한 체크 | 인증/인가 로직이 적절한지 |

### Step 5: 통합 확인 — "기존 시스템과 충돌 없나?"

```bash
# 전체 빌드
npm run build

# E2E 테스트 (있는 경우)
npm run test:e2e

# 개발 서버에서 수동 확인
npm run dev
```

## 자동 검증 파이프라인 구축

매번 수동으로 체크하기보다, CI/CD에 검증 게이트를 추가하면 누락을 막을 수 있어요.

### GitHub Actions 검증 워크플로우

```yaml
# .github/workflows/ai-code-verify.yml
name: AI Code Verification

on:
  pull_request:
    branches: [main]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install
        run: npm ci

      - name: Type Check
        run: npx tsc --noEmit

      - name: Lint
        run: npx eslint . --ext .ts,.tsx --max-warnings 0

      - name: Test
        run: npm test -- --coverage

      - name: Security Audit
        run: npm audit --audit-level=high

      - name: Check Coverage Threshold
        run: |
          COVERAGE=$(npx istanbul report --include coverage/coverage-final.json text-summary | grep Statements | awk '{print $3}' | tr -d '%')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi
```

### Pre-commit Hook으로 로컬 검증

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running AI code verification..."

# 타입 체크
npx tsc --noEmit || { echo "Type check failed"; exit 1; }

# 린트
npx eslint $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx)$') || { echo "Lint failed"; exit 1; }

# 시크릿 탐지
if git diff --cached | grep -iE "(api_key|secret|password)=.+"; then
  echo "Potential secret detected in staged changes"
  exit 1
fi

echo "All checks passed"
```

## AI 출력물 신뢰도 평가 기준

모든 AI 출력이 같은 수준의 검증을 필요로 하지는 않아요. 태스크 유형에 따라 검증 강도를 조절하세요.

| 태스크 유형 | 신뢰도 | 검증 강도 | 이유 |
|-----------|--------|----------|------|
| 보일러플레이트 생성 | 높음 | 낮음 | 패턴이 명확하고 에러 가능성 적음 |
| 유닛 테스트 작성 | 중간 | 중간 | 테스트 자체를 실행하면 검증 가능 |
| 비즈니스 로직 구현 | 낮음 | 높음 | 도메인 지식 필요, 에지 케이스 놓치기 쉬움 |
| 보안 관련 코드 | 낮음 | 최고 | 취약점이 직접적 피해로 이어짐 |
| 인프라/설정 변경 | 낮음 | 최고 | 잘못되면 서비스 전체에 영향 |
| 리팩토링 | 중간 | 높음 | 기존 동작을 깨뜨릴 수 있음 |

## 검증 실패 시 대응 패턴

AI 출력이 검증을 통과하지 못했을 때, 효과적으로 수정을 요청하는 패턴이에요.

### 패턴 1: 구체적 에러 피드백

```
이 코드에서 문제를 발견했어:
1. getUserById에서 null 반환 시 처리가 없음
2. 에러 메시지가 사용자에게 내부 스택을 노출함
3. rate limiting이 빠져 있음

각각 수정해줘. 기존 프로젝트에서는 
src/middleware/errorHandler.ts 패턴을 따르고 있어.
```

### 패턴 2: 테스트로 기대 동작 명시

```
이 테스트가 통과하도록 구현을 수정해줘:

test('빈 배열이면 기본값 반환', () => {
  expect(processItems([])).toEqual({ count: 0, items: [] });
});

test('null 입력이면 에러 throw', () => {
  expect(() => processItems(null)).toThrow(InvalidInputError);
});
```

### 패턴 3: 비교 레퍼런스 제공

```
src/services/orderService.ts의 createOrder 함수 스타일을 참고해서
이 코드를 다시 작성해줘. 특히 에러 핸들링 패턴과 로깅 방식을 맞춰줘.
```

## 팀에서 AI 코드 리뷰 문화 만들기

개인의 검증도 중요하지만, 팀 전체가 AI 코드를 다루는 기준을 갖추면 더 효과적이에요.

| 실천 방법 | 설명 |
|----------|------|
| PR 템플릿에 AI 사용 체크박스 추가 | AI 도구 사용 여부와 검증 항목을 명시 |
| CODEOWNERS 설정 | 보안/인프라 코드는 반드시 시니어 리뷰 |
| AI 생성 코드 커버리지 기준 상향 | 사람이 쓴 코드보다 높은 테스트 커버리지 요구 |
| 정기 AI 코드 품질 리뷰 | 월 1회 AI 생성 코드만 모아 패턴 분석 |

## 다음 단계

→ [가이드 16: AI 코딩 보안 가이드](./16-ai-coding-security.md)에서 보안 심화 내용 확인
→ [플레이북 10: AI 코드 리뷰](../claude-code/playbooks/10-code-review.md)에서 리뷰 자동화 실습
→ [워크플로우: AI 테스트 강화](../workflows/ai-test-augmentation.md)에서 테스트 파이프라인 구축

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder)
