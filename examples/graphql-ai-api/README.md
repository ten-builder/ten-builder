# GraphQL + AI API 개발 예제

> AI 코딩 도구(Claude Code, Cursor, Copilot)로 GraphQL API를 처음부터 만드는 실전 가이드

## 이런 분께 추천

- GraphQL로 API를 만들어보고 싶은 백엔드 개발자
- REST에서 GraphQL로 전환을 고민 중인 팀
- AI 코딩 도구로 스키마 설계를 빠르게 하고 싶은 분
- 타입 안전한 API를 TypeScript로 구축하려는 개발자

## 빠른 시작

```bash
# 1. 프로젝트 생성
mkdir graphql-api && cd graphql-api
npm init -y

# 2. 핵심 패키지 설치
npm install @apollo/server graphql
npm install -D typescript @types/node ts-node nodemon graphql-tag

# 3. TypeScript 설정
npx tsc --init --target ES2022 --module NodeNext --moduleResolution NodeNext \
  --outDir dist --rootDir src --strict true

# 4. AI에 첫 프롬프트
# "Apollo Server 4 + TypeScript 프로젝트를 세팅해줘.
#  src/index.ts를 진입점으로, nodemon 개발 서버를 설정해줘."
```

## 이 예제에서 배울 수 있는 것

- GraphQL 스키마를 AI와 함께 설계하고 반복 개선하는 패턴
- 리졸버를 AI로 빠르게 생성하고 타입 안전성을 확보하는 방법
- Codegen으로 스키마→타입→리졸버 파이프라인을 자동화하는 워크플로우
- 테스트, 에러 핸들링, DataLoader까지 실전 수준의 GraphQL 서버 구축

## 프로젝트 구조

```
graphql-ai-api/
├── src/
│   ├── index.ts              # 서버 진입점
│   ├── schema/
│   │   ├── typeDefs.ts       # GraphQL 스키마 정의
│   │   └── index.ts          # 스키마 통합
│   ├── resolvers/
│   │   ├── index.ts          # 리졸버 통합
│   │   ├── postResolvers.ts  # Post CRUD 리졸버
│   │   └── userResolvers.ts  # User 리졸버
│   ├── datasources/
│   │   ├── PostAPI.ts        # Post 데이터 소스
│   │   └── UserAPI.ts        # User 데이터 소스
│   ├── generated/
│   │   └── graphql.ts        # Codegen 자동 생성 타입
│   └── utils/
│       ├── dataloader.ts     # DataLoader (N+1 방지)
│       └── errors.ts         # 커스텀 에러 클래스
├── tests/
│   ├── queries.test.ts       # 쿼리 통합 테스트
│   ├── mutations.test.ts     # 뮤테이션 테스트
│   └── setup.ts              # 테스트 헬퍼
├── codegen.ts                # GraphQL Codegen 설정
├── package.json
└── tsconfig.json
```

## Step 1: 스키마 설계 — AI와 함께 시작하기

GraphQL의 핵심은 스키마 설계예요. AI에게 도메인 모델을 설명하면 초안을 빠르게 뽑을 수 있어요.

### AI 프롬프트

```
블로그 API의 GraphQL 스키마를 설계해줘.
- Post: id, title, content, author, tags, createdAt, updatedAt
- User: id, name, email, posts
- Query: posts(limit, offset), post(id), users
- Mutation: createPost, updatePost, deletePost
- 페이지네이션은 커서 기반으로 해줘
```

### 생성되는 스키마

