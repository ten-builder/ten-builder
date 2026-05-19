# 플레이북 69: AI 에이전트 풀스택 TypeScript 프로젝트 초기화

> Next.js App Router + tRPC + Prisma + Zod 스택을 AI 에이전트와 함께 처음부터 설정하는 플레이북 — 타입 안전성, 테스트, CI/CD까지 한 번에

## 소요 시간

60-90분 (초기 설정 전체)

## 사전 준비

- Claude Code v2.1.120 이상 설치
- Node.js 20+ 및 pnpm 9+ 설치
- GitHub 레포지터리 생성 (빈 레포)
- PostgreSQL 또는 PlanetScale/Neon 연결 정보

## 왜 이 스택인가

`Next.js + tRPC + Prisma + Zod` 조합은 2026년 기준 TypeScript 풀스택 개발에서 가장 검증된 선택이다.

| 레이어 | 도구 | 역할 |
|--------|------|------|
| 프레임워크 | Next.js App Router | 풀스택 렌더링, API Routes |
| API 계층 | tRPC | 타입 안전 RPC, 자동 추론 |
| ORM | Prisma | 타입 안전 DB 쿼리, 마이그레이션 |
| 검증 | Zod | 런타임 스키마 검증, 타입 추론 |
| 테스트 | Vitest + Playwright | 유닛/E2E 자동화 |

AI 에이전트와 이 스택을 함께 쓸 때의 진짜 강점은 **타입이 에이전트의 가이드 역할**을 한다는 점이다. Prisma 스키마를 알려주면 에이전트가 타입 오류 없는 쿼리를 즉시 생성하고, Zod 스키마를 정의해두면 입력값 검증 코드를 반복 없이 재사용한다.

## Step 1: 프로젝트 스캐폴딩

먼저 빈 레포를 클론하고 Next.js를 초기화한다:

```bash
# 레포 클론
git clone https://github.com/{org}/{repo}.git && cd {repo}

# Next.js 설치 (App Router 선택, TypeScript strict 활성화)
npx create-next-app@latest . --typescript --tailwind --eslint \
  --app --src-dir --import-alias "@/*"
```

`tsconfig.json`에서 strict 모드를 확인한다:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

`exactOptionalPropertyTypes`와 `noUncheckedIndexedAccess`는 기본 strict에 포함되지 않지만, AI 에이전트가 더 안전한 코드를 생성하도록 유도한다.

## Step 2: tRPC 설정

```bash
pnpm add @trpc/server @trpc/client @trpc/next @trpc/react-query \
  @tanstack/react-query superjson zod
```

tRPC 라우터 구조:

```
src/
  server/
    trpc.ts          # 기본 프로시저 정의
    routers/
      _app.ts        # 루트 라우터
      user.ts        # 도메인별 라우터 예시
  app/
    api/
      trpc/
        [trpc]/
          route.ts   # Next.js App Router 핸들러
```

기본 프로시저 설정(`src/server/trpc.ts`):

```typescript
import { initTRPC, TRPCError } from '@trpc/server';
import superjson from 'superjson';
import { z } from 'zod';
import { getServerSession } from 'next-auth';

const t = initTRPC.context<{ session: Awaited<ReturnType<typeof getServerSession>> }>().create({
  transformer: superjson,
});

export const router = t.router;
export const publicProcedure = t.procedure;
export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.session?.user) throw new TRPCError({ code: 'UNAUTHORIZED' });
  return next({ ctx: { session: ctx.session } });
});
```

## Step 3: Prisma 스키마 설계

```bash
pnpm add prisma @prisma/client
npx prisma init --datasource-provider postgresql
```

기본 스키마 패턴(`prisma/schema.prisma`):

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  posts     Post[]
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

AI 에이전트에게 스키마를 먼저 보여주면 이후 라우터/컴포넌트 생성 품질이 크게 달라진다. CLAUDE.md에 스키마 경로를 명시하는 이유다.

## Step 4: Zod 스키마 레이어

tRPC 입력값 검증용 공유 스키마를 별도 파일로 분리한다:

```
src/
  shared/
    schemas/
      user.ts
      post.ts
      common.ts
```

