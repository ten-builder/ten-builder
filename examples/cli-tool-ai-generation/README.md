# CLI 도구 AI 자동 생성 프로젝트

> 아이디어 하나로 완성된 CLI 도구를 만드는 과정 — AI 에이전트에게 설계부터 테스트까지 맡기기

## 이 예제에서 배울 수 있는 것

- 프롬프트 하나로 CLI 프로젝트 구조를 자동 생성하는 방법
- CLAUDE.md로 AI 에이전트에게 설계 의도를 정확히 전달하는 패턴
- 반복 프롬프트로 기능을 점진적으로 확장하는 워크플로우
- AI가 만든 코드의 품질을 검증하고 개선하는 실전 팁

## 프로젝트 구조

```
cli-tool-ai-generation/
├── CLAUDE.md              # AI 에이전트 컨텍스트
├── src/
│   └── gitpulse/
│       ├── __init__.py
│       ├── main.py        # CLI 엔트리포인트
│       ├── analyzer.py    # Git 로그 분석 엔진
│       ├── formatter.py   # 출력 포맷터 (테이블/차트)
│       ├── config.py      # 설정 관리
│       └── utils.py       # 유틸리티 함수
├── tests/
│   ├── test_analyzer.py
│   ├── test_formatter.py
│   └── conftest.py
├── pyproject.toml
└── README.md
```

## 만들 도구: gitpulse

Git 커밋 히스토리를 분석해서 개발 패턴을 시각화하는 CLI 도구예요. 특정 레포에서 누가, 언제, 어떤 파일을 많이 수정했는지 한눈에 보여줘요.

```bash
# 사용 예시
gitpulse summary              # 최근 7일 커밋 요약
gitpulse hotspots --days 30   # 자주 변경되는 파일 Top 10
gitpulse rhythm               # 시간대별 커밋 패턴
gitpulse contributors         # 기여자별 통계
```

## 시작하기

### Step 1: 프로젝트 초기화 프롬프트

프로젝트 뼈대를 만드는 첫 프롬프트예요. 기술 스택과 구조를 명확히 지정하는 게 핵심이에요.

```
Python CLI 도구를 만들어줘.

- 이름: gitpulse
- 기능: git log를 파싱해서 커밋 통계를 터미널에 출력
- 기술 스택: Python 3.12+, Click (CLI 프레임워크), Rich (터미널 UI)
- 구조: src/gitpulse/ 하위에 모듈 분리
- pyproject.toml로 패키징, pytest로 테스트
- 서브커맨드: summary, hotspots, rhythm, contributors

먼저 프로젝트 구조만 생성하고, 각 파일에 docstring과 TODO 주석을 넣어줘.
```

이 프롬프트의 포인트:
- **기술 스택을 명시**해서 AI가 다른 라이브러리를 고르는 걸 방지
- **"구조만 먼저"** 라고 해서 한번에 전부 만들지 않도록 유도
- 서브커맨드를 미리 정해서 설계 흔들림을 줄임

### Step 2: CLAUDE.md로 컨텍스트 설정

AI 에이전트가 프로젝트를 이해하도록 컨텍스트 파일을 작성해요.

```markdown
# gitpulse — Git 커밋 분석 CLI 도구

## 기술 스택
- Python 3.12+, Click, Rich, GitPython
- 테스트: pytest + pytest-cov
- 포맷: ruff (lint + format)

## 설계 원칙
- subprocess 대신 GitPython으로 git 조작
- 모든 출력은 Rich 테이블/패널 사용
- 설정은 ~/.config/gitpulse/config.toml
- 에러 메시지는 사용자 친화적으로 (스택트레이스 숨김)

## 규칙
- 타입 힌트 필수
- 함수당 최대 20줄
- docstring은 한국어로 작성
- 테스트 커버리지 80% 이상
```

### Step 3: 핵심 로직 구현 프롬프트

구조가 잡히면 핵심 분석 로직을 요청해요.

```
analyzer.py를 구현해줘.

GitPython으로 현재 디렉토리의 git 레포를 열고:
1. 최근 N일간 커밋 목록 가져오기
2. 커밋별 변경 파일, 추가/삭제 줄 수 파싱
3. 파일별 변경 빈도 집계 (hotspots)
4. 시간대별 커밋 수 집계 (rhythm)
5. 작성자별 커밋 수 + 변경 줄 수 집계

각 기능은 독립 함수로 분리하고, 반환 타입은 dataclass나 TypedDict로 정의해줘.
```

