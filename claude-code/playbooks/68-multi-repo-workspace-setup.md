# 플레이북 68: AI 에이전트 멀티 레포 워크스페이스 구성

> 여러 레포지터리를 동시에 작업할 때 AI 에이전트가 흩어진 컨텍스트를 하나처럼 다루게 만드는 플레이북

## 소요 시간

30-45분 (초기 설정)

## 사전 준비

- Claude Code 설치 (v2.1.120 이상)
- 작업 대상 레포지터리 2개 이상
- VS Code 또는 Zed IDE (멀티 루트 워크스페이스 지원)
- `gh` CLI 설치

## 왜 멀티 레포 설정이 중요한가

Claude Code를 `orders/order-service` 디렉토리에서 실행하면, AI 에이전트는 옆에 있는 `orders/orders-ui`를 전혀 모른다. 공유 라이브러리가 `shared/`에 있어도 마찬가지다.

단일 레포라면 문제없지만, 실제 팀은 대부분 멀티 레포 구조로 일한다:

```
workspace/
  backend/          # Node.js API 서버
  frontend/         # React 앱
  shared-types/     # 공유 TypeScript 타입
  infra/            # Terraform/Pulumi 설정
```

이 구조에서 에이전트에게 "백엔드 API를 바꾸면 프론트도 같이 수정해줘"라고 했을 때, 에이전트가 올바르게 동작하려면 **컨텍스트 계층**을 미리 설계해야 한다.

| 문제 상황 | 원인 | 해결 방향 |
|----------|------|----------|
| 에이전트가 크로스 레포 의존성을 모름 | 단일 레포만 인식 | 워크스페이스 CLAUDE.md |
| 레포마다 다른 코딩 스타일 사용 | 공유 설정 없음 | 공통 `.claude/settings.json` |
| 역할별 설정이 레포 간 충돌 | 분리 없음 | 계층별 CLAUDE.md |

## Step 1: 컨텍스트 3계층 이해하기

멀티 레포 환경에서 AI 에이전트 컨텍스트는 3단계로 쌓인다:

```
[1레이어: 조직/팀 공통]
  workspace/CLAUDE.md
    → 팀 공통 규칙, 레포 지도, 기술 스택 개요

[2레이어: 레포별 설정]
  backend/CLAUDE.md
  frontend/CLAUDE.md
  shared-types/CLAUDE.md
    → 각 레포 목적, 디렉토리 구조, 주요 명령어

[3레이어: 모듈/기능별]
  backend/src/auth/CLAUDE.md (필요 시)
    → 특정 모듈 규칙, 복잡한 비즈니스 로직 설명
```

1레이어가 핵심이다. 에이전트를 어느 레포에서 실행하든, **워크스페이스 루트 CLAUDE.md를 먼저 읽도록** 구성하면 전체 그림을 알고 시작할 수 있다.

## Step 2: 워크스페이스 루트 CLAUDE.md 작성

```markdown
# 워크스페이스: orders-platform

## 레포 구조
- `backend/` — Express + TypeScript API 서버 (포트 3000)
- `frontend/` — Next.js 14 앱 (포트 3001)
- `shared-types/` — 공유 TypeScript 인터페이스 & Zod 스키마
- `infra/` — AWS Terraform 설정

## 레포 간 의존성
- backend → shared-types (npm workspace 링크)
- frontend → shared-types (npm workspace 링크)
- frontend → backend (API 클라이언트)

## 크로스 레포 작업 시 주의사항
- shared-types를 변경하면 반드시 backend/frontend 모두 확인
- API 엔드포인트 변경 시 frontend api 클라이언트 파일도 함께 수정
- 환경변수는 infra/env/ 폴더에서 관리

## 공통 명령어
- 전체 빌드: `npm run build:all` (워크스페이스 루트)
- 전체 테스트: `npm run test:all`
- 타입 체크: `npm run typecheck:all`
```

이 파일을 `workspace/CLAUDE.md`에 두면 Claude Code가 자동으로 상위 디렉토리를 탐색해 읽는다.

## Step 3: 레포별 CLAUDE.md 작성

각 레포 CLAUDE.md는 간결하게 유지한다. 중복 설명보다 레포 고유 정보에 집중하는 게 좋다:

