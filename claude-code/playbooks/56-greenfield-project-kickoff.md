# 플레이북 56: AI 에이전트 그린필드 프로젝트 킥오프

> 새 프로젝트를 AI 에이전트와 함께 처음부터 설정하는 단계별 가이드 — CLAUDE.md 초안 작성, 디렉토리 구조 설계, 팀 룰 정의, 첫 스프린트 자동화까지

## 소요 시간

30-60분 (프로젝트 규모에 따라 다름)

## 사전 준비

- Claude Code 또는 선호하는 AI 에이전트 설치 완료
- 프로젝트 언어/프레임워크 결정
- 팀 코딩 컨벤션 초안 (없어도 됨)

---

## Step 1: 빈 레포에서 CLAUDE.md 초안 만들기

새 프로젝트 디렉토리를 만들고 Claude Code를 실행하면 `/init` 명령으로 CLAUDE.md 초안을 얻을 수 있어요.

```bash
mkdir my-project && cd my-project
git init
claude   # Claude Code 실행
```

Claude Code 내에서:

```
/init
```

생성된 초안은 **시작점**일 뿐이에요. 다음 항목을 직접 채워 넣어야 해요.

```markdown
# CLAUDE.md

## 프로젝트 개요
{프로젝트가 무엇을 하는지 2-3문장}

## 기술 스택
- 언어: {언어}
- 프레임워크: {프레임워크}
- 데이터베이스: {DB}
- 배포: {배포 환경}

## 디렉토리 구조
{핵심 디렉토리 설명}

## 코딩 컨벤션
{팀의 핵심 규칙 5-10개}

## 금지 사항
{에이전트가 절대 하면 안 되는 것}

## 테스트 실행 방법
{테스트 명령어}
```

**핵심 원칙:** CLAUDE.md는 얇게 유지해요. AI에게 "이 프로젝트는 TypeScript를 씁니다"처럼 package.json만 봐도 알 수 있는 내용은 넣지 않아도 돼요.

---

## Step 2: 디렉토리 구조 설계

AI 에이전트에게 구조 제안을 요청하고, 이를 CLAUDE.md에 명시해요.

```bash
# Claude Code에서
"이 프로젝트는 Next.js + TypeScript SaaS입니다.
팀 규모: 3명, 도메인: 결제 + 대시보드.
권장 디렉토리 구조를 제안해주세요."
```

AI가 제안한 구조를 검토하고 확정하면, 디렉토리를 일괄 생성해요.

```bash
mkdir -p src/{components,hooks,lib,services,types}
mkdir -p src/app/{dashboard,billing,auth}
mkdir -p tests/{unit,integration,e2e}
mkdir -p docs
touch .env.example
touch .gitignore
```

CLAUDE.md에 구조 설명을 추가해요.

```markdown
## 디렉토리 구조

| 경로 | 용도 |
|------|------|
| `src/components/` | 재사용 UI 컴포넌트 (Storybook 연동) |
| `src/services/` | 외부 API 연동 (각 서비스 1파일) |
| `src/lib/` | 공통 유틸리티, 순수 함수 |
| `tests/e2e/` | Playwright E2E 테스트 |
```

---

## Step 3: 모듈형 룰 파일 설정

대형 CLAUDE.md 하나보다 `.claude/rules/` 아래 역할별 파일로 분리하면 유지보수가 쉬워요.

```bash
mkdir -p .claude/rules
```

| 파일 | 담당 |
|------|------|
| `.claude/rules/code-style.md` | 포맷, 네이밍, 린트 규칙 |
| `.claude/rules/testing.md` | 테스트 작성 기준 |
| `.claude/rules/git.md` | 브랜치, PR, 커밋 메시지 규칙 |
| `.claude/rules/security.md` | 비밀키 관리, 입력 검증 |

```markdown
# .claude/rules/git.md

## 브랜치 전략
- main: 프로덕션 배포용, 직접 push 금지
- feature/{name}: 기능 개발
- fix/{name}: 버그 수정

## 커밋 메시지
- feat: 새 기능
- fix: 버그 수정
- refactor: 리팩토링
- test: 테스트 추가

## PR 기준
- PR 하나에 한 가지 변경
- 스크린샷 필수 (UI 변경 시)
```

CLAUDE.md에서 이 파일들을 참조해요.

```markdown
## 규칙 파일
- 코드 스타일: `.claude/rules/code-style.md`
- 테스트: `.claude/rules/testing.md`
- Git: `.claude/rules/git.md`
```

---

## Step 4: CI/CD 파이프라인 초기 설정

프로젝트 첫날에 CI를 설정하면 이후 AI 에이전트가 생성한 코드를 자동 검증할 수 있어요.

```bash
# Claude Code에서
"GitHub Actions로 기본 CI 파이프라인을 만들어줘.
- push/PR 시 테스트 실행
- 린트 체크
- 타입 체크
- 브랜치 보호 규칙 파일 포함"
```

AI가 생성한 워크플로우 파일을 검토하고 커밋해요.

```yaml
# .github/workflows/ci.yml (AI 생성 후 검토)
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run type-check
      - run: npm test
```

---

## Step 5: 첫 스프린트 태스크 자동화

프로젝트 구조가 확정되면, AI 에이전트에게 첫 스프린트 작업 목록을 넘겨요.

```bash
# Claude Code에서
"CLAUDE.md를 읽고 다음 초기 설정 태스크를 처리해줘:
1. ESLint + Prettier 설정 (.eslintrc, .prettierrc)
2. 기본 타입 정의 파일 (src/types/index.ts)
3. 환경변수 로더 (src/lib/env.ts)
4. README.md 초안 작성
각 태스크마다 진행 상황을 알려줘."
```

AI가 태스크를 처리하는 동안, 다음 항목을 CLAUDE.md에 추가해요.

```markdown
## 초기 설정 완료 항목
- [x] ESLint + Prettier
- [x] TypeScript strict 모드
- [x] 환경변수 검증 (Zod)
- [x] 기본 CI 파이프라인
```

---

## 체크리스트

### CLAUDE.md 완성도
- [ ] 프로젝트 목적 2-3문장 설명 포함
- [ ] 핵심 디렉토리 구조 명시
- [ ] "하면 안 되는 것" 섹션 포함
- [ ] 테스트 실행 명령어 포함
- [ ] 불필요한 내용 없이 간결함

### 환경 설정
- [ ] `.gitignore`에 `.env`, `.claude/` 포함
- [ ] `.env.example` 작성 완료
- [ ] CI 파이프라인 첫 실행 성공
- [ ] 브랜치 보호 규칙 설정 완료

### 팀 온보딩 준비
- [ ] README.md에 로컬 설정 방법 기재
- [ ] 팀원이 `git clone` 후 30분 내 실행 가능

---

## 흔한 실수

| 실수 | 결과 | 해결 |
|------|------|------|
| CLAUDE.md를 너무 길게 작성 | 에이전트가 핵심을 놓침 | 500자 이내 유지 |
| 첫날 CI 없이 시작 | 나중에 기술 부채 누적 | Day 1에 기본 CI 필수 |
| 룰 파일 없이 단일 CLAUDE.md | 수정 시 충돌 잦음 | `.claude/rules/`로 분리 |
| 에이전트에게 구조 결정 완전 위임 | 팀 컨벤션 무시 | 팀이 먼저 큰 방향 결정 |

---

## 다음 단계

→ [플레이북 43: AI 에이전트 온보딩 자동화](./43-team-onboarding-automation.md)
→ [플레이북 51: 팀 AI 에이전트 협업 워크플로우](./51-team-ai-collaboration-workflow.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
