# EP29: Cline + Claude API로 풀스택 앱 처음부터 만들기 — VS Code 에이전트 실전

> VS Code에서 Cline 에이전트로 Next.js 풀스택 앱을 처음부터 구현하는 라이브 코딩 — Plan 모드로 설계하고 Act 모드로 실행하며, MCP 도구와 Claude API 비용까지 최적화

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- Cline 설치 및 Claude API 연동 — 30초 만에 시작하기
- Plan 모드로 구조 설계, Act 모드로 코드 구현하는 2단계 워크플로우
- GitHub MCP 연동으로 이슈 트래킹까지 Cline 안에서 처리하기
- 입력 토큰을 절반으로 줄이는 `.clinerules` 설정 패턴
- Claude Code와의 차이점 — 어떤 상황에 Cline이 더 유리한지

## 완성하는 것

할일 관리 앱 — 태스크 생성, 완료, 필터링 기능이 있는 Next.js App Router 기반 풀스택 서비스

**기술 스택:** Next.js 16 · TypeScript · Prisma · SQLite · Tailwind CSS · shadcn/ui

## 사전 준비

- VS Code 설치
- Anthropic API 키 ([console.anthropic.com](https://console.anthropic.com) 발급)
- Node.js 20+ 설치

## Step 1: Cline 설치 및 Claude API 연동

### 1-1. 익스텐션 설치

VS Code 익스텐션 검색창에서 `Cline` 검색 후 설치 (ID: `saoudrizwan.claude-dev`)

### 1-2. Claude API 연결

```json
// Cline 설정 패널 → API Provider: Anthropic
{
  "apiProvider": "anthropic",
  "apiModelId": "claude-sonnet-4-6",
  "anthropicApiKey": "sk-ant-..."
}
```

> **비용 팁:** `claude-sonnet-4-6`을 기본 모델로 사용하세요. Opus 4.7 대비 비용이 5배 저렴하고, 일반적인 코딩 태스크에서 품질 차이는 거의 없어요.

## Step 2: .clinerules 설정

프로젝트 루트에 `.clinerules` 파일을 만들면 Cline이 매번 동일한 컨텍스트를 인식해요.
불필요한 질문을 줄이고 토큰 낭비를 막는 핵심 설정입니다.

```markdown
# 프로젝트 규칙

## 기술 스택
- Next.js 16 App Router
- TypeScript (strict mode)
- Prisma ORM + SQLite
- Tailwind CSS + shadcn/ui

## 코딩 규칙
- 컴포넌트는 src/components/ 에 위치
- API 라우트는 src/app/api/ 에 위치
- 서버 컴포넌트 기본, 클라이언트 컴포넌트는 필요 시에만 사용
- 파일명: kebab-case

## 언어
- 변수명/함수명: 영어
- 주석: 한국어
```

## Step 3: Plan 모드로 구조 설계

Plan 모드는 코드를 전혀 수정하지 않고 계획만 세우는 모드예요.
복잡한 기능을 구현하기 전에 방향을 검토할 수 있어서 실수를 줄여줍니다.

Cline 입력창 우측의 토글을 **Plan** 으로 전환 후 입력:

```
다음 기능을 구현할 계획을 세워줘:
- 할일 목록 표시 (미완료/완료 필터)
- 할일 추가 (텍스트 입력 + 엔터)
- 완료 토글 (체크박스)
- 할일 삭제

Prisma 스키마, API 라우트, 컴포넌트 구조를 제안해줘.
```

Cline이 수정할 파일 목록과 구현 순서를 제안합니다.
계획이 마음에 들면 **Act** 모드로 전환해서 실행합니다.

## Step 4: Act 모드로 구현

```
계획대로 구현해줘. 순서:
1. Prisma 스키마 정의
2. DB 마이그레이션 실행
3. API 라우트 구현 (CRUD)
4. UI 컴포넌트 구현
5. 기본 스타일 적용
```

Cline이 각 단계마다 어떤 파일을 만들고 어떤 커맨드를 실행할지 보여준 뒤 승인을 요청해요.

### 생성되는 핵심 파일

```
src/
├── app/
│   ├── page.tsx              # 메인 페이지
│   └── api/
│       └── todos/
│           ├── route.ts      # GET, POST
│           └── [id]/
│               └── route.ts  # PATCH, DELETE
├── components/
│   ├── todo-list.tsx
│   ├── todo-item.tsx
│   └── todo-input.tsx
└── lib/
    └── db.ts                 # Prisma 클라이언트
```

### Prisma 스키마

```prisma
// prisma/schema.prisma
model Todo {
  id        String   @id @default(cuid())
  title     String
  done      Boolean  @default(false)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

## Step 5: MCP 도구 연동 (선택)

GitHub MCP를 연결하면 이슈 확인, PR 생성까지 Cline 안에서 처리할 수 있어요.

```json
// .vscode/mcp.json
{
  "servers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${env:GITHUB_TOKEN}"
      }
    }
  }
}
```

연결 후 Cline에서 바로 사용:

```
현재 레포의 열린 이슈 목록을 보여줘
```

## Claude Code와의 차이점

| 항목 | Cline | Claude Code |
|------|-------|-------------|
| 실행 환경 | VS Code 익스텐션 | 터미널 (독립 실행) |
| 모델 선택 | 30+ LLM 지원 | Claude 모델만 |
| 비용 | API 요청당 과금 | 구독 플랜 |
| Plan/Act 분리 | 명시적 토글 | /plan 커맨드 |
| IDE 통합 | 인라인 에디터 통합 | 파일 시스템 접근 |
| 적합한 상황 | IDE 중심 개발, 다양한 LLM 실험 | 터미널 자동화, 대규모 코드베이스 |

## 비용 최적화 팁

```markdown
## .clinerules에 추가하기

## 비용 절약 규칙
- 파일을 읽기 전에 꼭 필요한지 확인
- 대규모 파일 전체 대신 관련 섹션만 참조
- 반복적인 수정은 한 번에 묶어서 요청
```

> 토큰 사용량은 Cline 상태 바에서 실시간으로 확인할 수 있어요.
> 세션 시작 전 `.clinerules`를 잘 작성해두면 동일한 작업에서 토큰을 30~50% 절약할 수 있어요.

## 따라하기

### Step 1: 프로젝트 생성

```bash
npx create-next-app@latest todo-app \
  --typescript \
  --tailwind \
  --app \
  --no-src-dir

cd todo-app
npx prisma init --datasource-provider sqlite
```

### Step 2: Cline에서 구현 요청

```bash
# .clinerules 파일 생성 후 Cline 열기
# Plan 모드로 설계 확인
# Act 모드로 구현 시작
```

### Step 3: 실행 확인

```bash
npx prisma migrate dev --name init
npm run dev
# http://localhost:3000 접속
```

## 더 알아보기

- [Cline GitHub](https://github.com/cline/cline)
- [guides/109-cline-vscode-agent-guide-2026.md](../../guides/109-cline-vscode-agent-guide-2026.md)
- [guides/80-spec-first-ai-workflow-guide.md](../../guides/80-spec-first-ai-workflow-guide.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