```markdown
# backend/CLAUDE.md

## 역할
orders-platform의 REST API 서버

## 주요 경로
- `src/routes/` — API 라우터
- `src/services/` — 비즈니스 로직
- `src/db/` — Drizzle ORM 스키마 & 마이그레이션

## 개발 명령어
- 실행: `npm run dev`
- 마이그레이션: `npm run db:migrate`
- 테스트: `npm test`

## 코딩 규칙
- 모든 외부 입력은 Zod로 검증 (shared-types/schemas에서 import)
- 에러는 반드시 ApiError 클래스 사용
- 컨트롤러는 200자 이하, 로직은 서비스 레이어로 분리
```

## Step 4: 공유 settings.json 설정

여러 레포에서 동일한 allowed tools, hooks, 금지 명령어를 적용하려면 워크스페이스 루트에 공통 설정을 둔다:

```bash
# 워크스페이스 루트 공통 설정
mkdir -p workspace/.claude

cat > workspace/.claude/settings.json << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(git *)",
      "Bash(gh *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(curl * | bash *)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo '[AI Agent] 실행: $CLAUDE_TOOL_INPUT'"
          }
        ]
      }
    ]
  }
}
EOF
```

각 레포에는 레포 고유 설정만 추가한다:

```json
// backend/.claude/settings.json
{
  "permissions": {
    "allow": [
      "Bash(npm run db:*)",
      "Bash(drizzle-kit *)"
    ]
  }
}
```

Claude Code는 현재 레포 설정 + 상위 디렉토리 설정을 합쳐서 적용한다.

## Step 5: VS Code 멀티 루트 워크스페이스 설정

IDE에서 여러 레포를 동시에 열고 Claude Code를 연동하는 설정이다:

```json
// orders-platform.code-workspace
{
  "folders": [
    { "name": "workspace-root", "path": "." },
    { "name": "backend", "path": "./backend" },
    { "name": "frontend", "path": "./frontend" },
    { "name": "shared-types", "path": "./shared-types" }
  ],
  "settings": {
    "claude-code.workingDirectory": "${workspaceFolder:workspace-root}",
    "editor.formatOnSave": true
  }
}
```

`claude-code.workingDirectory`를 워크스페이스 루트로 지정하면 어느 파일을 편집 중이든 에이전트가 전체 컨텍스트를 인식한 상태로 실행된다.

## Step 6: 역할별 CLAUDE.md 분리 전략

팀 규모가 커지면 공개/비공개 컨텍스트를 분리할 필요가 생긴다:

```
workspace/
  CLAUDE.md                   # 공개 — 레포에 커밋, 팀 전체 공유
  CLAUDE.local.md             # 비공개 — .gitignore, 개인 환경/토큰
  .claude/
    settings.json             # 공개 설정 (커밋)
    settings.local.json       # 비공개 설정 (.gitignore)
```

`CLAUDE.local.md`에는 개인 API 키, 로컬 경로, 실험 중인 패턴을 적어둔다. `.gitignore`에 추가해두면 팀 레포에 올라가지 않는다.

## 체크리스트

- [ ] 워크스페이스 루트에 `CLAUDE.md` 생성 (레포 지도 포함)
- [ ] 각 레포에 레포 고유 `CLAUDE.md` 작성
- [ ] 워크스페이스 루트 `.claude/settings.json`에 공통 권한/훅 설정
- [ ] VS Code `.code-workspace` 파일로 멀티 루트 구성
- [ ] `CLAUDE.local.md` → `.gitignore`에 추가 (비공개 컨텍스트 보호)
- [ ] 크로스 레포 의존성을 워크스페이스 CLAUDE.md에 명시
- [ ] 공통 명령어(`npm run build:all` 등)를 루트 CLAUDE.md에 정리

## 다음 단계

→ [플레이북 69: AI 에이전트 코드 문서화 자동화 워크플로우](../playbooks/) (준비 중)
→ [Git Worktree 기반 병렬 에이전트 가이드](../../guides/91-git-worktree-parallel-agents-guide.md)
→ [AGENTS.md 컨텍스트 파일 설계 치트시트](../../cheatsheets/agents-md-context-engineering-cheatsheet.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
