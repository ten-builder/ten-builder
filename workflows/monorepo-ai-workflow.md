# 모노레포 + AI 코딩 도구 워크플로우

> 수십 개의 패키지가 있는 모노레포에서도 AI 코딩 도구를 효과적으로 쓸 수 있어요 — 컨텍스트 관리가 핵심이에요

## 개요

모노레포는 코드 공유와 일관성 측면에서 좋은 선택이지만, AI 코딩 도구를 사용할 때 한 가지 문제가 생겨요. 코드베이스가 너무 크면 AI가 전체를 이해하기 어렵고, 토큰 한도에 걸리기도 해요. 이 워크플로우에서는 모노레포 환경에서 컨텍스트를 적절히 나누고, AI 도구가 필요한 부분만 정확히 참조하도록 설정하는 방법을 다뤄요.

## 사전 준비

- 모노레포 프로젝트 (Turborepo, Nx, pnpm workspace 등)
- Claude Code 또는 Cursor AI
- 기본적인 모노레포 구조 이해

## 설정

### Step 1: 계층형 CLAUDE.md 구조 만들기

모노레포에서 가장 중요한 건 CLAUDE.md를 패키지별로 나누는 거예요. 루트에 전체 아키텍처를, 각 패키지에 세부 컨텍스트를 배치해요:

```
my-monorepo/
├── CLAUDE.md              # 전체 아키텍처, 공통 컨벤션
├── packages/
│   ├── web/
│   │   └── CLAUDE.md      # 프론트엔드 컨텍스트
│   ├── api/
│   │   └── CLAUDE.md      # 백엔드 컨텍스트
│   └── shared/
│       └── CLAUDE.md      # 공유 라이브러리 컨텍스트
```

루트 CLAUDE.md 예시:

```markdown
# 프로젝트 아키텍처

## 패키지 구조
- `packages/web` — Next.js 프론트엔드 (포트 3000)
- `packages/api` — FastAPI 백엔드 (포트 8000)
- `packages/shared` — 공유 타입, 유틸리티

## 공통 컨벤션
- TypeScript strict mode
- pnpm workspace 사용
- 테스트: vitest (web), pytest (api)

## 패키지 간 의존성
web → shared (타입 임포트)
api → shared (스키마 검증)
```

### Step 2: .cursorignore로 불필요한 파일 제외

Cursor를 쓸 때는 인덱싱 범위를 제한하면 응답 속도가 확 달라져요:

```
# .cursorignore
node_modules/
dist/
.next/
__pycache__/
*.lock
coverage/
.turbo/
```

### Step 3: 패키지별 작업 스크립트 설정

AI에게 특정 패키지만 작업시킬 때 유용한 Turborepo 필터 설정이에요:

```json
{
  "scripts": {
    "dev:web": "turbo run dev --filter=web",
    "dev:api": "turbo run dev --filter=api",
    "test:web": "turbo run test --filter=web",
    "test:api": "turbo run test --filter=api",
    "lint:changed": "turbo run lint --filter=...[HEAD~1]"
  }
}
```

## 사용 방법

### 패턴 1: 패키지 단위로 AI 세션 분리

모노레포 전체를 하나의 AI 세션에 넣으면 컨텍스트가 흐려져요. 대신 패키지별로 세션을 나누세요:

```bash
# 프론트엔드 작업 시
cd packages/web
claude "로그인 페이지에 소셜 로그인 버튼 추가해줘"

# 백엔드 작업 시
cd packages/api
claude "OAuth2 소셜 로그인 엔드포인트 만들어줘"
```

Claude Code는 현재 디렉토리 기준으로 컨텍스트를 잡기 때문에, 작업 대상 패키지로 이동한 뒤 실행하는 게 좋아요.

### 패턴 2: 크로스 패키지 변경 시 명시적 참조

패키지 간 연결이 필요한 작업에서는 관련 파일을 직접 알려주세요:

```bash
claude "shared/types/user.ts의 User 타입에 role 필드를 추가하고,
       web/components/UserProfile.tsx와 api/routes/users.py에도 반영해줘"
```

### 패턴 3: Turborepo 태스크 그래프와 AI 연동

변경된 패키지만 테스트하면 시간을 아낄 수 있어요:

```bash
# 변경된 패키지만 테스트
pnpm turbo run test --filter=...[origin/main]

# AI에게 실패한 테스트 수정 요청
claude "turbo run test 결과에서 실패한 테스트를 확인하고 수정해줘"
```

### 패턴 4: Nx 프로젝트 그래프 활용

Nx를 쓴다면 의존성 그래프를 AI 컨텍스트로 넘겨줄 수 있어요:

```bash
# 영향 받는 프로젝트 확인
npx nx affected --target=test --base=main

# 프로젝트 그래프 시각화
npx nx graph
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| CLAUDE.md 깊이 | 2단계 | 루트 + 패키지별 (서브패키지는 선택) |
| .cursorignore | 빌드 산출물 | 프로젝트에 맞게 추가 |
| 필터 범위 | 패키지 단위 | `--filter` 문법으로 세분화 가능 |
| 세션 분리 | 패키지별 | 작은 프로젝트는 통합 세션도 가능 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| AI가 다른 패키지 코드를 참조 못 함 | 루트 CLAUDE.md에 패키지 간 관계 명시 |
| 토큰 한도 초과 | `.cursorignore`에 큰 파일 추가, 패키지별 세션 분리 |
| 타입 변경 후 다른 패키지에서 에러 | `turbo run typecheck`로 전체 타입 체크 후 AI에 결과 전달 |
| AI가 잘못된 임포트 경로 생성 | CLAUDE.md에 임포트 패턴 예시 추가 (`@repo/shared` 등) |
| 빌드 순서 문제 | `turbo.json`의 `dependsOn` 설정 확인, AI에게 빌드 그래프 설명 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
