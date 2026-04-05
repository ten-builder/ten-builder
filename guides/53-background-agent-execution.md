# 53. 백그라운드 에이전트 실행 — 비동기 코딩 자동화

> 터미널을 닫아도 AI 에이전트가 계속 일하게 만드는 방법

## 왜 백그라운드 실행인가?

2026년 AI 코딩 에이전트의 가장 큰 변화는 **장시간 자율 실행**이에요. 프롬프트 하나 던지고 결과를 기다리는 게 아니라, 에이전트가 독립적으로 태스크를 수행하고 완료되면 알려주는 방식이죠.

GitHub Copilot의 Agent Mode, Cursor의 Background Agents, OpenAI Codex의 클라우드 실행 — 모두 같은 방향을 가리키고 있어요. 개발자가 자는 동안에도 에이전트가 코드를 작성하고, 테스트하고, PR을 만들어주는 거예요.

## 주요 도구별 백그라운드 실행 방식

| 도구 | 실행 환경 | 방식 | 특징 |
|------|----------|------|------|
| Claude Code | 터미널 (로컬/원격) | `--headless` + tmux/screen | 로컬 파일 시스템 직접 접근 |
| OpenAI Codex | 클라우드 VM | API 호출 → 샌드박스 실행 | 격리된 환경, 병렬 실행 |
| Cursor | 원격 VM | Background Agent 탭 | IDE 내 관리, 자동 PR |
| GitHub Copilot | GitHub Actions | Agent Mode trigger | 리포 단위 실행, CI 통합 |

## 방법 1: Claude Code Headless + tmux

가장 직접적인 방법이에요. 터미널에서 Claude Code를 헤드리스 모드로 실행하고, tmux로 세션을 유지해요.

### 기본 설정

```bash
# tmux 세션 생성
tmux new-session -d -s agent-work

# 세션 안에서 Claude Code 헤드리스 실행
tmux send-keys -t agent-work \
  'claude -p "src/api 폴더의 모든 엔드포인트에 입력값 검증 추가해줘. zod 스키마 사용." --allowedTools Edit,Bash,Read --output-format json' Enter
```

### 여러 에이전트 병렬 실행

```bash
#!/bin/bash
# run-agents.sh — 태스크별 에이전트 병렬 실행

TASKS=(
  "src/api 입력값 검증 추가"
  "src/utils 유틸 함수 단위 테스트 작성"
  "src/components 접근성 속성 추가"
)

for i in "${!TASKS[@]}"; do
  SESSION="agent-$i"
  tmux new-session -d -s "$SESSION"
  tmux send-keys -t "$SESSION" \
    "claude -p '${TASKS[$i]}' --allowedTools Edit,Bash,Read --output-format json > /tmp/agent-$i-result.json 2>&1" Enter
  echo "에이전트 $i 시작: ${TASKS[$i]}"
done

echo "모든 에이전트 실행 중. 'tmux ls'로 상태 확인"
```

### 완료 감지 + 알림

```bash
#!/bin/bash
# watch-agents.sh — 에이전트 완료 감지 & 슬랙/디스코드 알림

WEBHOOK_URL="https://discord.com/api/webhooks/..."

while true; do
  for session in $(tmux ls -F '#{session_name}' 2>/dev/null | grep '^agent-'); do
    # tmux 세션의 마지막 출력 확인
    LAST_LINE=$(tmux capture-pane -t "$session" -p | tail -5)

    if echo "$LAST_LINE" | grep -q "cost=\|result\|completed"; then
      # 결과 파일 확인
      IDX=${session#agent-}
      RESULT="/tmp/agent-$IDX-result.json"

      if [ -f "$RESULT" ]; then
        curl -s -H "Content-Type: application/json" \
          -d "{\"content\":\"에이전트 $session 완료\"}" \
          "$WEBHOOK_URL"

        # 세션 정리
        tmux kill-session -t "$session"
      fi
    fi
  done
  sleep 30
done
```

## 방법 2: AGENTS.md 기반 태스크 위임

`AGENTS.md` 파일로 에이전트의 역할과 범위를 정의하면, 더 체계적으로 태스크를 위임할 수 있어요.

### 프로젝트 루트에 AGENTS.md 작성

```markdown
# AGENTS.md

## /agents/api-validator
역할: API 엔드포인트 입력값 검증
범위: src/api/**
규칙:
- zod 스키마 사용
- 에러 응답 형식 통일
- 기존 테스트 깨지지 않게

## /agents/test-writer
역할: 누락된 단위 테스트 작성
범위: src/**/*.ts (*.test.ts 제외)
규칙:
- vitest 사용
- 커버리지 80% 이상
- 모킹은 최소한으로

## /agents/docs-updater
역할: API 문서 동기화
범위: docs/api/**
규칙:
- OpenAPI 스펙 기반
- 코드 변경 감지 시 자동 업데이트
```

### AGENTS.md 기반 실행 스크립트

```bash
#!/bin/bash
# run-by-agents-md.sh

PROJECT_DIR=$(pwd)
AGENTS_FILE="$PROJECT_DIR/AGENTS.md"

# AGENTS.md에서 에이전트 정의 파싱
parse_agents() {
  grep -E '^## /agents/' "$AGENTS_FILE" | sed 's/## \/agents\///'
}

for agent in $(parse_agents); do
  # 각 에이전트 섹션의 역할과 범위 추출
  ROLE=$(sed -n "/## \/agents\/$agent/,/## \/agents/p" "$AGENTS_FILE" | grep "역할:" | cut -d: -f2-)
  SCOPE=$(sed -n "/## \/agents\/$agent/,/## \/agents/p" "$AGENTS_FILE" | grep "범위:" | cut -d: -f2-)

  PROMPT="$ROLE. 대상 파일: $SCOPE. AGENTS.md의 규칙을 따라줘."

  tmux new-session -d -s "agent-$agent"
  tmux send-keys -t "agent-$agent" \
    "cd $PROJECT_DIR && claude -p '$PROMPT' --allowedTools Edit,Bash,Read" Enter

  echo "[$agent] 시작 — $ROLE"
done
```

