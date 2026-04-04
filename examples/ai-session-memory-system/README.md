# AI 에이전트 세션 메모리 시스템

> AI 코딩 에이전트가 이전 대화와 결정을 기억하는 메모리 시스템을 직접 만들어보기

## 이 예제에서 배울 수 있는 것

- CLAUDE.md와 메모리 파일을 조합해서 세션 간 컨텍스트를 유지하는 방법
- 계층형 메모리 구조(단기/장기/프로젝트)를 설계하는 패턴
- 메모리 자동 정리와 요약으로 토큰 소비를 줄이는 전략
- AI 에이전트가 스스로 학습하고 개선하는 피드백 루프 구현

## 프로젝트 구조

```
ai-session-memory-system/
├── CLAUDE.md                    # 프로젝트 규칙 + 메모리 로딩 지시
├── MEMORY.md                    # 장기 메모리 (직접 편집 가능)
├── memory/
│   ├── 2026-04-04.md            # 일별 세션 로그
│   ├── 2026-04-03.md
│   └── decisions.md             # 주요 기술 결정 기록
├── src/
│   └── memoryctl/
│       ├── __init__.py
│       ├── main.py              # CLI 엔트리포인트
│       ├── loader.py            # 메모리 파일 로딩 엔진
│       ├── compactor.py         # 오래된 메모리 요약/정리
│       ├── injector.py          # 프롬프트에 메모리 주입
│       └── watcher.py           # 파일 변경 감지
├── tests/
│   ├── test_loader.py
│   ├── test_compactor.py
│   └── conftest.py
├── pyproject.toml
└── README.md
```

## 왜 세션 메모리가 필요한가

AI 코딩 에이전트는 기본적으로 대화가 끝나면 모든 컨텍스트를 잊어요. 어제 "React 대신 Svelte 쓰자"고 결정했어도, 오늘 새 세션에서는 다시 React를 제안할 수 있죠.

이 문제를 해결하는 핵심 아이디어: **파일 시스템을 메모리로 사용한다.**

```
세션 시작 → CLAUDE.md 읽기 → 메모리 파일 로딩 → 컨텍스트 주입 → 작업
    ↓
세션 종료 → 결정사항 기록 → 메모리 파일 업데이트
```

## 시작하기

### Step 1: CLAUDE.md 기본 템플릿 작성

CLAUDE.md는 AI 에이전트가 프로젝트에 진입할 때 가장 먼저 읽는 파일이에요. 여기에 메모리 로딩 규칙을 넣어요.

```markdown
# 프로젝트 컨텍스트

## 세션 시작 시 필수 행동
1. MEMORY.md를 읽어서 장기 메모리를 로드
2. memory/ 폴더에서 최근 3일 파일을 확인
3. memory/decisions.md에서 기술 결정사항 확인

## 세션 종료 시 필수 행동
1. 오늘 내린 결정을 memory/YYYY-MM-DD.md에 기록
2. 중요한 결정은 memory/decisions.md에도 추가
3. MEMORY.md에 장기적으로 기억할 내용 업데이트

## 메모리 우선순위
- CLAUDE.md > MEMORY.md > memory/decisions.md > memory/일별 로그
- 충돌 시 더 최신 파일의 내용을 우선
```

**포인트:** CLAUDE.md에 "무엇을 읽을지"뿐 아니라 "무엇을 기록할지"도 명시하는 게 핵심이에요. 읽기만 하면 메모리가 축적되지 않아요.

### Step 2: 계층형 메모리 구조 설계

메모리를 세 계층으로 나누면 토큰 효율이 좋아져요.

| 계층 | 파일 | 역할 | 토큰 예산 |
|------|------|------|-----------|
| L1: 프로젝트 규칙 | `CLAUDE.md` | 절대 변하지 않는 규칙 | 1,000~2,000 |
| L2: 장기 메모리 | `MEMORY.md` | 직접 요약한 핵심 컨텍스트 | 500~1,500 |
| L3: 단기 로그 | `memory/*.md` | 일별 원본 로그 | 최근 3일만 로드 |

```python
# src/memoryctl/loader.py
"""메모리 파일 계층 로더"""
from pathlib import Path
from datetime import date, timedelta

class MemoryLoader:
    def __init__(self, project_root: Path):
        self.root = project_root
        self.memory_dir = project_root / "memory"

    def load_all(self, days: int = 3) -> dict:
        """계층별 메모리를 로드해서 하나의 컨텍스트로 합침"""
        return {
            "rules": self._load_file("CLAUDE.md"),
            "long_term": self._load_file("MEMORY.md"),
            "decisions": self._load_file("memory/decisions.md"),
            "recent_logs": self._load_recent_logs(days),
        }

    def _load_recent_logs(self, days: int) -> list[dict]:
        """최근 N일의 세션 로그만 로드"""
        logs = []
        today = date.today()
        for i in range(days):
            target = today - timedelta(days=i)
            path = self.memory_dir / f"{target.isoformat()}.md"
            if path.exists():
                logs.append({
                    "date": target.isoformat(),
                    "content": path.read_text(encoding="utf-8"),
                })
        return logs

    def _load_file(self, relative: str) -> str | None:
        path = self.root / relative
        return path.read_text(encoding="utf-8") if path.exists() else None
```

