# Claude Code Agent View 실전 가이드 2026

> 터미널 하나에서 여러 에이전트를 병렬로 돌리는 시대가 왔다 — v2.1.139에서 등장한 Agent View와 백그라운드 세션으로 코딩 생산성을 높이는 방법

## Agent View란?

Claude Code v2.1.139부터 추가된 Agent View는 여러 에이전트 세션을 하나의 대시보드에서 관리하는 기능이다. 단일 터미널 세션에서 탭을 전환하듯 에이전트 상태를 확인하고, 응답이 필요한 에이전트에 빠르게 개입할 수 있다.

```bash
# Agent View 진입
claude agents

# 특정 세션 직접 실행
claude --background "PR 리뷰 요약 작성"
```

핵심은 **슈퍼바이저(supervisor) 프로세스**다. 처음으로 백그라운드 세션을 시작하거나 `claude agents`를 열면, 사용자별 슈퍼바이저 데몬이 뜬다. 이 슈퍼바이저가 각 에이전트 프로세스를 관리한다 — 터미널을 닫아도 에이전트는 계속 실행된다.

```
[슈퍼바이저 데몬]
    ├── 백그라운드 세션 A (PR 리뷰 중)
    ├── 백그라운드 세션 B (테스트 작성 중)
    └── 백그라운드 세션 C (문서 업데이트 중)
```

## 핵심 개념 3가지

| 개념 | 설명 |
|------|------|
| 슈퍼바이저 프로세스 | 모든 백그라운드 세션을 관리하는 데몬. 터미널과 독립적으로 실행 |
| 백그라운드 세션 | `--background` 플래그로 시작한 독립 Claude Code 프로세스 |
| Peek 패널 | Agent View에서 에이전트를 전환하지 않고 빠르게 답변하는 인라인 패널 |

## 설치 및 시작

v2.1.139 이상으로 업데이트한 뒤 바로 사용 가능하다.

```bash
# 버전 확인
claude --version

# 업데이트
npm install -g @anthropic-ai/claude-code@latest

# Agent View 실행
claude agents
```

Agent View가 보이지 않으면 환경변수를 확인한다:

```bash
# Agent View 비활성화 플래그 (설정되어 있으면 제거)
echo $CLAUDE_CODE_DISABLE_AGENT_VIEW
unset CLAUDE_CODE_DISABLE_AGENT_VIEW
```

## 기본 워크플로우

### 백그라운드 세션 시작

```bash
# 태스크와 함께 백그라운드 실행
claude --background "auth 모듈 단위 테스트 작성, 커버리지 80% 이상 목표"

# 백그라운드 + 워크트리 격리 (같은 레포에서 여러 에이전트)
claude --background --worktree "결제 API 리팩토링"

# 목표 기반 자율 실행
claude --background /goal "다음 스프린트 이슈 3개 순서대로 처리"
```

### Agent View에서 세션 관리

```bash
# Agent View 열기
claude agents

# 세션 목록 조회 (CLI 방식)
claude agents list

# 특정 세션에 메시지 전달
claude agents send <session-id> "auth.test.ts 작성 완료되면 PR 올려줘"

# 세션 종료
claude agents kill <session-id>
```

### Peek 패널 활용

Agent View에서 에이전트가 질문을 기다리는 경우(⏸ 상태), 탭 전환 없이 Peek 패널로 바로 답변할 수 있다:

1. Agent View에서 해당 세션 선택
2. `p` 키로 Peek 패널 열기
3. 답변 입력 후 Enter

## 병렬 에이전트 실전 패턴

### 패턴 1: 프론트엔드 + 백엔드 동시 개발

```bash
# 터미널 1: Agent View 모니터링
claude agents

# 새 세션 2개 띄우기 (별도 워크트리)
claude --background --worktree "백엔드 API /v2/users CRUD 구현 (TypeScript, Prisma)"
claude --background --worktree "프론트엔드 Users 페이지 구현 (Next.js App Router)"
```

Agent View에서 두 세션 상태를 동시에 모니터링하다가, 어느 쪽이 스펙 질문을 하면 Peek 패널로 즉시 답변한다.

