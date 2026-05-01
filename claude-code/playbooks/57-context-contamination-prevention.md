# 플레이북 57: AI 에이전트 컨텍스트 오염 방지

> 계획→실행→검증 루프에서 컨텍스트가 오염되면 에이전트가 틀린 방향으로 달려간다 — 사전에 막는 실전 패턴

## 소요 시간

30-45분 (초기 설정 기준)

## 사전 준비

- Claude Code 또는 동급 AI 코딩 에이전트
- 프로젝트 루트에 `CLAUDE.md` (없으면 빈 파일로 생성)
- 에이전트 실행 로그 확인 가능한 터미널

---

## 컨텍스트 오염이란?

AI 에이전트가 여러 태스크를 이어서 실행하다 보면 이전 대화의 잔재, 실패한 시도의 흔적, 관련 없는 파일 내용이 현재 추론에 끼어든다. 이를 **컨텍스트 오염(context contamination)**이라 한다.

증상은 크게 두 가지다:

| 증상 | 원인 |
|------|------|
| 에이전트가 이미 수정된 코드를 다시 수정하려 함 | 이전 태스크 상태가 컨텍스트에 남아 있음 |
| 잘못된 파일 경로나 변수명을 자신 있게 사용 | 다른 태스크의 컨텍스트가 혼입 |
| 같은 오류를 반복적으로 수정 시도 | 실패 기록이 누적되어 판단 왜곡 |
| 관련 없는 모듈을 수정 대상으로 포함 | 과도한 컨텍스트 로딩 |

---

## Step 1: 오염 유형 진단

### 1-1. 태스크 전환 오염

긴 세션에서 태스크가 바뀔 때 이전 맥락이 남는 경우다.

```bash
# Claude Code: 태스크 전환 시 항상 새 대화 시작
# Ctrl+C로 현재 세션 종료 후 재시작

# 또는 명시적으로 컨텍스트 초기화 요청
claude "이전 대화 내용은 무시하고, 현재 README.md만 참고해서 진행해줘"
```

**탐지 신호:** 에이전트가 이전 태스크의 파일명이나 함수명을 언급하면 오염 의심.

### 1-2. 누적 실패 오염

에이전트가 같은 실패를 3회 이상 반복하면 실패 기록 자체가 판단을 방해한다.

```bash
# 실패 루프 탐지: 에러 메시지가 반복되는지 확인
claude code의 최근 출력에서 같은 에러가 반복되면 → 세션 리셋
```

### 1-3. 과도한 파일 로딩 오염

에이전트가 불필요한 파일을 대량으로 읽으면 핵심 정보가 희석된다.

```bash
# 로딩된 파일 수 확인 (Claude Code 기준)
# 도구 호출 로그에서 Read 횟수가 20회 이상이면 과적재 의심
```

---

## Step 2: CLAUDE.md로 컨텍스트 경계 설정

프로젝트 루트의 `CLAUDE.md`에 명확한 경계를 선언한다.

```markdown
# 컨텍스트 규칙

## 작업 범위
- 이 태스크의 범위: src/auth/ 디렉토리만
- 수정 금지 경로: src/payment/, src/admin/
- 참조 가능한 설정 파일: .env.example, tsconfig.json

## 컨텍스트 초기화 조건
- 오류가 3회 이상 반복되면 현재 접근법을 포기하고 다른 방법 제안
- 이전 대화에서 언급된 파일명은 다시 확인 후 사용

## 할루시네이션 방지
- 존재하지 않는 함수나 모듈을 가정하지 말 것
- 파일 존재 여부를 항상 먼저 확인할 것
- "아마도", "~일 것 같은" 표현 사용 시 즉시 확인 요청
```

---

## Step 3: 서브에이전트 격리 패턴

복잡한 태스크는 서브에이전트를 분리하여 컨텍스트가 섞이지 않게 한다.

```bash
# Git Worktree로 물리적 격리
git worktree add ../task-auth feature/auth-refactor
git worktree add ../task-api feature/api-cleanup

# 각 worktree에서 독립적인 에이전트 실행
cd ../task-auth && claude "auth 모듈만 리팩토링해줘"
cd ../task-api && claude "API 응답 구조 통일해줘"
```

