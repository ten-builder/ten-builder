# AI 에이전트 프로덕션 배포 워크플로우

> AI 코딩 에이전트를 실제 서비스에 배포하고 운영하는 전체 흐름 — 스케줄링, 비용 제어, 장애 대응까지

## 개요

개발 환경에서 잘 돌아가던 AI 에이전트가 프로덕션에서 예상치 못한 방식으로 실패하는 경우가 많아요. 무한 루프로 API 비용을 폭발시키거나, 조용히 잘못된 결과를 내놓거나, 외부 서비스 장애에 속절없이 멈추거나.

핵심 원칙은 하나예요: **에이전트는 "실패해도 괜찮은 구조"에서만 자율성을 가져야 한다.** 이 워크플로우는 에이전트가 프로덕션에서 안정적으로 동작할 수 있도록 가드레일, 모니터링, 비용 제어, 장애 대응을 단계별로 설계해요.

## 사전 준비

- AI 에이전트 코드 (Claude Code, Codex, 또는 자체 구현)
- 클라우드 인프라 (AWS/GCP/Azure 또는 VPS)
- Docker / 컨테이너 환경
- 알림 수신 채널 (Slack, Discord, 이메일 중 하나 이상)

## 설정

### Step 1: 에이전트 실행 환경 격리

프로덕션 에이전트는 반드시 격리된 환경에서 실행해야 해요. 파일 시스템, 네트워크, 실행 시간을 제한하지 않으면 단순한 버그가 인프라 전체에 영향을 줄 수 있어요.

```dockerfile
# Dockerfile.agent
FROM python:3.12-slim

# 읽기 전용 파일시스템 준비
WORKDIR /workspace
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 네트워크 접근 허용 목록 (allowlist)만 열어둠
ENV AGENT_ALLOWED_HOSTS="api.openai.com,api.anthropic.com,api.github.com"

# 실행 시간 제한 (환경변수로 조정 가능)
ENV AGENT_TIMEOUT_SECONDS=300

COPY agent/ ./agent/
CMD ["python", "-m", "agent.main"]
```

```yaml
# docker-compose.agent.yml
services:
  agent:
    build:
      context: .
      dockerfile: Dockerfile.agent
    read_only: true
    tmpfs:
      - /tmp:size=100m
    mem_limit: 512m
    cpus: 0.5
    restart: on-failure:3
    environment:
      - AGENT_TIMEOUT_SECONDS=300
      - AGENT_MAX_TOKENS_PER_RUN=50000
```

### Step 2: 비용 가드레일 설정

토큰 소비를 제어하지 않으면 루프 버그 하나로 수십만 원을 쓸 수 있어요. 3단계 제한을 걸어요:

```python
# agent/cost_guard.py
import time
from dataclasses import dataclass, field

@dataclass
class CostGuard:
    max_tokens_per_run: int = 50_000
    max_tokens_per_day: int = 500_000
    soft_limit_ratio: float = 0.75  # 75%에서 경고

    _tokens_used: int = field(default=0, init=False)
    _run_start: float = field(default_factory=time.time, init=False)

    def check(self, tokens_to_use: int) -> None:
        """토큰 소비 전 호출. 한도 초과 시 예외 발생."""
        projected = self._tokens_used + tokens_to_use

        # 소프트 리밋: 경고 알림
        if projected >= self.max_tokens_per_run * self.soft_limit_ratio:
            self._notify_soft_limit(projected)

        # 하드 리밋: 실행 중단
        if projected > self.max_tokens_per_run:
            raise CostLimitExceeded(
                f"토큰 한도 초과: {projected} > {self.max_tokens_per_run}"
            )

        self._tokens_used += tokens_to_use

    def _notify_soft_limit(self, projected: int) -> None:
        pct = int(projected / self.max_tokens_per_run * 100)
        print(f"[WARN] 토큰 사용량 {pct}% 도달 ({projected:,} / {self.max_tokens_per_run:,})")

class CostLimitExceeded(Exception):
    pass
```

### Step 3: 스케줄러 설정 (cron 기반)

에이전트를 주기적으로 실행할 때는 단순 cron보다 **상태 추적이 가능한 스케줄러**를 사용하세요. 이전 실행이 아직 진행 중인데 새 실행이 겹치는 상황(중복 실행)을 막아야 해요.

```bash
# scripts/run-agent.sh
#!/bin/bash
set -euo pipefail

LOCK_FILE="/tmp/agent-production.lock"
STATE_FILE="/var/agent/state.json"
LOG_FILE="/var/log/agent/$(date +%Y-%m-%d).log"

# 중복 실행 방지
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
  if [ $LOCK_AGE -lt 600 ]; then  # 10분 이내 실행 중이면 스킵
    echo "[SKIP] 이전 실행이 진행 중 (${LOCK_AGE}초 경과)"
    exit 0
  fi
  echo "[WARN] 오래된 락 파일 감지, 강제 해제"
fi

# 락 파일 생성
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# 에이전트 실행
echo "[START] $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG_FILE"
docker run --rm \
  --env-file /etc/agent/secrets.env \
  -v "$STATE_FILE:/workspace/state.json" \
  agent:latest 2>> "$LOG_FILE"

echo "[DONE] $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG_FILE"
```

