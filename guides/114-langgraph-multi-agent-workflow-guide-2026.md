# LangGraph 멀티에이전트 워크플로우 실전 가이드 2026

> 선형 체인의 한계를 넘어 상태 기반 그래프로 복잡한 에이전트 팀을 구성하는 방법

## 소요 시간

30~50분

## LangGraph를 선택하는 이유

LangChain의 선형 파이프라인은 단순한 Q&A나 요약에는 적합합니다. 하지만 에이전트가 루프를 돌고, 중간에 사람이 개입하고, 여러 전문가 에이전트가 협력해야 할 때는 부족합니다.

LangGraph는 방향 그래프(Directed Graph)로 에이전트 워크플로우를 설계합니다. 각 노드는 에이전트나 도구, 각 엣지는 실행 흐름입니다. 조건부 분기, 루프, 체크포인트를 지원합니다.

## 사전 준비

- Python 3.11+
- `pip install langgraph langchain-anthropic`
- Anthropic API 키

## Step 1: 기본 StateGraph 구성

LangGraph의 핵심은 `StateGraph`입니다. 에이전트들이 공유하는 상태를 TypedDict로 정의합니다.

```python
from typing import TypedDict, Annotated, Sequence
from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages
from langchain_anthropic import ChatAnthropic

class AgentState(TypedDict):
    messages: Annotated[list, add_messages]
    task: str
    result: str
    approved: bool

llm = ChatAnthropic(model="claude-sonnet-4-5")
```

| 필드 | 역할 |
|------|------|
| `messages` | 에이전트 간 대화 이력 (자동 병합) |
| `task` | 처리할 작업 설명 |
| `result` | 에이전트 출력 결과 |
| `approved` | 사람 검수 통과 여부 |

## Step 2: 노드(에이전트) 정의

각 노드는 상태를 받아 업데이트된 상태를 반환하는 함수입니다.

```python
def planner_node(state: AgentState) -> dict:
    """작업을 분석하고 실행 계획을 수립하는 에이전트"""
    response = llm.invoke([
        {"role": "system", "content": "당신은 작업 계획 전문가입니다."},
        {"role": "user", "content": f"다음 작업을 분석하고 단계별 계획을 세우세요: {state['task']}"}
    ])
    return {"messages": [response], "result": response.content}

def executor_node(state: AgentState) -> dict:
    """계획을 실제로 실행하는 에이전트"""
    last_plan = state["messages"][-1].content
    response = llm.invoke([
        {"role": "system", "content": "당신은 계획 실행 전문가입니다."},
        {"role": "user", "content": f"다음 계획을 실행하세요:\n{last_plan}"}
    ])
    return {"messages": [response], "result": response.content}

def reviewer_node(state: AgentState) -> dict:
    """결과물을 검증하는 에이전트"""
    response = llm.invoke([
        {"role": "system", "content": "당신은 품질 검증 전문가입니다. 결과가 충분하면 'APPROVED', 아니면 'RETRY'라고 답하세요."},
        {"role": "user", "content": f"결과를 검토하세요:\n{state['result']}"}
    ])
    approved = "APPROVED" in response.content.upper()
    return {"messages": [response], "approved": approved}
```

## Step 3: 조건부 엣지로 흐름 제어

```python
def should_retry(state: AgentState) -> str:
    """리뷰 결과에 따라 재시도 여부 결정"""
    if state.get("approved"):
        return "done"
    return "retry"

# 그래프 구성
builder = StateGraph(AgentState)
builder.add_node("planner", planner_node)
builder.add_node("executor", executor_node)
builder.add_node("reviewer", reviewer_node)

# 엣지 정의
builder.add_edge(START, "planner")
builder.add_edge("planner", "executor")
builder.add_edge("executor", "reviewer")
builder.add_conditional_edges(
    "reviewer",
    should_retry,
    {
        "done": END,
        "retry": "planner"  # 재시도 시 처음으로
    }
)

graph = builder.compile()
```

## Step 4: 체크포인팅으로 상태 저장

