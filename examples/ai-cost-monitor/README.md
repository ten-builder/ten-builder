# AI 코딩 비용 모니터링 대시보드

> Claude Code, Cursor, Copilot 사용량을 한 곳에서 추적하고 비용을 분석하는 CLI 대시보드

## 이 예제에서 배울 수 있는 것

- 여러 AI 코딩 도구의 사용량 데이터를 수집하고 통합하는 방법
- Rich 라이브러리로 터미널 대시보드를 구성하는 패턴
- ccusage 등 기존 도구와 연동하여 토큰 사용량을 추적하는 워크플로우
- 일별/주별 비용 트렌드를 시각화하고 예산 초과 알림을 설정하는 구조

## 프로젝트 구조

```
ai-cost-monitor/
├── CLAUDE.md              # 프로젝트 컨텍스트
├── src/
│   └── costmon/
│       ├── __init__.py
│       ├── main.py        # CLI 엔트리포인트
│       ├── collectors/
│       │   ├── __init__.py
│       │   ├── claude.py  # Claude Code 사용량 수집
│       │   ├── cursor.py  # Cursor 사용량 수집
│       │   └── copilot.py # Copilot 사용량 수집
│       ├── models.py      # 데이터 모델 (Pydantic)
│       ├── storage.py     # SQLite 저장소
│       ├── dashboard.py   # Rich 대시보드 렌더링
│       └── alerts.py      # 예산 알림 로직
├── tests/
│   ├── test_collectors.py
│   ├── test_storage.py
│   └── test_alerts.py
├── pyproject.toml
└── README.md
```

## 시작하기

### Step 1: 프로젝트 초기화

```bash
mkdir costmon && cd costmon
python -m venv .venv && source .venv/bin/activate
pip install typer rich pydantic sqlite-utils httpx
```

AI 코딩 도구에 프로젝트 컨텍스트를 제공하세요:

```bash
cat > CLAUDE.md << 'EOF'
# costmon - AI 코딩 비용 모니터링 CLI

## 기술 스택
- Python 3.12+, Typer (CLI), Rich (터미널 UI)
- SQLite (로컬 저장), Pydantic (데이터 모델)
- httpx (API 호출)

## 아키텍처
- collectors/: 도구별 사용량 수집기 (플러그인 패턴)
- storage.py: SQLite로 일별 사용량 기록
- dashboard.py: Rich Live 대시보드
- alerts.py: 예산 임계값 초과 시 알림

## 규칙
- 수집기는 CollectorBase를 상속
- 모든 금액은 USD 센트 단위로 내부 처리
- 날짜는 항상 UTC 기준
EOF
```

### Step 2: 데이터 모델 정의

```python
# src/costmon/models.py
from pydantic import BaseModel
from datetime import date
from enum import Enum

class ToolName(str, Enum):
    CLAUDE_CODE = "claude-code"
    CURSOR = "cursor"
    COPILOT = "copilot"

class UsageRecord(BaseModel):
    """하루 단위 사용량 레코드"""
    tool: ToolName
    date: date
    input_tokens: int = 0
    output_tokens: int = 0
    requests: int = 0
    cost_cents: int = 0  # USD 센트 단위

class DailySummary(BaseModel):
    """일별 전체 도구 요약"""
    date: date
    total_cost_cents: int
    breakdown: dict[ToolName, int]  # 도구별 비용
    top_tool: ToolName

class BudgetAlert(BaseModel):
    """예산 초과 알림"""
    period: str  # "daily" | "weekly" | "monthly"
    budget_cents: int
    actual_cents: int
    exceeded_by_cents: int
```

### Step 3: 수집기 베이스 클래스

```python
# src/costmon/collectors/__init__.py
from abc import ABC, abstractmethod
from costmon.models import UsageRecord

class CollectorBase(ABC):
    """도구별 사용량 수집기 인터페이스"""

    @abstractmethod
    def collect(self, target_date: date) -> UsageRecord | None:
        """지정 날짜의 사용량을 수집하여 반환"""
        ...

    @abstractmethod
    def is_available(self) -> bool:
        """해당 도구가 설치/설정되어 있는지 확인"""
        ...
```

### Step 4: Claude Code 수집기

ccusage 도구나 로컬 로그를 파싱하여 토큰 사용량을 가져옵니다:

```python
# src/costmon/collectors/claude.py
import subprocess
import json
from datetime import date
from pathlib import Path

from costmon.collectors import CollectorBase
from costmon.models import UsageRecord, ToolName

# 모델별 토큰 단가 (USD 센트 / 1K 토큰)
PRICING = {
    "claude-sonnet-4-20250514": {"input": 0.3, "output": 1.5},
    "claude-opus-4-20250514": {"input": 1.5, "output": 7.5},
    "claude-haiku-3.5": {"input": 0.08, "output": 0.4},
}
DEFAULT_MODEL = "claude-sonnet-4-20250514"

class ClaudeCollector(CollectorBase):
    def __init__(self):
        self.sessions_dir = Path.home() / ".claude" / "projects"

    def is_available(self) -> bool:
        return self.sessions_dir.exists()

    def collect(self, target_date: date) -> UsageRecord | None:
        if not self.is_available():
            return None

        total_input = 0
        total_output = 0
        total_requests = 0

        # 세션 JSONL 파일에서 해당 날짜 사용량 집계
        for jsonl_file in self.sessions_dir.rglob("*.jsonl"):
            stats = self._parse_session(jsonl_file, target_date)
            total_input += stats["input"]
            total_output += stats["output"]
            total_requests += stats["requests"]

        cost = self._calculate_cost(total_input, total_output)

        return UsageRecord(
            tool=ToolName.CLAUDE_CODE,
            date=target_date,
            input_tokens=total_input,
            output_tokens=total_output,
            requests=total_requests,
            cost_cents=cost,
        )

    def _parse_session(
        self, path: Path, target_date: date
    ) -> dict:
        """JSONL 세션 파일에서 특정 날짜 토큰 사용량 추출"""
        result = {"input": 0, "output": 0, "requests": 0}
        try:
            with open(path) as f:
                for line in f:
                    entry = json.loads(line)
                    ts = entry.get("timestamp", "")
                    if not ts.startswith(str(target_date)):
                        continue
                    usage = entry.get("usage", {})
                    result["input"] += usage.get(
                        "input_tokens", 0
                    )
                    result["output"] += usage.get(
                        "output_tokens", 0
                    )
                    result["requests"] += 1
        except (json.JSONDecodeError, OSError):
            pass
        return result

    def _calculate_cost(
        self, input_tokens: int, output_tokens: int
    ) -> int:
        """토큰 수를 기반으로 비용(센트) 계산"""
        pricing = PRICING.get(
            DEFAULT_MODEL,
            PRICING["claude-sonnet-4-20250514"],
        )
        cost = (
            input_tokens / 1000 * pricing["input"]
            + output_tokens / 1000 * pricing["output"]
        )
        return round(cost)
```

### Step 5: SQLite 저장소

```python
# src/costmon/storage.py
import sqlite3
from datetime import date, timedelta
from pathlib import Path
from costmon.models import UsageRecord, DailySummary, ToolName

DB_PATH = Path.home() / ".costmon" / "usage.db"

class UsageStorage:
    def __init__(self, db_path: Path = DB_PATH):
        db_path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(str(db_path))
        self._init_tables()

    def _init_tables(self):
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS usage (
                tool TEXT NOT NULL,
                date TEXT NOT NULL,
                input_tokens INTEGER DEFAULT 0,
                output_tokens INTEGER DEFAULT 0,
                requests INTEGER DEFAULT 0,
                cost_cents INTEGER DEFAULT 0,
                PRIMARY KEY (tool, date)
            )
        """)
        self.conn.commit()

    def upsert(self, record: UsageRecord):
        """사용량 레코드를 저장 (있으면 업데이트)"""
        self.conn.execute("""
            INSERT INTO usage
                (tool, date, input_tokens, output_tokens,
                 requests, cost_cents)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(tool, date) DO UPDATE SET
                input_tokens = excluded.input_tokens,
                output_tokens = excluded.output_tokens,
                requests = excluded.requests,
                cost_cents = excluded.cost_cents
        """, (
            record.tool.value,
            str(record.date),
            record.input_tokens,
            record.output_tokens,
            record.requests,
            record.cost_cents,
        ))
        self.conn.commit()

    def get_range(
        self, start: date, end: date
    ) -> list[UsageRecord]:
        """기간 내 모든 레코드 조회"""
        rows = self.conn.execute("""
            SELECT tool, date, input_tokens,
                   output_tokens, requests, cost_cents
            FROM usage
            WHERE date BETWEEN ? AND ?
            ORDER BY date DESC
        """, (str(start), str(end))).fetchall()

        return [
            UsageRecord(
                tool=ToolName(r[0]), date=date.fromisoformat(r[1]),
                input_tokens=r[2], output_tokens=r[3],
                requests=r[4], cost_cents=r[5],
            )
            for r in rows
        ]

    def get_weekly_total(self) -> int:
        """이번 주 총 비용(센트)"""
        today = date.today()
        week_start = today - timedelta(days=today.weekday())
        rows = self.conn.execute("""
            SELECT COALESCE(SUM(cost_cents), 0)
            FROM usage WHERE date >= ?
        """, (str(week_start),)).fetchone()
        return rows[0]
```

