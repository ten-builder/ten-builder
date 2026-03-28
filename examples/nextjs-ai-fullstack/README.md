# Next.js 풀스택 앱 AI 빌드 예제

> 바이브 코딩으로 Next.js 15 풀스택 앱을 처음부터 배포까지 — 프롬프트 설계, 반복 개선, 품질 관리

## 이 예제에서 배울 수 있는 것

- 바이브 코딩 방식으로 Next.js 15 풀스택 앱을 단계적으로 만드는 흐름
- AI에게 작업을 맡기기 전 스펙을 정리하는 프롬프트 패턴
- 인증, DB, API, 대시보드를 하나의 프로젝트에서 연결하는 구조
- AI가 생성한 코드를 검증하고 반복 개선하는 실전 루프

## 프로젝트 구조

```
nextjs-ai-fullstack/
├── CLAUDE.md                    # 프로젝트 규칙 + 컨텍스트
├── SPEC.md                      # 기능 스펙 문서
├── src/
│   ├── app/
│   │   ├── layout.tsx           # 루트 레이아웃
│   │   ├── page.tsx             # 랜딩 페이지
│   │   ├── (auth)/
│   │   │   ├── login/page.tsx   # 로그인
│   │   │   └── signup/page.tsx  # 회원가입
│   │   ├── dashboard/
│   │   │   ├── page.tsx         # 대시보드 메인
│   │   │   └── settings/page.tsx
│   │   └── api/
│   │       ├── auth/[...nextauth]/route.ts
│   │       └── tasks/route.ts   # CRUD API
│   ├── components/
│   │   ├── ui/                  # 공통 UI 컴포넌트
│   │   ├── TaskBoard.tsx        # 태스크 보드
│   │   └── StatsCard.tsx        # 통계 카드
│   ├── lib/
│   │   ├── db.ts                # Prisma 클라이언트
│   │   ├── auth.ts              # NextAuth 설정
│   │   └── validations.ts       # Zod 스키마
│   └── types/
│       └── index.ts             # 공유 타입
├── prisma/
│   └── schema.prisma            # DB 스키마
├── __tests__/
│   ├── api/tasks.test.ts
│   └── components/TaskBoard.test.tsx
├── package.json
└── tsconfig.json
```

## 사전 준비

- Node.js 20+
- pnpm
- AI 코딩 도구 (Claude Code, Cursor, 또는 다른 에이전트)
- PostgreSQL (로컬 또는 Supabase/Neon)

## Phase 1: 스펙 먼저, 코드는 나중에

바이브 코딩에서 가장 중요한 건 **코드를 쓰기 전에 뭘 만들지 정리하는 것**이에요.

### SPEC.md 작성

```markdown
# Task Dashboard — 기능 스펙

## 개요
개인 태스크 관리 대시보드. 할 일을 등록하고 상태별로 관리.

## 핵심 기능
1. 이메일/비밀번호 로그인 (NextAuth)
2. 태스크 CRUD (생성, 조회, 수정, 삭제)
3. 태스크 상태: todo → in_progress → done
4. 대시보드: 상태별 카운트, 최근 활동

## 기술 스택
- Next.js 15 (App Router)
- TypeScript strict mode
- Prisma + PostgreSQL
- NextAuth v5
- Tailwind CSS v4
- Vitest + Testing Library

## 제약 조건
- Server Component 기본, Client는 필요할 때만
- API Route Handler 사용 (pages/api 아님)
- 모든 입력은 Zod로 검증
```

이 스펙 문서를 CLAUDE.md와 함께 프로젝트 루트에 두면, AI가 전체 맥락을 파악한 상태에서 작업해요.

### CLAUDE.md 설정

