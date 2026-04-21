# LangGraph 멀티 에이전트 코딩 파이프라인

> 여러 AI 에이전트가 상태를 공유하며 코딩 태스크를 처리하는 실전 예제 — LangGraph로 계획, 구현, 테스트, 리뷰 에이전트를 연결하는 방법

## 이 예제에서 배울 수 있는 것

- LangGraph의 상태 기반 에이전트 설계와 노드-엣지 구조 이해
- 코딩 태스크를 단계별로 위임하는 4노드 파이프라인 구성
- 에이전트 간 상태 전달과 조건부 분기 처리 패턴
- 에러 복구와 재시도 루프를 포함한 프로덕션용 워크플로우 설계

## 프로젝트 구조

```
langgraph-multi-agent/
├── README.md                  # 이 문서
├── pyproject.toml             # 의존성 (langgraph, langchain, anthropic)
├── src/
│   ├── graph.py               # LangGraph 워크플로우 정의
│   ├── state.py               # 공유 상태 스키마 (TypedDict)
│   ├── nodes/
│   │   ├── planner.py         # 계획 에이전트 노드
│   │   ├── coder.py           # 구현 에이전트 노드
│   │   ├── tester.py          # 테스트 생성 에이전트 노드
│   │   └── reviewer.py        # 코드 리뷰 에이전트 노드
│   └── tools/
│       ├── file_ops.py        # 파일 읽기/쓰기 도구
│       └── code_runner.py     # 코드 실행 도구
├── config/
│   └── prompts.yaml           # 노드별 시스템 프롬프트
├── tests/
│   └── test_pipeline.py       # 파이프라인 통합 테스트
└── examples/
    └── build_todo_api.py      # 실행 예제 (Todo API 생성)
```

## 핵심 개념: 상태 기반 에이전트 협업

LangGraph는 여러 에이전트가 **공유 상태(State)**를 통해 협업하는 구조예요. CrewAI가 역할 중심이라면, LangGraph는 데이터 흐름 중심이에요. 상태가 노드를 거치면서 점진적으로 완성되고, 조건부 엣지로 분기나 루프를 제어할 수 있어요.

```
[태스크 입력]
     │
     ▼
┌──────────┐
│ Planner  │  요구사항 분석 → 구현 계획 작성
└────┬─────┘
     │ plan
     ▼
┌──────────┐
│  Coder   │  계획 기반 코드 구현
└────┬─────┘
     │ code
     ▼
┌──────────┐        ┌──────────┐
│  Tester  │──fail──▶  Coder   │  (재시도 루프)
└────┬─────┘        └──────────┘
     │ pass
     ▼
┌──────────┐
│ Reviewer │  코드 품질 검증 → 최종 승인
└──────────┘
```

### LangGraph vs CrewAI 핵심 차이

| 항목 | LangGraph | CrewAI |
|------|-----------|--------|
| 설계 방식 | 상태 그래프 (노드+엣지) | 역할 팀 (에이전트+태스크) |
| 분기 처리 | 조건부 엣지로 명시적 제어 | 에이전트 자율 판단 |
| 루프/재시도 | 그래프 구조로 자연스럽게 지원 | Task 체이닝으로 우회 |
| 디버깅 | 상태 스냅샷으로 추적 용이 | 로그 기반 |
| 복잡도 | 초기 설계 비용 높음 | 빠른 프로토타이핑 |

## 시작하기

### Step 1: 의존성 설치

```bash
pip install langgraph langchain-anthropic python-dotenv pyyaml
```

`.env` 파일:

```bash
ANTHROPIC_API_KEY=your_key_here
```

### Step 2: 공유 상태 정의

에이전트 간 전달되는 데이터 스키마를 먼저 설계해요.

```python
# src/state.py
from typing import TypedDict, Annotated, Optional
from langgraph.graph import add_messages

class CodePipelineState(TypedDict):
    task: str                          # 원본 태스크 설명
    plan: Optional[str]               # Planner 출력
    code: Optional[str]               # Coder 출력
    test_result: Optional[str]        # Tester 출력 (pass/fail + 로그)
    review: Optional[str]             # Reviewer 출력
    retry_count: int                  # 재시도 횟수
    status: str                       # pending / coding / testing / done / error
    messages: Annotated[list, add_messages]  # 전체 메시지 히스토리
```

