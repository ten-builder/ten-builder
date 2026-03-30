# EP10: MCP 서버 직접 만들기 실전 — 나만의 AI 도구를 처음부터 구축하기

> 프로젝트 관리 도구를 MCP 서버로 연동하는 과정을 처음부터 끝까지 따라하는 핸즈온 에피소드

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- MCP(Model Context Protocol)의 구조와 동작 원리 이해
- TypeScript로 커스텀 MCP 서버를 처음부터 만들기
- 프로젝트 관리 도구와 연동하는 실전 Tool/Resource 구현
- Claude Desktop과 Cursor에서 직접 연결해서 테스트하기

## MCP가 뭔가요

AI 코딩 에이전트를 쓰다 보면 "이 데이터도 같이 참조하면 좋겠는데" 하는 순간이 와요. 예를 들어:

- Jira 이슈를 보면서 코드를 작성하고 싶다
- 사내 위키를 검색하면서 답변을 만들고 싶다
- DB 스키마를 조회하면서 마이그레이션을 짜고 싶다

MCP는 이런 연결을 표준화한 프로토콜이에요. REST API가 웹 서비스 간 통신을 표준화했듯이, MCP는 AI 에이전트와 외부 도구 간 통신을 표준화해요.

```
┌─────────────────┐     MCP Protocol     ┌─────────────────┐
│   AI 에이전트     │ ←──────────────────→ │   MCP 서버       │
│  (Claude, Cursor) │   Tool 호출/결과     │  (나만의 도구)    │
└─────────────────┘                       └─────────────────┘
                                                  │
                                           ┌──────┴──────┐
                                           │ DB, API,    │
                                           │ 파일시스템   │
                                           └─────────────┘
```

## MCP 서버의 3가지 기능

| 기능 | 설명 | 예시 |
|------|------|------|
| **Tools** | AI가 호출할 수 있는 함수 | `create_issue`, `search_docs` |
| **Resources** | AI가 읽을 수 있는 데이터 | `project://issues/123`, `wiki://page/setup` |
| **Prompts** | 미리 정의된 프롬프트 템플릿 | `summarize_sprint`, `review_pr` |

이번 에피소드에서는 **Tools**와 **Resources**를 집중적으로 다뤄요.

## 프로젝트 세팅

### Step 1: 프로젝트 초기화

```bash
mkdir mcp-project-manager && cd mcp-project-manager
npm init -y
npm install @modelcontextprotocol/sdk zod
npm install -D typescript @types/node tsx
npx tsc --init
```

### Step 2: tsconfig 설정

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"]
}
```

### Step 3: package.json 수정

```json
{
  "type": "module",
  "scripts": {
    "build": "tsc",
    "dev": "tsx src/index.ts"
  }
}
```

## MCP 서버 기본 구조

### Step 4: 서버 엔트리포인트 만들기

```typescript
// src/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// 간단한 인메모리 프로젝트 저장소
interface Task {
  id: string;
  title: string;
  status: "todo" | "in-progress" | "done";
  assignee?: string;
  priority: "low" | "medium" | "high";
  createdAt: string;
}

const tasks: Map<string, Task> = new Map();
let nextId = 1;

