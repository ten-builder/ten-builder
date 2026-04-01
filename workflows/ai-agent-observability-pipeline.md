# AI 에이전트 옵저버빌리티 파이프라인 워크플로우

> AI 코딩 에이전트가 어떻게 동작하는지 모르면 개선할 수 없어요. 세션 로그, 토큰 사용량, 에러율을 체계적으로 수집하고 시각화하는 파이프라인을 구축해 봐요.

## 개요

AI 코딩 에이전트를 팀에서 사용하다 보면 이런 질문이 생겨요:

- 에이전트가 작업 하나에 토큰을 얼마나 쓰는지?
- 어떤 종류의 작업에서 실패율이 높은지?
- 팀 전체의 월간 AI 비용이 얼마인지?

이 워크플로우는 세션 단위 로그 수집부터 대시보드 시각화까지의 파이프라인을 다뤄요.

## 사전 준비

- AI 코딩 에이전트 (Claude Code, Cursor, Codex CLI 등)
- 로그 저장소 (SQLite, PostgreSQL, 또는 S3)
- 시각화 도구 (Grafana, Metabase, 또는 간단한 웹 대시보드)
- CI 환경 (GitHub Actions 권장)

## 설정

### Step 1: 세션 로그 수집기 구성

AI 에이전트의 세션 데이터를 구조화된 형태로 캡처하는 래퍼 스크립트를 만들어요.

```bash
#!/bin/bash
# ai-session-logger.sh — 에이전트 실행을 감싸서 메트릭을 수집

SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_DIR="${AI_LOG_DIR:-$HOME/.ai-logs}"
mkdir -p "$LOG_DIR"

# 에이전트 실행 + 출력 캡처
"$@" 2>&1 | tee "$LOG_DIR/$SESSION_ID.log"
EXIT_CODE=${PIPESTATUS[0]}

END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 메트릭 JSON 생성
cat > "$LOG_DIR/$SESSION_ID.json" << EOF
{
  "session_id": "$SESSION_ID",
  "command": "$*",
  "start_time": "$START_TIME",
  "end_time": "$END_TIME",
  "exit_code": $EXIT_CODE,
  "log_file": "$SESSION_ID.log",
  "log_size_bytes": $(wc -c < "$LOG_DIR/$SESSION_ID.log")
}
EOF

echo "[logger] Session $SESSION_ID logged (exit=$EXIT_CODE)"
```

### Step 2: 토큰 사용량 파서

Claude Code와 같은 도구는 세션 종료 시 토큰 사용량을 출력해요. 이걸 파싱해서 구조화해요.

```python
# token_parser.py — 세션 로그에서 토큰 메트릭 추출
import json
import re
import sys
from pathlib import Path

def parse_session_log(log_path: str) -> dict:
    """세션 로그에서 토큰 사용량 패턴을 추출"""
    text = Path(log_path).read_text()
    metrics = {
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_read_tokens": 0,
        "total_cost_usd": 0.0,
    }

    # Claude Code 패턴: "Total tokens: 12,345 input / 6,789 output"
    token_match = re.search(
        r"(\d[\d,]*)\s*input\s*/\s*(\d[\d,]*)\s*output", text
    )
    if token_match:
        metrics["input_tokens"] = int(token_match.group(1).replace(",", ""))
        metrics["output_tokens"] = int(token_match.group(2).replace(",", ""))

    # 비용 패턴: "Cost: $0.42"
    cost_match = re.search(r"Cost:\s*\$?([\d.]+)", text)
    if cost_match:
        metrics["total_cost_usd"] = float(cost_match.group(1))

    # 캐시 패턴
    cache_match = re.search(r"cache.*?(\d[\d,]*)", text, re.IGNORECASE)
    if cache_match:
        metrics["cache_read_tokens"] = int(cache_match.group(1).replace(",", ""))

    return metrics


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python token_parser.py <log_file>")
        sys.exit(1)
    result = parse_session_log(sys.argv[1])
    print(json.dumps(result, indent=2))
```

### Step 3: 메트릭 저장소 스키마

```sql
-- ai_metrics.sql — SQLite/PostgreSQL 호환
CREATE TABLE IF NOT EXISTS sessions (
    session_id    TEXT PRIMARY KEY,
    agent_type    TEXT NOT NULL,        -- claude-code, cursor, codex
    task_type     TEXT,                 -- review, generate, refactor, debug
    start_time    TIMESTAMP NOT NULL,
    end_time      TIMESTAMP,
    exit_code     INTEGER,
    input_tokens  INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    cache_tokens  INTEGER DEFAULT 0,
    cost_usd      REAL DEFAULT 0.0,
    user_id       TEXT,
    repo          TEXT,
    branch        TEXT
);

CREATE TABLE IF NOT EXISTS errors (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id    TEXT REFERENCES sessions(session_id),
    error_type    TEXT NOT NULL,        -- timeout, rate_limit, context_overflow
    error_message TEXT,
    occurred_at   TIMESTAMP NOT NULL
);

-- 일별 비용 집계 뷰
CREATE VIEW IF NOT EXISTS daily_cost AS
SELECT
    DATE(start_time) AS day,
    agent_type,
    COUNT(*) AS session_count,
    SUM(input_tokens + output_tokens) AS total_tokens,
    SUM(cost_usd) AS total_cost
FROM sessions
GROUP BY DATE(start_time), agent_type
ORDER BY day DESC;
```

