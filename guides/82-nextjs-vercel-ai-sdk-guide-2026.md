# Next.js + Vercel AI SDK 풀스택 AI 앱 개발 가이드 2026

> Next.js App Router, Vercel AI SDK, Convex, Clerk을 조합해 AI 기능이 내장된 풀스택 앱을 AI 에이전트와 함께 구축하는 실전 가이드

---

## 이 스택을 쓰는 이유

2026년 현재 AI 앱을 빠르게 만드는 표준 스택이 굳어졌습니다.

| 레이어 | 도구 | 역할 |
|--------|------|------|
| 웹 | Next.js 16 (App Router) | 라우팅, 서버 컴포넌트, API |
| AI | Vercel AI SDK 6 | 스트리밍, 툴 호출, 멀티 프로바이더 |
| 데이터 | Convex | 실시간 DB, 서버 함수, 스케줄링 |
| 인증 | Clerk | 유저 관리, 미들웨어 통합 |
| 스타일 | Tailwind CSS | 빠른 UI 구성 |

LangChain(101.2 kB) 대신 Vercel AI SDK(67.5 kB)를 쓰는 이유는 단순합니다. 엣지 런타임 최적화, React Server Components 네이티브 지원, `useChat`/`streamText`/`generateObject` 세 가지 API로 대부분의 AI 패턴을 커버합니다.

---

## 1. 프로젝트 초기 설정

### 1-1. 스캐폴딩

```bash
npx create-next-app@latest my-ai-app \
  --typescript --tailwind --app --src-dir

cd my-ai-app
npm install ai @ai-sdk/anthropic convex @clerk/nextjs
```

### 1-2. 환경 변수

```bash
# .env.local
ANTHROPIC_API_KEY=sk-ant-...
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_...
CLERK_SECRET_KEY=sk_...
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
NEXT_PUBLIC_CONVEX_URL=https://your-project.convex.cloud
```

### 1-3. Clerk 미들웨어 설정

```typescript
// middleware.ts
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'

const isPublicRoute = createRouteMatcher(['/sign-in(.*)', '/sign-up(.*)', '/'])

export default clerkMiddleware(async (auth, request) => {
  if (!isPublicRoute(request)) {
    await auth.protect()
  }
})

export const config = {
  matcher: ['/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)', '/(api|trpc)(.*)'],
}
```

---

## 2. AI 채팅 라우트 구성

### 2-1. API 라우트 — 스트리밍 응답

```typescript
// app/api/chat/route.ts
import { anthropic } from '@ai-sdk/anthropic'
import { streamText, tool } from 'ai'
import { auth } from '@clerk/nextjs/server'
import { z } from 'zod'

export const runtime = 'edge'

export async function POST(req: Request) {
  const { userId } = await auth()
  if (!userId) return new Response('Unauthorized', { status: 401 })

  const { messages } = await req.json()

  const result = await streamText({
    model: anthropic('claude-sonnet-4-6'),
    system: '당신은 개발자를 돕는 AI 어시스턴트입니다.',
    messages,
    maxSteps: 5,
    tools: {
      searchDocs: tool({
        description: '문서에서 정보를 검색합니다',
        parameters: z.object({ query: z.string() }),
        execute: async ({ query }) => {
          // 실제 검색 로직
          return { results: [`${query}에 대한 검색 결과`] }
        },
      }),
    },
  })

  return result.toDataStreamResponse()
}
```

### 2-2. 클라이언트 — useChat 훅

```typescript
// app/chat/page.tsx
'use client'

import { useChat } from 'ai/react'

export default function ChatPage() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat',
    onToolCall: ({ toolCall }) => {
      // 툴 호출 중 UI 피드백
      console.log('툴 실행 중:', toolCall.toolName)
    },
  })

  return (
    <div className="flex flex-col h-screen max-w-2xl mx-auto p-4">
      <div className="flex-1 overflow-y-auto space-y-4">
        {messages.map((m) => (
          <div key={m.id} className={m.role === 'user' ? 'text-right' : 'text-left'}>
            {m.role === 'assistant' && m.toolInvocations && (
              <div className="text-xs text-gray-500 mb-1">
                {m.toolInvocations.map((t) => (
                  <span key={t.toolCallId}>🔧 {t.toolName}</span>
                ))}
              </div>
            )}
            <div className={`inline-block p-3 rounded-lg ${
              m.role === 'user' ? 'bg-blue-500 text-white' : 'bg-gray-100'
            }`}>
              {m.content}
            </div>
          </div>
        ))}
        {isLoading && <div className="text-gray-400">생각 중...</div>}
      </div>

      <form onSubmit={handleSubmit} className="flex gap-2 mt-4">
        <input
          value={input}
          onChange={handleInputChange}
          placeholder="메시지를 입력하세요..."
          className="flex-1 border rounded-lg p-2"
        />
        <button type="submit" className="bg-blue-500 text-white px-4 rounded-lg">전송</button>
      </form>
    </div>
  )
}
```

---

## 3. 구조화된 출력 — generateObject

단순 텍스트가 아닌 JSON 데이터가 필요할 때 `generateObject`를 씁니다.

