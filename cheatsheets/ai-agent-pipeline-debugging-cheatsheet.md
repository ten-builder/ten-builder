# AI 에이전트 파이프라인 디버깅 치트시트 2026

> 멀티에이전트 파이프라인이 실패할 때 빠르게 원인을 찾고 수정하는 패턴 한 페이지 정리

## 에이전트 파이프라인 실패 유형 분류

| 실패 유형 | 증상 | 주요 원인 |
|-----------|------|-----------|
| **핸드오프 실패** | 에이전트 전환 후 응답 없음, 무한 대기 | 핸드오프 조건 모호, 대상 에이전트 미정의 |
| **도구 호출 오류** | `ToolCallError`, 도구 응답 없음 | 잘못된 파라미터, 타임아웃, 권한 부족 |
| **컨텍스트 손실** | 이전 단계 정보 무시, 중복 작업 반복 | 컨텍스트 윈도우 초과, 잘못된 상태 전달 |
| **연쇄 오염** | 초반 오류가 이후 단계 전부 오염 | N단계 도구 오류 → N+1~END 전파 |
| **할루시네이션 루프** | 같은 작업 반복, 진전 없음 | 종료 조건 누락, 검증 스텝 부재 |

---

## 핸드오프 실패 디버깅

### OpenAI Agents SDK

```python
import asyncio
from agents import Agent, Runner, trace

async def debug_handoff():
    # trace()로 전체 실행 경로 기록
    with trace("handoff-debug"):
        result = await Runner.run(
            orchestrator_agent,
            input="태스크 내용"
        )
    # 핸드오프가 발생했는지 확인
    for item in result.new_items:
        print(f"[{item.__class__.__name__}] {getattr(item, 'agent', 'N/A')}")
```

**핸드오프 조건 명시화:**

```python
# 모호한 핸드오프 (문제)
orchestrator = Agent(
    instructions="필요하면 다른 에이전트에게 전달해"
)

# 명시적 핸드오프 (권장)
orchestrator = Agent(
    instructions="""
    - 코드 작성 태스크 → coder_agent로 전달
    - 코드 리뷰 태스크 → reviewer_agent로 전달
    - 위 두 경우가 아니면 직접 처리
    """
)
```

### LangGraph

```python
from langgraph.graph import StateGraph
import logging

# 노드 간 상태 전달 로깅
logging.basicConfig(level=logging.DEBUG)

def debug_node_transition(state, node_name):
    print(f"\n=== {node_name} 진입 ===")
    print(f"상태 키: {list(state.keys())}")
    print(f"메시지 수: {len(state.get('messages', []))}")
    return state

# 그래프 실행 시 스트리밍으로 각 단계 확인
for step in graph.stream(initial_state):
    print(f"현재 노드: {list(step.keys())}")
```

---

## 도구 호출 오류 디버깅

| 오류 코드 | 원인 | 해결 |
|-----------|------|------|
| `timeout` | 도구 응답 3초+ 초과 | 타임아웃 설정 조정, 비동기 처리 |
| `invalid_params` | 스키마 불일치 | 도구 정의와 호출 파라미터 비교 |
| `permission_denied` | API 키 권한 부족 | 최소 권한 원칙 재검토 |
| `rate_limited` | API 한도 초과 | 재시도 로직 + 지수 백오프 추가 |

**도구 실패 재시도 패턴:**

```python
import asyncio

async def robust_tool_call(tool, params, max_retries=3):
    for attempt in range(max_retries):
        try:
            result = await tool.invoke(params)
            return result
        except TimeoutError:
            wait = 2 ** attempt  # 지수 백오프: 1s, 2s, 4s
            print(f"타임아웃 — {wait}초 후 재시도 ({attempt+1}/{max_retries})")
            await asyncio.sleep(wait)
        except PermissionError as e:
            print(f"권한 오류 — 재시도 불가: {e}")
            raise
    raise RuntimeError(f"도구 호출 {max_retries}회 실패")
```

---

## 컨텍스트 손실 디버깅

### 증상별 체크리스트

```
[ ] 에이전트가 이전 단계 결과를 언급하지 않음
[ ] 같은 정보를 다시 요청함
[ ] 태스크 초반에 설정한 제약 조건을 무시함
[ ] 중간 단계에서 갑자기 다른 방향으로 진행
```

### 컨텍스트 체크포인트 패턴

```python
# 각 단계 후 핵심 상태를 별도 파일로 저장
import json
from pathlib import Path

def save_checkpoint(step_name: str, state: dict):
    checkpoint = {
        "step": step_name,
        "timestamp": datetime.now().isoformat(),
        "key_decisions": state.get("decisions", []),
        "task_progress": state.get("progress", {}),
        "constraints": state.get("constraints", [])
    }
    Path(f".agent-checkpoints/{step_name}.json").write_text(
        json.dumps(checkpoint, ensure_ascii=False, indent=2)
    )

# 이전 체크포인트에서 복구
def restore_from_checkpoint(step_name: str) -> dict:
    data = Path(f".agent-checkpoints/{step_name}.json").read_text()
    return json.loads(data)
```

---

## 연쇄 오염 방지 패턴

```
실패 전파 경로:
Step 1 ✅ → Step 2 ✅ → Step 3 ❌ → Step 4 ❌ (오염) → Step 5 ❌ (오염)

격리 패턴:
Step 1 ✅ → Step 2 ✅ → Step 3 ❌ → [격리 + 롤백] → Step 3' ✅ → Step 4 ✅
```

```python
# 각 단계에 독립 검증 추가
async def validated_step(step_fn, state, validation_fn):
    result = await step_fn(state)

    # 검증 실패 시 해당 단계만 재실행
    if not validation_fn(result):
        print(f"검증 실패 — 이전 상태로 롤백")
        return await step_fn(state)  # 이전 state 사용 (오염 차단)

    return result
```

---

## 관찰 도구 비교

| 도구 | 특징 | 적합 프레임워크 |
|------|------|----------------|
| **LangSmith** | 단계별 트레이스, 프롬프트 비교 | LangGraph, LangChain |
| **Braintrust** | 평가 데이터셋, 회귀 탐지 | 프레임워크 무관 |
| **Maxim AI** | 실시간 실패 패턴 감지 | 프레임워크 무관 |
| **내장 trace()** | OpenAI SDK 자체 트레이싱 | OpenAI Agents SDK |

**LangSmith 빠른 설정:**

```bash
export LANGCHAIN_TRACING_V2=true
export LANGCHAIN_API_KEY="your-key"
export LANGCHAIN_PROJECT="my-agent-debug"
```

---

## 빠른 진단 체크리스트

```
파이프라인이 실패했을 때 순서대로 확인

1. [ ] 어느 단계에서 실패했는가? (트레이스 확인)
2. [ ] 실패 직전 단계의 출력 상태는? (체크포인트)
3. [ ] 도구 호출 파라미터가 스키마와 일치하는가?
4. [ ] 컨텍스트 윈도우가 초과되지 않았는가?
5. [ ] 핸드오프 조건이 명확하게 정의되어 있는가?
6. [ ] 종료 조건이 반드시 도달 가능한가?
7. [ ] 에러 격리 로직이 연쇄 오염을 막고 있는가?
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
