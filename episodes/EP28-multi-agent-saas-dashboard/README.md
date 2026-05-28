# EP28: AI 에이전트 팀으로 SaaS 대시보드 빌드하기 — 멀티에이전트 협업 실전

> Claude Code Agent Teams로 백엔드, 프론트엔드, 데이터베이스 에이전트를 동시에 돌리고 SaaS 분석 대시보드를 실제로 완성하는 에피소드

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- Claude Code Agent Teams로 역할별 에이전트 동시 실행하기
- 백엔드(API) · 프론트엔드(UI) · 데이터베이스(스키마) 에이전트 분리 전략
- 에이전트 간 파일 충돌 없이 병렬 개발하는 Git Worktree 패턴
- 실시간 에이전트 상태 모니터링과 충돌 감지

## 완성하는 것

SaaS 분석 대시보드 — 사용자당 이벤트, MAU, 구독 상태를 실시간으로 보여주는 Next.js 앱

**기술 스택:** Next.js 16 · TypeScript · Drizzle ORM · Neon Postgres · Tailwind CSS · Clerk

## 에이전트 팀 구성

```
오케스트레이터 (리드 에이전트)
├── backend-agent    → API 라우트, 데이터 집계 로직
├── frontend-agent   → 대시보드 UI 컴포넌트
└── db-agent         → 스키마 설계, 마이그레이션
```

## 핵심 설정

### AGENTS.md (팀 규칙)

```markdown
## 에이전트 팀 역할

- **backend-agent**: src/app/api/** 만 수정
- **frontend-agent**: src/app/(dashboard)/** 만 수정
- **db-agent**: src/db/schema.ts, drizzle/ 만 수정
- 파일 소유권 충돌 시 오케스트레이터에게 즉시 보고
- 공유 타입은 src/types/shared.ts에 정의 — 먼저 완성하고 시작
```

### 에이전트 팀 실행

```bash
# 오케스트레이터 시작
claude --model claude-opus-4-7

# 오케스트레이터 프롬프트
"""
다음 역할로 에이전트 팀을 구성해:
1. backend-agent: src/app/api/ — 이벤트 집계 API 구현
2. frontend-agent: src/app/(dashboard)/ — 차트 및 카드 UI 구현
3. db-agent: src/db/ — 스키마 설계 및 마이그레이션 실행

먼저 db-agent가 스키마를 완성한 후, backend-agent와 frontend-agent가 동시에 시작하도록 조율해.
"""
```

## 따라하기

### Step 1: 프로젝트 초기화

```bash
npx create-next-app@latest saas-dashboard \
  --typescript --tailwind --app --src-dir

cd saas-dashboard

# 의존성 설치
npm install drizzle-orm @neondatabase/serverless drizzle-kit
npm install @clerk/nextjs recharts date-fns
npm install -D @types/node
```

### Step 2: 에이전트 설정 파일 작성

```bash
# CLAUDE.md 초안 작성 프롬프트
claude "이 Next.js SaaS 대시보드 프로젝트의 CLAUDE.md를 작성해줘.
스택: Next.js 16, TypeScript, Drizzle ORM, Neon Postgres, Clerk, Recharts.
에이전트 팀이 병렬로 작업할 예정이므로 파일 소유권 규칙을 명확히 포함해줘."
```

### Step 3: 스키마 에이전트 (db-agent) 실행

```bash
claude "db-agent로서 SaaS 분석 대시보드의 Drizzle ORM 스키마를 설계하고 마이그레이션을 실행해.

필요한 테이블:
- events: userId, eventName, properties, createdAt
- subscriptions: userId, plan, status, startedAt, cancelledAt
- users: id, email, createdAt, lastActiveAt

스키마를 src/db/schema.ts에 작성하고, src/types/shared.ts에 공유 타입을 export해줘."
```

**db-agent 결과물:**

```typescript
// src/db/schema.ts
import { pgTable, text, timestamp, jsonb } from 'drizzle-orm/pg-core'

export const events = pgTable('events', {
  id: text('id').primaryKey().default('gen_random_uuid()'),
  userId: text('user_id').notNull(),
  eventName: text('event_name').notNull(),
  properties: jsonb('properties'),
  createdAt: timestamp('created_at').defaultNow(),
})

export const subscriptions = pgTable('subscriptions', {
  id: text('id').primaryKey().default('gen_random_uuid()'),
  userId: text('user_id').notNull(),
  plan: text('plan').notNull(),
  status: text('status').notNull(),
  startedAt: timestamp('started_at').defaultNow(),
  cancelledAt: timestamp('cancelled_at'),
})
```

### Step 4: 백엔드 에이전트 (backend-agent) 실행

스키마 완료 후 backend-agent 동시 시작:

```bash
claude "backend-agent로서 src/app/api/ 하위에 대시보드 API 라우트를 구현해.

필요한 엔드포인트:
- GET /api/metrics/summary — MAU, 총 이벤트 수, 활성 구독자
- GET /api/metrics/events — 날짜별 이벤트 추이 (최근 30일)
- GET /api/metrics/subscriptions — 플랜별 구독 분포

src/types/shared.ts의 타입을 import해서 사용해줘.
Drizzle ORM + Neon Postgres로 실제 데이터를 조회해야 해."
```

### Step 5: 프론트엔드 에이전트 (frontend-agent) 실행

backend-agent와 동시에:

```bash
claude "frontend-agent로서 src/app/(dashboard)/ 하위에 분석 대시보드 UI를 구현해.

필요한 컴포넌트:
- SummaryCards — MAU, 이벤트 수, 활성 구독자 카드
- EventsChart — Recharts LineChart로 날짜별 이벤트 추이
- SubscriptionPieChart — 플랜별 구독 분포 파이 차트

/api/metrics/* 엔드포인트에서 데이터를 fetch해줘.
Tailwind CSS로 스타일링하고 로딩 상태도 처리해줘."
```

### Step 6: 오케스트레이터가 통합

```bash
claude "백엔드와 프론트엔드 에이전트 작업이 완료됐어.
타입 충돌이나 API 불일치가 없는지 확인하고, 필요하면 조정해줘.
최종적으로 TypeScript 빌드 에러가 없는지 검증해줘."
```

## 병렬 실행 시 주의점

| 상황 | 대응 |
|------|------|
| 같은 파일 동시 수정 | AGENTS.md 파일 소유권 규칙으로 사전 차단 |
| API 타입 불일치 | shared.ts를 먼저 확정 후 에이전트 시작 |
| 에이전트가 멈춤 | Agent View에서 상태 확인 후 재시작 |
| 빌드 에러 | 오케스트레이터가 통합 단계에서 최종 검증 |

## AI 활용 포인트

| 상황 | 접근 방식 |
|------|-----------|
| 에이전트 역할 경계 불명확 | AGENTS.md에 파일 경로 단위로 소유권 명시 |
| 에이전트 간 데이터 타입 공유 | 공유 타입 파일을 먼저 확정하고 에이전트 시작 |
| 완성 속도 측정 | 단일 에이전트 vs 팀 에이전트 소요 시간 직접 비교 |

## 결과 비교

| 방식 | 소요 시간 | 코드 품질 |
|------|-----------|-----------|
| 단일 에이전트 (순차) | 약 45분 | 일관성 높음 |
| 에이전트 팀 (병렬) | 약 18분 | 통합 단계 필요 |

에이전트 팀은 빠르지만 **설계가 명확할 때** 효과적이에요. 모호한 요구사항이라면 오케스트레이터와 함께 스펙을 먼저 확정하는 게 더 빠릅니다.

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
