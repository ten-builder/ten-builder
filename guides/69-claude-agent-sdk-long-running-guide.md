# Claude Agent SDK & 장기 실행 에이전트 실전 가이드 2026

> Claude Code SDK가 Claude Agent SDK로 확장되면서 달라진 것들 — 장시간 자율 실행, Hooks 3가지 유형, 서브에이전트 컨텍스트 격리 패턴을 현장 기준으로 정리했습니다.

## 왜 지금 Agent SDK인가

2026년 초, Anthropic이 "Claude Code SDK"를 **Claude Agent SDK**로 이름을 바꿨습니다. 단순한 리브랜딩이 아닙니다. 코딩 보조 도구에서 **프로덕션 에이전트 플랫폼**으로 포지셔닝이 바뀐 겁니다.

핵심 변화 3가지:
- **장기 실행(Long-Running) 지원** — 분, 시간, 경우에 따라 수일간 자율 작업
- **Hooks 시스템 정식화** — 명령형 제어를 CLAUDE.md 지시사항과 분리
- **Claude Managed Agents** — Anthropic 클라우드에서 에이전트 런타임 관리

이 가이드는 이 세 가지를 실제 프로젝트에 적용하는 방법에 집중합니다.

---

## Part 1: Hooks 3가지 유형

Hooks는 Claude Code의 생애주기 특정 시점에 실행을 보장하는 메커니즘입니다. CLAUDE.md에 "이렇게 해줘"라고 쓰는 것과 달리, Hooks는 **반드시 실행됩니다**.

### 1-1. Command Hooks (명령형)

가장 일반적인 유형. 셸 스크립트를 실행하고 결과를 stdin/stdout/exit code로 전달합니다.

```json
// .claude/hooks/post-code.json
{
  "event": "PostToolUse",
  "tool": "Write",
  "script": "~/.claude/hooks/format-and-lint.sh"
}
```

```bash
#!/bin/bash
# format-and-lint.sh — 파일 작성 후 자동 포맷
FILE="$CLAUDE_TOOL_ARG_PATH"
EXTENSION="${FILE##*.}"

case "$EXTENSION" in
  ts|tsx) npx prettier --write "$FILE" && npx eslint --fix "$FILE" ;;
  py)     black "$FILE" && isort "$FILE" ;;
  go)     gofmt -w "$FILE" ;;
esac

# exit 0: 계속 진행
# exit 2: Claude에게 피드백 전달 후 계속
# exit 1: 실행 중단
exit 0
```

**실전 활용:**

| 이벤트 | 활용 예시 |
|--------|----------|
| `PreToolUse(Bash)` | 위험한 명령어 차단 (`rm -rf`, `DROP TABLE`) |
| `PostToolUse(Write)` | 코드 포맷, 린트 자동 실행 |
| `Stop` | 작업 완료 후 Slack 알림, 테스트 실행 |
| `SubagentStop` | 서브에이전트 결과 검증 |

### 1-2. Prompt Hooks (LLM 판단형)

셸 없이 Claude 모델에게 예/아니오 판단을 맡깁니다. 코드 보안 검토, 요구사항 적합성 확인에 유용합니다.

```json
// .claude/hooks/security-check.json
{
  "event": "PreToolUse",
  "tool": "Bash",
  "prompt": "이 명령어가 프로덕션 데이터에 영구적인 영향을 미칠 수 있나요? 영향이 있으면 'BLOCK', 없으면 'ALLOW'로만 답하세요.",
  "model": "claude-haiku-4-5",
  "blockOn": "BLOCK"
}
```

Command Hook보다 느리지만 맥락 이해가 필요한 판단에 적합합니다. 비용을 줄이려면 Haiku 모델을 지정하세요.

### 1-3. Agent Hooks (서브에이전트 검증형)

가장 정밀한 유형. 별도의 Claude 인스턴스를 스폰해서 파일 읽기, 코드 분석, 명령 실행으로 조건을 검증합니다.