```typescript
// app/api/analyze/route.ts
import { anthropic } from '@ai-sdk/anthropic'
import { generateObject } from 'ai'
import { z } from 'zod'

const CodeReviewSchema = z.object({
  summary: z.string(),
  issues: z.array(z.object({
    severity: z.enum(['critical', 'warning', 'info']),
    line: z.number().optional(),
    message: z.string(),
    suggestion: z.string(),
  })),
  score: z.number().min(0).max(100),
})

export async function POST(req: Request) {
  const { code } = await req.json()

  const { object } = await generateObject({
    model: anthropic('claude-sonnet-4-6'),
    schema: CodeReviewSchema,
    prompt: `다음 코드를 리뷰해 주세요:\n\n${code}`,
  })

  return Response.json(object)
}
```

**언제 쓰나요?**

| 상황 | 추천 API |
|------|----------|
| 실시간 채팅 | `streamText` + `useChat` |
| 폼 자동 완성 | `generateObject` + Zod |
| 파일 분석 리포트 | `generateObject` |
| 스트리밍 JSON | `streamObject` + `useObject` |

---

## 4. Convex 실시간 DB 연동

Convex는 WebSocket 기반 실시간 동기화를 제공합니다. 채팅 기록을 저장하고 모든 클라이언트에 즉시 반영하는 패턴입니다.

### 4-1. 스키마 정의

```typescript
// convex/schema.ts
import { defineSchema, defineTable } from 'convex/server'
import { v } from 'convex/values'

export default defineSchema({
  conversations: defineTable({
    userId: v.string(),
    title: v.string(),
    createdAt: v.number(),
  }).index('by_user', ['userId']),

  messages: defineTable({
    conversationId: v.id('conversations'),
    role: v.union(v.literal('user'), v.literal('assistant')),
    content: v.string(),
    createdAt: v.number(),
  }).index('by_conversation', ['conversationId']),
})
```

### 4-2. 쿼리와 뮤테이션

```typescript
// convex/messages.ts
import { query, mutation } from './_generated/server'
import { v } from 'convex/values'

export const list = query({
  args: { conversationId: v.id('conversations') },
  handler: async (ctx, { conversationId }) => {
    return ctx.db
      .query('messages')
      .withIndex('by_conversation', (q) => q.eq('conversationId', conversationId))
      .order('asc')
      .collect()
  },
})

export const add = mutation({
  args: {
    conversationId: v.id('conversations'),
    role: v.union(v.literal('user'), v.literal('assistant')),
    content: v.string(),
  },
  handler: async (ctx, args) => {
    return ctx.db.insert('messages', {
      ...args,
      createdAt: Date.now(),
    })
  },
})
```

---

## 5. Claude Code로 개발하는 법

AI 에이전트와 함께 이 스택을 구축할 때 효과적인 프롬프트 패턴입니다.

### CLAUDE.md 핵심 설정

```markdown
## 스택
- Next.js 16 App Router (src/ 디렉토리)
- Vercel AI SDK 6 (ai 패키지)
- Convex (실시간 DB)
- Clerk (인증)
- TypeScript strict mode

## 컨벤션
- API 라우트: edge runtime 기본
- 스트리밍: toDataStreamResponse() 사용
- 인증 체크: 모든 API 라우트 첫 줄
- Zod 스키마: generateObject와 항상 함께
```

### 태스크별 프롬프트 패턴

| 태스크 | 프롬프트 |
|--------|---------|
| AI 기능 추가 | "CLAUDE.md 스택 기준으로 [기능] API 라우트와 useChat 훅 연결하는 코드 작성해줘" |
| 스키마 생성 | "Convex 스키마에 [엔티티] 테이블 추가하고 쿼리/뮤테이션 만들어줘" |
| 인증 보호 | "이 페이지에 Clerk 인증 추가하고 미인증 시 /sign-in으로 리다이렉트" |
| 구조화 출력 | "Zod 스키마 정의하고 generateObject로 [데이터] 추출하는 라우트 만들어줘" |

---

## 6. 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 툴 호출 중 UI가 멈춰 보임 | `toolInvocations` 렌더링으로 진행 상태 표시 |
| Convex 쿼리 과다 호출 | `useQuery` 캐싱 활용, 조건부 쿼리 |
| 엣지 런타임에서 Node.js API 사용 | `runtime = 'nodejs'`로 변경 또는 호환 라이브러리 선택 |
| 스트림 중단 | `onError` 콜백 추가, 재시도 로직 구현 |
| Clerk + Convex 인증 불일치 | `useConvexAuth()`로 동기화 상태 확인 |

---

## 다음 단계

이 스택을 구축했다면 자연스럽게 연결되는 주제들입니다.

- **다중 모델 라우팅** → [workflows/ai-multi-model-routing.md](../workflows/ai-multi-model-routing.md)
- **E2E 테스트 자동화** → [workflows/ai-e2e-test-generation.md](../workflows/ai-e2e-test-generation.md)
- **프롬프트 버전 관리** → [claude-code/playbooks/54-prompt-version-control.md](../claude-code/playbooks/54-prompt-version-control.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) — AI 코딩 실전 팁을 매주 무료로 받아보세요.