### 패턴 2: 이슈 병렬 처리

```bash
# GitHub 이슈 번호별로 에이전트 분리
for issue in 101 102 103; do
  claude --background --worktree "GitHub 이슈 #$issue 분석하고 수정, PR 생성까지"
done

# 상태 확인
claude agents list
```

### 패턴 3: 리뷰어 에이전트

```bash
# 구현 에이전트와 리뷰 에이전트 분리
claude --background --worktree "feature/payment-refund 브랜치에 환불 로직 구현"
claude --background "feature/payment-refund 브랜치 코드 리뷰, 보안 이슈 집중 검토"
```

## 워크트리 자동 격리

Agent View의 `--worktree` 옵션은 각 에이전트에 별도 Git worktree를 자동으로 만든다. 여러 에이전트가 같은 레포를 동시에 수정해도 충돌이 없다.

```bash
# worktree.baseRef 설정 (settings.json 또는 CLAUDE.md)
# "fresh": origin/<default>에서 분기 (기본값)
# "head": 현재 로컬 HEAD에서 분기

# CLI로 설정 변경
claude config set worktree.baseRef head
```

| 설정 | 사용 시점 |
|------|---------|
| `fresh` (기본) | 커밋되지 않은 작업과 격리해야 할 때 |
| `head` | 아직 push 안 된 커밋 위에서 작업해야 할 때 |

## settings.autoMode 활용

Agent View와 함께 auto mode 규칙을 설정하면 에이전트가 더 자율적으로 동작한다:

```json
// ~/.claude/settings.json
{
  "autoMode": {
    "hard_deny": [
      "production 데이터베이스에 직접 쿼리",
      "외부 API 실제 결제 호출"
    ]
  }
}
```

`hard_deny`에 등록된 액션은 사용자 의도와 상관없이 에이전트가 무조건 거부한다. 자율 실행 중 예상치 못한 위험 작업을 사전 차단하는 데 쓴다.

## 슈퍼바이저 아키텍처 이해

```
사용자 터미널
    │
    ├── claude agents (Agent View UI)
    │
슈퍼바이저 데몬 (~/.claude/supervisor)
    ├── 인증: 인터랙티브 세션과 동일 자격증명
    ├── 네트워크: 모델 API 호출만
    └── 세션 관리:
         ├── 백그라운드 세션 A (독립 프로세스)
         ├── 백그라운드 세션 B (독립 프로세스)
         └── 백그라운드 세션 C (독립 프로세스)
```

슈퍼바이저는 추가 네트워크 연결을 만들지 않는다. 모델 API 호출 외에는 외부와 통신하지 않는다.

## 주의사항

| 상황 | 대응 |
|------|------|
| `ANTHROPIC_API_KEY`가 설정된 경우 | Remote Control, `/schedule` 등 일부 기능 비활성화됨 — 해당 기능을 쓰려면 API 키 대신 Claude.ai 로그인 사용 |
| 세션이 너무 많을 때 | `claude agents list`로 종료된 세션 정리: `claude agents kill <id>` |
| 에이전트가 같은 파일 수정 시 | `--worktree` 플래그로 격리 필수 |
| 슈퍼바이저 재시작 필요 시 | `claude agents restart-supervisor` |

## 체크리스트

- [ ] v2.1.139 이상으로 업데이트
- [ ] `claude agents`로 Agent View 진입 확인
- [ ] 첫 백그라운드 세션 시작 (`--background`)
- [ ] 슈퍼바이저 프로세스 확인 (`claude agents status`)
- [ ] 동시 수정 시 `--worktree` 플래그 적용
- [ ] `settings.autoMode.hard_deny`로 위험 작업 사전 차단
- [ ] Peek 패널로 대기 중인 에이전트에 빠르게 응답하는 루틴 확립

## 다음 단계

→ [에이전틱 워크플로우 설계 패턴](./94-agentic-workflow-design-patterns-guide.md)
→ [Git Worktree 기반 병렬 에이전트](./91-git-worktree-parallel-agents-guide.md)
→ [claude agents 디스패치 플래그](./98-claude-agents-dispatch-flags-guide.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
