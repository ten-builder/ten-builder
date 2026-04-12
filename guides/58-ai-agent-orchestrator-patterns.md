# 오케스트레이터-워커 패턴 심화 가이드 — AI 에이전트 팀 조율하기

> 단일 에이전트의 한계를 넘어, 여러 AI 에이전트를 체계적으로 조율하는 오케스트레이터-워커 패턴을 실전 예제와 함께 정리합니다.

## 왜 오케스트레이터 패턴인가

단일 AI 에이전트는 컨텍스트 윈도우가 가득 차거나, 독립적으로 병렬 처리할 수 있는 작업을 하나씩 순차 실행하면서 병목이 생깁니다. 2026년 기준으로 프로덕션 팀이 가장 많이 채택하는 패턴은 **오케스트레이터가 계획을 세우고, 워커 에이전트들이 독립 실행**하는 방식입니다.

핵심 아이디어는 세 줄로 요약됩니다:

- 오케스트레이터: 전체 목표 분석 → 하위 태스크로 분해 → 공유 태스크 큐 생성
- 워커: 큐에서 태스크를 가져가 독립 실행 → 결과를 공유 저장소에 기록
- 오케스트레이터: 결과 취합 → 검증 → 다음 단계 결정

---

## 소요 시간

초기 설정 20-30분, 이후 재사용 시 5분 이내

## 사전 준비

- Claude Code 최신 버전 설치
- Git worktree 기능을 지원하는 레포지토리
- `AGENTS.md` 또는 각 에이전트 역할을 기술한 지시 파일

---

## Step 1: 태스크 분해 설계

오케스트레이터가 작업을 받으면 가장 먼저 **태스크 독립성 여부**를 판단합니다.

| 판단 기준 | 독립 처리 가능 | 순차 처리 필요 |
|-----------|--------------|--------------|
| 파일 의존성 | 서로 다른 파일 수정 | A 결과가 B 입력 |
| 상태 공유 | 없거나 읽기만 | 쓰기 공유 |
| 실행 시간 | 각 30분 이상 | 각 5분 이내 |

독립성이 확인된 태스크는 병렬 워커에게 위임합니다.

```bash
# 태스크 큐 파일 예시 (tasks.json)
{
  "tasks": [
    { "id": "task-001", "type": "implement", "target": "src/auth/login.ts", "status": "pending" },
    { "id": "task-002", "type": "implement", "target": "src/auth/logout.ts", "status": "pending" },
    { "id": "task-003", "type": "test", "target": "src/auth/", "status": "blocked", "depends_on": ["task-001", "task-002"] }
  ]
}
```

---

## Step 2: Git Worktree로 워커 격리

병렬 워커가 서로 충돌 없이 동시에 작업하려면 **각 워커마다 별도의 작업 디렉토리**가 필요합니다. Git worktree가 이 역할을 합니다.

```bash
# 오케스트레이터가 워커별 worktree 생성
git worktree add ../worker-auth-login feature/auth-login
git worktree add ../worker-auth-logout feature/auth-logout

# 각 worktree에서 Claude Code 독립 실행
cd ../worker-auth-login && claude --headless "AGENTS.md의 auth-login 태스크를 구현해줘"
cd ../worker-auth-logout && claude --headless "AGENTS.md의 auth-logout 태스크를 구현해줘"
```

워크트리를 사용하면 각 에이전트가:
- 독립된 파일 시스템 뷰를 가집니다
- 서로의 변경 사항을 덮어쓰지 않습니다
- 병렬로 커밋을 생성할 수 있습니다

---

## Step 3: 오케스트레이터-워커 역할 분리

### 오케스트레이터 AGENTS.md 예시

```markdown
# 오케스트레이터 에이전트

역할: 전체 목표 분해 및 워커 조율

## 책임
- tasks.json에 하위 태스크 등록
- 워커 결과 검토 및 통합 판단
- 실패한 태스크 재시도 or 인간에게 에스컬레이션

## 금지
- 직접 코드 구현 금지
- tasks.json 외 파일 직접 수정 금지
```

### 워커 AGENTS.md 예시

```markdown
# 워커 에이전트 — [태스크 ID]

역할: 지정된 단일 태스크 완료

## 책임
- 할당된 파일만 수정
- tasks.json의 상태를 "done" 또는 "failed"로 업데이트
- 완료 시 결과 요약을 results/[태스크ID].md에 저장

## 금지
- 다른 워커의 파일 수정 금지
- 새 의존성 추가 시 오케스트레이터에게 확인 필요
```

---

## Step 4: 결과 취합 및 검증

모든 워커가 완료되면 오케스트레이터가 결과를 검토합니다.

```bash
# 오케스트레이터 검증 스크립트
#!/bin/bash
FAILED=()
for dir in ../worker-*/; do
  cd "$dir"
  if ! npm test --silent 2>/dev/null; then
    FAILED+=("$dir")
  fi
  cd -
done

if [ ${#FAILED[@]} -eq 0 ]; then
  echo "모든 워커 통과 — 머지 진행"
  git worktree list | grep worker | while read path _; do
    git merge "$path"
  done
else
  echo "실패한 워커: ${FAILED[*]}"
  echo "오케스트레이터에게 재시도 요청"
fi
```

---

## Step 5: 패턴 변형 — Plan/Execute 분리

복잡한 시스템에서는 **계획 전담 모델**과 **실행 전담 모델**을 분리하는 방식도 있습니다.

| 역할 | 모델 | 역할 설명 |
|------|------|----------|
| 플래너 | Claude Opus | 아키텍처 결정, 태스크 우선순위 설정 |
| 리뷰어 | Claude Sonnet | 코드 리뷰, 일관성 검토 |
| 구현자 | Claude Haiku | 반복적 코드 생성, 단위 테스트 작성 |

```bash
# Plan/Execute 분리 예시
# 1단계: 플래너가 spec 작성
claude --model opus "다음 기능의 구현 계획을 작성해줘: {요구사항}" > plan.md

# 2단계: 구현자들이 병렬 실행
cat plan.md | claude --model haiku "plan.md를 읽고 할당된 모듈을 구현해줘" &
cat plan.md | claude --model haiku "plan.md를 읽고 테스트를 작성해줘" &
wait

# 3단계: 리뷰어가 통합 검토
claude --model sonnet "구현 결과를 리뷰하고 개선점을 제안해줘"
```

---

## 체크리스트

- [ ] 태스크 독립성 분석 후 병렬/순차 결정
- [ ] 워커마다 Git worktree 독립 환경 구성
- [ ] AGENTS.md에 각 에이전트 역할과 금지 사항 명시
- [ ] 공유 tasks.json 또는 태스크 큐 파일 설계
- [ ] 실패 시 재시도 또는 에스컬레이션 정책 결정
- [ ] 워커 완료 후 오케스트레이터 검증 단계 포함

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| 워커끼리 같은 파일 수정 | worktree 격리 + 파일 수정 범위 명시 |
| 태스크 의존성 무시 | tasks.json에 `depends_on` 필드 명시 |
| 오케스트레이터가 직접 구현 | 역할 분리 원칙 AGENTS.md에 명시 |
| 실패한 워커 무시 | results/ 폴더 상태 파일 의무화 |

---

## 다음 단계

→ [claude-code/playbooks/41-multi-file-coherent-editing.md](../claude-code/playbooks/41-multi-file-coherent-editing.md)
→ [guides/56-claude-code-subagent-parallel-guide.md](56-claude-code-subagent-parallel-guide.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
