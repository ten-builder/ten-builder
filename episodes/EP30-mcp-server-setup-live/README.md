# EP30: MCP 서버 10개 실시간 연동 — GitHub, Linear, Slack, Sentry 완전 통합

> Claude Code에서 MCP 서버 10개를 실시간으로 설치하고 조합해 GitHub-Linear-Slack-Sentry 완전 연동 개발 환경을 구성하는 라이브 코딩 에피소드

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- MCP 서버를 선택하는 기준과 Tier 분류법
- GitHub, Linear, Slack, Sentry MCP를 조합한 실전 개발 환경
- 글로벌 설정 vs 프로젝트별 설정 전략
- MCP 서버 10개를 라이브로 설치하고 실제로 쓰는 과정

## 왜 MCP 서버인가

Claude Code가 코드를 잘 작성하는 건 기본이에요. 그런데 실제 개발 환경은 코드만 있지 않아요.

- GitHub에 열려있는 PR, 이슈, CI 결과
- Linear 티켓에 적힌 요구사항
- Slack 스레드에 있는 컨텍스트
- Sentry에 쌓이는 프로덕션 오류

이 모든 것들이 Claude Code 세션 바깥에 있어요. MCP 서버는 이 장벽을 없애줘요. GitHub 이슈를 직접 조회하고, Linear 티켓을 닫고, Sentry 스택 트레이스를 가져와서 코드를 고치는 것을 한 세션 안에서 해낼 수 있어요.

```
┌──────────────────────────────────────────────────────────────┐
│                     Claude Code 세션                          │
│                                                              │
│  코드 작성 + GitHub PR + Linear 티켓 + Slack 알림 + Sentry   │
│         ↕             ↕           ↕           ↕             │
└──────────────────────────────────────────────────────────────┘
           │             │           │           │
       GitHub MCP   Linear MCP  Slack MCP  Sentry MCP
```

## MCP 서버 Tier 분류

이번 에피소드에서 설치하는 10개 서버를 용도별로 나눠봤어요.

| Tier | 서버 | 용도 | 필요도 |
|------|------|------|--------|
| **핵심** | GitHub | PR, 이슈, 코드 검색 | 거의 모든 프로젝트 |
| **핵심** | Context7 | 라이브러리 최신 문서 | 거의 모든 프로젝트 |
| **핵심** | Filesystem | 로컬 파일 탐색/수정 | Claude Code 기본 내장 |
| **협업** | Linear | 티켓 조회/생성/업데이트 | Linear 사용 팀 |
| **협업** | Slack | 채널 메시지 전송/조회 | Slack 사용 팀 |
| **모니터링** | Sentry | 오류 스택 트레이스 조회 | 프로덕션 운영 팀 |
| **개발** | Playwright | E2E 테스트, 브라우저 자동화 | 프론트엔드 포함 프로젝트 |
| **개발** | PostgreSQL | DB 스키마 조회, SQL 실행 | 백엔드 프로젝트 |
| **개발** | Figma | 디자인 → 코드 변환 | 디자인 협업 팀 |
| **문서** | Notion | 문서 조회/작성 | Notion 사용 팀 |

## 설치 전 준비

### 글로벌 vs 프로젝트 설정 선택 기준

```
글로벌 (~/.claude/settings.json)
  → 모든 프로젝트에서 쓰는 서버 (GitHub, Context7, Filesystem)

프로젝트 (.claude/settings.json)
  → 이 프로젝트에서만 쓰는 서버 (특정 DB, 특정 Slack 채널)
```

### API 키 준비

```bash
# GitHub Personal Access Token (repo, issues 권한)
# https://github.com/settings/tokens

# Linear API Key
# https://linear.app/settings/api

# Slack Bot Token (channels:read, chat:write 권한)
# https://api.slack.com/apps

# Sentry Auth Token
# https://sentry.io/settings/account/api/auth-tokens/
```

## Step 1: 핵심 서버 2개 먼저 (GitHub + Context7)

