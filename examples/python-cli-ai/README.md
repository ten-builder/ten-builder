# Python CLI + AI 실전 예제

> Typer + Rich로 CLI 도구를 만들고, AI 코딩 도구로 개발 속도를 높이는 단계별 가이드

## 이 예제에서 배울 수 있는 것

- Typer로 타입 안전한 CLI 인터페이스를 빠르게 구성하는 방법
- Rich를 사용해 터미널 출력을 보기 좋게 꾸미는 패턴
- AI 코딩 도구와 함께 테스트까지 한 번에 완성하는 워크플로우

## 프로젝트 구조

```
python-cli-ai/
├── CLAUDE.md              # 프로젝트 컨텍스트 설정
├── src/
│   └── taskr/
│       ├── __init__.py
│       ├── main.py        # CLI 엔트리포인트
│       ├── commands.py    # 서브 커맨드 정의
│       ├── models.py      # 데이터 모델 (Pydantic)
│       ├── storage.py     # JSON 파일 저장소
│       └── display.py     # Rich 테이블/패널 출력
├── tests/
│   ├── test_commands.py   # 커맨드 단위 테스트
│   └── test_storage.py   # 저장소 테스트
├── pyproject.toml
└── README.md
```

## 시작하기

### Step 1: 프로젝트 초기화

```bash
mkdir taskr && cd taskr
python -m venv .venv && source .venv/bin/activate
pip install typer rich pydantic pytest
```

### Step 2: CLAUDE.md 작성

AI에게 프로젝트 맥락을 전달하는 설정 파일을 먼저 만들어요.

```markdown
# taskr — 터미널 할 일 관리 도구

## 기술 스택
- Python 3.12+, Typer (CLI), Rich (출력), Pydantic (모델)
- 저장소: ~/.taskr/tasks.json (JSON 파일)

## 규칙
- 모든 함수에 타입 힌트 필수
- docstring은 한국어
- 테스트는 pytest, 커버리지 80% 이상 목표
```

### Step 3: 데이터 모델 정의

```python
# src/taskr/models.py
from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum

class Priority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"

class Task(BaseModel):
    """할 일 항목"""
    id: int
    title: str
    priority: Priority = Priority.MEDIUM
    done: bool = False
    created_at: datetime = Field(default_factory=datetime.now)

class TaskStore(BaseModel):
    """전체 할 일 저장소"""
    tasks: list[Task] = []
    next_id: int = 1
```

### Step 4: 저장소 구현

```python
# src/taskr/storage.py
import json
from pathlib import Path
from .models import TaskStore

STORE_PATH = Path.home() / ".taskr" / "tasks.json"

def load() -> TaskStore:
    """저장된 할 일 목록을 불러와요."""
    if not STORE_PATH.exists():
        return TaskStore()
    data = json.loads(STORE_PATH.read_text())
    return TaskStore.model_validate(data)

def save(store: TaskStore) -> None:
    """할 일 목록을 파일에 저장해요."""
    STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STORE_PATH.write_text(store.model_dump_json(indent=2))
```

### Step 5: Rich 출력 모듈

```python
# src/taskr/display.py
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from .models import Task, Priority

console = Console()

PRIORITY_COLORS = {
    Priority.HIGH: "red",
    Priority.MEDIUM: "yellow",
    Priority.LOW: "dim",
}

def show_tasks(tasks: list[Task]) -> None:
    """할 일 목록을 테이블로 출력해요."""
    if not tasks:
        console.print(Panel("등록된 할 일이 없어요 ✨", style="green"))
        return

    table = Table(title="📋 할 일 목록", show_lines=True)
    table.add_column("ID", style="cyan", width=4)
    table.add_column("상태", width=4)
    table.add_column("제목")
    table.add_column("우선순위", width=8)

    for t in tasks:
        status = "✅" if t.done else "⬜"
        color = PRIORITY_COLORS[t.priority]
        table.add_row(
            str(t.id), status, t.title,
            f"[{color}]{t.priority.value}[/{color}]",
        )
    console.print(table)
```

### Step 6: CLI 커맨드 조립

