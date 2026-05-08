# A2A 프로토콜 치트시트

> AI 에이전트 간 통신을 위한 A2A(Agent-to-Agent) 프로토콜 핵심 개념과 설정 — 한 페이지 요약

---

## A2A란?

Google이 2025년 발표하고 Linux Foundation이 관리하는 에이전트 간 통신 표준 프로토콜. 서로 다른 프레임워크로 만들어진 AI 에이전트가 서로를 발견하고 태스크를 주고받을 수 있도록 합니다.

| 구분 | MCP | A2A |
|------|-----|-----|
| 방향 | 에이전트 ↔ 도구/컨텍스트 (수직) | 에이전트 ↔ 에이전트 (수평) |
| 역할 | 에이전트에게 능력 제공 | 에이전트 간 태스크 위임 |
| 통신 | 로컬/원격 함수 호출 | HTTP + Server-Sent Events |
| 비유 | 플러그인 시스템 | 마이크로서비스 아키텍처 |

---

## Agent Card — 에이전트 명함

에이전트가 자신의 능력을 선언하는 JSON 파일. `/.well-known/agent.json`에 공개 호스팅합니다.

```json
{
  "name": "CodeReviewAgent",
  "description": "PR 코드를 분석하고 리뷰 코멘트를 생성하는 에이전트",
  "url": "https://my-agent.example.com",
  "version": "1.0.0",
  "provider": {
    "organization": "TenBuilder",
    "url": "https://tenbuilder.io"
  },
  "capabilities": {
    "streaming": true,
    "pushNotifications": false
  },
  "authentication": {
    "schemes": ["bearer"]
  },
  "skills": [
    {
      "id": "code-review",
      "name": "Code Review",
      "description": "PR diff를 받아 개선점과 버그를 찾아 리뷰 코멘트를 생성",
      "inputModes": ["text"],
      "outputModes": ["text"]
    }
  ]
}
```

**주요 필드**

| 필드 | 필수 | 설명 |
|------|------|------|
| `name` | ✅ | 에이전트 식별 이름 |
| `url` | ✅ | 에이전트 엔드포인트 URL |
| `skills` | ✅ | 제공하는 능력 목록 |
| `capabilities.streaming` | — | SSE 스트리밍 지원 여부 |
| `authentication.schemes` | — | 지원 인증 방식 (`bearer`, `oauth2` 등) |

---

## 태스크 라이프사이클

```
클라이언트 에이전트          리모트 에이전트
      │                           │
      │── tasks/send ────────────>│  submitted
      │                           │  ↓
      │                           │  working (처리 중)
      │<── streaming updates ─────│
      │                           │  ↓
      │<── task complete ─────────│  completed
                                     (또는 failed / canceled / input-required)
```

**태스크 상태 정의**

| 상태 | 의미 |
|------|------|
| `submitted` | 태스크 수신 완료, 처리 대기 중 |
| `working` | 에이전트가 처리 중 |
| `input-required` | 사용자 추가 입력 필요 |
| `completed` | 태스크 완료 |
| `failed` | 처리 실패 |
| `canceled` | 취소됨 |

---

## 핵심 API 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `GET` | `/.well-known/agent.json` | Agent Card 조회 |
| `POST` | `/a2a` (또는 `agent.url`) | 태스크 전송 |
| `GET` | `/a2a/tasks/{id}` | 태스크 상태 조회 |
| `DELETE` | `/a2a/tasks/{id}` | 태스크 취소 |

---

## 태스크 요청 예시

```bash
# 태스크 전송 (단방향)
curl -X POST https://my-agent.example.com/a2a \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "task-001",
    "message": {
      "role": "user",
      "parts": [
        {
          "type": "text",
          "text": "다음 PR diff를 리뷰해줘:\n\n+ const x = null\n+ if (x.length > 0) {"
        }
      ]
    }
  }'
```

```bash
# 스트리밍 응답 수신
curl -N -X POST https://my-agent.example.com/a2a \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"id": "task-002", "message": {...}}'
```

---

## 인증 패턴

A2A는 OpenAPI 보안 스킴을 그대로 따릅니다.

```json
// Agent Card에서 선언
"authentication": {
  "schemes": ["bearer"],
  "credentials": "https://auth.example.com/token"
}
```

| 방식 | 사용 시기 |
|------|----------|
| `bearer` | 서비스 간 API 토큰 (가장 일반적) |
| `oauth2` | 사용자 위임 권한이 필요할 때 |
| `apiKey` | 단순 키 기반 접근 |

---

## Python으로 A2A 에이전트 만들기

```python
# Google ADK 사용
from google.adk.a2a import A2AServer

server = A2AServer(
    agent_card={
        "name": "SummaryAgent",
        "url": "http://localhost:8080",
        "skills": [{"id": "summarize", "name": "Summarize Text"}]
    }
)

@server.skill("summarize")
async def summarize(task):
    text = task.message.parts[0].text
    summary = await my_llm.summarize(text)
    return {"text": summary}

server.run(port=8080)
```

---

## A2A vs MCP — 언제 뭘 쓰나?

| 상황 | 권장 |
|------|------|
| 에이전트가 DB/파일/API에 접근해야 할 때 | MCP |
| 에이전트가 다른 에이전트에게 태스크를 위임할 때 | A2A |
| 멀티 에이전트 워크플로우 구성 | A2A + MCP 병행 |
| 기존 REST API를 에이전트화할 때 | A2A |

---

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| Agent Card를 내부 URL에만 두는 경우 | `/.well-known/agent.json` 공개 경로 필수 |
| 스트리밍을 선언하고 단방향만 지원 | `capabilities.streaming: false`로 정확히 선언 |
| 태스크 ID를 재사용하는 경우 | 태스크마다 고유 UUID 사용 |
| 인증 없이 에이전트를 공개하는 경우 | 프로덕션에서는 반드시 bearer/oauth2 설정 |

---

**더 자세한 내용:** [guides/51-a2a-mcp-integration.md](../guides/51-a2a-mcp-integration.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
