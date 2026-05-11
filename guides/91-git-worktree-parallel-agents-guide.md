# Git Worktree 기반 병렬 에이전트 실전 가이드 2026

> 하나의 레포에서 여러 AI 에이전트가 충돌 없이 동시에 작업하는 법 — `git worktree`로 각 에이전트에 독립 작업 공간을 만들어주는 실전 패턴

## 왜 Worktree인가

Claude Code를 여러 개 동시에 실행하면 어떻게 될까요? 같은 디렉토리에서 두 세션이 동일한 파일을 동시에 편집하면 한 세션의 작업이 다른 세션에 덮어씌워집니다. 컨텍스트도 뒤섞입니다.

Git Worktree는 이 문제를 해결합니다. **하나의 Git 저장소에서 여러 브랜치를 동시에 서로 다른 디렉토리에 체크아웃**할 수 있는 기능입니다. 각 에이전트는 자신만의 작업 공간을 가지고, 같은 레포지토리의 히스토리는 공유합니다.

| 방식 | 디렉토리 | 브랜치 | 충돌 |
|------|----------|--------|------|
| 디렉토리 복사 | 별도 폴더 | 동일 | `git pull/push` 번거로움 |
| 멀티 클론 | 별도 폴더 | 별도 | 히스토리 분리 |
| **Git Worktree** | **별도 폴더** | **별도** | **충돌 없음 + 히스토리 공유** |

## 기본 설정

### Step 1: 워크트리 디렉토리 구조 설계

```bash
# 메인 레포
~/projects/my-app/          # main 브랜치

# 에이전트별 워크트리
~/projects/my-app-feat-auth/    # 인증 기능 담당
~/projects/my-app-feat-api/     # API 개선 담당
~/projects/my-app-feat-ui/      # UI 개선 담당
```

### Step 2: 워크트리 생성

```bash
cd ~/projects/my-app

# 새 브랜치로 워크트리 생성 (가장 일반적인 패턴)
git worktree add ../my-app-feat-auth -b feat/auth
git worktree add ../my-app-feat-api -b feat/api-improvements
git worktree add ../my-app-feat-ui -b feat/ui-redesign

# 현재 워크트리 목록 확인
git worktree list
```

출력 예시:

```
/Users/dev/projects/my-app           abc1234 [main]
/Users/dev/projects/my-app-feat-auth def5678 [feat/auth]
/Users/dev/projects/my-app-feat-api  ghi9012 [feat/api-improvements]
/Users/dev/projects/my-app-feat-ui   jkl3456 [feat/ui-redesign]
```

### Step 3: 각 워크트리에서 Claude Code 실행

```bash
# 터미널 1
cd ~/projects/my-app-feat-auth && claude

# 터미널 2
cd ~/projects/my-app-feat-api && claude

# 터미널 3
cd ~/projects/my-app-feat-ui && claude
```

각 Claude Code 세션은 자신의 디렉토리만 보고, 독립된 컨텍스트로 작업합니다.

## Claude Code worktree.baseRef 설정

2026년 5월 Week 23에 추가된 `worktree.baseRef` 설정을 사용하면, 서브에이전트가 새 태스크를 받을 때 자동으로 지정된 브랜치를 기준으로 워크트리를 생성합니다.

```bash
# Claude Code 설정 파일에 추가
claude config set worktree.baseRef main
```

또는 프로젝트별로 `.claude/settings.json`에 설정:

```json
{
  "worktree": {
    "baseRef": "main",
    "cleanupOnMerge": true
  }
}
```

이 설정이 있으면 `/task` 명령어로 새 태스크를 생성할 때 항상 `main` 기준으로 새 워크트리가 만들어집니다.

## 병렬 실행 패턴

### 패턴 1: 오케스트레이터 + 워커

```
오케스트레이터 (메인 레포)
  ├── 태스크 분배
  ├── 서브에이전트 A → my-app-feat-auth (인증 기능)
  ├── 서브에이전트 B → my-app-feat-api (API 개선)
  └── 서브에이전트 C → my-app-feat-ui (UI 개선)
```

CLAUDE.md 설정 예시:

```markdown
## 병렬 태스크 규칙

- 각 기능은 독립 워크트리에서 개발
- 워크트리 경로: ~/projects/{프로젝트명}-{기능명}/
- 브랜치 명명: feat/{기능명}
- 워크트리 간 파일 공유 금지
- 머지는 반드시 PR을 통해 진행
```

