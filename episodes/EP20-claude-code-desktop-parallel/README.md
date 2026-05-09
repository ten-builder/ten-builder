# EP20: Claude Code 데스크탑 재설계로 풀스택 병렬 개발하기

> 새로운 Claude Code 데스크탑 앱의 세션 사이드바를 활용해 백엔드, 프론트엔드, 테스트를 3개 에이전트가 동시에 개발하는 병렬 워크플로우 라이브 데모

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

---

## 이 에피소드에서 다루는 것

- 재설계된 Claude Code 데스크탑 앱의 세션 사이드바로 여러 에이전트를 한 화면에서 관리하는 방법
- 백엔드·프론트엔드·테스트 에이전트를 동시에 실행해 개발 시간을 단축하는 실전 흐름
- Git Worktree로 에이전트별 작업 공간을 격리해 충돌을 방지하는 설정
- 드래그 앤 드롭 레이아웃으로 터미널·파일 에디터 배치를 자유롭게 조정하는 UX 활용법
- 에이전트 실행 중 충돌·오류가 발생했을 때 대응하는 트러블슈팅

---

## 스택

| 레이어 | 기술 |
|--------|------|
| 프론트엔드 | Next.js 15 + TypeScript + Tailwind CSS |
| 백엔드 | Fastify + Zod + Prisma |
| 데이터베이스 | PostgreSQL 16 |
| 테스트 | Vitest + Playwright (E2E) |
| 에이전트 도구 | Claude Code 데스크탑 앱 (재설계 버전) + Git Worktree |
| 배포 | Vercel (프론트) + Railway (백엔드 + DB) |

---

## Claude Code 데스크탑 재설계 핵심 변경점

| 기능 | 이전 | 재설계 이후 |
|------|------|------------|
| 세션 관리 | 탭 전환 방식, 한 번에 1개 | 사이드바에서 N개 동시 표시 |
| 레이아웃 | 고정 분할 | 드래그 앤 드롭으로 자유 배치 |
| 터미널·에디터 | 별도 앱 전환 필요 | 앱 내 통합 |
| 원격 접속 | 미지원 | SSH 세션 직접 연결 |
| 전체화면 모드 | 없음 | `/tui` 명령어로 진입 |

---

## 타임라인

### Part 1 (0-15분): 데스크탑 앱 설정 + 병렬 세션 준비

```
0min  → Claude Code 데스크탑 앱 설치 확인 및 업데이트
5min  → Git Worktree 3개 초기화 (backend / frontend / test)
10min → 사이드바에 세션 3개 동시 열기 + 레이아웃 배치
15min → 각 세션에 역할 지시사항 입력 (CLAUDE.md 기반)
```

### Part 2 (15-50분): 병렬 구현 라이브

```
15min → 3개 에이전트 동시 시작
20min → Backend 세션: Fastify 라우트 + Prisma 스키마 완성
30min → Frontend 세션: Next.js App Router 컴포넌트 구조 완성
35min → Test 세션: Vitest 단위 테스트 + Mock 설정 완성
45min → 세션 상태 점검 및 중간 통합 확인
```

### Part 3 (50-80분): 통합 + 배포

```
50min → 프론트엔드 ↔ 백엔드 API 연결 확인
60min → Playwright E2E 테스트 에이전트 추가 실행
70min → 통합 테스트 전체 통과 확인
75min → Vercel + Railway 배포 에이전트 실행
80min → 배포된 앱 최종 데모
```

---

## Git Worktree 세션 격리 설정

세션 사이드바를 열기 전에 Worktree를 먼저 만들어 두는 게 핵심이에요.

```bash
# 프로젝트 루트에서 실행
cd ~/projects/my-fullstack-app

# 3개 Worktree 생성
git worktree add ../wt-backend feature/backend-api
git worktree add ../wt-frontend feature/frontend-ui
git worktree add ../wt-test feature/test-setup

# 확인
git worktree list
```

각 Claude Code 세션은 해당 Worktree 디렉토리를 루트로 열어요. 에이전트들이 같은 파일을 동시에 수정해서 생기는 충돌이 원천 차단됩니다.

---

## 세션별 CLAUDE.md 설정

에이전트가 역할을 벗어나지 않도록 각 Worktree에 CLAUDE.md를 넣어요.

### 백엔드 세션 (`../wt-backend/CLAUDE.md`)

```markdown
# 역할: Backend API 에이전트

## 담당 범위
- `src/routes/` — API 엔드포인트 구현
- `prisma/schema.prisma` — 데이터 모델 정의
- `src/plugins/` — Fastify 플러그인 설정

## 금지 범위
- `frontend/` 폴더 수정 금지
- `tests/e2e/` 폴더 수정 금지

## API 설계 원칙
- REST 엔드포인트는 `/api/v1/` 접두어 사용
- 요청/응답 스키마는 반드시 Zod로 검증
- 에러 응답 형식: `{ error: string, code: string }`
```

### 프론트엔드 세션 (`../wt-frontend/CLAUDE.md`)

