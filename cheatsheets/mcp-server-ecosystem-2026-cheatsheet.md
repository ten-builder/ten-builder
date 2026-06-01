# MCP 서버 생태계 2026 치트시트 — 카테고리별 필수 서버 50+ 정리

> Claude Code, Cursor, VS Code에서 바로 연결할 수 있는 MCP 서버를 카테고리별로 정리한 한 페이지 참조 가이드

## MCP 서버란?

Model Context Protocol(MCP) 서버는 AI 에이전트가 외부 도구·데이터베이스·서비스를 직접 호출할 수 있도록 표준화된 인터페이스를 제공합니다. 2026년 기준 공식 디렉토리(mcp.directory)에 2,000개 이상의 서버가 등록되어 있어요.

## 기본 연결 설정

```json
// claude_desktop_config.json (Claude Code)
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..." }
    }
  }
}
```

## 카테고리별 필수 서버

### 개발 도구 (Dev Tools)

| 서버 | 설치 | 주요 기능 |
|------|------|-----------|
| **GitHub** | `@modelcontextprotocol/server-github` | PR/이슈 생성, 코드 검색, Actions 실행 |
| **Linear** | `@linear/mcp-server` | 이슈 생성·조회, 스프린트 관리, 팀 동기화 |
| **GitLab** | `@modelcontextprotocol/server-gitlab` | MR, 파이프라인, 저장소 관리 |
| **Jira** | `@atlassian/mcp-server-jira` | 티켓 생성·업데이트, 백로그 조회 |

```bash
# GitHub MCP 빠른 연결
claude mcp add github --command "npx -y @modelcontextprotocol/server-github"
```

### 브라우저 & 테스트

| 서버 | 설치 | 주요 기능 |
|------|------|-----------|
| **Playwright** | `@playwright/mcp-server` | E2E 테스트, 스크린샷, 폼 자동화 |
| **Puppeteer** | `@modelcontextprotocol/server-puppeteer` | 헤드리스 브라우저 제어 |
| **Browserbase** | `@browserbasehq/mcp-server` | 클라우드 브라우저 세션 |

```bash
# Playwright로 E2E 스크린샷 자동 촬영
claude mcp add playwright --command "npx @playwright/mcp-server"
```

### 데이터베이스

| 서버 | 설치 | 주요 기능 |
|------|------|-----------|
| **PostgreSQL** | `@modelcontextprotocol/server-postgres` | 스키마 조회, SQL 실행, 쿼리 분석 |
| **MySQL** | `@modelcontextprotocol/server-mysql` | 테이블 검색, 데이터 조회 |
| **MongoDB** | `@modelcontextprotocol/server-mongodb` | 도큐먼트 CRUD, 어그리게이션 |
| **Supabase** | `@supabase/mcp-server-supabase` | 인증·스토리지·Functions 통합 |
| **SQLite** | `@modelcontextprotocol/server-sqlite` | 로컬 DB 빠른 프로토타이핑 |

### 커뮤니케이션 & 협업

| 서버 | 설치 | 주요 기능 |
|------|------|-----------|
| **Slack** | `@slack/mcp-server` | 채널 메시지 전송, 스레드 요약 |
| **Notion** | `@notionhq/mcp-server` | 페이지 생성·검색, 데이터베이스 쿼리 |
| **Google Drive** | `@modelcontextprotocol/server-gdrive` | 파일 검색, 문서 읽기/쓰기 |
| **Gmail** | `@modelcontextprotocol/server-gmail` | 이메일 조회·전송, 라벨 관리 |

### 모니터링 & 오류 추적

| 서버 | 설치 | 주요 기능 |
|------|------|-----------|
| **Sentry** | `@sentry/mcp-server` | 에러 조회, 스택 트레이스 분석 |
| **Datadog** | `@datadog/mcp-server` | 메트릭·로그 조회, 알림 설정 |
| **Grafana** | `@grafana/mcp-server` | 대시보드 쿼리, 패널 데이터 추출 |

```bash
# Sentry 에러 컨텍스트 바로 조회
claude mcp add sentry \
  --command "npx @sentry/mcp-server" \
  --env "SENTRY_AUTH_TOKEN=sntrys_..."
```

### 디자인 & UI

| 서버 | 설치 | 주요 기능 |
|------|------|-----------|
| **Figma** | `@figma/mcp-server` | 프레임 링크 → 코드 자동 생성 |
| **Storybook** | `@storybook/mcp-server` | 컴포넌트 목록, 스토리 조회 |

### AI & 검색

| 서버 | 설치 | 주요 기능 |
|------|------|-----------|
| **Brave Search** | `@modelcontextprotocol/server-brave-search` | 실시간 웹 검색 |
| **Tavily** | `@tavily/mcp-server` | 심층 검색·연구 자동화 |
| **Claude Context** | `@anthropic/claude-context-mcp` | 수백만 줄 코드 시맨틱 검색 |

### 파일 & 스토리지

| 서버 | 설치 | 주요 기능 |
|------|------|-----------|
| **Filesystem** | `@modelcontextprotocol/server-filesystem` | 로컬 파일 읽기/쓰기/검색 |
| **AWS S3** | `@modelcontextprotocol/server-s3` | 버킷 탐색, 파일 업로드/다운로드 |
| **Cloudflare R2** | `@cloudflare/mcp-server` | R2 스토리지 + KV + D1 통합 |

## 설정 패턴

### 프로젝트별 MCP 설정 분리

```json
// .mcp.json (프로젝트 루트)
{
  "mcpServers": {
    "github": { /* ... */ },
    "linear": { /* ... */ },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": { "POSTGRES_URL": "postgresql://localhost/mydb" }
    }
  }
}
```

### alwaysLoad로 자동 연결

```json
// claude_desktop_config.json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..." },
      "alwaysLoad": true
    }
  }
}
```

> `alwaysLoad: true` 설정 시 세션 시작마다 자동 연결됩니다 (Claude Code v2.1.122+).

## 자주 쓰는 조합 패턴

| 목적 | 조합 |
|------|------|
| 이슈 → 코드 → PR | GitHub + Linear |
| 풀스택 개발 | GitHub + Supabase + Figma |
| 모니터링 대응 | Sentry + Datadog + Slack |
| 문서 자동화 | GitHub + Notion + Google Drive |
| E2E 테스트 자동화 | Playwright + GitHub Actions |
| 데이터 파이프라인 | PostgreSQL + AWS S3 + Slack |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 서버 연결 실패 | `claude mcp list`로 상태 확인, `npx`가 최신 버전인지 확인 |
| 인증 오류 | `.env` 파일에 토큰 재설정, 만료 여부 확인 |
| 느린 응답 | `timeout` 값 늘리기 (기본 30초), 로컬 서버 우선 사용 |
| 도구 미노출 | 서버 재시작 (`claude mcp restart <name>`) |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