```markdown
# CLAUDE.md

## Project
- Next.js 15 (App Router) + TypeScript strict
- Prisma + PostgreSQL
- NextAuth v5 (credentials provider)
- Tailwind CSS v4
- pnpm

## Architecture
- Server Components 기본
- Client Components는 "use client" 명시
- API: src/app/api/ Route Handlers
- DB: Prisma ORM (src/lib/db.ts)
- Auth: NextAuth (src/lib/auth.ts)
- Validation: Zod (src/lib/validations.ts)

## Conventions
- 컴포넌트 파일명: PascalCase
- API 응답: { data, error, message } 형태
- 에러 핸들링: try/catch + NextResponse
- 테스트: __tests__/ 디렉토리, *.test.ts(x)

## Commands
- pnpm dev — 개발 서버
- pnpm build — 빌드
- pnpm test — Vitest 실행
- pnpm db:push — Prisma 스키마 동기화
- pnpm db:studio — Prisma Studio
```

## Phase 2: 프로젝트 초기 셋업

### 프롬프트 1: 프로젝트 생성

```
Next.js 15 프로젝트를 만들어줘. TypeScript strict, Tailwind, App Router, src 디렉토리 구조.
pnpm 패키지 매니저 사용. eslint 설정 포함.
```

```bash
pnpm create next-app@latest task-dashboard \
  --typescript --tailwind --app --src-dir \
  --use-pnpm
```

### 프롬프트 2: 의존성 추가

```
Prisma, NextAuth v5, Zod, Vitest, Testing Library를 설치해줘.
prisma init도 실행해서 기본 설정 만들어줘.
```

```bash
# 핵심 의존성
pnpm add @prisma/client next-auth@beta zod
pnpm add -D prisma vitest @vitejs/plugin-react \
  @testing-library/react @testing-library/jest-dom

# Prisma 초기화
pnpm prisma init
```

### 프롬프트 3: DB 스키마 정의

```
SPEC.md를 참고해서 Prisma 스키마를 만들어줘.
User, Task 모델이 필요해. Task는 User에 연결.
status는 enum으로 TODO, IN_PROGRESS, DONE.
```

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum TaskStatus {
  TODO
  IN_PROGRESS
  DONE
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  password  String
  name      String?
  tasks     Task[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Task {
  id          String     @id @default(cuid())
  title       String
  description String?
  status      TaskStatus @default(TODO)
  userId      String
  user        User       @relation(fields: [userId], references: [id])
  createdAt   DateTime   @default(now())
  updatedAt   DateTime   @updatedAt

  @@index([userId])
  @@index([status])
}
```

## Phase 3: 인증 구현

### 프롬프트 4: NextAuth 설정

```
NextAuth v5로 이메일/비밀번호 인증을 구현해줘.
src/lib/auth.ts에 설정, 회원가입은 API 라우트로 별도 구현.
비밀번호는 bcryptjs로 해시.
```

**핵심 코드 — `src/lib/auth.ts`:**

```typescript
import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import { PrismaAdapter } from "@auth/prisma-adapter";
import bcrypt from "bcryptjs";
import { db } from "./db";

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(db),
  providers: [
    Credentials({
      credentials: {
        email: { type: "email" },
        password: { type: "password" },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null;
        }

        const user = await db.user.findUnique({
          where: { email: credentials.email as string },
        });

        if (!user) return null;

        const isValid = await bcrypt.compare(
          credentials.password as string,
          user.password
        );

        return isValid ? { id: user.id, email: user.email, name: user.name } : null;
      },
    }),
  ],
  session: { strategy: "jwt" },
  pages: {
    signIn: "/login",
  },
});
```

**왜 이렇게 했나요?**

- Credentials Provider로 자체 인증을 구현하면 외부 OAuth 없이도 빠르게 작동해요
- JWT 세션은 DB 조회 없이 인증 상태를 확인할 수 있어서 Server Component에서 빠르게 사용 가능
- 비밀번호 해시는 bcryptjs — 순수 JS 구현이라 서버리스 환경에서도 문제없어요

## Phase 4: 태스크 CRUD API

### 프롬프트 5: API Route Handler

```
태스크 CRUD API를 만들어줘. Route Handler로 구현.
인증된 사용자만 자기 태스크에 접근 가능.
모든 입력은 Zod로 검증. GET은 페이지네이션 지원.
```

**핵심 코드 — `src/app/api/tasks/route.ts`:**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { createTaskSchema, taskQuerySchema } from "@/lib/validations";

export async function GET(req: NextRequest) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const params = Object.fromEntries(req.nextUrl.searchParams);
  const query = taskQuerySchema.parse(params);

  const [tasks, total] = await Promise.all([
    db.task.findMany({
      where: {
        userId: session.user.id,
        ...(query.status && { status: query.status }),
      },
      orderBy: { createdAt: "desc" },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    }),
    db.task.count({
      where: { userId: session.user.id },
    }),
  ]);

  return NextResponse.json({
    data: tasks,
    meta: { total, page: query.page, limit: query.limit },
  });
}

export async function POST(req: NextRequest) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await req.json();
  const data = createTaskSchema.parse(body);

  const task = await db.task.create({
    data: { ...data, userId: session.user.id },
  });

  return NextResponse.json({ data: task }, { status: 201 });
}
```

