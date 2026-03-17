# 가이드 20: AI 코딩 에러 복구 실전 전략

> AI 코딩 에이전트가 잘못된 코드를 생성했을 때 — 빠르게 감지하고, 안전하게 되돌리고, 재시도하는 방법

## 왜 에러 복구가 중요한가

AI 코딩 도구는 코드를 빠르게 만들어주지만, 그만큼 빠르게 잘못된 방향으로 갈 수도 있어요. 2026년 기준으로 AI가 생성한 코드의 약 5%에는 미묘한 버그가 포함되어 있다는 조사 결과가 있습니다. 문제는 이 5%가 "거의 맞는" 코드라서 찾기가 더 어렵다는 점이에요.

에러 복구 전략이 있으면:

- 잘못된 코드가 프로덕션에 도달하기 전에 잡을 수 있어요
- AI 세션이 꼬였을 때 빠르게 원래 상태로 돌아갈 수 있어요
- 시행착오를 두려워하지 않고 과감하게 실험할 수 있어요

## Step 1: Git을 세이브 포인트로 사용하기

AI와 작업할 때 가장 기본적인 방어선은 **자주 커밋하기**예요.

```bash
# AI에게 태스크를 하나 맡기기 전에 현재 상태 저장
git add -A && git commit -m "checkpoint: before AI refactoring"

# AI 작업 완료 후 결과가 좋으면
git add -A && git commit -m "feat: implement auth middleware"

# AI 작업 결과가 이상하면 즉시 되돌리기
git checkout -- .
# 또는 마지막 커밋으로 완전히 복구
git reset --hard HEAD
```

핵심 원칙은 **하나의 AI 태스크 = 하나의 커밋 단위**예요. 3번의 프롬프트까지는 괜찮았는데 4번째에서 꼬이는 경우가 많거든요. 중간중간 커밋해두면 안전하게 되돌릴 수 있어요.

## Step 2: 에러 패턴 인식하기

AI 코딩 도구가 만드는 대표적인 실수 유형을 알아두면 빠르게 감지할 수 있어요.

| 에러 유형 | 증상 | 감지 방법 |
|-----------|------|-----------|
| 환각(Hallucination) | 존재하지 않는 API/라이브러리 호출 | 타입 체크, import 확인 |
| Happy Path Only | 에러 핸들링 없음, null 체크 누락 | 엣지 케이스 테스트 |
| 과잉 구현 | 라이브러리 대신 직접 구현 | 코드 리뷰, 의존성 확인 |
| 보안 취약점 | SQL 인젝션, XSS, 하드코딩된 시크릿 | SAST 도구, 보안 린트 |
| 스타일 불일치 | 프로젝트 컨벤션 무시 | 린터, 포맷터 |

### 환각 감지 체크리스트

```bash
# TypeScript/JavaScript — 타입 체크로 존재하지 않는 API 잡기
npx tsc --noEmit

# Python — import 확인
python -c "import ast; ast.parse(open('main.py').read())"

# 의존성에 없는 패키지 참조 확인
grep -r "from\|import" src/ | grep -v node_modules | sort -u
```

## Step 3: 자동 검증 파이프라인 구축

AI가 코드를 생성할 때마다 자동으로 검증하는 파이프라인을 만들어두면 수동 리뷰 부담을 줄일 수 있어요.

### Pre-commit Hook 설정

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: type-check
        name: TypeScript Type Check
        entry: npx tsc --noEmit
        language: system
        pass_filenames: false
      - id: lint
        name: ESLint
        entry: npx eslint --fix
        language: system
        types: [javascript, typescript]
      - id: test
        name: Unit Tests
        entry: npm test -- --bail
        language: system
        pass_filenames: false
```

### 테스트를 함께 생성하는 습관

```
# 좋은 프롬프트 예시
"auth 미들웨어를 구현해줘. 
단위 테스트도 함께 작성하고, 
토큰 만료/잘못된 토큰/토큰 없음 케이스를 포함해줘."
```

테스트가 함께 생성되면 AI가 만든 코드의 정확성을 바로 확인할 수 있어요. 테스트 자체도 AI가 만들기 때문에 100% 신뢰하긴 어렵지만, 없는 것보다 훨씬 나아요.

## Step 4: "꼬였을 때" 복구 전략

AI 세션이 갈수록 이상해지는 경우가 있어요. 같은 에러를 반복 수정하거나, "맞습니다, 수정하겠습니다"를 반복하면서 코드가 점점 복잡해지는 상황이에요.

### 복구 방법 1: 컨텍스트 초기화

```bash
# Claude Code에서
/clear

