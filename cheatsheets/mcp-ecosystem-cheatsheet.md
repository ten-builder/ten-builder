# MCP 생태계 치트시트

> Model Context Protocol 주요 서버와 도구 한눈에 보기 — 카테고리별 정리

## MCP란?

MCP(Model Context Protocol)는 AI 코딩 도구가 외부 데이터 소스와 표준화된 방식으로 연결되는 프로토콜이에요. USB-C가 다양한 기기를 하나의 포트로 연결하듯, MCP는 AI 에이전트가 파일시스템, DB, API 등에 일관된 인터페이스로 접근할 수 있게 해줘요.

## 아키텍처 구조

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  AI Client  │────▶│  MCP Server │────▶│  Data Source │
│ (Claude,    │ MCP │ (로컬/원격)   │     │ (DB, API,   │
│  Cursor 등) │ ◀───│             │ ◀───│  파일 등)     │
└─────────────┘     └─────────────┘     └─────────────┘
```

| 구성 요소 | 역할 |
|----------|------|
| Host | MCP 커넥션을 관리하는 앱 (Claude Desktop, IDE) |
| Client | Host 내부에서 서버와 1:1 연결 유지 |
| Server | 특정 기능을 노출하는 경량 프로그램 |

## 카테고리별 인기 MCP 서버

### 개발 도구

| 서버 | 용도 | 설치 |
|------|------|------|
| `@modelcontextprotocol/server-github` | GitHub 이슈, PR, 코드 검색 | `npx -y @modelcontextprotocol/server-github` |
| `@modelcontextprotocol/server-gitlab` | GitLab 프로젝트/MR 관리 | `npx -y @modelcontextprotocol/server-gitlab` |
| `@anthropics/mcp-server-linear` | Linear 이슈 트래킹 연동 | `npx -y @anthropics/mcp-server-linear` |
| `mcp-server-kubernetes` | K8s 클러스터 조회/관리 | `pip install mcp-server-kubernetes` |

### 데이터베이스

| 서버 | 용도 | 설치 |
|------|------|------|
| `@modelcontextprotocol/server-postgres` | PostgreSQL 쿼리/스키마 탐색 | `npx -y @modelcontextprotocol/server-postgres` |
| `@modelcontextprotocol/server-sqlite` | SQLite DB 조회/분석 | `npx -y @modelcontextprotocol/server-sqlite` |
| `mcp-server-mysql` | MySQL 연동 | `npx -y mcp-server-mysql` |
| `mcp-mongo-server` | MongoDB 컬렉션 탐색 | `npx -y mcp-mongo-server` |

### 파일 & 지식

| 서버 | 용도 | 설치 |
|------|------|------|
| `@modelcontextprotocol/server-filesystem` | 로컬 파일 읽기/쓰기 | `npx -y @modelcontextprotocol/server-filesystem` |
| `@modelcontextprotocol/server-memory` | 영속적 지식 그래프 | `npx -y @modelcontextprotocol/server-memory` |
| `@anthropics/mcp-server-fetch` | 웹 페이지 가져오기/변환 | `npx -y @anthropics/mcp-server-fetch` |
| `@anthropics/mcp-server-gdrive` | Google Drive 파일 접근 | `npx -y @anthropics/mcp-server-gdrive` |

### 인프라 & DevOps

| 서버 | 용도 | 설치 |
|------|------|------|
| `mcp-server-terraform` | Terraform 상태/플랜 관리 | `pip install mcp-server-terraform` |
| `mcp-server-azure-devops` | Azure DevOps 파이프라인 | `npx -y mcp-server-azure-devops` |
| `@modelcontextprotocol/server-docker` | Docker 컨테이너 관리 | `npx -y @modelcontextprotocol/server-docker` |
| `mcp-server-aws` | AWS 리소스 조회/관리 | `pip install mcp-server-aws` |

### 커뮤니케이션 & 생산성

| 서버 | 용도 | 설치 |
|------|------|------|
| `@modelcontextprotocol/server-slack` | Slack 메시지/채널 연동 | `npx -y @modelcontextprotocol/server-slack` |
| `@anthropics/mcp-server-notion` | Notion 페이지/DB 접근 | `npx -y @anthropics/mcp-server-notion` |
| `mcp-server-obsidian` | Obsidian 볼트 탐색 | `npx -y mcp-server-obsidian` |

## Claude Desktop 설정 예시

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"],
      "env": {}
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "<your-token>"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"],
      "env": {}
    }
  }
}
```

