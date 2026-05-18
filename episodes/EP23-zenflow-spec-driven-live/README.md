# EP23: Zencoder ZenFlow로 스펙 주도 개발 실전 — 플래닝부터 배포까지

> 코드를 짜기 전에 스펙을 정의하고, AI가 그 스펙에 따라 구현·검증·배포까지 완성하는 라이브 코딩

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

---

## 이 에피소드에서 다루는 것

- ZenFlow의 스펙 주도 개발 워크플로우 — 요구사항에서 스펙 문서를 만들고 AI가 실행하는 구조
- GitHub, Jira, Sentry MCP 도구를 ZenFlow에 연결해 티켓 → 스펙 → 구현 → 배포를 하나의 흐름으로 이어가는 방법
- ZenFlow Work의 플래닝 기능으로 기능 요구사항을 검증 가능한 스펙으로 변환하는 패턴
- 에이전트가 스펙을 읽고 단계별로 구현하면서 자체 검증 루프를 돌리는 실전 시나리오
- "바이브 코딩"과 스펙 주도 개발의 실질적 차이를 실습으로 비교

---

## 스택

| 항목 | 내용 |
|------|------|
| AI 플랫폼 | Zencoder ZenFlow (v2.0+, 2026년 4월 출시) |
| MCP 연동 | GitHub, Jira, Sentry, Slack |
| 핵심 기능 | ZenFlow Work, 스펙 에디터, 내장 검증 |
| 예제 기능 | SaaS 구독 결제 알림 기능 (Node.js + TypeScript) |
| 배포 타깃 | Vercel (프론트엔드) + Railway (백엔드) |

---

## 배경: 왜 스펙 주도 개발인가

AI 코딩 도구를 쓰면서 이런 경험 있으신가요?

| 문제 | 바이브 코딩 | 스펙 주도 개발 |
|------|-----------|-------------|
| 구현 방향 불일치 | AI가 요구사항을 다르게 해석 | 스펙 문서가 기준 — 에이전트가 스펙을 읽고 실행 |
| 엣지 케이스 누락 | 프롬프트에 없으면 구현 안 됨 | 스펙에 모든 조건 명시, AI가 자동 체크 |
| 리뷰 기준 불명확 | "뭔가 이상해 보이는데..." | 스펙 충족 여부로 명확하게 판단 |
| 회귀 발생 | 새 기능이 기존 기능을 깨뜨림 | 스펙 기반 검증이 자동으로 돌아감 |

ZenFlow는 "목표만 알려줘, 내가 실행할게"에서 "스펙대로 짜, 내가 검증할게"로 패러다임을 바꿔요.

---

## 실습 기능: 구독 결제 알림 시스템

이 에피소드에서 구현하는 기능은 SaaS에서 흔히 필요한 **구독 결제 알림**이에요.

**기능 요구사항 (Jira 티켓 형태)**

```
제목: 결제 실패 시 사용자에게 이메일 + Slack 알림 전송
설명:
- 결제 실패 감지 시 이메일 알림 (Resend API)
- 팀 Slack 채널에 실패 요약 전송
- 실패 3회 이후 계정 일시 정지 처리
- Sentry에 결제 실패 이벤트 로깅
수락 기준:
  - 결제 실패 후 30초 내 이메일 발송
  - Slack 메시지에 고객 ID, 금액, 실패 사유 포함
  - 3회 연속 실패 계정은 DB 상태값 suspended 변경
```

---

## ZenFlow 스펙 에디터 — 요구사항을 스펙으로

Jira 티켓을 ZenFlow에 연결하면 스펙 에디터가 열려요. 자연어 요구사항을 검증 가능한 스펙으로 변환하는 단계예요.

**ZenFlow가 생성한 스펙 예시**

