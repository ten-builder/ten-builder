# OpenAI Agents SDK 실전 가이드 2026 — 프로덕션 AI 에이전트 제대로 만들기

> 2026년 4월 대규모 업데이트로 SandboxAgent, 네이티브 MCP 지원, 서브에이전트를 갖춘 OpenAI Agents SDK — 설치부터 프로덕션 배포까지 실전 중심으로 정리합니다.

## SDK 소개

OpenAI Agents SDK는 AI 에이전트를 코드로 구성하는 경량 프레임워크입니다. 2026년 4월 v0.15.1 이후 세 가지 핵심 기능이 추가되었습니다.

- **SandboxAgent**: 격리된 파일시스템과 셸 접근을 에이전트에 제공
- **서브에이전트 핸드오프**: 에이전트 간 작업 위임을 코드 한 줄로 구현
- **MCP 1등 지원**: 외부 도구를 표준 프로토콜로 연결

LangChain처럼 추상화가 무겁지 않고, Claude Code처럼 터미널에 종속되지 않습니다. 어떤 LLM 백엔드(100개 이상 지원)와도 연결 가능하며, 복잡한 멀티에이전트 파이프라인을 Python 코드로 명시적으로 설계할 수 있습니다.

## 설치 및 기본 설정

```bash
pip install openai-agents
export OPENAI_API_KEY="your-key"
```

Claude나 Gemini를 백엔드로 쓰려면:

```bash
pip install openai-agents anthropic
```

```python
from agents import Agent, ModelSettings

# Claude 백엔드 사용
agent = Agent(
    name="코드 리뷰어",
    model="claude-opus-4-7",
    instructions="코드를 검토하고 개선점을 한국어로 설명하세요.",
    model_settings=ModelSettings(temperature=0.3),
)
```

## 기본 에이전트 만들기

### Step 1: 단순 에이전트

```python
from agents import Agent, Runner

reviewer = Agent(
    name="PR 리뷰어",
    instructions="""
    PR 코드를 검토합니다.
    - 버그 가능성이 있는 부분 찾기
    - 성능 개선 포인트 제안
    - 보안 취약점 확인
    모든 응답은 한국어로 작성합니다.
    """,
)

result = Runner.run_sync(reviewer, "다음 함수를 검토해주세요: def divide(a, b): return a/b")
print(result.final_output)
```

### Step 2: 도구(Tool) 연결

```python
from agents import Agent, function_tool

@function_tool
def run_tests(test_file: str) -> str:
    """테스트 파일을 실행하고 결과를 반환합니다."""
    import subprocess
    result = subprocess.run(
        ["python", "-m", "pytest", test_file, "-v"],
        capture_output=True, text=True
    )
    return result.stdout + result.stderr

tdd_agent = Agent(
    name="TDD 에이전트",
    instructions="테스트를 실행하고 실패 원인을 분석하세요.",
    tools=[run_tests],
)
```

## SandboxAgent — 안전한 코드 실행

SandboxAgent는 격리된 환경에서 코드를 실행합니다. 호스트 시스템에 영향을 주지 않아 프로덕션 자동화에 적합합니다.

```python
from agents.sandbox import SandboxAgent

sandbox_agent = SandboxAgent(
    name="코드 실행 에이전트",
    instructions="""
    주어진 Python 코드를 샌드박스에서 실행하고 결과를 분석합니다.
    에러가 있으면 수정하여 재실행합니다.
    """,
    # 샌드박스 설정
    sandbox_config={
        "allowed_packages": ["pandas", "numpy", "requests"],
        "max_execution_time": 30,  # 초
        "network_access": False,
    }
)

result = Runner.run_sync(
    sandbox_agent,
    "다음 코드를 실행하고 최적화하세요: [코드 내용]"
)
```

## 멀티에이전트 핸드오프

복잡한 태스크를 전문화된 에이전트에게 위임하는 패턴입니다.

```python
from agents import Agent, handoff

# 전문가 에이전트
security_agent = Agent(
    name="보안 전문가",
    instructions="코드의 보안 취약점을 분석합니다. SQL 인젝션, XSS, 인증 취약점을 중점 검토합니다.",
)

performance_agent = Agent(
    name="성능 엔지니어",
    instructions="코드의 성능 병목을 찾습니다. 시간 복잡도, 메모리 사용, DB 쿼리 최적화를 분석합니다.",
)

# 오케스트레이터
orchestrator = Agent(
    name="코드 리뷰 오케스트레이터",
    instructions="""
    PR 코드를 전체적으로 검토합니다.
    보안 이슈가 의심되면 보안 전문가에게 핸드오프합니다.
    성능 문제가 보이면 성능 엔지니어에게 핸드오프합니다.
    """,
    handoffs=[
        handoff(security_agent),
        handoff(performance_agent),
    ],
)

result = Runner.run_sync(orchestrator, pr_code)
```

### 핸드오프 흐름 제어

