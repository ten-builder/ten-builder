# Express.js + AI API 개발 예제

> AI 코딩 도구(Claude Code, Cursor, Copilot)로 Express.js REST API를 처음부터 만드는 실전 가이드

## 🎯 이런 분께 추천

- Express.js로 REST API를 만들어보고 싶은 백엔드 입문자
- AI 코딩 도구를 실전 프로젝트에 활용하고 싶은 개발자
- 프로토타입을 빠르게 만들고 싶은 사이드 프로젝트 빌더
- TDD와 API 문서화까지 AI로 자동화하고 싶은 분

## ⚡ 빠른 시작

```bash
# 1. 프로젝트 생성
mkdir express-api && cd express-api
npm init -y

# 2. 핵심 패키지 설치
npm install express cors helmet morgan
npm install -D typescript @types/express @types/node ts-node nodemon

# 3. AI 코딩 도구에 첫 프롬프트
# "Express.js + TypeScript 프로젝트를 세팅해줘. 
#  src/index.ts를 진입점으로, nodemon으로 개발 서버 실행하도록 설정해줘."
```

## 이 예제에서 배울 수 있는 것

- Express.js REST API를 AI와 함께 단계적으로 구축하는 워크플로우
- 각 단계에서 사용할 수 있는 실전 AI 프롬프트 패턴
- 미들웨어, 입력 검증, 에러 핸들링, 테스트, API 문서화까지 전체 과정

## 프로젝트 구조

```
express-api-ai/
├── src/
│   ├── index.ts              # 앱 진입점
│   ├── app.ts                # Express 앱 설정
│   ├── routes/
│   │   ├── index.ts          # 라우트 통합
│   │   ├── posts.ts          # 포스트 CRUD 라우트
│   │   └── users.ts          # 유저 라우트
│   ├── middleware/
│   │   ├── errorHandler.ts   # 글로벌 에러 핸들러
│   │   ├── validate.ts       # 입력 검증 미들웨어
│   │   └── logger.ts         # 요청 로깅
│   ├── models/
│   │   └── post.ts           # 데이터 모델
│   └── schemas/
│       └── post.schema.ts    # Zod 검증 스키마
├── tests/
│   ├── routes/
│   │   └── posts.test.ts     # 라우트 통합 테스트
│   └── setup.ts              # 테스트 설정
├── package.json
├── tsconfig.json
└── swagger.json              # API 문서
```

## 단계별 가이드

### Step 1: 프로젝트 초기화 — AI에게 scaffold 요청

AI에게 프로젝트 전체 뼈대를 잡아달라고 요청해요.

**사용 프롬프트:**

```
Express.js + TypeScript 프로젝트를 초기화해줘.
- src/index.ts를 진입점으로 설정
- tsconfig.json 생성 (strict 모드, ES2022 타겟)
- nodemon.json으로 개발 서버 자동 재시작
- package.json scripts: dev, build, start, test
```

**생성 결과:**

```json
// package.json
{
  "name": "express-api-ai",
  "version": "1.0.0",
  "scripts": {
    "dev": "nodemon",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "jest --coverage"
  },
  "dependencies": {
    "express": "^4.21.0",
    "cors": "^2.8.5",
    "helmet": "^8.0.0",
    "morgan": "^1.10.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "typescript": "^5.6.0",
    "@types/express": "^5.0.0",
    "@types/node": "^22.0.0",
    "ts-node": "^10.9.0",
    "nodemon": "^3.1.0",
    "jest": "^29.7.0",
    "supertest": "^7.0.0",
    "@types/jest": "^29.5.0",
    "@types/supertest": "^6.0.0",
    "ts-jest": "^29.2.0"
  }
}
```

```typescript
// src/index.ts
import app from "./app"

const PORT = process.env.PORT || 3000

app.listen(PORT, () => {
  console.log(\`🚀 서버가 http://localhost:${PORT}에서 실행 중입니다\`)
})
```

---

### Step 2: 라우팅 설계 — RESTful endpoints

REST 원칙에 맞는 라우트를 AI에게 설계하도록 요청해요.

**사용 프롬프트:**

```
블로그 포스트 CRUD API 라우트를 만들어줘.
- GET /api/posts — 전체 목록 (pagination 지원)
- GET /api/posts/:id — 단건 조회
- POST /api/posts — 생성
- PUT /api/posts/:id — 수정
- DELETE /api/posts/:id — 삭제
- src/routes/posts.ts에 Router로 분리해줘
```

