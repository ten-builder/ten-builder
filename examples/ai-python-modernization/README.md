# AI 에이전트 기반 Python 프로젝트 현대화 예제 — uv, Ruff, pyproject.toml 완전 전환

> pip + requirements.txt 기반 레거시 Python 프로젝트를 uv, Ruff, pyproject.toml 스택으로 전환하는 AI 에이전트 자동화 예제

## 이 예제에서 배울 수 있는 것

- pip/virtualenv + requirements.txt → uv + pyproject.toml 마이그레이션 전 과정
- flake8 + black + isort → Ruff 단일 도구 통합
- AI 에이전트로 기존 코드베이스를 분석하고 변환 작업을 자동화하는 패턴
- 마이그레이션 전후 동작 동등성 검증 방법

## 프로젝트 구조

```
ai-python-modernization/
├── legacy/                    # 마이그레이션 전 상태 (예시)
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   ├── setup.py
│   ├── .flake8
│   └── src/
├── modern/                    # 마이그레이션 후 상태 (목표)
│   ├── pyproject.toml
│   ├── uv.lock
│   └── src/
├── scripts/
│   ├── analyze.sh             # 현재 환경 분석
│   ├── migrate.sh             # 마이그레이션 실행
│   └── verify.sh              # 동등성 검증
└── README.md
```

## 시작하기

### 사전 준비

```bash
# uv 설치
curl -LsSf https://astral.sh/uv/install.sh | sh

# 또는 Homebrew로 설치
brew install uv

# 버전 확인
uv --version
# uv 0.6+ 기준
```

### Step 1: 기존 환경 분석

AI 에이전트에게 현재 프로젝트 상태를 분석하도록 지시합니다.

```bash
# 현재 의존성 목록 추출
pip freeze > requirements-snapshot.txt

# 직접 의존성과 전이적 의존성 분리
cat requirements.txt

# 사용 중인 Python 버전 확인
python --version
```

분석 후 AI 에이전트가 생성하는 `migration-plan.md`:

```markdown
## 마이그레이션 계획

### 직접 의존성 (pyproject.toml에 추가)
- fastapi==0.115.0
- sqlalchemy==2.0.36
- pydantic==2.9.2

### 개발 의존성 (dev 그룹)
- pytest==8.3.3
- httpx==0.27.2

### 제거 대상 (전이적 의존성)
- starlette (fastapi에 포함)
- anyio (httpx에 포함)
```

### Step 2: pyproject.toml 생성

```bash
# 새 uv 프로젝트 초기화
uv init --python 3.12

# 또는 기존 디렉토리에서 초기화
uv init
```

AI 에이전트가 생성하는 `pyproject.toml`:

```toml
[project]
name = "my-app"
version = "0.1.0"
description = "A modern Python application"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115.0",
    "sqlalchemy>=2.0.36",
    "pydantic>=2.9.2",
    "uvicorn>=0.32.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3.3",
    "pytest-asyncio>=0.24.0",
    "httpx>=0.27.2",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
extend-select = [
    "F",    # Pyflakes
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "I",    # isort
    "UP",   # pyupgrade — 구문 현대화
    "B",    # flake8-bugbear
    "C4",   # flake8-comprehensions
    "N",    # pep8-naming
]
extend-ignore = ["E501"]  # 라인 길이는 formatter가 처리

[tool.ruff.format]
quote-style = "double"

[tool.ruff.lint.isort]
known-first-party = ["my_app"]
```

### Step 3: 의존성 설치 및 락 파일 생성

```bash
# 의존성 설치 + uv.lock 생성
uv sync

# 개발 의존성 포함
uv sync --extra dev

# 특정 패키지 추가
uv add httpx

# 개발 의존성 추가
uv add --dev pytest-cov
```

### Step 4: Ruff로 코드 정리

```bash
# 린팅 오류 확인
uv run ruff check .

# 자동 수정 가능한 오류 처리
uv run ruff check --fix .

# 코드 포매팅
uv run ruff format .

# 변경 사항 미리 확인
uv run ruff format --check .
```

### Step 5: 기존 도구 제거

```bash
# 불필요해진 설정 파일 삭제
rm -f .flake8 setup.cfg .isort.cfg

# setup.py가 단순 메타데이터용이라면 삭제
# (pyproject.toml로 대체됨)
rm -f setup.py

# 기존 requirements 파일은 참조용으로 보관하거나 삭제
mv requirements.txt requirements.txt.bak
```

### Step 6: 스크립트 실행 방식 변경

```bash
# 기존 방식 (virtualenv 활성화 필요)
source venv/bin/activate
python main.py

# uv 방식 (활성화 불필요)
uv run python main.py

# 또는 간단하게
uv run main.py
```

## 핵심 코드

### 마이그레이션 자동화 스크립트

```bash
#!/bin/bash
# scripts/migrate.sh

set -e

echo "1. 현재 의존성 스냅샷 저장..."
pip freeze > /tmp/requirements-snapshot.txt

echo "2. uv 초기화..."
uv init --python 3.12 --no-readme 2>/dev/null || true

echo "3. requirements.txt에서 직접 의존성 추출 및 추가..."
# AI 에이전트가 분석한 직접 의존성만 추가
while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    uv add "$line"
done < requirements.txt

echo "4. Ruff 설치..."
uv add --dev ruff

echo "5. 코드 정리 실행..."
uv run ruff check --fix .
uv run ruff format .

echo "마이그레이션 완료!"
echo "uv sync 후 uv run python -m pytest 로 테스트 확인하세요."
```

### CI/CD 파이프라인 (GitHub Actions)

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: uv 설치
        uses: astral-sh/setup-uv@v4
        with:
          version: "latest"

      - name: 의존성 설치
        run: uv sync --extra dev

      - name: Ruff 린팅
        run: uv run ruff check .

      - name: Ruff 포매팅 확인
        run: uv run ruff format --check .

      - name: 테스트 실행
        run: uv run pytest
```

**왜 이렇게 했나요?**

`setup-uv` 공식 GitHub Action을 사용하면 uv를 빠르게 설치하고 `uv.lock`을 활용한 재현 가능한 빌드를 만들 수 있어요. pip 대비 의존성 설치 속도가 10~100배 빠르기 때문에 CI 실행 시간이 눈에 띄게 줄어들어요.

## 마이그레이션 전후 비교

| 항목 | 이전 (pip + 개별 도구) | 이후 (uv + Ruff) |
|------|------------------------|------------------|
| 패키지 설치 | pip install (느림) | uv sync (10-100배 빠름) |
| 린팅 | flake8 + pylint | ruff check (한 번에 처리) |
| 포매팅 | black | ruff format |
| import 정렬 | isort | ruff check --select I |
| 설정 파일 | .flake8, setup.cfg, ... | pyproject.toml 하나 |
| 락 파일 | requirements.txt (부정확) | uv.lock (정확한 버전 고정) |
| 가상환경 | 수동 활성화 필요 | uv run으로 자동 처리 |

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 의존성 분석 | `requirements.txt에서 직접 의존성과 전이적 의존성을 분리하고 pyproject.toml 형식으로 변환해줘` |
| Ruff 규칙 설정 | `현재 .flake8 설정을 읽고 동일한 규칙을 pyproject.toml [tool.ruff.lint] 섹션으로 변환해줘` |
| 오류 수정 | `ruff check 결과를 보고 수동 수정이 필요한 항목만 골라서 코드 수정해줘` |
| CI 최적화 | `GitHub Actions에서 uv cache를 활용해 빌드 시간을 줄이는 설정을 추가해줘` |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