## 방법 3: Git Worktree 분리 실행

각 에이전트가 독립적인 워킹 디렉토리에서 작업하면 충돌 없이 병렬 실행할 수 있어요.

```bash
#!/bin/bash
# parallel-worktree.sh — 브랜치별 독립 작업

REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_BASE="/tmp/agent-worktrees"
mkdir -p "$WORKTREE_BASE"

create_worktree_agent() {
  local NAME=$1
  local BRANCH="agent/$NAME"
  local DIR="$WORKTREE_BASE/$NAME"

  git branch "$BRANCH" main 2>/dev/null
  git worktree add "$DIR" "$BRANCH" 2>/dev/null

  echo "$DIR"
}

# 에이전트별 독립 워크트리 생성
API_DIR=$(create_worktree_agent "api-validation")
TEST_DIR=$(create_worktree_agent "test-coverage")
DOCS_DIR=$(create_worktree_agent "docs-sync")

# 각 워크트리에서 에이전트 실행
tmux new-session -d -s wt-api
tmux send-keys -t wt-api "cd $API_DIR && claude -p 'API 입력값 검증 추가' --allowedTools Edit,Bash,Read" Enter

tmux new-session -d -s wt-test
tmux send-keys -t wt-test "cd $TEST_DIR && claude -p '단위 테스트 보강' --allowedTools Edit,Bash,Read" Enter

tmux new-session -d -s wt-docs
tmux send-keys -t wt-docs "cd $DOCS_DIR && claude -p 'API 문서 업데이트' --allowedTools Edit,Bash,Read" Enter
```

### 완료 후 PR 자동 생성

```bash
#!/bin/bash
# create-prs.sh — 워크트리 작업 결과를 PR로

for dir in /tmp/agent-worktrees/*/; do
  NAME=$(basename "$dir")
  BRANCH="agent/$NAME"

  cd "$dir"

  # 변경사항 있는지 확인
  if [ -n "$(git status --porcelain)" ]; then
    git add -A
    git commit -m "feat: $NAME 자동 작업 완료"
    git push origin "$BRANCH"

    gh pr create \
      --title "feat: $NAME" \
      --body "에이전트가 자동으로 수행한 작업입니다." \
      --base main \
      --head "$BRANCH"

    echo "PR 생성: $BRANCH"
  fi
done

# 워크트리 정리
git worktree prune
```

## 실전 팁

### 에이전트 리소스 관리

```bash
# 동시 실행 에이전트 수 제한 (CPU 코어 수 기반)
MAX_AGENTS=$(( $(nproc 2>/dev/null || sysctl -n hw.ncpu) / 2 ))
echo "권장 최대 에이전트: $MAX_AGENTS"

# 메모리 사용량 모니터링
watch -n 5 'ps aux | grep -E "claude|node" | grep -v grep | awk "{sum+=\$6} END {printf \"에이전트 메모리: %.0f MB\n\", sum/1024}"'
```

### 실패 복구 패턴

| 실패 유형 | 감지 방법 | 복구 전략 |
|----------|----------|----------|
| 에이전트 크래시 | tmux 세션 종료 감지 | 자동 재시작 (최대 3회) |
| 무한 루프 | 30분 타임아웃 | 세션 강제 종료 + 롤백 |
| 테스트 실패 | exit code 확인 | 변경사항 stash + 알림 |
| 충돌 | git merge 실패 | rebase 시도 → 수동 알림 |

### 비용 제어

```bash
# 에이전트별 토큰 사용량 추적
claude -p "태스크" --output-format json 2>&1 | \
  python3 -c "
import sys, json
for line in sys.stdin:
    try:
        data = json.loads(line)
        if 'usage' in data:
            tokens = data['usage']
            cost = tokens.get('input_tokens', 0) * 0.000015 + \
                   tokens.get('output_tokens', 0) * 0.000075
            print(f'비용: \${cost:.4f}')
    except: pass
"
```

## 언제 백그라운드 실행을 쓰면 좋을까?

| 적합한 상황 | 비적합한 상황 |
|------------|-------------|
| 반복적인 리팩토링 (N개 파일) | 아키텍처 의사결정 |
| 테스트 작성/보강 | 새로운 기능 설계 |
| 문서 업데이트/동기화 | 보안 관련 코드 변경 |
| 린트/포맷 일괄 수정 | DB 스키마 마이그레이션 |
| 의존성 업데이트 후 호환성 수정 | 프로덕션 배포 스크립트 |

## 체크리스트

- [ ] `AGENTS.md`로 에이전트 역할과 범위 정의
- [ ] Git worktree 또는 별도 브랜치로 작업 격리
- [ ] 타임아웃 설정 (무한 루프 방지)
- [ ] 완료 알림 설정 (Slack/Discord webhook)
- [ ] 비용 상한 설정
- [ ] 변경사항 리뷰 프로세스 확립 (PR 기반)

## 다음 단계

→ [AI 에이전트 인텐트 기반 태스크 분해](../claude-code/playbooks/40-intent-based-task-decomposition.md)
→ [AI 에이전트 멀티 모델 라우팅](../workflows/ai-multi-model-routing.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
