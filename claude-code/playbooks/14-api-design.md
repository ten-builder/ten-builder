# 플레이북 14: AI로 API 설계하기

> 스키마 정의부터 엔드포인트 구현까지 — AI 코딩 에이전트와 함께 실전 API를 빠르게 설계하고 검증하는 워크플로우

## 소요 시간

20-40분

## 사전 준비

- AI 코딩 도구 (Claude Code, Cursor 등) 설정 완료
- Node.js 18+ 또는 Python 3.10+ 환경
- REST API 기본 개념 이해
- 만들고 싶은 서비스의 대략적인 요구사항

## Step 1: 요구사항을 스키마로 변환하기

API 설계의 첫 단계는 비즈니스 요구사항을 데이터 스키마로 바꾸는 것이에요. AI에게 자연어로 설명하면 됩니다.

**프롬프트 예시:**

```
할 일 관리 앱의 REST API를 설계해줘.
요구사항:
- 사용자는 할 일을 생성, 조회, 수정, 삭제할 수 있어
- 할 일에는 제목, 설명, 우선순위(high/medium/low), 마감일이 있어
- 카테고리별로 할 일을 필터링할 수 있어
- 완료/미완료 상태를 토글할 수 있어

OpenAPI 3.0 스키마로 작성해줘.
```

**AI가 생성하는 스키마 구조:**

```yaml
openapi: 3.0.0
info:
  title: Todo API
  version: 1.0.0
paths:
  /todos:
    get:
      summary: 할 일 목록 조회
      parameters:
        - name: category
          in: query
          schema:
            type: string
        - name: status
          in: query
          schema:
            type: string
            enum: [pending, completed]
        - name: priority
          in: query
          schema:
            type: string
            enum: [high, medium, low]
    post:
      summary: 할 일 생성
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateTodo'
  /todos/{id}:
    get:
      summary: 할 일 상세 조회
    patch:
      summary: 할 일 수정
    delete:
      summary: 할 일 삭제
  /todos/{id}/toggle:
    post:
      summary: 완료 상태 토글
```

> **팁:** 처음부터 완벽한 스키마를 만들려고 하지 마세요. 핵심 엔드포인트 5-7개로 시작하고, 반복적으로 개선하는 게 훨씬 효과적이에요.

## Step 2: 엔드포인트 구조 검증하기

스키마가 나오면 AI에게 검증을 요청해요.

**검증 프롬프트:**

```
이 API 스키마를 검증해줘:
1. RESTful 규칙을 잘 따르고 있는지
2. 누락된 에러 응답이 있는지
3. 페이지네이션이 필요한 엔드포인트가 있는지
4. 인증/인가가 필요한 부분은 어디인지
```

**자주 발견되는 문제와 해결:**

| 문제 | 해결 방법 |
|------|----------|
| 페이지네이션 누락 | 목록 API에 `page`, `limit` 파라미터 추가 |
| 에러 응답 미정의 | 400, 404, 422, 500 응답 스키마 추가 |
| 일관성 없는 네이밍 | camelCase 또는 snake_case 중 하나로 통일 |
| 벌크 작업 부재 | 여러 항목을 한 번에 처리하는 엔드포인트 추가 |
| 필터링 부족 | 자주 쓰는 조건을 쿼리 파라미터로 추가 |

## Step 3: 구현 코드 생성하기

검증이 끝나면 바로 구현으로 넘어가요. AI에게 프레임워크와 패턴을 지정하면 일관된 코드가 나옵니다.

**Express.js 예시:**

```typescript
// routes/todos.ts
import { Router } from 'express';
import { z } from 'zod';

const CreateTodoSchema = z.object({
  title: z.string().min(1).max(200),
  description: z.string().optional(),
  priority: z.enum(['high', 'medium', 'low']).default('medium'),
  category: z.string().optional(),
  dueDate: z.string().datetime().optional(),
});

const router = Router();

router.get('/todos', async (req, res) => {
  const { category, status, priority, page = 1, limit = 20 } = req.query;

  const filters: Record<string, unknown> = {};
  if (category) filters.category = category;
  if (status) filters.status = status;
  if (priority) filters.priority = priority;

  const todos = await TodoService.list({
    filters,
    page: Number(page),
    limit: Math.min(Number(limit), 100),
  });

  res.json({
    data: todos.items,
    pagination: {
      page: todos.page,
      limit: todos.limit,
      total: todos.total,
    },
  });
});

router.post('/todos', async (req, res) => {
  const parsed = CreateTodoSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(422).json({
      error: 'Validation failed',
      details: parsed.error.issues,
    });
  }

  const todo = await TodoService.create(parsed.data);
  res.status(201).json({ data: todo });
});
```

**FastAPI 예시:**

