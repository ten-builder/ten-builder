# AI 테스트 강화 워크플로우

> 기존 테스트 스위트의 빈틈을 AI가 찾아내고, 누락된 테스트를 자동 생성하여 CI 파이프라인에 통합하는 워크플로우

## 개요

코드는 잘 짰는데 테스트 커버리지가 50%대에서 멈춰있다면, AI 코딩 도구를 활용해서 빠르게 끌어올릴 수 있어요. 이 워크플로우는 세 단계로 나뉘어요:

1. **분석** — 현재 커버리지의 빈틈을 AI가 식별
2. **생성** — 누락된 테스트 케이스를 자동으로 작성
3. **통합** — CI 파이프라인에 자동 검증 단계 추가

핵심은 "처음부터 전부 AI가 쓰는 것"이 아니라, **이미 있는 테스트를 기반으로 빈틈을 채우는 것**이에요.

## 사전 준비

- AI 코딩 도구 (Claude Code, Cursor, 또는 Copilot)
- 기존 테스트 프레임워크가 설정된 프로젝트 (Jest, pytest, Go test 등)
- 커버리지 리포트 도구 (`istanbul`, `coverage.py`, `go tool cover`)
- CI 환경 (GitHub Actions, GitLab CI 등)

## 설정

### Step 1: 현재 커버리지 기준선 측정

먼저 현재 상태를 정확히 파악해요.

```bash
# JavaScript/TypeScript (Jest)
npx jest --coverage --coverageReporters=json-summary
cat coverage/coverage-summary.json | jq '.total'

# Python (pytest + coverage)
pytest --cov=src --cov-report=json
cat coverage.json | jq '.totals'

# Go
go test ./... -coverprofile=coverage.out
go tool cover -func=coverage.out | tail -1
```

커버리지 숫자만 보지 말고, **어떤 파일/함수가 0%인지** 확인하는 게 중요해요.

```bash
# Jest — 커버리지 0%인 파일 목록
npx jest --coverage 2>&1 | grep "0 %" | awk '{print $2}'

# pytest — 미커버 라인이 많은 파일 상위 10개
pytest --cov=src --cov-report=term-missing 2>&1 | sort -t'%' -k2 -n | head -10
```

### Step 2: AI에게 커버리지 갭 분석 요청

```
프로젝트의 테스트 커버리지를 분석해줘.

1. coverage 리포트를 읽고 커버리지가 낮은 파일 TOP 10을 정리해줘
2. 각 파일에서 테스트가 없는 함수/메서드를 나열해줘
3. 엣지 케이스가 빠져있는 기존 테스트를 찾아줘
4. 우선순위를 매겨줘 (비즈니스 로직 > 유틸리티 > 타입 정의)
```

AI가 분석 결과를 줄 때, **바로 테스트를 쓰라고 하지 말고** 분석 결과를 먼저 검토해요. AI가 놓치는 컨텍스트(예: 일부러 테스트를 안 쓴 레거시 코드)가 있을 수 있거든요.

### Step 3: 테스트 생성 규칙 설정

AI가 테스트를 쓸 때 지켜야 할 규칙을 프로젝트 설정 파일에 명시해요.

```markdown
# 테스트 생성 규칙 (CLAUDE.md 또는 .cursorrules에 추가)

## 테스트 컨벤션
- 테스트 파일명: `*.test.ts` (Jest) / `test_*.py` (pytest)
- describe 블록: 함수/클래스 단위로 그룹핑
- 테스트명: 한국어 OK, "~하면 ~해야 한다" 패턴
- mock은 최소한으로 — 실제 동작을 테스트하는 게 우선

## 금지 사항
- snapshot 테스트 남용 금지
- implementation detail 테스트 금지 (내부 상태 직접 확인)
- sleep/setTimeout으로 비동기 대기 금지

## 필수 포함
- Happy path + 최소 2개 엣지 케이스
- 에러 케이스 (잘못된 입력, 네트워크 실패 등)
- 경계값 테스트 (빈 배열, null, 최대값)
```

## 사용 방법

### 패턴 1: 파일 단위 테스트 생성

가장 기본적인 패턴이에요. 커버리지가 낮은 파일 하나를 지정해서 테스트를 만들어요.

```
src/services/payment.ts 파일의 테스트를 작성해줘.

기존 테스트 파일: src/services/__tests__/payment.test.ts
현재 커버리지: 라인 35%, 브랜치 20%

다음을 포함해줘:
- processPayment() 의 성공/실패/타임아웃 케이스
- refund() 의 전액/부분 환불 케이스
- validateCard() 의 유효/만료/잘못된 형식 케이스
```

### 패턴 2: PR 기반 테스트 강화

PR에서 변경된 코드에 대한 테스트를 자동으로 요청하는 패턴이에요.

```bash
# 변경된 파일 목록 추출
git diff --name-only main...HEAD -- '*.ts' '*.tsx' ':!*.test.*' ':!*.spec.*'
```

