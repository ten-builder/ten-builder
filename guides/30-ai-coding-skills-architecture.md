# 30. Claude Code Skills 아키텍처 설계 가이드

> CLAUDE.md 한 파일에 모든 규칙을 우겨넣던 시절은 끝났습니다. Skills로 프로젝트 지식을 모듈화하고 팀과 공유하는 방법을 다룹니다.

## Skills가 필요한 이유

프로젝트가 커지면 CLAUDE.md도 같이 커져요. 500줄이 넘어가면 에이전트가 필요한 규칙을 놓치기 시작하고, 팀원마다 다른 버전의 CLAUDE.md를 쓰게 됩니다. 결국 "이 규칙 왜 안 먹혀요?"라는 질문이 반복돼요.

Skills는 이 문제를 해결하는 구조예요:
- **관심사 분리** — 배포 규칙과 코딩 스타일을 각각 독립된 파일로 관리
- **조건부 로딩** — 프론트엔드 작업할 때만 React 규칙을 활성화
- **팀 공유** — Git으로 버전 관리하고 PR 리뷰를 거쳐 업데이트
- **재사용** — 여러 프로젝트에서 동일한 Skills를 참조

## 사전 준비

- Claude Code CLI (최신 버전)
- 프로젝트 루트에 `.claude/` 디렉토리
- CLAUDE.md 기본 설정 완료

## Step 1: 디렉토리 구조 설계

Skills의 물리적 구조부터 잡아요. 핵심 원칙은 **한 파일 = 한 관심사**입니다.

```
project-root/
├── CLAUDE.md                    # 진입점 (라우팅만)
├── .claude/
│   ├── skills/
│   │   ├── coding-style.md      # 코딩 스타일
│   │   ├── testing.md           # 테스트 규칙
│   │   ├── deployment.md        # 배포 프로세스
│   │   ├── security.md          # 보안 정책
│   │   └── api-design.md        # API 설계 패턴
│   ├── context/
│   │   ├── architecture.md      # 시스템 아키텍처
│   │   └── dependencies.md      # 주요 의존성 설명
│   └── templates/
│       ├── pr-template.md       # PR 본문 템플릿
│       └── commit-guide.md      # 커밋 메시지 가이드
```

### CLAUDE.md를 라우터로 전환

CLAUDE.md에는 규칙을 직접 쓰지 않아요. 대신 Skills로의 **라우팅 테이블**만 유지합니다.

```markdown
# CLAUDE.md

## Context Routing

| 키워드 | Skill 파일 |
|--------|-----------|
| 스타일, 포맷, lint | `.claude/skills/coding-style.md` |
| 테스트, jest, pytest | `.claude/skills/testing.md` |
| 배포, CI, CD | `.claude/skills/deployment.md` |
| 보안, auth, 토큰 | `.claude/skills/security.md` |
| API, 엔드포인트, 스키마 | `.claude/skills/api-design.md` |

## 기본 규칙
- 커밋 메시지는 영어
- PR 생성 전 rebase 필수
- .claude/ 폴더는 커밋하지 않음
```

이렇게 하면 CLAUDE.md는 항상 가볍게 유지되고, 에이전트는 작업 맥락에 맞는 Skill만 로딩해요.

## Step 2: Skill 파일 작성 패턴

좋은 Skill 파일에는 공통적인 구조가 있어요.

### 기본 구조

```markdown
---
tags: [skill-name, related-topic]
updated: 2026-03-24
scope: 이 skill이 적용되는 범위
---

# Skill: 코딩 스타일

> 한 줄 요약 — 이 프로젝트의 코딩 컨벤션

## 반드시 따를 규칙 (MUST)

1. 함수명은 camelCase
2. 컴포넌트명은 PascalCase
3. 상수는 UPPER_SNAKE_CASE

## 권장 사항 (SHOULD)

- early return 패턴 선호
- 매직 넘버 대신 상수 정의
- 3줄 이상의 조건문은 함수로 추출

## 하지 말 것 (MUST NOT)

- any 타입 사용 금지
- console.log 커밋 금지
- 주석으로 코드 비활성화 금지

## 예시

```typescript
// Good
const getUserName = (user: User): string => {
  if (!user.profile) return 'Anonymous';
  return user.profile.displayName;
};

// Bad
function get_user_name(user: any) {
  // console.log(user);
  if (user.profile) {
    return user.profile.displayName;
  } else {
    return 'Anonymous';
  }
}
```
```

### 작성 규칙

| 항목 | 권장 |
|------|------|
| 파일 크기 | 100~300줄 (초과 시 분리) |
| 규칙 수 | MUST 5~10개, SHOULD 5~15개 |
| 예시 | 규칙당 Good/Bad 최소 1쌍 |
| 업데이트 주기 | 분기별 또는 메이저 변경 시 |

## Step 3: 계층 구조와 상속

Skills는 계층적으로 구성할 수 있어요. 조직 공통 → 프로젝트 → 모듈 순으로 구체화됩니다.

```
~/.claude/skills/           # 개인/조직 공통 (모든 프로젝트)
  ├── git-conventions.md
  └── code-review.md

~/project-a/.claude/skills/ # 프로젝트 A 전용
  ├── coding-style.md       # 프로젝트 컨벤션
  └── deployment.md         # 배포 환경

~/project-a/packages/api/.claude/skills/
  └── api-rules.md          # API 모듈 전용
```

### 우선순위 규칙

규칙이 충돌할 때의 우선순위:

| 우선순위 | 레벨 | 예시 |
|---------|------|------|
| 1 (최고) | 모듈 레벨 | `packages/api/.claude/skills/` |
| 2 | 프로젝트 레벨 | `project/.claude/skills/` |
| 3 (최저) | 사용자 레벨 | `~/.claude/skills/` |