```markdown
# 역할: Frontend UI 에이전트

## 담당 범위
- `app/` — Next.js App Router 페이지 및 레이아웃
- `components/` — UI 컴포넌트 (shadcn/ui 기반)
- `lib/api.ts` — 백엔드 API 클라이언트

## 금지 범위
- `src/routes/` 폴더 수정 금지
- `prisma/` 폴더 수정 금지

## API 호출 원칙
- 백엔드 base URL은 `process.env.NEXT_PUBLIC_API_URL` 사용
- 서버 컴포넌트에서 직접 fetch, 클라이언트 컴포넌트는 SWR
```

### 테스트 세션 (`../wt-test/CLAUDE.md`)

```markdown
# 역할: Test 에이전트

## 담당 범위
- `tests/unit/` — Vitest 단위 테스트
- `tests/integration/` — 통합 테스트
- `tests/e2e/` — Playwright E2E 시나리오

## 테스트 원칙
- 단위 테스트: 외부 의존성은 모두 Mock 처리
- E2E 테스트: 실제 백엔드 서버에 연결 (localhost:3001)
- 커버리지 목표: 핵심 비즈니스 로직 80% 이상
```

---

## 사이드바 레이아웃 배치 팁

```
┌─────────────────────────────────────────┐
│  세션 사이드바 (좌측)                     │
│  ├─ [실행중] Backend API               │
│  ├─ [실행중] Frontend UI               │
│  └─ [실행중] Test Suite                │
├───────────────────┬─────────────────────┤
│  메인 에디터 (중앙) │  터미널 패널 (우측)   │
│  파일 미리보기     │  에이전트 로그 출력   │
└───────────────────┴─────────────────────┘
```

드래그 앤 드롭으로 터미널을 우측에 배치하면 세 에이전트의 로그를 탭으로 전환하며 볼 수 있어요.

---

## 에이전트 조율 패턴

### 의존성 순서 관리

백엔드 API 타입이 확정되기 전에 프론트엔드 에이전트가 API 클라이언트를 작성하면 나중에 수정이 생겨요. 의존성 순서를 지키는 게 중요합니다.

```
1단계: Backend 에이전트 → API 계약 파일 생성
       (openapi.yaml 또는 TypeScript 타입 파일)

2단계: Frontend 에이전트 → API 계약 파일 기반으로 클라이언트 작성
       (1단계 완료 확인 후 시작)

3단계: Test 에이전트 → 두 계층 모두 참조해 E2E 시나리오 작성
       (1, 2단계 완료 확인 후 시작)
```

### 충돌 발생 시 대응

```bash
# Worktree 간 변경사항 병합 (충돌 발생 시)
cd ~/projects/my-fullstack-app

# 백엔드 변경사항 main에 머지
git checkout main
git merge feature/backend-api

# 프론트엔드 브랜치에 main 변경사항 반영
cd ../wt-frontend
git rebase main

# 충돌 해결 후
git add .
git rebase --continue
```

---

## 이 에피소드에서 얻어가는 것

- **시간 단축**: 순차 개발 대비 약 40-60% 시간 절감 (에피소드에서 실제 측정)
- **역할 분리**: CLAUDE.md로 에이전트가 담당 범위를 벗어나지 않도록 강제
- **충돌 없는 협업**: Git Worktree 격리로 에이전트 간 파일 충돌 제거
- **레이아웃 자유**: 드래그 앤 드롭으로 개인 개발 스타일에 맞게 화면 배치

---

## 따라하기

### 사전 준비

```bash
# Claude Code 데스크탑 앱 설치 (재설계 버전 이상)
# https://claude.ai/code 에서 다운로드

# Git 버전 확인 (2.5 이상 필요)
git --version

# 프로젝트 초기화
mkdir my-fullstack-app && cd my-fullstack-app
git init
```

### Worktree 초기화

```bash
# 기본 파일 커밋 후 Worktree 생성
echo "# My Fullstack App" > README.md
git add . && git commit -m "init"

git worktree add ../wt-backend feature/backend-api
git worktree add ../wt-frontend feature/frontend-ui
git worktree add ../wt-test feature/test-setup
```

### 세션 사이드바 열기

1. Claude Code 데스크탑 앱 실행
2. 사이드바 `+` 버튼 클릭 → 새 세션 추가
3. `../wt-backend` 디렉토리를 세션 루트로 선택
4. 동일한 방법으로 `wt-frontend`, `wt-test` 세션 추가
5. 세 세션 동시 실행

---

## 더 알아보기

- [Claude Code 데스크탑 재설계 가이드](../guides/87-claude-code-desktop-redesign-guide.md)
- [오케스트레이터-워커 패턴](../guides/58-ai-agent-orchestrator-patterns.md)
- [Git Worktree 병렬 에이전트 워크플로우](../cheatsheets/ai-terminal-workflow-cheatsheet.md)
- [AI 에이전트 팀 구성 가이드](../guides/72-ai-coding-agent-team-composition-guide.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
