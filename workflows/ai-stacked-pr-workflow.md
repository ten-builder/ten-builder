# Stacked PR 워크플로우 — 대형 기능을 작은 PR로 분해하기

> 대형 기능 개발 시 AI와 함께 Stacked PR을 활용해 리뷰 부담을 줄이고 머지 속도를 높이는 실전 워크플로우

## 개요

AI 코딩 도구가 코드 생성 속도를 10배 높이면서 새로운 병목이 생겼어요. 코드 작성은 빠른데 **리뷰가 느린** 문제입니다. 500줄짜리 PR을 하루 만에 만들어내니, 리뷰어 입장에서는 어디서부터 봐야 할지 막막하죠.

Stacked PR은 이 문제를 해결하는 방식이에요. 하나의 큰 기능을 5~10개의 작은 PR로 나누어 순차적으로 쌓아 올리는 구조입니다. 각 PR은 독립적으로 리뷰받을 수 있고, 앞선 PR이 머지를 기다리는 동안 다음 PR 작업을 계속할 수 있어요.

Google, Meta 같은 회사들이 내부적으로 수십 년간 써온 방식인데, Graphite 같은 도구 덕분에 일반 팀도 쉽게 적용할 수 있게 됐습니다.

## 사전 준비

- Git 기본 사용 숙련
- GitHub CLI (`gh`) 설치 및 인증
- Graphite CLI (선택) — `npm install -g @withgraphite/graphite-cli`
- AI 코딩 에이전트 (Claude Code, Cursor 등)

## 핵심 개념: 스택 구조

```
main
  └── feat/db-schema          PR #1 — 데이터베이스 스키마 변경
        └── feat/api-endpoints  PR #2 — API 엔드포인트 추가
              └── feat/frontend-ui  PR #3 — 프론트엔드 UI 연결
```

각 브랜치는 이전 브랜치를 베이스로 삼아요. PR #1이 머지되면 PR #2가 자동으로 main 위로 rebase되는 구조입니다.

## Step 1: 기능을 AI와 함께 분해하기

대형 기능 구현 전, AI에게 분해 계획을 먼저 요청하세요.

```
[Claude Code 프롬프트 예시]
"사용자 프로필 편집 기능을 구현할 건데, Stacked PR로 나눠줘.
각 PR은 독립적으로 리뷰 가능해야 하고,
앞 PR 없이도 빌드/테스트가 통과해야 해."
```

AI가 제안하는 분해 예시:

| PR | 내용 | 의존성 |
|----|------|--------|
| #1 | DB 마이그레이션 + 모델 수정 | 없음 |
| #2 | API 엔드포인트 + 검증 로직 | PR #1 |
| #3 | 서비스 레이어 + 테스트 | PR #2 |
| #4 | 프론트엔드 폼 컴포넌트 | PR #3 |
| #5 | E2E 테스트 + 문서 | PR #4 |

## Step 2: Graphite CLI로 스택 생성

### Graphite 방식 (권장)

```bash
# 초기 설정 (최초 1회)
gt auth
gt repo init

# 스택 첫 번째 PR 생성
git checkout main
gt create -m "feat: user profile DB schema migration"
# 작업 후...
gt submit  # PR 생성까지 한 번에

# 두 번째 PR — 첫 번째 위에 쌓기
gt create -m "feat: profile edit API endpoints"
# 작업 후...
gt submit
```

### 순수 Git 방식

```bash
# 스택 첫 번째 브랜치
git checkout main
git checkout -b feat/profile-db-schema
# 작업...
git add . && git commit -m "feat: user profile DB schema"
git push origin feat/profile-db-schema
gh pr create --base main --title "feat: user profile DB schema migration"

# 스택 두 번째 브랜치 — 첫 번째 위에서 분기
git checkout feat/profile-db-schema
git checkout -b feat/profile-api
# 작업...
git add . && git commit -m "feat: profile edit API endpoints"
git push origin feat/profile-api
gh pr create --base feat/profile-db-schema --title "feat: profile edit API endpoints"
```

