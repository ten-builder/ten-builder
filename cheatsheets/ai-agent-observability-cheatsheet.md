# AI 에이전트 워크플로우 관찰 치트시트

> AI 코딩 에이전트 실행 중 내부 상태를 관찰하고 디버깅하는 도구와 패턴 — 한 페이지 요약

## 1. 왜 일반 로깅으로는 부족한가

| 전통적 모니터링 | AI 에이전트 관찰 |
|--------------|----------------|
| 단일 함수 호출 추적 | 멀티턴 실행 흐름 전체 추적 |
| 에러 발생 지점 확인 | 에이전트 의사결정 경로 파악 |
| 응답 시간 측정 | 토큰 소비량 + 비용 추적 |
| 로그 레벨 필터링 | 도구 호출 순서 및 결과 재현 |

AI 에이전트는 루프, 분기, 서브에이전트 위임이 섞여 있어 개별 호출만 봐서는 실패 원인을 찾기 어렵다. 세션 전체의 인과 관계(causal trace)가 필요하다.

## 2. 핵심 관찰 메트릭

| 메트릭 | 설명 | 도구 |
|--------|------|------|
| `tool_call_count` | 도구 호출 횟수/에이전트 루프당 | LangSmith, Braintrust |
| `token_input/output` | 입력/출력 토큰 수 | 모든 트레이싱 도구 |
| `latency_p50/p99` | 호출 지연 분포 | OpenTelemetry |
| `first_try_success` | 첫 시도 성공률 | 커스텀 메트릭 |
| `error_recovery_count` | 자동 복구 횟수 | 커스텀 로그 |
| `context_fill_ratio` | 컨텍스트 윈도우 사용률 | 모델 API 응답 |

## 3. 주요 관찰 도구

### 3-1. LangSmith (LangChain 생태계)

```python
from langsmith import traceable

@traceable(run_type="llm", name="코드_생성_에이전트")
def run_coding_agent(task: str) -> str:
    # 에이전트 실행 코드
    return result
```

- OpenTelemetry 호환 (OpenLLMetry 포맷 지원)
- 멀티턴 세션 타임라인 뷰 제공
- 프리 플랜: 5,000 traces/월

### 3-2. Braintrust (평가 중심)

```python
import braintrust

with braintrust.start_span(name="tool_call", span_type="tool") as span:
    result = call_tool(tool_name, args)
    span.log(output=result, metadata={"cost_usd": estimated_cost})
```

- 평가(eval) + 트레이싱 통합
- 자동화된 품질 점수 산출
- 프로덕션 피드백 루프 구성 가능

### 3-3. OpenTelemetry (벤더 중립)

```python
from opentelemetry import trace

tracer = trace.get_tracer("ai-coding-agent")

with tracer.start_as_current_span("agent_iteration") as span:
    span.set_attribute("agent.iteration", iteration_num)
    span.set_attribute("agent.decision", "tool_call")
    span.set_attribute("agent.tool.name", tool_name)
    span.set_attribute("agent.tool.args", str(args))
```

표준 속성 구조:

| 속성 | 타입 | 예시 |
|------|------|------|
| `agent.iteration` | int | 3 |
| `agent.decision` | string | `tool_call` \| `final_answer` |
| `agent.tool.name` | string | `bash`, `read_file` |
| `agent.tool.latency_ms` | int | 450 |
| `llm.token.input` | int | 8432 |
| `llm.token.output` | int | 1247 |

## 4. Claude Code 관찰 패턴

### 4-1. 도구 호출 로그 파싱

Claude Code 실행 시 `--output-format json` 옵션으로 구조화된 로그를 얻을 수 있다:

```bash
# JSON 형식으로 실행 및 로그 저장
claude code --print --output-format json \
  "파일 구조를 분석하고 개선점을 제안해줘" \
  > agent_run_$(date +%Y%m%d_%H%M%S).json
```

로그에서 도구 호출 순서 추출:

```bash
# 도구 호출 이름만 추출
cat agent_run.json | python3 -c "
import json, sys
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('type') == 'tool_use':
            print(f\"{d['name']} → {str(d.get('input',''))[:60]}\")
    except: pass
"
```

### 4-2. 토큰 사용량 추적

```bash
# 실행 후 토큰 요약 출력
claude code --print --output-format json "작업" | \
  python3 -c "
import json, sys
total_in = total_out = 0
for line in sys.stdin:
    try:
        d = json.loads(line)
        u = d.get('usage', {})
        total_in += u.get('input_tokens', 0)
        total_out += u.get('output_tokens', 0)
    except: pass
print(f'입력 토큰: {total_in:,}')
print(f'출력 토큰: {total_out:,}')
print(f'예상 비용: \${(total_in * 3 + total_out * 15) / 1_000_000:.4f}')
"
```

## 5. 디버깅 체크리스트

### 에이전트가 루프에 빠졌을 때

- [ ] 도구 호출 순서 로그 확인 → 같은 도구를 반복 호출하는지 체크
- [ ] 컨텍스트 윈도우 사용률 확인 → 80% 이상이면 요약 삽입 필요
- [ ] 마지막 5개 도구 결과 검토 → 예상과 다른 출력인지 확인
- [ ] 에이전트에게 명시적 중단 조건 추가

### 예상보다 비용이 클 때

- [ ] `token_input` vs `token_output` 비율 확인 (출력이 3배 이상이면 비정상)
- [ ] 불필요한 파일 전체 읽기 여부 확인
- [ ] 서브에이전트 병렬 실행 수 제한

### 도구 호출 실패 패턴

```python
# 실패한 도구 호출 감지
def detect_tool_failures(trace_log: list) -> dict:
    failures = {}
    for event in trace_log:
        if event.get("type") == "tool_result" and event.get("is_error"):
            tool = event.get("tool_name", "unknown")
            failures[tool] = failures.get(tool, 0) + 1
    return failures
```

## 6. 관찰 도구 선택 기준

| 상황 | 추천 도구 |
|------|-----------|
| LangChain 기반 에이전트 | LangSmith |
| 평가/벤치마킹 중심 | Braintrust |
| 자체 인프라(벤더 중립) | OpenTelemetry + Jaeger |
| 간단한 디버깅 | Claude Code JSON 로그 파싱 |
| 프로덕션 모니터링 | Arize Phoenix / Datadog LLM |

## 7. 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 개별 API 호출만 추적 | 세션 단위 full trace 수집 |
| 토큰 수만 보고 비용 무시 | 모델별 단가 적용한 비용 계산 |
| 에러 로그만 저장 | 성공 케이스도 샘플링하여 기준값 확보 |
| 트레이스 너무 세분화 | 에이전트 루프 단위로 묶어서 저장 |
| 프로덕션에서만 관찰 | 개발 단계부터 trace 습관화 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