```yaml
# spec: subscription-payment-alert
version: 1.0
feature: 결제 실패 알림 시스템

behaviors:
  - id: ALERT-001
    when: 결제 실패 이벤트 감지
    then:
      - 이메일 발송 (Resend API, 30초 내)
      - Slack 메시지 전송 (customer_id, amount, reason 포함)
    verify: 이메일 발송 로그 + Slack webhook 응답 200

  - id: ALERT-002
    when: 동일 계정 연속 3회 실패
    then:
      - DB accounts.status = 'suspended'
      - Sentry 이벤트 캡처
    verify: DB 쿼리 결과 + Sentry 이벤트 존재 확인

constraints:
  - 이메일 발송 실패 시 재시도 3회 (지수 백오프)
  - Slack 전송 실패는 비차단 (결제 로직에 영향 없음)
  - 민감 정보(카드번호 등) 로그 기록 금지
```

스펙이 확정되면 ZenFlow가 실행 계획을 생성해요.

---

## 실행 단계 — 에이전트가 스펙을 읽고 구현

### Step 1: ZenFlow 플래닝

ZenFlow가 스펙을 분석해 구현 계획을 수립해요.

```
ZenFlow Planner
> 스펙 ALERT-001, ALERT-002 분석 중...

실행 계획:
1. Webhook 핸들러 구현 (payment/webhook.ts)
2. 이메일 서비스 연결 (services/email.ts)
3. Slack 알림 서비스 구현 (services/slack.ts)
4. 연속 실패 카운터 로직 (services/payment-monitor.ts)
5. Sentry 에러 캡처 추가 (middleware/sentry.ts)
6. 통합 테스트 작성 (tests/payment-alert.test.ts)
```

### Step 2: 에이전트 구현

```typescript
// services/payment-monitor.ts (ZenFlow 생성)
import { sendEmail } from './email'
import { notifySlack } from './slack'
import * as Sentry from '@sentry/node'
import { db } from '../db'

export async function handlePaymentFailure(event: PaymentFailureEvent) {
  const { customerId, amount, reason, attemptCount } = event

  // ALERT-001: 이메일 + Slack 알림
  await Promise.allSettled([
    sendEmail({
      to: await getCustomerEmail(customerId),
      subject: '결제 실패 안내',
      template: 'payment-failure',
      data: { amount, reason }
    }),
    notifySlack({
      channel: '#billing-alerts',
      text: `결제 실패 — 고객: ${customerId} | 금액: ${amount}원 | 사유: ${reason}`
    })
  ])

  // ALERT-002: 3회 연속 실패 시 계정 정지
  if (attemptCount >= 3) {
    await db.accounts.update({
      where: { id: customerId },
      data: { status: 'suspended' }
    })

    Sentry.captureEvent({
      message: 'Account suspended due to repeated payment failures',
      level: 'warning',
      extra: { customerId, attemptCount }
    })
  }
}
```

### Step 3: 스펙 검증

구현이 끝나면 ZenFlow가 스펙 조건을 자동으로 검증해요.

```
ZenFlow Validator
> ALERT-001 검증 중...
  ✅ 이메일 발송 응답 시간: 평균 8.3초 (< 30초 기준 충족)
  ✅ Slack 메시지 customer_id 포함: 확인
  ✅ Slack 메시지 amount 포함: 확인
  ✅ Slack 메시지 reason 포함: 확인

> ALERT-002 검증 중...
  ✅ 3회 실패 후 DB status = 'suspended' 확인
  ✅ Sentry 이벤트 캡처 확인

> constraints 검증 중...
  ✅ 이메일 재시도 로직 (3회, 지수 백오프) 확인
  ✅ Slack 실패 시 비차단 처리 확인
  ✅ 카드 정보 로그 누락 확인

스펙 충족률: 100% (7/7)
```

---

## MCP 연동 실전 — GitHub PR 자동 생성

검증을 통과하면 ZenFlow가 GitHub MCP를 통해 PR을 자동 생성해요.

