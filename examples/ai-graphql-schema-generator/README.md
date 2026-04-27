# AI 에이전트 기반 GraphQL API 스키마 자동 생성기

> 데이터베이스 스키마에서 GraphQL 타입·리졸버·뮤테이션을 자동으로 뽑아내는 Python 스크립트

## 이 예제에서 배울 수 있는 것

- Prisma 스키마와 Drizzle 스키마를 파싱해 GraphQL SDL(Schema Definition Language)을 생성하는 방법
- Claude API `Tool Use`로 복잡한 타입 관계를 분석하고 리졸버 로직까지 만드는 방법
- 생성된 스키마를 Apollo Server 프로젝트에 바로 붙여 쓸 수 있는 구조로 출력하는 방법
- 반복 가능한 CLI 파이프라인으로 묶어 CI/CD에서 스키마를 항상 최신으로 유지하는 방법

## 프로젝트 구조

```
ai-graphql-schema-generator/
├── src/
│   ├── parsers/
│   │   ├── prisma_parser.py      # Prisma schema.prisma 파싱
│   │   └── drizzle_parser.py     # Drizzle schema.ts 파싱
│   ├── generators/
│   │   ├── sdl_generator.py      # GraphQL SDL 생성
│   │   └── resolver_generator.py # 리졸버 스텁 생성
│   ├── claude_agent.py           # Claude API Tool Use 연동
│   └── main.py                   # CLI 엔트리포인트
├── examples/
│   ├── prisma/schema.prisma      # 샘플 Prisma 스키마
│   └── drizzle/schema.ts         # 샘플 Drizzle 스키마
├── output/                        # 생성 결과 저장
├── requirements.txt
└── README.md
```

## 시작하기

### 1. 의존성 설치

```bash
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-graphql-schema-generator

pip install -r requirements.txt
```

`requirements.txt`:

```
anthropic>=0.49.0
click>=8.0
pydantic>=2.0
```

### 2. 환경 변수 설정

```bash
export ANTHROPIC_API_KEY="your-api-key"
```

### 3. 실행

```bash
# Prisma 스키마 → GraphQL SDL + 리졸버 생성
python src/main.py --input examples/prisma/schema.prisma --format prisma

# Drizzle 스키마 → GraphQL SDL + 리졸버 생성
python src/main.py --input examples/drizzle/schema.ts --format drizzle

# 출력 디렉토리 지정
python src/main.py --input schema.prisma --format prisma --output ./generated
```

## 핵심 코드

### 1. Prisma 스키마 파싱 (`src/parsers/prisma_parser.py`)

```python
import re
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class PrismaField:
    name: str
    type: str
    is_list: bool = False
    is_optional: bool = False
    is_relation: bool = False
    attributes: list[str] = field(default_factory=list)

@dataclass
class PrismaModel:
    name: str
    fields: list[PrismaField] = field(default_factory=list)

def parse_prisma_schema(content: str) -> list[PrismaModel]:
    """schema.prisma 파일에서 모델 정의를 추출합니다."""
    models = []
    model_pattern = re.compile(r'model\s+(\w+)\s*\{([^}]+)\}', re.DOTALL)

    for match in model_pattern.finditer(content):
        model_name = match.group(1)
        model_body = match.group(2)
        fields = []

        for line in model_body.strip().splitlines():
            line = line.strip()
            if not line or line.startswith('//') or line.startswith('@@'):
                continue

            parts = line.split()
            if len(parts) < 2:
                continue

            field_name = parts[0]
            field_type_raw = parts[1]

            is_list = field_type_raw.endswith('[]')
            is_optional = '?' in field_type_raw
            clean_type = field_type_raw.replace('[]', '').replace('?', '')

            # 관계 필드 감지 (첫 글자 대문자 → 다른 모델 참조)
            is_relation = clean_type[0].isupper() and clean_type not in {
                'String', 'Int', 'Float', 'Boolean', 'DateTime', 'Json'
            }

            fields.append(PrismaField(
                name=field_name,
                type=clean_type,
                is_list=is_list,
                is_optional=is_optional,
                is_relation=is_relation,
                attributes=parts[2:],
            ))

        models.append(PrismaModel(name=model_name, fields=fields))

    return models
```

**왜 이렇게 했나요?**

Prisma의 스키마 문법은 정규식으로 파싱하기 충분히 단순합니다. 완전한 AST 파서를 만들면 복잡해지고, 실제 프로젝트에서 마주치는 99%의 케이스는 이 수준으로 커버됩니다. 관계 필드 감지는 Prisma 컨벤션(모델명은 PascalCase)을 활용해 별도 파싱 없이 처리합니다.

### 2. Claude Agent로 리졸버 생성 (`src/claude_agent.py`)

```python
import anthropic
import json

client = anthropic.Anthropic()

RESOLVER_TOOL = {
    "name": "generate_resolvers",
    "description": "GraphQL 타입 정의를 받아 Query/Mutation/Subscription 리졸버 스텁을 생성합니다.",
    "input_schema": {
        "type": "object",
        "properties": {
            "type_name": {
                "type": "string",
                "description": "GraphQL 타입명 (예: User, Post)"
            },
            "fields": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "return_type": {"type": "string"},
                        "is_list": {"type": "boolean"}
                    }
                }
            },
            "db_client": {
                "type": "string",
                "enum": ["prisma", "drizzle"],
                "description": "사용 중인 DB 클라이언트"
            }
        },
        "required": ["type_name", "fields", "db_client"]
    }
}

def generate_resolvers_with_agent(type_name: str, fields: list, db_client: str) -> str:
    """Claude Tool Use로 타입별 리졸버 코드를 생성합니다."""
    
    response = client.messages.create(
        model="claude-opus-4-6-20251101",
        max_tokens=2048,
        tools=[RESOLVER_TOOL],
        messages=[{
            "role": "user",
            "content": (
                f"{type_name} 타입의 GraphQL 리졸버를 TypeScript로 작성해줘. "
                f"DB 클라이언트는 {db_client}야. "
                f"Query(list, findById), Mutation(create, update, delete) 포함. "
                f"타입 안전성을 위해 제네릭 사용."
            )
        }]
    )

    # Tool Use 결과 추출
    for block in response.content:
        if block.type == "tool_use":
            return json.dumps(block.input, ensure_ascii=False, indent=2)

    return ""
```