가까운 범위가 먼 범위보다 우선해요. 프로젝트에서 "들여쓰기 4칸"이라고 했으면, 사용자 설정의 "들여쓰기 2칸"을 덮어씁니다.

## Step 4: 레퍼런스 파일 연동

Skills만으로는 부족한 경우가 있어요. 복잡한 아키텍처 설명이나 외부 API 스펙은 별도 레퍼런스로 분리하세요.

```markdown
# Skill: API 설계

## 참조 문서
- 아키텍처: `.claude/context/architecture.md`
- OpenAPI 스펙: `docs/api-spec.yaml`
- 에러 코드 목록: `docs/error-codes.md`
```

### 레퍼런스 파일 가이드라인

```
.claude/context/
├── architecture.md     # 시스템 구조도 + 데이터 흐름
├── dependencies.md     # 핵심 라이브러리와 선택 이유
├── glossary.md         # 프로젝트 전용 용어집
└── decisions/          # ADR (Architecture Decision Records)
    ├── 001-auth.md
    └── 002-database.md
```

| 파일 유형 | 권장 크기 | 업데이트 시점 |
|----------|----------|-------------|
| architecture.md | 200줄 이내 | 아키텍처 변경 시 |
| dependencies.md | 100줄 이내 | 의존성 추가/변경 시 |
| glossary.md | 50줄 이내 | 새 도메인 개념 추가 시 |
| ADR | 각 50줄 이내 | 결정 시점에 1회 |

## Step 5: 팀 공유 전략

Skills를 팀 단위로 운영하는 패턴이에요.

### Git 기반 공유

```bash
# 조직 공통 Skills를 별도 레포로 관리
git clone git@github.com:org/coding-standards.git ~/.claude/org-skills

# 프로젝트 CLAUDE.md에서 참조
# "조직 스킬: ~/.claude/org-skills/ 참조"
```

### PR 리뷰 프로세스

Skills 변경도 코드처럼 리뷰를 거쳐요:

1. Skill 파일 수정 → feature 브랜치
2. PR 생성 (변경 이유 + 영향 범위 명시)
3. 팀원 2명 이상 승인
4. main 머지 후 팀 공지

```yaml
# .github/CODEOWNERS
/.claude/skills/  @team-leads
/.claude/context/ @architects
```

### 버전 관리 팁

```markdown
---
tags: [coding-style]
updated: 2026-03-24
version: 2.1
changelog:
  - "2.1: any 타입 금지 규칙 추가"
  - "2.0: TypeScript 전환에 맞춰 전면 개편"
  - "1.0: 초기 JavaScript 컨벤션"
---
```

## Step 6: 실전 운영 패턴

### 패턴 1: 온보딩 Skill

새 팀원이 프로젝트를 빠르게 파악할 수 있는 전용 Skill:

```markdown
# Skill: 온보딩

## 프로젝트 한 줄 요약
결제 SaaS. Next.js + Supabase + Stripe.

## 핵심 디렉토리
- `src/app/` — 페이지 라우트
- `src/lib/` — 비즈니스 로직
- `src/components/` — 공유 컴포넌트
- `supabase/migrations/` — DB 마이그레이션

## 로컬 실행
1. `cp .env.example .env.local`
2. `pnpm install`
3. `pnpm dev`

## 자주 하는 작업
- 새 API 추가: `.claude/skills/api-design.md` 참조
- 컴포넌트 생성: `.claude/skills/coding-style.md` 참조
```

### 패턴 2: 조건부 활성화

작업 유형에 따라 Skill을 선택적으로 적용하는 패턴:

```markdown
# CLAUDE.md - Context Routing

## 자동 감지 규칙
- `src/app/` 파일 수정 시 → `skills/frontend.md` 활성화
- `src/api/` 파일 수정 시 → `skills/api-design.md` 활성화  
- `tests/` 파일 수정 시 → `skills/testing.md` 활성화
- PR 리뷰 요청 시 → `skills/code-review.md` 활성화
```

### 패턴 3: 프로젝트 간 Skill 재사용

```bash
# 공통 Skill을 심볼릭 링크로 공유
ln -s ~/.claude/shared-skills/typescript.md \
      ~/project-a/.claude/skills/typescript.md
ln -s ~/.claude/shared-skills/typescript.md \
      ~/project-b/.claude/skills/typescript.md
```

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| CLAUDE.md에 모든 규칙을 직접 작성 | Skills로 분리하고 라우팅 테이블만 유지 |
| Skill 파일이 500줄 초과 | 관심사별로 2~3개로 분리 |
| 예시 없이 규칙만 나열 | 규칙당 Good/Bad 코드 예시 추가 |
| 레퍼런스 파일 업데이트 안 함 | CODEOWNERS + PR 리뷰로 강제 |
| 팀원마다 다른 Skills 버전 사용 | Git 레포로 중앙 관리 |
| 모든 Skill을 항상 로딩 | 조건부 활성화로 컨텍스트 절약 |

## 체크리스트

- [ ] CLAUDE.md를 라우팅 테이블로 전환했는가
- [ ] Skill 파일이 각각 300줄 이내인가
- [ ] 각 Skill에 MUST/SHOULD/MUST NOT이 구분되어 있는가
- [ ] Good/Bad 예시가 포함되어 있는가
- [ ] 팀 공유를 위한 CODEOWNERS가 설정되어 있는가
- [ ] 레퍼런스 파일이 최신 상태인가

## 다음 단계

→ [하네스 엔지니어링 가이드](13-harness-engineering.md) — Skills를 포함한 전체 실행 환경 설계
→ [CLAUDE.md 최적화 플레이북](../claude-code/playbooks/13-claudemd-optimization.md) — CLAUDE.md 작성 실전 팁

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
