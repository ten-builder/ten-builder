# 멀티 에이전트 코딩 조율 워크플로우 — 충돌 없는 병렬 개발

> 여러 AI 에이전트가 같은 저장소에서 동시에 작업할 때 충돌을 방지하고 품질을 유지하는 조율 워크플로우

## 개요

2026년 AI 코딩 환경에서 단일 에이전트로 처리하기 어려운 규모의 작업이 많아졌습니다. 기능 개발, 테스트 작성, 문서 업데이트를 서로 다른 에이전트에게 동시에 맡기면 생산성이 올라가지만, 조율 없이 시작하면 반드시 충돌이 생깁니다.

여러 AI 에이전트가 조율 없이 같은 레포에 접근할 때 생기는 문제:

- 같은 파일을 동시에 수정하다가 서로 덮어쓰기
- `package.json`, `yarn.lock`, `poetry.lock` 같은 공유 파일에서 경쟁 조건 발생
- 한 에이전트의 변경이 다른 에이전트의 가정을 깨뜨림
- 머지 충돌로 모든 작업이 멈춤

이 워크플로우는 Git Worktree 격리, 오케스트레이터 패턴, 파일 잠금 전략을 조합해서 이 문제를 체계적으로 해결합니다.

## 사전 준비

- Claude Code, Cursor, Gemini CLI 등 AI 코딩 에이전트 설치
- Git 2.38 이상 (worktree 기능)
- `gh` CLI 설치 및 인증
- AGENTS.md 또는 CLAUDE.md 작성 완료
- 선택: tmux (병렬 세션 관리)

## 워크플로우 개요

```
태스크 분해 → Worktree 격리 → 오케스트레이터 감시 → 순차 머지 → 통합 검증
```

---

## Phase 1: 태스크 분해 및 격리 전략 설계

### 1-1. 파일 의존성 맵 작성

병렬 실행 전에 어떤 에이전트가 어떤 파일을 건드리는지 미리 파악합니다.

```bash
# 태스크별 예상 수정 파일 목록 작성
cat > /tmp/agent-file-map.md << 'EOF'
## Agent-A: 결제 모듈 리팩토링
- src/payment/
- src/billing/
- tests/payment/

## Agent-B: 사용자 인증 개선
- src/auth/
- src/middleware/auth.ts
- tests/auth/

## Agent-C: API 문서 업데이트
- docs/api/
- openapi.yaml
EOF
```

**핵심 원칙:** 에이전트 간 파일 영역이 겹치면 병렬 실행이 아니라 순차 실행으로 전환합니다.

### 1-2. 공유 파일 처리 전략

반드시 겹칠 수밖에 없는 파일이 있습니다. 미리 처리 방식을 정해두세요.

| 파일 유형 | 처리 방식 |
|-----------|-----------|
| `package.json`, `pyproject.toml` | 오케스트레이터만 수정, 에이전트는 수정 금지 |
| `CHANGELOG.md`, `README.md` | 마지막 에이전트(Agent-C)가 통합 정리 |
| 데이터베이스 스키마 파일 | 시퀀셜 실행으로 전환 |
| 환경 설정 파일 (`.env.example`) | 공유 파일 목록에 명시, 충돌 시 수동 해결 |

---

## Phase 2: Git Worktree 격리 설정

### 2-1. 에이전트별 Worktree 생성

```bash
# 메인 레포에서 에이전트별 Worktree 분리
git fetch origin
git checkout main

# 각 에이전트용 브랜치 + Worktree 생성
git worktree add ../repo-agent-a -b feature/payment-refactor origin/main
git worktree add ../repo-agent-b -b feature/auth-improvement origin/main
git worktree add ../repo-agent-c -b docs/api-update origin/main

# Worktree 목록 확인
git worktree list
```

각 에이전트는 완전히 분리된 디렉토리에서 독립적으로 작업합니다. 파일시스템 레벨의 격리라 충돌이 원천적으로 방지됩니다.

### 2-2. AGENTS.md로 에이전트 역할 고정

각 Worktree에 해당 에이전트의 역할을 명시합니다.

```markdown
# AGENTS.md — Agent-A 전용 (결제 모듈)

## 역할
결제 모듈 리팩토링 담당. src/payment/ 및 src/billing/ 만 수정한다.

## 금지 영역
- src/auth/ 절대 수정 금지
- package.json 수정 금지 (오케스트레이터에게 요청)
- 루트 설정 파일 수정 금지

## 완료 신호
작업 완료 시 .agent-done 파일 생성:
echo "payment-refactor:done" > .agent-done
```

---

## Phase 3: 오케스트레이터 모니터링

### 3-1. 오케스트레이터 대시보드 설정

오케스트레이터(사람 또는 메인 에이전트)가 모든 워커의 상태를 감시합니다.

