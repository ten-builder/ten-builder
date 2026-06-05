# AI 에이전트 API-First 개발 플레이북 — OpenAPI 스펙부터 SDK 자동 생성까지

> 코드보다 계약(contract)을 먼저 작성하면, AI 에이전트가 나머지를 자동으로 처리해 줘요.

## 소요 시간

40-60분 (초기 설정 기준)

## 사전 준비

- Claude Code 또는 터미널 AI 에이전트
- Node.js 18+ 또는 Python 3.10+
- GitHub Actions 환경
- Speakeasy CLI (SDK 생성용, 선택)

---

## API-First가 왜 지금인가

기존 개발 방식은 코드를 먼저 만들고 문서를 나중에 썼어요. 결과적으로 문서는 항상 코드보다 뒤처졌죠.

API-First는 순서를 뒤집어요. **OpenAPI 스펙 → Mock 서버 → 계약 테스트 → 구현 → SDK 생성** 순서로 진행해요. AI 에이전트는 이 흐름의 각 단계를 자동화해 주기 때문에, 팀이 실제 로직에만 집중할 수 있어요.

2026년 기준으로 Postman Agent Mode, Speakeasy, Shift-Left API 같은 도구들이 OpenAPI 스펙만 있으면 테스트 케이스와 Mock 서버를 자동 생성해 줘요. AI 에이전트가 스펙을 읽고, 구현 코드와 스펙의 일치 여부를 실시간으로 검증하는 것도 가능해졌어요.

---

## Step 1: OpenAPI 스펙 설계

먼저 구현 없이 스펙만 작성해요. AI 에이전트에게 요구사항을 설명하면 초안을 만들어 줘요.

```bash
claude "다음 요구사항으로 OpenAPI 3.1 스펙을 작성해줘.

서비스: 사용자 관리 API
엔드포인트:
- POST /users (회원가입)
- GET /users/{id} (조회)
- PUT /users/{id} (수정)
- DELETE /users/{id} (탈퇴)
- POST /auth/login (로그인)

응답 형식: JSON, 에러는 RFC 7807 Problem Details"
```

스펙 파일을 `api/openapi.yaml`에 저장해요. 이게 이후 모든 단계의 입력이 돼요.

```yaml
# api/openapi.yaml 예시 구조
openapi: "3.1.0"
info:
  title: User Management API
  version: "1.0.0"
paths:
  /users:
    post:
      operationId: createUser
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateUserRequest"
      responses:
        "201":
          description: 생성 성공
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/User"
components:
  schemas:
    CreateUserRequest:
      type: object
      required: [email, password, name]
      properties:
        email:
          type: string
          format: email
        password:
          type: string
          minLength: 8
        name:
          type: string
```

---

## Step 2: Mock 서버 자동 구성

스펙이 있으면 구현 코드 없이도 클라이언트를 개발할 수 있어요. AI 에이전트로 Mock 서버를 바로 띄워요.

```bash
# Prism Mock Server (OpenAPI 기반)
npm install -g @stoplight/prism-cli

# 스펙에서 즉시 Mock 서버 실행
prism mock api/openapi.yaml --port 4010
```

AI 에이전트가 스펙에 맞는 샘플 응답을 자동 생성해 줘요:

```bash
# 테스트
curl -X POST http://localhost:4010/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"secret123","name":"테스트"}'

# 스펙의 schema 기반으로 자동 응답 반환
# {"id": "usr_abc123", "email": "test@example.com", ...}
```

프론트엔드 팀은 백엔드 구현을 기다리지 않고, Mock 서버를 사용해 병렬로 개발할 수 있어요.

---

## Step 3: 계약 테스트 자동 생성

AI 에이전트에게 스펙 파일을 주면 계약 테스트 코드를 자동으로 생성해 줘요.

```bash
claude "api/openapi.yaml을 분석해서 Jest + supertest 계약 테스트를 작성해줘.
각 엔드포인트에 대해:
- 정상 케이스 (2xx)
- 유효성 실패 케이스 (4xx)
- 응답 스키마 검증
를 포함해줘."
```

생성된 테스트 예시:

```typescript
// tests/contract/users.test.ts
import request from "supertest";
import { app } from "../../src/app";

describe("POST /users 계약 테스트", () => {
  test("정상 회원가입 — 201 응답과 User 스키마 반환", async () => {
    const res = await request(app)
      .post("/users")
      .send({ email: "a@b.com", password: "secure123", name: "홍길동" });

    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      id: expect.any(String),
      email: "a@b.com",
      name: "홍길동",
    });
    expect(res.body.password).toBeUndefined(); // 비밀번호 노출 방지
  });

  test("이메일 누락 — 400 응답", async () => {
    const res = await request(app)
      .post("/users")
      .send({ password: "secure123", name: "홍길동" });

    expect(res.status).toBe(400);
    expect(res.body.type).toMatch(/validation/); // RFC 7807
  });
});
```

---

## Step 4: 구현 코드 생성

계약 테스트가 있으니, 이제 AI 에이전트가 테스트를 통과하는 구현을 작성해요.

```bash
claude "tests/contract/users.test.ts의 계약 테스트를 통과하는
Express + TypeScript 구현을 작성해줘.
prisma를 ORM으로 사용하고, api/openapi.yaml의 스키마를 따라줘."
```

이 방식의 핵심: **테스트가 먼저 정의되어 있어서** AI 에이전트가 방향을 잃지 않아요. 스펙을 벗어난 구현이 자동으로 실패하기 때문에 즉시 발견할 수 있어요.

```bash
# CI에서 계약 테스트 실행
npm test -- --testPathPattern=contract

# 스펙과 구현 불일치 자동 감지
npx @stoplight/spectral-cli lint api/openapi.yaml
```

---

## Step 5: 클라이언트 SDK 자동 생성

스펙이 확정되면 AI 에이전트가 다양한 언어로 SDK를 자동으로 만들어요.

```bash
# Speakeasy로 TypeScript SDK 생성
speakeasy generate sdk \
  --schema api/openapi.yaml \
  --lang typescript \
  --out sdk/typescript

# Python SDK도 동시에 생성
speakeasy generate sdk \
  --schema api/openapi.yaml \
  --lang python \
  --out sdk/python
```

생성된 SDK 사용 예시:

```typescript
// 자동 생성된 SDK 사용
import { UserManagementSDK } from "./sdk/typescript";

const sdk = new UserManagementSDK({ baseUrl: "https://api.example.com" });

// 타입 안전하게 API 호출
const user = await sdk.users.create({
  email: "new@example.com",
  password: "secure123",
  name: "새 사용자",
});
```

SDK를 수동으로 작성하고 유지보수하는 데 드는 시간을 완전히 없앨 수 있어요.

---

## Step 6: CI/CD 파이프라인 통합

스펙 변경이 감지되면 자동으로 테스트와 SDK 재생성이 트리거되도록 설정해요.

```yaml
# .github/workflows/api-contract.yml
name: API Contract CI

on:
  pull_request:
    paths: ["api/openapi.yaml"]

jobs:
  contract-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: 스펙 유효성 검증
        run: npx @stoplight/spectral-cli lint api/openapi.yaml

      - name: Mock 서버 실행
        run: npx prism mock api/openapi.yaml --port 4010 &

      - name: 계약 테스트 실행
        run: npm test -- --testPathPattern=contract

      - name: SDK 재생성 (스펙 변경 시)
        if: success()
        run: speakeasy generate sdk --schema api/openapi.yaml --lang typescript --out sdk/typescript
```

---

## 체크리스트

- [ ] OpenAPI 3.1 스펙 초안을 AI 에이전트로 작성했다
- [ ] `spectral lint`로 스펙 유효성을 검증했다
- [ ] Prism Mock 서버가 로컬에서 실행된다
- [ ] 계약 테스트가 모든 엔드포인트를 커버한다
- [ ] CI에서 스펙 변경 시 자동으로 계약 테스트가 실행된다
- [ ] 클라이언트 SDK가 자동 생성되고 사용 가능하다

---

## 카테고리별 도구 선택 기준

| 용도 | 추천 도구 | 특징 |
|------|----------|------|
| 스펙 작성 | Claude Code + OpenAPI | 자연어 → 스펙 변환 |
| 스펙 유효성 | Spectral | 규칙 기반 린팅 |
| Mock 서버 | Prism | OpenAPI 직접 지원 |
| 계약 테스트 생성 | Claude Code + Shift-Left AI | AI 기반 자동 생성 |
| SDK 생성 | Speakeasy | 다언어 지원, 프로덕션급 |
| API 테스팅 | Postman Agent Mode | AI 네이티브 테스트 |

---

## 다음 단계

→ [AI 에이전트 기반 E2E 테스트 자동화 워크플로우](../workflows/ai-e2e-test-generation.md)

→ [AI 에이전트 보안 코드 리뷰 플레이북](./71-security-code-review-sast-dast.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
