# Git + AI 워크플로우 치트시트

> AI 코딩 도구와 Git을 함께 쓸 때 알아두면 좋은 브랜치 전략, 커밋 패턴, 리뷰 워크플로우 — 한 페이지 요약

## 브랜치 전략

### AI 작업용 브랜치 패턴

| 패턴 | 용도 | 예시 |
|------|------|------|
| `feat/ai-{기능명}` | AI로 새 기능 구현 | `feat/ai-auth-flow` |
| `fix/ai-{이슈}` | AI로 버그 수정 | `fix/ai-race-condition` |
| `refactor/ai-{대상}` | AI로 리팩토링 | `refactor/ai-db-layer` |
| `experiment/{아이디어}` | AI 실험/프로토타입 | `experiment/new-api-design` |

### Worktree 활용 — 병렬 AI 작업

```bash
# 메인 디렉토리는 유지하면서 별도 디렉토리에서 작업
git worktree add ../project-feat-auth feat/ai-auth
git worktree add ../project-fix-perf fix/ai-performance

# AI 에이전트를 각 worktree에 배정
cd ../project-feat-auth && claude "인증 플로우 구현해줘"
cd ../project-fix-perf && claude "N+1 쿼리 문제 해결해줘"

# 작업 완료 후 정리
git worktree remove ../project-feat-auth
```

**왜 worktree인가?** 별도 clone 없이 같은 저장소에서 여러 브랜치를 동시에 체크아웃할 수 있어요. AI 에이전트 여러 개를 병렬로 돌릴 때 특히 유용합니다.

## 커밋 패턴

### AI 작업 시 커밋 주기

| 상황 | 커밋 시점 | 이유 |
|------|-----------|------|
| 기능 구현 | 각 함수/모듈 완성 시 | AI가 잘못 건드리면 롤백 가능 |
| 리팩토링 | 변환 단계마다 | 중간 상태 보존 |
| 디버깅 | 원인 파악 후 & 수정 후 | 원인-해결 이력 추적 |
| 실험 | 동작 확인될 때마다 | 실패 시 되돌릴 기준점 |

> **핵심:** AI와 작업할 때는 평소보다 **자주** 커밋하세요. AI가 예상치 못한 변경을 하면 `git checkout -- .` 한 방이면 됩니다.

### 커밋 메시지 작성

```bash
# AI로 커밋 메시지 생성
git diff --staged | claude -p "이 변경사항의 conventional commit 메시지를 작성해줘"

# 결과 예시
# feat(auth): add JWT refresh token rotation
# - 리프레시 토큰 만료 시 자동 갱신
# - 동시 요청 시 레이스 컨디션 방지
```

### 커밋 전 체크리스트

```bash
# 1. 변경 범위 확인 — AI가 의도하지 않은 파일을 수정했는지
git diff --stat

# 2. 변경 내용 리뷰
git diff

# 3. 불필요한 파일 제외
git reset HEAD -- package-lock.json  # 의도하지 않은 변경 제외

# 4. 테스트 실행
npm test  # 또는 프로젝트의 테스트 명령어
```

## 리뷰 워크플로우

### AI가 만든 PR 리뷰하기

```bash
# PR의 전체 변경사항 확인
gh pr diff 42

# AI로 변경사항 요약 받기
gh pr diff 42 | claude -p "이 PR의 변경사항을 요약하고 잠재적 문제점을 찾아줘"

# 특정 파일만 집중 리뷰
gh pr diff 42 -- src/auth/ | claude -p "인증 관련 변경사항에서 보안 취약점이 있는지 확인해줘"
```

### 리뷰 시 중점 체크 항목

| 체크 항목 | 확인 방법 |
|-----------|----------|
| 불필요한 파일 변경 | `git diff --stat` — 파일 수가 예상보다 많으면 의심 |
| 하드코딩된 값 | 설정/환경변수로 빼야 할 값이 코드에 박혀있는지 |
| 에러 핸들링 | try-catch가 빈 블록인지, 에러를 삼키는지 |
| 타입 안전성 | `any` 남용, 타입 단언 과다 사용 |
| 테스트 커버리지 | 새 코드에 대한 테스트가 있는지 |
| 의존성 변경 | 불필요한 패키지가 추가되지 않았는지 |