### Step 3: 메모리 자동 정리 (Compaction)

일별 로그가 쌓이면 토큰 소비가 늘어나요. 7일 이상 된 로그는 요약해서 MEMORY.md에 병합하는 게 좋아요.

```python
# src/memoryctl/compactor.py
"""오래된 메모리 요약 + 정리"""
from pathlib import Path
from datetime import date, timedelta

class MemoryCompactor:
    def __init__(self, memory_dir: Path, retention_days: int = 7):
        self.memory_dir = memory_dir
        self.retention_days = retention_days

    def find_stale_logs(self) -> list[Path]:
        """보관 기간이 지난 로그 파일 목록"""
        cutoff = date.today() - timedelta(days=self.retention_days)
        stale = []
        for f in self.memory_dir.glob("????-??-??.md"):
            try:
                log_date = date.fromisoformat(f.stem)
                if log_date < cutoff:
                    stale.append(f)
            except ValueError:
                continue
        return sorted(stale)

    def compact(self, stale_files: list[Path]) -> str:
        """여러 로그를 하나의 요약으로 압축"""
        combined = []
        for f in stale_files:
            content = f.read_text(encoding="utf-8")
            combined.append(f"### {f.stem}\n{content}")

        raw = "\n\n".join(combined)
        # 실제로는 여기서 LLM API를 호출해서 요약
        # 이 예제에서는 간단히 섹션 헤더만 추출
        return self._extract_headers(raw)

    def _extract_headers(self, text: str) -> str:
        """Markdown 헤더와 첫 줄만 추출하는 간단한 요약"""
        lines = text.split("\n")
        summary = []
        for i, line in enumerate(lines):
            if line.startswith("#"):
                summary.append(line)
                # 헤더 다음 줄이 비어있지 않으면 추가
                if i + 1 < len(lines) and lines[i + 1].strip():
                    summary.append(lines[i + 1])
        return "\n".join(summary)
```

### Step 4: 프롬프트에 메모리 주입

로드한 메모리를 AI 에이전트 프롬프트에 자연스럽게 주입해요.

```python
# src/memoryctl/injector.py
"""메모리를 프롬프트 컨텍스트로 변환"""

class MemoryInjector:
    MAX_TOKENS = 4000  # 메모리용 토큰 예산

    def build_context(self, memory: dict) -> str:
        """계층별 메모리를 하나의 컨텍스트 블록으로 조합"""
        sections = []

        if memory.get("rules"):
            sections.append(
                f"## Project Rules\n{memory['rules']}"
            )

        if memory.get("long_term"):
            sections.append(
                f"## What I Remember\n{memory['long_term']}"
            )

        if memory.get("decisions"):
            sections.append(
                f"## Past Decisions\n{memory['decisions']}"
            )

        if memory.get("recent_logs"):
            log_text = "\n\n".join(
                f"### {log['date']}\n{log['content']}"
                for log in memory["recent_logs"]
            )
            sections.append(f"## Recent Sessions\n{log_text}")

        full = "\n\n---\n\n".join(sections)
        return self._truncate(full)

    def _truncate(self, text: str) -> str:
        """토큰 예산 초과 시 오래된 로그부터 잘라냄"""
        # 대략 1 토큰 ≈ 4 chars (영어 기준)
        max_chars = self.MAX_TOKENS * 4
        if len(text) <= max_chars:
            return text
        return text[:max_chars] + "\n\n[... truncated due to token budget]"
```

### Step 5: CLI 도구로 묶기

```python
# src/memoryctl/main.py
"""memoryctl — AI 에이전트 세션 메모리 관리 CLI"""
import click
from pathlib import Path
from .loader import MemoryLoader
from .compactor import MemoryCompactor

@click.group()
@click.option("--root", default=".", help="프로젝트 루트 경로")
@click.pass_context
def cli(ctx, root):
    ctx.ensure_object(dict)
    ctx.obj["root"] = Path(root).resolve()

@cli.command()
@click.pass_context
def status(ctx):
    """현재 메모리 상태 확인"""
    root = ctx.obj["root"]
    loader = MemoryLoader(root)
    memory = loader.load_all()

    click.echo(f"Project root: {root}")
    click.echo(f"CLAUDE.md: {'found' if memory['rules'] else 'missing'}")
    click.echo(f"MEMORY.md: {'found' if memory['long_term'] else 'missing'}")
    click.echo(f"Recent logs: {len(memory['recent_logs'])} days")

@cli.command()
@click.option("--days", default=7, help="보관 기간 (일)")
@click.pass_context
def compact(ctx, days):
    """오래된 로그를 요약하고 정리"""
    root = ctx.obj["root"]
    compactor = MemoryCompactor(root / "memory", retention_days=days)
    stale = compactor.find_stale_logs()

    if not stale:
        click.echo("정리할 로그가 없어요.")
        return

    click.echo(f"{len(stale)}개의 오래된 로그를 발견했어요:")
    for f in stale:
        click.echo(f"  - {f.name}")

    summary = compactor.compact(stale)
    click.echo(f"\n요약 결과:\n{summary}")

@cli.command()
@click.pass_context
def context(ctx):
    """AI 에이전트에 주입할 컨텍스트 미리보기"""
    from .injector import MemoryInjector
    root = ctx.obj["root"]
    loader = MemoryLoader(root)
    injector = MemoryInjector()

    memory = loader.load_all()
    ctx_text = injector.build_context(memory)
    click.echo(ctx_text)
```

