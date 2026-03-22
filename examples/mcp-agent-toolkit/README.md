# MCP 에이전트 도구 키트 실전 예제

> 파일 시스템, Git, 데이터베이스 — MCP 서버 3개를 연결해서 AI 코딩 에이전트의 도구 체인을 구축하는 실전 가이드

## 이 예제에서 배울 수 있는 것

- MCP 서버 3개를 조합해 개발 환경을 자동화하는 구성 방법
- 파일 시스템 + Git + SQLite를 하나의 도구 체인으로 연결하는 패턴
- AI 에이전트가 도구를 선택하고 호출하는 과정의 실제 동작 원리
- 커스텀 MCP 서버를 추가해 도구 키트를 확장하는 방법

## 프로젝트 구조

```
mcp-agent-toolkit/
├── .claude/
│   └── settings.local.json    # Claude Code MCP 설정
├── mcp-servers/
│   ├── filesystem-server/
│   │   ├── package.json
│   │   └── index.ts           # 파일 시스템 MCP 서버
│   ├── git-server/
│   │   ├── package.json
│   │   └── index.ts           # Git 작업 MCP 서버
│   └── db-server/
│       ├── package.json
│       └── index.ts           # SQLite MCP 서버
├── scripts/
│   └── setup.sh               # 전체 설정 스크립트
├── demo-project/
│   ├── src/
│   │   └── app.ts             # 데모 앱 (도구 테스트용)
│   ├── migrations/
│   │   └── 001_init.sql       # DB 초기 스키마
│   └── package.json
├── CLAUDE.md
└── README.md
```

## 시작하기

### Step 1: 프로젝트 초기화

```bash
mkdir mcp-agent-toolkit && cd mcp-agent-toolkit
npm init -y

# MCP SDK 설치
npm install @modelcontextprotocol/sdk zod
npm install -D typescript @types/node tsx
```

### Step 2: CLAUDE.md 작성

```markdown
# MCP 에이전트 도구 키트

## 기술 스택
- TypeScript, MCP SDK (@modelcontextprotocol/sdk)
- SQLite (better-sqlite3), simple-git

## MCP 서버 구성
- filesystem-server: 파일 읽기/쓰기/검색
- git-server: 커밋, 브랜치, 히스토리 조회
- db-server: SQLite 쿼리 실행, 스키마 조회

## 규칙
- 모든 도구에 입력 스키마(Zod) 정의 필수
- 에러 시 사용자 친화적 메시지 반환
```

## 핵심 코드

### 파일 시스템 MCP 서버

프로젝트 파일을 읽고, 쓰고, 검색하는 도구를 제공해요.

```typescript
// mcp-servers/filesystem-server/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import * as fs from "fs/promises";
import * as path from "path";

const server = new McpServer({
  name: "filesystem-server",
  version: "1.0.0",
});

// 허용된 루트 디렉토리 (보안을 위해 제한)
const ALLOWED_ROOT = process.env.PROJECT_ROOT || process.cwd();

function validatePath(filePath: string): string {
  const resolved = path.resolve(ALLOWED_ROOT, filePath);
  if (!resolved.startsWith(ALLOWED_ROOT)) {
    throw new Error("접근 불가: 허용된 디렉토리 밖의 경로");
  }
  return resolved;
}

// 도구 1: 파일 읽기
server.tool(
  "read_file",
  "파일 내용을 읽어서 반환",
  { path: z.string().describe("읽을 파일 경로 (상대 경로)") },
  async ({ path: filePath }) => {
    const resolved = validatePath(filePath);
    const content = await fs.readFile(resolved, "utf-8");
    return { content: [{ type: "text", text: content }] };
  }
);

// 도구 2: 파일 쓰기
server.tool(
  "write_file",
  "파일에 내용을 쓰기 (없으면 생성)",
  {
    path: z.string().describe("쓸 파일 경로"),
    content: z.string().describe("파일에 쓸 내용"),
  },
  async ({ path: filePath, content }) => {
    const resolved = validatePath(filePath);
    await fs.mkdir(path.dirname(resolved), { recursive: true });
    await fs.writeFile(resolved, content, "utf-8");
    return {
      content: [{ type: "text", text: `파일 저장 완료: ${filePath}` }],
    };
  }
);

// 도구 3: 디렉토리 트리 조회
server.tool(
  "list_directory",
  "디렉토리의 파일/폴더 목록을 트리 형태로 반환",
  {
    path: z.string().default(".").describe("조회할 디렉토리 경로"),
    depth: z.number().default(2).describe("탐색 깊이"),
  },
  async ({ path: dirPath, depth }) => {
    const resolved = validatePath(dirPath);

    async function buildTree(
      dir: string,
      currentDepth: number
    ): Promise<string> {
      if (currentDepth > depth) return "";
      const entries = await fs.readdir(dir, { withFileTypes: true });
      const lines: string[] = [];

      for (const entry of entries) {
        if (entry.name.startsWith(".") || entry.name === "node_modules")
          continue;
        const prefix = "  ".repeat(currentDepth);
        if (entry.isDirectory()) {
          lines.push(`${prefix}${entry.name}/`);
          lines.push(
            await buildTree(path.join(dir, entry.name), currentDepth + 1)
          );
        } else {
          lines.push(`${prefix}${entry.name}`);
        }
      }
      return lines.filter(Boolean).join("\n");
    }

    const tree = await buildTree(resolved, 0);
    return { content: [{ type: "text", text: tree }] };
  }
);

// 서버 시작
const transport = new StdioServerTransport();
await server.connect(transport);
```