공유 스키마 예시(`src/shared/schemas/user.ts`):

```typescript
import { z } from 'zod';

export const CreateUserSchema = z.object({
  email: z.string().email('올바른 이메일 형식이 아닙니다'),
  name: z.string().min(2, '이름은 2자 이상 입력해주세요').max(50),
});

export const UpdateUserSchema = CreateUserSchema.partial().extend({
  id: z.string().cuid(),
});

export type CreateUserInput = z.infer<typeof CreateUserSchema>;
export type UpdateUserInput = z.infer<typeof UpdateUserSchema>;
```

tRPC 라우터에서 바로 재사용:

```typescript
import { CreateUserSchema } from '@/shared/schemas/user';

export const userRouter = router({
  create: publicProcedure
    .input(CreateUserSchema)
    .mutation(async ({ input }) => {
      return prisma.user.create({ data: input });
    }),
});
```

## Step 5: CLAUDE.md 초안 작성

프로젝트 루트에 CLAUDE.md를 작성한다. 이 파일이 AI 에이전트의 첫 번째 가이드다:

```markdown
# 프로젝트 컨텍스트

## 기술 스택
- Next.js 15 App Router (src/ 디렉토리 구조)
- tRPC v11 + @tanstack/react-query
- Prisma 6 (PostgreSQL)
- Zod v3 (공유 스키마: src/shared/schemas/)
- Tailwind CSS v4
- Vitest (유닛), Playwright (E2E)

## 디렉토리 구조
- `src/app/` — Next.js App Router 라우트
- `src/server/` — tRPC 라우터, Prisma 클라이언트
- `src/shared/` — Zod 스키마, 공유 타입
- `src/components/` — React 컴포넌트
- `prisma/` — 스키마, 마이그레이션

## 주요 명령어
- `pnpm dev` — 개발 서버
- `pnpm test` — Vitest 유닛 테스트
- `pnpm test:e2e` — Playwright E2E
- `pnpm db:push` — Prisma 스키마 반영
- `pnpm db:studio` — Prisma Studio

## 코딩 규칙
- 모든 입력값은 Zod 스키마로 검증
- DB 접근은 반드시 Prisma 클라이언트 사용
- 서버 컴포넌트 기본, 필요 시 'use client'
- TypeScript strict 모드 준수
```

## Step 6: 테스트 환경 구성

```bash
# Vitest 설치
pnpm add -D vitest @vitejs/plugin-react @testing-library/react \
  @testing-library/jest-dom jsdom

# Playwright 설치
pnpm add -D @playwright/test
npx playwright install --with-deps chromium
```

`vitest.config.ts`:

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
  },
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
});
```

`package.json` 스크립트:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui"
  }
}
```

## Step 7: GitHub Actions CI/CD

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm

      - run: pnpm install --frozen-lockfile

      - name: Prisma 마이그레이션
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
        run: npx prisma migrate deploy

      - name: 타입 체크
        run: pnpm tsc --noEmit

      - name: 유닛 테스트
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
        run: pnpm test

      - name: E2E 테스트
        run: pnpm test:e2e
```

## 체크리스트

- [ ] `tsconfig.json`에 `strict: true`, `noUncheckedIndexedAccess: true` 확인
- [ ] Prisma 스키마 초안 작성 및 `prisma db push` 완료
- [ ] tRPC 루트 라우터 + 첫 번째 도메인 라우터 생성
- [ ] `src/shared/schemas/` 디렉토리에 공유 Zod 스키마 분리
- [ ] CLAUDE.md에 스택, 디렉토리, 주요 명령어 작성
- [ ] Vitest 설정 + 예시 테스트 1개 통과 확인
- [ ] Playwright 설치 + 헬스체크 E2E 1개 통과 확인
- [ ] GitHub Actions CI 파이프라인 첫 실행 성공

## 다음 단계

→ [플레이북 60: AI 에이전트 풀스택 타입 안전성 확보](./60-fullstack-type-safety-playbook.md)
→ [플레이북 55: AI 에이전트 도입 실패 패턴](./55-ai-agent-adoption-failure-patterns.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