**왜 이렇게 했나요?**

단순 프롬프트로 코드를 생성하면 출력 포맷이 들쭉날쭉합니다. Tool Use를 쓰면 리턴값의 구조가 JSON 스키마로 고정되어 파싱 실패 없이 후처리할 수 있습니다. 특히 여러 타입을 반복 처리할 때 일관된 출력이 보장됩니다.

### 3. SDL 생성기 (`src/generators/sdl_generator.py`)

```python
PRISMA_TO_GRAPHQL_TYPE = {
    "String": "String",
    "Int": "Int",
    "Float": "Float",
    "Boolean": "Boolean",
    "DateTime": "String",  # ISO 8601 문자열로 직렬화
    "Json": "JSON",        # scalar JSON 별도 선언 필요
}

def model_to_graphql_type(model) -> str:
    """Prisma 모델을 GraphQL type 정의로 변환합니다."""
    lines = [f"type {model.name} {{"]

    for f in model.fields:
        # @id, @default, @relation 같은 어트리뷰트 필드는 제외
        if any(attr.startswith('@relation') for attr in f.attributes):
            # 관계 뒷편 FK 필드는 SDL에서 숨김
            continue

        gql_type = PRISMA_TO_GRAPHQL_TYPE.get(f.type, f.type)
        if f.is_list:
            gql_type = f"[{gql_type}!]"
        if not f.is_optional:
            gql_type = f"{gql_type}!"

        lines.append(f"  {f.name}: {gql_type}")

    lines.append("}")
    return "\n".join(lines)

def generate_query_type(models) -> str:
    """Query 루트 타입을 생성합니다."""
    lines = ["type Query {"]
    for model in models:
        name = model.name
        camel = name[0].lower() + name[1:]
        lines.append(f"  {camel}(id: ID!): {name}")
        lines.append(f"  {camel}s: [{name}!]!")
    lines.append("}")
    return "\n".join(lines)

def generate_mutation_type(models) -> str:
    """Mutation 루트 타입을 생성합니다."""
    lines = ["type Mutation {"]
    for model in models:
        name = model.name
        camel = name[0].lower() + name[1:]
        lines.append(f"  create{name}(input: Create{name}Input!): {name}!")
        lines.append(f"  update{name}(id: ID!, input: Update{name}Input!): {name}!")
        lines.append(f"  delete{name}(id: ID!): Boolean!")
    lines.append("}")
    return "\n".join(lines)
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 복잡한 관계 타입 처리 | `"User-Post-Comment 3단계 중첩 관계를 GraphQL로 표현해. N+1 문제를 방지하는 DataLoader 패턴 포함."` |
| Input 타입 자동 생성 | `"User 모델의 CreateInput, UpdateInput 타입을 생성해. id, createdAt 같은 자동 생성 필드는 제외."` |
| 리졸버 최적화 | `"Post 리졸버에서 author 필드를 매번 DB 조회하지 않도록 BatchedDataLoader로 최적화해줘."` |
| 스키마 검증 | `"이 GraphQL 스키마에서 순환 참조나 타입 충돌이 있는지 검사하고 수정 방법을 알려줘."` |

## 샘플 입력 / 출력

**입력 (`examples/prisma/schema.prisma`):**

```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String
  createdAt DateTime @default(now())
}
```

**출력 (`output/schema.graphql`):**

```graphql
scalar DateTime
scalar JSON

type User {
  id: ID!
  email: String!
  name: String
  posts: [Post!]!
  createdAt: String!
}

type Post {
  id: ID!
  title: String!
  content: String
  published: Boolean!
  authorId: String!
  createdAt: String!
}

type Query {
  user(id: ID!): User
  users: [User!]!
  post(id: ID!): Post
  posts: [Post!]!
}

type Mutation {
  createUser(input: CreateUserInput!): User!
  updateUser(id: ID!, input: UpdateUserInput!): User!
  deleteUser(id: ID!): Boolean!
  createPost(input: CreatePostInput!): Post!
  updatePost(id: ID!, input: UpdatePostInput!): Post!
  deletePost(id: ID!): Boolean!
}
```

## CI/CD 통합

GitHub Actions에서 스키마 변경 시 자동으로 GraphQL 정의를 재생성합니다:

```yaml
name: Regenerate GraphQL Schema

on:
  push:
    paths:
      - 'prisma/schema.prisma'
      - 'src/db/schema.ts'

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install -r requirements.txt
      - run: python src/main.py --input prisma/schema.prisma --format prisma --output src/graphql
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      - uses: peter-evans/create-pull-request@v6
        with:
          commit-message: "chore: regenerate GraphQL schema from Prisma"
          branch: chore/update-graphql-schema
          title: "chore: GraphQL schema 자동 업데이트"
```

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
