# 플레이북 71: 멀티 에이전트 병렬 코딩 플레이북

> 여러 AI 코딩 에이전트를 역할별로 분리해 동시에 운용하는 실전 가이드 — Claude Code, Copilot, Cursor, Codex를 각자 잘하는 일에 배치하면 혼자 쓸 때보다 처리 속도가 3-5배 빨라져요.

## 소요 시간

30-60분 (초기 구성) / 이후 10분 내 반복 적용

## 사전 준비

- Claude Code (Max 이상 권장), GitHub Copilot, Cursor 중 2개 이상
- Git 워크트리 지원 환경 (Git 2.5+)
- tmux 또는 iTerm2 분할 터미널
- 태스크별 독립 실행이 가능한 프로젝트

## Step 1: 역할 설계 — 도구마다 강점이 다르다

멀티 에이전트 병렬 코딩의 핵심은 "같은 도구를 여러 개 켜기"가 아니라 **각 도구가 잘하는 역할에 배치**하는 거예요.

| 역할 | 추천 도구 | 이유 |
|------|----------|------|
| 오케스트레이터 (계획·조율) | Claude Code | 긴 컨텍스트, 복잡한 지시 처리 우수 |
| 기능 구현 | Claude Code / Codex CLI | 파일 편집·실행·테스트 루프 자동화 |
| IDE 내 인라인 편집 | Cursor / Copilot | 빠른 자동완성, 파일 내 부분 수정 |
| 코드 리뷰·버그 탐지 | Claude Code | 전체 코드베이스 분석 강점 |
| 테스트 생성 | Copilot / Claude Code | 단위 테스트 대량 생성 |
| 문서화 | Claude Code | 마크다운·주석 품질 우수 |

**기본 팀 구성 예시 (3인 팀):**

```
[Claude Code A] 오케스트레이터 + 핵심 기능 구현
[Claude Code B] 테스트 작성 + 문서화
[Cursor/Copilot] IDE 내 인라인 수정·리팩토링
```

## Step 2: Git 워크트리로 충돌 없는 환경 만들기

에이전트 병렬 작업에서 가장 많이 발생하는 실수가 "같은 브랜치에서 동시 편집"이에요. 워크트리로 각 에이전트에게 독립 작업 공간을 주면 파일 충돌이 구조적으로 없어져요.

```bash
cd ~/projects/myapp

# 에이전트별 독립 브랜치 + 워크트리 생성
git worktree add ../myapp-feat-auth    -b feature/auth-refactor
git worktree add ../myapp-feat-payment -b feature/payment-api
git worktree add ../myapp-tests        -b chore/test-coverage

# 현재 워크트리 목록 확인
git worktree list
```

각 에이전트는 자신에게 할당된 경로에서만 작업합니다:

```bash
# 에이전트 A: 인증 리팩토링
cd ~/projects/myapp-feat-auth
claude  # 또는 cursor, codex

# 에이전트 B: 결제 API 개발
cd ~/projects/myapp-feat-payment
claude

# 에이전트 C: 테스트 커버리지 확장
cd ~/projects/myapp-tests
claude
```

## Step 3: 태스크 스펙 파일로 지시 명확화

에이전트가 여럿이면 지시가 불명확할 때 비용이 증폭돼요. 각 에이전트에게 `TASK.md`를 만들어 전달하면 재질문 없이 독립 실행이 가능해요.

```bash
# 에이전트 A용 태스크 스펙
cat > ~/projects/myapp-feat-auth/TASK.md << 'EOF'
# 태스크: JWT 리프레시 로직 개선

## 범위
- src/auth/refresh.ts 수정
- src/auth/middleware.ts 수정
- 공유 파일(src/db/, src/config/) 수정 금지

## 완료 조건
- [ ] 리프레시 토큰 만료 처리 로직 추가
- [ ] 단위 테스트 3개 이상 통과
- [ ] 타입 에러 없음 (pnpm typecheck)

## 제약
- payment 모듈 의존성 추가 금지
- DB 스키마 변경 금지
EOF
```

태스크 스펙 핵심 항목:

| 항목 | 설명 |
|------|------|
| 범위 | 수정 가능한 파일/디렉토리 명시 |
| 공유 파일 금지 | 다른 에이전트와 겹치는 파일 명시 |
| 완료 조건 | 체크리스트 형태로 명확화 |
| 제약 | 금지 액션(의존성 추가, 스키마 변경 등) |

## Step 4: tmux로 병렬 실행 관리

여러 에이전트를 동시에 관찰하려면 tmux 분할 레이아웃이 가장 효과적이에요.

```bash
# 4분할 레이아웃 자동 설정 스크립트
#!/bin/bash
SESSION="multi-agents"

tmux new-session -d -s $SESSION -n "agents"

# 4개 패널 분할
tmux split-window -h -t $SESSION
tmux split-window -v -t $SESSION:0.0
tmux split-window -v -t $SESSION:0.1

# 각 패널에서 에이전트 시작
tmux send-keys -t $SESSION:0.0 "cd ~/projects/myapp-feat-auth && claude" Enter
tmux send-keys -t $SESSION:0.1 "cd ~/projects/myapp-feat-payment && claude" Enter
tmux send-keys -t $SESSION:0.2 "cd ~/projects/myapp-tests && claude" Enter
tmux send-keys -t $SESSION:0.3 "cd ~/projects/myapp && watch -n5 'git worktree list && echo && git log --oneline --all -8'" Enter

tmux attach-session -t $SESSION
```

레이아웃 구성:

```
┌─────────────────┬─────────────────┐
│ Claude A         │ Claude B         │
│ (feat-auth)      │ (feat-payment)   │
├─────────────────┼─────────────────┤
│ Claude C         │ 상태 모니터링     │
│ (tests)          │ git worktree 현황 │
└─────────────────┴─────────────────┘
```

## Step 5: 결과 통합 — PR 머지 순서 관리

에이전트가 독립 브랜치에서 작업을 마치면 의존성 순서대로 머지해야 충돌이 없어요.

```bash
# 1. 공유 인터페이스(타입·스키마)부터 머지
git checkout main
git merge feature/auth-refactor --no-ff

# 2. 의존하는 기능 순서대로
git merge feature/payment-api --no-ff

# 3. 테스트는 모든 기능 머지 후 마지막
git merge chore/test-coverage --no-ff

# 4. 워크트리 정리
git worktree remove ~/projects/myapp-feat-auth
git worktree remove ~/projects/myapp-feat-payment
git worktree remove ~/projects/myapp-tests
```

**머지 순서 원칙:**

| 단계 | 브랜치 유형 | 이유 |
|------|------------|------|
| 1순위 | 공유 타입·인터페이스 | 이후 작업이 의존 |
| 2순위 | 핵심 기능 구현 | 비즈니스 로직 |
| 3순위 | 의존 기능 | 1순위에 의존 |
| 마지막 | 테스트·문서 | 완성된 코드 기준 |

## 체크리스트

- [ ] 에이전트별 역할과 담당 파일/디렉토리 사전 분리 완료
- [ ] 각 에이전트용 git worktree 생성
- [ ] TASK.md로 범위·완료 조건·제약 명시
- [ ] 공유 파일(lock 파일, 스키마, 설정) 편집 에이전트 1개로 제한
- [ ] tmux 분할로 병렬 모니터링 환경 구성
- [ ] 의존성 기반 머지 순서 사전 정의

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| package-lock.json 동시 편집 | 의존성 추가 에이전트 1개만 지정 |
| 공유 유틸 함수 중복 수정 | TASK.md에 공유 파일 수정 금지 명시 |
| 역할 없이 에이전트 4개 켜기 | 역할 먼저 설계, 도구 나중에 배치 |
| 완료 확인 없이 머지 | TASK.md 체크리스트 검증 후 머지 |

## 다음 단계

→ [플레이북 66: 멀티에이전트 세션 병렬 관리](66-multitasking-agents-session-management.md)
→ [플레이북 68: 멀티 레포 워크스페이스 설정](68-multi-repo-workspace-setup.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