한 번에 10개를 설치하면 트러블슈팅이 어려워요. 핵심 2개부터 시작해요.

```bash
# GitHub MCP 추가
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxx \
  -- npx -y @modelcontextprotocol/server-github

# Context7 MCP 추가 (라이브러리 최신 문서)
claude mcp add context7 \
  -- npx -y @upstash/context7-mcp
```

**동작 확인:**

```
> claude
> /mcp
```

`github`, `context7` 두 개가 `connected` 상태로 보이면 성공이에요.

실제로 써보기:

```
사용자: 이 레포의 열려있는 PR 목록 보여줘

Claude: [GitHub MCP 호출]
현재 열린 PR:
#42 - feat: 다크모드 지원 (리뷰 대기 중)
#38 - fix: 로그인 오류 수정 (CI 통과)
...
```

## Step 2: 협업 서버 (Linear + Slack)

```bash
# Linear MCP
claude mcp add linear -e LINEAR_API_KEY=lin_api_xxx \
  -- npx -y @linear/mcp-server

# Slack MCP
claude mcp add slack \
  -e SLACK_BOT_TOKEN=xoxb-xxx \
  -e SLACK_TEAM_ID=T0XXXXXXX \
  -- npx -y @modelcontextprotocol/server-slack
```

**Linear + GitHub 조합 사용법:**

```
사용자: Linear에서 진행 중인 내 티켓 가져와서
        각각에 맞는 브랜치가 GitHub에 있는지 확인해줘

Claude: [Linear MCP → GitHub MCP 순서로 호출]
티켓 TEN-142: 다크모드 구현
  → GitHub 브랜치 feat/darkmode ✅ (PR #42)

티켓 TEN-156: 알림 설정 페이지
  → GitHub 브랜치 없음 ⚠️ 아직 시작 안 됨
```

**Slack 알림 연동:**

```
사용자: PR #42 머지되면 #dev-team 채널에 알려줘

Claude: [Slack MCP 호출]
#dev-team 채널에 메시지 전송 완료:
"PR #42 (feat: 다크모드 지원) 머지되었습니다 🎉"
```

## Step 3: 모니터링 서버 (Sentry)

```bash
# Sentry MCP
claude mcp add sentry \
  -e SENTRY_AUTH_TOKEN=sntryu_xxx \
  -e SENTRY_ORGANIZATION=my-org \
  -- npx -y @sentry/mcp-server-sentry
```

**Sentry → 코드 수정 워크플로:**

```
사용자: 오늘 Sentry에서 가장 많이 발생한 오류 보여줘

Claude: [Sentry MCP 호출]
1위 TypeError: Cannot read property 'user' of null
   - 발생 횟수: 847회
   - 최초 발생: 오전 3:12
   - 파일: src/components/ProfileCard.tsx:48

관련 코드 수정할까요?

사용자: 응, 고쳐줘

Claude: [파일 수정]
null 체크를 추가했어요:
- const name = user.name
+ const name = user?.name ?? '알 수 없음'
```

## Step 4: 개발 도구 서버 (Playwright + PostgreSQL)

```bash
# Playwright MCP (E2E 테스트, 브라우저 자동화)
claude mcp add playwright \
  -- npx -y @playwright/mcp

# PostgreSQL MCP
claude mcp add postgres \
  -e DATABASE_URL=postgresql://localhost/mydb \
  -- npx -y @modelcontextprotocol/server-postgres
```

**Playwright 활용 예:**

```
사용자: 로그인 플로우가 정상 동작하는지 확인해줘

Claude: [Playwright MCP 호출]
1. https://localhost:3000/login 접속 ✅
2. 이메일/비밀번호 입력 ✅
3. 로그인 버튼 클릭 ✅
4. /dashboard 리다이렉트 확인 ✅
로그인 플로우 정상 동작합니다.
```

## Step 5: 나머지 4개 (Figma + Notion + 추가 2개)