```json
// .claude/hooks/test-coverage.json
{
  "event": "Stop",
  "agent": {
    "prompt": "방금 작성된 코드에 대한 테스트가 있는지 확인하고, 커버리지가 80% 미만이면 'FAIL: 커버리지 {N}%'를 출력하세요.",
    "tools": ["Read", "Bash"],
    "blockOn": "FAIL"
  }
}
```

```
에이전트 실행 흐름:
메인 에이전트 → 코드 작성 완료
       ↓
Agent Hook 트리거
       ↓
검증 서브에이전트 (독립 컨텍스트)
  - 작성된 파일 읽기
  - 테스트 파일 확인
  - npx jest --coverage 실행
       ↓
결과: "PASS" → 메인 계속 / "FAIL" → 메인 차단
```

---

## Part 2: 서브에이전트 컨텍스트 격리 패턴

### 2-1. 왜 격리가 중요한가

서브에이전트는 **독립된 Claude 인스턴스**입니다. 각자의 컨텍스트 윈도우, 시스템 프롬프트, 도구 권한을 가집니다. 서브에이전트가 완료하면 **최종 결과만** 부모 에이전트에 돌아옵니다.

이 구조의 이점:

```
단일 에이전트 방식:
[모든 중간 단계가 컨텍스트에 쌓임] → 컨텍스트 오염, 느려짐

서브에이전트 방식:
부모: "보안 검토해줘"
  └─ 서브에이전트 A: 인증 로직 분석 → "취약점 3개 발견"
  └─ 서브에이전트 B: SQL 쿼리 분석 → "인젝션 위험 없음"
부모: 요약된 결과만 수신 → 컨텍스트 깔끔
```

### 2-2. CLAUDE.md로 서브에이전트 제어

```markdown
<!-- CLAUDE.md -->
## 서브에이전트 위임 규칙

복잡한 태스크는 서브에이전트로 분리:
- 보안 감사 → 반드시 별도 에이전트 실행
- 300줄 이상 파일 리팩토링 → 파일별 서브에이전트 분리
- 테스트 작성 → 구현 에이전트와 별도 에이전트

서브에이전트에게 전달할 것:
1. 담당 파일/범위 명확히 지정
2. 출력 형식 구체적으로 지정 (JSON, Markdown 등)
3. 성공 기준 정의
```

### 2-3. Git Worktree로 병렬 격리

여러 서브에이전트가 같은 코드베이스에서 동시에 작업할 때:

```bash
# 각 서브에이전트마다 독립 워킹트리 생성
git worktree add /tmp/agent-auth feature/auth-refactor
git worktree add /tmp/agent-api feature/api-refactor
git worktree add /tmp/agent-db feature/db-refactor

# 각 경로에서 독립적으로 서브에이전트 실행
# 완료 후 메인 브랜치로 병합
```

| 패턴 | 언제 | 장점 |
|------|------|------|
| 단순 서브에이전트 | 읽기 전용 분석 | 설정 최소 |
| Worktree 분리 | 파일 수정 병렬 작업 | 충돌 없음 |
| 브랜치 분리 | 독립 기능 개발 | 완전한 격리 |

---

## Part 3: 장기 실행 에이전트 설계

### 3-1. 상태 관리 — 파일이 메모리다

장기 실행 에이전트는 재시작 후에도 작업을 이어가야 합니다. 인메모리 상태는 사용하지 마세요.

```bash
# state.yaml — 에이전트 체크포인트
current_phase: 3
completed_files:
  - src/auth/login.ts
  - src/auth/register.ts
pending_files:
  - src/auth/oauth.ts
  - src/auth/mfa.ts
last_checkpoint: "2026-04-24T10:30:00+09:00"
error_count: 0
```

```markdown
<!-- CLAUDE.md -->
## 장기 작업 체크포인트 규칙

1. 파일 하나 완료할 때마다 state.yaml 업데이트
2. 오류 발생 시 error_count 증가, 3회 초과 시 중단
3. 재시작 시 state.yaml 읽고 pending_files부터 이어서 작업
4. 전체 완료 시 DONE.md 생성
```

### 3-2. 에이전트 감시 루프

장기 실행 에이전트가 멈추지 않고 있는지 확인하는 watchdog 패턴:

```bash
#!/bin/bash
# watchdog.sh — 에이전트 상태 모니터링

LAST_UPDATE=$(stat -f %m ~/.agent/state.yaml 2>/dev/null || echo 0)
NOW=$(date +%s)
DIFF=$((NOW - LAST_UPDATE))

if [ $DIFF -gt 1800 ]; then
  # 30분 이상 업데이트 없으면 알림
  echo "ALERT: Agent inactive for ${DIFF}s" | \
    curl -s -X POST "$SLACK_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d '{"text":"'"$( cat)"'"}'
fi
```

### 3-3. 단계별 권한 확대

장기 실행일수록 단계적으로 권한을 확대하세요. 처음부터 모든 권한을 주지 않습니다.

```
Phase 1: 읽기 전용 분석
  권한: Read, Bash(read-only)
  목표: 코드베이스 파악, 계획 작성

Phase 2: 제한적 수정
  권한: Read, Write, Bash(format-only)
  목표: 포맷팅, 린트 수정

Phase 3: 완전 실행
  권한: 모든 도구
  목표: 기능 구현, 테스트 작성
```

```json
// .claude/settings.json — 단계별 권한
{
  "phases": {
    "analyze": {
      "allow": ["Read", "Bash"],
      "deny": ["Write", "Delete"]
    },
    "implement": {
      "allow": ["Read", "Write", "Bash"],
      "deny": ["Delete", "WebSearch"]
    }
  }
}
```

---

## Part 4: Claude Managed Agents

2026년 4월 출시된 Claude Managed Agents는 에이전트 런타임 관리를 Anthropic 클라우드에 위임합니다.

### 로컬 vs Managed 비교

| 항목 | 로컬 실행 | Managed Agents |
|------|----------|---------------|
| 인프라 관리 | 직접 | Anthropic 위임 |
| 확장성 | 수동 | 자동 |
| 비용 | 서버 비용 별도 | API 사용량 기반 |
| 적합한 경우 | 사내 환경, 데이터 보안 | 외부 서비스, 빠른 프로토타입 |

### 간단한 Managed Agent 설정

```python
import anthropic

client = anthropic.Anthropic()

# Managed Agent 생성
agent = client.beta.agents.create(
    name="code-reviewer",
    model="claude-sonnet-4-6",
    instructions="""
    코드 리뷰 전문가로서 다음을 확인하세요:
    1. 보안 취약점
    2. 성능 문제
    3. 코드 품질
    
    결과는 JSON 형식으로 반환하세요.
    """,
    tools=[{"type": "code_execution"}]
)

# 태스크 실행
run = client.beta.agents.runs.create(
    agent_id=agent.id,
    messages=[{
        "role": "user",
        "content": f"다음 코드를 리뷰해주세요:\n```python\n{code}\n```"
    }]
)

# 결과 확인 (폴링)
while run.status in ["queued", "running"]:
    run = client.beta.agents.runs.retrieve(run.id)
    time.sleep(2)

print(run.result)
```

---

## 빠른 적용 체크리스트

### Hooks 도입

- [ ] `.claude/hooks/` 디렉토리 생성
- [ ] 코드 포맷 자동화 Command Hook 추가
- [ ] 위험 명령어 차단 PreToolUse Hook 추가
- [ ] 테스트 커버리지 검증 Stop Hook 추가

### 서브에이전트 적용

- [ ] CLAUDE.md에 위임 기준 명시 (파일 수, 복잡도 기준)
- [ ] 대형 작업 시 Git Worktree 활용
- [ ] 서브에이전트 출력 형식 표준화 (JSON 권장)

### 장기 실행 준비

- [ ] state.yaml 체크포인트 구조 설계
- [ ] watchdog 스크립트 설정
- [ ] 단계별 권한 정책 문서화

---

## 다음 단계

- [오케스트레이터-워커 패턴 심화](58-ai-agent-orchestrator-patterns.md)
- [Claude Code 비동기 백그라운드 운영](../claude-code/playbooks/49-async-background-agent-operations.md)
- [Claude Code Hooks 자동화 치트시트](../cheatsheets/claude-code-hooks-cheatsheet.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) — AI 코딩 인사이트 매주 목요일