```python
from agents import AgentHook

class ReviewHook(AgentHook):
    async def on_handoff(self, context, source_agent, target_agent):
        print(f"{source_agent.name} → {target_agent.name} 핸드오프")
    
    async def on_tool_call(self, context, tool_name, tool_input):
        # 도구 호출 로깅
        print(f"도구 호출: {tool_name}")

result = await Runner.run(
    orchestrator,
    pr_code,
    hooks=ReviewHook(),
)
```

## MCP 도구 연결

```python
from agents.mcp import MCPServerStdio, MCPServerSSE

# 로컬 MCP 서버 (stdio)
github_mcp = MCPServerStdio(
    command="npx",
    args=["-y", "@modelcontextprotocol/server-github"],
    env={"GITHUB_TOKEN": os.environ["GITHUB_TOKEN"]},
)

# 원격 MCP 서버 (SSE)
jira_mcp = MCPServerSSE(
    url="https://your-jira-mcp.example.com/sse",
)

mcp_agent = Agent(
    name="GitHub + Jira 에이전트",
    instructions="GitHub PR과 Jira 이슈를 연동하여 작업을 추적합니다.",
    mcp_servers=[github_mcp, jira_mcp],
)
```

## 프로덕션 배포 패턴

### 패턴 1: 비동기 실행

```python
import asyncio
from agents import Runner

async def process_pr_batch(pr_list: list[str]):
    tasks = []
    for pr_code in pr_list:
        task = Runner.run(reviewer, pr_code)
        tasks.append(task)
    
    # 병렬 실행
    results = await asyncio.gather(*tasks, return_exceptions=True)
    return results

# 실행
asyncio.run(process_pr_batch(pr_codes))
```

### 패턴 2: 스트리밍 응답

```python
from agents import Runner, StreamEvent

async def stream_review(code: str):
    async with Runner.run_streamed(reviewer, code) as stream:
        async for event in stream.stream_events():
            if event.type == StreamEvent.TEXT_DELTA:
                print(event.delta, end="", flush=True)
            elif event.type == StreamEvent.HANDOFF:
                print(f"\n[{event.target_agent} 에이전트로 전환]")
```

### 패턴 3: 에러 처리 및 재시도

```python
from agents import Runner, MaxTurnsExceeded, ModelBehaviorError

async def safe_run(agent, input_text, max_retries=3):
    for attempt in range(max_retries):
        try:
            result = await Runner.run(
                agent,
                input_text,
                max_turns=20,
            )
            return result.final_output
        except MaxTurnsExceeded:
            print(f"최대 턴 초과 (시도 {attempt+1}/{max_retries})")
            if attempt == max_retries - 1:
                raise
        except ModelBehaviorError as e:
            print(f"모델 오류: {e}")
            await asyncio.sleep(2 ** attempt)
    
    return None
```

## Claude Code vs OpenAI Agents SDK 비교

| 기준 | Claude Code | OpenAI Agents SDK |
|------|-------------|-------------------|
| 주요 용도 | 터미널 AI 코딩 보조 | 프로그래밍 방식 에이전트 |
| 인터페이스 | TUI / CLI | Python API |
| 멀티에이전트 | 서브에이전트 지원 | 핸드오프 기반 |
| LLM 지원 | Claude 모델 중심 | 100+ 모델 |
| 샌드박스 | bubblewrap 격리 | SandboxAgent |
| 적합한 상황 | 대화형 개발 | 자동화 파이프라인 |

**함께 사용하는 패턴:**
- Claude Code로 코드를 작성 → OpenAI Agents SDK로 품질 검증 파이프라인 자동화
- Agents SDK 에이전트가 Claude Code `/autofix-pr`로 수정 요청 전달

## 실전 활용 사례

### CI/CD 품질 게이트

```yaml
# GitHub Actions
- name: AI 코드 리뷰
  run: |
    python review_agent.py \
      --pr-number ${{ github.event.pull_request.number }} \
      --fail-on-critical true
```

```python
# review_agent.py
import sys
from agents import Agent, Runner, function_tool

@function_tool
def get_pr_diff(pr_number: int) -> str:
    """GitHub API로 PR diff를 가져옵니다."""
    # GitHub API 호출
    ...

agent = Agent(
    name="CI 리뷰어",
    instructions="PR을 검토하고 critical 이슈를 JSON으로 반환하세요.",
    tools=[get_pr_diff],
)

result = Runner.run_sync(agent, f"PR #{sys.argv[1]} 검토")
issues = json.loads(result.final_output)

if any(i["severity"] == "critical" for i in issues):
    sys.exit(1)  # CI 실패
```

## 체크리스트

- [ ] `OPENAI_API_KEY` 또는 대체 LLM 키 설정
- [ ] SandboxAgent 사용 시 `sandbox_config` 검토 (network_access 기본값 확인)
- [ ] 멀티에이전트 핸드오프 루프 방지 (`max_turns` 설정)
- [ ] 프로덕션에서 비동기 실행으로 처리량 확보
- [ ] AgentHook으로 모든 도구 호출 로깅
- [ ] 에러 재시도 로직 구현

## 다음 단계

→ [에이전틱 워크플로우 설계 패턴](./94-agentic-workflow-design-patterns-guide.md)

→ [claude agents 디스패치 플래그 실전 가이드](./98-claude-agents-dispatch-flags-guide.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
