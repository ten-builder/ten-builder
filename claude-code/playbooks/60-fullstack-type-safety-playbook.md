# 플레이북 60: AI 에이전트 풀스택 타입 안전성 확보 플레이북

> TypeScript strict mode, Zod 런타임 검증, tRPC/GraphQL 타입 생성을 AI 에이전트로 자동화해서 타입 오류 0건을 달성하는 전략

## 소요 시간

30-60분 (코드베이스 규모에 따라 다름)

## 사전 준비

- TypeScript 4.0 이상 프로젝트
- Claude Code 또는 Cursor
- Node.js 패키지 매니저 (npm/pnpm/bun)
- 기존 TypeScript 프로젝트 (또는 신규 프로젝트)

---

## 왜 타입 안전성이 중요한가

AI 에이전트는 코드를 빠르게 생성하지만, 타입 제약 없이 작업하면 런타임 오류를 심는 경우가 많다. 2026년 기준 AI 코딩 도구 사용 팀의 공통 불만은 "생성된 코드는 돌아가는데 프로덕션에서 `undefined is not a function`이 터진다"는 것이다. 해결책은 간단하다. **AI가 작업하는 환경 자체를 타입 안전하게 만드는 것**.

타입 안전성 3계층:

1. **컴파일 타임**: TypeScript strict mode
2. **런타임**: Zod 스키마 검증
3. **API 경계**: tRPC 또는 GraphQL 코드젠

이 플레이북은 AI 에이전트에게 이 3계층을 단계별로 설정하도록 지시하는 방법을 다룬다.

---

## Step 1: TypeScript Strict Mode 활성화

### 1-1. 현재 타입 오류 현황 파악

```bash
# 현재 오류 수 확인
npx tsc --noEmit 2>&1 | tail -3
```

### 1-2. AI 에이전트에게 strict mode 활성화 지시

```
tsconfig.json에 strict mode를 단계적으로 활성화해줘.
한 번에 all-or-nothing이 아니라 아래 순서로 진행:
1. "strictNullChecks": true 먼저 적용
2. tsc --noEmit 실행해서 오류 목록 확인
3. 각 오류를 타입 좁히기(type narrowing)나 non-null assertion(!)이 아닌
   실제 로직 수정으로 해결
4. 오류 0개 확인 후 다음 옵션 추가
```

### 1-3. 추천 tsconfig.json 설정

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

**AI에게 피해야 할 패턴 명시하기:**

```
타입 오류를 수정할 때 다음은 사용하지 마:
- any 타입 캐스팅 (as any)
- non-null assertion (!)
- @ts-ignore / @ts-expect-error (기존 코드 유지 시만 허용)

대신:
- 타입 가드 함수 작성
- unknown 타입 후 타입 좁히기
- 유니온 타입과 discriminated union 활용
```

---

## Step 2: Zod 런타임 검증 통합

### 2-1. Zod 설치

```bash
# Zod v4 (2026년 기준 최신)
npm install zod@^4.0.0

# Zod v3를 쓰고 있다면 마이그레이션
# import { z } from 'zod'  →  변경 없이 사용 가능
# z.string().email()  →  z.email() (v4 변경)
```

### 2-2. 외부 데이터 입력점 식별

```bash
# AI 에이전트에게 입력점 찾기 지시
echo "이 코드베이스에서 외부 데이터가 들어오는 지점을 모두 찾아줘:
- API 응답 (fetch, axios)
- 폼 데이터 (req.body)
- 환경 변수 (process.env)
- 로컬 스토리지 / 쿠키
- URL 파라미터 / 쿼리스트링
각 지점에 Zod 스키마를 적용하는 코드를 작성해줘"
```

### 2-3. 핵심 Zod 패턴

**API 응답 검증:**

```typescript
import { z } from 'zod'

// 스키마 정의
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.email(),
  name: z.string().min(1),
  role: z.enum(['admin', 'user', 'guest']),
  createdAt: z.iso.datetime()
})

type User = z.infer<typeof UserSchema>

// API 응답 검증
async function fetchUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`)
  const raw = await res.json()
  return UserSchema.parse(raw)  // 타입 불일치 시 즉시 오류 발생
}
```

**환경 변수 안전 처리:**

```typescript
const EnvSchema = z.object({
  DATABASE_URL: z.string().url(),
  API_KEY: z.string().min(1),
  PORT: z.coerce.number().int().default(3000),
  NODE_ENV: z.enum(['development', 'production', 'test'])
})

// 앱 시작 시 한 번만 검증
export const env = EnvSchema.parse(process.env)
```

**폼 데이터 검증 (Next.js Server Actions):**

```typescript
const LoginSchema = z.object({
  email: z.email(),
  password: z.string().min(8)
})

