# EP26: AI 에이전트로 실시간 스트리밍 앱 만들기 — WebSocket + Redis

> WebSocket, Redis Pub/Sub, Claude API 스트리밍을 조합해 실시간 AI 채팅 앱을 처음부터 구현합니다.

## 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- Claude API 스트리밍 응답을 WebSocket으로 실시간 전달하는 구조 설계
- Redis Pub/Sub로 다중 서버 간 메시지 동기화
- WebSocket 연결 관리 — 재연결, 하트비트, 정리 처리
- 수천 명이 동시 접속해도 버티는 스케일링 전략

---

## 1. 전체 아키텍처

```
클라이언트 (브라우저)
    ↕ WebSocket
API 서버 (FastAPI)
    ↕ Redis Pub/Sub
    ↕ Claude API (스트리밍)
Redis (메시지 브로커)
    ↕ Subscribe
다른 API 서버 인스턴스 (수평 확장)
```

단일 서버에서는 WebSocket 연결을 메모리에서 바로 관리할 수 있어요. 그런데 서버가 2대 이상으로 늘어나는 순간, 서버 A에 붙은 클라이언트와 서버 B에 붙은 클라이언트가 같은 방에 있어도 서로 메시지를 못 받는 문제가 생깁니다. Redis Pub/Sub이 이 문제를 해결하는 핵심이에요.

---

## 2. 프로젝트 구조

```
realtime-ai-chat/
├── backend/
│   ├── main.py          # FastAPI 진입점
│   ├── ws_manager.py    # WebSocket 연결 관리
│   ├── redis_bus.py     # Redis Pub/Sub 래퍼
│   └── claude_stream.py # Claude API 스트리밍
├── frontend/
│   ├── index.html
│   └── chat.js          # WebSocket 클라이언트
├── docker-compose.yml
└── requirements.txt
```

## 3. 시작하기

```bash
# 의존성 설치
pip install fastapi uvicorn websockets anthropic redis python-dotenv

# Redis 실행 (Docker)
docker run -d -p 6379:6379 redis:7-alpine

# 서버 실행
uvicorn main:app --reload
```

---

## 4. 핵심 코드

### Claude API 스트리밍 처리

```python
# claude_stream.py
import anthropic
from typing import AsyncGenerator

client = anthropic.AsyncAnthropic()

async def stream_response(
    room_id: str,
    messages: list[dict],
) -> AsyncGenerator[str, None]:
    """Claude API에서 토큰 단위로 응답을 받아 yield합니다."""

    async with client.messages.stream(
        model="claude-opus-4-5",
        max_tokens=2048,
        messages=messages,
    ) as stream:
        async for text in stream.text_stream:
            yield text
```

Claude API의 `stream` 컨텍스트 매니저를 쓰면 토큰이 생성될 때마다 `text_stream`으로 받을 수 있어요. 이걸 그대로 WebSocket으로 보내면 브라우저에서 실시간으로 타이핑되는 효과가 나옵니다.

### WebSocket 연결 관리

```python
# ws_manager.py
from fastapi import WebSocket
from collections import defaultdict
import asyncio

class ConnectionManager:
    def __init__(self):
        # room_id → {client_id: WebSocket}
        self.rooms: dict[str, dict[str, WebSocket]] = defaultdict(dict)
        self._lock = asyncio.Lock()

    async def connect(self, room_id: str, client_id: str, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self.rooms[room_id][client_id] = ws

    async def disconnect(self, room_id: str, client_id: str):
        async with self._lock:
            self.rooms[room_id].pop(client_id, None)
            if not self.rooms[room_id]:
                del self.rooms[room_id]

    async def broadcast_to_room(self, room_id: str, message: str):
        """방 안의 모든 클라이언트에게 메시지를 보냅니다."""
        if room_id not in self.rooms:
            return

        disconnected = []
        for client_id, ws in self.rooms[room_id].items():
            try:
                await ws.send_text(message)
            except Exception:
                disconnected.append(client_id)

        # 끊긴 연결 정리
        for client_id in disconnected:
            await self.disconnect(room_id, client_id)

manager = ConnectionManager()
```

연결이 끊긴 클라이언트를 즉시 제거하지 않고 `disconnected` 리스트에 모았다가 나중에 처리하는 이유가 있어요. 브로드캐스트 루프 도중에 `rooms` 딕셔너리를 수정하면 `RuntimeError: dictionary changed size during iteration` 에러가 나기 때문이에요.

### Redis Pub/Sub 브로커

```python
# redis_bus.py
import redis.asyncio as redis
import json
import asyncio

class RedisBus:
    def __init__(self, url: str = "redis://localhost:6379"):
        self.client = redis.from_url(url)

    async def publish(self, channel: str, data: dict):
        await self.client.publish(channel, json.dumps(data))

    async def subscribe(self, channel: str):
        """Redis 채널을 구독하고 메시지를 yield합니다."""
        pubsub = self.client.pubsub()
        await pubsub.subscribe(channel)

        async for message in pubsub.listen():
            if message["type"] == "message":
                yield json.loads(message["data"])

bus = RedisBus()
```

### FastAPI 메인 서버

