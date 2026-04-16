# 플레이북 49: Claude Code 비동기 백그라운드 에이전트 운영

> 터미널을 닫아도 에이전트가 계속 일하게 만드는 법 — Tasks 기능과 병렬 실행 전략 실전 정리

## 소요 시간

20-40분 (초기 설정 기준)

## 사전 준비

- Claude Code 최신 버전 (2026년 1분기 이후)
- Git worktree 사용 가능한 프로젝트
- tmux 또는 screen (선택)

## 왜 비동기 실행이 필요한가

AI 에이전트가 복잡한 태스크를 처리할 때 가장 흔한 병목은 **대기 시간**입니다.

- 테스트 전체를 돌리는 동안 에이전트를 멈추고 기다려야 함
- 대규모 코드베이스 탐색에 수십 분 소요
- 서브에이전트가 결과를 반환할 때까지 메인 흐름 중단

동기 방식은 에이전트를 한 번에 한 가지 일만 하게 만듭니다. 비동기 실행은 이 구조를 바꿉니다. 여러 서브에이전트를 동시에 띄우고, 메인 에이전트는 다른 태스크를 계속 처리합니다.

## 핵심 개념: 세 가지 실행 모드

| 모드 | 특징 | 사용 시점 |
|------|------|----------|
| 동기(기본) | 서브에이전트 완료 대기 | 결과가 다음 단계에 즉시 필요할 때 |
| 백그라운드 Tasks | 별도 프로세스로 분리 실행 | 오래 걸리는 탐색, 빌드, 테스트 |
| Headless + worktree | 터미널 분리 + 독립 디렉토리 | 완전 병렬 코딩 세션 |

## Step 1: Tasks 기능으로 백그라운드 실행

Claude Code는 2026년 초부터 Tasks 기능을 지원합니다. 서브에이전트를 백그라운드로 전환하면 메인 에이전트가 계속 응답하면서 태스크가 병렬로 실행됩니다.

**기본 패턴:**

```
"이 레포의 테스트 커버리지가 낮은 파일 목록을 백그라운드에서 조사해줘.
완료되면 알려줘. 나는 다른 작업 계속할게."
```

에이전트가 서브태스크를 Tasks로 분리하면 `/tasks` 명령으로 진행 상황을 확인할 수 있습니다.

```
/tasks
```

```
TASK-01  analyzing coverage        running  [2m 14s]
TASK-02  indexing src/api          done     [1m 52s]
TASK-03  reviewing auth module     running  [0m 43s]
```

**완료 알림 설정 (`.claude/settings.json`):**

```json
{
  "notifications": {
    "onTaskComplete": true,
    "sound": true
  }
}
```

## Step 2: Git Worktree로 완전 병렬 실행

Tasks는 같은 워크스페이스 안에서 실행됩니다. 완전히 독립된 파일 시스템이 필요하면 Git worktree를 씁니다. 각 에이전트가 서로 다른 디렉토리에서 동시에 작업해 충돌을 막습니다.

**worktree 준비:**

```bash
# feature 브랜치별 worktree 생성
git worktree add ../my-project-auth feature/auth-refactor
git worktree add ../my-project-api  feature/api-cleanup
git worktree add ../my-project-test feature/add-tests
```

**에이전트 병렬 실행 (tmux 활용):**

```bash
# 세션 생성
tmux new-session -d -s agents

# 각 패널에 에이전트 실행
tmux send-keys -t agents "cd ../my-project-auth && claude -p 'auth 모듈을 OAuth 2.0으로 리팩터링해줘. PR 브랜치는 feature/auth-refactor'" Enter

tmux split-window -t agents
tmux send-keys -t agents "cd ../my-project-api && claude -p 'API 엔드포인트 응답 포맷을 JSON:API 스펙으로 통일해줘'" Enter

tmux split-window -t agents
tmux send-keys -t agents "cd ../my-project-test && claude -p '커버리지 60% 미만 파일에 유닛 테스트를 추가해줘'" Enter
```