각 서브에이전트가 처리하는 결과를 오케스트레이터가 수집하는 구조다.

```
오케스트레이터 에이전트
├── 서브에이전트 A (auth worktree) → 결과 파일 저장
├── 서브에이전트 B (api worktree)  → 결과 파일 저장
└── 수집 → 통합 검증
```

---

## Step 4: 체크포인트 저장으로 복구 지점 확보

에이전트가 긴 작업을 할 때 중간 상태를 파일로 저장한다.

```bash
# 체크포인트 파일 구조
cat > .agent-checkpoint.json << 'EOF'
{
  "task": "auth-module-refactor",
  "started_at": "2026-05-01T09:00:00",
  "completed_steps": ["step1-analysis", "step2-test-setup"],
  "current_step": "step3-implementation",
  "artifacts": ["src/auth/types.ts", "tests/auth.test.ts"]
}
EOF
```

에이전트 지시에 포함:
```
현재 진행 상황은 .agent-checkpoint.json을 참고해줘.
이미 완료된 단계는 건너뛰고 current_step부터 시작해줘.
```

---

## Step 5: 할루시네이션 탐지 게이트

에이전트 출력에서 오염/할루시네이션 신호를 사전에 잡는 검증 단계다.

### 5-1. 파일 존재 검증 게이트

```bash
# 에이전트가 언급한 파일이 실제로 존재하는지 확인
MENTIONED_FILES=$(cat agent-output.md | grep -E "`[^`]+\.(ts|js|py)`" | grep -oE "[a-zA-Z0-9/_.-]+\.(ts|js|py)")

for f in $MENTIONED_FILES; do
  if [ ! -f "$f" ]; then
    echo "WARNING: 에이전트가 언급한 파일 없음: $f"
  fi
done
```

### 5-2. API 호출 검증 게이트

```bash
# 에이전트가 작성한 코드에서 존재하지 않는 함수 호출 탐지
# TypeScript 기준
npx tsc --noEmit 2>&1 | grep "Cannot find name" | head -10
```

### 5-3. 반복 실패 감지

```bash
# 같은 테스트가 3회 이상 실패하면 중단
FAIL_COUNT=0
for i in {1..5}; do
  npm test 2>&1 | grep "FAIL" && FAIL_COUNT=$((FAIL_COUNT + 1))
  if [ $FAIL_COUNT -ge 3 ]; then
    echo "연속 실패 감지: 에이전트 접근법 변경 필요"
    break
  fi
done
```

---

## Step 6: 컨텍스트 프루닝 전략

컨텍스트가 커질수록 핵심 정보가 희석된다. 주기적으로 압축한다.

```markdown
# 에이전트에게 컨텍스트 요약 요청 (긴 세션 중간에 활용)

"지금까지 한 작업을 3줄로 요약하고,
다음 단계에서 필요한 정보만 남겨줘.
나머지 대화 내용은 무시해도 돼."
```

### 요약 저장 패턴

```bash
# 세션 중간 요약을 파일로 저장
cat > .context-summary.md << 'EOF'
## 현재 상태 (2026-05-01 11:00)

완료:
- auth/login.ts 타입 수정
- 단위 테스트 3개 추가

진행 중:
- auth/refresh.ts 리팩토링 (50% 완료)

미완료:
- 통합 테스트 작성
- 코드 리뷰 반영
EOF
```

---

## 체크리스트

- [ ] CLAUDE.md에 작업 범위와 수정 금지 경로 명시
- [ ] 태스크 전환 시 세션 새로 시작
- [ ] 복잡한 태스크는 Git Worktree로 격리
- [ ] 체크포인트 파일로 중간 상태 저장
- [ ] 3회 이상 같은 오류 반복 시 접근법 변경
- [ ] 에이전트 출력의 파일명/함수명 실존 여부 검증
- [ ] 세션이 길어지면 중간 요약으로 컨텍스트 압축

---

## 다음 단계

→ [플레이북 56: 그린필드 프로젝트 킥오프](./56-greenfield-project-kickoff.md)

→ [플레이북 54: 프롬프트 버전 관리](./54-prompt-version-control.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
