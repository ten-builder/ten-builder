# CrewAI 실전 가이드 2026 — 멀티에이전트 팀을 코드로 만들기

> 역할 기반 에이전트 협업 프레임워크 CrewAI — 설치부터 프로덕션 배포까지

## CrewAI란

CrewAI는 여러 AI 에이전트에게 역할을 부여하고 협업시키는 Python 프레임워크입니다. 2026년 현재 월 1.5만 회 이상 검색되는 가장 빠르게 성장 중인 멀티에이전트 라이브러리로, Claude API, GPT-4, Gemini 등 다양한 LLM과 연동할 수 있어요.

단일 에이전트가 하나의 거대한 프롬프트를 처리하는 방식 대신, CrewAI는 **전문가 팀**처럼 에이전트를 구성합니다.

```python
# 한눈에 보는 CrewAI 구조
Crew(
    agents=[researcher, analyst, writer],  # 역할 분담
    tasks=[research_task, analysis_task, write_task],  # 순서 정의
    process=Process.sequential  # 또는 hierarchical
)
```

## 핵심 개념 4가지

| 개념 | 설명 |
|------|------|
| **Agent** | 역할(role), 목표(goal), 배경(backstory)을 가진 AI 실행 단위 |
| **Task** | 에이전트가 수행할 구체적인 작업 — 기대 결과물 포함 |
| **Tool** | 에이전트가 사용할 수 있는 능력 — 웹 검색, 파일 읽기 등 |
| **Crew** | 에이전트와 태스크를 묶어 워크플로우를 실행하는 오케스트레이터 |

## 설치 및 기본 설정

```bash
pip install crewai[tools]

# .env 파일 설정
OPENAI_API_KEY=sk-...      # GPT-4 사용 시
ANTHROPIC_API_KEY=sk-...   # Claude 사용 시
SERPER_API_KEY=...         # 웹 검색 도구 사용 시
```

CrewAI는 기본적으로 OpenAI를 사용하지만, Claude API로 전환하는 것도 간단해요.

```python
from crewai import Agent
from langchain_anthropic import ChatAnthropic

claude = ChatAnthropic(model="claude-sonnet-4-5")

agent = Agent(
    role="Senior Software Engineer",
    goal="Review code and suggest improvements",
    backstory="10년 경력의 시니어 엔지니어, TypeScript와 Python 전문",
    llm=claude,
    verbose=True
)
```

## Step 1: 첫 번째 Crew 만들기

코드 리뷰 Crew를 만들어 보겠습니다.

```python
from crewai import Agent, Task, Crew, Process
from crewai_tools import FileReadTool

# 도구 설정
file_tool = FileReadTool()

# 에이전트 정의
reviewer = Agent(
    role="Code Reviewer",
    goal="코드 품질, 보안 취약점, 성능 문제를 철저히 검토한다",
    backstory="보안과 성능 최적화 전문 시니어 개발자",
    tools=[file_tool],
    verbose=True
)

documenter = Agent(
    role="Technical Writer",
    goal="리뷰 결과를 명확하고 실행 가능한 보고서로 작성한다",
    backstory="개발팀과 비개발팀 모두가 이해할 수 있는 문서를 작성하는 전문가",
    verbose=True
)

# 태스크 정의
review_task = Task(
    description="다음 파일을 분석하세요: {file_path}. 보안 취약점, 코드 품질, 성능 문제를 확인하세요.",
    expected_output="발견된 문제 목록, 심각도 분류, 구체적인 개선 방안",
    agent=reviewer
)

report_task = Task(
    description="리뷰 결과를 개발팀이 바로 적용할 수 있는 액션 아이템 형식으로 정리하세요.",
    expected_output="우선순위별 수정 항목 목록과 예제 코드",
    agent=documenter,
    context=[review_task]  # 이전 태스크 결과를 컨텍스트로 활용
)

# Crew 조합
crew = Crew(
    agents=[reviewer, documenter],
    tasks=[review_task, report_task],
    process=Process.sequential,
    verbose=True
)

# 실행
result = crew.kickoff(inputs={"file_path": "src/auth/login.py"})
print(result)
```

## Step 2: 계층형 프로세스 (Hierarchical)

복잡한 작업에는 관리자 에이전트가 워커를 자동으로 배분하는 계층형 구조가 적합해요.

```python
from crewai import Agent, Task, Crew, Process

manager = Agent(
    role="Engineering Manager",
    goal="작업을 분석하고 적절한 전문가에게 배분한다",
    backstory="팀 전체를 조율하는 테크 리드",
    allow_delegation=True  # 위임 허용
)

backend_dev = Agent(
    role="Backend Developer",
    goal="API와 데이터베이스 레이어를 구현한다",
    backstory="FastAPI와 PostgreSQL 전문가"
)

frontend_dev = Agent(
    role="Frontend Developer",
    goal="UI 컴포넌트와 상태 관리를 구현한다",
    backstory="React와 TypeScript 전문가"
)

# 계층형 Crew — 관리자가 태스크를 자동 배분
crew = Crew(
    agents=[backend_dev, frontend_dev],
    tasks=[...],
    process=Process.hierarchical,
    manager_agent=manager
)
```

