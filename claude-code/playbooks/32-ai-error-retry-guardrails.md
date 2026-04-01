# 플레이북 32: AI 에이전트 에러 핸들링과 가드레일

> AI 코딩 에이전트가 실패할 때 자동으로 재시도하고, 안전하게 멈추고, 대안을 찾는 6단계 방어 체계

## 언제 쓰나요?

- AI 에이전트가 같은 실수를 반복하면서 토큰만 소모할 때
- 자동화된 코딩 파이프라인에서 실패 시 수동 개입이 필요할 때
- 에이전트에게 자율성을 주되 안전 범위를 정하고 싶을 때
- 프로덕션 환경에서 AI 에이전트를 신뢰성 있게 운영하고 싶을 때

## 소요 시간

30-45분

## 사전 준비

- Claude Code 또는 AI 코딩 에이전트 설치
- 프로젝트 CLAUDE.md에 에러 처리 관련 컨텍스트 포함
- 테스트 환경 (에러 시나리오 재현 가능)
- 모니터링 도구 (선택: 에러율 추적용)

## 왜 에러 핸들링 가드레일이 필요한가

AI 코딩 에이전트는 강력하지만, 실패 모드를 이해하지 못하면 오히려 문제를 키워요. 흔한 실패 패턴을 먼저 살펴보죠:

| 실패 패턴 | 증상 | 결과 |
|-----------|------|------|
| 무한 수정 루프 | 같은 파일을 반복 편집 | 토큰 소진, 코드 품질 저하 |
| 컨텍스트 오버플로우 | 대화가 길어져 핵심을 잊음 | 이전 지시 무시, 회귀 버그 |
| 환각 코드 | 존재하지 않는 API 호출 | 런타임 에러, 디버깅 시간 낭비 |
| 범위 이탈 | 요청하지 않은 파일까지 수정 | 의도치 않은 사이드 이펙트 |
| 테스트 무시 | 테스트 없이 구현만 완료 | 숨은 버그, 리그레션 위험 |

가드레일 없이 운영하면 에이전트가 "열심히 일하지만 쓸모없는" 상태에 빠지기 쉬워요.

## Step 1: 재시도 정책 설계

에이전트가 실패했을 때 어떻게 재시도할지 정책을 먼저 세워요.

### 단순 재시도 vs 지능형 재시도

```yaml
# .ai-guardrails.yaml — 프로젝트 루트에 두는 설정 예시
retry:
  max_attempts: 3
  strategy: "exponential_backoff"
  base_delay_seconds: 5
  max_delay_seconds: 60
  
  # 재시도할 에러 유형
  retryable_errors:
    - "rate_limit"          # API 속도 제한
    - "timeout"             # 응답 시간 초과
    - "context_overflow"    # 컨텍스트 윈도우 초과
    
  # 재시도하면 안 되는 에러
  non_retryable_errors:
    - "auth_failure"        # 인증 실패
    - "permission_denied"   # 권한 부족
    - "invalid_model"       # 잘못된 모델 지정
```

### 지능형 재시도 스크립트

```bash
#!/bin/bash
# ai-retry.sh — 에이전트 명령을 재시도하는 래퍼

MAX_RETRIES=3
RETRY_COUNT=0
BACKOFF=5

run_agent() {
  local prompt="$1"
  claude -p "$prompt" --output-format json 2>&1
}

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  RESULT=$(run_agent "$PROMPT")
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 0 ]; then
    echo "$RESULT"
    exit 0
  fi
  
  # 재시도 불가능한 에러 체크
  if echo "$RESULT" | grep -q "auth_failure\|permission_denied"; then
    echo "재시도 불가능한 에러: $RESULT" >&2
    exit 1
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  SLEEP_TIME=$((BACKOFF * (2 ** (RETRY_COUNT - 1))))
  echo "재시도 ${RETRY_COUNT}/${MAX_RETRIES} — ${SLEEP_TIME}초 대기..." >&2
  sleep $SLEEP_TIME
done

echo "최대 재시도 횟수 초과" >&2
exit 1
```

