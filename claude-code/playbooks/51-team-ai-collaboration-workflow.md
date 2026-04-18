# 플레이북 51: 팀 AI 에이전트 협업 워크플로우

> 여러 개발자가 동시에 AI 에이전트를 활용할 때 — 충돌 없이 빠르게 협업하는 실전 플레이북

## 소요 시간

30-45분 (초기 팀 설정 기준)

## 사전 준비

- 팀 전체 AI 코딩 도구 설치 완료 (Claude Code, Cursor, Codex CLI 등)
- Git 브랜치 전략 합의 (feature branch 기반 권장)
- 공유 저장소 쓰기 권한
- AGENTS.md 또는 CLAUDE.md 작성 경험

## 왜 이 플레이북이 필요한가

혼자 AI 에이전트를 쓸 때는 별 문제가 없어요. 속도도 빠르고, 실수도 즉시 잡을 수 있죠.

문제는 팀이 되는 순간이에요. 5명이 각자 AI 에이전트로 코드를 생성하면 어떻게 될까요? 같은 파일을 동시에 건드리고, 서로 다른 패턴으로 코드를 작성하고, 머지 컨플릭트가 눈덩이처럼 불어나요.

2026년 기준, 팀 AI 협업 실패의 80%는 도구 문제가 아니라 **조율 없는 병렬 작업** 때문이에요. 이 플레이북은 그 문제를 구조적으로 해결해요.

## Step 1: 팀 AI 규칙 문서 공유 설정

AI 에이전트가 팀 컨벤션을 모르면, 제각각 다른 스타일로 코드를 생성해요. 이를 막는 첫 번째 단계는 공유 규칙 파일을 저장소에 커밋하는 거예요.

```bash
# 저장소 루트에 AGENTS.md 또는 CLAUDE.md 생성
touch CLAUDE.md
```

팀 CLAUDE.md에 포함할 최소 항목:

```markdown
# 프로젝트 AI 코딩 규칙

## 코드 스타일
- TypeScript strict mode 사용
- 함수는 단일 책임 원칙 준수 (200줄 초과 금지)
- 외부 라이브러리 추가 시 팀 리뷰 필수

## 브랜치 규칙
- feature/<이름>/<기능> 형식 사용
- AI 에이전트 실험은 ai/<이름>/<실험명> 브랜치 사용
- main 직접 push 절대 금지

## AI 에이전트 제한 구역
- /auth — 보안 민감, 수동 작성만 허용
- /migrations — DBA 검토 필수
- /payments — L3 검증 필수

## 테스트 의무
- 새 함수 작성 시 단위 테스트 필수
- AI 생성 코드는 최소 L2 검증 통과 후 PR 제출
```

이 파일은 Claude Code, Cursor, Codex CLI가 자동으로 읽어요. 팀 모두가 같은 맥락에서 AI를 쓰게 돼요.

## Step 2: 작업 구역 분리 전략

병렬 AI 작업의 핵심 원칙은 **같은 파일을 동시에 건드리지 않는 것**이에요. 이를 위한 세 가지 방법이 있어요.

### 방법 A: 파일/모듈 소유권 할당

| 개발자 | 담당 모듈 | AI 에이전트 작업 범위 |
|--------|----------|------------------|
| 개발자 A | `/features/auth`, `/features/user` | auth/user 관련 모든 변경 |
| 개발자 B | `/features/payment`, `/features/billing` | payment/billing 변경 |
| 개발자 C | `/api`, `/middleware` | API 레이어 변경 |
| 개발자 D | `/tests`, `/docs` | 테스트/문서 생성 |

주 1회 소유권 순환: 한 모듈에만 집중하면 전체 코드베이스를 이해하지 못하는 문제가 생겨요.

### 방법 B: Git Worktree 기반 격리

같은 저장소에서 여러 AI 세션을 동시에 실행할 때 가장 안전한 방법이에요.

```bash
# 각 개발자 또는 AI 태스크마다 독립 worktree 생성
git worktree add ../feature-auth-ai ai/홍길동/auth-refactor
git worktree add ../feature-payment-ai ai/이순신/payment-module

# 각 worktree에서 독립적으로 AI 에이전트 실행
cd ../feature-auth-ai
claude code  # 또는 cursor, codex 등

# 완료 후 메인 저장소에서 머지
cd ~/project
git merge ai/홍길동/auth-refactor
```

### 방법 C: 순차 병합 전략

동시 작업이 불가피할 때 머지 순서를 명시적으로 관리해요.

```bash
#!/bin/bash
# merge-queue.sh - 팀 머지 순서 관리 스크립트

BRANCHES=(
  "ai/홍길동/auth-refactor"
  "ai/이순신/payment-module"
  "ai/김유신/api-optimization"
)

for branch in "${BRANCHES[@]}"; do
  echo "머지 준비: $branch"
  git fetch origin
  git checkout "$branch"
  git rebase origin/main  # 각 브랜치를 최신 main 기반으로 재배치
  echo "CI 통과 확인 후 엔터를 누르세요..."
  read
  git checkout main
  git merge --no-ff "$branch"
  git push origin main
  echo "$branch 머지 완료"
done
```

## Step 3: 공유 컨텍스트 관리

