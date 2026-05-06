# 플레이북 61: AI 에이전트 디버깅 타임라인 — 프로덕션 버그 30분 내 해결

> 프로덕션 장애가 발생했을 때 AI 에이전트와 함께 30분 안에 근본 원인을 찾고 핫픽스를 배포하는 단계별 타임라인

## 소요 시간

20-35분 (장애 심각도에 따라 차이 있음)

## 사전 준비

- Claude Code 설치 및 레포 접근 권한
- 프로덕션 로그 접근 권한 (Datadog, CloudWatch, 또는 로컬 로그 파일)
- 스테이징/로컬 재현 환경
- hotfix 브랜치 생성 권한 및 긴급 배포 절차 숙지

## 타임라인 개요

| 구간 | 시간 | 목표 |
|------|------|------|
| T+0~5분 | 초기 파악 | 장애 범위와 증상 정의 |
| T+5~12분 | 로그 분석 | 근본 원인 후보 2~3개 도출 |
| T+12~20분 | 재현 및 확인 | 원인 특정 + 수정 코드 작성 |
| T+20~30분 | 검증 및 배포 | 테스트 통과 + 핫픽스 PR |

---

## T+0~5분: 초기 파악

### Step 1: 증상을 명확히 정의하기

Claude Code에 장애 상황을 바로 공유합니다. 이때 **구체적인 증상**을 함께 붙여넣으세요:

```bash
# 에러 로그 첫 번째 발생 시점부터 수집
grep -E "ERROR|FATAL|Exception" /var/log/app/production.log \
  | tail -100 \
  | head -50

# 혹은 CloudWatch (AWS)
aws logs filter-log-events \
  --log-group-name /app/production \
  --start-time $(date -v-30M +%s000) \
  --filter-pattern "ERROR"
```

Claude Code에 전달할 첫 번째 프롬프트:

```
다음 에러 로그를 분석해줘. 
- 서비스: [서비스명]
- 발생 시점: [시각]
- 영향 범위: [예: 결제 API 전체 / 특정 유저 그룹]
- 직전 배포: [예: 30분 전 v2.3.1 배포]

[에러 로그 붙여넣기]

근본 원인 후보 3가지와 각각의 확인 방법을 알려줘.
```

### Step 2: 최근 변경 이력 확인

```bash
# 최근 24시간 커밋
git log --oneline --since="24 hours ago"

# 최근 배포된 파일 목록
git diff HEAD~1 HEAD --name-only

# 직전 배포와 현재 비교
git diff v2.3.0 v2.3.1 -- src/payment/
```

---

## T+5~12분: 로그 분석

### Step 3: 스택 트레이스 파싱

Claude Code에 스택 트레이스 전체를 붙여넣고 분석을 요청합니다:

```
스택 트레이스에서 실제 내 코드가 호출된 첫 번째 지점을 찾아줘.
라이브러리/프레임워크 내부 호출은 제외하고,
src/ 또는 app/ 디렉토리 하위 파일만 집중해서 분석해줘.
```

Claude Code는 다음을 찾아냅니다:

- 내 코드에서 실제 실패한 라인
- 해당 함수에 전달된 입력값 (로그에서 추출)
- 유사한 실패 패턴이 과거에도 있었는지

### Step 4: 패턴 기반 원인 좁히기

장애 유형별 빠른 확인 방법:

| 장애 유형 | 빠른 확인 쿼리 |
|-----------|---------------|
| DB 연결 오류 | `grep "connection pool\|timeout\|ECONNREFUSED" *.log` |
| 메모리 부족 | `grep "OutOfMemory\|heap\|killed" *.log` |
| 외부 API 실패 | `grep "status: 5[0-9][0-9]\|ETIMEDOUT" *.log` |
| 배포 코드 오류 | `git diff HEAD~1 HEAD -- [의심 파일]` |
| 데이터 이상 | `grep "undefined\|null reference\|NaN" *.log` |

Claude Code 프롬프트:

```
위 로그에서 타임스탬프 기준으로 에러가 처음 발생한 시점과
그 직전 10초 동안의 정상 로그를 비교해줘.
무엇이 달라졌는지 찾아줘.
```

---

## T+12~20분: 재현 및 수정

### Step 5: 로컬 재현

원인이 특정되면 재현 환경을 빠르게 구성합니다:

```bash
# 프로덕션과 동일한 입력으로 테스트
NODE_ENV=production node -e "
  const { handler } = require('./src/payment/checkout');
  handler({ userId: '문제유저ID', amount: 문제금액 })
    .catch(console.error);
"
```

Claude Code에 재현 케이스 작성을 요청합니다:

```
이 버그를 재현하는 최소한의 테스트 케이스를 작성해줘.
기존 테스트 파일: [파일명]
재현 조건: [로그에서 파악한 입력값]
```

### Step 6: 수정 코드 작성

원인이 명확해지면 Claude Code에 수정을 요청합니다:

