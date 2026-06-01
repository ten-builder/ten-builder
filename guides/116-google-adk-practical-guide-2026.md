# Google ADK 실전 가이드 2026 — 오픈소스 멀티에이전트 프레임워크 제대로 쓰기

> Google이 만든 오픈소스 에이전트 프레임워크 ADK로 멀티에이전트 시스템을 구축하는 방법 — 설치부터 Vertex AI 배포, Claude Code와의 역할 분담까지

## ADK란

Google Agent Development Kit(ADK)는 AI 에이전트를 구축하고 평가하고 배포하기 위한 오픈소스 Python 프레임워크다. 2025년 출시 이후 2026년 상반기에 v1.25까지 업데이트되며 멀티에이전트 오케스트레이션, 네이티브 MCP 지원, OpenTelemetry 연동이 추가됐다.

**ADK의 특징:**

- 계층형 에이전트 트리 구조로 복잡한 오케스트레이션 지원
- Gemini 모델 최적화, 단일 LLM 의존 없이 멀티 모델 사용 가능
- `adk web` 명령어로 로컬 UI에서 에이전트 테스트
- Vertex AI Agent Engine 또는 Cloud Run으로 배포
- 내장 평가 프레임워크로 에이전트 품질 측정

## 소요 시간

첫 에이전트: 15분  
멀티에이전트 시스템: 1~2시간  
Vertex AI 배포: 30분 추가

## 사전 준비

- Python 3.10 이상
- Google Cloud 계정 (Vertex AI 배포 시)
- `GOOGLE_API_KEY` 또는 `GOOGLE_CLOUD_PROJECT` 설정

## Step 1: 설치 및 기본 에이전트 구성

```bash
pip install google-adk

# 프로젝트 초기화
mkdir my-agent-project && cd my-agent-project
adk create my_agent
```

`my_agent/agent.py` 기본 구조:

```python
from google.adk.agents import Agent
from google.adk.tools import google_search

# 기본 에이전트 정의
root_agent = Agent(
    name="my_agent",
    model="gemini-2.0-flash",
    description="코드 분석 및 문서화를 담당하는 AI 에이전트",
    instruction="""
    당신은 코드베이스를 분석하고 명확한 문서를 작성하는 에이전트입니다.
    코드를 이해하고 개발자 친화적인 설명을 제공하세요.
    """,
    tools=[google_search],
)
```

로컬에서 실행:

```bash
# 웹 UI로 테스트
adk web

# CLI에서 바로 실행
adk run my_agent --message "이 함수를 설명해줘"
```

## Step 2: 도구 연동 및 커스텀 툴 작성

ADK의 도구는 일반 Python 함수에 타입 힌트만 추가하면 된다.

```python
from google.adk.agents import Agent

def analyze_code(file_path: str, language: str = "python") -> dict:
    """
    코드 파일을 분석하고 품질 리포트를 반환합니다.
    
    Args:
        file_path: 분석할 파일 경로
        language: 프로그래밍 언어 (기본값: python)
    
    Returns:
        분석 결과 딕셔너리
    """
    # 실제 분석 로직
    return {
        "complexity": "medium",
        "issues": ["긴 함수", "중복 코드"],
        "suggestions": ["함수 분리 권장"]
    }

def write_documentation(code_analysis: dict, output_path: str) -> str:
    """분석 결과를 기반으로 문서를 생성합니다."""
    # 문서 생성 로직
    return f"문서 생성 완료: {output_path}"

code_agent = Agent(
    name="code_analyzer",
    model="gemini-2.0-flash",
    tools=[analyze_code, write_documentation],
    instruction="코드 파일을 분석하고 문서를 작성하는 에이전트입니다."
)
```

## Step 3: 멀티에이전트 시스템 구성

ADK의 핵심은 계층형 에이전트 트리다. 오케스트레이터가 서브에이전트에 태스크를 위임한다.

```python
from google.adk.agents import Agent

# 분석 담당 서브에이전트
analyzer_agent = Agent(
    name="analyzer",
    model="gemini-2.0-flash",
    description="코드 품질 분석 전문 에이전트",
    instruction="코드를 상세히 분석하고 결과를 구조화된 형식으로 반환하세요.",
    tools=[analyze_code],
)

# 문서화 담당 서브에이전트
doc_agent = Agent(
    name="documenter",
    model="gemini-2.0-flash",
    description="기술 문서 작성 전문 에이전트",
    instruction="코드 분석 결과를 바탕으로 개발자 문서를 작성하세요.",
    tools=[write_documentation],
)

# 리뷰 담당 서브에이전트
review_agent = Agent(
    name="reviewer",
    model="gemini-2.5-pro",  # 리뷰는 더 정교한 모델 사용
    description="코드 리뷰 및 개선 제안 전문 에이전트",
    instruction="분석 결과와 문서를 검토하고 개선점을 제안하세요.",
)

# 오케스트레이터 — 서브에이전트 등록
root_agent = Agent(
    name="code_pipeline",
    model="gemini-2.0-flash",
    description="코드 분석부터 문서화까지 전체 파이프라인 조율",
    instruction="""
    사용자 요청에 따라 적절한 서브에이전트에 태스크를 위임하세요.
    1. 코드 분석 → analyzer 에이전트
    2. 문서 작성 → documenter 에이전트
    3. 최종 검토 → reviewer 에이전트
    """,
    sub_agents=[analyzer_agent, doc_agent, review_agent],
)
```

