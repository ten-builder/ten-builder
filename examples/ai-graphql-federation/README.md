# AI 에이전트 기반 GraphQL Federation 구성 예제

> Apollo Federation v2 + Apollo Router로 마이크로서비스 API를 통합하는 예제 — AI 에이전트가 서브그래프 스키마를 작성하고 타입 머지와 인증 전파를 설정합니다.

## 이 예제에서 배울 수 있는 것

- AI 에이전트로 Federation 서브그래프 스키마를 도메인 경계에 맞게 설계하는 방법
- `@key` 디렉티브로 여러 서브그래프에서 동일 엔티티를 확장하는 타입 머지 패턴
- Apollo Router를 통한 인증 전파 및 헤더 처리 방법
- 각 서브그래프를 독립적으로 개발·배포하는 AI 에이전트 워크플로우

## 프로젝트 구조

```
ai-graphql-federation/
├── router/
│   └── router.yaml            # Apollo Router 설정
├── subgraphs/
│   ├── users/
│   │   ├── schema.graphql     # 사용자 서브그래프 스키마
│   │   ├── index.js           # 서브그래프 서버
│   │   └── package.json
│   └── products/
│       ├── schema.graphql     # 상품 서브그래프 스키마
│       ├── index.js
│       └── package.json
├── supergraph.yaml            # Federation 구성 파일
└── CLAUDE.md                  # AI 에이전트 컨텍스트
```

## 시작하기

### 의존성 설치

```bash
# Apollo Router 다운로드
curl -sSL https://router.apollo.dev/download/nix/latest | sh

# 서브그래프 의존성 설치
cd subgraphs/users && npm install
cd ../products && npm install

# Rover CLI 설치 (Federation 구성 도구)
npm install -g @apollo/rover
```

### 서브그래프 실행

```bash
# 터미널 3개 열어서 각각 실행
cd subgraphs/users && node index.js      # :4001
cd subgraphs/products && node index.js   # :4002
./router --config router.yaml           # :4000 (수퍼그래프)
```

## 핵심 코드

### 1. Users 서브그래프 스키마

`@key` 디렉티브로 `User` 엔티티를 다른 서브그래프에서 참조할 수 있게 합니다.

```graphql
# subgraphs/users/schema.graphql
extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.0",
        import: ["@key", "@shareable"])

type User @key(fields: "id") {
  id: ID!
  name: String!
  email: String!
}

type Query {
  me: User
  user(id: ID!): User
  users: [User!]!
}
```

### 2. Products 서브그래프에서 User 확장

다른 서브그래프의 엔티티를 `@key`로 참조하고 필드를 추가합니다.

```graphql
# subgraphs/products/schema.graphql
extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.0",
        import: ["@key", "@external", "@requires"])

# User 엔티티 확장 — Users 서브그래프 소유, 여기서 구매 내역 추가
type User @key(fields: "id") {
  id: ID! @external
  purchases: [Product!]!
}

type Product @key(fields: "id") {
  id: ID!
  name: String!
  price: Int!
  seller: User!
}

type Query {
  product(id: ID!): Product
  products: [Product!]!
}
```

### 3. Apollo Router 설정

```yaml
# router.yaml
supergraph:
  listen: 0.0.0.0:4000

# 인증 헤더를 서브그래프로 전파
headers:
  all:
    request:
      - propagate:
          named: authorization
      - propagate:
          named: x-user-id

# CORS 설정
cors:
  origins:
    - http://localhost:3000
  allow_headers:
    - authorization
    - content-type
```

### 4. Federation 수퍼그래프 구성

```yaml
# supergraph.yaml
federation_version: =2.0.0

subgraphs:
  users:
    routing_url: http://localhost:4001/graphql
    schema:
      file: ./subgraphs/users/schema.graphql

  products:
    routing_url: http://localhost:4002/graphql
    schema:
      file: ./subgraphs/products/schema.graphql
```

수퍼그래프 스키마 구성:

```bash
rover supergraph compose --config ./supergraph.yaml > supergraph.graphql
```

## AI 에이전트로 서브그래프 추가하기

새 서브그래프가 필요할 때 AI 에이전트에게 위임하는 방법입니다.

### CLAUDE.md 설정

```markdown
# GraphQL Federation 프로젝트

## 아키텍처
- Apollo Federation v2 + Apollo Router
- 서브그래프: users(:4001), products(:4002)
- 수퍼그래프 라우터: :4000

## 새 서브그래프 추가 규칙
1. subgraphs/{name}/ 디렉토리 생성
2. schema.graphql에 federation 지시어 포함 필수
3. 기존 @key 엔티티 참조 시 @external 사용
4. supergraph.yaml에 서브그래프 등록
5. 각 서브그래프는 독립 포트 사용 (현재 최대: :4002)
```

### 프롬프트 예시

```
주문(orders) 서브그래프를 추가해줘:
- Order 엔티티: id, userId, productIds, totalPrice, status, createdAt
- User와 Product를 @key로 연결
- Query: order(id), ordersByUser(userId)
- Mutation: createOrder, updateOrderStatus
- resolveReference로 엔티티 조회 구현
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 서브그래프 설계 | `도메인 경계를 기준으로 서브그래프를 분리해줘. 현재 스키마: [schema]` |
| 타입 머지 오류 | `@key 충돌 오류가 발생해: [오류 메시지]. 수정 방법 알려줘` |
| 인증 전파 | `JWT 토큰에서 userId를 추출해 모든 서브그래프로 전파하는 Router 설정 작성해줘` |
| 성능 최적화 | `N+1 쿼리가 발생하는 resolveReference 코드를 DataLoader로 최적화해줘` |
| 스키마 검증 | `rover supergraph compose 실패 오류를 분석하고 수정해줘: [오류]` |

## 문제 해결

| 문제 | 해결 |
|------|------|
| `@key` 필드 타입 불일치 | 참조하는 서브그래프와 소유 서브그래프의 `@key` 타입이 동일한지 확인 |
| `resolveReference` 미구현 | `@key` 엔티티는 반드시 `__resolveReference` 리졸버 구현 필요 |
| Router 인증 헤더 미전달 | `router.yaml`의 `headers.all.request.propagate` 설정 확인 |
| 서브그래프 스키마 구성 실패 | `rover subgraph check` 명령어로 단일 서브그래프 먼저 검증 |

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
