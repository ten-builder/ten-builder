# PydanticAI 실전 가이드 2026 — 타입 안전 에이전트 프레임워크 제대로 쓰기

> Python 생태계의 검증 표준인 Pydantic 팀이 만든 에이전트 프레임워크 — 타입 안전성과 검증을 AI 에이전트에도 그대로 가져왔다.

## 왜 PydanticAI인가

FastAPI, OpenAI SDK, 수백 개의 Python 라이브러리 밑에 깔린 데이터 검증 엔진이 Pydantic이다. PydanticAI는 같은 철학으로 에이전트를 만든다 — 구조화된 출력, 런타임 검증, IDE 자동완성, 타입 힌트 기반 개발.

LangGraph는 상태 그래프가 복잡하고, CrewAI는 역할 기반이지만 타입 안전성이 약하다. PydanticAI는 Python 개발자가 이미 아는 방식 그대로 에이전트를 작성한다.

## 설치

```bash
pip install pydantic-ai

# 추가 모델 지원
pip install pydantic-ai[anthropic]   # Claude
pip install pydantic-ai[openai]      # GPT
pip install pydantic-ai[google]      # Gemini
```

## 핵심 개념

| 개념 | 역할 |
|------|------|
| `Agent` | 에이전트 인스턴스, 모델과 도구 바인딩 |
| `@agent.tool` | 에이전트가 호출할 수 있는 함수 |
| `RunContext` | 에이전트 실행 중 공유 의존성 주입 |
| `result_type` | 구조화된 출력 Pydantic 모델 |
| `ModelRetry` | 검증 실패 시 모델에 재시도 요청 |

## 기본 에이전트 만들기

```python
from pydantic_ai import Agent

agent = Agent(
    "anthropic:claude-sonnet-4-5",
    system_prompt="당신은 Python 코드 리뷰 전문가입니다.",
)

result = agent.run_sync("이 코드에서 개선점을 찾아줘: for i in range(len(lst)): print(lst[i])")
print(result.data)
```

## 구조화된 출력 — 타입 안전성의 핵심

```python
from pydantic import BaseModel
from pydantic_ai import Agent

class CodeReview(BaseModel):
    severity: str          # "critical" | "warning" | "info"
    issue: str
    suggestion: str
    example: str

class ReviewResult(BaseModel):
    reviews: list[CodeReview]
    overall_score: int     # 0-100
    summary: str

agent = Agent(
    "anthropic:claude-sonnet-4-5",
    result_type=ReviewResult,
    system_prompt="Python 코드를 분석하고 구체적인 개선 사항을 제시하세요.",
)

result = agent.run_sync("""
def get_user(db, id):
    users = db.query("SELECT * FROM users")
    for u in users:
        if u['id'] == id:
            return u
""")

# result.data는 ReviewResult 타입 — IDE 자동완성 지원
print(f"점수: {result.data.overall_score}")
for review in result.data.reviews:
    print(f"[{review.severity}] {review.issue}")
    print(f"  제안: {review.suggestion}")
```

## 도구(Tool) 연결

```python
from pydantic_ai import Agent, RunContext
import httpx

agent = Agent(
    "anthropic:claude-sonnet-4-5",
    system_prompt="GitHub 레포지터리 정보를 조회하고 분석합니다.",
)

@agent.tool_plain
def get_repo_info(repo: str) -> dict:
    """GitHub 레포지터리 기본 정보를 가져옵니다."""
    response = httpx.get(f"https://api.github.com/repos/{repo}")
    data = response.json()
    return {
        "stars": data["stargazers_count"],
        "forks": data["forks_count"],
        "language": data["language"],
        "description": data["description"],
        "open_issues": data["open_issues_count"],
    }

@agent.tool_plain
def get_recent_commits(repo: str, limit: int = 5) -> list[dict]:
    """최근 커밋 목록을 가져옵니다."""
    response = httpx.get(
        f"https://api.github.com/repos/{repo}/commits",
        params={"per_page": limit}
    )
    return [
        {"sha": c["sha"][:7], "message": c["commit"]["message"][:80]}
        for c in response.json()
    ]

result = agent.run_sync("ten-builder/ten-builder 레포를 분석해줘")
print(result.data)
```

## 의존성 주입 — RunContext 활용

```python
from dataclasses import dataclass
from pydantic_ai import Agent, RunContext

@dataclass
class AppContext:
    db_connection: str
    user_id: str
    api_key: str

agent = Agent(
    "anthropic:claude-sonnet-4-5",
    deps_type=AppContext,
    system_prompt="사용자 데이터를 분석하고 개인화된 응답을 제공합니다.",
)

@agent.tool
async def get_user_history(ctx: RunContext[AppContext], limit: int = 10) -> list[dict]:
    """현재 사용자의 최근 활동 이력을 조회합니다."""
    # ctx.deps로 주입된 의존성에 접근
    user_id = ctx.deps.user_id
    # 실제로는 DB 쿼리
    return [{"action": f"action_{i}", "user_id": user_id} for i in range(limit)]

# 실행 시 의존성 주입
ctx = AppContext(
    db_connection="postgresql://...",
    user_id="user_123",
    api_key="sk-..."
)
result = agent.run_sync("내 최근 활동을 요약해줘", deps=ctx)
```

## 멀티 에이전트 파이프라인

