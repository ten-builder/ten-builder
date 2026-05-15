# claude agents 디스패치 플래그 실전 가이드 2026

> `claude agents` 명령어에 추가된 디스패치 플래그를 활용하면, 에이전트를 띄울 때 MCP 서버·플러그인·설정·디렉토리를 세밀하게 제어할 수 있습니다. 팀 전체에 일관된 환경을 강제하거나, 프로젝트별로 도구를 격리하는 데 핵심이 됩니다.

## 소요 시간

15~20분

## 사전 준비

- Claude Code v2.1.128 이상
- 사용 중인 MCP 서버 또는 플러그인 1개 이상
- 기본 `claude` CLI 사용 경험

---

## 왜 디스패치 플래그가 필요한가

`claude` CLI를 직접 실행할 때는 `~/.claude/settings.json`과 프로젝트의 `.claude/settings.json`이 자동으로 적용됩니다. 하지만 `claude agents`로 백그라운드 서브에이전트를 디스패치할 때는 기본적으로 부모 세션의 설정만 상속됩니다.

결과적으로 다음 두 가지 문제가 발생합니다.

| 문제 | 영향 |
|------|------|
| 서브에이전트가 다른 MCP 서버를 씀 | 부모와 자식 에이전트 간 도구 불일치 |
| 플러그인 버전이 세션마다 다름 | 재현 불가능한 에이전트 동작 |

디스패치 플래그는 이 문제를 해결합니다. 플래그를 한 번 지정하면 해당 에이전트 뷰에서 생성되는 **모든 서브에이전트 세션**에 동일하게 전달됩니다.

---

## 핵심 플래그 일람

| 플래그 | 용도 | 예시 |
|--------|------|------|
| `--settings <path>` | 커스텀 settings.json 지정 | `--settings ./team-settings.json` |
| `--add-dir <path>` | 추가 작업 디렉토리 허용 | `--add-dir /data/shared` |
| `--mcp-config <path>` | 커스텀 MCP 설정 파일 지정 | `--mcp-config ./mcp-prod.json` |
| `--plugin-dir <path>` | 커스텀 플러그인 디렉토리 지정 | `--plugin-dir ./plugins/v2` |
| `--permission-mode <mode>` | 권한 정책 지정 | `--permission-mode default` |
| `--model <model>` | 서브에이전트 기본 모델 | `--model claude-opus-4-7` |
| `--effort <level>` | 추론 노력 수준 | `--effort high` |
| `--dangerously-skip-permissions` | 권한 확인 생략 (CI 전용) | — |

---

## Step 1: 팀 공용 settings.json 분리

프로젝트 루트에 팀 설정 파일을 만듭니다. 이 파일은 코드베이스에 커밋하여 모든 팀원이 동일한 에이전트 동작을 경험하도록 합니다.

```json
// team-agent-settings.json
{
  "model": "claude-opus-4-7",
  "effort": "high",
  "maxTokens": 8096,
  "permissions": {
    "allow": [
      "Read(*)",
      "Write(src/**)",
      "Bash(git:*)",
      "Bash(npm:*)",
      "Bash(pnpm:*)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(curl:*)",
      "Bash(wget:*)"
    ]
  }
}
```

---

## Step 2: 프로젝트별 MCP 설정 파일 작성

`~/.claude/claude_desktop_config.json`을 전역으로 두는 대신, 프로젝트별로 MCP 설정을 분리합니다.

```json
// mcp-project.json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/panda/projects/myapp"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "${DATABASE_URL}"]
    }
  }
}
```

**주의:** MCP 설정 파일에 시크릿을 직접 넣지 않습니다. `${ENV_VAR}` 형식으로 환경변수를 참조하세요.

---

## Step 3: claude agents 실행

플래그를 조합해 에이전트 뷰를 실행합니다.

```bash
# 기본 사용법
claude agents \
  --settings ./team-agent-settings.json \
  --mcp-config ./mcp-project.json \
  --add-dir /data/shared-fixtures

# 멀티 디렉토리 허용
claude agents \
  --settings ./team-agent-settings.json \
  --mcp-config ./mcp-project.json \
  --add-dir /data/fixtures \
  --add-dir /data/migrations \
  --add-dir /tmp/agent-workspace

# 특정 모델 + 높은 추론 노력
claude agents \
  --model claude-opus-4-7 \
  --effort xhigh \
  --mcp-config ./mcp-prod.json
```

