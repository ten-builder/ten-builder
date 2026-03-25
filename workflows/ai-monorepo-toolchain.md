# AI 모노레포 도구 체인 자동화 워크플로우

> Turborepo/Nx 모노레포에서 AI 에이전트를 패키지별로 분리 실행하고, 변경 영향 범위를 자동으로 분석하는 워크플로우

## 개요

모노레포는 AI 코딩 에이전트와 궁합이 좋아요. 전체 코드베이스가 하나의 레포에 있으니 에이전트가 크로스 패키지 의존성을 파악하고, 한 번의 변경으로 여러 패키지를 동시에 수정할 수 있죠.

하지만 규모가 커지면 문제가 생겨요:
- 컨텍스트 윈도우에 전체 레포를 담을 수 없음
- 한 패키지 변경이 다른 패키지에 미치는 영향을 놓침
- CI 파이프라인이 불필요한 패키지까지 빌드/테스트

이 워크플로우는 Turborepo 또는 Nx의 패키지 그래프를 활용해서 AI 에이전트가 **정확한 범위**에서 작업하게 해요.

## 사전 준비

- Turborepo 또는 Nx가 설정된 모노레포
- AI 코딩 에이전트 (Claude Code, Cursor 등)
- Node.js 18+ / pnpm (또는 npm/yarn)

## Step 1: 패키지 의존성 그래프 파악

### Turborepo

```bash
# 패키지 간 의존성 시각화
turbo graph

# JSON으로 의존성 그래프 추출
turbo run build --dry=json | jq '.packages'

# 특정 패키지의 의존 관계만 확인
turbo run build --filter=@app/api --dry=json
```

### Nx

```bash
# 의존성 그래프 시각화
nx graph

# 영향 받는 프로젝트 목록
nx affected:apps --base=main
nx affected:libs --base=main

# JSON으로 프로젝트 그래프 추출
nx graph --file=project-graph.json
```

이 그래프 정보를 AI 에이전트에게 컨텍스트로 전달하면, 에이전트가 어떤 패키지를 건드려야 하는지 정확히 판단할 수 있어요.

## Step 2: 패키지별 AI 에이전트 분리 실행

### CLAUDE.md 패키지별 설정

모노레포 루트와 각 패키지에 독립적인 CLAUDE.md를 배치해요:

```
monorepo/
├── CLAUDE.md              # 루트: 전체 아키텍처, 공통 규칙
├── packages/
│   ├── api/
│   │   └── CLAUDE.md      # API 패키지 전용 규칙
│   ├── web/
│   │   └── CLAUDE.md      # 웹 프론트엔드 전용 규칙
│   └── shared/
│       └── CLAUDE.md      # 공유 라이브러리 전용 규칙
└── turbo.json
```

```markdown
# packages/api/CLAUDE.md

## 이 패키지 정보
- Express.js REST API 서버
- PostgreSQL + Prisma ORM
- 포트: 3001

## 의존하는 내부 패키지
- @mono/shared: 유틸리티, 타입 정의
- @mono/config: 환경 변수 관리

## 테스트 명령어
pnpm --filter @mono/api test

## 빌드
pnpm --filter @mono/api build
```

### 패키지 범위 지정 실행

```bash
# Claude Code를 특정 패키지 디렉토리에서 실행
cd packages/api && claude

# Cursor에서 워크스페이스를 패키지 단위로 열기
code packages/api
```

**핵심 규칙:** 한 번에 하나의 패키지에 집중시키되, 의존 패키지 정보는 컨텍스트로 제공해요.

## Step 3: 변경 영향 범위 자동 분석

### 변경 감지 스크립트

```bash
#!/bin/bash
# scripts/affected-packages.sh
# 변경된 파일에서 영향 받는 패키지 목록 추출

CHANGED_FILES=$(git diff --name-only main...HEAD)

# Turborepo 방식
AFFECTED=$(turbo run build --dry=json --filter='...[main...HEAD]' \
  | jq -r '.packages[]')

echo "변경된 파일:"
echo "$CHANGED_FILES"
echo ""
echo "영향 받는 패키지:"
echo "$AFFECTED"
```

### AI 에이전트용 영향 분석 프롬프트

