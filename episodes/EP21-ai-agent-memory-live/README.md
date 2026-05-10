# EP21: AI 에이전트 메모리 시스템 라이브 빌드

> 세션을 넘어 기억하는 AI 에이전트 — Mem0 기반 상태 지속 시스템 구축 라이브 코딩

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- AI 에이전트가 왜 기억을 갖지 못하는가 — 상태 없는(stateless) API의 한계
- Mem0 메모리 레이어 아키텍처 이해 — user / session / agent 스코프 분리
- Qdrant 벡터 스토어 + Mem0 로컬 설정
- LangChain 에이전트에 장기 메모리 붙이기 — 세션 종료 후에도 유지되는 컨텍스트
- 프로덕션에서 쓸 수 있는 메모리 관리 패턴

## 핵심 개념: 왜 메모리가 필요한가

AI 에이전트는 API 레벨에서 본질적으로 상태가 없습니다. 대화가 끝나면 모든 컨텍스트가 사라지고, 다음 세션에서 에이전트는 처음 만난 사람처럼 반응해요.

메모리 시스템은 크게 두 층으로 나뉩니다:

| 메모리 유형 | 유지 범위 | 저장 방식 |
|------------|----------|----------|
| 단기 메모리 (Thread-Level) | 현재 대화 스레드 내 | 대화 기록 (in-memory) |
| 장기 메모리 (Cross-Session) | 세션 종료 후에도 지속 | 벡터 DB / 그래프 DB |

이 에피소드에서는 장기 메모리 시스템을 직접 구축합니다.

## 핵심 코드 & 설정

### Step 1: Mem0 + Qdrant 로컬 설치

```bash
pip install mem0ai qdrant-client openai langchain langchain-openai
```

Qdrant를 Docker로 로컬 실행:

```bash
docker run -d -p 6333:6333 -p 6334:6334 \
  -v $(pwd)/qdrant_data:/qdrant/storage \
  qdrant/qdrant
```

### Step 2: Mem0 기본 설정

```python
from mem0 import Memory
import os

config = {
    "vector_store": {
        "provider": "qdrant",
        "config": {
            "collection_name": "agent_memories",
            "host": "localhost",
            "port": 6333,
            "embedding_model_dims": 1536,
        }
    },
    "llm": {
        "provider": "openai",
        "config": {
            "model": "gpt-4o-mini",
            "api_key": os.environ.get("OPENAI_API_KEY"),
        }
    },
    "embedder": {
        "provider": "openai",
        "config": {
            "model": "text-embedding-3-small",
        }
    }
}

memory = Memory.from_config(config)
```

### Step 3: 메모리 스코프 — user / session / agent

Mem0는 메모리를 세 가지 스코프로 구분합니다:

```python
# 유저별 장기 기억 저장
memory.add(
    messages=[{"role": "user", "content": "나는 Python 백엔드 개발자고, FastAPI를 주로 써"}],
    user_id="user_123",
    metadata={"category": "profile"}
)

# 세션별 단기 기억 저장
memory.add(
    messages=[{"role": "user", "content": "오늘 데이터베이스 마이그레이션 작업 중이야"}],
    user_id="user_123",
    session_id="session_20260511",
)

# 저장된 기억 검색
results = memory.search(
    query="이 사용자가 사용하는 기술 스택은?",
    user_id="user_123",
    limit=5
)
for r in results["results"]:
    print(r["memory"])
```

### Step 4: LangChain 에이전트에 메모리 연결

```python
from langchain_openai import ChatOpenAI
from langchain.agents import create_openai_functions_agent, AgentExecutor
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.messages import HumanMessage, AIMessage
from mem0 import Memory

class MemoryAgent:
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.memory = Memory.from_config(config)  # Step 2의 config 재사용
        self.llm = ChatOpenAI(model="gpt-4o-mini", temperature=0)

    def chat(self, user_message: str, session_id: str) -> str:
        # 관련 기억 검색
        relevant_memories = self.memory.search(
            query=user_message,
            user_id=self.user_id,
            limit=5
        )

        # 메모리를 시스템 컨텍스트로 주입
        memory_context = "\n".join([
            f"- {r['memory']}"
            for r in relevant_memories.get("results", [])
        ])

        messages = []
        if memory_context:
            messages.append({
                "role": "system",
                "content": f"사용자에 대해 알고 있는 정보:\n{memory_context}"
            })
        messages.append({"role": "user", "content": user_message})

        # LLM 응답 생성
        response = self.llm.invoke(messages)
        ai_response = response.content

        # 대화 내용을 메모리에 저장
        self.memory.add(
            messages=[
                {"role": "user", "content": user_message},
                {"role": "assistant", "content": ai_response}
            ],
            user_id=self.user_id,
            session_id=session_id
        )

        return ai_response
```

### Step 5: 실행 및 동작 확인

```python
agent = MemoryAgent(user_id="user_123")

# 첫 번째 세션
response1 = agent.chat("나는 FastAPI로 API 서버 만들고 있어", session_id="session_001")
print(response1)

# --- 프로그램 재시작 (세션 종료) ---

# 두 번째 세션 — 이전 세션 내용 기억
agent2 = MemoryAgent(user_id="user_123")
response2 = agent2.chat("지금 하던 작업 이어서 해줄 수 있어?", session_id="session_002")
# "FastAPI 서버 작업 말씀하시는 거죠? 어떤 부분부터 이어갈까요?" 같은 응답 기대
print(response2)
```

## 따라하기

### Step 1: 환경 준비

```bash
mkdir ai-memory-agent && cd ai-memory-agent
python -m venv venv && source venv/bin/activate
pip install mem0ai qdrant-client openai langchain langchain-openai
```

### Step 2: 환경변수 설정

```bash
export OPENAI_API_KEY="sk-..."

# Qdrant 로컬 실행
docker run -d -p 6333:6333 qdrant/qdrant
```

### Step 3: 기본 메모리 동작 테스트

```python
# test_memory.py
from mem0 import Memory

m = Memory()  # 기본 설정 (in-memory + OpenAI)

# 저장
m.add("Python FastAPI 개발자입니다", user_id="test_user")

# 검색
results = m.search("기술 스택", user_id="test_user")
print(results["results"])

# 전체 조회
all_memories = m.get_all(user_id="test_user")
print(all_memories)
```

### Step 4: 메모리 업데이트 & 삭제

```python
# 기억 업데이트 (Mem0가 자동으로 중복 감지)
m.add("FastAPI에서 Django로 전환 중입니다", user_id="test_user")

# 특정 메모리 삭제
memory_id = results["results"][0]["id"]
m.delete(memory_id=memory_id)

# 사용자의 모든 메모리 초기화
m.delete_all(user_id="test_user")
```

## 메모리 설계 패턴

| 상황 | 패턴 | 설명 |
|------|------|------|
| 사용자 프로필 저장 | `user_id` 스코프 | 기술 스택, 선호도, 컨텍스트 |
| 진행 중인 작업 추적 | `session_id` 스코프 | 현재 세션에서만 유효한 정보 |
| 에이전트 간 공유 지식 | `agent_id` 스코프 | 여러 에이전트가 공유하는 도메인 지식 |
| 프로덕션 스케일 | Qdrant + 필터링 | 메타데이터 필터로 메모리 분류 |

## 더 알아보기

- [Mem0 공식 문서](https://docs.mem0.ai)
- [Qdrant 로컬 설정 가이드](https://qdrant.tech/documentation/quick-start/)
- [EP20: Claude Code 데스크톱 풀스택 개발](../EP20-claude-code-desktop-parallel/README.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
