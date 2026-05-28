# Cline VS Code AI 코딩 에이전트 실전 가이드 2026

> VS Code에서 Claude Code, Cursor와 다른 선택지 — 오픈소스 모델 프리 에이전트 Cline을 제대로 써보는 법

## 소요 시간

초기 설정 15분, 첫 에이전트 실행 5분

## Cline이란

Cline은 VS Code 익스텐션으로 설치하는 AI 코딩 에이전트다. 원래 "Claude Dev"라는 이름으로 시작했지만 지금은 완전히 독자 프로젝트로 성장했다. 500만 명 이상의 개발자가 쓰고 있으며, 30개 이상의 LLM 프로바이더를 지원한다.

Claude Code와 가장 큰 차이점은 두 가지다.

- **에디터 내장:** 터미널이 아니라 VS Code 안에서 실행
- **모델 자유도:** Claude, GPT, Gemini, Ollama 등 어떤 모델이든 연결 가능

## 사전 준비

- VS Code 1.90 이상
- API 키 (Claude, OpenAI, Gemini 중 하나 이상)
- Node.js 18 이상 (MCP 서버 사용 시)

## Step 1: 설치 및 초기 설정

```bash
# VS Code 마켓플레이스에서 설치
code --install-extension saoudrizwan.claude-dev
```

설치 후 좌측 사이드바에 Cline 아이콘이 생긴다.

**API 연결:**

1. Cline 패널 → 설정(⚙️) 클릭
2. API Provider 선택 (Anthropic 권장)
3. API Key 입력

**모델 선택 기준:**

| 작업 유형 | 권장 모델 |
|-----------|-----------|
| 복잡한 아키텍처 설계 | claude-opus-4 / claude-sonnet-4-6 |
| 빠른 코드 수정 | claude-haiku-4 / GPT-4o-mini |
| 로컬 실행 (비용 무관) | Ollama qwen3, deepseek-coder |
| 대용량 코드베이스 분석 | Gemini 3.1 Pro (200만 토큰 컨텍스트) |

## Step 2: Plan / Act 모드 이해

Cline의 핵심 설계는 Plan → Act 분리다.

### Plan 모드

에이전트가 코드를 건드리지 않고 분석과 계획만 세운다. 파일을 읽고, 의존성을 파악하고, 접근법을 제안한다. 사람이 확인하고 승인해야 다음으로 넘어간다.

```
[Cline에게 입력]
"이 프로젝트에 Stripe 결제를 추가하려고 해. 
어떤 파일을 수정해야 하고 어떤 순서로 작업해야 할지 계획만 세워줘."
```

### Act 모드

실제로 파일을 생성, 수정, 삭제하고 터미널 명령어를 실행한다. 각 액션마다 확인을 요청한다 (설정으로 자동 승인 가능).

```
[Plan 검토 후]
"계획대로 진행해."
```

### 자동 승인 설정

반복 작업이 많을 때는 액션별 자동 승인을 켜두는 게 편하다.

```json
// .vscode/settings.json
{
  "cline.autoApprove": {
    "readFiles": true,
    "writeFiles": false,
    "executeCommands": false,
    "browserActions": false
  }
}
```

파일 읽기는 자동, 파일 쓰기와 명령어 실행은 확인 — 이 조합이 균형이 좋다.

## Step 3: MCP 서버 연동

Cline의 가장 큰 장점 중 하나는 MCP 생태계와 바로 연결된다는 점이다.

**MCP 서버 추가:**

```bash
# Cline MCP 마켓플레이스에서 직접 설치 가능
# 또는 커맨드 팔레트 → "Cline: Install MCP Server"
```

**유용한 MCP 서버 조합:**

| MCP 서버 | 용도 |
|----------|------|
| `@modelcontextprotocol/server-filesystem` | 파일 시스템 접근 확장 |
| `@modelcontextprotocol/server-postgres` | 데이터베이스 직접 쿼리 |
| `@modelcontextprotocol/server-github` | PR, 이슈, 코드 검색 |
| `@upstash/mcp-server-redis` | Redis 상태 관리 |
| Playwright MCP | 브라우저 자동화 테스트 |