```
이 PR에서 변경된 파일들의 테스트를 강화해줘.

변경된 파일:
- src/api/users.ts (새 함수 3개 추가)
- src/utils/validation.ts (기존 함수 수정)

각 변경사항에 대해:
1. 새로 추가된 함수 → 새 테스트 작성
2. 수정된 함수 → 기존 테스트가 여전히 유효한지 확인 + 새 케이스 추가
```

### 패턴 3: 뮤테이션 테스트로 약한 테스트 발견

커버리지 100%여도 테스트가 실제로 버그를 잡는지는 별개의 문제에요. 뮤테이션 테스트를 활용하면 "살아남는 뮤턴트"(= 테스트가 못 잡는 버그)를 찾을 수 있어요.

```bash
# JavaScript — Stryker
npx stryker run --reporters clear-text

# Python — mutmut
mutmut run --paths-to-mutate=src/
mutmut results
```

```
뮤테이션 테스트 결과에서 살아남은 뮤턴트들이에요:

1. src/utils/calc.ts:15 — `>` → `>=` 변경해도 테스트 통과
2. src/api/auth.ts:42 — `&&` → `||` 변경해도 테스트 통과

각 뮤턴트를 잡을 수 있는 테스트 케이스를 추가해줘.
경계값을 정확히 검증하는 assertion이 필요해.
```

## CI 파이프라인 통합

### GitHub Actions 예제

```yaml
name: Test Augmentation Check
on:
  pull_request:
    branches: [main]

jobs:
  coverage-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests with coverage
        run: |
          npm ci
          npx jest --coverage --coverageReporters=json-summary

      - name: Check coverage threshold
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          THRESHOLD=80
          echo "Current coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
            echo "::error::Coverage $COVERAGE% is below threshold $THRESHOLD%"
            exit 1
          fi

      - name: Check new files have tests
        run: |
          # PR에서 추가된 소스 파일 중 테스트가 없는 것 체크
          NEW_FILES=$(git diff --name-only --diff-filter=A origin/main -- 'src/**/*.ts' ':!src/**/*.test.*')
          for f in $NEW_FILES; do
            TEST_FILE="${f%.ts}.test.ts"
            if [ ! -f "$TEST_FILE" ]; then
              echo "::warning::New file $f has no corresponding test"
            fi
          done
```

### pytest + GitHub Actions 예제

```yaml
  coverage-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        run: |
          pip install -r requirements.txt
          pytest --cov=src --cov-report=xml --cov-fail-under=75

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: ./coverage.xml
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 커버리지 목표 | 80% (라인) | 프로젝트 성숙도에 따라 60~90% |
| 브랜치 커버리지 | 70% | 조건문 분기 커버리지 |
| 새 파일 테스트 필수 | Yes | PR에 새 파일 추가 시 테스트 동반 여부 |
| 뮤테이션 점수 목표 | 60% | Stryker/mutmut 생존 뮤턴트 비율 |
| AI 생성 테스트 리뷰 | 필수 | 자동 생성 테스트도 사람이 검토 |

## 실전 팁

### AI 테스트 생성 시 흔한 실수

| 실수 | 해결 |
|------|------|
| mock이 너무 많아서 실제 동작을 검증 못함 | "mock 최소화, 실제 의존성 사용 우선" 규칙 명시 |
| 테스트명이 구현 세부사항을 반영 | "사용자 관점에서 행동을 설명하는 이름" 규칙 |
| assertion 하나만 있는 테스트 | "최소 2개 assertion, 상태 변화도 검증" |
| 비동기 테스트에서 race condition | `waitFor`, `act` 패턴 예제를 규칙에 포함 |
| 생성된 테스트가 기존 테스트와 스타일 불일치 | 기존 테스트 파일을 컨텍스트로 함께 전달 |

### 점진적 커버리지 향상 전략

한 번에 100%를 목표로 하면 오히려 의미 없는 테스트가 쌓여요. 추천하는 단계:

1. **1주차**: 커버리지 기준선 측정 + CI 게이트 설정 (현재 값 - 5%)
2. **2주차**: 비즈니스 핵심 로직 파일 TOP 5 테스트 강화
3. **3주차**: 나머지 파일 + 엣지 케이스 보강
4. **4주차**: 뮤테이션 테스트 도입 + 약한 테스트 개선
5. **이후**: PR마다 "새 코드는 80% 이상" 규칙 유지

## 문제 해결

| 문제 | 해결 |
|------|------|
| AI가 생성한 테스트가 실행 안 됨 | import 경로, 환경 변수, DB 연결 등 로컬 설정을 컨텍스트에 포함 |
| 커버리지는 올랐는데 테스트 품질이 낮음 | 뮤테이션 테스트로 실제 검증력 확인 |
| CI에서만 실패하는 테스트 | 타임존, 파일 경로, 환경 차이 체크 — `process.env.CI` 분기 |
| 테스트 실행 시간이 너무 길어짐 | 병렬 실행 (`--shard`, `-n auto`) + 변경 파일만 테스트 (`--changedSince`) |
| 기존 테스트와 충돌 | AI에게 기존 테스트 파일을 반드시 함께 보여주기 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