```python
# src/taskr/main.py
import typer
from typing import Optional
from .models import Task, Priority
from .storage import load, save
from .display import show_tasks, console

app = typer.Typer(help="taskr — 터미널 할 일 관리 도구")

@app.command()
def add(title: str, priority: Priority = Priority.MEDIUM):
    """새 할 일을 추가해요."""
    store = load()
    task = Task(id=store.next_id, title=title, priority=priority)
    store.tasks.append(task)
    store.next_id += 1
    save(store)
    console.print(f"[green]✅ 추가됨:[/green] {task.title} (#{task.id})")

@app.command(name="list")
def list_tasks(
    all: bool = typer.Option(False, "--all", "-a", help="완료 항목도 표시"),
):
    """할 일 목록을 보여줘요."""
    store = load()
    tasks = store.tasks if all else [t for t in store.tasks if not t.done]
    show_tasks(tasks)

@app.command()
def done(task_id: int):
    """할 일을 완료 처리해요."""
    store = load()
    for t in store.tasks:
        if t.id == task_id:
            t.done = True
            save(store)
            console.print(f"[green]✅ 완료:[/green] {t.title}")
            return
    console.print(f"[red]ID {task_id}를 찾을 수 없어요[/red]")
    raise typer.Exit(1)

@app.command()
def remove(task_id: int):
    """할 일을 삭제해요."""
    store = load()
    before = len(store.tasks)
    store.tasks = [t for t in store.tasks if t.id != task_id]
    if len(store.tasks) == before:
        console.print(f"[red]ID {task_id}를 찾을 수 없어요[/red]")
        raise typer.Exit(1)
    save(store)
    console.print(f"[yellow]🗑 삭제됨[/yellow] (#{task_id})")

if __name__ == "__main__":
    app()
```

### Step 7: pyproject.toml 설정

```toml
[project]
name = "taskr"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["typer>=0.15", "rich>=13", "pydantic>=2"]

[project.scripts]
taskr = "taskr.main:app"

[tool.pytest.ini_options]
testpaths = ["tests"]
```

## 실행 예시

```bash
# 할 일 추가
taskr add "API 엔드포인트 구현" --priority high
taskr add "README 작성" --priority low

# 목록 확인
taskr list

# 완료 처리
taskr done 1

# 전체 보기 (완료 포함)
taskr list --all
```

## 핵심 코드 설명

### Typer + Enum 조합

`Priority`를 `str, Enum`으로 정의하면 Typer가 자동으로 `--priority` 옵션의 선택지를 만들어줘요. `--help`에도 `[low|medium|high]`가 표시되고, 잘못된 값을 넣으면 에러 메시지까지 자동으로 나와요.

### Pydantic + JSON 저장

`model_dump_json()`과 `model_validate()`를 사용하면 직렬화/역직렬화 코드를 직접 작성할 필요가 없어요. 스키마가 바뀌어도 마이그레이션이 간편해요.

### Rich Table 출력

`Table`에 `show_lines=True`를 주면 각 행이 선으로 구분돼서 터미널에서도 읽기 편해요. 우선순위별 색상 매핑은 딕셔너리 하나로 관리하면 깔끔해요.

## 테스트 작성

```python
# tests/test_commands.py
from typer.testing import CliRunner
from taskr.main import app
from taskr.storage import STORE_PATH

runner = CliRunner()

def setup_function():
    """각 테스트 전에 저장소를 초기화해요."""
    if STORE_PATH.exists():
        STORE_PATH.unlink()

def test_add_and_list():
    result = runner.invoke(app, ["add", "테스트 할 일"])
    assert result.exit_code == 0
    assert "추가됨" in result.stdout

    result = runner.invoke(app, ["list"])
    assert "테스트 할 일" in result.stdout

def test_done():
    runner.invoke(app, ["add", "완료할 항목"])
    result = runner.invoke(app, ["done", "1"])
    assert result.exit_code == 0
    assert "완료" in result.stdout

def test_remove():
    runner.invoke(app, ["add", "삭제할 항목"])
    result = runner.invoke(app, ["remove", "1"])
    assert result.exit_code == 0
    assert "삭제됨" in result.stdout

def test_done_not_found():
    result = runner.invoke(app, ["done", "999"])
    assert result.exit_code == 1
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 새 서브커맨드 추가 | `taskr에 stats 커맨드 추가해줘. 우선순위별 개수를 Rich 바 차트로 보여줘` |
| 테스트 보강 | `storage.py의 엣지 케이스 테스트 추가해줘. 파일이 깨졌을 때 복구 로직 포함` |
| 기능 확장 | `taskr에 due date 필드 추가하고, 기한 지난 항목은 빨간색으로 표시해줘` |
| 배포 준비 | `pyproject.toml 정리하고 PyPI 배포할 수 있게 만들어줘` |

## 더 알아보기

- [Typer 공식 문서](https://typer.tiangolo.com/) — CLI 프레임워크
- [Rich 공식 문서](https://rich.readthedocs.io/) — 터미널 출력
- [Pydantic V2 문서](https://docs.pydantic.dev/) — 데이터 모델

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