# 새 세션으로 시작하면서 이전 결과물은 파일로 전달
# "이 파일에 있는 코드를 리뷰하고 문제점을 찾아줘"
```

### 복구 방법 2: Git Stash + 재시도

```bash
# 현재 변경사항을 임시 저장
git stash

# 원래 코드 상태에서 다른 접근법으로 재시도
# AI에게 다른 프롬프트를 줌

# 재시도 결과가 나으면 stash 삭제
git stash drop

# 이전 결과가 나았으면 복원
git stash pop
```

### 복구 방법 3: 디버그 신호 주입

AI가 에러를 눈으로만 찾으려 하면 잘 못 찾아요. 실행 결과를 돌려주는 게 더 효과적이에요.

```
# 좋은 접근
"이 에러 로그를 봐줘:
[에러 로그 붙여넣기]
원인을 분석하고 수정해줘."

# 나쁜 접근
"에러가 나는데 고쳐줘."
```

## Step 5: 브랜치 전략으로 리스크 격리

큰 변경을 AI에게 맡길 때는 브랜치로 격리하는 게 안전해요.

```bash
# 실험용 브랜치 생성
git checkout -b experiment/ai-refactor-auth

# AI 작업 진행... 커밋...

# 결과가 좋으면 PR 생성
gh pr create --title "refactor: auth module" --body "AI 에이전트로 리팩토링"

# 결과가 별로면 브랜치 삭제
git checkout main
git branch -D experiment/ai-refactor-auth
```

### 점진적 머지 패턴

대규모 리팩토링을 한 번에 하지 말고, 작은 PR 여러 개로 나눠요.

| 단계 | 브랜치 | 내용 |
|------|--------|------|
| 1 | `refactor/extract-types` | 타입 정의만 분리 |
| 2 | `refactor/auth-utils` | 유틸 함수 추출 |
| 3 | `refactor/auth-middleware` | 미들웨어 리팩토링 |
| 4 | `refactor/auth-tests` | 테스트 추가/수정 |

각 PR이 독립적으로 리뷰/머지 가능하면, 한 단계에서 문제가 생겨도 나머지에 영향이 없어요.

## Step 6: 정적 분석 도구 연동

AI가 생성한 코드를 자동으로 검사하는 도구를 프로젝트에 연동해두세요.

```bash
# JavaScript/TypeScript
npm install -D eslint @typescript-eslint/parser
npx eslint --fix src/

# Python
pip install ruff
ruff check --fix .

# 보안 취약점 스캔
npm audit
pip-audit
```

### Claude Code Hooks 예시

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "write|edit",
        "command": "npx tsc --noEmit 2>&1 | head -20"
      }
    ]
  }
}
```

파일을 수정할 때마다 자동으로 타입 체크를 실행해서, AI가 잘못된 코드를 쓰면 바로 피드백이 돌아와요. 이러면 AI가 스스로 수정할 수 있는 기회를 가지게 됩니다.

## 에러 복구 체크리스트

- [ ] 매 AI 태스크 전에 커밋(세이브 포인트) 생성
- [ ] 타입 체크 / 린터 통과 확인
- [ ] 테스트 실행 후 결과 확인
- [ ] AI가 존재하지 않는 API를 호출하지 않는지 import 검증
- [ ] 에러 핸들링이 포함되어 있는지 확인
- [ ] 3회 이상 같은 에러를 반복 수정 중이면 `/clear` 후 재시작
- [ ] 큰 변경은 별도 브랜치에서 진행

## 실전 시나리오: 복구 플로우

```
1. AI에게 기능 구현 요청
   ↓
2. 자동 검증 (타입 체크 + 테스트)
   ├─ 통과 → 커밋 → 다음 태스크
   └─ 실패 → 에러 로그를 AI에 전달
              ├─ 1회 수정 → 재검증
              └─ 2회 이상 실패 → /clear → 다른 접근법
                                 └─ 그래도 실패 → git reset → 수동 수정
```

## 다음 단계

→ [AI 디버깅 플레이북](../claude-code/playbooks/04-debugging.md)
→ [AI 출력물 검증 가이드](./18-ai-output-verification.md)
→ [Git + AI 워크플로우 치트시트](../cheatsheets/git-ai-workflow-cheatsheet.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder)