**설정 파일 위치:**
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

## Claude Code에서 MCP 사용

```bash
# 서버 추가
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxx -- \
  npx -y @modelcontextprotocol/server-github

# 프로젝트 범위 (.mcp.json)
claude mcp add --scope project postgres -- \
  npx -y @modelcontextprotocol/server-postgres postgresql://localhost/mydb

# 등록된 서버 확인
claude mcp list

# 서버 제거
claude mcp remove github
```

## 원격 MCP 서버 (Streamable HTTP)

2026년부터 원격 MCP 서버가 본격적으로 확산되고 있어요. 로컬 설치 없이 URL만으로 연결할 수 있어요.

```json
{
  "mcpServers": {
    "remote-tool": {
      "type": "url",
      "url": "https://mcp.example.com/sse",
      "headers": {
        "Authorization": "Bearer <token>"
      }
    }
  }
}
```

| 전송 방식 | 특징 | 적합한 경우 |
|----------|------|-----------|
| stdio | 로컬 프로세스, 설정 간편 | 개인 개발 환경 |
| SSE | HTTP 기반, 방화벽 친화적 | 팀 공유 서버 |
| Streamable HTTP | 최신 표준, 양방향 | SaaS형 MCP 서비스 |

## MCP 게이트웨이

여러 MCP 서버를 중앙에서 관리하고 보안 정책을 적용하는 게이트웨이도 등장했어요.

| 게이트웨이 | 특징 |
|-----------|------|
| Bifrost | 오픈소스, 토큰 레벨 접근 제어 |
| ContextForge | 엔터프라이즈급 감사 로깅 |
| Traefik Hub MCP | 기존 Traefik 인프라와 통합 |

**게이트웨이가 필요한 경우:**
- 팀원별로 다른 접근 권한이 필요할 때
- MCP 서버 호출을 감사 로그로 남겨야 할 때
- 여러 AI 클라이언트가 같은 서버 풀을 공유할 때

## 커스텀 MCP 서버 만들기 (5분 코스)

```typescript
// server.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "my-tool", version: "1.0.0" });

server.tool("greet", { name: z.string() }, async ({ name }) => ({
  content: [{ type: "text", text: `Hello, ${name}!` }],
}));

const transport = new StdioServerTransport();
await server.connect(transport);
```

```bash
# 실행
npx tsx server.ts
```

## 서버 선택 가이드

```
필요한 기능이 뭔가요?
│
├─ 코드/이슈 관리 → GitHub/GitLab 서버
├─ DB 쿼리 실행 → Postgres/SQLite 서버
├─ 파일 접근 → Filesystem 서버
├─ 외부 API 호출 → Fetch 서버 또는 커스텀 서버
├─ 팀 협업 도구 → Slack/Notion 서버
└─ 특수 요구사항 → 커스텀 서버 직접 구현
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 환경변수 누락으로 서버 시작 실패 | `env` 블록에 필요한 토큰/URL 확인 |
| npx 캐시 문제로 구버전 실행 | `npx -y`로 항상 최신 버전 설치 |
| 파일시스템 서버 경로 권한 오류 | 허용할 디렉토리를 args에 명시 |
| 원격 서버 타임아웃 | `timeout` 설정 추가, 네트워크 확인 |
| 여러 서버 동시 사용 시 충돌 | 서버별 독립 프로세스로 실행됨 (충돌 없음) |

---

**더 자세한 가이드:** [workflows/custom-mcp-server.md](../workflows/custom-mcp-server.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