### Step 3: 에이전트 노드 구현

```python
# src/nodes/planner.py
from langchain_anthropic import ChatAnthropic
from src.state import CodePipelineState

llm = ChatAnthropic(model="claude-sonnet-4-6", max_tokens=2048)

PLANNER_PROMPT = """당신은 소프트웨어 설계 전문가입니다.
주어진 태스크를 분석하고 구체적인 구현 계획을 작성하세요.

계획에는 다음을 포함하세요:
1. 필요한 파일 목록 (경로 포함)
2. 각 파일의 역할과 핵심 로직
3. 사용할 라이브러리와 버전
4. 주의해야 할 엣지케이스
"""

def planner_node(state: CodePipelineState) -> CodePipelineState:
    response = llm.invoke([
        {"role": "system", "content": PLANNER_PROMPT},
        {"role": "user", "content": f"태스크: {state['task']}"}
    ])
    return {
        **state,
        "plan": response.content,
        "status": "coding"
    }
```

```python
# src/nodes/coder.py
from langchain_anthropic import ChatAnthropic
from src.state import CodePipelineState

llm = ChatAnthropic(model="claude-sonnet-4-6", max_tokens=4096)

def coder_node(state: CodePipelineState) -> CodePipelineState:
    retry_context = ""
    if state["retry_count"] > 0 and state["test_result"]:
        retry_context = f"\n\n이전 시도 실패 원인:\n{state['test_result']}\n이 문제를 반드시 수정하세요."

    response = llm.invoke([
        {"role": "system", "content": "당신은 시니어 Python 개발자입니다. 계획에 따라 깔끔한 코드를 작성하세요."},
        {"role": "user", "content": f"계획:\n{state['plan']}\n\n코드를 구현하세요.{retry_context}"}
    ])
    return {
        **state,
        "code": response.content,
        "status": "testing"
    }
```

```python
# src/nodes/tester.py
import subprocess
import tempfile
import os
from src.state import CodePipelineState

def tester_node(state: CodePipelineState) -> CodePipelineState:
    """코드를 실제로 실행해서 기본 동작을 검증합니다."""
    code = state["code"]

    # 코드 블록 추출 (```python ... ``` 형식)
    if "```python" in code:
        code = code.split("```python")[1].split("```")[0].strip()

    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
            f.write(code)
            tmp_path = f.name

        result = subprocess.run(
            ["python", "-c", f"import ast; ast.parse(open('{tmp_path}').read()); print('syntax OK')"],
            capture_output=True, text=True, timeout=10
        )
        os.unlink(tmp_path)

        if result.returncode == 0:
            return {**state, "test_result": "pass", "status": "reviewing"}
        else:
            return {
                **state,
                "test_result": f"fail: {result.stderr}",
                "retry_count": state["retry_count"] + 1,
                "status": "coding"
            }
    except Exception as e:
        return {
            **state,
            "test_result": f"fail: {str(e)}",
            "retry_count": state["retry_count"] + 1,
            "status": "coding"
        }
```

```python
# src/nodes/reviewer.py
from langchain_anthropic import ChatAnthropic
from src.state import CodePipelineState

llm = ChatAnthropic(model="claude-sonnet-4-6", max_tokens=2048)

REVIEWER_PROMPT = """당신은 코드 리뷰 전문가입니다.
다음 관점에서 코드를 검토하고 최종 평가를 내려주세요:

- 보안: 민감 정보 노출, SQL 인젝션 등 취약점
- 성능: 불필요한 반복, 메모리 낭비
- 유지보수성: 함수 분리, 변수명, 주석
- 테스트 가능성: 의존성 주입, 순수 함수

평가 형식:
[승인/수정 요청]
- 이슈 목록 (있을 경우)
- 개선 제안
"""

def reviewer_node(state: CodePipelineState) -> CodePipelineState:
    response = llm.invoke([
        {"role": "system", "content": REVIEWER_PROMPT},
        {"role": "user", "content": f"코드 리뷰 요청:\n{state['code']}"}
    ])
    return {
        **state,
        "review": response.content,
        "status": "done"
    }
