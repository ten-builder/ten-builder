# AI 코딩 에이전트 커스텀 룰 파일 설계 가이드

> CLAUDE.md, .cursorrules, AGENTS.md 등 에이전트 룰 파일을 프로젝트 규모와 팀에 맞게 설계하는 체계적 가이드

## 룰 파일이 왜 중요한가

AI 코딩 에이전트한테 "우리 프로젝트 스타일대로 코드 짜줘"라고 말해도, 에이전트는 **우리 프로젝트 스타일이 뭔지 모릅니다**. 코딩 컨벤션, 디렉토리 구조, 테스트 방식, 커밋 메시지 형식 — 이런 건 코드베이스만 봐서는 파악하기 어려운 **암묵적 지식**이에요.

룰 파일은 이 암묵적 지식을 명시적으로 적어두는 문서예요. 에이전트가 코드를 생성하기 전에 참조하는 **프로젝트 매뉴얼**이라고 생각하면 돼요.

### 룰 파일이 있을 때 vs 없을 때

| | 룰 파일 없음 | 룰 파일 있음 |
|---|---|---|
| 코딩 스타일 | 에이전트 기본값 (일반적인 패턴) | 프로젝트 컨벤션에 맞는 코드 |
| 테스트 작성 | 랜덤한 테스트 프레임워크 선택 | 지정된 프레임워크 + 패턴 사용 |
| 파일 위치 | 에이전트가 추측해서 배치 | 정확한 디렉토리에 생성 |
| 에러 처리 | 제각각인 에러 패턴 | 프로젝트 공통 에러 핸들링 적용 |
| 리뷰 시간 | 스타일 수정에 시간 소모 | 로직 검토에 집중 가능 |

## 에이전트별 룰 파일 종류

2026년 기준, 주요 AI 코딩 도구는 각자 다른 이름과 형식의 룰 파일을 사용해요.

| 에이전트 | 룰 파일 | 위치 | 형식 |
|----------|---------|------|------|
| Claude Code | `CLAUDE.md` | 프로젝트 루트 | Markdown |
| Cursor | `.cursor/rules/*.mdc` | `.cursor/rules/` | MDC (Markdown + frontmatter) |
| Windsurf | `.windsurfrules` | 프로젝트 루트 | Markdown |
| Copilot | `.github/copilot-instructions.md` | `.github/` | Markdown |
| Augment | `AGENTS.md` | 프로젝트 루트 | Markdown |
| Aider | `.aider.conf.yml` | 프로젝트 루트 | YAML |
| Gemini CLI | `GEMINI.md` | 프로젝트 루트 | Markdown |

### 핵심 포인트

