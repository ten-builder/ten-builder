# AI 에이전트 비상 정지 및 복구 치트시트 — 자율 에이전트 통제 패턴

> 루프에 갇히거나, 예산을 초과하거나, 의도치 않은 결과를 낼 때 즉시 개입하는 패턴 — 한 페이지 요약

## Kill Switch 3계층 구조

| 계층 | 위치 | 정지 방식 |
|------|------|----------|
| L1 — 코드 내부 | 에이전트 실행 루프 | 조건 검사 → `raise StopAgent` |
| L2 — API 게이트웨이 | LLM 호출 미들웨어 | 세션 토큰 무효화 |
| L3 — 인프라 | 프로세스/컨테이너 | `kill -9` / `kubectl delete pod` |

> **원칙:** Kill Switch는 LLM 프롬프트 바깥에 위치해야 한다. 시스템 프롬프트는 보안 경계가 아니다.

## KILLSWITCH.md 파일 구조

레포 루트에 `KILLSWITCH.md`를 배치해 에이전트 종료 조건을 명시적으로 선언합니다.

```markdown
# KILLSWITCH.md

## TRIGGERS
- cost_usd_per_run: 5.00
- consecutive_errors: 3
- wall_clock_minutes: 30
- file_writes_per_run: 50

## FORBIDDEN
- files: [".env", "*.pem", "secrets/"]
- apis: ["production.api.example.com"]
- commands: ["rm -rf", "DROP TABLE", "git push --force"]

## ON_TRIGGER
- action: stop
- log: true
- notify: webhook
```

> `KILLSWITCH.md`는 `AGENTS.md`, `CLAUDE.md`와 같은 디렉토리에 배치.

## 비상 정지 조건 체크리스트

에이전트 실행 전 다음 조건을 설정했는지 확인합니다.

- [ ] **비용 한도** — 1회 실행당 최대 허용 토큰/비용 설정
- [ ] **에러 한계** — 연속 N회 실패 시 자동 정지
- [ ] **타임아웃** — 단계별 최대 실행 시간 (예: 30분)
- [ ] **파일 쓰기 제한** — 1회 실행 중 최대 파일 변경 수
- [ ] **금지 경로** — 건드리면 안 되는 파일/디렉토리 목록
- [ ] **롤백 포인트** — 정지 전 git commit 체크포인트

## 즉시 사용하는 정지 패턴

### Claude Code — 실행 중 강제 종료

```bash
# 실행 중인 에이전트 프로세스 찾기
ps aux | grep 'claude'

# SIGTERM 전송 (graceful)
kill -TERM <PID>

# 응답 없으면 강제 종료
kill -9 <PID>
```

### Codex CLI — budget 플래그 활용

```bash
# 실행 전 비용 한도 설정
codex --max-tokens 50000 --timeout 600 "작업 설명"

# 실행 중 Ctrl+C로 즉시 중단 후 상태 확인
```

### Python 에이전트 — 조건부 종료 구현

```python
class AgentGuard:
    def __init__(self, max_cost_usd=5.0, max_errors=3):
        self.cost = 0.0
        self.errors = 0
        self.max_cost = max_cost_usd
        self.max_errors = max_errors

    def check(self):
        if self.cost >= self.max_cost:
            raise StopIteration(f"비용 한도 초과: ${self.cost:.2f}")
        if self.errors >= self.max_errors:
            raise StopIteration(f"연속 에러 {self.errors}회")

# 에이전트 루프에 삽입
guard = AgentGuard()
for step in agent_steps:
    guard.check()        # 매 단계마다 검사
    result = step.run()
    if result.error:
        guard.errors += 1
```

## 롤백 절차

### 1단계 — 상태 확인

```bash
# 에이전트가 변경한 파일 목록
git diff --name-only HEAD

# 변경 규모 확인
git diff --stat HEAD
```

### 2단계 — 선택적 롤백

```bash
# 특정 파일만 복구
git checkout HEAD -- path/to/file.ts

# 마지막 커밋 이전 상태로 전체 복구
git reset --hard HEAD~1

# 작업 브랜치 전체 삭제
git checkout main
git branch -D feature/agent-work
```

### 3단계 — 사후 분석

| 항목 | 확인 내용 |
|------|----------|
| 에이전트 로그 | 어느 단계에서 비정상 동작이 시작됐는지 |
| 변경된 파일 | 의도하지 않은 파일이 수정됐는지 |
| 외부 호출 | API, DB, 파일시스템에 부작용이 있는지 |
| 비용 기록 | 예산 초과 원인 (루프? 대형 컨텍스트?) |

## 알림 설정 패턴

### GitHub Actions 기반 에이전트 — 비상 정지 알림

```yaml
# .github/workflows/agent-guard.yml
jobs:
  agent-run:
    steps:
      - name: Run Agent
        id: agent
        run: |
          timeout 1800 python agent.py || echo "TIMEOUT=true" >> $GITHUB_OUTPUT

      - name: Emergency Notify
        if: failure() || steps.agent.outputs.TIMEOUT == 'true'
        uses: slackapi/slack-github-action@v2
        with:
          payload: |
            {"text": "AI 에이전트 비상 정지 — ${{ github.workflow }}"}
```

### Discord Webhook 즉시 알림

```python
import requests

def emergency_stop(reason: str, context: dict):
    webhook_url = os.environ["DISCORD_WEBHOOK"]
    requests.post(webhook_url, json={
        "content": f"🔴 에이전트 비상 정지\n사유: {reason}\n"
                   f"실행 비용: ${context.get('cost', 0):.2f}\n"
                   f"마지막 액션: {context.get('last_action', 'unknown')}"
    })
    sys.exit(1)
```

## 자율 루프 탈출 조건 설계

루프에 갇힌 에이전트는 같은 오류를 반복합니다. 탈출 조건을 반드시 명시합니다.

```python
MAX_RETRIES = 3
SEEN_ERRORS = set()

for attempt in range(MAX_RETRIES):
    result = agent.run(task)
    
    if result.success:
        break
    
    error_fingerprint = hash(result.error_message)
    if error_fingerprint in SEEN_ERRORS:
        # 동일 에러 반복 → 루프 탈출
        emergency_stop("동일 에러 반복 감지", {"error": result.error_message})
    
    SEEN_ERRORS.add(error_fingerprint)
```

| 루프 유형 | 감지 방법 | 탈출 조건 |
|----------|----------|----------|
| 동일 에러 반복 | 에러 해시 집합 | 중복 감지 즉시 정지 |
| 무한 재시도 | 시도 카운터 | N회 초과 정지 |
| 비용 폭증 | 누적 토큰 추적 | 한도 초과 정지 |
| 타임아웃 | wall-clock 타이머 | N분 경과 정지 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