```

### Step 4: 그래프 조립

```python
# src/graph.py
from langgraph.graph import StateGraph, END
from src.state import CodePipelineState
from src.nodes.planner import planner_node
from src.nodes.coder import coder_node
from src.nodes.tester import tester_node
from src.nodes.reviewer import reviewer_node

MAX_RETRIES = 3

def should_retry(state: CodePipelineState) -> str:
    """테스트 실패 시 재시도 여부 결정"""
    if state["status"] == "coding" and state["retry_count"] < MAX_RETRIES:
        return "retry_coding"
    elif state["retry_count"] >= MAX_RETRIES:
        return "error"
    return "reviewing"

def build_pipeline() -> StateGraph:
    graph = StateGraph(CodePipelineState)

    # 노드 등록
    graph.add_node("planner", planner_node)
    graph.add_node("coder", coder_node)
    graph.add_node("tester", tester_node)
    graph.add_node("reviewer", reviewer_node)

    # 엣지 연결
    graph.set_entry_point("planner")
    graph.add_edge("planner", "coder")
    graph.add_edge("coder", "tester")

    # 조건부 엣지: 테스트 결과에 따라 분기
    graph.add_conditional_edges(
        "tester",
        should_retry,
        {
            "retry_coding": "coder",    # 재시도
            "reviewing": "reviewer",    # 다음 단계
            "error": END                # 최대 재시도 초과
        }
    )
    graph.add_edge("reviewer", END)

    return graph.compile()
```

### Step 5: 실행

```python
# examples/build_todo_api.py
from src.graph import build_pipeline

pipeline = build_pipeline()

initial_state = {
    "task": "FastAPI로 Todo API를 만들어줘. CRUD 엔드포인트와 SQLite 저장소 포함.",
    "plan": None,
    "code": None,
    "test_result": None,
    "review": None,
    "retry_count": 0,
    "status": "pending",
    "messages": []
}

result = pipeline.invoke(initial_state)

print("=== 구현 계획 ===")
print(result["plan"][:500])

print("\n=== 생성된 코드 ===")
print(result["code"][:1000])

print(f"\n=== 테스트 결과 ===")
print(result["test_result"])

print("\n=== 코드 리뷰 ===")
print(result["review"])
```

실행:

```bash
python examples/build_todo_api.py
```

## AI 활용 포인트

| 상황 | 활용 패턴 |
|------|-----------|
| 파이프라인 설계 | "이 태스크를 단계별로 분해해줘. 각 단계의 입출력을 정의해" |
| 상태 스키마 설계 | "에이전트 간 전달할 데이터 구조를 TypedDict으로 설계해줘" |
| 조건부 분기 로직 | "테스트 실패 시 재시도 횟수를 제한하는 조건부 엣지를 추가해줘" |
| 디버깅 | "각 노드 실행 후 상태를 출력하는 디버그 모드를 추가해줘" |

## 응용: 스트리밍 + 체크포인트

```python
# 스트리밍으로 노드 실행 과정 실시간 확인
for step in pipeline.stream(initial_state):
    node_name = list(step.keys())[0]
    state = step[node_name]
    print(f"[{node_name}] 완료 - 상태: {state.get('status')}")

# 체크포인트로 중단 지점부터 재시작
from langgraph.checkpoint.sqlite import SqliteSaver

with SqliteSaver.from_conn_string("checkpoints.db") as memory:
    pipeline_with_checkpoint = build_pipeline().compile(checkpointer=memory)
    config = {"configurable": {"thread_id": "task-001"}}

    result = pipeline_with_checkpoint.invoke(initial_state, config=config)
    # 이후 동일 thread_id로 재시작하면 이전 상태부터 재개
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| 무한 루프 | `MAX_RETRIES` 확인, `retry_count` 증가 로직 검토 |
| 상태 누락 | `TypedDict`에 `Optional` 타입 지정, 기본값 설정 |
| 노드 간 데이터 불일치 | `state` 전체를 스프레드 후 변경 필드만 오버라이드 |
| 메모리 부족 | 대형 코드 결과물은 파일로 저장 후 경로만 상태에 전달 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
