# AI CLI 챗봇 구현 예제

> LangGraph + Claude API로 대화 메모리와 도구 호출 기능을 갖춘 CLI 챗봇을 처음부터 구현하는 예제

## 이 예제에서 배울 수 있는 것

- LangGraph로 상태 기반 대화 흐름 설계하기
- Claude API 도구 호출(tool use)로 외부 기능 연동하기
- 파일 기반 대화 메모리로 세션 간 컨텍스트 유지하기
- Rich 라이브러리로 터미널 UI를 읽기 좋게 만들기

## 프로젝트 구조

```
ai-cli-chatbot/
├── README.md
├── requirements.txt
├── .env.example
├── src/
│   ├── __init__.py
│   ├── main.py          # 진입점 — CLI 루프
│   ├── graph.py         # LangGraph 워크플로 정의
│   ├── state.py         # 대화 상태 스키마
│   ├── tools.py         # 도구 정의 (날씨, 파일 읽기 등)
│   └── memory.py        # 파일 기반 메모리 관리
└── sessions/            # 대화 세션 저장 디렉토리 (첫 실행 시 생성)
```

## 시작하기

```bash
# 레포 클론 후 예제 디렉토리로 이동
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-cli-chatbot

# 의존성 설치
pip install -r requirements.txt

# 환경 변수 설정
cp .env.example .env
# ANTHROPIC_API_KEY를 .env에 입력

# 실행
python src/main.py
```

## 핵심 코드

### state.py — 대화 상태 스키마

```python
from typing import Annotated, List
from typing_extensions import TypedDict
from langgraph.graph.message import add_messages

class ConversationState(TypedDict):
    messages: Annotated[list, add_messages]
    session_id: str
    tool_results: List[dict]
```

`add_messages`를 사용하면 메시지 리스트를 자동으로 누적해서 컨텍스트가 끊기지 않아요.

### graph.py — LangGraph 워크플로

```python
import anthropic
from langgraph.graph import StateGraph, END
from .state import ConversationState
from .tools import TOOLS

client = anthropic.Anthropic()

def call_model(state: ConversationState) -> dict:
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        tools=TOOLS,
        messages=state["messages"]
    )

    if response.stop_reason == "tool_use":
        return {"messages": [response], "tool_results": _extract_tool_calls(response)}

    return {"messages": [response]}

def route_after_model(state: ConversationState) -> str:
    """도구 호출이 있으면 tool_node로, 없으면 종료"""
    last = state["messages"][-1]
    if hasattr(last, "stop_reason") and last.stop_reason == "tool_use":
        return "tool_node"
    return END

def tool_node(state: ConversationState) -> dict:
    """도구를 실행하고 결과를 메시지로 반환"""
    from .tools import execute_tool
    results = []
    for call in state.get("tool_results", []):
        result = execute_tool(call["name"], call["input"])
        results.append({
            "type": "tool_result",
            "tool_use_id": call["id"],
            "content": result
        })
    return {"messages": [{"role": "user", "content": results}]}

# 그래프 조립
builder = StateGraph(ConversationState)
builder.add_node("model", call_model)
builder.add_node("tool_node", tool_node)
builder.set_entry_point("model")
builder.add_conditional_edges("model", route_after_model)
builder.add_edge("tool_node", "model")
graph = builder.compile()
```

**왜 이렇게 했나요?**

LangGraph의 조건부 엣지를 쓰면 모델이 도구 호출을 결정할 때마다 자동으로 루프를 처리해요. 직접 while 루프를 짤 필요 없이, 그래프 구조만 정의하면 흐름이 명확해집니다.

### tools.py — 도구 정의

```python
import json
from pathlib import Path

TOOLS = [
    {
        "name": "read_file",
        "description": "로컬 파일 내용을 읽어서 반환합니다",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "읽을 파일의 경로"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "list_directory",
        "description": "디렉토리 내 파일 목록을 반환합니다",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "조회할 디렉토리 경로"
                }
            },
            "required": ["path"]
        }
    }
]

def execute_tool(name: str, inputs: dict) -> str:
    if name == "read_file":
        try:
            return Path(inputs["path"]).read_text(encoding="utf-8")
        except FileNotFoundError:
            return f"파일을 찾을 수 없어요: {inputs['path']}"
    elif name == "list_directory":
        try:
            p = Path(inputs["path"])
            items = sorted(p.iterdir(), key=lambda x: (x.is_file(), x.name))
            return "\n".join(f"{'📁' if i.is_dir() else '📄'} {i.name}" for i in items)
        except FileNotFoundError:
            return f"디렉토리를 찾을 수 없어요: {inputs['path']}"
    return "알 수 없는 도구입니다"
```