## 핵심 코드

### MEMORY.md 작성 가이드

```markdown
# MEMORY.md — 장기 메모리

## 기술 결정
- 2026-04-01: 프론트엔드 프레임워크로 Svelte 5 선택 (React 대비 번들 크기 60% 감소)
- 2026-04-02: 상태 관리 zustand 대신 Svelte runes 사용 결정

## 아키텍처
- API: REST → tRPC 전환 예정 (4월 중)
- DB: PostgreSQL + Drizzle ORM
- 인프라: Vercel (프론트) + Railway (백엔드)

## 스타일 가이드
- 컴포넌트: 함수형, props는 TypeScript interface로 정의
- 네이밍: camelCase (변수), PascalCase (컴포넌트)
- 테스트: Vitest + Testing Library

## 회고
- AI가 Svelte 5 runes 문법을 자주 틀림 → 예시 코드를 CLAUDE.md에 추가하면 정확도 향상
- 큰 파일 리팩토링 시 파일 단위로 지시하면 결과가 더 좋음
```

**포인트:** MEMORY.md는 AI가 스스로 업데이트하게 할 수도 있지만, 처음에는 직접 관리하는 게 정확도가 높아요. 익숙해지면 "세션 끝에 MEMORY.md 업데이트해줘"라고 지시하면 돼요.

### decisions.md 패턴

```markdown
# 기술 결정 로그

## DEC-001: 프레임워크 선택 (2026-04-01)
- **결정:** Svelte 5
- **대안:** React 19, Vue 3.5
- **근거:** 번들 크기, runes 반응성 모델, 러닝커브
- **영향:** 컴포넌트 작성 패턴이 React와 완전히 다름

## DEC-002: 테스트 전략 (2026-04-02)
- **결정:** 통합 테스트 중심 (E2E 30%, 통합 50%, 유닛 20%)
- **근거:** AI가 생성한 코드는 모듈 간 연결부에서 버그가 많음
- **영향:** 유닛 테스트보다 통합 테스트 작성 우선
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 메모리 구조 초기화 | `이 프로젝트에 세션 메모리 시스템을 설정해줘. CLAUDE.md, MEMORY.md, memory/ 폴더를 만들고 기본 템플릿을 작성해` |
| 세션 시작 | `MEMORY.md와 최근 로그를 읽고, 어제 하던 작업을 이어서 해줘` |
| 결정 기록 | `방금 내린 결정을 memory/decisions.md에 DEC 형식으로 기록해줘` |
| 메모리 정리 | `일주일 넘은 로그를 요약해서 MEMORY.md에 병합하고 원본은 삭제해줘` |
| 컨텍스트 최적화 | `현재 MEMORY.md가 너무 길어. 핵심만 남기고 정리해줘` |

## 실전 팁

**1. 토큰 예산을 미리 정해두세요**

메모리 파일이 커지면 컨텍스트 윈도우를 잡아먹어요. CLAUDE.md에 "메모리 로딩 시 전체 컨텍스트의 20% 이내로 유지"같은 규칙을 넣어두면 좋아요.

**2. 결정 기록은 구조화하세요**

"Svelte 쓰기로 함"보다 "결정/대안/근거/영향"을 적어두면, 나중에 AI가 왜 그 결정을 했는지 맥락을 정확히 이해해요.

**3. 주기적으로 메모리를 정리하세요**

매주 한 번 `compact` 명령으로 오래된 로그를 요약하세요. 컨텍스트 윈도우를 아끼면서도 중요한 맥락은 유지할 수 있어요.

**4. 메모리 우선순위를 명시하세요**

CLAUDE.md에 "decisions.md가 MEMORY.md보다 우선"처럼 충돌 해결 규칙을 적어두면, AI가 모순된 정보를 만났을 때 올바른 판단을 해요.

## 확장 아이디어

- **벡터 검색 통합:** 메모리가 많아지면 키워드 기반 로딩 대신 임베딩 기반 검색으로 관련 메모리만 로드
- **팀 공유 메모리:** `MEMORY.md`는 개인용, `TEAM-MEMORY.md`는 팀 공유용으로 분리
- **자동 회고:** 주간 단위로 AI가 메모리를 분석해서 패턴과 개선점을 제안

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