세 에이전트가 독립 브랜치에서 동시에 작업합니다. 완료 후 각각 PR을 리뷰하면 됩니다.

## Step 3: Headless 모드로 터미널 없이 실행

터미널을 닫아도 에이전트가 계속 실행되게 하려면 `claude -p` + `nohup` 조합을 씁니다.

**기본 Headless 실행:**

```bash
nohup claude -p "src/ 전체를 분석해서 deprecated API 호출 목록을 DEPRECATED.md로 정리해줘" \
  --output-format json \
  > ~/logs/agent-deprecated.log 2>&1 &

echo "PID: $!"
```

**결과 파일로 출력 받기:**

```bash
nohup claude -p "$(cat <<'EOF'
다음 태스크를 수행해줘:
1. package.json의 모든 의존성 버전 확인
2. npm audit로 취약점 스캔
3. 결과를 ~/reports/security-$(date +%Y%m%d).md에 저장

완료 후 파일 경로를 출력해줘.
EOF
)" > ~/logs/security-scan.log 2>&1 &
```

**진행 확인:**

```bash
# 로그 실시간 확인
tail -f ~/logs/agent-deprecated.log

# 실행 중인 에이전트 확인
ps aux | grep "claude -p"
```

## Step 4: 결과 수집 패턴

병렬로 실행된 에이전트의 결과를 하나로 모으는 패턴입니다.

**공유 결과 파일 방식:**

```bash
REPORT_DIR=~/reports/$(date +%Y%m%d-%H%M)
mkdir -p "$REPORT_DIR"

# 각 에이전트가 같은 디렉토리에 결과 저장
nohup claude -p "auth 모듈 분석 결과를 $REPORT_DIR/auth.md에 저장해줘" &
nohup claude -p "api 모듈 분석 결과를 $REPORT_DIR/api.md에 저장해줘" &
nohup claude -p "DB 쿼리 성능 분석을 $REPORT_DIR/db.md에 저장해줘" &

# 모두 완료 후 병합
wait
cat "$REPORT_DIR"/*.md > "$REPORT_DIR/combined-report.md"
echo "최종 리포트: $REPORT_DIR/combined-report.md"
```

**CLAUDE.md로 에이전트 간 컨텍스트 공유:**

```markdown
# AGENTS.md (프로젝트 루트)

## 병렬 실행 컨텍스트

이 프로젝트는 여러 에이전트가 동시에 작업 중일 수 있습니다.

### 공유 규칙
- 결과는 반드시 `/tmp/agent-results/` 아래 개별 파일로 저장
- main 브랜치 직접 수정 금지 — 각자 feature 브랜치 사용
- 설정 파일(package.json, tsconfig.json) 동시 수정 금지
```

## 체크리스트

- [ ] Tasks 기능으로 백그라운드 서브에이전트 실행 확인
- [ ] `/tasks`로 진행 상황 모니터링 설정
- [ ] worktree 기반 병렬 브랜치 구조 준비
- [ ] Headless 실행 시 로그 파일 경로 지정
- [ ] 결과 수집 디렉토리 사전 생성
- [ ] AGENTS.md에 병렬 실행 규칙 명시
- [ ] wait / PID 추적으로 완료 감지

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 여러 에이전트가 같은 파일 수정 | worktree로 디렉토리 분리 |
| Headless 에이전트 로그 분실 | `nohup` + 명시적 로그 파일 경로 사용 |
| 태스크 완료 시점 모름 | `/tasks` 주기적 확인 또는 알림 설정 |
| 병렬 실행 중 컨텍스트 충돌 | AGENTS.md에 공유 규칙 명시 |
| 결과 파일 덮어쓰기 | 날짜+PID 기반 파일명 사용 |

## 다음 단계

→ [플레이북 47: AI 에이전트 플래닝 루프 복구 패턴](./47-planning-loop-recovery.md)
→ [플레이북 41: 멀티 파일 동시 편집](./41-multi-file-coherent-editing.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