**생성 결과:**

```typescript
// src/routes/posts.ts
import { Router, Request, Response } from "express"

const router = Router()

interface Post {
  id: string
  title: string
  content: string
  author: string
  createdAt: Date
  updatedAt: Date
}

// 임시 인메모리 저장소
const posts: Post[] = []

// GET /api/posts
router.get("/", (req: Request, res: Response) => {
  const page = parseInt(req.query.page as string) || 1
  const limit = parseInt(req.query.limit as string) || 10
  const start = (page - 1) * limit
  const paginatedPosts = posts.slice(start, start + limit)

  res.json({
    data: paginatedPosts,
    pagination: {
      page,
      limit,
      total: posts.length,
      totalPages: Math.ceil(posts.length / limit),
    },
  })
})

// GET /api/posts/:id
router.get("/:id", (req: Request, res: Response) => {
  const post = posts.find((p) => p.id === req.params.id)
  if (!post) {
    return res.status(404).json({ error: "포스트를 찾을 수 없습니다" })
  }
  res.json(post)
})

// POST /api/posts
router.post("/", (req: Request, res: Response) => {
  const { title, content, author } = req.body
  const newPost: Post = {
    id: crypto.randomUUID(),
    title,
    content,
    author,
    createdAt: new Date(),
    updatedAt: new Date(),
  }
  posts.push(newPost)
  res.status(201).json(newPost)
})

// PUT /api/posts/:id
router.put("/:id", (req: Request, res: Response) => {
  const index = posts.findIndex((p) => p.id === req.params.id)
  if (index === -1) {
    return res.status(404).json({ error: "포스트를 찾을 수 없습니다" })
  }
  posts[index] = { ...posts[index], ...req.body, updatedAt: new Date() }
  res.json(posts[index])
})

// DELETE /api/posts/:id
router.delete("/:id", (req: Request, res: Response) => {
  const index = posts.findIndex((p) => p.id === req.params.id)
  if (index === -1) {
    return res.status(404).json({ error: "포스트를 찾을 수 없습니다" })
  }
  posts.splice(index, 1)
  res.status(204).send()
})

export default router
```

---

### Step 3: 미들웨어 설정 — CORS, Error Handling, Logging

**사용 프롬프트:**

```
Express 앱에 미들웨어를 설정해줘.
- CORS (개발 환경에서 모든 origin 허용)
- Helmet (보안 헤더)
- Morgan (요청 로깅, dev 포맷)
- JSON body parser (100kb 제한)
- src/app.ts에 설정해줘
```

**생성 결과:**

```typescript
// src/app.ts
import express from "express"
import cors from "cors"
import helmet from "helmet"
import morgan from "morgan"
import postRoutes from "./routes/posts"
import { errorHandler } from "./middleware/errorHandler"

const app = express()

// 보안 미들웨어
app.use(helmet())
app.use(cors())

// 로깅
app.use(morgan("dev"))

// Body 파싱
app.use(express.json({ limit: "100kb" }))

// 라우트
app.use("/api/posts", postRoutes)

// 헬스체크
app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() })
})

// 글로벌 에러 핸들러 (라우트 뒤에 위치)
app.use(errorHandler)

export default app
```

---

### Step 4: 데이터 모델링 — in-memory에서 DB로

처음에는 배열로 시작하고, 나중에 DB로 마이그레이션하는 전략이에요.

**사용 프롬프트:**

```
posts 라우트의 인메모리 배열을 분리된 모델 레이어로 리팩토링해줘.
- src/models/post.ts에 PostModel 클래스를 만들어줘
- findAll, findById, create, update, delete 메서드
- 나중에 DB로 교체할 수 있도록 인터페이스 기반으로 설계
```

**생성 결과:**