```python
# routes/todos.py
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, Field
from enum import Enum

class Priority(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"

class CreateTodo(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: str | None = None
    priority: Priority = Priority.medium
    category: str | None = None
    due_date: str | None = None

router = APIRouter(prefix="/todos", tags=["todos"])

@router.get("/")
async def list_todos(
    category: str | None = Query(None),
    status: str | None = Query(None),
    priority: Priority | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
):
    todos = await todo_service.list(
        filters={"category": category, "status": status, "priority": priority},
        page=page,
        limit=limit,
    )
    return {"data": todos.items, "pagination": {...}}

@router.post("/", status_code=201)
async def create_todo(body: CreateTodo):
    todo = await todo_service.create(body.model_dump())
    return {"data": todo}
```

## Step 4: 에러 핸들링과 응답 표준화

일관된 응답 형식은 프론트엔드 개발자와 협업할 때 중요해요.

**표준 응답 패턴:**

```typescript
// 성공 응답
{ "data": { ... }, "pagination": { ... } }

// 에러 응답
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "제목은 필수 항목입니다",
    "details": [{ "field": "title", "issue": "required" }]
  }
}
```

**AI에게 에러 핸들러를 요청하는 프롬프트:**

```
이 API에 전역 에러 핸들러를 추가해줘:
- Zod 검증 에러 → 422 + 필드별 에러 메시지
- 리소스 미발견 → 404 + 리소스 타입 명시
- 인증 실패 → 401
- 서버 에러 → 500 + 에러 ID (디버깅용)
모든 에러 응답은 같은 형식을 따르게 해줘.
```

## Step 5: 테스트 자동 생성

API 구현이 끝나면 AI에게 테스트를 요청해요.

```
이 API의 통합 테스트를 작성해줘:
- 각 엔드포인트별 정상 케이스
- 잘못된 입력 (빈 제목, 잘못된 priority 값 등)
- 존재하지 않는 리소스 접근
- 페이지네이션 경계값
supertest/httpx를 사용하고, 테스트 DB는 각 테스트마다 초기화해줘.
```

**생성되는 테스트 예시:**

```typescript
describe('POST /todos', () => {
  it('유효한 데이터로 할 일을 생성한다', async () => {
    const res = await request(app)
      .post('/todos')
      .send({ title: '테스트 할 일', priority: 'high' })
      .expect(201);

    expect(res.body.data).toHaveProperty('id');
    expect(res.body.data.title).toBe('테스트 할 일');
  });

  it('제목 없이 요청하면 422를 반환한다', async () => {
    const res = await request(app)
      .post('/todos')
      .send({ priority: 'high' })
      .expect(422);

    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });
});
```

## Step 6: API 문서 자동 생성

코드에서 문서를 자동으로 뽑아내면 문서와 구현이 항상 동기화돼요.

```
이 API 코드를 기반으로:
1. OpenAPI 3.0 YAML 스펙 파일을 생성해줘
2. 각 엔드포인트에 요청/응답 예시를 포함해줘
3. 인증 방식 (Bearer Token) 섹션도 추가해줘
```

| 도구 | 용도 | 명령어 |
|------|------|--------|
| swagger-jsdoc | Express 주석에서 스펙 추출 | `npx swagger-jsdoc -d swaggerDef.js routes/*.ts` |
| FastAPI 내장 | 자동 Swagger UI 제공 | 기본 `/docs` 엔드포인트 |
| Redoc | 정적 문서 사이트 생성 | `npx @redocly/cli build-docs spec.yaml` |

## 체크리스트

- [ ] 비즈니스 요구사항 → OpenAPI 스키마 변환 완료
- [ ] RESTful 규칙 준수 검증 완료
- [ ] 페이지네이션, 필터링 파라미터 포함
- [ ] 입력 검증 (Zod/Pydantic) 적용
- [ ] 표준 에러 응답 형식 통일
- [ ] 통합 테스트 작성 및 통과
- [ ] API 문서 자동 생성 설정

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| 스키마 없이 바로 구현 시작 | 반드시 스키마 먼저 → 구현은 AI가 빠르게 처리 |
| 너무 많은 엔드포인트를 한번에 | 핵심 CRUD 5-7개부터 시작, 반복적으로 추가 |
| 에러 응답 형식 불일치 | 전역 에러 핸들러로 통일 |
| 검증 로직이 컨트롤러에 산재 | Zod/Pydantic 스키마로 중앙 관리 |
| 문서를 별도로 관리 | 코드에서 자동 생성하는 파이프라인 구축 |

## 다음 단계

→ [플레이북 07: 성능 최적화](07-performance.md) — API 성능 병목 찾기
→ [플레이북 05: AI 테스팅](05-testing.md) — 테스트 자동화 심화

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
