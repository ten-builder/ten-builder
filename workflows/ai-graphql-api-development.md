# AI 에이전트 기반 GraphQL API 개발 워크플로우

> 스키마 설계부터 리졸버 구현, N+1 문제 해결, 인증 미들웨어, 테스트 자동화까지 GraphQL API 개발 전체를 AI 에이전트로 자동화하는 워크플로우

## 개요

GraphQL API를 처음부터 끝까지 혼자 개발하려면 스키마 설계, 리졸버 구현, 성능 최적화, 인증/인가, 테스트까지 고려할 사항이 많습니다. AI 에이전트를 활용하면 이 과정을 크게 단축하면서도 품질을 유지할 수 있습니다.

이 워크플로우는 4단계로 구성됩니다: 스키마 설계 → 리졸버 구현 → 성능 최적화 → 테스트 자동화. 각 단계에서 AI 에이전트에게 넘길 부분과 직접 검토할 부분을 명확히 구분합니다.

## 사전 준비

- Node.js 20+ 또는 Python 3.11+
- Apollo Server 또는 Strawberry(Python) 설치
- 사용할 데이터베이스 연결 정보 (PostgreSQL, MongoDB 등)
- AI 에이전트 설정 완료 (Claude Code 또는 동등한 도구)

## Step 1: 스키마 설계

### 요구사항 → 타입 정의

먼저 요구사항 문서를 AI 에이전트에 넘기고 타입 정의를 생성합니다.

```
CLAUDE.md 또는 프롬프트에 추가:
- 데이터 모델: [요구사항 문서 또는 ERD 첨부]
- 네이밍 규칙: 타입은 PascalCase, 필드는 camelCase
- 스키마 우선 전략: DB 구조가 아닌 클라이언트 필요 기준으로 설계
- versionless 진화 방식 적용 (deprecated 대신 필드 추가)
```

AI가 생성한 스키마 초안 예시:

```graphql
type User {
  id: ID!
  email: String!
  name: String!
  createdAt: String!
  posts: [Post!]!
  profile: UserProfile
}

type Post {
  id: ID!
  title: String!
  content: String!
  author: User!
  tags: [Tag!]!
  publishedAt: String
  status: PostStatus!
}

enum PostStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
}

type Query {
  user(id: ID!): User
  users(limit: Int = 10, offset: Int = 0): [User!]!
  post(id: ID!): Post
  posts(status: PostStatus, authorId: ID): [Post!]!
}

type Mutation {
  createPost(input: CreatePostInput!): Post!
  updatePost(id: ID!, input: UpdatePostInput!): Post!
  deletePost(id: ID!): Boolean!
}

input CreatePostInput {
  title: String!
  content: String!
  tags: [String!]
}

input UpdatePostInput {
  title: String
  content: String
  status: PostStatus
}
```

### 검토 포인트

스키마를 받으면 다음을 직접 확인하세요:

| 항목 | 확인 기준 |
|------|-----------|
| 과도한 중첩 | 3단계 이상 중첩은 별도 쿼리로 분리 |
| 민감 필드 노출 | password, token 등이 타입에 포함되지 않았는지 |
| N+1 위험 경로 | 목록 타입에서 관계 필드를 가져오는 경로 파악 |
| nullable 설계 | 반드시 값이 있어야 하는 필드에만 `!` 사용 |

## Step 2: 리졸버 구현

### DataLoader 패턴 적용

N+1 문제가 예상되는 경로에 DataLoader를 먼저 설정합니다. AI에게 다음 지시사항으로 구현을 요청하세요:

```
지시사항:
- User.posts, Post.author 리졸버에 DataLoader 적용
- 요청별 새 DataLoader 인스턴스 생성 (캐시 격리)
- 배치 함수에서 입력 순서와 동일한 순서로 결과 반환 보장
- DB 쿼리는 배치 함수 안에서 한 번만 실행
```

생성된 DataLoader 예시 (Node.js):

```javascript
import DataLoader from 'dataloader';

// 컨텍스트 생성 시 호출 — 요청마다 새 인스턴스
export function createLoaders(db) {
  return {
    userLoader: new DataLoader(async (userIds) => {
      const users = await db.users.findMany({
        where: { id: { in: userIds } },
      });
      // 입력 순서 보장
      return userIds.map((id) => users.find((u) => u.id === id) ?? null);
    }),

    postsByAuthorLoader: new DataLoader(async (authorIds) => {
      const posts = await db.posts.findMany({
        where: { authorId: { in: authorIds } },
      });
      return authorIds.map((id) => posts.filter((p) => p.authorId === id));
    }),
  };
}
```

리졸버에서 사용:

```javascript
const resolvers = {
  User: {
    posts: (parent, _, { loaders }) => {
      return loaders.postsByAuthorLoader.load(parent.id);
    },
  },
  Post: {
    author: (parent, _, { loaders }) => {
      return loaders.userLoader.load(parent.authorId);
    },
  },
};
```

### 인증 미들웨어 설정

GraphQL 엔드포인트 앞에 인증 레이어를 설정합니다. AI에게 요청할 때 다음 원칙을 명시하세요:

```
원칙:
- 모든 인증 미들웨어는 GraphQL 처리 전에 실행
- 토큰 검증은 컨텍스트 생성 함수에서 처리
- 인증 실패 시 컨텍스트에 user: null, 리졸버에서 권한 검사
- WebSocket(Subscription) 연결도 동일한 토큰 검증 적용
```