```typescript
// src/models/post.ts
export interface Post {
  id: string
  title: string
  content: string
  author: string
  createdAt: Date
  updatedAt: Date
}

export interface CreatePostInput {
  title: string
  content: string
  author: string
}

export interface UpdatePostInput {
  title?: string
  content?: string
}

// Repository 인터페이스 — DB 교체 시 이것만 구현하면 됨
export interface PostRepository {
  findAll(page: number, limit: number): Promise<{ data: Post[]; total: number }>
  findById(id: string): Promise<Post | null>
  create(input: CreatePostInput): Promise<Post>
  update(id: string, input: UpdatePostInput): Promise<Post | null>
  delete(id: string): Promise<boolean>
}

// 인메모리 구현
export class InMemoryPostRepository implements PostRepository {
  private posts: Post[] = []

  async findAll(page: number, limit: number) {
    const start = (page - 1) * limit
    return {
      data: this.posts.slice(start, start + limit),
      total: this.posts.length,
    }
  }

  async findById(id: string) {
    return this.posts.find((p) => p.id === id) || null
  }

  async create(input: CreatePostInput) {
    const post: Post = {
      id: crypto.randomUUID(),
      ...input,
      createdAt: new Date(),
      updatedAt: new Date(),
    }
    this.posts.push(post)
    return post
  }

  async update(id: string, input: UpdatePostInput) {
    const index = this.posts.findIndex((p) => p.id === id)
    if (index === -1) return null
    this.posts[index] = { ...this.posts[index], ...input, updatedAt: new Date() }
    return this.posts[index]
  }

  async delete(id: string) {
    const index = this.posts.findIndex((p) => p.id === id)
    if (index === -1) return false
    this.posts.splice(index, 1)
    return true
  }
}
```

> 💡 **AI 활용 팁:** DB 마이그레이션 시 "InMemoryPostRepository를 PostgreSQL 버전으로 바꿔줘. Prisma 사용" 이라고 요청하면 같은 인터페이스의 DB 구현체를 만들어줘요.

---

### Step 5: 입력 검증 — Zod + AI 생성 스키마

**사용 프롬프트:**

```
Zod로 포스트 생성/수정 요청의 입력 검증 스키마를 만들어줘.
- title: 1~200자 문자열, 필수
- content: 1자 이상 문자열, 필수
- author: 1~100자 문자열, 필수
- 검증 미들웨어도 만들어서 라우트에 적용해줘
```

**생성 결과:**

```typescript
// src/schemas/post.schema.ts
import { z } from "zod"

export const createPostSchema = z.object({
  title: z
    .string({ required_error: "제목은 필수입니다" })
    .min(1, "제목을 입력해주세요")
    .max(200, "제목은 200자 이내로 입력해주세요"),
  content: z
    .string({ required_error: "내용은 필수입니다" })
    .min(1, "내용을 입력해주세요"),
  author: z
    .string({ required_error: "작성자는 필수입니다" })
    .min(1, "작성자를 입력해주세요")
    .max(100, "작성자명은 100자 이내로 입력해주세요"),
})

export const updatePostSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  content: z.string().min(1).optional(),
})

export type CreatePostInput = z.infer<typeof createPostSchema>
export type UpdatePostInput = z.infer<typeof updatePostSchema>
```

```typescript
// src/middleware/validate.ts
import { Request, Response, NextFunction } from "express"
import { ZodSchema, ZodError } from "zod"

export function validate(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      req.body = schema.parse(req.body)
      next()
    } catch (error) {
      if (error instanceof ZodError) {
        return res.status(400).json({
          error: "입력값이 올바르지 않습니다",
          details: error.errors.map((e) => ({
            field: e.path.join("."),
            message: e.message,
          })),
        })
      }
      next(error)
    }
  }
}
```

라우트에 적용:

```typescript
import { validate } from "../middleware/validate"
import { createPostSchema, updatePostSchema } from "../schemas/post.schema"

router.post("/", validate(createPostSchema), async (req, res) => {
  // req.body는 이미 검증 완료
  const post = await postRepo.create(req.body)
  res.status(201).json(post)
})

router.put("/:id", validate(updatePostSchema), async (req, res) => {
  const post = await postRepo.update(req.params.id, req.body)
  if (!post) return res.status(404).json({ error: "포스트를 찾을 수 없습니다" })
  res.json(post)
})
```

---

### Step 6: 테스트 작성 — Jest + Supertest

**사용 프롬프트:**

```
posts API의 통합 테스트를 Jest + Supertest로 작성해줘.
- 모든 CRUD 엔드포인트 테스트
- 입력 검증 실패 케이스 포함
- 404 케이스 포함
- 각 테스트는 독립적으로 실행 가능하도록
```

**생성 결과:**