## Step 3: AI와 함께 각 PR 구현

스택을 나눈 후 AI에게 맥락을 주고 각 단계를 구현합니다.

```bash
# PR #1 구현 시 프롬프트
claude "이전 PR 없이 이 브랜치만으로 테스트가 통과해야 해.
DB 마이그레이션 파일과 모델 수정만 담당한다.
API 레이어는 다음 PR에서 한다."
```

**각 PR 작성 규칙:**

| 규칙 | 이유 |
|------|------|
| PR당 변경 파일 10개 이하 | 리뷰어 집중력 유지 |
| 이전 PR 없이도 빌드 통과 | 독립 CI 검증 가능 |
| PR 설명에 스택 위치 명시 | 리뷰어 컨텍스트 제공 |
| 기능 플래그로 미완성 UI 숨김 | 안전한 점진적 배포 |

## Step 4: 스택 최신 상태 유지

아래 PR이 업데이트되면 위 PR들을 rebase해야 해요.

```bash
# Graphite CLI (자동 rebase)
gt sync       # main 변경사항 가져오기
gt restack    # 스택 전체 rebase

# 순수 Git (수동 rebase)
# PR #1이 수정된 경우 PR #2 rebase
git checkout feat/profile-api
git rebase feat/profile-db-schema
git push --force-with-lease origin feat/profile-api
```

## Step 5: 리뷰어 가이드

리뷰어는 **아래에서 위로** 리뷰합니다.

```
리뷰 순서:
1. PR #1 (main 기반) → 머지
2. PR #2 (PR #1 기반) → 머지  
3. PR #3 (PR #2 기반) → 머지
```

**PR 설명 템플릿 (리뷰어 친화적):**

```markdown
## 스택 위치
- [x] PR #1: DB 스키마 (이미 머지)
- **→ PR #2: API 엔드포인트 (현재 리뷰 중)**
- [ ] PR #3: 프론트엔드

## 이 PR에서 변경된 것
- `src/api/profile.ts` — 프로필 수정 엔드포인트 3개 추가
- `src/api/profile.test.ts` — 단위 테스트 15개

## 리뷰 시 집중할 것
- 검증 로직 (line 42-67)
- 에러 응답 형식
```

## 커스터마이징

| 설정 | 권장값 | 이유 |
|------|--------|------|
| PR당 변경 라인 수 | 200-400줄 | 30분 리뷰 가능 범위 |
| 스택 깊이 | 최대 5단계 | 그 이상은 설계 문제 신호 |
| CI 통과 조건 | 각 PR 독립 통과 필수 | rebase 후 실패 방지 |
| 머지 전략 | squash merge | main 히스토리 정리 |

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|------------|
| 스택 분해 계획 | `"이 기능을 Stacked PR 5개로 나눠줘. 각 PR이 독립적으로 테스트 통과해야 해"` |
| 의존성 확인 | `"이 변경사항이 이전 PR 없이도 동작하는지 확인해줘"` |
| rebase 충돌 해결 | `"rebase 충돌이 났어. feat/profile-db-schema 기준으로 해결해줘"` |
| PR 설명 작성 | `"이 diff를 보고 리뷰어 친화적인 PR 설명을 작성해줘. 스택 위치도 포함해서"` |

## 문제 해결

| 문제 | 해결 |
|------|------|
| rebase 후 CI 실패 | `git rebase --abort` 후 충돌 파일 AI에게 전달 |
| 스택이 너무 깊어짐 | 중간 PR을 main으로 머지 후 나머지 rebase |
| 리뷰어가 컨텍스트 없음 | PR 설명에 스택 다이어그램 추가 |
| force push로 리뷰 사라짐 | GitHub 브랜치 보호 규칙에서 "Dismiss stale reviews" 비활성화 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