### 패턴 2: tmux로 병렬 세션 관리

```bash
# tmux 세션 생성
tmux new-session -s agents -d

# 3개 패널로 분할
tmux split-window -h -t agents
tmux split-window -v -t agents:0.1

# 각 패널에 에이전트 실행
tmux send-keys -t agents:0.0 'cd ~/projects/my-app-feat-auth && claude' Enter
tmux send-keys -t agents:0.1 'cd ~/projects/my-app-feat-api && claude' Enter
tmux send-keys -t agents:0.2 'cd ~/projects/my-app-feat-ui && claude' Enter

# 세션 접속
tmux attach -t agents
```

### 패턴 3: Claude Code 서브에이전트 자동 워크트리

Claude Code의 Task 도구를 사용하면 오케스트레이터가 서브에이전트에게 자동으로 격리된 환경을 할당합니다:

```
오케스트레이터에서 지시:
"다음 3가지 태스크를 병렬로 처리해줘.
각 태스크는 독립 워크트리에서 실행해야 해:

태스크 A: feat/auth 브랜치에서 OAuth2 로그인 구현
태스크 B: feat/api 브랜치에서 REST API 응답 최적화
태스크 C: feat/ui 브랜치에서 대시보드 컴포넌트 리팩토링"
```

## 충돌 예방 규칙

Git Worktree를 써도 잘못 사용하면 충돌이 생깁니다. 지켜야 할 규칙들입니다.

### 파일 도메인 분리

| 에이전트 | 담당 파일/디렉토리 | 접근 금지 |
|----------|-------------------|-----------|
| auth | `src/auth/`, `tests/auth/` | `src/api/`, `src/ui/` |
| api | `src/api/`, `tests/api/` | `src/auth/`, `src/ui/` |
| ui | `src/components/`, `src/pages/` | `src/auth/`, `src/api/` |

공유 파일(`package.json`, `tsconfig.json`, `README.md`)은 **오케스트레이터 세션에서만** 수정합니다.

### 브랜치 전략

```bash
# 좋은 예: 각 에이전트가 독립 브랜치 보유
feat/auth     ← auth 에이전트 전용
feat/api      ← api 에이전트 전용
feat/ui       ← ui 에이전트 전용

# 나쁜 예: 여러 에이전트가 같은 브랜치 공유
feat/sprint-15 ← 모든 에이전트 공유 (충돌 위험)
```

## 워크트리 정리

작업이 끝나면 워크트리를 정리합니다.

```bash
# 특정 워크트리 제거
git worktree remove ../my-app-feat-auth

# 머지된 브랜치 워크트리 일괄 정리
git worktree prune

# 현재 상태 확인
git worktree list
```

PR이 머지된 후 자동으로 워크트리를 정리하려면:

```bash
# 머지 후 정리 스크립트
#!/bin/bash
BRANCH=$1
WORKTREE_PATH="../my-app-${BRANCH//\//-}"

if git branch -d "$BRANCH" 2>/dev/null; then
  git worktree remove "$WORKTREE_PATH" 2>/dev/null
  echo "Worktree $WORKTREE_PATH 정리 완료"
fi
```

## 실전 체크리스트

- [ ] 각 에이전트에 독립 워크트리 할당 완료
- [ ] `git worktree list`로 브랜치 겹침 없음 확인
- [ ] 파일 도메인 분리 규칙 CLAUDE.md에 명시
- [ ] 공유 파일 수정 시 오케스트레이터만 담당
- [ ] 작업 완료 후 `git worktree remove`로 정리
- [ ] PR 머지 전 `git worktree list`로 상태 재확인

## 흔한 실수와 해결

| 실수 | 증상 | 해결 |
|------|------|------|
| 같은 브랜치를 두 워크트리에 체크아웃 | `fatal: already checked out` 오류 | 각 워크트리마다 다른 브랜치 사용 |
| 워크트리에서 `git checkout` | 다른 워크트리가 사용 중인 브랜치 이동 시 오류 | `git switch` 대신 새 브랜치 생성 |
| 공유 파일 병렬 수정 | 머지 시 충돌 | 파일 도메인 엄격히 분리 |
| 워크트리 디렉토리 삭제 후 `prune` 미실행 | `git worktree list`에 오래된 경로 잔존 | `git worktree prune` 실행 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
