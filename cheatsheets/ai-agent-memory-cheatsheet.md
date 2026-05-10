# AI 에이전트 메모리 관리 치트시트

> 세션을 넘어 기억하는 AI 에이전트 — 메모리 계층, 프레임워크 선택, 실전 패턴 한 페이지 요약

---

## 메모리 4계층

| 계층 | 저장소 | 유효 시간 | 용도 |
|------|--------|-----------|------|
| **단기 (Working)** | Redis, 인메모리 | 15분 ~ 수 시간 | 현재 대화 컨텍스트, 진행 중인 태스크, 최근 툴 출력 |
| **세션 (Session)** | 벡터 DB | 1세션 ~ 며칠 | 사용자 의도, 중간 결정, 작업 체크포인트 |
| **장기 (Long-term)** | 벡터 DB + 그래프 DB | 무제한 | 사용자 선호도, 도메인 지식, 과거 패턴 |
| **영구 기록 (Audit)** | SQL / 오브젝트 스토리지 | 무제한 | 감사 로그, 전체 이력, 컴플라이언스 |

---

## 프레임워크 빠른 비교 (2026 기준)

| 프레임워크 | 강점 | 적합한 케이스 | 비용 |
|-----------|------|--------------|------|
| **Mem0** | 개인화, 넓은 생태계(21개 통합), AWS 공식 파트너 | 사용자별 선호도 기억, 다중 에이전트 | Free 티어 있음, Pro $249/월 |
| **Zep / Graphiti** | 시간 기반 지식 그래프, 관계 추론 | 감사 추적, 엔티티 관계 변화 추적 | Free 티어, Flex $25/월 |
| **LangMem** | LangGraph 네이티브 통합, 무료 오픈소스 | 이미 LangGraph 쓰는 팀 | 오픈소스 |
| **Hindsight** | BEAM 벤치마크 1위, 4-네트워크 아키텍처 | 정확도가 최우선인 케이스 | 오픈소스 |

### 성능 벤치마크 (LOCOMO 기준)

| 방식 | 정확도 | 응답 시간 | 토큰 소비 |
|------|--------|-----------|-----------|
| Full-context | 72.9% | 9.87초 | ~26,000 / 대화 |
| Mem0g (그래프 포함) | 68.4% | 1.09초 | ~1,800 / 대화 |
| **Mem0** | **66.9%** | **0.71초** | **~1,800 / 대화** |
| RAG | 61.0% | 0.70초 | — |

> Full-context 대비 Mem0: 토큰 14배 절감, 응답 14배 빠름, 정확도 6% 차이

---

## Mem0 4범위 메모리 모델

모든 메모리 쓰기는 4개 범위 중 하나 이상에 연결:

```python
from mem0 import Memory

m = Memory()

# user_id: 사용자별 개인화
m.add("사용자는 Python보다 TypeScript를 선호함", user_id="user_123")

# agent_id: 에이전트별 도메인 지식
m.add("이 에이전트는 금융 분석 전문", agent_id="finance-agent")

# run_id: 세션별 상태
m.add("현재 작업: Q3 리포트 분석 중", run_id="session_456")

# app_id: 앱 전체 공유 메모리
m.add("회사 API 기본 URL: api.example.com", app_id="our-saas")

# 검색 — 자동으로 범위 내 유사도 검색
results = m.search("사용자 언어 선호도", user_id="user_123")
```

---

## 실전 패턴 모음

### 패턴 1: 세션 시작 시 컨텍스트 주입

```python
def build_system_prompt(user_id: str, task: str) -> str:
    memories = memory_client.search(task, user_id=user_id, limit=5)
    
    if not memories:
        return BASE_SYSTEM_PROMPT
    
    memory_context = "\n".join([f"- {m['memory']}" for m in memories])
    return f"""{BASE_SYSTEM_PROMPT}

## 이 사용자에 대해 알고 있는 것
{memory_context}
"""
```

### 패턴 2: 세션 종료 시 메모리 추출

```python
def save_session_memories(messages: list, user_id: str):
    # 대화에서 중요 정보 자동 추출 + 저장
    memory_client.add(messages, user_id=user_id)
    # Mem0가 자동으로 중요 정보만 추출하여 벡터 저장
```

### 패턴 3: 메모리 통합 (메모리 압축)

```python
# 오래된 메모리가 쌓이면 주기적으로 통합
def consolidate_memories(user_id: str):
    old_memories = memory_client.get_all(user_id=user_id)
    # 비슷한 항목 합치기, 오래된 항목 삭제
    memory_client.update(memory_id, data={"memory": consolidated})
```

### 패턴 4: CLAUDE.md로 파일 기반 메모리 (코딩 에이전트용)

```markdown
# CLAUDE.md 메모리 섹션 예시
## 내가 기억해야 할 것들
- 이 프로젝트는 PostgreSQL 16을 사용 (MySQL 아님)
- 테스트는 반드시 vitest로 작성
- 배포는 main 브랜치 push 시 자동 실행
- API 키는 .env 파일이 아닌 Vault에서 관리
```

---

## 프레임워크 선택 기준

```
사용자별 개인화가 핵심?
  └─ YES → Mem0 (가장 넓은 통합, 빠른 검색)
  
시간 흐름에 따른 관계 변화 추적 필요?
  └─ YES → Zep / Graphiti (지식 그래프, 감사 추적)
  
이미 LangGraph 쓰는 팀?
  └─ YES → LangMem (가장 낮은 마찰)
  
정확도가 최우선, 새 기술 도입 가능?
  └─ YES → Hindsight (BEAM 벤치마크 최고 성능)
  
단순 코딩 에이전트?
  └─ YES → CLAUDE.md / AGENTS.md 파일 기반으로 충분
```

---

## 흔한 실수

| 실수 | 해결 |
|------|------|
| 모든 대화 원문을 그대로 저장 | 메모리 통합 파이프라인 설정, 요약 저장 |
| 메모리 범위 없이 저장 (`user_id` 누락) | 반드시 `user_id` 또는 `agent_id` 지정 |
| 검색 임계값 없이 모든 결과 주입 | `limit=5`, 신뢰도 점수 필터 적용 |
| 단기 캐시와 장기 메모리 혼용 | Redis(단기) + 벡터 DB(장기) 역할 분리 |
| 메모리 시스템 없이 full-context 사용 | 토큰 14배 낭비, 응답 14배 느림 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