**왜 이렇게 했나요?**

`validatePath`로 루트 디렉토리 밖의 접근을 차단해요. AI 에이전트가 도구를 호출할 때 임의 경로에 접근하는 것을 방지하는 기본 보안 장치예요.

### Git MCP 서버

커밋 히스토리 조회, 브랜치 관리, diff 확인 도구를 제공해요.

```typescript
// mcp-servers/git-server/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import simpleGit, { SimpleGit } from "simple-git";

const server = new McpServer({
  name: "git-server",
  version: "1.0.0",
});

const REPO_PATH = process.env.REPO_PATH || process.cwd();
const git: SimpleGit = simpleGit(REPO_PATH);

// 도구 1: 커밋 히스토리
server.tool(
  "git_log",
  "최근 커밋 히스토리를 조회",
  { count: z.number().default(10).describe("조회할 커밋 수") },
  async ({ count }) => {
    const log = await git.log({ maxCount: count });
    const formatted = log.all
      .map(
        (c) =>
          `${c.hash.slice(0, 7)} | ${c.date.split("T")[0]} | ${c.message}`
      )
      .join("\n");
    return { content: [{ type: "text", text: formatted }] };
  }
);

// 도구 2: 변경 파일 확인 (diff)
server.tool(
  "git_diff",
  "현재 변경사항 또는 특정 커밋 간 diff 확인",
  {
    target: z.string().default("HEAD").describe("비교 대상 (커밋 해시 또는 HEAD)"),
  },
  async ({ target }) => {
    const diff = await git.diff([target]);
    if (!diff) {
      return { content: [{ type: "text", text: "변경사항 없음" }] };
    }
    return { content: [{ type: "text", text: diff.slice(0, 5000) }] };
  }
);

// 도구 3: 브랜치 목록
server.tool("git_branches", "브랜치 목록 조회", {}, async () => {
  const branches = await git.branch();
  const list = branches.all
    .map((b) => `${b === branches.current ? "* " : "  "}${b}`)
    .join("\n");
  return { content: [{ type: "text", text: list }] };
});

// 도구 4: 파일별 최근 수정자 확인
server.tool(
  "git_blame_summary",
  "파일의 최근 수정 이력 요약",
  { file: z.string().describe("확인할 파일 경로") },
  async ({ file }) => {
    const log = await git.log({ file, maxCount: 5 });
    const summary = log.all
      .map(
        (c) =>
          `${c.hash.slice(0, 7)} | ${c.author_name} | ${c.date.split("T")[0]} | ${c.message}`
      )
      .join("\n");
    return {
      content: [{ type: "text", text: summary || "이력 없음" }],
    };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

**왜 이렇게 했나요?**

`simple-git` 라이브러리로 Git 명령어를 안전하게 래핑해요. AI 에이전트가 직접 셸 명령어를 실행하는 대신 MCP 도구를 통해 제어된 방식으로 Git 작업을 수행하게 돼요.

### SQLite MCP 서버

데이터베이스 쿼리와 스키마 조회 도구를 제공해요.

```typescript
// mcp-servers/db-server/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import Database from "better-sqlite3";