export async function loginAction(formData: FormData) {
  const result = LoginSchema.safeParse({
    email: formData.get('email'),
    password: formData.get('password')
  })

  if (!result.success) {
    return { error: result.error.flatten().fieldErrors }
  }

  // result.data는 완전히 타입 안전
  return await authenticate(result.data)
}
```

### 2-4. AI 에이전트 지시 템플릿

```
이 프로젝트의 모든 fetch 호출에 Zod 검증을 추가해줘.
파일별로 처리:
1. 해당 파일의 응답 타입을 분석
2. Zod 스키마 작성 (기존 TypeScript 타입에서 자동 변환)
3. .parse() 또는 .safeParse()로 래핑
4. 기존 타입 선언은 z.infer<typeof Schema>로 교체
```

---

## Step 3: tRPC로 API 타입 공유

### 3-1. tRPC 설정 (풀스택 TypeScript 프로젝트)

```bash
npm install @trpc/server @trpc/client @trpc/next zod
```

```typescript
// server/trpc.ts
import { initTRPC } from '@trpc/server'
import { z } from 'zod'

const t = initTRPC.create()

export const router = t.router
export const publicProcedure = t.procedure

// 라우터 정의
export const appRouter = router({
  user: router({
    getById: publicProcedure
      .input(z.string().uuid())
      .query(async ({ input }) => {
        return await db.user.findUnique({ where: { id: input } })
      }),

    create: publicProcedure
      .input(z.object({
        email: z.email(),
        name: z.string().min(1)
      }))
      .mutation(async ({ input }) => {
        return await db.user.create({ data: input })
      })
  })
})

export type AppRouter = typeof appRouter
```

```typescript
// client/trpc.ts - 타입이 자동으로 공유됨
import { createTRPCNext } from '@trpc/next'
import type { AppRouter } from '../server/trpc'

export const trpc = createTRPCNext<AppRouter>({ ... })

// 사용
const { data } = trpc.user.getById.useQuery('some-uuid')
// data는 User | undefined로 자동 타입 추론
```

### 3-2. GraphQL 코드젠 대안

REST API나 GraphQL을 유지해야 하는 경우:

```bash
# GraphQL 코드젠 설치
npm install -D @graphql-codegen/cli @graphql-codegen/typescript

# codegen.ts 설정
cat > codegen.ts << 'EOF'
import type { CodegenConfig } from '@graphql-codegen/cli'

const config: CodegenConfig = {
  schema: 'http://localhost:4000/graphql',
  documents: ['src/**/*.{ts,tsx}'],
  generates: {
    './src/gql/': { preset: 'client' }
  }
}
export default config
EOF

# 타입 생성
npx graphql-codegen
```

---

## Step 4: AI 에이전트 CLAUDE.md 설정

```markdown
## 타입 안전성 규칙

### 필수 사항
- 모든 외부 데이터(API 응답, 폼, env)는 반드시 Zod로 검증
- any 타입 사용 금지 (unknown + 타입 가드로 대체)
- API 핸들러 입출력은 Zod 스키마로 정의 후 z.infer 사용

### 금지 사항
- as any, as unknown as T 패턴
- non-null assertion (!) 남용
- @ts-ignore (레거시 코드 주석 처리 시만 허용)

### 선호 패턴
- discriminated union (type: 'success' | 'error')
- const assertion (as const)
- satisfies 키워드 활용
```

---

## 체크리스트

- [ ] `tsconfig.json`에 `"strict": true` 설정 완료
- [ ] `tsc --noEmit` 오류 0건 확인
- [ ] 모든 API 응답에 Zod 스키마 적용
- [ ] 환경 변수 Zod 검증 추가
- [ ] 폼 입력 Zod 검증 추가
- [ ] tRPC 또는 GraphQL 코드젠으로 API 타입 자동화
- [ ] CLAUDE.md에 타입 안전성 규칙 추가
- [ ] CI에 `tsc --noEmit` 스텝 추가

---

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| `z.string().email()`이 v4에서 안 됨 | `z.email()`로 교체 |
| Zod 검증 실패 시 앱 크래시 | `.safeParse()` 사용 후 오류 처리 |
| tRPC 타입이 클라이언트에 반영 안 됨 | `AppRouter` 타입을 `type import`로 가져올 것 |
| `noUncheckedIndexedAccess` 적용 후 오류 폭발 | 배열 접근 시 `arr[0]` → `arr.at(0)` 패턴 사용 |
| 제네릭 컴포넌트에서 타입 오류 | `<T extends object>` 대신 `<T,>` 쉼표 추가 (JSX 파싱 충돌 방지) |

---

## 다음 단계

→ [플레이북 57: 컨텍스트 오염 방지](../claude-code/playbooks/57-context-contamination-prevention.md)
→ [Zod 런타임 검증 치트시트](../cheatsheets/ai-coding-mistake-patterns-cheatsheet.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