```python
# AI가 생성한 코드 예시 — analyzer.py
from dataclasses import dataclass
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from git import Repo
from pathlib import Path


@dataclass
class CommitStat:
    """개별 커밋 통계"""
    hash: str
    author: str
    date: datetime
    message: str
    files_changed: int
    insertions: int
    deletions: int


@dataclass
class HotspotEntry:
    """자주 변경되는 파일 항목"""
    filepath: str
    change_count: int
    last_changed: datetime


def get_repo(path: str = ".") -> Repo:
    """현재 경로에서 Git 레포를 찾아 반환해요."""
    try:
        return Repo(path, search_parent_directories=True)
    except Exception:
        raise SystemExit("Git 레포를 찾을 수 없어요. git init이 된 디렉토리에서 실행해주세요.")


def collect_commits(repo: Repo, days: int = 7) -> list[CommitStat]:
    """최근 N일간 커밋을 수집해요."""
    since = datetime.now() - timedelta(days=days)
    commits = []

    for commit in repo.iter_commits(since=since.isoformat()):
        stats = commit.stats.total
        commits.append(CommitStat(
            hash=commit.hexsha[:8],
            author=commit.author.name,
            date=commit.committed_datetime,
            message=commit.message.strip().split("\n")[0],
            files_changed=stats.get("files", 0),
            insertions=stats.get("insertions", 0),
            deletions=stats.get("deletions", 0),
        ))

    return commits


def find_hotspots(repo: Repo, days: int = 30, limit: int = 10) -> list[HotspotEntry]:
    """자주 변경되는 파일 Top N을 찾아요."""
    since = datetime.now() - timedelta(days=days)
    file_counter: Counter = Counter()
    file_last_changed: dict[str, datetime] = {}

    for commit in repo.iter_commits(since=since.isoformat()):
        for filepath in commit.stats.files:
            file_counter[filepath] += 1
            current = file_last_changed.get(filepath)
            if current is None or commit.committed_datetime > current:
                file_last_changed[filepath] = commit.committed_datetime

    return [
        HotspotEntry(
            filepath=fp,
            change_count=count,
            last_changed=file_last_changed[fp],
        )
        for fp, count in file_counter.most_common(limit)
    ]


def analyze_rhythm(repo: Repo, days: int = 30) -> dict[int, int]:
    """시간대별 커밋 분포를 분석해요. {hour: count} 형태로 반환."""
    since = datetime.now() - timedelta(days=days)
    hourly: defaultdict[int, int] = defaultdict(int)

    for commit in repo.iter_commits(since=since.isoformat()):
        hour = commit.committed_datetime.hour
        hourly[hour] += 1

    return dict(sorted(hourly.items()))
```

### Step 4: 출력 포맷터 구현

```
formatter.py를 구현해줘.

Rich 라이브러리로 분석 결과를 보기 좋게 출력하는 함수들:
1. print_summary: 커밋 수, 총 변경 줄 수, 가장 활발한 작성자를 패널로 출력
2. print_hotspots: 파일별 변경 빈도를 테이블로 출력 (막대 그래프 포함)
3. print_rhythm: 시간대별 커밋 수를 가로 막대 차트로 출력
4. print_contributors: 기여자별 통계 테이블

각 함수는 analyzer.py의 반환 타입을 입력으로 받도록 해줘.
```

```python
# AI가 생성한 코드 예시 — formatter.py (일부)
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text

console = Console()


def print_summary(commits: list, days: int) -> None:
    """커밋 요약을 패널로 출력해요."""
    if not commits:
        console.print("[yellow]해당 기간에 커밋이 없어요.[/yellow]")
        return

    total_insertions = sum(c.insertions for c in commits)
    total_deletions = sum(c.deletions for c in commits)
    authors = {}
    for c in commits:
        authors[c.author] = authors.get(c.author, 0) + 1
    top_author = max(authors, key=authors.get) if authors else "없음"

    summary = Text()
    summary.append(f"기간: 최근 {days}일\n", style="bold")
    summary.append(f"총 커밋: {len(commits)}개\n")
    summary.append(f"추가: ", style="green")
    summary.append(f"+{total_insertions:,}줄  ")
    summary.append(f"삭제: ", style="red")
    summary.append(f"-{total_deletions:,}줄\n")
    summary.append(f"가장 활발한 기여자: {top_author} ({authors.get(top_author, 0)}개)")

    console.print(Panel(summary, title="gitpulse summary", border_style="blue"))


def print_hotspots(hotspots: list) -> None:
    """핫스팟 파일 목록을 테이블로 출력해요."""
    table = Table(title="파일 변경 빈도 Top 10")
    table.add_column("순위", style="dim", width=4)
    table.add_column("파일 경로", style="cyan")
    table.add_column("변경 횟수", justify="right")
    table.add_column("그래프", width=20)

    max_count = hotspots[0].change_count if hotspots else 1
    for i, h in enumerate(hotspots, 1):
        bar_len = int((h.change_count / max_count) * 20)
        bar = "█" * bar_len + "░" * (20 - bar_len)
        table.add_row(str(i), h.filepath, str(h.change_count), bar)

    console.print(table)
```