**설정 예시 (`~/.cline/mcp-settings.json`):**

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${env:GITHUB_TOKEN}"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"]
    }
  }
}
```

## Step 4: Rules 시스템 활용

Cline의 Rules는 Claude Code의 CLAUDE.md와 유사하다. 에이전트에게 프로젝트 컨텍스트와 규칙을 미리 알려준다.

```markdown
# .clinerules (프로젝트 루트)

## 프로젝트 개요
- Next.js 15 App Router + TypeScript + Prisma 스택
- 코드 스타일: ESLint + Prettier (pnpm format 필수)
- 테스트: Vitest + Testing Library

## 필수 규칙
- 모든 서버 컴포넌트는 async 함수로 작성
- 클라이언트 컴포넌트에는 반드시 "use client" 선언
- DB 접근은 항상 Prisma 클라이언트 통해서만 수행
- 환경변수는 .env.local에서만 관리

## 커밋 컨벤션
- feat: 새 기능
- fix: 버그 수정
- chore: 설정 변경
```

## Step 5: 멀티 에이전트 팀 구성

Cline 2026 버전에서는 에이전트가 다른 에이전트를 스폰할 수 있다.

```
[오케스트레이터 에이전트에게]
"다음 세 가지 작업을 병렬로 처리해줘:
1. 백엔드: /api/users 엔드포인트 구현
2. 프론트엔드: UserList 컴포넌트 구현
3. 테스트: 두 구현에 대한 테스트 작성
각 에이전트가 독립적으로 작업하고 결과를 보고하게 해줘."
```

## Claude Code와의 비교

| 기준 | Cline | Claude Code |
|------|-------|-------------|
| 실행 환경 | VS Code 내장 | 터미널 |
| 모델 지원 | 30개+ (Any) | Claude 전용 |
| 컨텍스트 창 | 모델 의존 | 200K (Sonnet) |
| SWE-bench | 모델 의존 | 80.8% (Agent Teams) |
| 비용 | 사용량 기반 BYOK | 구독 또는 API |
| 오픈소스 | 완전 공개 | 클로즈드 |
| 멀티 에이전트 | 지원 (SDK) | 지원 (Agent Teams) |

**Cline이 더 나은 경우:**
- VS Code 에코시스템을 벗어나고 싶지 않을 때
- 다양한 모델을 상황에 따라 바꿔 쓰고 싶을 때
- 오픈소스 기여 또는 커스터마이징이 필요할 때
- 비용을 모델 선택으로 직접 제어하고 싶을 때

**Claude Code가 더 나은 경우:**
- 터미널 기반 워크플로우를 선호할 때
- Claude 모델 최적화가 필요한 복잡한 에이전트 팀 작업
- Anthropic의 Routines, Dreaming, Outcomes 기능 활용 시

## 흔한 문제 해결

| 문제 | 해결 |
|------|------|
| 에이전트가 같은 파일을 반복 수정 | `.clinerules`에 "완료 조건 명시" 추가 |
| 토큰 초과 오류 | Plan 모드에서 파일 범위 좁히기 |
| MCP 서버 연결 실패 | `cline mcp list`로 상태 확인 |
| 승인 요청이 너무 잦음 | 설정에서 파일 읽기 자동 승인 |

## 체크리스트

- [ ] VS Code에 Cline 설치 완료
- [ ] 선호 LLM API 키 연결
- [ ] `.clinerules` 파일 작성
- [ ] 필요한 MCP 서버 설치
- [ ] Plan/Act 모드 분리 습관화
- [ ] 자동 승인 설정 적용

## 다음 단계

→ [가이드 110 - Claude Code Week 29](./110-claude-code-week29-features-guide.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
