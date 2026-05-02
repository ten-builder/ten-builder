# Claude Code Channels 다중 에이전트 조율 치트시트

> 여러 에이전트가 실시간으로 협력하는 패턴 — 한 페이지로 정리

## Channels란?

Claude Code의 Channels는 외부 시스템이 실행 중인 세션에 실시간 이벤트를 주입할 수 있는 MCP 기반 플러그인입니다. 2026년 3월 출시 이후, 에이전트 간 조율의 핵심 인프라로 자리잡았습니다.

```
외부 트리거 → Channel → Claude Code 세션 → 에이전트 실행 → 결과 반환
```

## 핵심 개념

| 개념 | 설명 |
|------|------|
| **Channel** | 이벤트를 세션에 주입하는 MCP 서버 |
| **Dispatch** | 채널로 들어온 이벤트를 에이전트에 라우팅하는 조율 레이어 |
| **구독자** | 특정 채널 이벤트를 처리하는 에이전트 |
| **발신자 허용 목록** | 채널에 메시지를 보낼 수 있는 계정/시스템 목록 |

## 채널 유형

| 유형 | 방향 | 사용 예시 |
|------|------|----------|
| 단방향 수신 | 외부 → 에이전트 | CI 실패 알림, 웹훅 수신 |
| 양방향 | 외부 ↔ 에이전트 | Telegram/Discord 채팅 브릿지 |
| 에이전트 간 | 에이전트 ↔ 에이전트 | 오케스트레이터-워커 조율 |

## 기본 설정

### 채널 연결 (CLAUDE.md)

```yaml
# .claude/channels.yaml
channels:
  - name: ci-alerts
    type: webhook
    allowlist:
      - github-actions
  - name: team-chat
    type: discord
    allowlist:
      - tenbuilder10x

dispatch:
  enabled: true
  routing:
    ci-alerts: "@reviewer"
    team-chat: "@assistant"
```

### 에이전트 구독 등록

```bash
# 에이전트를 특정 채널에 구독
claude --subscribe ci-alerts --role reviewer
claude --subscribe team-chat --role assistant

# 여러 채널 동시 구독
claude --subscribe ci-alerts,deploy-events --role ops-agent
```

## 메시지 라우팅 패턴

### 패턴 1: 역할 기반 라우팅

```
채널 이벤트 → Dispatch → 역할 매핑 → 담당 에이전트
```

```yaml
# 역할별 에이전트 매핑
dispatch:
  routes:
    - channel: code-review
      match: "PR opened"
      agent: "@reviewer"
    - channel: security-scan
      match: "CVE detected"
      agent: "@security-agent"
    - channel: deploy-pipeline
      match: "Build failed"
      agent: "@ops-agent"
```

### 패턴 2: 콘텐츠 기반 라우팅

```bash
# 이벤트 내용에 따라 에이전트 선택
claude dispatch route \
  --if "contains:error" --to "@debugger" \
  --if "contains:performance" --to "@profiler" \
  --default "@general-agent"
```

### 패턴 3: 오케스트레이터-워커

```
오케스트레이터 세션
    ├─ 채널 A → 워커 1 (구현)
    ├─ 채널 B → 워커 2 (테스트)
    └─ 채널 C → 워커 3 (리뷰)
         ↓
    결과 집계 → 오케스트레이터 → PR 생성
```

## 실전 워크플로우

### CI 실패 자동 대응

```bash
# GitHub Actions에서 채널로 이벤트 전송
- name: Notify Claude on failure
  if: failure()
  run: |
    curl -X POST "$CLAUDE_CHANNEL_WEBHOOK" \
      -H "Authorization: Bearer $CHANNEL_TOKEN" \
      -d '{
        "event": "build_failed",
        "branch": "${{ github.ref_name }}",
        "error_log": "${{ steps.test.outputs.log }}"
      }'
```

에이전트 응답:
1. 에러 로그 분석
2. 관련 코드 파일 검토
3. 수정 패치 생성
4. PR 자동 생성

### 팀 채팅 브릿지

```
Discord 메시지 → Channels MCP → Claude 세션
                                    ↓
                         코드 조회, 실행, 커밋
                                    ↓
                         Discord로 결과 응답
```

```yaml
# Discord 채널 설정
channels:
  - name: dev-assistant
    type: discord
    server_id: "YOUR_SERVER_ID"
    channel_id: "YOUR_CHANNEL_ID"
    allowlist:
      - "팀원1#1234"
      - "팀원2#5678"
```

## 에이전트 간 통신

### 태스크 큐 패턴

```python
# 오케스트레이터가 워커에게 태스크 전달
async def dispatch_task(channel, task):
    await channel.send({
        "type": "task",
        "id": generate_id(),
        "payload": task,
        "priority": task.get("priority", "normal"),
        "timeout": 300
    })

# 워커가 결과 반환
async def report_result(channel, task_id, result):
    await channel.send({
        "type": "result",
        "task_id": task_id,
        "status": "completed",
        "output": result
    })
```

### 상태 공유 패턴

```yaml
# 공유 상태 채널 설정
channels:
  - name: shared-state
    type: in-memory
    persistence: file
    path: .claude/shared-state.json

# 에이전트가 상태 업데이트
dispatch:
  state_sync:
    enabled: true
    channel: shared-state
    sync_interval: 30s
```

## 흔한 실수 & 해결

| 실수 | 원인 | 해결 |
|------|------|------|
| 이벤트가 전달되지 않음 | 발신자가 허용 목록에 없음 | `channels.yaml`의 `allowlist`에 추가 |
| 에이전트가 응답하지 않음 | 구독이 끊어짐 | `claude --subscribe` 재실행 |
| 메시지 순서 뒤바뀜 | 비동기 처리 시 순서 미보장 | `dispatch.ordered: true` 설정 |
| 토큰 비용 폭증 | 모든 이벤트를 대형 모델로 처리 | 이벤트 유형별 모델 라우팅 적용 |
| 루프 발생 | 에이전트가 자신의 채널에 메시지 전송 | `allowlist`에 자기 자신 제외 |

## 모델 라우팅 최적화

```yaml
# 이벤트 복잡도에 따라 모델 선택
dispatch:
  model_routing:
    simple_query: claude-haiku-4-5      # 단순 조회, 요약
    code_review: claude-sonnet-4-6      # 코드 분석, PR 리뷰
    architecture: claude-opus-4-6       # 복잡한 설계 결정
```

비용 절감 효과: 단순 이벤트에 haiku 사용 시 최대 **70% 절감**

## 보안 체크리스트

- [ ] 발신자 허용 목록 설정 (`allowlist`)
- [ ] 채널 토큰 환경변수로 관리 (`CLAUDE_CHANNEL_TOKEN`)
- [ ] 에이전트 권한 최소화 (읽기 전용 채널은 `read-only` 설정)
- [ ] 이벤트 로그 감사 (`dispatch.audit_log: true`)
- [ ] 프로덕션/스테이징 채널 분리

## Dispatch + Channels 조합 패턴

```
[트리거] GitHub PR 오픈
    ↓
[채널] code-review-channel
    ↓
[Dispatch] PR 크기 분류
    ├─ 소형 PR (< 50줄) → haiku + @fast-reviewer
    ├─ 중형 PR (50~300줄) → sonnet + @reviewer
    └─ 대형 PR (> 300줄) → opus + @senior-reviewer
    ↓
[결과] 리뷰 코멘트 → GitHub PR에 자동 게시
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