// MCP 서버 인스턴스 생성
const server = new McpServer({
  name: "project-manager",
  version: "1.0.0",
});
```

여기까지가 기본 뼈대예요. `McpServer` 인스턴스를 만들고, 데이터를 저장할 구조를 정의했어요.

## Tool 구현

### Step 5: 태스크 생성 Tool

```typescript
// 태스크 추가 Tool
server.tool(
  "create_task",
  "새 태스크를 생성합니다",
  {
    title: z.string().describe("태스크 제목"),
    assignee: z.string().optional().describe("담당자"),
    priority: z.enum(["low", "medium", "high"]).default("medium")
      .describe("우선순위"),
  },
  async ({ title, assignee, priority }) => {
    const id = `TASK-${nextId++}`;
    const task: Task = {
      id,
      title,
      status: "todo",
      assignee,
      priority,
      createdAt: new Date().toISOString(),
    };
    tasks.set(id, task);

    return {
      content: [
        {
          type: "text",
          text: `태스크 생성 완료: ${id} — "${title}" (${priority})`,
        },
      ],
    };
  }
);
```

핵심 포인트:
- `z.string()` 같은 Zod 스키마로 입력 파라미터를 정의해요
- `.describe()`로 AI에게 각 파라미터가 뭔지 알려줘요
- 반환값은 `content` 배열 — `text` 타입이 가장 기본이에요

### Step 6: 태스크 조회 Tool

```typescript
// 태스크 목록 조회 Tool
server.tool(
  "list_tasks",
  "태스크 목록을 조회합니다. 상태나 담당자로 필터링 가능",
  {
    status: z.enum(["todo", "in-progress", "done"]).optional()
      .describe("상태 필터"),
    assignee: z.string().optional().describe("담당자 필터"),
  },
  async ({ status, assignee }) => {
    let filtered = Array.from(tasks.values());

    if (status) {
      filtered = filtered.filter((t) => t.status === status);
    }
    if (assignee) {
      filtered = filtered.filter((t) => t.assignee === assignee);
    }

    if (filtered.length === 0) {
      return {
        content: [{ type: "text", text: "조건에 맞는 태스크가 없습니다." }],
      };
    }

    const table = filtered
      .map((t) =>
        `| ${t.id} | ${t.title} | ${t.status} | ${t.priority} | ${t.assignee ?? "-"} |`
      )
      .join("\n");

    return {
      content: [
        {
          type: "text",
          text: `| ID | 제목 | 상태 | 우선순위 | 담당자 |\n|---|---|---|---|---|\n${table}`,
        },
      ],
    };
  }
);
```

### Step 7: 태스크 상태 변경 Tool

```typescript
// 태스크 상태 업데이트 Tool
server.tool(
  "update_task_status",
  "태스크의 상태를 변경합니다",
  {
    taskId: z.string().describe("태스크 ID (예: TASK-1)"),
    status: z.enum(["todo", "in-progress", "done"]).describe("변경할 상태"),
  },
  async ({ taskId, status }) => {
    const task = tasks.get(taskId);
    if (!task) {
      return {
        content: [{ type: "text", text: `태스크 ${taskId}를 찾을 수 없습니다.` }],
        isError: true,
      };
    }

    const prevStatus = task.status;
    task.status = status;

    return {
      content: [
        {
          type: "text",
          text: `${taskId} 상태 변경: ${prevStatus} → ${status}`,
        },
      ],
    };
  }
);
```

`isError: true`를 반환하면 AI가 에러 상황을 인식하고 적절히 처리해요.

## Resource 구현

### Step 8: 프로젝트 대시보드 Resource

```typescript
// 프로젝트 요약 Resource
server.resource(
  "dashboard",
  "project://dashboard",
  { description: "프로젝트 전체 현황 대시보드", mimeType: "text/plain" },
  async () => {
    const all = Array.from(tasks.values());
    const todo = all.filter((t) => t.status === "todo").length;
    const inProgress = all.filter((t) => t.status === "in-progress").length;
    const done = all.filter((t) => t.status === "done").length;
    const highPriority = all.filter((t) => t.priority === "high" && t.status !== "done");

    let text = `# 프로젝트 대시보드\n\n`;
    text += `- 전체: ${all.length}건\n`;
    text += `- 할 일: ${todo}건 | 진행 중: ${inProgress}건 | 완료: ${done}건\n`;

    if (highPriority.length > 0) {
      text += `\n## 높은 우선순위 미완료\n`;
      highPriority.forEach((t) => {
        text += `- ${t.id}: ${t.title} (${t.status})\n`;
      });
    }

    return { contents: [{ uri: "project://dashboard", text, mimeType: "text/plain" }] };
  }
);
```

Resource는 AI가 직접 호출하는 게 아니라, 컨텍스트로 읽어가는 데이터예요. `project://dashboard` URI를 통해 접근해요.

## 서버 시작

### Step 9: Transport 연결

```typescript
// 서버 시작
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Project Manager MCP Server running on stdio");
}

main().catch(console.error);
```