```javascript
// Apollo Server 컨텍스트 설정 예시
const server = new ApolloServer({
  typeDefs,
  resolvers,
  context: async ({ req }) => {
    const token = req.headers.authorization?.replace('Bearer ', '') ?? null;

    let currentUser = null;
    if (token) {
      try {
        const decoded = verifyJWT(token);
        currentUser = await db.users.findUnique({ where: { id: decoded.userId } });
      } catch {
        // 토큰 검증 실패 — user는 null로 유지
      }
    }

    return {
      currentUser,
      loaders: createLoaders(db),
    };
  },
});
```

리졸버에서 권한 검사:

```javascript
Mutation: {
  deletePost: async (_, { id }, { currentUser, db }) => {
    if (!currentUser) throw new Error('로그인이 필요합니다.');
    
    const post = await db.posts.findUnique({ where: { id } });
    if (post.authorId !== currentUser.id) {
      throw new Error('권한이 없습니다.');
    }
    
    await db.posts.delete({ where: { id } });
    return true;
  },
},
```

## Step 3: 보안 및 성능 설정

AI 에이전트에게 보안 설정 자동화를 요청할 때 체크리스트를 넘겨주면 됩니다:

```
보안 설정 체크리스트:
- 쿼리 깊이 제한: maxDepth: 7
- 쿼리 복잡도 제한: maxComplexity: 1000
- 프로덕션 환경에서 introspection 비활성화
- 요청 크기 제한: bodyParser maxFileSize 설정
- 필드 레벨 권한: @auth 디렉티브 또는 미들웨어 적용
```

```javascript
import { createComplexityLimitRule } from 'graphql-validation-complexity';
import depthLimit from 'graphql-depth-limit';

const server = new ApolloServer({
  typeDefs,
  resolvers,
  validationRules: [
    depthLimit(7),
    createComplexityLimitRule(1000),
  ],
  introspection: process.env.NODE_ENV !== 'production',
  plugins: [
    // 느린 쿼리 로깅
    {
      requestDidStart: () => ({
        willSendResponse({ response, metrics }) {
          if (metrics.executionEndTime - metrics.executionStartTime > 500) {
            console.warn('느린 쿼리 감지:', metrics);
          }
        },
      }),
    },
  ],
});
```

## Step 4: 테스트 자동화

### AI가 생성하는 테스트 케이스

스키마와 리졸버 파일을 AI에 넘기면 다음 유형의 테스트를 자동 생성합니다:

```
테스트 생성 요청 예시:
"users 쿼리와 createPost 뮤테이션에 대한 테스트를 작성해줘.
- Happy path: 정상 동작 확인
- 권한 없는 접근: 인증 에러 확인
- 잘못된 입력: 검증 에러 확인
- N+1 방지 확인: DataLoader 배치 호출 횟수 검증"
```

```javascript
import { createTestClient } from 'apollo-server-testing';

describe('Post API', () => {
  test('인증 없이 createPost 호출 시 에러 반환', async () => {
    const { mutate } = createTestClient(server, { context: { currentUser: null } });
    
    const result = await mutate({
      mutation: CREATE_POST,
      variables: { input: { title: '테스트', content: '내용' } },
    });
    
    expect(result.errors[0].message).toBe('로그인이 필요합니다.');
  });

  test('DataLoader가 N+1 없이 배치 처리', async () => {
    const batchFnSpy = jest.spyOn(db.users, 'findMany');
    
    const { query } = createTestClient(server, { context: authenticatedContext });
    await query({ query: POSTS_WITH_AUTHORS });
    
    // 저자 10명이 있어도 DB 호출은 1회여야 함
    expect(batchFnSpy).toHaveBeenCalledTimes(1);
  });
});
```

### CI/CD 파이프라인 통합

```yaml
# .github/workflows/graphql-test.yml
name: GraphQL API Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - run: npm ci
      - run: npm test -- --coverage

      # 스키마 변경 충돌 감지
      - name: Schema compatibility check
        run: npx graphql-inspector diff schema.graphql origin/main:schema.graphql
        continue-on-error: true
```

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| N+1 쿼리 반복 | DataLoader 미적용 또는 컨텍스트 외부 생성 | 컨텍스트 안에서 요청마다 새로 생성 |
| 인증 우회 | WebSocket 연결에 미들웨어 미적용 | Subscription context에도 토큰 검증 추가 |
| 깊은 쿼리로 성능 저하 | depth limit 미설정 | `graphql-depth-limit` 적용 |
| 프로덕션 스키마 노출 | introspection 비활성화 미설정 | `NODE_ENV` 기반 조건 처리 |
| 타입 불일치 에러 | 스키마와 리졸버 반환값 불일치 | `graphql-code-generator`로 타입 자동 생성 |

## 커스터마이징

| 설정 | 기본값 | 조정 기준 |
|------|--------|-----------|
| `depthLimit` | 7 | 중첩이 깊은 도메인은 10까지 허용 |
| `maxComplexity` | 1000 | 복잡한 집계 쿼리가 필요하면 2000으로 상향 |
| DataLoader `maxBatchSize` | 제한 없음 | DB 인파라미터 한계에 맞게 설정 (예: 1000) |
| 느린 쿼리 임계값 | 500ms | 서비스 SLA에 맞게 조정 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