장시간 실행되는 워크플로우에서 상태를 저장하고 재개할 수 있습니다.

```python
from langgraph.checkpoint.memory import MemorySaver
from langgraph.checkpoint.sqlite import SqliteSaver

# 개발 환경: 메모리 체크포인터
dev_checkpointer = MemorySaver()

# 프로덕션 환경: SQLite 체크포인터 (서버 재시작 후에도 유지)
prod_checkpointer = SqliteSaver.from_conn_string("./workflow.db")

graph = builder.compile(checkpointer=prod_checkpointer)

# 스레드 ID로 세션 식별
config = {"configurable": {"thread_id": "project-001"}}
result = graph.invoke(
    {"task": "Next.js 앱의 성능 병목 분석 및 최적화"},
    config=config
)
```

## Step 5: Human-in-the-Loop 패턴

```python
from langgraph.types import interrupt, Command

def human_review_node(state: AgentState) -> dict:
    """위험도가 높은 작업 전 사람 검수 요청"""
    # interrupt()는 실행을 일시정지하고 사람의 응답을 기다림
    decision = interrupt({
        "message": "다음 변경사항을 검토해 주세요",
        "result": state["result"],
        "risk_level": "high"
    })
    return {"approved": decision.get("approved", False)}

# 재개 시 Command로 결과 전달
graph.invoke(
    Command(resume={"approved": True}),
    config=config
)
```

## Step 6: 서브그래프로 복잡도 관리

대규모 시스템에서는 서브그래프로 에이전트 팀을 모듈화합니다.

```python
# 리서치 팀 서브그래프
research_builder = StateGraph(AgentState)
research_builder.add_node("search", search_agent)
research_builder.add_node("analyze", analysis_agent)
research_builder.add_edge(START, "search")
research_builder.add_edge("search", "analyze")
research_builder.add_edge("analyze", END)
research_subgraph = research_builder.compile()

# 메인 그래프에 서브그래프 통합
main_builder = StateGraph(AgentState)
main_builder.add_node("research_team", research_subgraph)
main_builder.add_node("writer", writer_agent)
main_builder.add_edge(START, "research_team")
main_builder.add_edge("research_team", "writer")
main_builder.add_edge("writer", END)
```

## 카테고리별 선택 기준

| 상황 | 권장 패턴 |
|------|----------|
| 단순 순차 실행 | 기본 StateGraph + 고정 엣지 |
| 결과 검증 + 재시도 | 조건부 엣지 + 루프 |
| 사람 승인 필요 | interrupt() + checkpointing |
| 대규모 에이전트 팀 | 서브그래프 모듈화 |
| 병렬 처리 | Send API (fan-out 패턴) |

## OpenAI Agents SDK와의 비교

| 항목 | LangGraph | OpenAI Agents SDK |
|------|-----------|-------------------|
| 상태 관리 | TypedDict 기반 명시적 | 자동 핸드오프 |
| 체크포인팅 | 내장 지원 | 외부 구현 필요 |
| 디버깅 | LangSmith 통합 | OpenAI 대시보드 |
| 모델 | LLM 무관 | OpenAI 기본 |
| 학습 곡선 | 높음 | 낮음 |

LangGraph는 제어권이 중요한 엔터프라이즈 환경에, OpenAI Agents SDK는 빠른 프로토타이핑에 적합합니다.

## 체크리스트

- [ ] StateGraph에 공유 상태 TypedDict 정의
- [ ] 각 에이전트를 독립 노드 함수로 분리
- [ ] 조건부 엣지로 분기/루프 흐름 구현
- [ ] 프로덕션 환경에 SqliteSaver 체크포인터 설정
- [ ] 위험 작업에 interrupt() 패턴 적용
- [ ] LangSmith로 그래프 실행 추적 설정

## 다음 단계

→ [에이전틱 워크플로우 설계 패턴](../guides/94-agentic-workflow-design-patterns-guide.md)

→ [OpenAI Agents SDK 실전 가이드](../guides/103-openai-agents-sdk-practical-guide-2026.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