### Step 5: 테스트 생성 프롬프트

```
테스트를 작성해줘.

1. test_analyzer.py: 임시 git 레포를 만들어서 analyzer 함수들을 테스트
   - pytest의 tmp_path 픽스처 사용
   - 테스트용 커밋 3~5개 자동 생성
2. test_formatter.py: Rich의 Console(record=True)로 출력 캡처해서 검증

edge case도 포함해줘:
- 커밋이 0개인 레포
- 파일 변경 없는 커밋 (--allow-empty)
- 한 파일이 매우 많이 변경된 경우
```

```python
# AI가 생성한 테스트 예시 — conftest.py
import pytest
from git import Repo
from pathlib import Path
from datetime import datetime


@pytest.fixture
def temp_repo(tmp_path: Path) -> Repo:
    """테스트용 임시 Git 레포를 생성해요."""
    repo = Repo.init(tmp_path)
    repo.config_writer().set_value("user", "name", "Test User").release()
    repo.config_writer().set_value("user", "email", "test@example.com").release()

    # 테스트 커밋 생성
    test_file = tmp_path / "main.py"
    for i in range(5):
        test_file.write_text(f"# version {i}\nprint('hello {i}')\n")
        repo.index.add(["main.py"])
        repo.index.commit(f"Update main.py v{i}")

    return repo


@pytest.fixture
def empty_repo(tmp_path: Path) -> Repo:
    """커밋이 없는 빈 레포를 생성해요."""
    repo = Repo.init(tmp_path / "empty")
    repo.config_writer().set_value("user", "name", "Test User").release()
    repo.config_writer().set_value("user", "email", "test@example.com").release()
    return repo
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 새 서브커맨드 추가 | `compare 서브커맨드를 추가해줘. 두 브랜치의 커밋 통계를 비교하는 기능이야.` |
| 에러 처리 보강 | `GitPython에서 발생할 수 있는 예외를 전부 찾아서 사용자 친화적 에러 메시지로 바꿔줘.` |
| 성능 개선 | `커밋 1만 개 이상인 레포에서 느릴 수 있어. 제너레이터로 바꾸고 프로그레스바를 추가해줘.` |
| 배포 준비 | `pyproject.toml을 PyPI 배포 가능하게 수정하고, GitHub Actions CI 워크플로우도 만들어줘.` |
| 설정 파일 지원 | `~/.config/gitpulse/config.toml로 기본 옵션을 설정할 수 있게 해줘.` |

## 패턴 정리: AI에게 CLI 도구 만들기를 잘 시키는 법

### 1. 점진적으로 요청하기

한 번에 전체를 만들어 달라고 하면 구조가 엉킬 수 있어요. 이 순서를 추천해요:

```
구조 생성 → CLAUDE.md 작성 → 핵심 로직 → 포맷터/UI → 테스트 → 에러 처리 → 배포
```

### 2. 서브커맨드 단위로 나누기

CLI 도구는 서브커맨드 단위로 요청하면 결과가 좋아요. 각 커맨드가 독립적이라서 AI가 맥락을 놓칠 확률이 줄어요.

### 3. 출력 예시 먼저 보여주기

"이런 형태로 출력되면 좋겠어"라고 예시를 주면 AI가 Rich 테이블 구조를 정확하게 잡아요.

```
이런 식으로 출력되면 좋겠어:

┌─────────────────────────┐
│    gitpulse summary     │
│ 기간: 최근 7일          │
│ 총 커밋: 23개           │
│ 추가: +1,234줄          │
│ 삭제: -567줄            │
└─────────────────────────┘
```

### 4. 테스트를 같이 요청하기

"기능 구현하고 테스트도 같이 만들어줘"라고 하면 AI가 테스트하기 쉬운 구조로 코드를 설계해요. 테스트를 나중에 요청하면 기존 코드를 리팩토링해야 하는 경우가 생겨요.

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
