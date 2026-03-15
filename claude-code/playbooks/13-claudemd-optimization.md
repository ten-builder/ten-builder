# 플레이북 13: CLAUDE.md 최적화

> 프로젝트별 CLAUDE.md를 제대로 작성해서 AI 코딩 도구의 출력 품질을 끌어올리는 실전 가이드

## 언제 쓰나요?

- Claude Code에게 매번 같은 규칙을 반복 설명하고 있을 때
- 팀원마다 AI 출력 스타일이 제각각이라 통일이 필요할 때
- AI가 프로젝트 컨벤션을 무시하고 기본 스타일로 코드를 생성할 때
- 새 프로젝트를 시작하면서 AI 협업 기반을 잡고 싶을 때

## 소요 시간

20-30분

## 사전 준비

- Claude Code 설치 및 기본 사용 경험
- 프로젝트 코드베이스 (신규 또는 기존)
- 팀 코딩 컨벤션 문서 (있으면 좋음)

## Step 1: CLAUDE.md의 3계층 구조 이해하기

CLAUDE.md는 세 곳에 둘 수 있고, 각각 적용 범위가 다릅니다.

| 위치 | 적용 범위 | 용도 |
|------|----------|------|
| `~/.claude/CLAUDE.md` | 모든 프로젝트 | 개인 선호 (언어, 스타일) |
| `프로젝트루트/CLAUDE.md` | 현재 프로젝트 전체 | 프로젝트 규칙 |
| `하위폴더/CLAUDE.md` | 해당 폴더 내 | 모듈별 특수 규칙 |

```bash
# 글로벌 설정 생성
mkdir -p ~/.claude
cat > ~/.claude/CLAUDE.md << 'EOF'
# Global Rules
- 한국어로 커밋 메시지를 쓰지 않는다
- 타입스크립트 프로젝트에서는 any 타입을 쓰지 않는다
- console.log 대신 구조화된 로거를 사용한다
EOF

# 프로젝트 루트 설정 생성
cat > CLAUDE.md << 'EOF'
# Project: my-saas-app
## 기술 스택
- Next.js 15 + TypeScript
- Supabase (Auth + DB)
- Tailwind CSS v4
EOF
```

> **핵심:** 글로벌에는 개인 습관, 프로젝트 루트에는 프로젝트 규칙, 하위 폴더에는 모듈 특수 사항을 넣으세요. Claude Code는 세 파일을 자동으로 합쳐서 읽습니다.

## Step 2: 필수 섹션 10가지

실전에서 가장 효과 있는 섹션을 우선순위 순으로 정리했어요.

### 1. 프로젝트 개요 (필수)

```markdown
## Project Overview
SaaS 대시보드 — B2B 고객이 데이터 파이프라인을 모니터링하는 웹앱.
```

두 줄이면 충분합니다. AI가 "이 프로젝트가 뭐하는 건지"를 바로 이해할 수 있게요.

### 2. 기술 스택 (필수)

```markdown
## Tech Stack
- Runtime: Node.js 22, TypeScript 5.7 (strict mode)
- Framework: Next.js 15 (App Router)
- DB: Supabase PostgreSQL + Row Level Security
- Styling: Tailwind CSS v4 + shadcn/ui
- Test: Vitest + Playwright
- Deploy: Vercel
```

버전 번호가 중요합니다. `"Next.js 사용"`이라고만 쓰면 AI가 Pages Router 코드를 생성할 수 있어요.

### 3. 코딩 컨벤션 (필수)

```markdown
## Coding Conventions
- 함수형 컴포넌트 + 커스텀 훅 패턴 사용
- OOP 클래스는 외부 서비스 커넥터에만 사용
- 비즈니스 로직은 순수 함수로 분리
- 파일명: kebab-case (user-profile.ts)
- 컴포넌트명: PascalCase (UserProfile.tsx)
- import 순서: React → 외부 → 내부 → 타입
```

### 4. 아키텍처 구조 (권장)

```markdown
## Architecture
src/
├── app/          # Next.js App Router 페이지
├── components/   # 공유 UI 컴포넌트
├── lib/          # 비즈니스 로직 + 유틸리티
├── hooks/        # 커스텀 React 훅
├── types/        # TypeScript 타입 정의
└── services/     # 외부 API 연동
```

디렉토리 트리를 넣으면 AI가 새 파일을 올바른 위치에 만들어요.

### 5. 금지 사항 (효과 높음)

```markdown
## Do NOT
- `any` 타입 사용 금지 — unknown + 타입 가드 사용
- console.log 디버깅 금지 — pino 로거 사용
- 인라인 스타일 금지 — Tailwind 클래스 사용
- API 키를 코드에 하드코딩 금지 — 환경변수 사용
- default export 사용 금지 (페이지 컴포넌트 제외)
```

> **팁:** "~하지 마라" 규칙이 "~해라" 규칙보다 AI 출력 품질에 더 큰 영향을 줍니다. AI는 허용 범위를 넓게 해석하는 경향이 있거든요.

### 6. 테스트 규칙 (권장)

```markdown
## Testing Rules
- 새 함수 작성 시 유닛 테스트 필수 (vitest)
- API 엔드포인트는 통합 테스트 포함
- 테스트 파일: __tests__/모듈명.test.ts
- 모킹: vi.mock 사용, 외부 서비스만 모킹
- 커버리지 목표: 라인 80% 이상
```