```typescript
// tests/routes/posts.test.ts
import request from "supertest"
import app from "../../src/app"

describe("POST /api/posts", () => {
  it("새 포스트를 생성한다", async () => {
    const res = await request(app)
      .post("/api/posts")
      .send({
        title: "테스트 포스트",
        content: "이것은 테스트입니다",
        author: "테스터",
      })

    expect(res.status).toBe(201)
    expect(res.body).toMatchObject({
      title: "테스트 포스트",
      content: "이것은 테스트입니다",
      author: "테스터",
    })
    expect(res.body.id).toBeDefined()
    expect(res.body.createdAt).toBeDefined()
  })

  it("제목 없이 요청하면 400을 반환한다", async () => {
    const res = await request(app)
      .post("/api/posts")
      .send({
        content: "내용만 있음",
        author: "테스터",
      })

    expect(res.status).toBe(400)
    expect(res.body.error).toBe("입력값이 올바르지 않습니다")
  })
})

describe("GET /api/posts", () => {
  it("포스트 목록을 반환한다", async () => {
    const res = await request(app).get("/api/posts")

    expect(res.status).toBe(200)
    expect(res.body.data).toBeInstanceOf(Array)
    expect(res.body.pagination).toBeDefined()
  })

  it("페이지네이션이 동작한다", async () => {
    const res = await request(app).get("/api/posts?page=1&limit=5")

    expect(res.status).toBe(200)
    expect(res.body.pagination.page).toBe(1)
    expect(res.body.pagination.limit).toBe(5)
  })
})

describe("GET /api/posts/:id", () => {
  it("존재하지 않는 포스트는 404를 반환한다", async () => {
    const res = await request(app).get("/api/posts/nonexistent-id")

    expect(res.status).toBe(404)
  })
})

describe("PUT /api/posts/:id", () => {
  it("포스트를 수정한다", async () => {
    // 먼저 포스트 생성
    const createRes = await request(app)
      .post("/api/posts")
      .send({
        title: "원본 제목",
        content: "원본 내용",
        author: "테스터",
      })

    const res = await request(app)
      .put(\`/api/posts/${createRes.body.id}\`)
      .send({ title: "수정된 제목" })

    expect(res.status).toBe(200)
    expect(res.body.title).toBe("수정된 제목")
    expect(res.body.content).toBe("원본 내용") // 수정하지 않은 필드는 유지
  })
})

describe("DELETE /api/posts/:id", () => {
  it("포스트를 삭제한다", async () => {
    const createRes = await request(app)
      .post("/api/posts")
      .send({
        title: "삭제할 포스트",
        content: "삭제 예정",
        author: "테스터",
      })

    const res = await request(app).delete(\`/api/posts/${createRes.body.id}\`)
    expect(res.status).toBe(204)
  })
})
```

---

### Step 7: 에러 핸들링 패턴

**사용 프롬프트:**

```
Express 앱에 체계적인 에러 핸들링을 추가해줘.
- 커스텀 AppError 클래스
- 글로벌 에러 핸들러 미들웨어
- 404 핸들러
- async 라우트 래퍼 (try-catch 반복 제거)
```

**생성 결과:**

```typescript
// src/middleware/errorHandler.ts
import { Request, Response, NextFunction } from "express"

export class AppError extends Error {
  constructor(
    public statusCode: number,
    public message: string,
    public isOperational = true
  ) {
    super(message)
    Object.setPrototypeOf(this, AppError.prototype)
  }
}

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
) {
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      error: err.message,
      ...(process.env.NODE_ENV === "development" && { stack: err.stack }),
    })
  }

  // 예상하지 못한 에러
  console.error("Unexpected error:", err)
  res.status(500).json({
    error: "서버 내부 오류가 발생했습니다",
    ...(process.env.NODE_ENV === "development" && { 
      message: err.message,
      stack: err.stack 
    }),
  })
}

// async 라우트 래퍼
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>
) {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next)
  }
}
```

라우트에서 활용:

```typescript
import { asyncHandler, AppError } from "../middleware/errorHandler"

router.get("/:id", asyncHandler(async (req, res) => {
  const post = await postRepo.findById(req.params.id)
  if (!post) {
    throw new AppError(404, "포스트를 찾을 수 없습니다")
  }
  res.json(post)
}))
```

---

### Step 8: API 문서 자동 생성 — Swagger/OpenAPI

**사용 프롬프트:**

```
swagger-jsdoc과 swagger-ui-express로 API 문서를 자동 생성해줘.
- 모든 posts 엔드포인트에 JSDoc 주석 추가
- /api-docs에서 Swagger UI 접속 가능하도록
- 요청/응답 스키마도 문서화
```

**생성 결과:**

