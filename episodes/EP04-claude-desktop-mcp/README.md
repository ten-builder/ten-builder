# EP04: Claude Desktop + MCP — AI에게 도구를 쥐여주는 법

> Claude Desktop에 MCP 서버를 연결해서 파일 시스템, 데이터베이스, API까지 자유롭게 다루는 실전 가이드

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- MCP(Model Context Protocol)가 뭔지, 왜 필요한지
- Claude Desktop에서 MCP 서버를 설정하는 방법
- 파일 시스템, GitHub, 데이터베이스 MCP 서버 실전 연결
- 나만의 커스텀 MCP 서버를 만드는 기본 구조

## MCP가 뭔가요?

MCP는 Anthropic이 만든 오픈 프로토콜이에요. 쉽게 말하면 **AI에게 도구를 연결하는 표준 규격**이죠.

기존에는 AI에게 뭔가를 시키려면 매번 프롬프트에 데이터를 복사해서 붙여넣어야 했어요. MCP를 쓰면 AI가 직접 파일을 읽고, API를 호출하고, 데이터베이스를 조회할 수 있어요.

```
┌──────────────┐     MCP 프로토콜     ┌──────────────┐
│ Claude       │ ◄──────────────────► │ MCP 서버     │
│ Desktop      │   JSON-RPC 통신      │ (도구 제공)   │
└──────────────┘                      └──────────────┘
                                            │
                                      ┌─────┴─────┐
                                      │ 파일시스템  │
                                      │ GitHub     │
                                      │ DB         │
                                      └───────────┘
```

## 핵심 설정 & 코드

### Step 1: Claude Desktop 설치 및 MCP 활성화

Claude Desktop을 설치한 뒤, 설정 파일을 열어야 해요.

```bash
# macOS 기준 설정 파일 위치
code ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### Step 2: 파일 시스템 MCP 서버 연결

가장 기본적인 MCP 서버예요. Claude가 로컬 파일을 직접 읽고 쓸 수 있게 해줘요.

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/me/projects",
        "/Users/me/documents"
      ]
    }
  }
}
```

| 설정 항목 | 설명 |
|-----------|------|
| `command` | 실행할 명령어 (npx, python, node 등) |
| `args` | 명령어 인자 — 접근 허용할 디렉토리 경로 포함 |
| `env` | 환경 변수 (API 키 등을 전달할 때 사용) |

### Step 3: GitHub MCP 서버 추가

레포 관리, 이슈 생성, PR 리뷰를 Claude에게 맡길 수 있어요.

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxxxxxxxxx"
      }
    }
  }
}
```

### Step 4: PostgreSQL MCP 서버

데이터베이스를 연결하면 Claude가 스키마를 분석하고 쿼리를 작성해줘요.

```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-postgres",
        "postgresql://user:password@localhost:5432/mydb"
      ]
    }
  }
}
```

## 나만의 MCP 서버 만들기 (기본 구조)

공식 MCP 서버만 쓸 필요 없어요. 간단한 TypeScript로 나만의 도구를 만들 수 있어요.

```typescript
// my-mcp-server/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "my-tools",
  version: "1.0.0",
});

// 도구 등록: 현재 시각 반환
server.tool("current-time", "현재 시각을 반환합니다", {}, async () => {
  return {
    content: [
      {
        type: "text",
        text: new Date().toISOString(),
      },
    ],
  };
});

// 도구 등록: 환율 조회 (예시)
server.tool(
  "exchange-rate",
  "USD/KRW 환율을 조회합니다",
  { amount: z.number().describe("변환할 USD 금액") },
  async ({ amount }) => {
    const rate = 1380; // 실제로는 API 호출
    return {
      content: [
        {
          type: "text",
          text: `$${amount} = ₩${(amount * rate).toLocaleString()}`,
        },
      ],
    };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

```bash
# 패키지 초기화 및 의존성 설치
npm init -y
npm install @modelcontextprotocol/sdk zod

# Claude Desktop 설정에 추가
# "my-tools": {
#   "command": "npx",
#   "args": ["tsx", "/path/to/my-mcp-server/index.ts"]
# }
```

## 실전 활용 시나리오

| 시나리오 | 사용할 MCP 서버 | 프롬프트 예시 |
|----------|----------------|---------------|
| 프로젝트 파일 분석 | filesystem | `프로젝트 구조를 분석하고 README를 만들어줘` |
| PR 자동 리뷰 | github | `최근 PR을 확인하고 코드 리뷰해줘` |
| DB 스키마 파악 | postgres | `users 테이블 구조를 분석하고 최적화 제안해줘` |
| 슬랙 요약 | 커스텀 서버 | `오늘 #general 채널 요약해줘` |

## 자주 겪는 문제와 해결법

| 문제 | 원인 | 해결 |
|------|------|------|
| MCP 서버가 목록에 안 뜸 | 설정 후 재시작 안 함 | Claude Desktop 완전 종료 후 재시작 |
| `spawn npx ENOENT` 에러 | Node.js 경로 문제 | `command`를 절대 경로로 변경 (`/usr/local/bin/npx`) |
| 권한 에러 | 디렉토리 접근 제한 | `args`에 허용 디렉토리를 정확히 지정 |
| 도구 호출 시 타임아웃 | 서버 응답 지연 | MCP 서버 로그 확인 후 비동기 처리 점검 |

## 다음 단계

MCP 설정이 끝났다면 이런 것도 시도해 보세요:

- **Brave Search MCP**: 웹 검색 결과를 Claude에게 직접 전달
- **Puppeteer MCP**: 웹 브라우저 자동화
- **Memory MCP**: 대화 기억을 영구 저장
- 나만의 사내 도구를 MCP로 감싸서 연결

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