```graphql
# src/schema/typeDefs.ts
import gql from 'graphql-tag';

export const typeDefs = gql`
  type Post {
    id: ID!
    title: String!
    content: String!
    author: User!
    tags: [String!]!
    createdAt: String!
    updatedAt: String!
  }

  type User {
    id: ID!
    name: String!
    email: String!
    posts: [Post!]!
  }

  type PostConnection {
    edges: [PostEdge!]!
    pageInfo: PageInfo!
  }

  type PostEdge {
    node: Post!
    cursor: String!
  }

  type PageInfo {
    hasNextPage: Boolean!
    endCursor: String
  }

  input CreatePostInput {
    title: String!
    content: String!
    authorId: ID!
    tags: [String!]
  }

  input UpdatePostInput {
    title: String
    content: String
    tags: [String!]
  }

  type Query {
    posts(first: Int = 10, after: String): PostConnection!
    post(id: ID!): Post
    users: [User!]!
    user(id: ID!): User
  }

  type Mutation {
    createPost(input: CreatePostInput!): Post!
    updatePost(id: ID!, input: UpdatePostInput!): Post!
    deletePost(id: ID!): Boolean!
  }
`;
```

**포인트:** Input 타입을 별도로 분리하면 뮤테이션 인자가 깔끔해지고, 나중에 필드 추가가 쉬워요.

## Step 2: Codegen으로 타입 자동 생성

스키마를 직접 타이핑하지 않아도 돼요. `graphql-codegen`이 스키마에서 TypeScript 타입을 자동으로 만들어줘요.

### AI 프롬프트

```
GraphQL Codegen 설정을 추가해줘.
스키마는 src/schema/typeDefs.ts에 있고,
리졸버 타입을 src/generated/graphql.ts에 생성해줘.
```

### Codegen 설정

```typescript
// codegen.ts
import type { CodegenConfig } from '@graphql-codegen/cli';

const config: CodegenConfig = {
  schema: './src/schema/typeDefs.ts',
  generates: {
    './src/generated/graphql.ts': {
      plugins: [
        'typescript',
        'typescript-resolvers',
      ],
      config: {
        useIndexSignature: true,
        contextType: '../index#GraphQLContext',
        mappers: {
          Post: '../datasources/PostAPI#PostModel',
          User: '../datasources/UserAPI#UserModel',
        },
      },
    },
  },
};

export default config;
```

```bash
# Codegen 패키지 설치
npm install -D @graphql-codegen/cli @graphql-codegen/typescript \
  @graphql-codegen/typescript-resolvers

# 타입 생성
npx graphql-codegen

# package.json에 스크립트 추가
# "codegen": "graphql-codegen",
# "codegen:watch": "graphql-codegen --watch"
```

**왜 이렇게 하나요?** `mappers`를 설정하면 리졸버에서 DB 모델과 GraphQL 타입 간 변환이 타입 안전하게 이뤄져요. 런타임 에러를 컴파일 타임에 잡을 수 있어요.

## Step 3: 리졸버 구현

리졸버는 스키마 필드를 실제 데이터로 채우는 함수예요. AI가 스키마를 보고 리졸버 뼈대를 만들어주면, 비즈니스 로직만 채우면 돼요.

### AI 프롬프트

```
위 스키마에 맞는 리졸버를 만들어줘.
- PostAPI, UserAPI 데이터소스를 context에서 가져와 사용
- 커서 기반 페이지네이션 구현
- 에러 처리는 GraphQLError 사용
```

### 리졸버 코드

```typescript
// src/resolvers/postResolvers.ts
import { GraphQLError } from 'graphql';
import type { Resolvers } from '../generated/graphql';

export const postResolvers: Resolvers = {
  Query: {
    posts: async (_, { first = 10, after }, { dataSources }) => {
      const { posts, hasNextPage } = await dataSources.postAPI
        .getPosts({ first, after });

      const edges = posts.map((post) => ({
        node: post,
        cursor: Buffer.from(post.id).toString('base64'),
      }));

      return {
        edges,
        pageInfo: {
          hasNextPage,
          endCursor: edges.length > 0
            ? edges[edges.length - 1].cursor
            : null,
        },
      };
    },

    post: async (_, { id }, { dataSources }) => {
      const post = await dataSources.postAPI.getPost(id);
      if (!post) {
        throw new GraphQLError('게시글을 찾을 수 없어요', {
          extensions: { code: 'NOT_FOUND' },
        });
      }
      return post;
    },
  },

  Mutation: {
    createPost: async (_, { input }, { dataSources }) => {
      return dataSources.postAPI.createPost(input);
    },

    updatePost: async (_, { id, input }, { dataSources }) => {
      const existing = await dataSources.postAPI.getPost(id);
      if (!existing) {
        throw new GraphQLError('게시글을 찾을 수 없어요', {
          extensions: { code: 'NOT_FOUND' },
        });
      }
      return dataSources.postAPI.updatePost(id, input);
    },

    deletePost: async (_, { id }, { dataSources }) => {
      return dataSources.postAPI.deletePost(id);
    },
  },

  Post: {
    author: async (post, _, { dataSources }) => {
      return dataSources.userAPI.getUser(post.authorId);
    },
  },
};
```

