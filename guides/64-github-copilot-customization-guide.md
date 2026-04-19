# GitHub Copilot 팀 맞춤 설정 가이드 2026

> 커스텀 지시사항과 익스텐션 설정으로 팀 전체가 일관된 AI 코딩 환경을 갖추는 방법

## 왜 팀 설정이 중요한가

GitHub Copilot을 그냥 켜두면 개발자마다 다른 스타일, 다른 맥락으로 코드를 제안받는다. 팀이 5명이면 5가지 코딩 스타일이 나온다.

팀 단위로 Copilot을 설정하면:
- 코드 스타일과 컨벤션을 AI가 자동으로 맞춰준다
- 신규 입사자도 팀 규칙을 빠르게 흡수할 수 있다
- PR 리뷰에서 스타일 지적이 줄어든다

---

## 설정 파일 구조

GitHub Copilot의 팀 설정은 레포지토리에 파일로 관리한다. Git으로 공유하면 팀 전체가 동일한 설정을 쓴다.

```
.github/
├── copilot-instructions.md    # 레포 전체 기본 지시사항
└── instructions/              # 파일 유형별 세분화 지시사항
    ├── python.instructions.md
    ├── typescript.instructions.md
    └── review.instructions.md
```

### 우선순위 (높은 순)
1. 개인 설정 (VS Code 사용자 설정)
2. 레포지토리 (`.github/copilot-instructions.md`, `AGENTS.md`)
3. 조직 설정 (GitHub 조직 관리자 설정)

---

## Phase 1: 기본 지시사항 파일 작성

### `.github/copilot-instructions.md` 기본 구조

```markdown
# 프로젝트 Copilot 지시사항

## 기술 스택
- Node.js 22 + TypeScript 5.x
- Next.js 15 (App Router)
- PostgreSQL + Prisma ORM
- Tailwind CSS

## 코드 스타일
- 함수 이름: camelCase
- 컴포넌트 이름: PascalCase
- 상수: SCREAMING_SNAKE_CASE
- 들여쓰기: 2칸 공백 (탭 금지)

## 아키텍처 패턴
- 서버 컴포넌트를 기본으로 사용. 클라이언트 컴포넌트는 명시적으로 선택
- 비즈니스 로직은 서비스 레이어에 분리 (`/services/`)
- 데이터 페칭은 React Query 사용

## 보안 요구사항
- 사용자 입력은 zod로 반드시 검증
- SQL 쿼리 직접 작성 금지 (Prisma 사용)
- 시크릿은 환경변수로만 관리

## 문서화
- 공개 함수에는 JSDoc 주석 추가
- 복잡한 로직에는 한 줄 설명 코멘트 삽입
```

---

## Phase 2: 파일 유형별 세분화 설정

레포 전체 지시사항 외에, 파일 유형별로 더 구체적인 설정을 추가할 수 있다.

### `.github/instructions/typescript.instructions.md`

```markdown
---
applyTo: "**/*.ts,**/*.tsx"
---

## TypeScript 규칙
- `any` 타입 사용 금지. `unknown` 또는 구체적인 타입 사용
- 타입 단언(`as`) 최소화. 타입 가드 함수 사용 권장
- `interface`보다 `type` 우선 (유니온 타입이 필요한 경우만 예외)
- 옵셔널 체이닝(`?.`)과 nullish coalescing(`??`) 적극 활용
```

### `.github/instructions/review.instructions.md`

```markdown
---
applyTo: "**"
---

## 코드 리뷰 지시사항
- 성능 문제가 될 수 있는 코드는 반드시 언급
- 테스트 커버리지가 부족한 부분 지적
- 보안 취약점 (인젝션, XSS, 인증 누락) 우선 확인
```

---

## Phase 3: 조직 단위 공유 설정

2026년 4월부터 조직(Organization) 레벨의 커스텀 지시사항이 일반 공개됐다. GitHub 조직 설정에서 모든 레포에 적용되는 기본 지시사항을 관리할 수 있다.

### 설정 방법

1. GitHub 조직 → Settings → Copilot
2. "Custom instructions" 탭 선택
3. 조직 전체에 적용할 지시사항 작성

### 조직 지시사항 예시

```markdown
## 보안 정책
- 의존성 취약점 발견 시 즉시 보고
- 개인정보(이름, 이메일, 전화번호) 하드코딩 절대 금지
- 내부 API 키는 환경변수로만 관리

## 공통 컨벤션
- 커밋 메시지: Conventional Commits 형식 준수
- PR 제목: `feat:`, `fix:`, `docs:` 등 prefix 필수
```

---

## Phase 4: 태스크별 지시사항

특정 작업(커밋 메시지 작성, PR 설명 생성 등)에 전용 지시사항을 설정할 수 있다.

| 태스크 | 파일명 |
|--------|--------|
| 커밋 메시지 | `commitMessageGeneration.instructions.md` |
| PR 설명 | `pullRequestDescription.instructions.md` |
| 코드 리뷰 | `codeReview.instructions.md` |
| 테스트 생성 | `testGeneration.instructions.md` |

### `.github/instructions/commitMessageGeneration.instructions.md`

```markdown
---
applyTo: commitMessage
---

커밋 메시지는 Conventional Commits 형식으로 작성하세요.

형식: `type(scope): description`

type 목록:
- feat: 새 기능
- fix: 버그 수정
- docs: 문서만 변경
- refactor: 기능 변경 없는 코드 개선
- test: 테스트 추가/수정

예시:
- `feat(auth): add Google OAuth login`
- `fix(api): handle null response from payment service`
```

---

## Phase 5: 실전 팀 온보딩 워크플로우

팀에 Copilot 설정을 처음 도입할 때 순서:

### Step 1: 현재 코드베이스 분석

```bash
# 프로젝트에서 자주 사용하는 패턴 파악
find . -name "*.ts" -not -path "*/node_modules/*" | head -20 | xargs head -30
```

기존 코드의 스타일과 패턴을 파악한 뒤 지시사항 파일을 작성한다.

### Step 2: 초안 작성 후 팀 리뷰

```bash
# 지시사항 파일 생성
mkdir -p .github/instructions
touch .github/copilot-instructions.md

# 팀 리뷰를 위한 PR 생성
git checkout -b chore/add-copilot-instructions
git add .github/
git commit -m "chore: add Copilot team instructions"
gh pr create --title "chore: add Copilot team instructions"
```

### Step 3: 효과 측정

도입 전후 2주간 다음 지표를 비교한다:

| 지표 | 측정 방법 |
|------|----------|
| PR 스타일 지적 수 | PR 코멘트 수 비교 |
| 코드 리뷰 시간 | PR 생성→머지 소요 시간 |
| 린트 에러 발생 수 | CI 파이프라인 로그 |

---

## 주의사항

- 지시사항이 너무 길면 Copilot이 일부를 무시할 수 있다. 핵심만 간결하게 작성
- 레포별로 지나치게 다른 설정을 쓰면 오히려 혼란스럽다. 조직 공통 설정을 기반으로 레포별 예외만 추가
- 정기적으로(월 1회) 지시사항을 검토하고 팀 피드백을 반영

---

**더 자세한 내용:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