```typescript
// src/app.ts에 추가
import swaggerUi from "swagger-ui-express"
import swaggerJsdoc from "swagger-jsdoc"

const swaggerSpec = swaggerJsdoc({
  definition: {
    openapi: "3.0.0",
    info: {
      title: "Express API with AI",
      version: "1.0.0",
      description: "AI 코딩 도구로 만든 Express.js REST API",
    },
    servers: [{ url: "http://localhost:3000" }],
  },
  apis: ["./src/routes/*.ts"],
})

app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec))
```

라우트에 JSDoc 추가:

```typescript
/**
 * @swagger
 * /api/posts:
 *   get:
 *     summary: 포스트 목록 조회
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *     responses:
 *       200:
 *         description: 포스트 목록
 */
router.get("/", async (req, res) => {
  // ...
})
```

## AI 프롬프트 모음

각 단계에서 실제로 사용할 수 있는 프롬프트를 정리했어요.

| 단계 | 프롬프트 |
|------|----------|
| 초기화 | `Express.js + TypeScript 프로젝트 세팅해줘. nodemon, ts-node 포함` |
| 라우팅 | `RESTful CRUD 라우트를 만들어줘. pagination, 에러 응답 포함` |
| 미들웨어 | `CORS, Helmet, Morgan 미들웨어 설정해줘. 프로덕션/개발 환경 분리` |
| 모델링 | `인메모리 저장소를 Repository 패턴으로 리팩토링해줘` |
| 검증 | `Zod로 입력 검증 스키마 만들고 미들웨어로 라우트에 적용해줘` |
| 테스트 | `Jest + Supertest로 모든 엔드포인트 통합 테스트 작성해줘` |
| 에러 | `AppError 클래스와 글로벌 에러 핸들러를 만들어줘. async 래퍼 포함` |
| 문서 | `swagger-jsdoc으로 OpenAPI 문서 자동 생성 설정해줘` |
| 리팩토링 | `라우트 핸들러를 컨트롤러 레이어로 분리해줘` |
| DB 전환 | `InMemoryPostRepository를 Prisma + PostgreSQL 버전으로 교체해줘` |

## AI 도구 활용 팁

### 1. 단계적으로 구축하기

한 번에 전체를 요청하지 말고, 작은 단위로 나눠서 빌드해요.

```
❌ "블로그 API 전체를 만들어줘"
✅ "Post 모델 정의해줘" → "CRUD 라우트 만들어줘" → "검증 추가해줘" → "테스트 작성해줘"
```

### 2. 컨텍스트 관리하기

프로젝트가 커지면 AI에게 관련 파일을 알려줘요.

```
src/models/post.ts와 src/schemas/post.schema.ts를 참고해서
src/routes/posts.ts를 리팩토링해줘.
```

### 3. 테스트 우선 접근

테스트를 먼저 요청하면 요구사항이 명확해져요.

```
포스트 생성 API 테스트를 먼저 작성해줘.
- 정상 생성 시 201 반환
- 제목 누락 시 400 반환
- 빈 문자열 시 400 반환
그다음 테스트를 통과하는 라우트를 만들어줘.
```

### 4. 에러 케이스 명시하기

AI에게 에러 상황을 구체적으로 알려주면 더 견고한 코드가 나와요.

```
이 API에서 발생할 수 있는 에러 케이스를 모두 나열하고,
각각에 대한 에러 응답을 구현해줘.
```

### 5. 기존 코드 스타일 따르기

새 코드를 만들 때 기존 파일을 참조하게 하면 일관성이 유지돼요.

```
src/routes/posts.ts와 같은 패턴으로 src/routes/comments.ts를 만들어줘
```

## 다음 단계

이 예제를 완성한 후 도전해볼 수 있는 확장 과제:

- 🔐 JWT 인증 미들웨어 추가
- 📊 Rate limiting 구현
- 🗄️ Prisma + PostgreSQL로 DB 전환
- 🐳 Docker + docker-compose 설정
- 🚀 CI/CD 파이프라인 (GitHub Actions)

## 관련 리소스

- 📺 [텐빌더 YouTube](https://youtube.com/@ten-builder) — AI 코딩 실전 영상
- 📧 [텐빌더 뉴스레터](https://maily.so/tenbuilder) — 주간 AI 개발 뉴스
- 📁 [Next.js + Claude Code 예제](../nextjs-claude-code/) — 프론트엔드 예제도 확인해보세요

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
