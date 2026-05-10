# 플레이북 63: AI 에이전트 상태 지속성 플레이북

> 장시간 실행되는 AI 에이전트의 상태를 보존하고 복구하는 실전 전략 — 컨텍스트 윈도우를 넘어 작업을 계속하는 법

## 소요 시간

30-60분 (초기 설정), 이후 자동화

## 사전 준비

- Claude Code 최신 버전
- 프로젝트 루트에 `CLAUDE.md` 또는 `AGENTS.md` 파일
- 체크포인트 저장용 디렉토리 (`~/.agent-checkpoints/` 또는 프로젝트 내 `.checkpoints/`)

---

## 왜 상태 지속성이 필요한가

장시간 실행 AI 에이전트의 가장 큰 위협은 컨텍스트 소진이다. 에이전트가 중간에 중단되면 이전까지의 작업 맥락을 잃고 처음부터 다시 시작해야 한다.

2026년 현재 실제 팀들이 겪는 상황:

| 상황 | 결과 |
|------|------|
| 컨텍스트 윈도우 한계 도달 | 이전 결정과 맥락을 잃고 재시작 |
| 네트워크/API 장애 | 완료된 작업도 다시 처음부터 |
| 실수로 터미널 종료 | 진행 중이던 멀티파일 작업 유실 |
| 다음 날 다시 시작 | 어디까지 했는지 에이전트가 모름 |

상태 지속성은 에이전트에게 "기억"을 주는 작업이다.

---

## Step 1: 체크포인트 디렉토리 구성

```bash
# 프로젝트별 체크포인트 디렉토리
mkdir -p .checkpoints

# .gitignore에 추가 (선택적으로 git에서 제외)
echo ".checkpoints/" >> .gitignore

# 또는 Git으로 추적하여 팀과 공유
# (작업 상태를 팀원과 공유할 때 유용)
```

체크포인트 파일 구조:

```
.checkpoints/
  current.yaml       # 현재 진행 상태
  phase-01.yaml      # 각 단계별 스냅샷
  phase-02.yaml
  rollback.yaml      # 롤백 포인트
```

---

## Step 2: CLAUDE.md에 체크포인트 규칙 추가

에이전트가 자동으로 체크포인트를 저장하게 지시한다:

```markdown
## 상태 관리 규칙

### 체크포인트 저장 시점
- 각 주요 단계 완료 시 `.checkpoints/current.yaml` 업데이트
- 파일 5개 이상 수정 후 `.checkpoints/phase-{N}.yaml` 저장
- 외부 API 호출 전 상태 저장

### 체크포인트 형식
현재 진행 단계, 완료된 파일 목록, 다음 할 일, 결정 사항을 기록한다.

### 재개 시 처음 할 일
`.checkpoints/current.yaml`을 먼저 읽고 어디서부터 시작할지 파악한다.
```

---

## Step 3: 체크포인트 파일 형식

`.checkpoints/current.yaml` 예시:

```yaml
timestamp: "2026-05-10T15:30:00+09:00"
task: "인증 모듈 리팩토링"
phase: 3
total_phases: 5

completed:
  - path: src/auth/jwt.ts
    action: "JWT 검증 로직 개선"
    result: "완료"
  - path: src/auth/middleware.ts
    action: "미들웨어 타입 안전성 강화"
    result: "완료"

in_progress:
  - path: src/auth/session.ts
    action: "세션 관리 로직 리팩토링"
    status: "50% 완료"

pending:
  - path: src/auth/oauth.ts
    action: "OAuth 플로우 업데이트"
  - path: tests/auth.test.ts
    action: "테스트 커버리지 추가"

decisions:
  - "JWT 만료 시간 15분으로 통일"
  - "refresh token은 httpOnly 쿠키만 사용"

next_action: "src/auth/session.ts의 SessionStore 클래스부터 재개"

blockers: []
```

---

## Step 4: Claude Code 내장 기능 활용

Claude Code는 세션 재개를 기본으로 지원한다:

| 명령어 | 용도 |
|--------|------|
| `/resume [이름]` | 이전 세션 재개 |
| `/rewind` | 마지막 체크포인트로 되돌리기 |
| `/clear` | 새 대화 시작 (세션은 저장됨) |
| `/compact` | 컨텍스트 압축 (진행 유지) |

```bash
# 세션 이름 붙이기 (재개 쉽게)
claude --session auth-refactor

# 다음 날 재개
claude
> /resume auth-refactor
```

**중요:** `/clear` 이후에도 파일 체크포인트는 남는다. 에이전트가 재시작하면 CLAUDE.md 규칙에 따라 `.checkpoints/current.yaml`을 먼저 읽게 된다.

---

## Step 5: 단계별 상태 저장 패턴

장시간 작업을 단계로 나누고 각 단계 완료 시 저장한다:

```bash
# Phase 완료 체크포인트 저장 스크립트
cat > .checkpoints/save-phase.sh << 'EOF'
#!/bin/bash
PHASE=$1
DESCRIPTION=$2

cp .checkpoints/current.yaml ".checkpoints/phase-$(printf '%02d' $PHASE).yaml"

echo "Phase $PHASE 체크포인트 저장: $DESCRIPTION"
echo "Saved at: $(date '+%Y-%m-%dT%H:%M:%S')"
EOF

chmod +x .checkpoints/save-phase.sh
```

**Git 기반 체크포인트** (팀 작업 시 권장):

```bash
# 각 단계 완료 후 WIP 커밋
git add -A
git commit -m "wip: phase 3 complete - session management refactored"

# 체크포인트 태그
git tag checkpoint/auth-phase-3

# 롤백이 필요할 때
git checkout checkpoint/auth-phase-2
```

---

## Step 6: 실패 복구 워크플로우

에이전트가 중단되었을 때 복구하는 순서:

```bash
# 1. 마지막 상태 확인
cat .checkpoints/current.yaml

# 2. 완료된 파일 검증
git diff HEAD~5 --name-only  # 최근 변경된 파일

# 3. 에이전트 재시작 시 컨텍스트 주입
claude << 'EOF'
이전 작업을 재개한다. 먼저 .checkpoints/current.yaml을 읽어서
어디까지 완료됐는지 파악하고, next_action부터 시작해라.
완료된 파일은 다시 수정하지 않는다.
EOF
```

---

## 체크리스트

- [ ] `.checkpoints/` 디렉토리 생성
- [ ] CLAUDE.md에 체크포인트 규칙 추가
- [ ] `current.yaml` 형식 정의
- [ ] 단계별 저장 시점 결정 (파일 N개, 단계 완료, 시간 기준)
- [ ] Git 체크포인트 태그 전략 수립
- [ ] 팀과 체크포인트 공유 방식 합의
- [ ] 복구 프로세스 문서화

---

## 상태 지속성 전략 비교

| 전략 | 적합한 상황 | 구현 복잡도 |
|------|-------------|-------------|
| CLAUDE.md 규칙 | 단기 작업, 개인 프로젝트 | 낮음 |
| YAML 체크포인트 | 중기 작업, 명확한 단계 구분 | 중간 |
| Git 태그 기반 | 팀 작업, 롤백 필요 | 중간 |
| 외부 상태 저장소 | 장기 자율 에이전트 | 높음 |

## 다음 단계

→ [플레이북 58: 체크포인트 기반 장기 실행](58-checkpoint-autonomous-operation.md)
→ [플레이북 57: 컨텍스트 오염 방지](57-context-contamination-prevention.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