const server = new McpServer({
  name: "db-server",
  version: "1.0.0",
});

const DB_PATH = process.env.DB_PATH || "./data.db";
const db = new Database(DB_PATH);

// WAL 모드로 읽기 성능 향상
db.pragma("journal_mode = WAL");

// 도구 1: SELECT 쿼리 실행
server.tool(
  "db_query",
  "SELECT 쿼리 실행 (읽기 전용)",
  { sql: z.string().describe("실행할 SELECT SQL 쿼리") },
  async ({ sql }) => {
    // SELECT만 허용 (안전 장치)
    if (!sql.trim().toUpperCase().startsWith("SELECT")) {
      return {
        content: [
          { type: "text", text: "읽기 전용: SELECT 쿼리만 실행할 수 있어요" },
        ],
      };
    }

    try {
      const rows = db.prepare(sql).all();
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(rows, null, 2).slice(0, 5000),
          },
        ],
      };
    } catch (err) {
      return {
        content: [{ type: "text", text: `쿼리 에러: ${(err as Error).message}` }],
      };
    }
  }
);

// 도구 2: 쓰기 쿼리 실행 (INSERT/UPDATE/DELETE)
server.tool(
  "db_execute",
  "INSERT, UPDATE, DELETE 쿼리 실행",
  {
    sql: z.string().describe("실행할 SQL 쿼리"),
    params: z
      .array(z.union([z.string(), z.number(), z.null()]))
      .default([])
      .describe("바인딩할 파라미터"),
  },
  async ({ sql, params }) => {
    const forbidden = ["DROP", "TRUNCATE", "ALTER"];
    const upper = sql.trim().toUpperCase();
    if (forbidden.some((f) => upper.startsWith(f))) {
      return {
        content: [{ type: "text", text: "위험한 쿼리는 실행할 수 없어요" }],
      };
    }

    try {
      const result = db.prepare(sql).run(...params);
      return {
        content: [
          {
            type: "text",
            text: `실행 완료 — 변경된 행: ${result.changes}`,
          },
        ],
      };
    } catch (err) {
      return {
        content: [{ type: "text", text: `실행 에러: ${(err as Error).message}` }],
      };
    }
  }
);

