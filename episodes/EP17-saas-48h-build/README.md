# EP17: AI 에이전트로 풀스택 SaaS 48시간 만에 만들기

> Next.js + Supabase + AI 에이전트로 실제 SaaS 제품을 48시간 내 구현하는 라이브 코딩 에피소드 — 기획부터 배포까지

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

---

## 이 에피소드에서 다루는 것

- 48시간 제한 안에 SaaS MVP를 완성하는 실전 전략
- Next.js + Supabase + Vercel 스택을 AI 에이전트로 빠르게 설정하는 방법
- 기획 → 스캐폴딩 → 인증 → DB → 결제 → 배포 전 과정 자동화
- Claude Code로 반복 작업을 위임하고 본질적인 판단에만 집중하기
- 실제 배포까지 마친 결과물 데모

---

## 스택

| 레이어 | 기술 |
|--------|------|
| 프론트엔드 | Next.js 15 + TypeScript + Tailwind CSS |
| 백엔드/DB | Supabase (PostgreSQL + RLS + pgvector) |
| 인증 | Supabase Auth |
| 결제 | Stripe |
| 배포 | Vercel |
| AI 에이전트 | Claude Code + AGENTS.md |
| 이메일 | Resend |

---

## 타임라인

### Day 1 (0-24h): 기반 구축

```
0h  → 기획 & 스펙 문서 작성 (SPEC.md)
2h  → 스캐폴딩 + AGENTS.md 설정
4h  → Supabase 프로젝트 생성 + 스키마 설계
8h  → 인증 플로우 구현
12h → 핵심 기능 1차 구현
18h → API 라우트 + DB 연동
24h → 중간 점검 + 버그 수정
```

### Day 2 (24-48h): 완성 & 배포

```
24h → 결제 연동 (Stripe)
30h → UI 다듬기 + 에러 처리
36h → E2E 테스트 자동 생성
42h → 환경변수 정리 + 배포
45h → 첫 배포 + 최종 테스트
48h → 완성!
```

---

## 핵심 코드 & 설정

### AGENTS.md — AI 에이전트 팀 규칙 정의

```markdown
# AGENTS.md

## 프로젝트 개요
SaaS MVP: [제품명] — [핵심 기능 한 줄 설명]
기술 스택: Next.js 15, Supabase, Stripe, Vercel
데드라인: 48시간

## 코드 규칙
- TypeScript strict mode 필수
- 컴포넌트: Server Component 우선, 클라이언트는 필요한 경우만
- DB 접근: Supabase RLS 항상 활성화
- 에러 처리: try-catch + 사용자 친화적 메시지

## 우선순위
1. 동작하는 코드 > 완벽한 코드
2. 핵심 기능 먼저, 엣지 케이스는 나중에
3. 테스트는 핵심 플로우만

## 금지 사항
- console.log를 프로덕션 코드에 남기지 말 것
- any 타입 사용 금지
- 주석으로만 설명하고 코드 안 짜는 것 금지
```

### Supabase 스키마 설계

```sql
-- 사용자 프로필
create table profiles (
  id uuid references auth.users primary key,
  email text unique not null,
  display_name text,
  plan text default 'free' check (plan in ('free', 'pro', 'team')),
  stripe_customer_id text,
  created_at timestamptz default now()
);

-- RLS 정책
alter table profiles enable row level security;
create policy "Users can view own profile"
  on profiles for select using (auth.uid() = id);
create policy "Users can update own profile"
  on profiles for update using (auth.uid() = id);

-- 자동 프로필 생성 트리거
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

### Next.js 미들웨어 — 인증 보호

```typescript
// middleware.ts
import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export async function middleware(req: NextRequest) {
  const res = NextResponse.next()
  const supabase = createMiddlewareClient({ req, res })

  const {
    data: { session },
  } = await supabase.auth.getSession()

  // 보호된 경로: 로그인 필요
  if (!session && req.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', req.url))
  }

  // 로그인 상태에서 auth 페이지 접근 시 대시보드로
  if (session && ['/login', '/signup'].includes(req.nextUrl.pathname)) {
    return NextResponse.redirect(new URL('/dashboard', req.url))
  }

  return res
}