```
다음 패키지를 수정했어:
- @mono/shared (types.ts에 새 타입 추가)

영향 받는 패키지 목록:
- @mono/api (shared 타입을 import)
- @mono/web (shared 타입을 import)

각 영향 받는 패키지에서:
1. 새 타입을 사용하는 코드 업데이트
2. 타입 호환성 확인
3. 테스트 실행해서 깨지는 거 없는지 확인
```

### CI 파이프라인 통합

```yaml
# .github/workflows/ai-affected-check.yml
name: AI Affected Package Check

on:
  pull_request:
    branches: [main]

jobs:
  affected-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect affected packages
        run: |
          # Turborepo
          AFFECTED=$(npx turbo run build --dry=json \
            --filter='...[origin/main...HEAD]' \
            | jq -r '.packages[]')
          echo "affected=$AFFECTED" >> $GITHUB_OUTPUT

      - name: Run tests only for affected
        run: |
          npx turbo run test \
            --filter='...[origin/main...HEAD]'
```

## Step 4: 크로스 패키지 변경 안전하게 하기

### 변경 순서 결정

패키지 의존성 그래프의 **리프 노드부터** 변경해요:

```
1. shared (의존성 없음) → 먼저 수정
2. config (shared 의존) → 다음 수정
3. api, web (shared + config 의존) → 마지막 수정
```

### 단계별 검증 루프

```bash
# 1단계: 공유 라이브러리 변경 + 테스트
cd packages/shared
# AI 에이전트로 변경 작업
pnpm --filter @mono/shared test
pnpm --filter @mono/shared build

# 2단계: 의존 패키지 타입 체크
pnpm --filter @mono/api typecheck
pnpm --filter @mono/web typecheck

# 3단계: 영향 받는 패키지 테스트
turbo run test --filter='...@mono/shared'

# 4단계: 전체 빌드 확인
turbo run build
```

| 단계 | 범위 | 검증 항목 |
|------|------|----------|
| 1 | 변경 패키지 | 단위 테스트 + 빌드 |
| 2 | 직접 의존 패키지 | 타입 체크 |
| 3 | 전이적 의존 패키지 | 통합 테스트 |
| 4 | 전체 레포 | 빌드 + E2E |

## Step 5: 병렬 에이전트로 속도 높이기

독립적인 패키지는 여러 AI 에이전트 세션을 동시에 실행할 수 있어요:

```bash
# tmux로 패키지별 에이전트 병렬 실행
tmux new-session -d -s api 'cd packages/api && claude'
tmux new-session -d -s web 'cd packages/web && claude'
tmux new-session -d -s mobile 'cd packages/mobile && claude'

# 각 세션에 독립적인 작업 지시
tmux send-keys -t api "이 패키지의 인증 미들웨어를 JWT에서 세션 기반으로 변경해줘" Enter
tmux send-keys -t web "로그인 페이지에 세션 기반 인증 연동해줘" Enter
```

### 병렬 실행 가능 여부 판단

```
의존 관계 없음 → 병렬 OK
  packages/api  ←→  packages/web    (서로 의존 안 함)

의존 관계 있음 → 순차 실행
  packages/shared → packages/api    (shared 먼저)
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 빌드 도구 | Turborepo | Nx로 변경 시 명령어만 교체 |
| 패키지 매니저 | pnpm | npm, yarn도 동일 패턴 |
| AI 에이전트 수 | 1 | CPU/메모리에 따라 2~4개 병렬 |
| 영향 분석 기준 | git diff | 파일 변경 기반 |
| CI 테스트 범위 | affected only | 전체로 변경 가능 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 에이전트가 다른 패키지 파일을 수정 | CLAUDE.md에 작업 범위 명시 + `--filter` 사용 |
| 타입 변경 후 의존 패키지 빌드 실패 | 리프 노드부터 순서대로 변경 |
| CI가 모든 패키지를 빌드 | `--filter='...[origin/main...HEAD]'` 적용 |
| 컨텍스트 윈도우 초과 | 패키지 단위로 에이전트 분리 실행 |
| 병렬 에이전트 간 충돌 | 독립 패키지만 병렬, 의존 있으면 순차 |
| Turborepo 캐시 미스 | `turbo run build --force`로 캐시 초기화 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