### Step 6: Rich 대시보드

```python
# src/costmon/dashboard.py
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.columns import Columns
from rich.text import Text
from datetime import date, timedelta
from costmon.storage import UsageStorage
from costmon.models import ToolName

console = Console()

TOOL_COLORS = {
    ToolName.CLAUDE_CODE: "bright_magenta",
    ToolName.CURSOR: "bright_cyan",
    ToolName.COPILOT: "bright_green",
}

def render_dashboard(days: int = 7):
    """최근 N일 비용 대시보드 출력"""
    storage = UsageStorage()
    today = date.today()
    start = today - timedelta(days=days - 1)
    records = storage.get_range(start, today)

    # 요약 패널
    total = sum(r.cost_cents for r in records)
    daily_avg = total // days if days > 0 else 0
    weekly_total = storage.get_weekly_total()

    summary = Table.grid(padding=(0, 2))
    summary.add_row(
        Text(f"${total / 100:.2f}", style="bold yellow"),
        Text(f"최근 {days}일 합계"),
    )
    summary.add_row(
        Text(f"${daily_avg / 100:.2f}", style="bold"),
        Text("일 평균"),
    )
    summary.add_row(
        Text(f"${weekly_total / 100:.2f}", style="bold cyan"),
        Text("이번 주"),
    )

    console.print(Panel(summary, title="비용 요약", border_style="blue"))

    # 도구별 일별 테이블
    table = Table(title=f"최근 {days}일 상세")
    table.add_column("날짜", style="dim")
    for tool in ToolName:
        table.add_column(
            tool.value,
            style=TOOL_COLORS.get(tool, "white"),
            justify="right",
        )
    table.add_column("합계", style="bold yellow", justify="right")

    by_date: dict[date, dict[ToolName, int]] = {}
    for r in records:
        by_date.setdefault(r.date, {})[r.tool] = r.cost_cents

    for d in sorted(by_date.keys(), reverse=True):
        row = [str(d)]
        day_total = 0
        for tool in ToolName:
            cents = by_date[d].get(tool, 0)
            day_total += cents
            row.append(f"${cents / 100:.2f}")
        row.append(f"${day_total / 100:.2f}")
        table.add_row(*row)

    console.print(table)
```

### Step 7: CLI 엔트리포인트

```python
# src/costmon/main.py
import typer
from datetime import date, timedelta
from costmon.dashboard import render_dashboard
from costmon.collectors.claude import ClaudeCollector
from costmon.storage import UsageStorage
from costmon.alerts import check_budgets

app = typer.Typer(help="AI 코딩 도구 비용 모니터링")

@app.command()
def collect(
    days: int = typer.Option(1, help="수집할 일수"),
):
    """사용량 데이터를 수집하여 로컬 DB에 저장"""
    storage = UsageStorage()
    collectors = [ClaudeCollector()]
    today = date.today()

    for offset in range(days):
        target = today - timedelta(days=offset)
        for collector in collectors:
            if not collector.is_available():
                continue
            record = collector.collect(target)
            if record and record.requests > 0:
                storage.upsert(record)
                typer.echo(
                    f"  {record.tool.value} {target}: "
                    f"{record.requests}건, "
                    f"${record.cost_cents / 100:.2f}"
                )

@app.command()
def show(
    days: int = typer.Option(7, help="표시할 일수"),
):
    """비용 대시보드 출력"""
    render_dashboard(days)

@app.command()
def budget(
    daily: int = typer.Option(500, help="일일 예산 (센트)"),
    weekly: int = typer.Option(3000, help="주간 예산 (센트)"),
):
    """예산 대비 현재 사용량 확인"""
    alerts = check_budgets(
        daily_budget=daily, weekly_budget=weekly
    )
    for alert in alerts:
        if alert.exceeded_by_cents > 0:
            typer.secho(
                f"  {alert.period}: "
                f"${alert.actual_cents / 100:.2f} / "
                f"${alert.budget_cents / 100:.2f} "
                f"(${alert.exceeded_by_cents / 100:.2f} 초과)",
                fg=typer.colors.RED,
            )
        else:
            typer.secho(
                f"  {alert.period}: "
                f"${alert.actual_cents / 100:.2f} / "
                f"${alert.budget_cents / 100:.2f}",
                fg=typer.colors.GREEN,
            )

if __name__ == "__main__":
    app()
```