### memory.py — 세션 메모리 관리

```python
import json
from pathlib import Path
from datetime import datetime

SESSIONS_DIR = Path("sessions")

def load_session(session_id: str) -> list:
    """이전 세션 메시지 불러오기"""
    path = SESSIONS_DIR / f"{session_id}.json"
    if path.exists():
        return json.loads(path.read_text())
    return []

def save_session(session_id: str, messages: list) -> None:
    """현재 대화 저장 — 텍스트 메시지만 직렬화"""
    SESSIONS_DIR.mkdir(exist_ok=True)
    serializable = []
    for m in messages:
        if isinstance(m, dict):
            serializable.append(m)
        elif hasattr(m, "role") and hasattr(m, "content"):
            content = m.content
            if isinstance(content, list):
                # 텍스트 블록만 추출
                content = " ".join(
                    b.text for b in content if hasattr(b, "text")
                )
            serializable.append({"role": m.role, "content": content})
    path = SESSIONS_DIR / f"{session_id}.json"
    path.write_text(json.dumps(serializable, ensure_ascii=False, indent=2))
```

### main.py — CLI 루프

```python
import uuid
from rich.console import Console
from rich.prompt import Prompt
from rich.panel import Panel
from .graph import graph
from .memory import load_session, save_session

console = Console()

def run():
    session_id = str(uuid.uuid4())[:8]
    messages = load_session(session_id)

    console.print(Panel(
        f"[bold cyan]AI CLI 챗봇[/bold cyan] — 세션 ID: {session_id}\n"
        "종료하려면 [bold]exit[/bold] 또는 [bold]Ctrl+C[/bold]",
        expand=False
    ))

    while True:
        try:
            user_input = Prompt.ask("\n[bold green]You[/bold green]")
        except (EOFError, KeyboardInterrupt):
            break

        if user_input.strip().lower() in ("exit", "quit", "종료"):
            break

        messages.append({"role": "user", "content": user_input})

        result = graph.invoke({
            "messages": messages,
            "session_id": session_id,
            "tool_results": []
        })

        messages = result["messages"]
        save_session(session_id, messages)

        # 마지막 assistant 응답 출력
        last = messages[-1]
        if hasattr(last, "content"):
            text = ""
            for block in last.content:
                if hasattr(block, "text"):
                    text += block.text
            if text:
                console.print(f"\n[bold blue]Assistant[/bold blue]: {text}")

if __name__ == "__main__":
    run()
```

## requirements.txt

```
anthropic>=0.40.0
langgraph>=0.2.0
langchain-core>=0.3.0
rich>=13.0.0
python-dotenv>=1.0.0
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 도구 추가 | `"파일 수정 기능을 tools.py에 추가하고 싶어. write_file 도구를 만들어줘"` |
| 메모리 확장 | `"세션 간 중요한 사실만 요약해서 유지하는 장기 메모리 기능이 필요해"` |
| 스트리밍 응답 | `"사용자가 기다리지 않도록 응답을 스트리밍으로 출력하고 싶어"` |
| 멀티 모달 | `"이미지 파일도 분석할 수 있는 도구를 추가해줘"` |

## 흔한 문제 & 해결

| 문제 | 해결 |
|------|------|
| 도구 결과가 다음 메시지에 반영 안 됨 | `tool_result` 메시지를 `user` 역할로 반환하는지 확인 |
| 세션 저장 시 직렬화 에러 | `Message` 객체는 직접 직렬화 불가 — `memory.py`의 변환 로직 참고 |
| 컨텍스트가 너무 길어져 느려짐 | 오래된 메시지를 요약 후 압축하는 `summarize_old_messages()` 함수 추가 |
| API 비용이 예상보다 큼 | 긴 대화는 캐시 가능한 시스템 프롬프트를 `cache_control`로 설정 |

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
