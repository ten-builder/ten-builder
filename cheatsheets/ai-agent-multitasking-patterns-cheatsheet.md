# AI 에이전트 멀티태스킹 패턴 치트시트 2026

> 여러 AI 에이전트를 동시에 운영하면서 작업을 병렬 처리하는 실전 패턴 — 한 페이지 요약

## 핵심 개념: 왜 병렬인가

단일 에이전트로 작업할 때 병목 구간이 생기면 그 시간 동안 아무것도 하지 못한다. 에이전트를 병렬로 운영하면:

- 독립적인 기능 개발을 동시에 진행
- 에이전트 1이 테스트 작성하는 동안 에이전트 2가 다른 모듈 구현
- 전체 완료 시간을 직렬 대비 30~60% 단축

---

## Git Worktree — 병렬의 기반

| 명령어 | 설명 |
|--------|------|
| `git worktree add ../agent-feat-auth feature/auth` | 에이전트용 새 worktree 생성 |
| `git worktree add ../agent-feat-dashboard feature/dashboard` | 두 번째 에이전트 worktree |
| `git worktree list` | 현재 활성 worktree 목록 확인 |
| `git worktree remove ../agent-feat-auth` | 작업 완료 후 정리 |
| `git worktree prune` | 삭제된 디렉토리 참조 제거 |

**Worktree의 공유/격리 범위:**

| 항목 | 공유 여부 | 의미 |
|------|-----------|------|
| `.git/objects/` (이력) | 공유 | 저장 공간 효율적 |
| `.git/refs/` (브랜치명) | 공유 | 브랜치 이름 충돌 금지 |
| 작업 디렉토리 파일 | **격리** | 에이전트별 독립 편집 |
| `.git/index` (스테이징) | **격리** | 커밋 충돌 없음 |

---

## 병렬 에이전트 실행 패턴

### 패턴 1: 기능별 분리 (Feature Split)

```bash
# 메인 레포에서 worktree 두 개 생성
git worktree add ../agent-auth feature/auth
git worktree add ../agent-payment feature/payment

# 터미널 1: 인증 에이전트
cd ../agent-auth && claude

# 터미널 2: 결제 에이전트
cd ../agent-payment && claude
```

**언제 쓰는가:** 독립적인 기능 두 개를 동시에 개발할 때

### 패턴 2: 구현 + 테스트 분리 (Impl/Test Split)

```bash
# 에이전트 1: 구현 담당
git worktree add ../agent-impl feature/new-api

# 에이전트 2: 테스트 및 문서 담당
git worktree add ../agent-test test/new-api-coverage
```

**언제 쓰는가:** TDD 워크플로우, 에이전트 1이 코드 작성 중 에이전트 2가 테스트 준비

### 패턴 3: 리뷰 에이전트 분리 (Review Agent)

```bash
# 에이전트 1: 기능 개발
git worktree add ../agent-feat feature/dashboard

# 에이전트 2: 별도 컨텍스트에서 코드 리뷰
cd ../agent-feat
claude --print "구현된 코드를 OWASP Top 10 기준으로 보안 검토해줘"
```

**언제 쓰는가:** AI 생성 코드를 다른 컨텍스트의 AI로 교차 검증

---

## Claude Code 설정 — 병렬 최적화

### `.claude/settings.json` (worktree별 설정)

```json
{
  "worktree": {
    "baseRef": "main",
    "autoCleanup": true
  },
  "permissions": {
    "allow": ["Bash", "Edit", "Write"]
  }
}
```

### CLAUDE.md — 에이전트 역할 명시

```markdown
## 이 에이전트의 역할

**담당 범위:** `src/auth/` 모듈만 수정
**금지:** `src/payment/`, `src/shared/` 디렉토리 변경 금지
**완료 조건:** 모든 유닛 테스트 통과 + 타입 에러 0개
```

---

## 충돌 방지 전략

| 상황 | 대응 |
|------|------|
| 같은 파일 수정 가능성 | 담당 디렉토리를 CLAUDE.md에 명시 |
| 공유 타입/인터페이스 충돌 | 인터페이스 먼저 확정 → 구현 병렬화 |
| package.json 의존성 충돌 | 에이전트 1만 의존성 추가 권한 |
| 환경변수 충돌 | worktree별 `.env.local` 사용 |

### 머지 순서 설계

```
에이전트 A (공유 인터페이스) → 머지 먼저
에이전트 B (기능 A 구현) → A 머지 후 rebase → 머지
에이전트 C (기능 B 구현) → A 머지 후 rebase → 머지
```

---

## 비용 최적화

병렬 에이전트는 **비용도 병렬**로 증가한다. 에이전트 2개를 동시에 8시간 돌리면 비용도 2배.

| 전략 | 절감 효과 |
|------|----------|
| 단순 작업은 Sonnet, 복잡한 설계는 Opus | 30~50% |
| 에이전트 완료 후 즉시 종료 (idle 방지) | 10~20% |
| CLAUDE.md로 범위 제한 → 불필요한 탐색 감소 | 15~30% |
| 테스트/린트는 에이전트 대신 CI/CD에서 실행 | 의미있음 |

```bash
# 비용 모니터링 (Claude Code 내장)
/cost  # 현재 세션 누적 비용 확인
```

---

## 결과 통합 패턴

```bash
# 에이전트 A 작업 완료 후
cd ../agent-auth
git fetch origin main
git rebase origin/main
git push origin feature/auth

# PR 생성
gh pr create --title "feature: auth module implementation" \
  --base main

# 에이전트 B도 동일하게 진행
cd ../agent-payment
git rebase origin/main
# ...
```

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 같은 브랜치명으로 두 개 worktree 생성 | 브랜치명은 worktree마다 유일하게 |
| 에이전트가 다른 worktree 파일 수정 | CLAUDE.md에 절대 경로로 금지 명시 |
| Worktree 정리 안 하고 쌓임 | `git worktree prune` 주기적 실행 |
| 비용 추적 안 함 | 세션 시작/종료마다 `/cost` 확인 |

---

**더 자세한 가이드:** [git worktree 병렬 에이전트 실전 가이드](../guides/91-git-worktree-parallel-agents-guide.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