export const config = {
  matcher: ['/dashboard/:path*', '/login', '/signup'],
}
```

### Stripe 결제 연동

```typescript
// app/api/checkout/route.ts
import Stripe from 'stripe'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(req: Request) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { priceId } = await req.json()

  const session = await stripe.checkout.sessions.create({
    customer_email: user.email,
    line_items: [{ price: priceId, quantity: 1 }],
    mode: 'subscription',
    success_url: `${process.env.NEXT_PUBLIC_URL}/dashboard?success=true`,
    cancel_url: `${process.env.NEXT_PUBLIC_URL}/pricing`,
    metadata: { userId: user.id },
  })

  return Response.json({ url: session.url })
}
```

---

## AI 에이전트 프롬프트 패턴

| 단계 | 프롬프트 예시 |
|------|-------------|
| 스캐폴딩 | `Next.js 15 + Supabase + Tailwind SaaS 보일러플레이트 만들어줘. AGENTS.md 규칙 따라서.` |
| 인증 | `Supabase Auth로 이메일/소셜 로그인 추가해줘. 미들웨어로 대시보드 보호.` |
| DB 스키마 | `profiles 테이블 + RLS 정책 + 트리거 만들어줘. 스키마는 위 파일 참고.` |
| 결제 | `Stripe 체크아웃 + 웹훅으로 plan 업데이트하는 API 라우트 만들어줘.` |
| 배포 준비 | `.env.example 만들고, Vercel 배포에 필요한 환경변수 목록 정리해줘.` |

---

## 실제로 막혔던 순간들

### 문제 1: Supabase RLS가 API 호출을 차단

```bash
# 증상: 대시보드 데이터 조회 시 빈 배열 반환
# 원인: RLS 정책에서 service role 미사용

# 해결: Server Component에서는 service role 클라이언트 사용
import { createClient } from '@supabase/supabase-js'

const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY! // 서버에서만 사용!
)
```

### 문제 2: Stripe 웹훅 서명 검증 실패

```typescript
// 해결: raw body 사용 (Next.js App Router 방식)
export async function POST(req: Request) {
  const body = await req.text() // json() 아닌 text()!
  const sig = req.headers.get('stripe-signature')!

  const event = stripe.webhooks.constructEvent(
    body,
    sig,
    process.env.STRIPE_WEBHOOK_SECRET!
  )
  // ...
}
```

### 문제 3: 환경변수 누락으로 Vercel 배포 실패

```bash
# 배포 전 체크리스트 (Claude Code에 맡기기)
# "Vercel 배포에 필요한 모든 환경변수를 .env.example로 정리해줘"

NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=
RESEND_API_KEY=
NEXT_PUBLIC_URL=
```

---

## 48시간 완성을 위한 핵심 원칙

1. **스펙 먼저, 코드 나중** — SPEC.md를 30분 안에 완성하고 AI에 넘기기
2. **보일러플레이트는 AI가** — 반복적인 설정 코드는 처음부터 위임
3. **막히면 5분 규칙** — 5분 안에 해결 안 되면 다음으로 넘어가기
4. **배포는 일찍** — Day 1 끝에 프리뷰 배포, 환경 문제 조기 발견
5. **MVP 범위 지키기** — "이것도 되면 좋겠다"를 이겨내기

---

## 에피소드 결과물

이번 에피소드에서 완성한 제품: **AI 기반 코드 리뷰 대기열 관리 SaaS**

- PR 제출 → AI 우선순위 분류 → 팀 슬랙 알림
- 무료 플랜: 월 10 PR, Pro 플랜: 무제한
- 48시간 후 실제 배포 완료

---

## 더 알아보기

- [플레이북 43: 팀 온보딩 자동화](../../claude-code/playbooks/43-team-onboarding-automation.md)
- [가이드 63: 컨텍스트 엔지니어링](../../guides/63-context-engineering-2026.md)
- [가이드 56: 그린필드 프로젝트 킥오프](../../claude-code/playbooks/56-greenfield-project-kickoff.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