```bash
# Figma MCP
claude mcp add figma \
  -e FIGMA_API_KEY=figd_xxx \
  -- npx -y figma-developer-mcp

# Notion MCP
claude mcp add notion \
  -e NOTION_API_KEY=secret_xxx \
  -- npx -y @notionhq/notion-mcp-server
```

**Figma → 코드 변환:**

```
사용자: 이 Figma 프레임 보고 React 컴포넌트 만들어줘
        https://figma.com/file/xxx/frame/yyy

Claude: [Figma MCP 호출]
디자인을 분석했어요. ButtonGroup 컴포넌트를 만들게요.

export function ButtonGroup({ primary, secondary }: ButtonGroupProps) {
  return (
    <div className="flex gap-2">
      <button className="px-4 py-2 bg-blue-600 text-white rounded-lg">
        {primary}
      </button>
      <button className="px-4 py-2 border border-gray-300 rounded-lg">
        {secondary}
      </button>
    </div>
  )
}
```

## 설정 파일 최종 정리

```json
// ~/.claude/settings.json (글로벌 — 모든 프로젝트 공통)
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxx"
      }
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

```json
// .claude/settings.json (프로젝트별 — 이 레포에서만)
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "@linear/mcp-server"],
      "env": {
        "LINEAR_API_KEY": "lin_api_xxx"
      }
    },
    "sentry": {
      "command": "npx",
      "args": ["-y", "@sentry/mcp-server-sentry"],
      "env": {
        "SENTRY_AUTH_TOKEN": "sntryu_xxx",
        "SENTRY_ORGANIZATION": "my-org"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://localhost/mydb"
      }
    }
  }
}
```

## 자주 생기는 문제

| 문제 | 원인 | 해결 |
|------|------|------|
| MCP 서버가 `failed` 상태 | API 키 오류 또는 권한 부족 | `/mcp`로 오류 메시지 확인 |
| 서버가 너무 느림 | 너무 많은 서버 동시 실행 | 필요한 서버만 프로젝트별 설정으로 분리 |
| `npx -y` 매번 설치 | npm 캐시 문제 | 서버를 전역 설치 후 경로 직접 지정 |
| Slack 메시지 전송 실패 | Bot 권한 설정 부족 | `chat:write`, `channels:read` 권한 추가 |

## 라이브에서 배운 것

10개 서버를 한 번에 설치하고 나서 깨달은 것들이에요.

**1. 시작은 작게** — 처음에 2개로 시작해서 하나씩 추가하는 게 훨씬 안정적이에요. 한 번에 10개 설치하면 어디서 오류가 났는지 찾기 힘들어요.

**2. 글로벌 서버는 최소로** — GitHub과 Context7 정도만 글로벌로 두고, 나머지는 프로젝트별 설정이 적합해요. 서버가 많을수록 Claude Code 시작 시간이 늘어나요.

**3. 환경변수를 `.env`로 관리** — 설정 파일에 API 키를 직접 넣지 말고, `.env` 파일을 참조하거나 시스템 환경변수로 관리하세요.

**4. `alwaysLoad: true` 주의** — 자주 쓰는 서버만 `alwaysLoad`로 지정하세요. 모든 서버에 걸면 메모리 사용량이 높아져요.

## 따라하기

### 최소 환경 (10분)

```bash
# GitHub + Context7 만 먼저 설치
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_token \
  -- npx -y @modelcontextprotocol/server-github

claude mcp add context7 -- npx -y @upstash/context7-mcp

# 확인
claude
> /mcp
```

### 전체 환경 (30분)

영상 순서대로 Step 1~5를 따라하세요. 각 단계에서 `/mcp`로 상태를 확인하고 다음으로 넘어가세요.

## 더 알아보기

- [MCP 서버 생태계 치트시트](../../cheatsheets/mcp-server-ecosystem-2026-cheatsheet.md)
- [커스텀 MCP 서버 빌드 및 배포 플레이북](../../claude-code/playbooks/45-custom-mcp-server-build-deploy.md)
- [AI 코딩 에이전트 멀티 툴 스택](../../cheatsheets/ai-multi-tool-coding-stack-cheatsheet.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
