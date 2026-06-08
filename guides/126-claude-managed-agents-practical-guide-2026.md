# 가이드 126: Claude Managed Agents 실전 가이드 2026

> 프로덕션 AI 에이전트 인프라를 직접 구축하지 않아도 되는 시대가 왔습니다 — Anthropic이 런타임을 대신 관리해 줍니다.

## 소요 시간

30-50분

## 사전 준비

- Anthropic API 키 (anthropic.com/console)
- Python 3.11+ 또는 Node.js 20+
- Managed Agents 베타 접근 (콘솔에서 신청)

---

## Claude Managed Agents란?

2026년 4월 8일, Anthropic이 공개 베타로 출시한 **Claude Managed Agents**는 AI 에이전트 개발의 가장 어려운 문제를 해결합니다. 기존에는 에이전트를 프로덕션에 올리려면 직접 런타임, 메모리, 세션 관리, 오케스트레이션을 구축해야 했습니다. Managed Agents는 이 인프라 전체를 API 뒤에 숨겨두고, 개발자는 에이전트 로직에만 집중할 수 있게 합니다.

**출시 이후 주요 업데이트:**

| 날짜 | 업데이트 |
|------|----------|
| 2026-04-08 | 공개 베타: Agent, Environment, Session API |
| 2026년 4월 중순 | Memory API 추가 |
| 2026-05-07 | Dreaming, Outcomes, 멀티에이전트 오케스트레이션, Webhooks |

---

## Step 1: 첫 번째 Managed Agent 만들기

모든 Managed Agents API 요청에는 `managed-agents-2026-04-01` 베타 헤더가 필요합니다. SDK를 사용하면 자동으로 추가됩니다.

```python
import anthropic

client = anthropic.Anthropic(api_key="your-key")

# 에이전트 생성
agent = client.beta.agents.create(
    model="claude-opus-4-5",
    name="code-reviewer",
    description="GitHub PR을 자동으로 리뷰하는 에이전트",
    instructions="""
    PR의 변경사항을 분석하고 다음을 확인해:
    - 잠재적 버그와 엣지 케이스
    - 성능 문제
    - 보안 취약점
    - 코드 스타일 일관성
    한국어로 리뷰 코멘트를 작성해줘.
    """,
    tools=[{"type": "computer_use"}, {"type": "text_editor"}],
    betas=["managed-agents-2026-04-01"]
)

print(f"에이전트 생성됨: {agent.id}")
```

```bash
# 환경 변수 설정
export ANTHROPIC_API_KEY="sk-ant-..."
export MANAGED_AGENT_ID="agt_..."
```

---

## Step 2: 세션 시작 + 작업 실행

```python
# 세션 생성
session = client.beta.agents.sessions.create(
    agent_id=agent.id,
)

# 작업 실행
response = client.beta.agents.sessions.submit_turn(
    agent_id=agent.id,
    session_id=session.id,
    messages=[{
        "role": "user",
        "content": "PR #247의 변경사항을 리뷰해줘: https://github.com/my-org/my-repo/pull/247"
    }]
)

# 결과 확인
for block in response.content:
    if block.type == "text":
        print(block.text)
```

**세션의 특징:**

| 속성 | 설명 |
|------|------|
| 격리된 컨텍스트 | 각 세션은 독립적인 메모리를 가짐 |
| 지속 가능 | 세션을 닫지 않으면 대화 이어서 진행 |
| 비용 | 베타 기간 $0.08/세션시간 |

---

## Step 3: 멀티에이전트 오케스트레이션

여러 에이전트가 병렬로 복잡한 작업을 나눠 처리합니다. 코디네이터 에이전트가 서브에이전트에 작업을 위임합니다.

```python
# 서브에이전트 스폰 (코디네이터 에이전트 내부에서)
response = client.beta.agents.sessions.submit_turn(
    agent_id=coordinator_agent_id,
    session_id=session.id,
    messages=[{
        "role": "user",
        "content": """
        다음 작업을 병렬로 처리해줘:
        1. 백엔드 API 변경사항 리뷰
        2. 프론트엔드 컴포넌트 분석
        3. 데이터베이스 마이그레이션 스크립트 검증
        각 작업에 전문 에이전트를 할당해.
        """
    }],
    agent_config={
        "multiagent": {
            "enabled": True,
            "max_subagents": 3,
            "coordination_strategy": "parallel"
        }
    }
)
```

**오케스트레이션 패턴:**

```
코디네이터 에이전트
├── 서브에이전트 A (백엔드 리뷰)    ─┐
├── 서브에이전트 B (프론트엔드 분석) ─┼─ 병렬 실행
└── 서브에이전트 C (DB 검증)        ─┘
         ↓
    결과 취합 + 최종 리포트
```

---

## Step 4: Outcomes — 결과 기반 실행

목표를 정의하면 에이전트가 스스로 완료 여부를 판단합니다. 루프를 직접 구현할 필요가 없습니다.

```python
# Outcome 정의
outcome_session = client.beta.agents.sessions.create(
    agent_id=agent.id,
    outcome={
        "type": "task_completion",
        "success_criteria": "PR 리뷰 코멘트가 최소 3개 이상 작성되고, 모든 critical 이슈가 명시되어야 함",
        "max_turns": 10,
        "on_success": "webhook",
        "on_failure": "notify"
    }
)
```

