# 플레이북 47: AI 에이전트 플래닝 루프 복구 패턴

> AI 코딩 에이전트가 플래닝 단계에서 막혔을 때 자동으로 빠져나오는 4가지 복구 패턴

## 소요 시간

15-30분 (초기 설정 기준)

## 사전 준비

- Claude Code 최신 버전
- CLAUDE.md 설정 파일
- 프로젝트 루트에 쓰기 권한

## 왜 플래닝 루프가 문제인가

AI 에이전트가 복잡한 태스크를 받으면 간혹 이런 상황이 생깁니다:

- 같은 파일을 반복적으로 읽고 쓰다 멈춤
- 에러를 고치려다 다른 에러를 만들고 다시 돌아오는 루프
- 플랜을 세우다 필요한 컨텍스트를 찾지 못해 무한 탐색
- 도구 응답 대기 중 타임아웃 후 재시도를 반복

프로덕션 환경에서는 이런 상황이 비용 낭비와 지연으로 직결됩니다. 감지와 복구를 자동화하면 자리를 비울 때도 에이전트가 제대로 작동합니다.

## 복구 패턴 4가지

### 패턴 1: 타임아웃 감지 + 자동 인터럽트

에이전트가 일정 시간 이상 같은 동작을 반복하면 Hooks로 감지해 중단합니다.

**`.claude/settings.json` 설정:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/loop-detector.py"
          }
        ]
      }
    ]
  }
}
```

**`~/.claude/hooks/loop-detector.py`:**

```python
import sys
import json
import time
import os

STATE_FILE = "/tmp/claude-tool-state.json"
MAX_REPEAT = 5      # 같은 도구+인자 반복 허용 횟수
WINDOW_SEC = 120    # 감지 윈도우 (초)

def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"history": []}

def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)

data = json.load(sys.stdin)
tool = data.get("tool_name", "")
params = json.dumps(data.get("tool_input", {}), sort_keys=True)
key = f"{tool}:{params[:100]}"
now = time.time()

state = load_state()
history = [h for h in state["history"] if now - h["t"] < WINDOW_SEC]
history.append({"key": key, "t": now})
save_state({"history": history})

count = sum(1 for h in history if h["key"] == key)
if count >= MAX_REPEAT:
    print(json.dumps({
        "decision": "block",
        "reason": f"루프 감지: '{tool}' {count}회 반복. 태스크를 더 작게 나누거나 접근 방식을 바꿔보세요."
    }))
else:
    print(json.dumps({"decision": "approve"}))
```

### 패턴 2: 체크포인트 저장 + 재플래닝

긴 작업은 진행 상황을 파일로 저장해두고, 막히면 저장된 지점부터 재시작합니다.

**CLAUDE.md에 추가할 지침:**

```markdown
## 긴 태스크 처리 규칙

1. 10분 이상 걸릴 작업은 시작 전에 `.agent-checkpoint.json`에 계획을 기록한다
2. 각 단계 완료 시 체크포인트를 업데이트한다
3. 에러 발생 시 즉시 체크포인트에 상태와 에러 내용을 기록한다
4. 3회 이상 같은 에러가 반복되면 더 작은 단위로 분해해서 재시도한다
```

**체크포인트 파일 예시 (`.agent-checkpoint.json`):**

```json
{
  "task": "결제 모듈 리팩토링",
  "started_at": "2026-04-14T09:00:00",
  "steps": [
    {
      "id": 1,
      "description": "payment.ts 의존성 분석",
      "status": "completed",
      "completed_at": "2026-04-14T09:05:00"
    },
    {
      "id": 2,
      "description": "인터페이스 추출",
      "status": "in_progress",
      "started_at": "2026-04-14T09:05:00"
    },
    {
      "id": 3,
      "description": "테스트 업데이트",
      "status": "pending"
    }
  ],
  "last_error": null,
  "error_count": 0
}
```

### 패턴 3: 에러 임계값 기반 자동 전략 전환

같은 에러가 일정 횟수 반복되면 접근 방식을 바꾸도록 CLAUDE.md에 명시합니다.

**CLAUDE.md 에러 처리 규칙:**

```markdown
## 에러 복구 전략

| 에러 반복 횟수 | 행동 |
|---------------|------|
| 1-2회 | 동일 방법으로 재시도 |
| 3회 | 다른 접근 방식 시도 (예: 다른 파일부터 시작) |
| 5회 | 태스크를 더 작게 분해 |
| 7회 | 사용자에게 현황 보고하고 대기 |