`AGENTS.md`는 원래 Anthropic이 Claude Code용으로 제안한 형식인데, 2026년 들어서 **에이전트 독립적인 표준**으로 자리잡고 있어요. Augment, Cline 등 여러 도구가 이 파일을 인식하기 시작했고, [agents.md](https://agents.md) 커뮤니티도 생겼어요.

실전에서는 **AGENTS.md를 공통 룰 파일로 작성**하고, 에이전트별 파일에서 이걸 참조하는 구조가 효과적이에요.

## 룰 파일 기본 구조

좋은 룰 파일에는 다음 5가지 섹션이 들어가요:

```markdown
# 프로젝트 룰

## 1. 빌드 & 실행 명령어
(에이전트가 빌드하고 테스트할 때 쓰는 명령어)

## 2. 코딩 컨벤션
(스타일, 네이밍, 파일 구조 규칙)

## 3. 아키텍처 패턴
(디렉토리 구조, 모듈 경계, 의존성 방향)

## 4. 테스트 규칙
(프레임워크, 커버리지, 테스트 작성 패턴)

## 5. 금지 사항
(절대 하면 안 되는 것들)
```

### 각 섹션 작성 가이드

#### 빌드 & 실행 명령어

에이전트가 가장 먼저 확인하는 부분이에요. 의존성 설치부터 테스트 실행까지 한 눈에 볼 수 있게 작성하세요.

```markdown
## 빌드 & 실행

- 의존성 설치: `pnpm install`
- 개발 서버: `pnpm dev`
- 빌드: `pnpm build`
- 테스트 전체: `pnpm test`
- 테스트 단일: `pnpm test -- --filter {파일명}`
- 린트: `pnpm lint`
- 포맷: `pnpm format`
```

#### 코딩 컨벤션

**구체적일수록 좋아요.** "깔끔한 코드를 작성하세요" 같은 추상적인 지침은 효과가 없어요.

```markdown
## 코딩 컨벤션

- TypeScript strict 모드 필수 (`any` 타입 사용 금지)
- 함수는 화살표 함수로 작성 (React 컴포넌트 제외)
- import 순서: 외부 패키지 → 내부 모듈 → 타입 → 스타일
- 에러는 커스텀 에러 클래스 사용 (`src/errors/` 참조)
- 네이밍: camelCase (변수/함수), PascalCase (클래스/타입/컴포넌트)
```

#### 금지 사항

에이전트가 반복적으로 하는 실수를 여기에 적어두세요. **"하지 마라"가 "이렇게 해라"보다 효과적**인 경우가 많아요.

```markdown
## 금지 사항

- `console.log` 디버깅 코드를 프로덕션 코드에 남기지 말 것
- `eslint-disable` 주석 추가 금지 (규칙이 맞지 않으면 논의)
- `.env` 파일을 절대 커밋하지 말 것
- `any` 타입 사용 금지 — `unknown`으로 대체 후 타입 가드 사용
- 새 의존성 추가 시 반드시 이유를 커밋 메시지에 명시
```

## 프로젝트 규모별 설계 전략

### 소규모 프로젝트 (파일 50개 이하)

룰 파일 하나면 충분해요. CLAUDE.md 또는 AGENTS.md 하나에 모든 규칙을 담으세요.

```
프로젝트/
├── AGENTS.md          ← 모든 규칙 (200줄 이내)
├── src/
├── tests/
└── package.json
```

**유의할 점:** 소규모라도 빌드 명령어와 테스트 실행 방법은 반드시 포함하세요. 에이전트가 코드를 수정한 뒤 검증할 수 있어야 해요.

### 중규모 프로젝트 (파일 200~500개)

메인 룰 파일 + 하위 디렉토리별 룰 파일로 분리하세요.

```
프로젝트/
├── AGENTS.md          ← 공통 규칙 (빌드, 컨벤션, 아키텍처)
├── src/
│   ├── AGENTS.md      ← src 전용 규칙 (모듈 경계, import 규칙)
│   ├── api/
│   │   └── AGENTS.md  ← API 레이어 규칙 (응답 형식, 에러 코드)
│   └── core/
├── tests/
│   └── AGENTS.md      ← 테스트 규칙 (픽스처, 모킹 패턴)
└── package.json
```

Claude Code는 하위 디렉토리의 `CLAUDE.md`를 자동으로 인식해요. 에이전트가 `src/api/` 디렉토리에서 작업할 때는 루트의 CLAUDE.md와 `src/api/CLAUDE.md`를 함께 참조해요.

### 대규모 프로젝트 / 모노레포

패키지별 독립 룰 파일 + 글로벌 공통 규칙으로 나누세요.

```
monorepo/
├── AGENTS.md                    ← 글로벌 규칙 (모노레포 정책)
├── packages/
│   ├── web/
│   │   ├── AGENTS.md            ← 프론트엔드 전용 규칙
│   │   └── src/
│   ├── api/
│   │   ├── AGENTS.md            ← 백엔드 전용 규칙
│   │   └── src/
│   └── shared/
│       ├── AGENTS.md            ← 공유 라이브러리 규칙
│       └── src/
└── turbo.json
```

**글로벌 AGENTS.md에 넣을 것:**
- 모노레포 빌드 시스템 (Turborepo, Nx 등) 명령어
- 패키지 간 의존성 방향 규칙
- 공통 린트/포맷 설정
- PR/커밋 컨벤션

**패키지별 AGENTS.md에 넣을 것:**
- 해당 패키지의 빌드/테스트 명령어
- 프레임워크 특화 규칙 (React, Express 등)
- 디렉토리 구조와 파일 배치 규칙

## 멀티 에이전트 대응 전략

팀에서 여러 AI 도구를 쓴다면, **하나의 공통 파일 + 에이전트별 래퍼** 구조가 관리하기 편해요.

```
프로젝트/
├── AGENTS.md                ← 공통 진실의 원천 (모든 규칙)
├── CLAUDE.md                ← "@import AGENTS.md" + Claude 전용 설정
├── .cursor/rules/
│   └── project.mdc          ← AGENTS.md 내용 반영 + Cursor 전용 설정
├── .github/
│   └── copilot-instructions.md  ← AGENTS.md 내용 반영
└── src/
```

```markdown
<!-- CLAUDE.md 예시 -->
# Claude Code 설정

@AGENTS.md 파일의 모든 규칙을 따르세요.

## Claude 전용 추가 규칙
- 파일 수정 후 반드시 `pnpm typecheck` 실행
- 새 함수 작성 시 JSDoc 주석 필수
```

이렇게 하면 규칙을 한 곳에서만 관리하면서, 각 에이전트의 특성에 맞게 확장할 수 있어요.

## 실전에서 효과적인 룰 작성 패턴

### 패턴 1: Before/After 예시

추상적인 규칙보다 구체적인 예시가 에이전트에게 훨씬 효과적이에요.

```markdown
## 에러 핸들링 규칙

❌ 이렇게 하지 마세요:
```typescript
try {
  const user = await getUser(id);
} catch (e) {
  throw new Error("failed");
}
```

✅ 이렇게 하세요:
```typescript
try {
  const user = await getUser(id);
} catch (error) {
  throw new UserNotFoundError(id, { cause: error });
}
```
```

### 패턴 2: 결정 트리

조건에 따라 다른 패턴을 써야 할 때 유용해요.

```markdown
## 상태 관리 선택 기준

- 컴포넌트 로컬 상태 → `useState`
- 형제 컴포넌트 간 공유 → `Context` + `useReducer`
- 서버 데이터 캐싱 → `TanStack Query`
- 복잡한 클라이언트 상태 → `Zustand`
- 절대 사용 금지: Redux (프로젝트에서 제거 중)
```

### 패턴 3: 디렉토리 맵

새 파일을 어디에 만들어야 하는지 명확하게 알려주세요.

```markdown
## 파일 배치 규칙

| 파일 종류 | 위치 | 네이밍 |
|----------|------|--------|
| React 컴포넌트 | `src/components/{도메인}/` | PascalCase.tsx |
| API 라우트 | `src/app/api/{리소스}/` | route.ts |
| 유틸리티 | `src/lib/` | camelCase.ts |
| 타입 정의 | `src/types/` | {도메인}.types.ts |
| 테스트 | `__tests__/{원본과 같은 경로}/` | {원본}.test.ts |
| E2E 테스트 | `e2e/` | {시나리오}.spec.ts |
```

### 패턴 4: 체크리스트 형식

에이전트가 PR이나 코드 리뷰 전에 자체 점검할 수 있게 만들어요.

```markdown
## PR 전 자체 검증

- [ ] `pnpm typecheck` 통과
- [ ] `pnpm test` 통과
- [ ] `pnpm lint` 통과
- [ ] 새 의존성 추가 시 `pnpm audit` 확인
- [ ] 환경변수 추가 시 `.env.example` 업데이트
- [ ] DB 스키마 변경 시 마이그레이션 파일 생성
```

## 흔한 실수와 해결

| 실수 | 왜 문제인가 | 해결 |
|------|------------|------|
| 룰 파일이 500줄 이상 | 에이전트 컨텍스트 윈도우 낭비, 우선순위 혼란 | 디렉토리별로 분리하거나 핵심만 남기기 |
| "깔끔한 코드 작성" 같은 모호한 지침 | 에이전트가 해석할 수 없음 | Before/After 예시로 구체화 |
| 상충하는 규칙 | 에이전트가 랜덤하게 하나를 선택 | 우선순위를 명시하거나 규칙 통합 |
| 한 번 작성하고 업데이트 안 함 | 프로젝트가 바뀌면 룰 파일도 바뀌어야 함 | 분기별 리뷰 일정 설정 |
| 모든 상황을 커버하려는 과욕 | 중요한 규칙이 묻힘 | 80/20 법칙 — 자주 겪는 문제 위주로 |
| 에이전트별 파일을 각각 관리 | 규칙이 어긋나기 시작 | 공통 AGENTS.md → 에이전트별 래퍼 |

## Cursor Rules 특화 팁

Cursor는 `.cursor/rules/` 디렉토리에 MDC 형식 파일을 사용해요. **glob 패턴으로 특정 파일에만 규칙을 적용**할 수 있어서 세밀한 제어가 가능해요.

```yaml
# .cursor/rules/react-components.mdc
---
description: React 컴포넌트 작성 규칙
globs: ["src/components/**/*.tsx"]
alwaysApply: false
---

# React 컴포넌트 규칙

- 함수 컴포넌트만 사용 (class 컴포넌트 금지)
- Props 타입은 인라인 대신 별도 interface로 분리
- forwardRef 사용 시 displayName 필수
```

```yaml
# .cursor/rules/api-routes.mdc
---
description: API 라우트 작성 규칙
globs: ["src/app/api/**/*.ts"]
alwaysApply: false
---

# API 라우트 규칙

- 모든 응답은 NextResponse.json() 사용
- 에러 응답 형식: { error: string, code: string }
- 인증 필요 라우트는 withAuth 미들웨어 래핑
```

**alwaysApply 설정 가이드:**
- `true`: 항상 컨텍스트에 포함 (빌드 명령어, 공통 컨벤션)
- `false`: 매칭되는 파일 작업 시에만 포함 (토큰 절약)

## 팀에 적용하기

### 1단계: 현재 규칙 수집 (1시간)

팀원들한테 "AI 에이전트한테 매번 반복해서 알려주는 게 뭐예요?"라고 물어보세요. 그게 룰 파일에 들어갈 내용이에요.

### 2단계: 초안 작성 (30분)

빌드 명령어 + 핵심 컨벤션 5개 + 금지 사항 3개로 시작하세요. 처음부터 완벽할 필요 없어요.

### 3단계: 팀 리뷰 (PR 기반)

룰 파일도 코드처럼 PR로 관리하세요. 변경 이력이 남고, 팀원들이 리뷰할 수 있어요.

### 4단계: 주기적 업데이트

코드 리뷰에서 반복되는 피드백이 있으면 룰 파일에 추가하세요. 살아있는 문서로 유지하는 게 핵심이에요.

```bash
# 룰 파일 변경 이력 확인
git log --oneline AGENTS.md

# 팀원 제안으로 규칙 추가
git checkout -b chore/update-agents-rules
# ... 규칙 추가 ...
git commit -m "chore: add error handling convention to AGENTS.md"
```

## 다음 단계

→ [CLAUDE.md 템플릿](../templates/CLAUDE.md.template) — 바로 사용할 수 있는 템플릿
→ [프로젝트 셋업 가이드](01-project-setup.md) — AI 코딩 시작 설정
→ [프롬프트 체이닝 패턴](50-advanced-prompt-chaining-patterns.md) — 효과적인 프롬프트 설계

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