### Step 8: 예산 알림

```python
# src/costmon/alerts.py
from datetime import date, timedelta
from costmon.storage import UsageStorage
from costmon.models import BudgetAlert

def check_budgets(
    daily_budget: int = 500,
    weekly_budget: int = 3000,
    monthly_budget: int = 10000,
) -> list[BudgetAlert]:
    """예산 대비 사용량을 체크하고 알림 목록을 반환"""
    storage = UsageStorage()
    today = date.today()
    alerts = []

    # 일별
    daily_records = storage.get_range(today, today)
    daily_total = sum(r.cost_cents for r in daily_records)
    alerts.append(BudgetAlert(
        period="daily",
        budget_cents=daily_budget,
        actual_cents=daily_total,
        exceeded_by_cents=max(0, daily_total - daily_budget),
    ))

    # 주별
    week_start = today - timedelta(days=today.weekday())
    weekly_records = storage.get_range(week_start, today)
    weekly_total = sum(r.cost_cents for r in weekly_records)
    alerts.append(BudgetAlert(
        period="weekly",
        budget_cents=weekly_budget,
        actual_cents=weekly_total,
        exceeded_by_cents=max(0, weekly_total - weekly_budget),
    ))

    # 월별
    month_start = today.replace(day=1)
    monthly_records = storage.get_range(month_start, today)
    monthly_total = sum(r.cost_cents for r in monthly_records)
    alerts.append(BudgetAlert(
        period="monthly",
        budget_cents=monthly_budget,
        actual_cents=monthly_total,
        exceeded_by_cents=max(0, monthly_total - monthly_budget),
    ))

    return alerts
```

## 핵심 설계 포인트

| 설계 결정 | 이유 |
|-----------|------|
| 플러그인 패턴 수집기 | 새 도구 추가 시 `CollectorBase`만 구현 |
| SQLite 로컬 저장 | 외부 의존성 없이 즉시 사용 가능 |
| 센트 단위 내부 처리 | 부동소수점 오차 방지 |
| 날짜 기반 UPSERT | 같은 날 재수집 시 덮어쓰기 |
| Rich Live 대시보드 | 터미널에서 실시간 모니터링 가능 |

## 확장 아이디어

### Cursor 수집기 추가

```python
# src/costmon/collectors/cursor.py
class CursorCollector(CollectorBase):
    """Cursor 설정 디렉토리에서 사용량 추출"""

    def is_available(self) -> bool:
        config = Path.home() / ".cursor"
        return config.exists()

    def collect(self, target_date: date) -> UsageRecord | None:
        # Cursor는 Settings > Usage에서 확인 가능
        # 로컬 로그 파싱 또는 API 연동
        ...
```

### 크론으로 자동 수집

```bash
# crontab -e
# 매일 자정에 수집 + 예산 체크
0 0 * * * cd /path/to/costmon && \
  python -m costmon.main collect --days 1 && \
  python -m costmon.main budget
```

### Slack/Discord 알림 연동

```python
# 예산 초과 시 webhook 전송
def send_alert_webhook(alert: BudgetAlert, webhook_url: str):
    import httpx
    if alert.exceeded_by_cents > 0:
        httpx.post(webhook_url, json={
            "text": (
                f"AI 비용 알림: {alert.period} 예산 초과\n"
                f"사용: ${alert.actual_cents / 100:.2f} / "
                f"예산: ${alert.budget_cents / 100:.2f}"
            ),
        })
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 새 수집기 추가 | `Copilot용 수집기를 CollectorBase 패턴으로 만들어줘` |
| 대시보드 개선 | `Rich Live로 실시간 업데이트되는 대시보드로 바꿔줘` |
| 테스트 작성 | `ClaudeCollector의 _parse_session에 대한 단위 테스트 작성해줘` |
| 데이터 시각화 | `비용 트렌드를 Rich 바 차트로 보여주는 커맨드 추가해줘` |
| 비용 예측 | `최근 7일 데이터로 월말 예상 비용을 계산하는 기능 만들어줘` |

## 참고 도구

| 도구 | 용도 |
|------|------|
| [ccusage](https://ccusage.com/) | Claude Code 토큰 사용량 추적 |
| [Torii](https://toriihq.com) | SaaS 비용 통합 관리 |
| SQLite | 로컬 경량 데이터베이스 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
