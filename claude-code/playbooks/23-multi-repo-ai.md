# 플레이북 23: 멀티 레포 AI 개발

> 마이크로서비스 환경에서 여러 레포를 AI 코딩 에이전트로 동시에 작업하는 단계별 전략

## 소요 시간

30-45분 (초기 구성), 이후 레포별 5분

## 사전 준비

- AI 코딩 에이전트 (Claude Code, Cursor, Codex CLI 중 하나 이상)
- 2개 이상의 관련 레포 (마이크로서비스, 모노레포 내 패키지 등)
- Git worktree 지원 환경 (Git 2.15+)
- 터미널 멀티플렉서 (tmux 권장)

## Step 1: 레포 간 의존 관계 파악

멀티 레포 작업의 첫 단계는 서비스 간 연결 지점을 명확히 하는 거예요.

```bash
# 각 레포의 API 계약(스키마) 확인
find ./services -name "openapi.yaml" -o -name "schema.graphql" | head -20

# package.json / go.mod 에서 내부 의존성 추출
grep -r "internal-packages\|@myorg" */package.json
```

### 의존 관계 매트릭스

| 서비스 | 의존하는 서비스 | 공유 스키마 |
|--------|----------------|-------------|
| api-gateway | auth, user, product | `shared-types` |
| auth-service | user | `auth-schema` |
| user-service | (없음) | `user-schema` |

> 이 매트릭스를 `CLAUDE.md`에 적어두면 AI 에이전트가 컨텍스트를 빠르게 파악해요.

## Step 2: 워크트리로 격리된 작업 공간 만들기

레포마다 별도 브랜치를 워크트리로 분리하면 각 에이전트 세션이 충돌 없이 작업할 수 있어요.

```bash
# 메인 레포에서 워크트리 생성
cd ~/projects/api-gateway
git worktree add ../api-gateway-feature feature/cross-repo-update

cd ~/projects/auth-service
git worktree add ../auth-service-feature feature/auth-api-change

# 각 워크트리에서 독립 에이전트 세션 실행
cd ~/projects/api-gateway-feature
claude  # 세션 1: API 게이트웨이 작업

cd ~/projects/auth-service-feature
claude  # 세션 2: Auth 서비스 작업
```

### 워크트리 정리

```bash
# 작업 완료 후 워크트리 제거
git worktree remove ../api-gateway-feature
git worktree list  # 남은 워크트리 확인
```

## Step 3: 컨텍스트 브릿지 구성

AI 에이전트는 현재 레포만 볼 수 있기 때문에 다른 레포의 API 계약을 명시적으로 전달해야 해요.

### 방법 A: CLAUDE.md에 크로스 레포 컨텍스트 기록

```markdown
# 크로스 레포 의존성

## auth-service API (v2.3)
- POST /auth/verify → { valid: boolean, userId: string }
- POST /auth/refresh → { accessToken: string, expiresIn: number }
- 에러 코드: AUTH_EXPIRED(401), AUTH_INVALID(403)

## user-service API (v1.8)  
- GET /users/:id → { id, name, email, role }
- PATCH /users/:id → { updated: boolean }
```

### 방법 B: 공유 스키마 파일 심링크

```bash
# 공유 타입 정의를 각 레포에 심링크
ln -s ~/projects/shared-types/api-contracts.d.ts \
      ~/projects/api-gateway/src/types/external.d.ts
```

### 방법 C: 메타 레포(Spine) 패턴

```
meta-repo/
├── CLAUDE.md          # 전체 아키텍처 + API 계약
├── services/
│   ├── api-gateway/   # git submodule 또는 심링크
│   ├── auth-service/
│   └── user-service/
└── contracts/
    ├── auth-api.yaml
    └── user-api.yaml
```

```bash
# 메타 레포 구성
mkdir meta-repo && cd meta-repo
git init
git submodule add git@github.com:org/api-gateway.git services/api-gateway
git submodule add git@github.com:org/auth-service.git services/auth-service
```

> 메타 레포를 사용하면 AI 에이전트가 한 세션에서 전체 아키텍처를 파악할 수 있어요.

## Step 4: 병렬 에이전트 세션 운영

tmux로 여러 에이전트를 동시에 실행하면서 작업을 조율해요.