**Zod 검증 스키마 — `src/lib/validations.ts`:**

```typescript
import { z } from "zod";

export const createTaskSchema = z.object({
  title: z.string().min(1).max(200),
  description: z.string().max(2000).optional(),
});

export const updateTaskSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  description: z.string().max(2000).optional(),
  status: z.enum(["TODO", "IN_PROGRESS", "DONE"]).optional(),
});

export const taskQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  status: z.enum(["TODO", "IN_PROGRESS", "DONE"]).optional(),
});
```

## Phase 5: 대시보드 UI

### 프롬프트 6: 대시보드 컴포넌트

```
태스크 대시보드 페이지를 만들어줘. Server Component로 데이터 페칭.
상단에 상태별 카운트 카드 3개, 아래에 태스크 리스트.
태스크 상태 변경은 Client Component로 구현.
```

**Server Component — `src/app/dashboard/page.tsx`:**

```tsx
import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { redirect } from "next/navigation";
import { StatsCard } from "@/components/StatsCard";
import { TaskBoard } from "@/components/TaskBoard";

export default async function DashboardPage() {
  const session = await auth();
  if (!session?.user?.id) redirect("/login");

  const [tasks, stats] = await Promise.all([
    db.task.findMany({
      where: { userId: session.user.id },
      orderBy: { updatedAt: "desc" },
    }),
    db.task.groupBy({
      by: ["status"],
      where: { userId: session.user.id },
      _count: true,
    }),
  ]);

  const statMap = Object.fromEntries(
    stats.map((s) => [s.status, s._count])
  );

  return (
    <main className="max-w-6xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">대시보드</h1>

      <div className="grid grid-cols-3 gap-4 mb-8">
        <StatsCard label="할 일" count={statMap.TODO ?? 0} color="blue" />
        <StatsCard label="진행 중" count={statMap.IN_PROGRESS ?? 0} color="yellow" />
        <StatsCard label="완료" count={statMap.DONE ?? 0} color="green" />
      </div>

      <TaskBoard initialTasks={tasks} />
    </main>
  );
}
```

**Client Component — `src/components/TaskBoard.tsx`:**