```cron
# /etc/cron.d/ai-agent
# 매시 :03분 실행, 타임아웃 5분 적용
3 * * * * agent-user timeout 300 /scripts/run-agent.sh >> /var/log/agent/cron.log 2>&1
```

### Step 4: 모니터링 파이프라인

에이전트가 "조용히 실패"하는 경우를 잡으려면 결과 검증 단계가 필요해요.

```python
# agent/monitor.py
import json
import requests
from datetime import datetime, timezone
from pathlib import Path

class AgentMonitor:
    def __init__(self, webhook_url: str, state_path: str):
        self.webhook_url = webhook_url
        self.state = self._load_state(state_path)

    def record_run(self, success: bool, metrics: dict) -> None:
        """실행 결과 기록 및 이상 감지"""
        run = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "success": success,
            **metrics
        }

        # 연속 실패 감지
        self.state["consecutive_errors"] = (
            0 if success else self.state.get("consecutive_errors", 0) + 1
        )

        if self.state["consecutive_errors"] >= 3:
            self._alert(f"에이전트 연속 실패 {self.state['consecutive_errors']}회 — 수동 점검 필요")

        # 비용 이상 감지 (전날 평균의 3배 초과 시 경고)
        avg_tokens = self.state.get("avg_tokens_per_run", 10000)
        if metrics.get("tokens_used", 0) > avg_tokens * 3:
            self._alert(f"토큰 사용량 이상: {metrics['tokens_used']:,} (평균의 {metrics['tokens_used']//avg_tokens}배)")

        self._update_state(run)

    def _alert(self, message: str) -> None:
        requests.post(self.webhook_url, json={"content": f"🔴 AI 에이전트 경보\n{message}"})

    def _load_state(self, path: str) -> dict:
        p = Path(path)
        return json.loads(p.read_text()) if p.exists() else {}

    def _update_state(self, run: dict) -> None:
        # 이동 평균 업데이트
        prev_avg = self.state.get("avg_tokens_per_run", run.get("tokens_used", 0))
        self.state["avg_tokens_per_run"] = int(prev_avg * 0.8 + run.get("tokens_used", 0) * 0.2)
        self.state["last_run"] = run["timestamp"]
        # state 파일 저장 생략 (실제 구현에서 추가)
```

## 사용 방법

### 배포 체크리스트

새 에이전트를 프로덕션에 올리기 전에 확인하세요:

| 항목 | 확인 방법 |
|------|----------|
| 격리 환경 구성 | `docker run --rm agent:latest echo "sandbox OK"` |
| 비용 가드레일 작동 | 단위 테스트에서 `CostLimitExceeded` 발생 확인 |
| 중복 실행 방지 | 스크립트 두 번 동시 실행 후 두 번째가 스킵되는지 확인 |
| 장애 알림 설정 | 의도적으로 실패 유도 후 알림 수신 확인 |
| 롤백 절차 | `git revert` 또는 이전 Docker 이미지로 복구 가능한지 확인 |

### 장애 대응 절차

```bash
# 1. 에이전트 즉시 중단
docker stop $(docker ps -q --filter "ancestor=agent:latest")
rm -f /tmp/agent-production.lock

# 2. 최근 로그 확인
tail -100 /var/log/agent/$(date +%Y-%m-%d).log

# 3. 상태 파일 확인
cat /var/agent/state.json | python3 -m json.tool

# 4. 원인 파악 후 수동 실행 (--dry-run 모드)
docker run --rm -e DRY_RUN=true agent:latest
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `AGENT_TIMEOUT_SECONDS` | 300 | 실행당 최대 시간 (초) |
| `AGENT_MAX_TOKENS_PER_RUN` | 50,000 | 실행당 토큰 한도 |
| `AGENT_MAX_TOKENS_PER_DAY` | 500,000 | 일일 토큰 한도 |
| `AGENT_SOFT_LIMIT_RATIO` | 0.75 | 경고 발생 임계값 (비율) |
| `AGENT_MAX_CONSECUTIVE_ERRORS` | 3 | 자동 정지 연속 실패 횟수 |

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| 에이전트가 중간에 멈춤 | 타임아웃 초과 | `AGENT_TIMEOUT_SECONDS` 값 조정 |
| 중복 실행 발생 | 락 파일 미해제 | `rm -f /tmp/agent-production.lock` |
| 비용 급증 | 루프 버그 또는 한도 미설정 | `CostGuard` 설정 확인 |
| 알림이 안 옴 | Webhook URL 만료 | 알림 채널 연결 상태 확인 |
| 에이전트가 스킵만 함 | 이전 실행 지연 | 이전 프로세스 종료 후 재시작 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
