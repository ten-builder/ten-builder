# 커스텀 MCP 서버 구축 워크플로우

> Claude Code에 나만의 도구를 연결하는 MCP 서버를 직접 만들어요

## 개요

Model Context Protocol(MCP)은 AI 코딩 도구에 외부 데이터와 기능을 연결하는 표준 프로토콜이에요. 공식 MCP 서버도 많지만, 팀 내부 API나 사내 시스템에 맞는 도구는 직접 만들어야 할 때가 있어요. 이 워크플로우에서는 TypeScript와 Python 두 가지 방법으로 커스텀 MCP 서버를 만들고, Claude Code에 연결하는 전체 과정을 다뤄요.

## 사전 준비

- Node.js 18+ 또는 Python 3.10+
- Claude Code CLI 설치 완료
- MCP의 기본 개념 이해 (tools, resources, prompts)

## 설정

### Step 1: 프로젝트 초기화 (TypeScript)

TypeScript로 MCP 서버를 만들 때는 `@modelcontextprotocol/sdk`를 사용해요:

```bash
mkdir my-mcp-server && cd my-mcp-server
npm init -y
npm install @modelcontextprotocol/sdk zod
npm install -D typescript @types/node
npx tsc --init
```

`tsconfig.json`에서 핵심 설정을 맞춰요:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "./dist",
    "strict": true
  }
}
```

### Step 2: 서버 코드 작성

`src/index.ts` 파일을 만들어요. 여기서는 예시로 GitHub 이슈를 조회하는 도구를 만들어 볼게요:

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "my-github-tools",
  version: "1.0.0",
});

// Tool 정의: GitHub 이슈 목록 조회
server.tool(
  "list_issues",
  "GitHub 레포의 이슈 목록을 가져옵니다",
  {
    owner: z.string().describe("레포 소유자"),
    repo: z.string().describe("레포 이름"),
    state: z.enum(["open", "closed", "all"]).default("open"),
  },
  async ({ owner, repo, state }) => {
    const res = await fetch(
      `https://api.github.com/repos/${owner}/${repo}/issues?state=${state}`,
      { headers: { "User-Agent": "mcp-server" } }
    );
    const issues = await res.json();
    const summary = issues.slice(0, 10).map((i: any) =>
      `#${i.number} ${i.title} (${i.state})`
    );
    return {
      content: [{ type: "text", text: summary.join("\n") }],
    };
  }
);

// Resource 정의: 프로젝트 컨벤션 문서
server.resource(
  "conventions",
  "project://conventions",
  async (uri) => ({
    contents: [{
      uri: uri.href,
      mimeType: "text/markdown",
      text: "# 코딩 컨벤션\n- 변수명: camelCase\n- 함수명: 동사로 시작",
    }],
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

### Step 3: Python으로 만들기

Python이 더 편하다면 `mcp` 패키지를 사용해요:

```bash
pip install mcp
```

```python
# server.py
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-tools")

@mcp.tool()
def search_docs(query: str, limit: int = 5) -> str:
    """사내 문서를 검색합니다"""
    # 실제로는 Elasticsearch, Notion API 등 연동
    results = [
        {"title": "온보딩 가이드", "url": "/docs/onboarding"},
        {"title": "API 스펙 v2", "url": "/docs/api-v2"},
    ]
    filtered = [r for r in results if query.lower() in r["title"].lower()]
    return "\n".join(f"- [{r['title']}]({r['url']})" for r in filtered[:limit])

@mcp.tool()
def create_ticket(title: str, description: str, priority: str = "medium") -> str:
    """내부 이슈 트래커에 티켓을 생성합니다"""
    # Jira, Linear 등 연동
    return f"티켓 생성 완료: {title} (우선순위: {priority})"

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

## 사용 방법

### Claude Code에 MCP 서버 등록

프로젝트 루트의 `.mcp.json` 파일에 서버를 등록해요:

```json
{
  "mcpServers": {
    "my-github-tools": {
      "command": "node",
      "args": ["dist/index.js"],
      "cwd": "/path/to/my-mcp-server"
    },
    "my-python-tools": {
      "command": "python",
      "args": ["server.py"],
      "cwd": "/path/to/my-python-tools"
    }
  }
}
```

글로벌로 등록하려면 `~/.claude.json`에 같은 형식으로 추가하면 돼요.

### 등록 확인

Claude Code에서 `/mcp` 명령어로 연결 상태를 확인할 수 있어요:

```bash
claude mcp list
# my-github-tools: connected
# my-python-tools: connected
```

### 실제 사용 시나리오

서버가 연결되면 Claude Code 대화에서 자연스럽게 도구를 호출할 수 있어요:

```
> 우리 레포의 열린 이슈 목록 보여줘
→ list_issues 도구가 자동으로 호출됨

> "로그인 버그" 티켓을 높은 우선순위로 만들어줘
→ create_ticket 도구가 자동으로 호출됨
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `transport` | `stdio` | 통신 방식 (stdio, SSE, streamable-http) |
| `timeout` | 30초 | 도구 실행 타임아웃 |
| `env` | - | 서버에 전달할 환경변수 (API 키 등) |
| `args` | - | 서버 실행 시 전달할 인자 |

### 환경변수로 API 키 전달

`.mcp.json`에서 `env` 필드를 사용하면 서버에 안전하게 시크릿을 전달할 수 있어요:

```json
{
  "mcpServers": {
    "my-tools": {
      "command": "node",
      "args": ["dist/index.js"],
      "env": {
        "JIRA_API_TOKEN": "your-token-here",
        "NOTION_API_KEY": "secret_xxx"
      }
    }
  }
}
```

### 디버깅 팁

개발 중에는 MCP Inspector로 서버를 테스트하면 편해요:

```bash
npx @modelcontextprotocol/inspector node dist/index.js
# 브라우저에서 http://localhost:5173 으로 도구 테스트 가능
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| 서버가 연결되지 않음 | `command` 경로가 정확한지, 빌드가 완료되었는지 확인 |
| 도구가 목록에 안 보임 | `server.tool()` 등록 후 서버 재시작. Claude Code도 재시작 필요 |
| 타임아웃 에러 | 외부 API 호출 시 에러 핸들링 추가, timeout 값 조정 |
| Python 서버 import 에러 | `pip install mcp` 버전 확인 (1.0+ 필요) |
| stdio 통신 깨짐 | `console.log` 대신 `console.error`로 디버그 출력 (stdout은 MCP가 사용) |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