```bash
#!/bin/bash
# scripts/orchestrator-watch.sh

WORKTREES=("../repo-agent-a" "../repo-agent-b" "../repo-agent-c")
AGENTS=("Agent-A(결제)" "Agent-B(인증)" "Agent-C(문서)")

while true; do
  clear
  echo "=== 멀티에이전트 대시보드 $(date) ==="
  
  for i in "${!WORKTREES[@]}"; do
    WT="${WORKTREES[$i]}"
    AG="${AGENTS[$i]}"
    
    if [ -f "$WT/.agent-done" ]; then
      STATUS="✅ 완료"
    elif [ -f "$WT/.agent-error" ]; then
      STATUS="❌ 에러"
    else
      # 최근 커밋 시간으로 활동 상태 확인
      LAST=$(cd "$WT" && git log -1 --format='%cr' 2>/dev/null || echo "미시작")
      STATUS="🔄 진행중 ($LAST)"
    fi
    
    echo "$AG: $STATUS"
  done
  
  sleep 30
done
```

### 3-2. 충돌 조기 감지

에이전트가 작업 중인 상태에서도 충돌 가능성을 미리 탐지할 수 있습니다.

```bash
#!/bin/bash
# scripts/conflict-detector.sh
# 두 브랜치 사이의 잠재적 충돌 파일 미리 확인

check_potential_conflict() {
  local branch1=$1
  local branch2=$2
  
  # 각 브랜치에서 변경된 파일 목록 추출
  FILES_A=$(git diff --name-only origin/main...$branch1 2>/dev/null)
  FILES_B=$(git diff --name-only origin/main...$branch2 2>/dev/null)
  
  # 겹치는 파일 찾기
  CONFLICTS=$(comm -12 \
    <(echo "$FILES_A" | sort) \
    <(echo "$FILES_B" | sort))
  
  if [ -n "$CONFLICTS" ]; then
    echo "⚠️  잠재적 충돌 ($branch1 vs $branch2):"
    echo "$CONFLICTS"
  fi
}

check_potential_conflict feature/payment-refactor feature/auth-improvement
check_potential_conflict feature/payment-refactor docs/api-update
```

---

## Phase 4: 순차 머지 전략

### 4-1. 우선순위 기반 머지 순서 결정

병렬 작업이 끝나면 순서를 정해 순차 머지합니다.

```
머지 우선순위:
1. 핵심 기능 변경 (Agent-B: 인증) — 다른 코드가 의존할 수 있음
2. 기능 구현 (Agent-A: 결제) — 독립적
3. 문서/설정 (Agent-C: 문서) — 최종 상태 반영
```

```bash
# 1단계: Agent-B 머지 (인증)
git checkout main
git merge --no-ff feature/auth-improvement -m "feat(auth): improve authentication flow"

# 테스트 통과 확인
npm test -- --testPathPattern=auth/

# 2단계: Agent-A 리베이스 후 머지
cd ../repo-agent-a
git fetch origin
git rebase origin/main  # main이 변경됐으니 리베이스 필수

# 충돌 있으면 해결 후
git add -A && git rebase --continue

# 메인에서 머지
cd -
git merge --no-ff feature/payment-refactor -m "feat(payment): refactor payment module"

# 3단계: Agent-C 리베이스 후 머지
cd ../repo-agent-c
git fetch origin
git rebase origin/main

cd -
git merge --no-ff docs/api-update -m "docs: update API documentation"
```

### 4-2. 머지 후 통합 검증

```bash
# 전체 테스트 실행
npm test

# 빌드 확인
npm run build

# 타입 체크
npx tsc --noEmit

# 정상이면 완료 알림
echo "✅ 멀티에이전트 병렬 작업 완료: $(date)"
```

---

## Phase 5: Worktree 정리

```bash
# 완료된 Worktree 제거
git worktree remove ../repo-agent-a
git worktree remove ../repo-agent-b
git worktree remove ../repo-agent-c

# 로컬 브랜치 정리
git branch -d feature/payment-refactor
git branch -d feature/auth-improvement
git branch -d docs/api-update

# Worktree 목록 확인
git worktree list
```

---

## 패턴별 조율 전략

| 상황 | 권장 전략 |
|------|-----------|
| 파일 영역이 완전히 분리됨 | 완전 병렬 실행, Worktree 격리 |
| 공유 파일 일부 있음 | 공유 파일은 오케스트레이터만 수정, 나머지 병렬 |
| 의존 관계 있는 태스크 | 파이프라인 방식 (A완료 → B시작) |
| 같은 파일 집중 수정 | 순차 실행으로 전환 |

## 자주 발생하는 문제와 해결

| 문제 | 해결 |
|------|------|
| 에이전트가 금지 영역 수정 | AGENTS.md에 명시, PostToolUse Hook으로 검증 |
| 리베이스 충돌 | 충돌 파일을 에디터에서 수동 해결 후 `git rebase --continue` |
| lockfile 충돌 | `npm install` 또는 `pip install` 재실행으로 자동 재생성 |
| 에이전트가 멈춤 | `.agent-error` 파일 확인 후 해당 작업만 재시작 |
| 머지 순서 실수 | `git reflog`로 이전 상태 복원 가능 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