## Step 3: Flows — 이벤트 기반 파이프라인

여러 Crew를 연결하는 복잡한 파이프라인은 CrewAI Flows를 사용해요.

```python
from crewai.flow.flow import Flow, listen, start
from pydantic import BaseModel

class DevelopmentState(BaseModel):
    requirements: str = ""
    design: str = ""
    code: str = ""
    tests: str = ""

class DevFlow(Flow[DevelopmentState]):
    
    @start()
    def analyze_requirements(self):
        # 요구사항 분석 Crew 실행
        result = requirements_crew.kickoff(
            inputs={"requirements": self.state.requirements}
        )
        self.state.design = result.raw
        return result
    
    @listen(analyze_requirements)
    async def implement(self, design):
        # 구현 Crew 실행
        result = await implementation_crew.kickoff_async(
            inputs={"design": self.state.design}
        )
        self.state.code = result.raw
        return result
    
    @listen(implement)
    async def write_tests(self, code):
        # 테스트 작성 Crew 실행
        result = await testing_crew.kickoff_async(
            inputs={"code": self.state.code}
        )
        self.state.tests = result.raw
        return result

# Flow 실행
flow = DevFlow()
flow.kickoff(inputs={"requirements": "사용자 인증 API 구현"})
```

## Step 4: 프로덕션 배포 — FastAPI 래핑

```python
from fastapi import FastAPI, BackgroundTasks
from pydantic import BaseModel
import asyncio

app = FastAPI()

class CrewRequest(BaseModel):
    task: str
    context: dict = {}

@app.post("/run-crew")
async def run_crew(request: CrewRequest, background_tasks: BackgroundTasks):
    job_id = str(uuid.uuid4())
    
    # 백그라운드에서 비동기 실행
    background_tasks.add_task(
        execute_crew_async,
        job_id=job_id,
        task=request.task,
        context=request.context
    )
    
    return {"job_id": job_id, "status": "started"}

@app.get("/job/{job_id}")
async def get_job_status(job_id: str):
    return job_store.get(job_id, {"status": "not_found"})

async def execute_crew_async(job_id: str, task: str, context: dict):
    try:
        result = await code_review_crew.kickoff_async(
            inputs={"task": task, **context}
        )
        job_store[job_id] = {"status": "completed", "result": result.raw}
    except Exception as e:
        job_store[job_id] = {"status": "failed", "error": str(e)}
```

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| 에이전트 backstory 부실 | 구체적인 배경과 전문 분야를 상세히 작성 — LLM의 페르소나에 영향 |
| Task expected_output 미지정 | 항상 명확한 출력 형식 명시 — 다음 에이전트가 파싱 가능해야 함 |
| 모든 태스크를 sequential로 | 독립 태스크는 async_execution=True로 병렬화 |
| 프로덕션에서 verbose=True | 성능 저하 — 프로덕션은 verbose=False |
| 도구 오류 처리 생략 | handle_parsing_errors=True 설정 필수 |

## Claude Code와의 역할 분담

| 상황 | 추천 |
|------|------|
| 코드베이스 탐색 + 구현 | Claude Code |
| 데이터 분석 + 리포트 생성 파이프라인 | CrewAI |
| PR 리뷰 + CI 연동 | Claude Code |
| 외부 API 조합 + 자동화 워크플로우 | CrewAI |
| 터미널 에이전트 작업 | Claude Code |
| 비개발 도메인 (마케팅, 리서치) | CrewAI |

CrewAI는 비개발 도메인을 포함한 범용 자동화에 강하고, Claude Code는 코드베이스 이해와 개발 워크플로우에 특화되어 있어요. 두 도구를 조합하면 개발부터 배포까지 전 과정을 자동화할 수 있어요.

## 체크리스트

- [ ] `crewai[tools]` 설치 및 API 키 설정
- [ ] 에이전트별 role/goal/backstory 구체화
- [ ] Task에 expected_output 명확히 지정
- [ ] 독립 태스크는 async_execution=True로 병렬화
- [ ] 프로덕션 배포 시 FastAPI + 비동기 실행 적용
- [ ] 로깅과 오류 처리 설정

## 다음 단계

→ [오케스트레이터-워커 패턴 심화 가이드](./58-ai-agent-orchestrator-patterns.md)  
→ [LangGraph 멀티에이전트 워크플로우 실전 가이드](./114-langgraph-multi-agent-workflow-guide-2026.md)  
→ [OpenAI Agents SDK 실전 가이드](./103-openai-agents-sdk-practical-guide-2026.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)  
**YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