```
[파일명]의 [함수명]에서 발생하는 [에러 메시지] 버그를 수정해줘.

조건:
- 기존 동작 방식은 유지
- 방어 코드를 추가하는 방향으로
- 변경 범위를 최소화
- 수정 후 영향 받는 함수 목록도 알려줘
```

수정 예시 패턴:

```typescript
// Before: 방어 코드 없음
function processPayment(amount: number, userId: string) {
  const user = getUserById(userId);
  return charge(user.paymentMethod, amount); // user가 null이면 에러
}

// After: null 체크 추가
function processPayment(amount: number, userId: string) {
  const user = getUserById(userId);
  if (!user) {
    throw new PaymentError(`User not found: ${userId}`);
  }
  if (!user.paymentMethod) {
    throw new PaymentError(`No payment method for user: ${userId}`);
  }
  return charge(user.paymentMethod, amount);
}
```

---

## T+20~30분: 검증 및 배포

### Step 7: 빠른 테스트 실행

```bash
# 수정된 파일 관련 테스트만 실행
npm test -- --testPathPattern="payment|checkout" --coverage

# 혹은 해당 모듈 단위 테스트
pytest tests/test_payment.py -v -k "checkout"
```

Claude Code에 추가 엣지 케이스 확인 요청:

```
방금 수정한 코드에서 놓쳤을 수 있는 엣지 케이스를 3가지만 알려줘.
각각에 대한 테스트 코드도 추가해줘.
```

### Step 8: 핫픽스 PR 생성

```bash
# hotfix 브랜치
git checkout -b "hotfix/payment-null-user-$(date +%Y%m%d)"

git add src/payment/checkout.ts tests/payment.test.ts
git commit -m "fix(payment): handle null user in processPayment

- Add null check for user object before accessing paymentMethod
- Add error logging for missing payment method
- Fixes production issue affecting checkout since 05:30 KST

Root cause: getUserById returns null for deleted accounts
but processPayment assumed user always exists"

git push origin HEAD
```

긴급 PR 생성:

```bash
gh pr create \
  --title "fix(payment): handle null user in processPayment [HOTFIX]" \
  --body "## 장애 요약
- **발생 시각:** [시각]
- **영향 범위:** [예: 결제 실패율 12% → 정상 0.1%]
- **근본 원인:** getUserById가 삭제된 계정에 null 반환

## 변경 내용
- processPayment에 null 체크 추가
- 명시적 에러 메시지로 디버깅 용이성 개선

## 검증
- [ ] 로컬 재현 케이스 통과
- [ ] 기존 테스트 전부 통과
- [ ] 스테이징 배포 확인

## 롤백 계획
이전 버전으로 즉시 롤백 가능 (v2.3.0)"
```

---

## 체크리스트

### 디버깅 시작 전
- [ ] 장애 범위 확인 (전체/부분/특정 유저)
- [ ] 최근 배포 시점과 장애 시작 시점 비교
- [ ] 로그 접근 권한 확인

### 원인 파악 단계
- [ ] 스택 트레이스에서 내 코드 진입점 찾기
- [ ] 첫 에러 발생 직전 로그 확인
- [ ] 배포 직전 코드 변경 내용 검토

### 수정 및 배포 단계
- [ ] 로컬 재현 성공 확인
- [ ] 수정 범위 최소화 확인
- [ ] 기존 테스트 통과 확인
- [ ] PR 설명에 장애 요약, 근본 원인, 검증 방법 포함

---

## 주요 에러 유형별 빠른 대응

### NullPointerException / TypeError

```
Claude Code 프롬프트:
"[스택 트레이스]에서 null/undefined가 어떤 경로로 전달되었는지 추적해줘.
가능한 입력 경로를 모두 나열하고 각각에 방어 코드를 추가해줘."
```

### DB 연결 풀 고갈

```bash
# 현재 연결 수 확인 (PostgreSQL)
SELECT count(*), state FROM pg_stat_activity GROUP BY state;

# 오래된 연결 강제 종료
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE duration > interval '5 minutes' AND state = 'idle';
```

### 메모리 누수

```bash
# Node.js 메모리 스냅샷 (프로덕션 임시)
node --expose-gc --inspect=0.0.0.0:9229 app.js

# Python 메모리 추적
py-spy top --pid $(pgrep -f gunicorn)
```

---

## 다음 단계

장애 해결 후 반드시 진행할 것:

1. **포스트모템 작성** — 타임라인, 근본 원인, 예방 조치 문서화
2. **회귀 테스트 추가** — 동일 버그 재발 방지용 테스트 코드 커밋
3. **알람 설정** — 유사 패턴 조기 감지를 위한 모니터링 룰 추가

→ [AI 에이전트 인시던트 대응 워크플로우](../../workflows/ai-incident-response-workflow.md)

→ [AI 에이전트 컨텍스트 오염 방지 플레이북](./57-context-contamination-prevention.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