```bash
# tmux 세션 구성
tmux new-session -d -s multi-repo

# 패널 1: API 게이트웨이
tmux send-keys -t multi-repo "cd ~/projects/api-gateway && claude" Enter

# 패널 2: Auth 서비스
tmux split-window -h -t multi-repo
tmux send-keys -t multi-repo "cd ~/projects/auth-service && claude" Enter

# 패널 3: 모니터링 (테스트/빌드 상태)
tmux split-window -v -t multi-repo
tmux send-keys -t multi-repo "watch -n 5 'cd ~/projects/api-gateway && npm test 2>&1 | tail -3'" Enter
```

### 작업 순서 전략

| 패턴 | 적합한 상황 | 설명 |
|------|------------|------|
| 바텀업 | 의존성이 한 방향일 때 | 가장 아래(의존받는) 서비스부터 변경 |
| 계약 우선 | API 스키마 변경 시 | 공유 스키마 먼저 수정 → 각 서비스 순차 반영 |
| 병렬 독립 | 서비스 간 의존 없을 때 | 각 에이전트가 독립적으로 동시 작업 |
| 핑퐁 | 양방향 의존 시 | 한쪽 변경 → 스텁 공유 → 다른 쪽 적응 |

## Step 5: API 계약 변경 시 안전한 전파

서비스 A의 API가 변경되면 의존하는 서비스 B, C가 깨질 수 있어요. 다음 순서를 지키세요.

```bash
# 1단계: 새 API 엔드포인트를 기존과 함께 배포 (하위 호환)
# auth-service: POST /auth/verify-v2 추가 (기존 /auth/verify 유지)

# 2단계: 의존 서비스들이 새 엔드포인트로 전환
# api-gateway: /auth/verify → /auth/verify-v2 호출로 변경

# 3단계: 기존 엔드포인트 제거
# auth-service: /auth/verify deprecated → 삭제
```

### AI 에이전트에게 전파 지시하기

```
auth-service의 /auth/verify 응답에 sessionId 필드가 추가됐어.
api-gateway에서 이 필드를 읽어서 X-Session-Id 헤더로 전달하도록 수정해줘.
기존 필드는 그대로 유지하고, sessionId가 없는 경우도 처리해야 해.
```

## Step 6: 통합 테스트와 검증

개별 서비스 작업이 끝나면 함께 동작하는지 확인해야 해요.

```bash
# docker-compose로 로컬 통합 테스트
docker-compose -f docker-compose.test.yml up -d

# 통합 테스트 실행
npm run test:integration

# 서비스 간 계약 테스트 (Pact 등)
npx pact-verify --provider auth-service --pact-url ./pacts/
```

### 레포별 PR 생성 순서

```bash
# 의존 방향 역순으로 PR 생성 (기반 서비스 먼저)
# 1. auth-service PR → 리뷰 & 머지
# 2. api-gateway PR → auth-service 변경 참조하며 리뷰 & 머지

# PR 본문에 관련 PR 크로스 레퍼런스
gh pr create --title "feat: add sessionId to verify response" \
  --body "Related: org/api-gateway#42"
```

## 체크리스트

- [ ] 서비스 간 의존 관계 매트릭스 작성
- [ ] 각 레포의 CLAUDE.md에 크로스 레포 컨텍스트 기록
- [ ] 워크트리 또는 메타 레포 패턴 선택 및 구성
- [ ] API 계약 변경 시 하위 호환 전략 확인
- [ ] 통합 테스트 파이프라인 구성
- [ ] PR 간 크로스 레퍼런스 포함

## 실전 팁

### CLAUDE.md 크로스 레포 섹션 템플릿

```markdown
## 관련 레포

| 레포 | 역할 | API 문서 |
|------|------|---------|
| auth-service | 인증/인가 | /docs/api.md |
| user-service | 사용자 관리 | /docs/api.md |

## 변경 시 영향 범위

이 레포의 API를 변경하면 다음 서비스에 영향:
- api-gateway: /auth/* 프록시 엔드포인트
- admin-panel: 토큰 갱신 로직
```

### 환경 변수로 서비스 URL 관리

```bash
# .env.development
AUTH_SERVICE_URL=http://localhost:3001
USER_SERVICE_URL=http://localhost:3002
PRODUCT_SERVICE_URL=http://localhost:3003
```

## 다음 단계

→ [모노레포 + AI 워크플로우](../../workflows/monorepo-ai-workflow.md)
→ [AI 에이전트 감독 워크플로우](../../workflows/ai-agent-supervision.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