### 7. Git 워크플로우

```markdown
## Git Rules
- 커밋 메시지: Conventional Commits (feat:, fix:, chore:)
- 브랜치: feature/기능명, fix/버그명
- main 직접 커밋 금지 — PR 필수
- 커밋 전 pnpm lint && pnpm test 실행
```

### 8. 외부 연동 정보

```markdown
## External Services
- Auth: Supabase Auth (magic link + OAuth)
- Payment: Stripe (test mode key: .env.local)
- Email: Resend API
- Monitoring: Sentry
```

### 9. 현재 작업 컨텍스트

```markdown
## Current Focus
- 대시보드 차트 컴포넌트 리팩토링 중 (recharts → visx 마이그레이션)
- 인증 미들웨어 테스트 추가 작업 진행 중
- /api/pipelines 엔드포인트 페이지네이션 구현 예정
```

이 섹션은 자주 바뀌어도 괜찮아요. AI에게 "지금 뭘 하고 있는지"를 알려주면 관련 코드를 더 정확하게 생성합니다.

### 10. 참조 문서 링크

```markdown
## References
- API 문서: docs/api-reference.md
- DB 스키마: prisma/schema.prisma
- 디자인 시스템: docs/design-system.md
```

## Step 3: 효과적인 작성 패턴

### 패턴 1: 구체적 > 추상적

```markdown
# Bad
- 깨끗한 코드를 작성한다
- 에러 처리를 잘 한다

# Good
- 함수 하나에 매개변수 3개 이하
- 에러는 Result<T, Error> 패턴으로 처리 (throw 금지)
```

### 패턴 2: 예시 포함

```markdown
# Bad
- API 응답 형식을 통일한다

# Good
- API 응답 형식:
  성공: { data: T, meta?: { page, total } }
  실패: { error: { code: string, message: string } }
```

### 패턴 3: 분량 조절

| 분량 | 효과 |
|------|------|
| ~50줄 | 핵심만 빠르게, 소규모 프로젝트에 적합 |
| 50~150줄 | 가장 이상적인 범위, 대부분의 프로젝트 |
| 150줄 이상 | 컨텍스트 낭비 가능성, 분할 권장 |

> **경험칙:** 150줄을 넘으면 하위 폴더 CLAUDE.md로 분리하는 게 낫습니다. 전체를 항상 읽히면 토큰 낭비이거든요.

## Step 4: 팀 공유 전략

혼자 쓰면 편하지만, 팀 전체가 같은 CLAUDE.md를 쓰면 코드 일관성이 생깁니다.

### 방법 1: Git 커밋 (권장)

```bash
# CLAUDE.md를 레포에 포함
git add CLAUDE.md
git commit -m "chore: add CLAUDE.md project rules"
```

팀 전체가 같은 규칙으로 AI를 쓰게 됩니다. PR 리뷰에서 "AI가 생성한 코드인데 스타일이 다르다"는 코멘트가 사라져요.

### 방법 2: 글로벌 규칙 공유 레포

```bash
# 팀 공통 규칙 레포
git clone git@github.com:my-org/claude-rules.git ~/.claude/rules

# ~/.claude/CLAUDE.md에서 참조
cat > ~/.claude/CLAUDE.md << 'EOF'
# Team Rules
@import ~/.claude/rules/typescript.md
@import ~/.claude/rules/testing.md
EOF
```

### 방법 3: 템플릿 제공

```bash
# 프로젝트 초기화 스크립트에 포함
cp templates/CLAUDE.md.template ./CLAUDE.md
# 팀원이 프로젝트별로 커스터마이징
```

## Step 5: 유지보수 루틴

CLAUDE.md는 한번 쓰고 끝이 아니에요. 프로젝트와 함께 진화해야 합니다.

### 주간 리뷰 체크리스트

- [ ] 기술 스택 버전이 실제와 일치하는가?
- [ ] "현재 작업 컨텍스트"가 최신인가?
- [ ] 더 이상 쓰지 않는 규칙이 있는가?
- [ ] AI가 반복적으로 무시하는 규칙이 있는가? (표현 개선 필요)

```bash
# CLAUDE.md 변경 히스토리 확인
git log --oneline -10 -- CLAUDE.md

# 최근 2주 수정 없으면 리뷰 필요 신호
git log -1 --format="%ar" -- CLAUDE.md
```

### AI가 규칙을 무시할 때

규칙을 적었는데 AI가 계속 무시하면 표현을 바꿔보세요:

| 약한 표현 | 강한 표현 |
|----------|----------|
| `~를 선호한다` | `~를 반드시 사용한다` |
| `가능하면 ~한다` | `~하지 않으면 안 된다` |
| `~를 권장한다` | `~가 아닌 코드는 거부한다` |

## 체크리스트

- [ ] 글로벌/프로젝트/하위폴더 3계층 중 필요한 곳에 배치
- [ ] 프로젝트 개요 + 기술 스택 + 코딩 컨벤션 필수 포함
- [ ] 금지 사항을 구체적으로 명시
- [ ] 150줄 이하로 유지 (초과 시 분할)
- [ ] Git에 커밋하여 팀 공유
- [ ] 주간 리뷰 루틴 설정

## 다음 단계

→ [플레이북 14: AI 코딩 보안 점검](../playbooks/14-security-checklist.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