## 사용 방법

### 수집 파이프라인 실행

```bash
# 1. 세션 래퍼로 에이전트 실행
./ai-session-logger.sh claude -p "이 함수를 리팩토링해줘"

# 2. 로그 파싱 + DB 적재 (크론으로 5분마다)
python ingest_logs.py --log-dir ~/.ai-logs --db ai_metrics.db

# 3. 에러 패턴 분석
python analyze_errors.py --db ai_metrics.db --since 7d
```

### CI 파이프라인 연동

```yaml
# .github/workflows/ai-metrics.yml
name: AI Agent Metrics Collection
on:
  workflow_run:
    workflows: ["AI Code Review", "AI Test Generation"]
    types: [completed]

jobs:
  collect-metrics:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download AI session artifacts
        uses: actions/download-artifact@v4
        with:
          name: ai-session-logs
          path: ./logs

      - name: Parse and ingest metrics
        run: |
          python scripts/token_parser.py ./logs/*.log > metrics.json
          python scripts/ingest_metrics.py \
            --input metrics.json \
            --db ${{ secrets.METRICS_DB_URL }}

      - name: Check budget threshold
        run: |
          DAILY_COST=$(python scripts/check_budget.py \
            --db ${{ secrets.METRICS_DB_URL }} \
            --period daily)
          if (( $(echo "$DAILY_COST > 50.00" | bc -l) )); then
            echo "::warning::Daily AI cost exceeded $50: $DAILY_COST"
          fi
```

### Grafana 대시보드 패널 설정

```json
{
  "panels": [
    {
      "title": "일별 토큰 사용량",
      "type": "timeseries",
      "targets": [{
        "rawSql": "SELECT day, total_tokens FROM daily_cost WHERE day > DATE('now', '-30 days')"
      }]
    },
    {
      "title": "에이전트별 비용 비율",
      "type": "piechart",
      "targets": [{
        "rawSql": "SELECT agent_type, SUM(cost_usd) FROM sessions WHERE start_time > DATE('now', '-30 days') GROUP BY agent_type"
      }]
    },
    {
      "title": "에러율 트렌드",
      "type": "stat",
      "targets": [{
        "rawSql": "SELECT ROUND(COUNT(e.id) * 100.0 / COUNT(DISTINCT s.session_id), 1) as error_pct FROM sessions s LEFT JOIN errors e ON s.session_id = e.session_id WHERE s.start_time > DATE('now', '-7 days')"
      }]
    }
  ]
}
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `AI_LOG_DIR` | `~/.ai-logs` | 세션 로그 저장 경로 |
| 수집 주기 | 5분 | 크론 기반 DB 적재 간격 |
| 보존 기간 | 90일 | 로그 파일 자동 삭제 기준 |
| 비용 알림 임계값 | $50/일 | 초과 시 Slack/이메일 알림 |
| 에러율 알림 | 10% | 세션 에러율이 이 값 초과 시 알림 |

## 수집 가능한 메트릭 목록

| 메트릭 | 소스 | 활용 |
|--------|------|------|
| 입출력 토큰 수 | 세션 로그 파싱 | 비용 추적, 모델 라우팅 최적화 |
| 세션 소요 시간 | 래퍼 스크립트 | 작업 유형별 효율 분석 |
| 에러 유형 분류 | 로그 패턴 매칭 | 반복 실패 패턴 식별 |
| 캐시 히트율 | 토큰 파서 | 프롬프트 캐싱 효과 측정 |
| 코드 수용률 | Git diff 분석 | AI 생성 코드의 실제 사용 비율 |
| 수정 횟수 | Git history | AI 출력물의 수정 빈도 추적 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 로그가 비어있음 | 래퍼 스크립트의 `tee` 경로와 권한 확인 |
| 토큰 파싱 실패 | 에이전트 출력 포맷이 변경됐는지 정규식 패턴 업데이트 |
| DB 적재 지연 | 크론 주기 확인, 대용량 로그는 배치 INSERT 사용 |
| Grafana 연결 오류 | 데이터소스 URL과 인증 정보 재확인 |
| 비용 집계 불일치 | 타임존 설정 확인 (UTC vs 로컬) |

## 주요 도구 비교

| 도구 | 특징 | 적합한 팀 |
|------|------|----------|
| Langfuse | 오픈소스, 셀프호스팅 가능, 트레이싱 | 데이터 주권이 중요한 팀 |
| Braintrust | 평가 중심, 프롬프트 실험 추적 | 프롬프트 최적화 중인 팀 |
| Helicone | 프록시 기반, 설치 간편 | 빠르게 시작하고 싶은 팀 |
| 커스텀 파이프라인 | 완전한 제어, 특수 요구사항 대응 | 기존 모니터링 스택이 있는 팀 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
