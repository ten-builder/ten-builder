# EP14: AGENTS.md로 AI 팀 구성하기 — 레포 전체 자동화 실전

> AGENTS.md 하나로 AI 에이전트 팀이 레포를 이해하고 기능을 자동 구현하는 과정을 라이브로 보여드립니다.

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- AGENTS.md 파일 작성법과 구조 — AI 팀이 실제로 읽는 방식
- Claude Code 에이전트 팀 기능으로 전문 역할 분담하기
- 레포 컨텍스트를 AI 팀에게 주입하는 실전 패턴
- 병렬 에이전트 실행 중 충돌 없이 코드 합치는 방법
- 처음부터 끝까지 사람 개입 최소화로 기능 구현 완성

## 핵심 개념: AGENTS.md가 뭐가 다른가요?

AGENTS.md는 레포 루트에 두는 Markdown 파일입니다. CLAUDE.md와 비슷하지만, **여러 AI 에이전트가 팀으로 작업할 때** 각자가 참조하는 공통 규칙서 역할을 합니다.

```markdown
# AGENTS.md 기본 구조

## 프로젝트 개요
이 레포는 [설명]. 에이전트는 [범위]에서만 변경할 것.

## 개발 환경
- 언어: TypeScript 5.x
- 패키지 매니저: pnpm
- 테스트: vitest

## 역할 분담 (에이전트 팀 실행 시)
- Backend 에이전트: src/api/, src/db/
- Frontend 에이전트: src/components/, src/pages/
- Test 에이전트: __tests__/ 디렉토리

## 금지 사항
- main 직접 push 금지
- .env 파일 수정 금지
- 타 에이전트 담당 디렉토리 변경 금지
```

AI 에이전트 팀을 실행하면 각 에이전트가 이 파일을 읽고 자신의 담당 영역과 제약 조건을 파악합니다.

## 핵심 코드 & 설정

### AGENTS.md 전체 예시 (실전 버전)

```markdown
# AGENTS.md — To-do 앱 프로젝트

## 프로젝트 구조
- src/api/: Express 라우터, 컨트롤러
- src/db/: Prisma 스키마, 마이그레이션
- src/components/: React 컴포넌트
- src/pages/: Next.js 페이지
- __tests__/: vitest 테스트 파일

## 빌드 & 테스트
pnpm install
pnpm dev        # 개발 서버
pnpm test       # 전체 테스트
pnpm build      # 프로덕션 빌드

## 코딩 규칙
- 함수는 단일 책임 원칙 준수
- 에러 처리는 Result 타입 사용
- API 응답은 { data, error, status } 형태

## 에이전트별 담당 영역
- BACKEND: src/api/, src/db/
- FRONTEND: src/components/, src/pages/
- TEST: __tests__/ (다른 에이전트가 만든 코드 테스트)

## 브랜치 전략
- 각 에이전트: feature/[담당영역]-[기능명] 브랜치 생성
- 완료 후 PR 생성 → 오케스트레이터가 리뷰
```

### 에이전트 팀 실행 스크립트

```bash
#!/bin/bash
# agents-team.sh — 에이전트 팀 병렬 실행

TASK="사용자 인증 기능 구현: 회원가입, 로그인, JWT 토큰 발급"

# 백엔드 에이전트 (별도 git checkout)
git worktree add /tmp/agent-backend feature/backend-auth
(cd /tmp/agent-backend && claude -p "
AGENTS.md를 읽고 BACKEND 역할로 다음 태스크를 완료하세요:
$TASK
완료 후 PR을 생성하세요.
" --allowedTools "Edit,Bash,Write") &

# 프론트엔드 에이전트
git worktree add /tmp/agent-frontend feature/frontend-auth
(cd /tmp/agent-frontend && claude -p "
AGENTS.md를 읽고 FRONTEND 역할로 다음 태스크를 완료하세요:
$TASK
백엔드 API 스펙은 src/api/auth.ts를 참조하세요.
" --allowedTools "Edit,Bash,Write") &

# 두 에이전트 완료 대기
wait

echo "에이전트 팀 작업 완료"
```

### Claude Code 에이전트 팀 vs 서브에이전트 비교

