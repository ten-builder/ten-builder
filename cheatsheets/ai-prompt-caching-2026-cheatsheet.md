# AI 에이전트 프롬프트 캐싱 전략 치트시트 2026

> 캐시 히트율을 높이고 API 비용을 60~90% 줄이는 실전 참조 카드 — Claude, Gemini, GPT 플랫폼별 캐싱 정책 비교

## 핵심 개념

| 개념 | 설명 |
|------|------|
| **캐시 히트** | 동일한 prefix가 감지돼 저장된 토큰을 재사용 |
| **캐시 미스** | 처음 보는 prefix → 전체 prefill 비용 발생 |
| **최소 토큰** | Claude: 1,024토큰 이상일 때 캐싱 활성화 |
| **캐시 유효 시간(TTL)** | Claude: 5분 (2026년 3월 이후), Gemini: 1시간+, GPT: 자동 관리 |
| **캐시 분담** | 사용자 간 캐시는 공유되지 않음 — 계정/세션 단위로 격리 |

## 플랫폼별 캐싱 정책 비교

| 항목 | Claude (Anthropic) | Gemini (Google) | GPT (OpenAI) |
|------|-------------------|-----------------|--------------|
| **캐싱 방식** | 명시적 `cache_control` 마커 | `cachedContent` API | 자동 prefix 매칭 |
| **최소 토큰** | 1,024 (Claude 3+) | 32,768 | ~1,024 (자동) |
| **TTL** | 5분 (기본), 최대 1시간 | 1시간 (설정 가능) | 5~10분 (자동) |
| **캐시 비용** | 히트 시 입력 비용 90% 절감 | 히트 시 입력 비용 75% 절감 | 히트 시 입력 비용 50% 절감 |
| **저장소 비용** | 캐시 쓰기 토큰 × 1.25 | 별도 저장 요금 | 없음 |
| **최대 중단점** | 4개 | 1개 | 자동 |

## Claude 프롬프트 캐싱 설정

### 기본 구조 (Python SDK)

```python
import anthropic

client = anthropic.Anthropic()

response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": "당신은 시니어 백엔드 개발자입니다. 항상 한국어로 답하세요.",
            "cache_control": {"type": "ephemeral"}  # 캐시 마커
        }
    ],
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": long_document,  # 긴 문서
                    "cache_control": {"type": "ephemeral"}
                },
                {
                    "type": "text",
                    "text": "위 코드에서 버그를 찾아주세요."
                }
            ]
        }
    ]
)

# 캐시 사용 확인
usage = response.usage
print(f"캐시 히트: {usage.cache_read_input_tokens}")
print(f"캐시 저장: {usage.cache_creation_input_tokens}")
```

### 멀티 중단점 패턴 (4개 최대)

```python
messages = [
    # 중단점 1: 시스템 프롬프트 (가장 안정적인 prefix)
    {"role": "system", "cache_control": {"type": "ephemeral"}},
    
    # 중단점 2: 공유 컨텍스트 문서
    {"role": "user", "type": "document", "cache_control": {"type": "ephemeral"}},
    
    # 중단점 3: 대화 히스토리
    {"role": "assistant", "cache_control": {"type": "ephemeral"}},
    
    # 중단점 4: 현재 질문 (캐시 안 함 — 매번 바뀜)
    {"role": "user", "content": current_question}
]
```

## 캐시 히트율 높이는 실전 패턴

### 패턴 1: 안정적인 prefix 앞에 배치

```
❌ 나쁜 구조 (타임스탬프가 앞에 있어 캐시 무효화)
[현재 시각: 2026-05-01 06:00] + [시스템 프롬프트] + [문서] + [질문]

✅ 좋은 구조 (변하지 않는 내용이 앞에)
[시스템 프롬프트] + [문서] + [대화 히스토리] + [현재 시각: ...] + [질문]
```

### 패턴 2: 시스템 프롬프트 분리 관리

```python
# 불변 부분 (캐싱)
BASE_SYSTEM = """
당신은 AI 코딩 어시스턴트입니다.
{여기에 긴 컨텍스트, 스타일 가이드, 규칙 등}
"""

# 가변 부분 (캐싱 안 함)
dynamic_context = f"현재 브랜치: {branch}, 작업: {task}"

messages = [
    {"type": "text", "text": BASE_SYSTEM, "cache_control": {"type": "ephemeral"}},
    {"type": "text", "text": dynamic_context}  # 마커 없음
]
```

### 패턴 3: 문서 분석 세션

```python
# 큰 코드베이스를 한 번 캐싱하고 여러 질문에 재사용
codebase_content = load_codebase()  # 수천 줄

for question in questions:
    response = client.messages.create(
        messages=[
            {"type": "text", "text": codebase_content, "cache_control": {"type": "ephemeral"}},
            {"type": "text", "text": question}
        ]
    )
    # 첫 번째 호출: 캐시 저장 비용 발생
    # 이후 호출: 90% 비용 절감
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 동적 값(시각, UUID)을 prefix에 삽입 | 고정 내용이 먼저, 동적 내용은 끝에 |
| 5분 TTL 이후 재요청 → 캐시 미스 | 주기적 warmup 요청 또는 세션 내 재사용 |
| 1,024토큰 미만 캐싱 시도 | 시스템 프롬프트 + 문서를 합쳐 기준 충족 |
| 캐시 히트 확인 안 함 | `usage.cache_read_input_tokens` 로깅 필수 |
| 모든 블록에 `cache_control` 추가 | 마커는 4개까지만 — 가장 큰 안정적 블록에만 |

## 비용 계산 예시

```
시나리오: 5,000토큰 시스템 프롬프트, 하루 1,000회 호출
Claude Opus 4.7 기준 (입력: $15/M 토큰)

캐싱 없이:
  5,000 × 1,000 = 5,000,000 토큰 = $75/일

캐싱 적용 후 (90% 히트율 가정):
  저장 비용: 5,000 × 1.25 × $15 = $0.09 (초기 1회)
  히트 비용: 5,000 × 900 × $1.5 = $6.75/일 (90% 할인)
  미스 비용: 5,000 × 100 × $15 = $7.50/일
  합계: ~$14.34/일 → 80% 이상 절감
```

## Claude Code에서 캐싱 동작 확인

```bash
# Claude Code 세션에서 캐시 상태 모니터링
# ~/.claude/logs/ 에서 usage 필드 확인
cat ~/.claude/logs/*.jsonl | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
        if 'cache_read_input_tokens' in str(d):
            usage = d.get('usage', {})
            hit = usage.get('cache_read_input_tokens', 0)
            create = usage.get('cache_creation_input_tokens', 0)
            if hit or create:
                print(f'히트: {hit}, 저장: {create}')
    except: pass
"
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