AI 에이전트는 작업 시작 시 컨텍스트를 새로 읽어요. 팀 공유 컨텍스트가 없으면 각 에이전트가 다른 가정을 하고 코드를 작성해요.

### 팀 공유 컨텍스트 파일 구조

```
.claude/
  ├── team-context.md      # 팀 공유 프로젝트 맥락
  ├── decisions.md         # 최근 아키텍처 결정 기록
  └── active-tasks.md      # 현재 진행 중인 작업 목록
```

```markdown
# team-context.md 예시

## 현재 스프린트 목표
- OAuth2 소셜 로그인 구현 (담당: 홍길동)
- 결제 API v2 마이그레이션 (담당: 이순신)

## 최근 주요 결정
- 2026-04-15: Redis 캐싱 레이어 추가 결정 (이유: DB 쿼리 지연 문제)
- 2026-04-10: API 응답 형식 표준화 완료 (참고: /docs/api-standard.md)

## 작업 중인 파일 (충돌 주의)
- /src/auth/oauth.ts — 홍길동 작업 중 (2026-04-18 완료 예정)
- /src/payment/gateway.ts — 이순신 작업 중
```

매일 스탠드업에서 `active-tasks.md`를 업데이트해요. AI 에이전트가 이 파일을 읽으면 충돌 위험 파일을 자동으로 회피해요.

## Step 4: AI 생성 코드 팀 리뷰 프로세스

개인 작업과 달리 팀 협업에서는 AI 생성 코드를 더 엄격하게 리뷰해야 해요. 리뷰어도 AI가 생성한 코드인지 알아야 적합한 검증을 할 수 있어요.

### PR 설명 표준 형식

```markdown
## 변경 요약
OAuth2 소셜 로그인 (Google, GitHub) 구현

## 작업 방식
- 전체 구현의 약 70%를 Claude Code로 생성
- 세션 토큰 처리 로직은 직접 작성 (보안 민감)
- 단위 테스트 12개 추가 (AI 생성 + 수동 검증)

## 리뷰 중점 사항
- [ ] OAuth 콜백 URL 검증 로직 (L3 보안 코드)
- [ ] 토큰 만료 처리 엣지 케이스
- [ ] 기존 auth 미들웨어와의 호환성
```

### 리뷰어 체크리스트

| 항목 | 확인 방법 |
|------|----------|
| 팀 CLAUDE.md 규칙 준수 | 코드 스타일, 파일 구조 확인 |
| 제한 구역 침범 없음 | 변경 파일 목록 확인 |
| 테스트 커버리지 | `npm test -- --coverage` 실행 |
| 타입 안전성 | TypeScript 컴파일 오류 없음 |
| 보안 민감 코드 수동 확인 | auth, payment, migration 파일 직접 읽기 |

## Step 5: 충돌 사후 처리

완벽한 예방에도 충돌은 발생해요. 팀이 충돌을 빠르게 해결하는 표준 프로세스를 갖추는 게 중요해요.

```bash
# 충돌 발생 시 AI 에이전트로 해결하는 패턴
git checkout feature/payment-module
git rebase origin/main

# 충돌 파일 확인
git diff --name-only --diff-filter=U

# Claude Code에 충돌 해결 위임 (컨텍스트 제공 필수)
# "아래 충돌을 해결해줘. 우리 팀은 결제 모듈 v2를 
# 마이그레이션 중이고, auth 팀이 최근 세션 처리 방식을 
# 변경했어. 결제 로직의 의도를 유지하면서 해결해줘."
```

충돌 해결 후 반드시 팀에 알림:

```bash
# Slack/Discord 알림 예시
echo "충돌 해결 완료: payment-module vs main (세션 처리 부분)" | \
  curl -s -X POST "$SLACK_WEBHOOK" -d @-
```

## 체크리스트

- [ ] 팀 CLAUDE.md 저장소에 커밋
- [ ] 각 개발자의 AI 에이전트 작업 범위 문서화
- [ ] Git Worktree 또는 브랜치 격리 전략 합의
- [ ] 공유 컨텍스트 파일 구조 설정 (`active-tasks.md` 포함)
- [ ] PR 설명 표준 형식 팀 합의
- [ ] 제한 구역 파일 목록 CLAUDE.md에 명시
- [ ] 주 1회 팀 AI 협업 회고 일정 등록

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 같은 파일 동시 작업 → 대규모 충돌 | active-tasks.md로 작업 중 파일 공지 |
| AI가 팀 규칙 무시하고 다른 스타일 생성 | CLAUDE.md에 구체적 예시 추가 |
| 병렬 에이전트 실행 후 머지 지옥 | worktree 격리 + 순차 머지 전략 |
| 리뷰어가 AI 코드 여부 모름 → 피상적 리뷰 | PR 설명에 AI 활용 비율 명시 |
| 개인 AI 설정이 팀 규칙과 충돌 | 로컬 설정보다 저장소 CLAUDE.md 우선 적용 |

## 다음 단계

→ [플레이북 42: AI 생성 코드 신뢰성 검증 파이프라인](./42-ai-code-trust-verification.md)
→ [플레이북 50: AI 코드 신뢰 앵커 설정](./50-ai-code-trust-anchors.md)
→ [가이드 58: 오케스트레이터-워커 패턴 심화 가이드](../../guides/58-ai-agent-orchestrator-patterns.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
