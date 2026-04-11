# 플레이북 45: 커스텀 MCP 서버 빌드 및 배포

> Node.js + TypeScript로 MCP 서버를 직접 만들고 Cloudflare Workers에 배포하는 단계별 플레이북 — 도구 설계, 인증, 프로덕션 배포까지

## 소요 시간

60-90분

## 사전 준비

- Node.js 20+, pnpm 설치
- Cloudflare 계정 (무료 플랜으로 충분)
- Wrangler CLI 설치: `pnpm install -g wrangler`
- MCP SDK: `@modelcontextprotocol/sdk`

---

## Step 1: 프로젝트 초기화

```bash
mkdir my-mcp-server && cd my-mcp-server
pnpm init
pnpm add @modelcontextprotocol/sdk zod
pnpm add -D typescript @types/node wrangler
npx tsc --init
```

`package.json` 핵심 설정:

```json
{
  "name": "@myorg/my-mcp-server",
  "version": "1.0.0",
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "dev": "wrangler dev",
    "deploy": "wrangler deploy"
  }
}
```

`tsconfig.json`에서 반드시 확인할 항목:

| 설정 | 값 | 이유 |
|------|-----|------|
| `module` | `ESNext` | Cloudflare Workers ESM 필수 |
| `target` | `ES2022` | 최신 JS 기능 활용 |
| `strict` | `true` | 타입 안전성 확보 |
| `outDir` | `./dist` | 빌드 결과물 분리 |

---

## Step 2: 서버 뼈대 구성

`src/index.ts`:

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "my-mcp-server",
  version: "1.0.0",
});

// 도구 등록
server.tool(
  "search_documents",
  "문서를 키워드로 검색합니다",
  {
    query: z.string().describe("검색할 키워드"),
    limit: z.number().optional().default(5).describe("최대 결과 수"),
  },
  async ({ query, limit }) => {
    // 실제 로직 구현
    const results = await searchDocs(query, limit);
    return {
      content: [{ type: "text", text: JSON.stringify(results) }],
    };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

**도구 설계 원칙:**

| 원칙 | 설명 |
|------|------|
| 단일 책임 | 도구 하나당 명확한 기능 1개 |
| Zod 검증 | 모든 입력 파라미터에 스키마 명시 |
| 에러 반환 | 예외 대신 `isError: true` 응답 |
| 설명 문구 | description이 AI 도구 선택에 직접 영향 |

---

## Step 3: Cloudflare Workers 배포 설정

```bash
pnpm create cloudflare@latest
# "Hello World example" → TypeScript 선택
```

`wrangler.toml`:

```toml
name = "my-mcp-server"
main = "src/index.ts"
compatibility_date = "2026-04-01"
compatibility_flags = ["nodejs_compat"]

[vars]
MCP_SERVER_NAME = "my-mcp-server"

[[kv_namespaces]]
binding = "STORAGE"
id = "your-kv-namespace-id"
```

Cloudflare Workers용 진입점 (`src/worker.ts`):

```typescript
import { McpAgent } from "agents/mcp";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

export class MyMcpAgent extends McpAgent {
  server = new McpServer({ name: "my-mcp-server", version: "1.0.0" });

  async init() {
    // 도구 등록 (Step 2와 동일)
    this.server.tool("search_documents", "...", schema, handler);
  }
}

export default {
  fetch(request: Request, env: Env, ctx: ExecutionContext) {
    const url = new URL(request.url);
    if (url.pathname === "/sse" || url.pathname === "/message") {
      return MyMcpAgent.serve("/sse").fetch(request, env, ctx);
    }
    return new Response("Not found", { status: 404 });
  },
};
```

---

## Step 4: 인증 설정 (OAuth 2.1)

프로덕션 배포 시 인증 없이 노출하면 안 돼요. OAuth 2.1 + PKCE를 기본으로 설정해요:

```typescript
import { WorkerOAuthProvider } from "workers-oauth-provider";

const oauthProvider = new WorkerOAuthProvider({
  apiRoute: "/sse",
  apiHandler: MyMcpAgent.serve("/sse"),
  defaultHandler: async (req) => new Response("Unauthorized", { status: 401 }),
  authorizeEndpoint: "/authorize",
  tokenEndpoint: "/token",
  clientRegistrationEndpoint: "/register",
});

export default { fetch: oauthProvider.fetch.bind(oauthProvider) };
```

**인증 레이어 체크리스트:**

- [ ] Bearer 토큰 만료 시간 설정 (권장: 1시간)
- [ ] PKCE (Proof Key for Code Exchange) 활성화
- [ ] Scope 기반 도구 접근 제어
- [ ] Rate limiting 설정 (Cloudflare Rate Limiting 규칙 활용)
- [ ] 환경변수로 시크릿 관리 (`wrangler secret put API_KEY`)

---

## Step 5: 배포 및 검증

```bash
# 로컬 테스트
wrangler dev

# 프로덕션 배포
wrangler deploy

# 배포 확인
curl -X POST https://my-mcp-server.your-subdomain.workers.dev/message \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

Claude Desktop에 원격 MCP 서버 연결 (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "my-mcp-server": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://my-mcp-server.your-subdomain.workers.dev/sse"
      ]
    }
  }
}
```

---

## 체크리스트

- [ ] Zod 스키마로 모든 입력값 검증
- [ ] 에러 응답에 `isError: true` 포함
- [ ] 환경변수로 시크릿 관리 (`wrangler secret`)
- [ ] OAuth 2.1 PKCE 인증 활성화
- [ ] Rate limiting 규칙 설정
- [ ] `wrangler deploy` 완료 및 URL 확인
- [ ] Claude Desktop 연결 테스트 완료

## 문제 해결

| 문제 | 해결 |
|------|------|
| `Cannot use import statement` | `tsconfig.json`의 `module`을 `ESNext`로 변경 |
| Cloudflare Workers에서 `require` 에러 | `compatibility_flags = ["nodejs_compat"]` 추가 |
| OAuth 토큰 만료 오류 | 토큰 갱신 로직 (refresh token) 구현 |
| 도구가 AI에 노출되지 않음 | `description` 필드 구체적으로 재작성 |
| KV 읽기 실패 | `wrangler.toml`의 `kv_namespaces` binding 확인 |

## 다음 단계

→ [플레이북 38: AI 코딩 도구 비용 최적화](./38-cost-optimization-playbook.md)  
→ [치트시트: MCP 프로덕션 보안 운영](../../cheatsheets/mcp-production-security-cheatsheet.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