**핵심 포인트:**
- 같은 방식으로 재시도하면 같은 결과가 나와요
- 재시도 시 프롬프트를 조금씩 바꾸는 게 더 효과적이에요 (온도 조절, 예시 추가 등)

## Step 2: 서킷 브레이커 구현

연속 실패가 쌓이면 에이전트를 자동으로 멈춰야 해요. 서킷 브레이커 패턴을 적용합니다.

### 3가지 상태

```
[CLOSED] → 정상 동작, 에러 카운트 추적
    ↓ (연속 N회 실패)
[OPEN] → 에이전트 호출 차단, 폴백 실행
    ↓ (쿨다운 시간 경과)
[HALF-OPEN] → 1회 시험 호출
    ↓ (성공하면 CLOSED, 실패하면 OPEN)
```

### 구현 예시

```python
import time
import json
from pathlib import Path

class AgentCircuitBreaker:
    """AI 에이전트용 서킷 브레이커"""
    
    STATE_FILE = ".ai-circuit-state.json"
    
    def __init__(self, failure_threshold=3, recovery_timeout=300):
        self.failure_threshold = failure_threshold  # 연속 실패 한계
        self.recovery_timeout = recovery_timeout    # 쿨다운 (초)
        self.state = self._load_state()
    
    def _load_state(self):
        path = Path(self.STATE_FILE)
        if path.exists():
            return json.loads(path.read_text())
        return {"status": "closed", "failures": 0, "last_failure": 0}
    
    def _save_state(self):
        Path(self.STATE_FILE).write_text(json.dumps(self.state))
    
    def can_execute(self) -> bool:
        if self.state["status"] == "closed":
            return True
        if self.state["status"] == "open":
            elapsed = time.time() - self.state["last_failure"]
            if elapsed > self.recovery_timeout:
                self.state["status"] = "half-open"
                self._save_state()
                return True  # 시험 호출 허용
            return False
        return True  # half-open
    
    def record_success(self):
        self.state = {"status": "closed", "failures": 0, "last_failure": 0}
        self._save_state()
    
    def record_failure(self):
        self.state["failures"] += 1
        self.state["last_failure"] = time.time()
        if self.state["failures"] >= self.failure_threshold:
            self.state["status"] = "open"
        self._save_state()
```

| 파라미터 | 권장 값 | 설명 |
|----------|---------|------|
| `failure_threshold` | 3 | 3번 연속 실패하면 차단 |
| `recovery_timeout` | 300초 | 5분 후 시험 재개 |
| `half_open_max` | 1 | 시험 호출은 1회만 |

## Step 3: 폴백 전략 수립

에이전트가 실패했을 때 대안을 준비해두면 전체 워크플로우가 멈추지 않아요.

### 폴백 체인

```yaml
# 폴백 우선순위 (위에서 아래로 시도)
fallback_chain:
  - name: "모델 다운그레이드"
    description: "Opus가 실패하면 Sonnet으로 전환"
    trigger: "context_overflow OR timeout"
    action:
      model: "claude-sonnet-4-20250514"
      max_tokens: 4096
      
  - name: "프롬프트 축소"
    description: "컨텍스트를 줄여서 재시도"
    trigger: "context_overflow"
    action:
      strategy: "truncate_history"
      keep_last_n: 5
      
  - name: "태스크 분할"
    description: "큰 작업을 작은 단위로 나눠 재시도"
    trigger: "incomplete_output OR quality_check_fail"
    action:
      strategy: "decompose"
      max_subtasks: 3
      
  - name: "수동 전환"
    description: "사람에게 알림 전송"
    trigger: "all_retries_exhausted"
    action:
      notify: true
      channel: "slack"
```

### 모델 폴백 스크립트

```bash
#!/bin/bash
# model-fallback.sh — 모델 자동 다운그레이드

MODELS=("claude-opus-4-20250918" "claude-sonnet-4-20250514" "claude-haiku-3-5-20241022")

for MODEL in "${MODELS[@]}"; do
  echo "시도 중: $MODEL" >&2
  RESULT=$(claude -p "$PROMPT" --model "$MODEL" 2>&1)
  
  if [ $? -eq 0 ]; then
    echo "$RESULT"
    echo "성공 모델: $MODEL" >&2
    exit 0
  fi
  
  echo "$MODEL 실패, 다음 모델로 전환..." >&2
done

echo "모든 모델 실패" >&2
exit 1
```

