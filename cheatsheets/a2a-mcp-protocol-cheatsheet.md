# A2A + MCP 프로토콜 통합 치트시트

> AI 에이전트 통신의 두 축 — A2A(에이전트 간)와 MCP(에이전트-도구 간)를 한 페이지로 정리

## 두 프로토콜이 필요한 이유

AI 에이전트가 실무에서 제대로 동작하려면 두 가지 통신이 필요해요.
하나는 **외부 도구와 연결**하는 것(MCP), 다른 하나는 **다른 에이전트와 협업**하는 것(A2A)이에요.
이 두 프로토콜을 조합하면 에이전트가 도구를 사용하면서 동시에 다른 에이전트에게 작업을 위임할 수 있어요.

| 구분 | MCP | A2A |
|------|-----|-----|
| 역할 | 에이전트 → 도구/데이터 연결 | 에이전트 ↔ 에이전트 협업 |
| 통신 방식 | JSON-RPC 2.0 | HTTP POST + SSE |
| 관계 | 수직 (호스트-서버) | 수평 (피어-투-피어) |
| 핵심 단위 | Tool, Resource, Prompt | Task, Agent Card, Artifact |
| 디스커버리 | 서버 목록 수동 설정 | `.well-known/agent.json` 자동 탐색 |

## A2A 핵심 개념 5가지

### 1. Agent Card — 에이전트 명함

에이전트가 자신의 능력을 JSON으로 공개하는 메타데이터예요.
클라이언트 에이전트는 이 카드를 보고 적합한 에이전트를 선택해요.

```json
{
  "name": "code-reviewer",
  "description": "코드 리뷰 및 보안 취약점 분석",
  "url": "https://agent.example.com",
  "skills": [
    {
      "id": "security-audit",
      "name": "보안 감사",
      "description": "OWASP Top 10 기준 코드 보안 검사"
    }
  ],
  "authentication": {
    "schemes": ["Bearer"]
  }
}
```

| 필드 | 설명 | 필수 |
|------|------|------|
| `name` | 에이전트 식별 이름 | O |
| `url` | A2A 엔드포인트 URL | O |
| `skills` | 제공하는 기능 목록 | O |
| `authentication` | 인증 방식 | 선택 |
| `provider` | 제공 조직 정보 | 선택 |

### 2. Task — 작업 생명주기

A2A에서 모든 상호작용은 Task 단위로 관리돼요.

```
submitted → working → completed
                   ↘ failed
                   ↘ canceled
```

```bash
# Task 생성 요청 (HTTP POST)
curl -X POST https://agent.example.com/a2a \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tasks/send",
    "params": {
      "id": "task-001",
      "message": {
        "role": "user",
        "parts": [{"type": "text", "text": "이 PR의 보안 취약점을 검사해줘"}]
      }
    }
  }'
```

| 상태 | 의미 | 전환 조건 |
|------|------|----------|
| `submitted` | 요청 접수됨 | 초기 상태 |
| `working` | 처리 중 | 에이전트가 작업 시작 |
| `completed` | 완료 | 결과 Artifact 생성 |
| `failed` | 실패 | 에러 발생 |
| `canceled` | 취소됨 | 클라이언트 취소 요청 |

### 3. Artifact — 작업 결과물

Task 완료 시 생성되는 결과 데이터예요. 텍스트, 파일, 구조화된 데이터 모두 가능해요.

```json
{
  "name": "security-report",
  "parts": [
    {
      "type": "text",
      "text": "## 보안 감사 결과\n- SQL 인젝션 위험: 2건\n- XSS 취약점: 1건"
    }
  ]
}
```

### 4. 스트리밍 — 실시간 진행 상황

긴 작업은 SSE(Server-Sent Events)로 실시간 업데이트를 받을 수 있어요.

```bash
# 스트리밍 Task 요청
curl -X POST https://agent.example.com/a2a \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tasks/sendSubscribe",
    "params": {
      "id": "task-002",
      "message": {
        "role": "user",
        "parts": [{"type": "text", "text": "전체 코드베이스 분석해줘"}]
      }
    }
  }'
```

### 5. Push Notification — 비동기 알림

작업이 오래 걸릴 때 웹훅으로 완료 알림을 받는 패턴이에요.

```json
{
  "pushNotificationConfig": {
    "url": "https://my-server.com/webhook/a2a",
    "authentication": {
      "schemes": ["Bearer"],
      "credentials": "webhook-token-123"
    }
  }
}
```