```python
# main.py
import uuid
import json
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from ws_manager import manager
from redis_bus import bus
from claude_stream import stream_response

app = FastAPI()

# Redis 구독 → WebSocket 브로드캐스트 백그라운드 태스크
async def redis_to_ws_relay(room_id: str):
    async for message in bus.subscribe(f"room:{room_id}"):
        await manager.broadcast_to_room(room_id, json.dumps(message))

@app.websocket("/ws/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: str):
    client_id = str(uuid.uuid4())[:8]
    await manager.connect(room_id, client_id, websocket)

    # 이 방에 대한 Redis 릴레이가 없으면 시작
    asyncio.create_task(redis_to_ws_relay(room_id))

    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)

            if payload.get("type") == "message":
                # AI 응답 스트리밍 시작
                asyncio.create_task(
                    handle_ai_stream(room_id, client_id, payload["content"])
                )

    except WebSocketDisconnect:
        await manager.disconnect(room_id, client_id)

async def handle_ai_stream(room_id: str, sender_id: str, user_message: str):
    """Claude 스트리밍 응답을 Redis를 통해 브로드캐스트합니다."""

    # 사용자 메시지 먼저 브로드캐스트
    await bus.publish(f"room:{room_id}", {
        "type": "user_message",
        "sender": sender_id,
        "content": user_message,
    })

    # AI 응답 스트리밍
    messages = [{"role": "user", "content": user_message}]
    full_response = ""

    async for token in stream_response(room_id, messages):
        full_response += token
        await bus.publish(f"room:{room_id}", {
            "type": "ai_token",
            "content": token,
        })

    # 완료 신호
    await bus.publish(f"room:{room_id}", {
        "type": "ai_done",
        "content": full_response,
    })
```

---

## 5. 브라우저 클라이언트

```javascript
// chat.js
class AIChat {
  constructor(roomId) {
    this.roomId = roomId;
    this.ws = null;
    this.buffer = "";
    this.connect();
  }

  connect() {
    this.ws = new WebSocket(`ws://localhost:8000/ws/${this.roomId}`);

    this.ws.onopen = () => console.log("연결됨");

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.handleMessage(data);
    };

    // 재연결 처리 — 끊기면 3초 후 재시도
    this.ws.onclose = () => {
      console.log("연결 끊김, 3초 후 재연결...");
      setTimeout(() => this.connect(), 3000);
    };
  }

  handleMessage(data) {
    switch (data.type) {
      case "user_message":
        this.appendMessage("user", data.content);
        break;

      case "ai_token":
        // 토큰이 올 때마다 현재 AI 버블에 덧붙이기
        this.buffer += data.content;
        this.updateAIBubble(this.buffer);
        break;

      case "ai_done":
        // 스트리밍 완료
        this.buffer = "";
        break;
    }
  }

  sendMessage(text) {
    if (this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type: "message", content: text }));
    }
  }
}

const chat = new AIChat("room-001");
```

재연결 로직에서 지수 백오프(exponential backoff)를 쓰면 더 좋아요. 서버가 재시작될 때 수천 명이 동시에 재연결하면 순간 트래픽이 폭발하거든요. 3초, 6초, 12초... 식으로 늘려가는 방식으로 개선할 수 있습니다.

---

## 6. Docker Compose로 전체 실행

```yaml
# docker-compose.yml
version: "3.9"

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s

  api:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - REDIS_URL=redis://redis:6379
    depends_on:
      redis:
        condition: service_healthy
    # 수평 확장: docker compose up --scale api=3
    deploy:
      replicas: 1
```

`deploy.replicas`를 3으로 올리면 API 서버가 3개 뜹니다. 앞에 nginx 로드 밸런서를 붙이면 바로 수평 확장이 돼요. Redis가 메시지를 중계하기 때문에 어느 서버에 붙든 같은 방의 메시지를 받을 수 있어요.

---

## 7. 스케일링 핵심 전략

| 문제 | 원인 | 해결 |
|------|------|------|
| 서버 간 메시지 누락 | WebSocket 연결이 서버마다 분리됨 | Redis Pub/Sub로 중계 |
| 연결 폭증 | 서버 재시작 시 동시 재연결 | 지수 백오프 재연결 |
| 메모리 누수 | 끊긴 연결이 방에 남아있음 | broadcast 실패 시 즉시 정리 |
| Redis 병목 | 모든 토큰을 publish | 토큰 N개 묶어서 한 번에 publish |

토큰 묶기(batching) 팁: 10ms 간격으로 토큰을 모아서 한 번에 보내면 Redis 호출 횟수가 10배 줄어요. 브라우저에서는 체감 지연이 거의 없고, 서버 부하는 크게 줄어듭니다.

```python
# 토큰 배치 전송 예시
async def handle_ai_stream_batched(room_id: str, messages: list):
    batch = []
    last_flush = asyncio.get_event_loop().time()

    async for token in stream_response(room_id, messages):
        batch.append(token)
        now = asyncio.get_event_loop().time()

        # 10ms마다 또는 배치가 20개 쌓이면 flush
        if now - last_flush > 0.01 or len(batch) >= 20:
            await bus.publish(f"room:{room_id}", {
                "type": "ai_tokens",
                "content": "".join(batch),
            })
            batch = []
            last_flush = now

    # 남은 배치 flush
    if batch:
        await bus.publish(f"room:{room_id}", {
            "type": "ai_done",
            "content": "".join(batch),
        })
```

---

## 8. 더 알아보기

- FastAPI WebSocket 공식 문서: `fastapi.tiangolo.com/advanced/websockets`
- Redis Pub/Sub 패턴: `redis.io/docs/manual/pubsub`
- [플레이북 37: AI 에이전트 컨텍스트 윈도우 관리](../../claude-code/playbooks/37-context-window-management.md)
- [워크플로우: AI 개발자 일일 자동화](../../workflows/ai-developer-daily-workflow-automation.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