에러 카운트는 `.agent-checkpoint.json`의 `error_count`에 기록한다.
```

**에러 카운트 추적 스크립트 (`scripts/track-errors.sh`):**

```bash
#!/bin/bash
# 에러 발생 시 호출: ./scripts/track-errors.sh "에러 메시지"

CHECKPOINT=".agent-checkpoint.json"
ERROR_MSG="$1"

if [ ! -f "$CHECKPOINT" ]; then
  echo '{"error_count": 0, "last_error": null}' > "$CHECKPOINT"
fi

COUNT=$(python3 -c "
import json
with open('$CHECKPOINT') as f:
    d = json.load(f)
count = d.get('error_count', 0) + 1
d['error_count'] = count
d['last_error'] = '$ERROR_MSG'
with open('$CHECKPOINT', 'w') as f:
    json.dump(d, f, indent=2)
print(count)
")

echo "에러 카운트: $COUNT"
if [ "$COUNT" -ge 7 ]; then
  echo "⚠️  에러 임계값 초과 — 사용자 개입 필요"
  exit 1
fi
```

### 패턴 4: 멀티 에이전트 페일오버

주 에이전트가 막히면 별도 Git Worktree에서 다른 에이전트가 같은 태스크를 이어받습니다.

**Worktree 기반 페일오버 설정:**

```bash
# 페일오버 Worktree 준비
git worktree add ../project-failover main
cd ../project-failover

# 체크포인트 공유 (심링크)
ln -s ../project/.agent-checkpoint.json .agent-checkpoint.json
```

**페일오버 에이전트용 CLAUDE.md 섹션:**

```markdown
## 페일오버 모드

이 Worktree는 주 에이전트 실패 시 이어받기용입니다.

시작 전 반드시 `.agent-checkpoint.json`을 읽어 현재 상태를 파악하세요.
완료된 단계는 건너뛰고 `in_progress` 또는 `pending` 단계부터 시작하세요.
주 에이전트와 동일한 파일을 동시에 수정하지 마세요.
```

## 실전 통합 예시

복잡한 리팩토링 작업에 위 패턴들을 한 번에 적용하는 방법입니다.

### 1. 작업 시작

```bash
# 체크포인트 초기화
cat > .agent-checkpoint.json << 'EOF'
{
  "task": "auth 모듈 리팩토링",
  "started_at": "2026-04-14T09:00:00",
  "steps": [
    {"id": 1, "description": "현재 구조 분석", "status": "pending"},
    {"id": 2, "description": "인터페이스 추출", "status": "pending"},
    {"id": 3, "description": "구현체 분리", "status": "pending"},
    {"id": 4, "description": "테스트 수정", "status": "pending"}
  ],
  "error_count": 0,
  "last_error": null
}
EOF

# 루프 감지 상태 초기화
rm -f /tmp/claude-tool-state.json

echo "작업 준비 완료"
```

### 2. 에이전트에게 전달할 컨텍스트

```
.agent-checkpoint.json을 읽고 auth 모듈 리팩토링을 진행해주세요.

규칙:
- 각 단계 완료 시 체크포인트 업데이트
- 같은 에러가 3회 이상이면 접근 방식 변경
- 7회 이상이면 현황 보고 후 대기
```

## 체크리스트

- [ ] `.claude/settings.json`에 루프 감지 Hook 추가
- [ ] `~/.claude/hooks/loop-detector.py` 생성 및 실행 권한 부여
- [ ] CLAUDE.md에 에러 복구 전략 추가
- [ ] 긴 작업 시작 전 `.agent-checkpoint.json` 초기화
- [ ] Git Worktree 페일오버 환경 준비 (선택)

## 어떤 패턴을 먼저 적용해야 하나

| 상황 | 권장 패턴 |
|------|----------|
| 에이전트가 자주 같은 도구를 반복 | 패턴 1 (루프 감지) |
| 장시간 실행 작업이 많음 | 패턴 2 (체크포인트) |
| 에러 유형이 다양함 | 패턴 3 (전략 전환) |
| 팀 환경, 중단 비용이 큼 | 패턴 4 (페일오버) |

단독으로 써도 효과가 있지만, 패턴 1 + 패턴 2 조합이 일반적인 시작점으로 좋습니다.

## 다음 단계

→ [플레이북 48: AI 에이전트 워크플로우 관찰 & 디버깅](./48-ai-agent-observability.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