```bash
# ZenFlow가 자동으로 실행하는 흐름
1. feature/payment-alert 브랜치 생성
2. 구현 파일 커밋 (5개 파일)
3. PR 생성 — 스펙 충족 여부를 PR 본문에 첨부
4. Jira 티켓 상태 → "In Review" 자동 변경
5. Slack #dev 채널에 PR 링크 전송
```

PR 본문 예시:

```markdown
## 구현 요약
구독 결제 실패 알림 시스템 구현 (스펙 v1.0 기반)

## 스펙 충족 결과
| 조건 | 결과 |
|------|------|
| ALERT-001: 이메일 30초 내 발송 | ✅ |
| ALERT-001: Slack 메시지 필드 포함 | ✅ |
| ALERT-002: 3회 실패 후 계정 정지 | ✅ |
| ALERT-002: Sentry 이벤트 캡처 | ✅ |
| 재시도 로직 | ✅ |
| 비차단 Slack 처리 | ✅ |
| 민감정보 로그 제외 | ✅ |

테스트 커버리지: 94%
```

---

## 따라하기

### 사전 준비

```bash
# ZenFlow CLI 설치
npm install -g @zencoder/zenflow

# 인증
zenflow login

# MCP 도구 연결
zenflow mcp add github
zenflow mcp add jira --project-key YOUR_PROJECT
zenflow mcp add sentry --org YOUR_ORG
```

### Step 1: Jira 티켓 가져오기

```bash
zenflow intake --source jira --ticket PROJ-1234
```

ZenFlow가 티켓 내용을 읽고 스펙 에디터를 엽니다.

### Step 2: 스펙 검토 및 확정

```bash
zenflow spec review
```

AI가 생성한 스펙 초안을 보고 누락된 엣지 케이스를 추가하거나 조건을 구체화합니다.

```bash
# 스펙 확정
zenflow spec approve
```

### Step 3: 실행

```bash
zenflow run --spec payment-alert
```

ZenFlow가 스펙을 실행하고 각 단계별 진행 상황을 터미널에 표시합니다.

### Step 4: 검증 결과 확인

```bash
zenflow validate --report
```

스펙 조건별 충족 여부와 테스트 커버리지를 JSON 리포트로 확인합니다.

### Step 5: 배포

```bash
# 검증 통과 후 배포
zenflow deploy --env production
```

---

## ZenFlow vs 기존 AI 코딩 방식 비교

| 항목 | 프롬프트 기반 | ZenFlow 스펙 기반 |
|------|------------|----------------|
| 요구사항 정의 | 프롬프트에 자연어로 | 구조화된 스펙 YAML |
| 구현 기준 | 에이전트 해석에 의존 | 스펙이 기준, 에이전트가 맞춤 |
| 검증 방법 | 수동 테스트 | 스펙 조건 자동 체크 |
| 리뷰 기준 | 코드 품질 판단 | 스펙 충족률 수치 |
| 도구 연동 | 별도 스크립트 | MCP로 통합 연결 |
| 반복 개선 | 새 프롬프트 작성 | 스펙 수정 후 재실행 |

---

## 핵심 정리

- **스펙이 실행 계약이다** — "구현해줘"가 아니라 "이 조건을 충족해줘"
- **검증은 자동으로** — 스펙 조건이 테스트 기준이 되므로 별도 테스트 작성 부담이 줄어요
- **연동은 MCP로** — GitHub, Jira, Sentry를 연결하면 티켓 → PR → 배포 흐름이 자동화돼요
- **스펙은 팀의 공통 언어** — 개발자, PM, QA 모두 같은 문서를 보고 판단 기준을 공유해요

---

## 더 알아보기

- [스펙 주도 개발 실전 가이드 2026](../guides/80-spec-first-ai-workflow-guide.md)
- [Zencoder ZenFlow 실전 가이드 2026](../guides/102-zencoder-zenflow-practical-guide-2026.md)
- [AI 에이전트 코드 생성 품질 게이트 자동화 플레이북](../claude-code/playbooks/67-ai-code-quality-gates.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