```tsx
"use client";

import { useState, useTransition } from "react";
import type { Task, TaskStatus } from "@prisma/client";

interface TaskBoardProps {
  initialTasks: Task[];
}

export function TaskBoard({ initialTasks }: TaskBoardProps) {
  const [tasks, setTasks] = useState(initialTasks);
  const [isPending, startTransition] = useTransition();

  const updateStatus = async (taskId: string, status: TaskStatus) => {
    startTransition(async () => {
      const res = await fetch(`/api/tasks/${taskId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status }),
      });

      if (res.ok) {
        const { data } = await res.json();
        setTasks((prev) =>
          prev.map((t) => (t.id === taskId ? data : t))
        );
      }
    });
  };

  const columns: { status: TaskStatus; label: string }[] = [
    { status: "TODO", label: "할 일" },
    { status: "IN_PROGRESS", label: "진행 중" },
    { status: "DONE", label: "완료" },
  ];

  return (
    <div className="grid grid-cols-3 gap-6">
      {columns.map(({ status, label }) => (
        <div key={status} className="bg-gray-50 rounded-lg p-4">
          <h2 className="font-semibold mb-4">{label}</h2>
          <div className="space-y-3">
            {tasks
              .filter((t) => t.status === status)
              .map((task) => (
                <div key={task.id} className="bg-white p-3 rounded shadow-sm">
                  <p className="font-medium">{task.title}</p>
                  {task.description && (
                    <p className="text-sm text-gray-500 mt-1">
                      {task.description}
                    </p>
                  )}
                  <select
                    className="mt-2 text-sm border rounded px-2 py-1"
                    value={task.status}
                    onChange={(e) =>
                      updateStatus(task.id, e.target.value as TaskStatus)
                    }
                    disabled={isPending}
                  >
                    <option value="TODO">할 일</option>
                    <option value="IN_PROGRESS">진행 중</option>
                    <option value="DONE">완료</option>
                  </select>
                </div>
              ))}
          </div>
        </div>
      ))}
    </div>
  );
}
```

## Phase 6: 테스트 작성

### 프롬프트 7: 테스트 코드

```
태스크 API와 TaskBoard 컴포넌트 테스트를 작성해줘.
API는 인증 미들웨어 모킹 포함. 컴포넌트는 렌더링 + 상호작용 테스트.
```

```typescript
// __tests__/api/tasks.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";

// auth 모킹
vi.mock("@/lib/auth", () => ({
  auth: vi.fn().mockResolvedValue({
    user: { id: "user-1", email: "test@test.com" },
  }),
}));

describe("POST /api/tasks", () => {
  it("유효한 입력으로 태스크를 생성한다", async () => {
    const { POST } = await import("@/app/api/tasks/route");

    const req = new Request("http://localhost/api/tasks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: "테스트 태스크",
        description: "설명",
      }),
    });

    const res = await POST(req as any);
    const { data } = await res.json();

    expect(res.status).toBe(201);
    expect(data.title).toBe("테스트 태스크");
    expect(data.status).toBe("TODO");
  });

  it("빈 제목이면 400을 반환한다", async () => {
    const { POST } = await import("@/app/api/tasks/route");

    const req = new Request("http://localhost/api/tasks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "" }),
    });

    const res = await POST(req as any);
    expect(res.status).toBe(400);
  });
});
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 새 API 엔드포인트 | `태스크 검색 API를 만들어줘. title 키워드 검색 + status 필터. Zod 검증 포함` |
| 에러 핸들링 | `API 라우트에 일관된 에러 핸들링 미들웨어를 추가해줘. Zod 에러는 400, 인증 에러는 401` |
| 성능 최적화 | `대시보드 페이지의 DB 쿼리를 최적화해줘. N+1 문제가 있는지 확인하고 수정` |
| UI 개선 | `TaskBoard에 드래그 앤 드롭 기능을 추가해줘. @hello-pangea/dnd 사용` |
| 테스트 보강 | `TaskBoard 컴포넌트의 상태 변경 테스트를 추가해줘. 성공/실패 케이스 포함` |

## 반복 개선 패턴

바이브 코딩의 핵심은 **한 번에 완성하려 하지 않는 것**이에요.

```
1회차: "기본 CRUD 동작하게 만들어줘"
  → 최소 기능 확인

2회차: "입력 검증이랑 에러 핸들링 추가해줘"
  → 안정성 확보

3회차: "로딩 상태랑 에러 UI 처리해줘"
  → 사용자 경험 개선

4회차: "성능 이슈 있는지 확인하고 최적화해줘"
  → 품질 향상
```

각 회차에서 AI가 생성한 코드를 직접 실행해보고, 문제가 있으면 구체적으로 알려주는 게 효과적이에요.

## 배포

```bash
# Vercel 배포
pnpm vercel

# 환경 변수 설정
# DATABASE_URL, NEXTAUTH_SECRET, NEXTAUTH_URL
```

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