## diff 관리

### AI에게 컨텍스트 제공

```bash
# 현재 변경사항만 전달
git diff | claude -p "이 코드에서 개선할 점을 알려줘"

# 특정 브랜치와의 차이
git diff main..HEAD | claude -p "main 대비 변경사항을 리뷰해줘"

# 특정 커밋 이후 변경사항
git diff abc1234..HEAD -- src/ | claude -p "이 변경사항을 검토해줘"
```

### 충돌 해결

```bash
# 충돌 파일 확인
git diff --name-only --diff-filter=U

# AI로 충돌 해결
cat src/service.ts | claude -p "이 merge conflict를 해결해줘. 두 변경 모두 유지하되 로직이 맞게 통합해줘"

# rebase 중 충돌
git rebase main
# 충돌 발생 시
claude "현재 rebase 충돌을 해결해줘"
git add .
git rebase --continue
```

## 실전 패턴 모음

### 패턴 1: AI 작업 → 사람 리뷰 → 머지

```bash
# 1. 브랜치 생성
git checkout -b feat/ai-user-dashboard

# 2. AI에게 작업 위임
claude "사용자 대시보드 페이지를 만들어줘"

# 3. 변경사항 확인 후 커밋
git diff --stat           # 범위 확인
git add -p                # 선택적 스테이징
git commit -m "feat(dashboard): add user dashboard page"

# 4. PR 생성
gh pr create --title "feat: user dashboard" --body "AI로 구현, 리뷰 필요"

# 5. 셀프 리뷰 후 머지
gh pr diff | claude -p "최종 리뷰해줘"
```

### 패턴 2: 실패 안전 실험

```bash
# stash로 현재 작업 보관
git stash push -m "현재 작업 백업"

# AI 실험
claude "이 함수를 완전히 다른 방식으로 구현해봐"

# 결과가 마음에 안 들면
git checkout -- .

# 원래 작업 복구
git stash pop
```

### 패턴 3: 대규모 리팩토링

```bash
# 1. 리팩토링 전 태그
git tag pre-refactor

# 2. 단계별 리팩토링 (각 단계마다 커밋)
claude "Step 1: 타입 정의를 별도 파일로 분리해줘"
git add . && git commit -m "refactor: extract type definitions"

claude "Step 2: 비즈니스 로직을 서비스 레이어로 이동해줘"
git add . && git commit -m "refactor: move logic to service layer"

# 3. 문제 발생 시 되돌리기
git reset --hard pre-refactor
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| AI가 관련 없는 파일까지 수정 | `git add -p`로 필요한 변경만 선택 |
| 커밋 없이 AI에게 큰 작업 위임 | 작업 전 반드시 커밋하여 기준점 확보 |
| main에서 직접 AI 작업 | 항상 feature 브랜치에서 작업 |
| 생성된 코드를 리뷰 없이 머지 | `git diff`로 모든 변경 확인 후 커밋 |
| lock 파일 충돌 무시 | `npm install` 재실행 후 lock 파일 새로 생성 |
| AI 실험 브랜치 방치 | 주기적으로 `git branch --merged` 정리 |

## 유용한 Git Alias

```bash
# ~/.gitconfig에 추가
[alias]
  # AI 작업 시작 (브랜치 생성 + 체크아웃)
  ai-start = "!f() { git checkout -b feat/ai-$1; }; f"

  # 변경 파일 수 확인
  ai-check = diff --stat

  # 변경사항 버리고 원복
  ai-undo = checkout -- .

  # 마지막 커밋 취소 (변경사항 유지)
  ai-retry = reset --soft HEAD~1

  # 스테이지된 변경 상세 확인
  ai-review = diff --cached
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