```python
from pydantic import BaseModel
from pydantic_ai import Agent

# 1단계: 코드 분석 에이전트
class AnalysisResult(BaseModel):
    has_security_issues: bool
    performance_issues: list[str]
    code_smells: list[str]

analyzer = Agent(
    "anthropic:claude-sonnet-4-5",
    result_type=AnalysisResult,
    system_prompt="코드의 보안, 성능, 품질 문제를 분석합니다.",
)

# 2단계: 수정 에이전트
class FixResult(BaseModel):
    fixed_code: str
    changes_made: list[str]
    explanation: str

fixer = Agent(
    "anthropic:claude-sonnet-4-5",
    result_type=FixResult,
    system_prompt="분석된 문제를 바탕으로 코드를 개선합니다.",
)

async def review_and_fix(code: str) -> FixResult:
    # 1단계: 분석
    analysis = await analyzer.run(f"다음 코드를 분석하세요:\n```python\n{code}\n```")

    if not (analysis.data.has_security_issues or analysis.data.performance_issues):
        return FixResult(
            fixed_code=code,
            changes_made=[],
            explanation="개선이 필요하지 않습니다."
        )

    # 2단계: 수정 (분석 결과를 컨텍스트로 전달)
    issues_summary = f"""
    보안 이슈: {analysis.data.has_security_issues}
    성능 문제: {', '.join(analysis.data.performance_issues)}
    코드 스멜: {', '.join(analysis.data.code_smells)}
    """

    fix = await fixer.run(
        f"문제:\n{issues_summary}\n\n원본 코드:\n```python\n{code}\n```"
    )
    return fix.data
```

## LangGraph vs CrewAI vs PydanticAI 선택 기준

| 기준 | PydanticAI | LangGraph | CrewAI |
|------|-----------|-----------|--------|
| 타입 안전성 | ✅ 최상 | 보통 | 약함 |
| 학습 곡선 | 낮음 | 높음 | 낮음 |
| 상태 관리 | 기본 | ✅ 최상 | 보통 |
| 역할 기반 에이전트 | 직접 구성 | 직접 구성 | ✅ 내장 |
| FastAPI 통합 | ✅ 자연스러움 | 복잡 | 보통 |
| 프로덕션 검증 | ✅ Pydantic 기반 | 별도 처리 | 별도 처리 |
| 멀티 LLM | ✅ 지원 | ✅ 지원 | ✅ 지원 |

**선택 가이드:**
- **PydanticAI** → FastAPI 기반 백엔드, 구조화된 출력이 중요한 경우, Python 타입을 선호하는 팀
- **LangGraph** → 복잡한 상태 머신, 인간-에이전트 협업, 체크포인트가 필요한 경우
- **CrewAI** → 빠른 프로토타이핑, 역할 기반 팀 구성, 비기술 팀과 협업

## FastAPI와 통합

```python
from fastapi import FastAPI
from pydantic import BaseModel
from pydantic_ai import Agent

app = FastAPI()

class ReviewRequest(BaseModel):
    code: str
    language: str = "python"

class ReviewResponse(BaseModel):
    score: int
    issues: list[str]
    suggestions: list[str]

review_agent = Agent(
    "anthropic:claude-sonnet-4-5",
    result_type=ReviewResponse,
    system_prompt="코드 품질을 분석하고 개선 사항을 제시합니다.",
)

@app.post("/review")
async def review_code(request: ReviewRequest) -> ReviewResponse:
    result = await review_agent.run(
        f"다음 {request.language} 코드를 리뷰해주세요:\n```{request.language}\n{request.code}\n```"
    )
    return result.data
```

## 흔한 실수와 해결법

| 실수 | 해결 |
|------|------|
| result_type 없이 구조화된 데이터 파싱 | `result_type=MyModel` 명시 |
| 동기 컨텍스트에서 `await agent.run()` | `agent.run_sync()` 사용 |
| 도구 함수에 타입 힌트 누락 | 모든 파라미터에 타입 힌트 필수 |
| deps_type 설정 없이 RunContext 사용 | `Agent(deps_type=MyDeps)` 먼저 설정 |
| 재시도 없이 모델 오류 처리 | `result_retries=3` 옵션 활용 |

## 검증 실패 시 재시도

```python
from pydantic import BaseModel, field_validator
from pydantic_ai import Agent, ModelRetry

class StrictResult(BaseModel):
    score: int
    grade: str

    @field_validator("score")
    @classmethod
    def validate_score(cls, v: int) -> int:
        if not 0 <= v <= 100:
            raise ValueError(f"점수는 0-100 사이여야 합니다: {v}")
        return v

    @field_validator("grade")
    @classmethod
    def validate_grade(cls, v: str) -> str:
        valid = {"A", "B", "C", "D", "F"}
        if v not in valid:
            raise ModelRetry(f"등급은 {valid} 중 하나여야 합니다")
        return v

agent = Agent(
    "anthropic:claude-sonnet-4-5",
    result_type=StrictResult,
    result_retries=3,   # 검증 실패 시 최대 3회 재시도
)
```

## 체크리스트

- [ ] 구조화된 출력에 `result_type` Pydantic 모델 정의
- [ ] 도구 함수에 타입 힌트와 docstring 작성
- [ ] 의존성을 `deps_type`으로 주입, 하드코딩 금지
- [ ] 비동기 환경에서 `await agent.run()` 사용
- [ ] `result_retries`로 검증 실패 재시도 설정
- [ ] 여러 단계의 워크플로우는 에이전트를 분리하여 구성

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
