# AI 에이전트 기반 실시간 알림 시스템 구현 예제

> Claude API + WebSocket + Redis로 구축하는 이벤트 기반 알림 시스템 — 우선순위 큐, 사용자별 필터링, 모바일 푸시 연동까지

## 이 예제에서 배울 수 있는 것

- WebSocket과 Redis Pub/Sub를 조합한 실시간 알림 아키텍처 설계
- 우선순위 큐(Redis Sorted Set)로 알림 중요도별 처리 순서 제어
- 사용자별 구독 필터링과 AI 기반 알림 내용 개인화
- FCM/APNs 모바일 푸시와 WebSocket 채널 동시 연동
- Claude API로 알림 내용을 맥락에 맞게 요약·변환하는 패턴

## 프로젝트 구조

```
ai-notification-system/
├── server/
│   ├── app.py              # FastAPI 메인 서버
│   ├── websocket.py        # WebSocket 연결 관리자
│   ├── redis_client.py     # Redis Pub/Sub + Sorted Set
│   ├── notification.py     # 알림 처리 로직
│   ├── ai_summarizer.py    # Claude API 알림 요약
│   └── push_sender.py      # 모바일 푸시 전송
├── client/
│   ├── index.html          # 브라우저 데모 클라이언트
│   └── ws_client.py        # Python 테스트 클라이언트
├── docker-compose.yml
├── requirements.txt
└── README.md
```

## 시작하기

### 사전 준비

- Python 3.11+
- Docker & Docker Compose
- Anthropic API 키 (`ANTHROPIC_API_KEY`)
- Redis 7.0+ (Docker로 실행 가능)

### 설치 및 실행

```bash
# 레포 클론
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-notification-system

# 환경 변수 설정
cp .env.example .env
# .env 파일에서 ANTHROPIC_API_KEY 등 설정

# Docker로 Redis 실행
docker-compose up -d redis

# Python 의존성 설치
pip install -r requirements.txt

# 서버 실행
uvicorn server.app:app --reload --port 8000
```

### Docker 전체 실행 (권장)

```bash
docker-compose up --build
# http://localhost:8000 에서 데모 확인
```

## 핵심 코드

### 1. WebSocket 연결 관리자

```python
# server/websocket.py
from fastapi import WebSocket
from typing import Dict, Set
import asyncio

class ConnectionManager:
    def __init__(self):
        # user_id -> WebSocket 연결들
        self.active: Dict[str, Set[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        if user_id not in self.active:
            self.active[user_id] = set()
        self.active[user_id].add(websocket)

    def disconnect(self, websocket: WebSocket, user_id: str):
        if user_id in self.active:
            self.active[user_id].discard(websocket)
            if not self.active[user_id]:
                del self.active[user_id]

    async def send_to_user(self, user_id: str, message: dict):
        """특정 사용자의 모든 연결에 메시지 전송"""
        if user_id not in self.active:
            return
        dead = set()
        for ws in self.active[user_id]:
            try:
                await ws.send_json(message)
            except Exception:
                dead.add(ws)
        # 끊긴 연결 정리
        for ws in dead:
            self.active[user_id].discard(ws)

    async def broadcast(self, message: dict):
        """모든 연결된 사용자에게 브로드캐스트"""
        for user_id in list(self.active.keys()):
            await self.send_to_user(user_id, message)

manager = ConnectionManager()
```

**핵심 포인트:** `Set[WebSocket]`으로 같은 사용자의 여러 탭/디바이스를 동시에 지원합니다.

### 2. Redis 우선순위 큐

```python
# server/redis_client.py
import redis.asyncio as aioredis
import json
import time

class NotificationQueue:
    def __init__(self, redis_url: str = "redis://localhost:6379"):
        self.redis = aioredis.from_url(redis_url, decode_responses=True)

    async def enqueue(self, user_id: str, notification: dict, priority: int = 5):
        """
        priority: 1(긴급) ~ 10(낮음)
        Redis Sorted Set 사용 — score가 낮을수록 먼저 처리
        """
        score = priority * 1e10 + time.time()  # 같은 우선순위 내에서 시간순
        payload = json.dumps(notification)
        key = f"notif:queue:{user_id}"
        await self.redis.zadd(key, {payload: score})
        await self.redis.expire(key, 86400)  # 24시간 후 자동 삭제

    async def dequeue_top(self, user_id: str, count: int = 5) -> list[dict]:
        """우선순위 높은 알림부터 꺼내기"""
        key = f"notif:queue:{user_id}"
        items = await self.redis.zpopmin(key, count)
        return [json.loads(item[0]) for item in items]

    async def publish(self, channel: str, message: dict):
        """Pub/Sub으로 실시간 브로드캐스트"""
        await self.redis.publish(channel, json.dumps(message))

    async def subscribe(self, channel: str):
        """채널 구독 — 비동기 제너레이터"""
        pubsub = self.redis.pubsub()
        await pubsub.subscribe(channel)
        async for message in pubsub.listen():
            if message["type"] == "message":
                yield json.loads(message["data"])
```

### 3. Claude API 알림 요약