// 도구 3: 스키마 조회
server.tool(
  "db_schema",
  "데이터베이스 테이블 목록과 스키마 조회",
  {},
  async () => {
    const tables = db
      .prepare(
        "SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY name"
      )
      .all() as { name: string; sql: string }[];

    const schema = tables
      .map((t) => `-- ${t.name}\n${t.sql};`)
      .join("\n\n");
    return { content: [{ type: "text", text: schema || "테이블 없음" }] };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

**왜 이렇게 했나요?**

읽기(`db_query`)와 쓰기(`db_execute`)를 분리하고, DROP/TRUNCATE 같은 위험한 쿼리를 차단해요. AI 에이전트에게 DB 접근 권한을 줄 때 반드시 필요한 안전 장치예요.

## MCP 서버 연결 설정

### Claude Code 설정

```json
// .claude/settings.local.json (프로젝트 루트)
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["tsx", "mcp-servers/filesystem-server/index.ts"],
      "env": {
        "PROJECT_ROOT": "/path/to/your/project"
      }
    },
    "git": {
      "command": "npx",
      "args": ["tsx", "mcp-servers/git-server/index.ts"],
      "env": {
        "REPO_PATH": "/path/to/your/project"
      }
    },
    "database": {
      "command": "npx",
      "args": ["tsx", "mcp-servers/db-server/index.ts"],
      "env": {
        "DB_PATH": "./demo-project/data.db"
      }
    }
  }
}
```

### Cursor / Windsurf 설정

```json
// .cursor/mcp.json 또는 .windsurf/mcp.json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["tsx", "mcp-servers/filesystem-server/index.ts"]
    },
    "git": {
      "command": "npx",
      "args": ["tsx", "mcp-servers/git-server/index.ts"]
    },
    "database": {
      "command": "npx",
      "args": ["tsx", "mcp-servers/db-server/index.ts"]
    }
  }
}
```

## 실전 시나리오: 도구 체인 활용

AI 에이전트가 3개 서버를 조합해서 작업하는 시나리오예요.

### 시나리오 1: 코드 변경 → DB 마이그레이션

| 단계 | 사용 도구 | 동작 |
|------|----------|------|
| 1 | `db_schema` | 현재 DB 스키마 확인 |
| 2 | `read_file` | 기존 마이그레이션 파일 확인 |
| 3 | `write_file` | 새 마이그레이션 SQL 작성 |
| 4 | `db_execute` | 마이그레이션 실행 |
| 5 | `git_diff` | 변경사항 확인 |

### 시나리오 2: 버그 조사 → 수정

| 단계 | 사용 도구 | 동작 |
|------|----------|------|
| 1 | `git_log` | 최근 커밋에서 관련 변경 찾기 |
| 2 | `git_blame_summary` | 문제 파일의 수정 이력 확인 |
| 3 | `read_file` | 현재 코드 확인 |
| 4 | `db_query` | 데이터 상태 확인 |
| 5 | `write_file` | 버그 수정 코드 작성 |

### 시나리오 3: 새 기능 추가

```
사용자: "users 테이블에 role 필드를 추가하고, 관련 API 엔드포인트를 만들어줘"

에이전트 실행 과정:
1. db_schema → 현재 users 테이블 구조 파악
2. write_file → migrations/002_add_role.sql 작성
3. db_execute → ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user'
4. read_file → 기존 API 코드 확인
5. write_file → src/routes/users.ts 업데이트
6. git_diff → 전체 변경사항 리뷰
```

## 도구 키트 확장하기

### 커스텀 MCP 서버 추가 방법

새로운 도구가 필요하면 같은 패턴으로 MCP 서버를 추가할 수 있어요.

```typescript
// mcp-servers/custom-server/index.ts — 기본 템플릿
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "custom-server",
  version: "1.0.0",
});

// 도구 정의
server.tool(
  "tool_name",        // 도구 이름 (에이전트가 호출할 식별자)
  "도구 설명",          // 에이전트가 도구를 선택할 때 참고하는 설명
  {
    param1: z.string().describe("파라미터 설명"),
  },
  async ({ param1 }) => {
    // 도구 로직
    return {
      content: [{ type: "text", text: "결과" }],
    };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

### 자주 추가하는 도구 목록

| 도구 | 용도 | npm 패키지 |
|------|------|-----------|
| HTTP 클라이언트 | 외부 API 호출 | `undici` |
| Docker 제어 | 컨테이너 관리 | `dockerode` |
| Redis 캐시 | 캐시 조회/설정 | `ioredis` |
| 로그 분석 | 로그 파일 파싱 | `tail` |
| 환경변수 관리 | .env 읽기/쓰기 | `dotenv` |

## 문제 해결

| 문제 | 해결 |
|------|------|
| MCP 서버 연결 실패 | `npx tsx mcp-servers/xxx/index.ts`로 직접 실행해서 에러 확인 |
| 도구가 목록에 안 보임 | `.claude/settings.local.json` 경로 확인, Claude Code 재시작 |
| 파일 접근 거부 | `PROJECT_ROOT` 환경변수가 올바른 경로인지 확인 |
| DB 쿼리 실패 | `DB_PATH`가 실제 SQLite 파일을 가리키는지 확인 |
| Git 서버 에러 | `REPO_PATH`가 `.git`이 있는 디렉토리인지 확인 |

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| MCP 서버 추가 | `"Redis MCP 서버를 같은 패턴으로 만들어줘"` |
| 도구 테스트 | `"filesystem 서버의 read_file 도구로 package.json 읽어봐"` |
| 스키마 변경 | `"DB 스키마 확인하고 필요한 마이그레이션 만들어줘"` |
| 코드 탐색 | `"git 히스토리에서 auth 관련 변경사항 찾아줘"` |
| 전체 파이프라인 | `"현재 DB 상태 보고, 새 API 엔드포인트 코드 작성해줘"` |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