---

## Step 4: 에이전트 뷰에서 서브에이전트 디스패치

에이전트 뷰가 열리면 `dispatch` 명령으로 서브에이전트를 생성합니다. 위에서 지정한 플래그는 모든 서브에이전트 세션에 자동 전달됩니다.

```
> dispatch "백엔드 API 서버를 구현해줘. src/api/ 디렉토리에 Express + TypeScript 기반으로"
> dispatch "프론트엔드 컴포넌트를 작성해줘. src/components/에 React + Shadcn UI 사용"
> dispatch "PostgreSQL 스키마와 마이그레이션 파일을 만들어줘. 데이터베이스 설계부터"
```

각 서브에이전트는 동일한 `mcp-project.json` 설정과 `team-agent-settings.json`을 씁니다.

---

## Step 5: CI/CD 파이프라인에서 디스패치

GitHub Actions에서 자동화 에이전트를 실행할 때는 `--dangerously-skip-permissions`를 사용합니다. **이 플래그는 CI 환경 전용**이며, 로컬 개발에서는 절대 사용하지 않습니다.

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: AI 코드 리뷰
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          claude agents \
            --settings ./ci-agent-settings.json \
            --mcp-config ./mcp-ci.json \
            --dangerously-skip-permissions \
            --model claude-sonnet-4-6 \
            --effort default \
            --print "PR 변경사항을 리뷰하고 인라인 코멘트를 남겨줘"
```

```json
// ci-agent-settings.json
{
  "permissions": {
    "allow": [
      "Read(*)",
      "Bash(git diff *)",
      "Bash(gh pr comment *)"
    ],
    "deny": ["Write(*)", "Bash(rm *)", "Bash(curl *)"]
  }
}
```

---

## 플래그 조합 패턴

### 패턴 1: 개발 환경 격리

```bash
# 개발/스테이징/프로덕션 MCP 서버를 분리
claude agents --mcp-config ./mcp-dev.json --settings ./settings-dev.json
claude agents --mcp-config ./mcp-staging.json --settings ./settings-staging.json
```

### 패턴 2: 팀별 플러그인 디렉토리

```bash
# 백엔드 팀용
claude agents --plugin-dir ./plugins/backend --settings ./team-backend.json

# 프론트엔드 팀용
claude agents --plugin-dir ./plugins/frontend --settings ./team-frontend.json
```

### 패턴 3: --add-dir로 공유 데이터 접근

서브에이전트가 프로젝트 밖의 디렉토리에 접근해야 할 때 사용합니다.

```bash
# 공유 픽스처 데이터에 접근 허용
claude agents \
  --add-dir /data/test-fixtures \
  --add-dir /data/seed-data \
  --mcp-config ./mcp-project.json
```

---

## 문제 해결

| 문제 | 확인 사항 | 해결 |
|------|----------|------|
| MCP 서버 연결 안 됨 | `mcp-config.json` 경로 확인 | 절대경로로 변경 |
| 서브에이전트가 다른 모델 씀 | `--model` 플래그 누락 | 명시적으로 지정 |
| 권한 오류 | `settings.json` allow 목록 | 필요한 권한 추가 |
| 플러그인 로드 실패 | `--plugin-dir` 경로 확인 | `ls ./plugins/` 검증 |
| CI에서 권한 확인 멈춤 | `--dangerously-skip-permissions` 누락 | CI 설정에 추가 |

---

## 체크리스트

- [ ] `team-agent-settings.json` 코드베이스에 커밋
- [ ] `mcp-project.json`에서 시크릿 환경변수로 분리
- [ ] `--add-dir`로 필요한 공유 디렉토리 허용
- [ ] CI 설정에서 `--dangerously-skip-permissions` 사용 여부 검토
- [ ] 서브에이전트 모델과 effort 수준 명시적 지정

---

## 다음 단계

→ [Git Worktree 기반 병렬 에이전트 실전 가이드](91-git-worktree-parallel-agents-guide.md)  
→ [Claude Code Channels 다중 에이전트 조율 치트시트](../cheatsheets/claude-code-channels-cheatsheet.md)  
→ [AI 에이전트 스킬 시스템 가이드 2026](92-ai-agent-skills-guide-2026.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