**Outcomes vs 수동 루프 비교:**

| | 수동 루프 | Outcomes |
|---|---|---|
| 완료 판단 | 개발자가 직접 구현 | 에이전트가 자동 판단 |
| 재시도 로직 | 직접 작성 | 자동 처리 |
| 상태 관리 | 외부 DB 필요 | 내장 |
| 코드 복잡도 | 높음 | 낮음 |

---

## Step 5: Webhooks로 비동기 처리

에이전트 작업이 완료되면 서버로 이벤트를 전송합니다. 긴 작업을 폴링 없이 처리할 수 있습니다.

```python
# 웹훅 설정
agent_with_webhook = client.beta.agents.update(
    agent_id=agent.id,
    webhooks={
        "session_completed": "https://api.my-service.com/webhooks/agent",
        "turn_completed": "https://api.my-service.com/webhooks/turn",
        "error": "https://api.my-service.com/webhooks/error"
    }
)
```

```python
# FastAPI 웹훅 수신 예제
from fastapi import FastAPI, Request
import json

app = FastAPI()

@app.post("/webhooks/agent")
async def handle_agent_webhook(request: Request):
    payload = await request.json()
    
    event_type = payload.get("type")
    session_id = payload.get("session_id")
    
    if event_type == "session.completed":
        result = payload.get("result")
        # 결과 처리
        await process_agent_result(session_id, result)
        
    return {"status": "ok"}
```

---

## Step 6: Dreaming — 자기 개선 에이전트

Dreaming은 에이전트가 과거 세션을 검토하고 패턴을 학습해 스스로 개선하는 기능입니다. 연구 프리뷰 단계로 별도 접근 신청이 필요합니다.

```python
# Dreaming 활성화 (연구 프리뷰)
agent_with_dreaming = client.beta.agents.update(
    agent_id=agent.id,
    dreaming={
        "enabled": True,
        "schedule": "daily",        # 매일 자동 실행
        "review_window_days": 7,    # 최근 7일 세션 검토
        "improvement_focus": [
            "accuracy",             # 정확도 향상
            "efficiency",           # 토큰 효율
            "user_satisfaction"     # 사용자 만족도
        ]
    }
)
```

**Dreaming이 하는 일:**

- 지난 세션에서 반복된 실수 패턴 탐지
- 성공적인 응답 패턴 강화
- 비효율적인 도구 사용 방식 개선
- 에이전트 지시사항 자동 업데이트 제안

---

## 실전 사용 패턴

### 패턴 1: 코드 리뷰 자동화

```bash
# GitHub Actions와 연동
# .github/workflows/ai-review.yml

name: AI Code Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - name: Claude Managed Agent Review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          AGENT_ID: ${{ secrets.CODE_REVIEW_AGENT_ID }}
        run: |
          python scripts/managed_agent_review.py \
            --pr-url "${{ github.event.pull_request.html_url }}" \
            --repo "${{ github.repository }}"
```

### 패턴 2: 비동기 대규모 분석

```python
# 100개 파일을 병렬 에이전트로 분석
import asyncio

async def analyze_with_managed_agents(file_list):
    sessions = []
    
    # 병렬 세션 생성
    for batch in chunks(file_list, size=10):
        session = client.beta.agents.sessions.create(
            agent_id=ANALYSIS_AGENT_ID,
            outcome={
                "type": "task_completion",
                "max_turns": 5
            }
        )
        sessions.append((session, batch))
    
    # 결과는 Webhook으로 수신
    return sessions

def chunks(lst, size):
    for i in range(0, len(lst), size):
        yield lst[i:i + size]
```

---

## 비용 계획

| 항목 | 베타 가격 | 예상 월간 비용 |
|------|-----------|---------------|
| 세션 시간 | $0.08/시간 | 1,000세션×10분 = $13.3 |
| 모델 토큰 | 기존 API와 동일 | 사용량에 따라 |
| 멀티에이전트 | 서브에이전트별 별도 과금 | 에이전트 수 × 세션비용 |

**비용 절감 팁:**

- Outcomes로 불필요한 턴 줄이기
- 세션 재사용: 같은 컨텍스트면 새 세션 대신 기존 세션 계속 사용
- 서브에이전트는 실제로 병렬이 필요한 경우에만 사용

---

## 체크리스트

- [ ] Anthropic Console에서 Managed Agents 베타 접근 신청
- [ ] SDK 최신 버전 설치 (`pip install anthropic --upgrade`)
- [ ] 에이전트 지시사항을 명확하고 구체적으로 작성
- [ ] Webhook 엔드포인트 HTTPS + 서명 검증 구현
- [ ] 세션 시간 모니터링으로 비용 관리
- [ ] Dreaming 활성화 전 과거 세션 데이터 충분히 확보 (최소 50세션)
- [ ] 멀티에이전트 사용 시 코디네이터-서브에이전트 책임 명확히 분리

---

## 다음 단계

→ [가이드 71: 멀티에이전트 병렬 코딩 플레이북](../claude-code/playbooks/71-multi-agent-parallel-coding-playbook.md)
→ [가이드 114: LangGraph 멀티에이전트 워크플로우](./114-langgraph-multi-agent-workflow-guide-2026.md)
→ [치트시트: 서브에이전트 오케스트레이션](../cheatsheets/subagent-orchestration-cheatsheet.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