실행:

```bash
adk run code_pipeline --message "src/api.py 파일을 분석하고 문서를 만들어줘"
```

## Step 4: MCP 서버 연동

ADK v1.25부터 MCP를 네이티브로 지원한다.

```python
from google.adk.agents import Agent
from google.adk.tools.mcp_tool import MCPToolset, StdioServerParameters

# MCP 서버 연결 (예: GitHub MCP)
mcp_toolset = MCPToolset(
    connection_params=StdioServerParameters(
        command="npx",
        args=["-y", "@modelcontextprotocol/server-github"],
        env={"GITHUB_TOKEN": "your-token"}
    )
)

github_agent = Agent(
    name="github_agent",
    model="gemini-2.0-flash",
    tools=[mcp_toolset],
    instruction="GitHub 레포지터리 작업을 처리하는 에이전트입니다."
)
```

## Step 5: Vertex AI 배포

로컬 개발이 완료되면 Vertex AI Agent Engine에 배포한다.

```bash
# Google Cloud 인증
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# ADK 배포
adk deploy --project YOUR_PROJECT_ID --region asia-northeast3
```

Python 코드에서 직접 배포:

```python
import vertexai
from vertexai.preview import reasoning_engines

vertexai.init(project="YOUR_PROJECT_ID", location="asia-northeast3")

# 에이전트를 Vertex AI에 래핑
app = reasoning_engines.AdkApp(agent=root_agent, enable_tracing=True)

# 배포
remote_app = reasoning_engines.ReasoningEngine.create(
    app,
    requirements=["google-adk>=1.25.0"],
    display_name="code-pipeline-agent",
)

# 배포된 에이전트 호출
session = remote_app.create_session(user_id="developer-1")
response = remote_app.stream_query(
    user_id="developer-1",
    session_id=session["id"],
    message="src/ 폴더 전체를 분석해줘"
)
```

## ADK vs 다른 프레임워크

| 항목 | ADK | OpenAI Agents SDK | Claude Agent SDK |
|------|-----|-------------------|------------------|
| 멀티에이전트 구조 | 계층형 트리 | 핸드오프 기반 | 서브에이전트 격리 |
| 모델 의존 | Gemini 최적화 | GPT 최적화 | Claude 최적화 |
| 배포 타깃 | Vertex AI | OpenAI 플랫폼 | 자체 인프라 |
| MCP 지원 | 네이티브 (v1.25) | 지원 | 네이티브 |
| 내장 평가 | 있음 | 제한적 | 있음 |
| 오픈소스 | 예 | 예 | 예 |

## Claude Code와의 역할 분담

ADK와 Claude Code는 경쟁 관계가 아니다. 용도가 다르다.

| 상황 | 추천 도구 |
|------|----------|
| 코드 작성·수정 | Claude Code |
| 프로덕션 에이전트 파이프라인 | ADK + Vertex AI |
| 내부 개발 자동화 | Claude Code |
| GCP 인프라 연동 워크플로우 | ADK |
| 빠른 프로토타입 | 둘 다 가능 |

**실전 조합:**
1. Claude Code로 ADK 에이전트 코드를 작성
2. `adk web`으로 로컬 테스트
3. ADK로 Vertex AI에 배포하여 프로덕션 운영

## 체크리스트

- [ ] Python 3.10 이상 설치
- [ ] `pip install google-adk` 완료
- [ ] `adk web`으로 로컬 UI 실행 확인
- [ ] 커스텀 도구 타입 힌트 + docstring 작성
- [ ] 오케스트레이터에 서브에이전트 등록
- [ ] MCP 서버 연결 테스트
- [ ] Vertex AI 프로젝트 ID 설정
- [ ] 배포 후 `remote_app.stream_query()` 동작 확인

## 더 알아보기

- [ADK 공식 문서](https://google.github.io/adk-docs/)
- [Vertex AI Agent Engine 가이드](https://cloud.google.com/vertex-ai/generative-ai/docs/agent-engine)
- [ADK GitHub](https://github.com/google/adk-python)

---

**더 자세한 에이전트 가이드:** [guides/103-openai-agents-sdk-practical-guide-2026.md](./103-openai-agents-sdk-practical-guide-2026.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
