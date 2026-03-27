# 가이드 35: AI 코딩 에이전트 스캐폴딩 설계

> 같은 모델이라도 에이전트 프레임워크에 따라 결과가 17문제 차이가 난다. 모델이 아니라 스캐폴딩이 코드 품질을 결정하는 시대, 에이전트를 제대로 설계하는 방법을 알아본다.

## 왜 스캐폴딩인가

2026년 기준으로 신규 코드의 42%가 AI 도움을 받아 작성된다. 그런데 같은 Claude 3.5 Sonnet을 쓰더라도 Cursor에서 돌렸을 때와 Windsurf에서 돌렸을 때 벤치마크 점수가 크게 다르다. 모델 성능은 동일한데 결과가 달라지는 이유는 **스캐폴딩** — 프롬프트 구성, 컨텍스트 관리, 도구 호출 파이프라인, 에러 복구 루프 — 이 다르기 때문이다.

| 요소 | 영향도 | 예시 |
|------|--------|------|
| 컨텍스트 윈도우 활용 | 높음 | 관련 파일만 선별 vs 전체 프로젝트 덤프 |
| 도구 호출 전략 | 높음 | 순차 실행 vs 병렬 에이전트 팀 |
| 에러 복구 루프 | 중간 | 자동 재시도 vs 사용자에게 던지기 |
| 프롬프트 체이닝 | 중간 | 단일 메가 프롬프트 vs 단계별 분할 |
| 메모리 관리 | 낮음~중간 | 세션 간 컨텍스트 유지 여부 |

## 핵심 구성 요소 5가지

### 1. 컨텍스트 라우팅

에이전트가 코드베이스에서 어떤 파일을 읽을지 결정하는 로직이다. 잘 설계된 스캐폴딩은 파일 트리 전체를 넣지 않고, 태스크와 관련된 파일만 선별해서 컨텍스트 윈도우에 넣는다.

```yaml
# .claude/context-routing.yaml 예시
routes:
  - pattern: "*.test.ts"
    trigger: ["테스트", "test", "spec"]
    priority: high
  - pattern: "src/api/**"
    trigger: ["API", "엔드포인트", "라우트"]
    priority: high
  - pattern: "*.config.*"
    trigger: ["설정", "config", "환경"]
    priority: medium
```

**팁:** CLAUDE.md나 .cursorrules에 `@파일그룹` 태그를 정의해두면 에이전트가 태스크 유형에 따라 자동으로 관련 파일 그룹을 참조한다.

### 2. 도구 체인 설계

에이전트가 쓸 수 있는 도구(터미널, 파일 편집, 검색, 테스트 실행 등)를 어떻게 묶느냐가 결과를 좌우한다.

```bash
# 효과적인 도구 체인: 읽기 → 수정 → 검증 루프
read_file → edit_file → run_tests → (실패 시) read_error → edit_file → run_tests
```

| 패턴 | 장점 | 단점 |
|------|------|------|
| 순차 체인 | 예측 가능, 디버깅 쉬움 | 느림 |
| 병렬 서브에이전트 | 빠름, 대규모 리팩터링에 적합 | 충돌 위험, 머지 필요 |
| 하이브리드 | 균형 잡힌 성능 | 설계 복잡도 증가 |

### 3. 프롬프트 분할 전략

하나의 거대한 프롬프트보다 단계별로 나눠서 주는 것이 정확도를 높인다.

```
Step 1: "이 코드베이스의 아키텍처를 분석해줘" → 구조 파악
Step 2: "이 함수의 버그를 찾아줘" → 특정 태스크
Step 3: "수정하고 테스트를 실행해줘" → 실행 + 검증
```

단일 프롬프트로 "버그 찾아서 고쳐줘"라고 하면 컨텍스트가 희석되어 엉뚱한 파일을 건드리는 경우가 많다. 단계를 나누면 각 단계에서 에이전트가 집중해야 할 범위가 명확해진다.

### 4. 에러 복구 루프

에이전트가 실패했을 때 어떻게 복구하느냐가 실질적인 성공률을 결정한다.

```python
# 에러 복구 루프 의사코드
MAX_RETRIES = 3

for attempt in range(MAX_RETRIES):
    result = agent.execute(task)
    if result.success:
        break
    
    # 에러 유형별 분기
    if result.error_type == "syntax":
        agent.context.add(result.error_message)
        agent.execute("문법 에러를 수정해줘")
    elif result.error_type == "test_failure":
        agent.context.add(result.test_output)
        agent.execute("실패한 테스트를 기반으로 코드를 수정해줘")
    elif result.error_type == "type_error":
        agent.context.add(result.type_info)
        agent.execute("타입 에러를 해결해줘")
```

### 5. 장기 실행 에이전트 관리

2026년의 큰 변화 중 하나는 **장기 실행(long-running) 에이전트**의 등장이다. 단일 프롬프트에 응답하는 게 아니라, 몇 시간에 걸쳐 자율적으로 작업을 수행한다.

| 관리 항목 | 방법 |
|-----------|------|
| 체크포인트 | 주요 단계마다 상태 저장 (git commit) |
| 감독 루프 | N분마다 진행 상황 보고 |
| 비용 제한 | 토큰 버짓 설정, 초과 시 중단 |
| 롤백 | git 기반 자동 롤백 포인트 |

## 실전 체크리스트

프로젝트에 AI 에이전트를 도입할 때 확인할 사항:

- [ ] CLAUDE.md 또는 .cursorrules 파일이 프로젝트 루트에 있는가
- [ ] 컨텍스트 라우팅 규칙이 정의되어 있는가
- [ ] 에이전트가 쓸 수 있는 도구 목록이 명시되어 있는가
- [ ] 테스트 실행 명령어가 에이전트에게 알려져 있는가
- [ ] 에러 발생 시 복구 전략이 있는가
- [ ] 토큰 사용량 모니터링이 설정되어 있는가
- [ ] 에이전트 출력 검증 프로세스가 있는가

## 도구별 스캐폴딩 비교

| 기능 | Claude Code | Cursor | Windsurf |
|------|------------|--------|----------|
| 컨텍스트 관리 | CLAUDE.md + 서브에이전트 | .cursorrules + 인덱싱 | Cascade 자동 탐색 |
| 병렬 실행 | 서브에이전트 8개 | Background agents 8개 | 단일 Cascade |
| MCP 지원 | 네이티브 | 플러그인 | 제한적 |
| 장기 실행 | Headless 모드 | Background 탭 | 미지원 |
| 비용 최적화 | 프롬프트 캐싱 | 모델 라우팅 | 자동 선택 |

## 다음 단계

→ [가이드 31: 컨텍스트 엔지니어링](./31-context-engineering.md) — 컨텍스트 윈도우를 효과적으로 관리하는 기법
→ [가이드 33: AI 위임 패턴](./33-ai-delegation-patterns.md) — 서브에이전트에게 작업을 분배하는 전략
→ [플레이북 24: 프롬프트 체이닝](../claude-code/playbooks/24-prompt-chaining.md) — 단계별 프롬프트 실행

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder)