## Step 4: DataLoader로 N+1 문제 해결

GraphQL에서 가장 흔한 성능 문제가 N+1 쿼리예요. `dataloader`를 쓰면 자동으로 배치 처리해줘요.

### AI 프롬프트

```
Post.author 리졸버에서 N+1 문제가 발생해.
DataLoader를 사용해서 User를 배치로 로딩하도록 수정해줘.
```

### DataLoader 설정

```typescript
// src/utils/dataloader.ts
import DataLoader from 'dataloader';
import type { UserModel } from '../datasources/UserAPI';

export function createUserLoader(
  getUsers: (ids: string[]) => Promise<UserModel[]>
) {
  return new DataLoader<string, UserModel>(async (userIds) => {
    const users = await getUsers([...userIds]);
    const userMap = new Map(users.map((u) => [u.id, u]));
    return userIds.map((id) => userMap.get(id)!);
  });
}
```

```typescript
// 리졸버에서 사용
Post: {
  author: async (post, _, { loaders }) => {
    return loaders.userLoader.load(post.authorId);
  },
},
```

| 상황 | DataLoader 미사용 | DataLoader 사용 |
|------|-------------------|-----------------|
| Post 10개 + Author | SELECT * FROM users × 10 | SELECT * FROM users WHERE id IN (...) × 1 |
| 쿼리 수 | 11회 | 2회 |
| 응답 시간 | ~110ms | ~20ms |

## Step 5: 에러 핸들링

```typescript
// src/utils/errors.ts
import { GraphQLError } from 'graphql';

export class NotFoundError extends GraphQLError {
  constructor(resource: string, id: string) {
    super(`${resource}(${id})을 찾을 수 없어요`, {
      extensions: {
        code: 'NOT_FOUND',
        resource,
        id,
      },
    });
  }
}

export class ValidationError extends GraphQLError {
  constructor(message: string, field?: string) {
    super(message, {
      extensions: {
        code: 'VALIDATION_ERROR',
        field,
      },
    });
  }
}

export class AuthenticationError extends GraphQLError {
  constructor() {
    super('인증이 필요해요', {
      extensions: { code: 'UNAUTHENTICATED' },
    });
  }
}
```

```typescript
// 포맷 커스터마이징 — Apollo Server 4
const server = new ApolloServer({
  typeDefs,
  resolvers,
  formatError: (formattedError, error) => {
    // 프로덕션에서 내부 에러 메시지 숨기기
    if (formattedError.extensions?.code === 'INTERNAL_SERVER_ERROR') {
      return { message: '서버 에러가 발생했어요' };
    }
    return formattedError;
  },
});
```

## Step 6: 테스트 작성

### AI 프롬프트

```
posts 쿼리와 createPost 뮤테이션의 통합 테스트를 작성해줘.
Apollo Server의 executeOperation을 사용해서 HTTP 없이 테스트해줘.
```

### 테스트 코드