| 항목 | 서브에이전트 | 에이전트 팀 |
|------|-------------|------------|
| 소통 방식 | 결과만 상위에 보고 | 팀원끼리 직접 소통 가능 |
| 컨텍스트 | 각자 독립 윈도우 | 공유 태스크 리스트 |
| 적합한 상황 | 독립적 병렬 작업 | 의존성 있는 협업 태스크 |
| 조율 방식 | 오케스트레이터가 수집 | 태스크 리스트로 실시간 동기화 |

## 따라하기

### Step 1: 레포에 AGENTS.md 만들기

```bash
cd your-project

cat > AGENTS.md << 'EOF'
# AGENTS.md

## 프로젝트 개요
[프로젝트 설명을 2-3줄로 작성]

## 디렉토리 구조
[주요 디렉토리와 역할 설명]

## 빌드 & 테스트 명령어
[실제 명령어 작성]

## 에이전트 역할 분담
- BACKEND: [담당 디렉토리]
- FRONTEND: [담당 디렉토리]
- TEST: [담당 디렉토리]

## 중요 규칙
- [지켜야 할 제약 사항]
EOF
```

### Step 2: git worktree로 에이전트별 격리 환경 구성

```bash
# 메인 레포에서 각 에이전트용 worktree 생성
git worktree add /tmp/agent-backend feature/backend-task
git worktree add /tmp/agent-frontend feature/frontend-task

# worktree 목록 확인
git worktree list
```

### Step 3: 에이전트별 역할 지시 + 병렬 실행

```bash
# 백엔드 에이전트 실행
claude --dangerously-skip-permissions -p "
레포의 AGENTS.md를 읽어라.
너는 BACKEND 에이전트다.
[구체적인 태스크 설명]
완료되면 PR을 생성하라.
" &

# 프론트엔드 에이전트 동시 실행
claude --dangerously-skip-permissions -p "
레포의 AGENTS.md를 읽어라.
너는 FRONTEND 에이전트다.
[구체적인 태스크 설명]
" &

wait  # 모든 에이전트 완료 대기
```

### Step 4: 결과 수집 + 통합

```bash
# 각 브랜치 확인
git worktree list

# 변경 내용 확인
git diff main feature/backend-task
git diff main feature/frontend-task

# PR 생성 여부 확인
gh pr list
```

## AGENTS.md 작성 팁

| 항목 | 잘 쓰는 방법 | 피해야 할 것 |
|------|------------|------------|
| 디렉토리 설명 | 각 폴더의 역할을 1줄로 명확히 | 모호한 표현 ("여기에 파일 있음") |
| 빌드 명령어 | 복사-붙여넣기 가능한 실제 명령어 | "적절한 명령어를 사용하세요" |
| 에이전트 역할 | 담당 디렉토리를 명시 | 역할 중복 또는 공백 영역 |
| 제약 조건 | 금지 행동을 구체적으로 나열 | 추상적인 원칙만 나열 |

## 주의사항

에이전트 팀은 강력하지만 몇 가지 조심해야 할 점이 있어요.

두 에이전트가 같은 파일을 동시에 수정하면 충돌이 생깁니다. AGENTS.md에서 담당 영역을 명확히 나누고, 공유 파일(설정, 타입 정의 등)은 한 에이전트가 먼저 작업한 뒤 나머지가 이를 참조하도록 순서를 정하세요.

`--dangerously-skip-permissions` 플래그는 파일 시스템 접근 제한을 해제합니다. 신뢰할 수 있는 격리 환경(git worktree, 컨테이너)에서만 사용하세요.

## 더 알아보기

- [오케스트레이터-워커 패턴 심화 가이드](../../guides/58-ai-agent-orchestrator-patterns.md)
- [Claude Code 서브에이전트 병렬 실행 심화 가이드](../../guides/56-claude-code-subagent-parallel-guide.md)
- [AGENTS.md 컨텍스트 파일 설계 치트시트](../../cheatsheets/agents-md-context-engineering-cheatsheet.md)
- [팀 AI 에이전트 협업 워크플로우 플레이북](../../claude-code/playbooks/51-team-ai-collaboration-workflow.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