## Step 4: 범위 제한 가드레일

에이전트가 요청 범위를 벗어나지 않도록 제한을 거는 게 중요해요.

### 파일 수정 범위 제한

```yaml
# CLAUDE.md에 추가할 가드레일 섹션
## Guardrails

### 수정 가능 파일
- src/ 디렉토리 내 파일만 수정 가능
- 테스트 파일은 tests/ 디렉토리에만 생성
- 설정 파일(*.config.*, *.json) 수정 시 반드시 diff 표시 후 확인 요청

### 수정 금지 파일
- .env, .env.* — 환경 변수 절대 수정 금지
- package-lock.json — 직접 수정 금지 (npm install로만 변경)
- migrations/ — 마이그레이션 파일 직접 수정 금지

### 작업 범위 제한
- 한 번에 최대 5개 파일까지만 수정
- 단일 파일 변경이 200줄을 넘으면 작업 분할 필요
- 새 의존성 추가 시 반드시 사유 설명
```

### Pre-commit 검증 훅

```bash
#!/bin/bash
# .git/hooks/pre-commit — AI 에이전트 변경사항 검증

CHANGED_FILES=$(git diff --cached --name-only)
CHANGED_COUNT=$(echo "$CHANGED_FILES" | wc -l)
MAX_FILES=10

# 파일 수 제한
if [ "$CHANGED_COUNT" -gt "$MAX_FILES" ]; then
  echo "가드레일 위반: ${CHANGED_COUNT}개 파일 변경 (최대 ${MAX_FILES}개)"
  echo "작업을 분할해서 커밋하세요."
  exit 1
fi

# 금지 파일 체크
BLOCKED_PATTERNS=".env|package-lock.json|migrations/"
BLOCKED=$(echo "$CHANGED_FILES" | grep -E "$BLOCKED_PATTERNS")
if [ -n "$BLOCKED" ]; then
  echo "가드레일 위반: 수정 금지 파일이 포함되어 있어요"
  echo "$BLOCKED"
  exit 1
fi

# 단일 파일 변경량 체크
for FILE in $CHANGED_FILES; do
  LINES=$(git diff --cached "$FILE" | grep '^[+-]' | grep -v '^[+-][+-][+-]' | wc -l)
  if [ "$LINES" -gt 200 ]; then
    echo "가드레일 위반: $FILE — ${LINES}줄 변경 (최대 200줄)"
    exit 1
  fi
done

echo "가드레일 체크 통과"
```

## Step 5: 품질 게이트 자동화

에이전트가 생성한 코드가 최소 품질 기준을 통과하는지 자동으로 확인해요.

### 품질 게이트 체크리스트

```python
import subprocess
import sys

class QualityGate:
    """AI 생성 코드 품질 자동 검증"""
    
    def __init__(self):
        self.checks = []
        self.results = []
    
    def check_lint(self) -> bool:
        """린트 통과 여부"""
        result = subprocess.run(
            ["npx", "eslint", "src/", "--quiet"],
            capture_output=True
        )
        return result.returncode == 0
    
    def check_types(self) -> bool:
        """타입 체크 통과 여부"""
        result = subprocess.run(
            ["npx", "tsc", "--noEmit"],
            capture_output=True
        )
        return result.returncode == 0
    
    def check_tests(self) -> bool:
        """테스트 통과 여부"""
        result = subprocess.run(
            ["npm", "test", "--", "--passWithNoTests"],
            capture_output=True
        )
        return result.returncode == 0
    
    def check_diff_size(self, max_lines=500) -> bool:
        """변경량 제한 체크"""
        result = subprocess.run(
            ["git", "diff", "--stat", "--cached"],
            capture_output=True, text=True
        )
        # 마지막 줄에서 총 변경량 파싱
        lines = result.stdout.strip().split('\n')
        if not lines:
            return True
        total = lines[-1]
        # "N insertions, M deletions" 파싱
        import re
        nums = re.findall(r'(\d+)', total)
        total_changes = sum(int(n) for n in nums[1:])
        return total_changes <= max_lines
    
    def run_all(self) -> bool:
        gates = {
            "lint": self.check_lint,
            "types": self.check_types,
            "tests": self.check_tests,
            "diff_size": self.check_diff_size,
        }
        
        all_passed = True
        for name, check in gates.items():
            passed = check()
            status = "PASS" if passed else "FAIL"
            print(f"  [{status}] {name}")
            if not passed:
                all_passed = False
        
        return all_passed

if __name__ == "__main__":
    gate = QualityGate()
    if not gate.run_all():
        print("\n품질 게이트 미통과 — 커밋 차단")
        sys.exit(1)
    print("\n모든 품질 게이트 통과")
```