```typescript
// tests/queries.test.ts
import { ApolloServer } from '@apollo/server';
import assert from 'node:assert';
import { describe, it, beforeEach } from 'node:test';

describe('Post Queries', () => {
  let server: ApolloServer;

  beforeEach(() => {
    server = createTestServer(); // 테스트용 서버 팩토리
  });

  it('posts 목록을 조회할 수 있어야 해요', async () => {
    const response = await server.executeOperation({
      query: `
        query GetPosts($first: Int) {
          posts(first: $first) {
            edges {
              node { id title content }
            }
            pageInfo { hasNextPage endCursor }
          }
        }
      `,
      variables: { first: 5 },
    });

    assert(response.body.kind === 'single');
    const { data, errors } = response.body.singleResult;
    assert.strictEqual(errors, undefined);
    assert(Array.isArray(data?.posts.edges));
  });

  it('존재하지 않는 post 조회 시 NOT_FOUND 에러', async () => {
    const response = await server.executeOperation({
      query: `query { post(id: "nonexistent") { id title } }`,
    });

    assert(response.body.kind === 'single');
    const { errors } = response.body.singleResult;
    assert(errors && errors.length > 0);
    assert.strictEqual(errors[0].extensions?.code, 'NOT_FOUND');
  });
});
```

```typescript
// tests/mutations.test.ts
describe('Post Mutations', () => {
  it('새 게시글을 생성할 수 있어야 해요', async () => {
    const response = await server.executeOperation({
      query: `
        mutation CreatePost($input: CreatePostInput!) {
          createPost(input: $input) {
            id title content tags
          }
        }
      `,
      variables: {
        input: {
          title: 'GraphQL 시작하기',
          content: 'AI와 함께 만드는 첫 GraphQL API',
          authorId: 'user-1',
          tags: ['graphql', 'tutorial'],
        },
      },
    });

    assert(response.body.kind === 'single');
    const { data } = response.body.singleResult;
    assert.strictEqual(data?.createPost.title, 'GraphQL 시작하기');
    assert.deepStrictEqual(data?.createPost.tags, ['graphql', 'tutorial']);
  });
});
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 스키마 초안 | `블로그 도메인의 GraphQL 스키마를 설계해줘. 페이지네이션은 커서 기반으로` |
| 리졸버 뼈대 | `이 스키마의 리졸버를 TypeScript로 만들어줘. context에서 dataSources 사용` |
| N+1 해결 | `Post.author에서 N+1 문제가 발생해. DataLoader로 해결해줘` |
| 에러 핸들링 | `GraphQL 커스텀 에러 클래스를 만들어줘. NOT_FOUND, VALIDATION, AUTH` |
| 테스트 생성 | `posts 쿼리의 통합 테스트를 executeOperation으로 작성해줘` |
| 스키마 확장 | `Comment 타입을 추가해줘. Post와 1:N 관계로` |
| 인증 추가 | `JWT 기반 인증 미들웨어를 추가하고, Mutation에 인증 체크를 넣어줘` |

## REST vs GraphQL 선택 기준

| 기준 | REST가 유리한 경우 | GraphQL이 유리한 경우 |
|------|-------------------|---------------------|
| 데이터 구조 | 단순하고 고정적 | 중첩 관계가 복잡 |
| 클라이언트 | 웹만 사용 | 웹 + 모바일 + 서드파티 |
| 응답 크기 | 항상 전체 데이터 필요 | 화면마다 필요한 필드가 다름 |
| 캐싱 | HTTP 캐싱이 중요 | 클라이언트 캐싱(Apollo Client) |
| 팀 규모 | 소규모, 빠른 개발 | 프론트-백 분리된 팀 |

## 더 나아가기

이 예제를 확장하는 방향:

- **인증 추가:** JWT + context에서 사용자 정보 주입
- **Subscription:** WebSocket으로 실시간 업데이트 (새 댓글 알림)
- **Federation:** 마이크로서비스 간 GraphQL 통합
- **Persisted Queries:** 프로덕션 보안 강화
- **Apollo Client 연동:** React/Next.js 프론트엔드와 연결

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