`StdioServerTransport`는 표준 입출력을 통해 통신해요. Claude Desktop이나 Cursor가 이 프로세스를 직접 실행하고 stdin/stdout으로 대화하는 구조예요.

> `console.error`를 쓰는 이유: stdout은 MCP 프로토콜 통신에 사용되기 때문에, 로그는 반드시 stderr로 보내야 해요.

## AI 클라이언트 연결

### Claude Desktop 설정

```json
// ~/Library/Application Support/Claude/claude_desktop_config.json
{
  "mcpServers": {
    "project-manager": {
      "command": "npx",
      "args": ["tsx", "/path/to/mcp-project-manager/src/index.ts"]
    }
  }
}
```

### Cursor 설정

```json
// .cursor/mcp.json (프로젝트 루트)
{
  "mcpServers": {
    "project-manager": {
      "command": "npx",
      "args": ["tsx", "/path/to/mcp-project-manager/src/index.ts"]
    }
  }
}
```

### Claude Code (CLI) 설정

```bash
claude mcp add project-manager -- npx tsx /path/to/mcp-project-manager/src/index.ts
```

## 실전 사용 시나리오

연결이 되면 AI에게 이렇게 말할 수 있어요:

```
"TASK-1 ~ TASK-5까지 만들어줘. 
TASK-1은 로그인 API, TASK-2는 회원가입 UI, 
나머지는 적절히 만들어주고 우선순위도 배분해줘"
```

AI가 `create_task` Tool을 여러 번 호출하면서 태스크를 만들어요.

```
"지금 할 일 목록 보여줘"
```

AI가 `list_tasks`를 호출해서 테이블로 보여줘요.

```
"TASK-1 진행 중으로 바꾸고, 대시보드 전체 현황도 같이 보여줘"
```

`update_task_status`로 상태를 바꾸고, `project://dashboard` Resource를 읽어서 현황을 보여줘요.

## 실제 프로젝트에 적용하려면

인메모리 저장소는 데모용이에요. 실제로 쓰려면:

| 확장 포인트 | 방법 |
|-------------|------|
| **영구 저장** | SQLite, PostgreSQL 등 DB 연결 |
| **외부 API 연동** | Jira, Linear, Notion API 호출 |
| **인증** | OAuth2 또는 API 키 기반 인증 추가 |
| **에러 핸들링** | 타임아웃, 재시도, 폴백 로직 |
| **배포** | Docker 컨테이너 또는 원격 서버 (SSE transport) |

### SSE Transport로 원격 배포

로컬 stdio 대신 HTTP SSE로 배포하면 팀원들이 공유할 수 있어요:

```typescript
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import express from "express";

const app = express();

app.get("/sse", async (req, res) => {
  const transport = new SSEServerTransport("/messages", res);
  await server.connect(transport);
});

app.post("/messages", async (req, res) => {
  // SSE transport가 처리
});

app.listen(3001, () => {
  console.log("MCP Server running on http://localhost:3001");
});
```

## 흔한 실수와 해결

| 실수 | 원인 | 해결 |
|------|------|------|
| Tool이 목록에 안 나옴 | `server.tool()` 호출 전에 `connect()` 실행 | Tool 등록을 connect 전에 완료 |
| `stdout` 오염 | `console.log` 사용 | `console.error`로 변경 |
| 파라미터 타입 에러 | Zod 스키마 불일치 | `.describe()` 추가, optional 명시 |
| 클라이언트 연결 실패 | 경로 오류 | 절대 경로 사용, `npx tsx` 확인 |
| Resource가 비어있음 | URI 불일치 | 등록한 URI와 요청 URI 동일한지 확인 |

## 더 알아보기

- [MCP 공식 문서](https://modelcontextprotocol.io)
- [MCP SDK GitHub](https://github.com/modelcontextprotocol/typescript-sdk)
- [MCP 치트시트](../cheatsheets/mcp-quick-reference.md)
- [MCP 에코시스템 치트시트](../cheatsheets/mcp-ecosystem-cheatsheet.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