| 게이트 | 필수 여부 | 실패 시 동작 |
|--------|----------|-------------|
| 린트(ESLint/Ruff) | 필수 | 커밋 차단 |
| 타입 체크 | 필수 | 커밋 차단 |
| 테스트 | 필수 | 커밋 차단 |
| 변경량 제한 | 권장 | 경고 + 분할 제안 |
| 보안 스캔 | 선택 | 경고 + 리뷰 요청 |

## Step 6: 모니터링과 알림 통합

가드레일 작동 현황을 추적하고 개선해야 해요.

### 에이전트 실행 로그 구조

```json
{
  "session_id": "abc-123",
  "timestamp": "2026-04-01T21:00:00+09:00",
  "task": "feature/user-auth 구현",
  "model": "claude-opus-4-20250918",
  "status": "success",
  "retries": 1,
  "circuit_state": "closed",
  "fallback_used": false,
  "guardrail_violations": [],
  "quality_gates": {
    "lint": true,
    "types": true,
    "tests": true,
    "diff_size": true
  },
  "tokens_used": 45000,
  "duration_seconds": 120
}
```

### 주간 리포트 메트릭

| 메트릭 | 계산 방법 | 목표 |
|--------|----------|------|
| 1차 성공률 | 재시도 없이 성공한 비율 | 70% 이상 |
| 최종 성공률 | 가드레일 포함 전체 성공률 | 95% 이상 |
| 평균 재시도 횟수 | 성공까지 평균 시도 수 | 1.5 이하 |
| 서킷 오픈 빈도 | 주당 서킷 브레이커 발동 수 | 2회 이하 |
| 폴백 사용률 | 폴백이 동작한 비율 | 10% 이하 |
| 가드레일 위반 | 범위 초과 차단 수 | 감소 추세 |

### 알림 설정 기준

```yaml
# 알림 트리거
alerts:
  - name: "서킷 브레이커 발동"
    condition: "circuit_state == 'open'"
    severity: "warning"
    
  - name: "연속 실패"
    condition: "consecutive_failures >= 3"
    severity: "critical"
    
  - name: "비용 급증"
    condition: "daily_token_usage > threshold * 2"
    severity: "warning"
    
  - name: "품질 게이트 연속 실패"
    condition: "quality_gate_failures >= 3"
    severity: "critical"
```

## 체크리스트

- [ ] 재시도 정책 정의 (최대 횟수, 백오프 전략, 재시도 가능 에러 목록)
- [ ] 서킷 브레이커 구현 (실패 한계, 쿨다운, 상태 파일)
- [ ] 폴백 체인 설정 (모델 다운그레이드, 프롬프트 축소, 태스크 분할)
- [ ] 파일 수정 범위 제한 (CLAUDE.md + pre-commit 훅)
- [ ] 품질 게이트 자동화 (린트, 타입, 테스트, 변경량)
- [ ] 모니터링 로그 구조 설계
- [ ] 알림 트리거 설정

## 다음 단계

→ [AI 장애 대응 플레이북](25-ai-incident-response.md)
→ [AI 에이전트 옵저버빌리티 가이드](../../guides/29-ai-agent-observability.md)
→ [AI 코딩 에이전트 트러블슈팅 가이드](../../guides/41-ai-agent-troubleshooting.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