## MCP vs A2A 선택 기준

| 상황 | 사용 프로토콜 | 이유 |
|------|-------------|------|
| DB 쿼리 실행 | MCP | 도구 호출 |
| GitHub PR 생성 | MCP | API 도구 연결 |
| 코드 리뷰 에이전트에 위임 | A2A | 에이전트 간 협업 |
| 번역 에이전트에 문서 전달 | A2A | 태스크 위임 |
| 파일 읽기/쓰기 | MCP | 리소스 접근 |
| 여러 에이전트 동시 작업 조율 | A2A | 오케스트레이션 |
| 로컬 CLI 도구 실행 | MCP | 로컬 서버 |
| 원격 에이전트 능력 탐색 | A2A | Agent Card 디스커버리 |

## A2A + MCP 통합 아키텍처

실전에서는 두 프로토콜을 함께 사용해요. 오케스트레이터 에이전트가 A2A로 전문 에이전트에 위임하고, 각 에이전트는 MCP로 도구를 사용하는 구조예요.

```
[사용자]
   │
   ▼
[오케스트레이터 에이전트]
   ├── A2A ──► [코드 리뷰 에이전트] ──── MCP ──► GitHub API
   ├── A2A ──► [테스트 에이전트]   ──── MCP ──► Jest Runner
   └── A2A ──► [배포 에이전트]     ──── MCP ──► Docker / K8s
```

### 통합 설정 예시

```yaml
# 오케스트레이터 설정
orchestrator:
  mcp_servers:
    - name: github
      transport: stdio
      command: npx @modelcontextprotocol/server-github

  a2a_agents:
    - name: code-reviewer
      url: https://reviewer.internal.dev/a2a
      skills: ["security-audit", "style-check"]
    - name: test-runner
      url: https://tester.internal.dev/a2a
      skills: ["unit-test", "integration-test"]
```

### 연동 워크플로 예시

```python
# 1. MCP로 PR 정보 가져오기
pr_data = mcp_client.call_tool("github", "get_pr", {"number": 42})

# 2. A2A로 코드 리뷰 에이전트에 위임
review_task = a2a_client.send_task(
    agent_url="https://reviewer.internal.dev/a2a",
    message=f"이 PR을 리뷰해줘: {pr_data['diff']}"
)

# 3. 결과 대기 + 수집
result = a2a_client.get_task(review_task.id)

# 4. MCP로 리뷰 코멘트 작성
mcp_client.call_tool("github", "create_review", {
    "pr_number": 42,
    "body": result.artifacts[0].text
})
```

## 보안 체크리스트

| 항목 | MCP | A2A |
|------|-----|-----|
| 인증 | 로컬 프로세스 신뢰 | Bearer/OAuth 토큰 |
| 권한 제어 | Tool 단위 허용/차단 | Skill 단위 접근 제어 |
| 네트워크 | 주로 로컬 (stdio) | HTTPS 필수 |
| 입력 검증 | JSON Schema 활용 | Agent Card 스킬 매칭 |
| 감사 로그 | 도구 호출 기록 | Task 상태 변경 이력 |

## 실전 도입 로드맵

| 단계 | 작업 | 예상 기간 |
|------|------|----------|
| 1단계 | MCP 서버 세팅 (GitHub, DB 등) | 1~2일 |
| 2단계 | 단일 에이전트 + MCP 도구 통합 | 1주 |
| 3단계 | Agent Card 작성 + A2A 서버 배포 | 1~2주 |
| 4단계 | 오케스트레이터로 멀티 에이전트 연결 | 2~3주 |
| 5단계 | 모니터링 + 보안 강화 | 지속적 |

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| MCP와 A2A 역할 혼동 | MCP=도구 연결, A2A=에이전트 협업으로 명확히 구분 |
| Agent Card 없이 직접 호출 | 반드시 `.well-known/agent.json` 디스커버리 구현 |
| Task 상태 폴링 과다 | SSE 스트리밍 또는 Push Notification 사용 |
| 인증 없이 A2A 엔드포인트 노출 | Bearer 토큰 + HTTPS 필수 적용 |
| 에이전트 실패 시 무한 재시도 | 최대 재시도 횟수 + 서킷 브레이커 적용 |
| MCP 서버에 과도한 권한 | 읽기 전용 토큰 + 허용 도구 화이트리스트 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