```python
# server/ai_summarizer.py
import anthropic
from typing import Optional

client = anthropic.AsyncAnthropic()

async def summarize_notification(
    raw_event: dict,
    user_context: Optional[str] = None
) -> dict:
    """
    원시 이벤트를 사용자 맥락에 맞는 알림으로 변환
    예: GitHub PR 병합 이벤트 -> "김철수님이 장바구니 기능 PR을 머지했어요"
    """
    prompt = f"""다음 이벤트를 사용자에게 보낼 짧은 알림 메시지로 변환해 주세요.

이벤트:
{raw_event}

{"사용자 맥락: " + user_context if user_context else ""}

요구사항:
- 제목: 10자 이내, 핵심만
- 본문: 30자 이내, 구체적인 내용
- 중요도: low / medium / high / urgent 중 하나
- JSON으로만 응답

출력 형식:
{{"title": "...", "body": "...", "priority": "medium"}}"""

    message = await client.messages.create(
        model="claude-opus-4-5",
        max_tokens=200,
        messages=[{"role": "user", "content": prompt}]
    )

    import json
    text = message.content[0].text.strip()
    # JSON 파싱 (마크다운 코드블록 제거)
    if "```" in text:
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())

# 우선순위 매핑
PRIORITY_MAP = {"low": 8, "medium": 5, "high": 2, "urgent": 1}
```

### 4. FastAPI 메인 서버

```python
# server/app.py
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, BackgroundTasks
from fastapi.responses import HTMLResponse
import asyncio
from .websocket import manager
from .redis_client import NotificationQueue
from .ai_summarizer import summarize_notification, PRIORITY_MAP
from .push_sender import send_push

app = FastAPI(title="AI Notification System")
queue = NotificationQueue()

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await manager.connect(websocket, user_id)
    try:
        # 미전달 알림 먼저 전송
        pending = await queue.dequeue_top(user_id, count=10)
        for notif in pending:
            await websocket.send_json({"type": "pending", **notif})

        # 연결 유지 (클라이언트 메시지 수신)
        while True:
            data = await websocket.receive_json()
            if data.get("type") == "ack":
                pass  # 클라이언트 수신 확인
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)

@app.post("/notify/{user_id}")
async def create_notification(
    user_id: str,
    event: dict,
    background_tasks: BackgroundTasks
):
    """이벤트 수신 -> AI 요약 -> 실시간 전송"""
    # AI로 알림 내용 변환
    notif = await summarize_notification(event)
    priority = PRIORITY_MAP.get(notif.get("priority", "medium"), 5)

    # WebSocket으로 즉시 전송 (연결된 경우)
    if user_id in manager.active:
        await manager.send_to_user(user_id, {"type": "realtime", **notif})
    else:
        # 오프라인: 큐에 저장
        await queue.enqueue(user_id, notif, priority=priority)
        # 모바일 푸시도 전송
        background_tasks.add_task(send_push, user_id, notif)

    return {"status": "sent", "priority": notif.get("priority")}

@app.post("/broadcast")
async def broadcast_notification(event: dict):
    """전체 사용자 브로드캐스트"""
    notif = await summarize_notification(event)
    await manager.broadcast({"type": "broadcast", **notif})
    return {"status": "broadcast", "connected_users": len(manager.active)}
```

### 5. 모바일 푸시 연동 (선택)

```python
# server/push_sender.py
import httpx
import os

FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY", "")

async def send_push(user_id: str, notification: dict):
    """Firebase FCM 푸시 전송 (디바이스 토큰은 DB에서 조회)"""
    device_token = await get_device_token(user_id)  # 구현 필요
    if not device_token:
        return

    async with httpx.AsyncClient() as client:
        await client.post(
            "https://fcm.googleapis.com/fcm/send",
            headers={"Authorization": f"key={FCM_SERVER_KEY}"},
            json={
                "to": device_token,
                "notification": {
                    "title": notification.get("title", ""),
                    "body": notification.get("body", ""),
                },
                "data": {"priority": notification.get("priority", "medium")},
            },
        )

async def get_device_token(user_id: str) -> str | None:
    # Redis나 DB에서 디바이스 토큰 조회
    # 실제 구현에서는 사용자 등록 API를 통해 저장
    return None
```

## 실행 예시

```bash
# 서버 실행 후 이벤트 전송 테스트
curl -X POST http://localhost:8000/notify/user-123 \
  -H "Content-Type: application/json" \
  -d '{"type": "pr_merged", "repo": "my-app", "author": "김철수", "branch": "feature/cart"}'

# 응답 예시
# {"status": "sent", "priority": "medium"}

# WebSocket 클라이언트로 수신 확인
# ws://localhost:8000/ws/user-123 연결 시 실시간 메시지 수신
```

## 성능 고려사항

| 항목 | 설정 | 설명 |
|------|------|------|
| Redis 연결 풀 | `max_connections=100` | 동시 연결 처리 |
| WebSocket 타임아웃 | 30초 ping/pong | 유휴 연결 정리 |
| AI 요약 캐시 | Redis TTL 1시간 | 동일 이벤트 중복 호출 방지 |
| 큐 보존 기간 | 24시간 | 오프라인 사용자 알림 유지 |
| 우선순위 범위 | 1(긴급) ~ 10(낮음) | 비즈니스 규칙에 맞게 조정 |

## AI 활용 포인트

| 상황 | 활용 방식 |
|------|----------|
| 이벤트 → 알림 변환 | 원시 이벤트 데이터를 사람이 읽기 좋은 메시지로 변환 |
| 알림 중요도 판단 | 이벤트 컨텍스트 기반 우선순위 자동 분류 |
| 다국어 알림 | 사용자 언어 설정에 따라 자동 번역 |
| 알림 그룹화 | 비슷한 이벤트를 하나의 요약 알림으로 묶기 |

## 확장 아이디어

- **알림 그룹화:** 5분 내 같은 사용자의 동일 유형 알림을 하나로 묶기
- **스마트 타이밍:** 사용자 활동 패턴 기반으로 방해 최소화 시간대 선택
- **A/B 테스트:** 알림 문구 변형으로 클릭률 측정
- **읽음 확인 동기화:** 여러 디바이스 간 읽음 상태 실시간 동기화

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
