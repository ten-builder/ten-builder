# 가이드 105: Code with Claude 2026 신기능 정리 — 관리형 에이전트, 드리밍, 프로액티브 워크플로우

> 2026년 5월 6일 Anthropic이 샌프란시스코에서 개최한 Code with Claude 행사에서 발표된 4가지 핵심 신기능을 개발자 관점에서 정리합니다.

## 소요 시간

이 가이드 읽기: 15분

## 이번 행사에서 달라진 것

Code with Claude 2026은 단순한 기능 업데이트를 넘어 에이전트 개발 패러다임의 방향을 제시한 자리였습니다. 핵심 메시지는 하나입니다 — 에이전트가 이제 며칠씩 지속 실행되는 시대로 넘어가고 있다는 것입니다.

---

## 1. 관리형 에이전트(Managed Agents) 베타

### 개념

Claude API에 에이전트 상태, 세션, 도구 호출을 통합 관리하는 레이어가 추가됐습니다. 기존에는 개발자가 직접 메모리 저장, 세션 이어가기, 도구 결과 파싱을 구현해야 했지만, Managed Agents는 이를 인프라 수준에서 처리합니다.

### 활성화 방법

현재 베타 단계로, API 호출 시 헤더를 추가해야 합니다.

```python
import anthropic

client = anthropic.Anthropic()

# Managed Agents 베타 헤더
response = client.beta.messages.create(
    model="claude-opus-4-5",
    max_tokens=4096,
    betas=["managed-agents-2026-04-01"],
    messages=[{"role": "user", "content": "프로젝트 코드베이스를 분석하고 개선점을 찾아줘"}],
    tools=[...],
)
```

### 주요 특징

| 항목 | 기존 방식 | Managed Agents |
|------|-----------|----------------|
| 세션 관리 | 개발자가 직접 구현 | API가 자동 처리 |
| 도구 결과 | 수동 파싱 필요 | 구조화된 응답 반환 |
| 메모리 저장 | 외부 DB 직접 연결 | Memory Store API 제공 |
| 에러 복구 | 수동 재시도 로직 | 내장 재시도 메커니즘 |

---

## 2. 드리밍(Dreaming) — 에이전트 자기 개선

### 문제를 먼저 이해하기

에이전트가 여러 세션에 걸쳐 실행되면 메모리 저장소에 문제가 쌓입니다. 중복 항목, 서로 모순된 정보, 더 이상 유효하지 않은 오래된 데이터가 누적됩니다.

드리밍은 이 문제를 해결합니다. 에이전트가 유휴 시간에 기존 메모리 저장소와 지난 세션 기록을 검토하여, 깔끔하게 정리된 새 메모리 저장소를 생성합니다.

### 드리밍이 하는 것

- 중복 항목 병합
- 모순되거나 오래된 항목 교체
- 패턴 추출 — 반복되는 실수나 자주 쓰는 전략을 명시적 규칙으로 정리

### 사용 예시

```python
# 에이전트 세션 종료 후 드리밍 실행
dream_response = client.beta.managed_agents.dreams.create(
    agent_id="my-coding-agent",
    memory_store_id="project-memory",
    betas=["managed-agents-2026-04-01"],
)

print(f"드리밍 완료: {dream_response.memories_consolidated}개 항목 정리")
print(f"새로운 패턴: {dream_response.patterns_discovered}개 발견")
```

### 언제 드리밍을 실행할까

드리밍은 연산 비용이 있으므로 모든 세션 후마다 실행할 필요는 없습니다.

| 상황 | 권장 여부 |
|------|-----------|
| 7일 이상 누적 세션 후 | ✅ 권장 |
| 에이전트가 같은 실수를 반복할 때 | ✅ 즉시 실행 |
| 프로젝트 마일스톤 완료 후 | ✅ 권장 |
| 매 세션 종료 후 | ❌ 불필요 |

---

## 3. 프로액티브 워크플로우(Proactive Workflows)

### 개념

기존 에이전트는 요청이 들어올 때만 동작했습니다. 프로액티브 워크플로우는 에이전트가 스케줄이나 이벤트 트리거에 따라 스스로 작업을 시작할 수 있게 합니다.

### 설정 예시

```python
# 매일 오전 9시 코드 품질 체크 자동 실행
workflow = client.beta.managed_agents.workflows.create(
    agent_id="code-quality-agent",
    trigger={
        "type": "schedule",
        "cron": "0 9 * * 1-5",  # 평일 오전 9시
        "timezone": "Asia/Seoul"
    },
    task="저장소의 새 커밋을 분석하고 코드 품질 리포트를 생성해줘",
    betas=["managed-agents-2026-04-01"],
)
```

### 실용 시나리오

1. **일일 코드 리뷰**: 매일 아침 전날 머지된 PR 요약
2. **의존성 감시**: 주요 패키지 보안 취약점 자동 감지
3. **문서 동기화**: 코드 변경 시 자동으로 README 업데이트 제안

---

## 4. 멀티 에이전트 오케스트레이션

### 구조

리드 에이전트가 작업을 분해하고 각 서브 에이전트에게 위임합니다. 서브 에이전트는 공유 파일시스템 위에서 병렬로 작동하며, 결과를 다시 리드 에이전트로 피드백합니다.

```python
# 리드 에이전트 설정
lead_agent = client.beta.managed_agents.create(
    name="lead-architect",
    model="claude-opus-4-5",
    sub_agents=[
        {"name": "backend-specialist", "model": "claude-sonnet-4-5"},
        {"name": "frontend-specialist", "model": "claude-sonnet-4-5"},
        {"name": "test-writer", "model": "claude-haiku-4-5"},
    ],
    betas=["managed-agents-2026-04-01"],
)

# 복합 작업 위임
result = lead_agent.run(
    "새 결제 API를 설계하고, 백엔드 구현, 프론트엔드 연동, 테스트 코드를 각각 작성해줘"
)
```

### 모델 선택 전략

비용 효율을 위해 역할별로 모델을 나눠 쓰는 것이 실용적입니다.

| 역할 | 추천 모델 | 이유 |
|------|-----------|------|
| 설계/의사결정 (리드) | claude-opus-4-5 | 복잡한 판단 필요 |
| 구현 (서브) | claude-sonnet-4-5 | 균형 잡힌 성능/비용 |
| 반복 작업 (테스트 생성 등) | claude-haiku-4-5 | 속도와 비용 우선 |

---

## 시작하기 전 체크리스트

- [ ] Anthropic API 키 보유 확인
- [ ] Python SDK 최신 버전 업데이트: `pip install anthropic --upgrade`
- [ ] Managed Agents 베타 접근 권한 신청 (platform.claude.com)
- [ ] 기존 에이전트 코드에 베타 헤더 추가 (`managed-agents-2026-04-01`)
- [ ] 드리밍 실행 주기 계획 수립

---

## 다음 단계

- 프로액티브 워크플로우 심화: [workflows/ai-agent-production-workflow-patterns.md](../workflows/ai-agent-production-workflow-patterns.md)
- 멀티 에이전트 역할 설계: [claude-code/playbooks/52-specialist-agent-roles.md](../claude-code/playbooks/52-specialist-agent-roles.md)
- 에이전트 상태 관리: [claude-code/playbooks/63-ai-agent-state-persistence-playbook.md](../claude-code/playbooks/63-ai-agent-state-persistence-playbook.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
