# 56: Claude Code 서브에이전트 병렬 실행 심화 가이드

> 복잡한 태스크를 쪼개서 동시에 처리하는 법 — 최대 7개 서브에이전트, Plan Mode, Git Worktree까지

## 왜 병렬 실행인가

Claude Code 혼자 큰 태스크를 처리하면 컨텍스트가 빨리 소진되고 시간도 오래 걸려요. 서브에이전트를 활용하면 독립적인 태스크를 나눠서 동시에 처리할 수 있어서 작업 시간이 크게 줄어요.

서브에이전트가 가장 빛나는 상황:
- 여러 모듈을 동시에 분석하거나 리팩토링할 때
- 코드베이스의 다른 부분을 병렬로 조사할 때
- 독립적인 기능을 동시에 구현할 때

## 서브에이전트 기본 개념

### Task 도구로 서브에이전트 실행

Claude Code는 `Task` 도구로 서브에이전트를 실행해요. 서브에이전트는 각자 독립된 컨텍스트를 가지며 메인 에이전트와 병렬로 실행돼요.

```bash
# 서브에이전트 실행 요청 예시 (Claude에게 지시)
"use subagents to investigate our authentication module and payment module simultaneously"
```

한 번에 최대 **7개**까지 동시 실행이 가능해요. 하지만 5개 이하로 운영하는 게 결과 품질 관리에 좋아요.

### 서브에이전트에 적합한 태스크

| 적합 | 부적합 |
|------|--------|
| 독립적 조사/리서치 | 순서가 정해진 작업 |
| 병렬 파일 분석 | 공유 상태 수정 |
| 모듈별 리팩토링 | 하나의 파일을 여럿이 수정 |
| 테스트 작성 (파일 분리) | 결과가 다음 작업 입력인 경우 |

## Plan Mode — 서브에이전트 실행 전 전략 수립

### Plan Mode 활용 패턴

큰 태스크에서는 먼저 Plan Mode로 실행 계획을 수립하고, 그다음 서브에이전트를 투입해요.

```bash
# 1단계: Plan Mode로 계획 수립
> /plan
"분석 범위: src/auth/, src/payment/, src/notification/ 세 모듈
각 모듈의 의존성, 복잡도, 리팩토링 우선순위를 분석해줘"

# Claude가 계획을 제시하면 검토 후 승인
# 2단계: 서브에이전트로 병렬 실행
> "위 계획대로 각 모듈을 서브에이전트로 동시 분석해줘"
```

### 언제 Plan Mode를 먼저 쓰는가

- 5개 이상 파일에 영향을 주는 작업
- 서브에이전트 간 의존성이 명확하지 않은 경우
- 비가역적 변경(파일 삭제, DB 마이그레이션)을 포함하는 작업

## Git Worktree로 진정한 병렬 실행

### 왜 Worktree인가

같은 레포에서 여러 Claude Code 세션을 열면 파일 충돌이 발생해요. Git Worktree는 같은 레포를 여러 디렉토리에서 독립적으로 체크아웃하여 이 문제를 해결해요.

### Worktree 세션 시작

```bash
# Claude Code에서 worktree 모드 실행
claude --worktree feature-auth-refactor
claude --worktree feature-payment-upgrade
claude --worktree feature-notification-overhaul
```

각 세션은 `.claude/worktrees/{branch-name}/` 에 독립 작업 디렉토리를 생성해요. 같은 Git 히스토리를 공유하지만 서로 다른 브랜치에서 작업해요.

### Worktree 상태 확인

```bash
# 현재 활성 worktree 목록
git worktree list

# 출력 예시
/Users/dev/myproject          abc1234 [main]
/Users/dev/myproject/.claude/worktrees/feature-auth    def5678 [feature-auth-refactor]
/Users/dev/myproject/.claude/worktrees/feature-payment ghj9012 [feature-payment-upgrade]
```

### Worktree 완료 후 정리

```bash
# 작업 완료 후 worktree 제거
git worktree remove .claude/worktrees/feature-auth-refactor

# 브랜치도 함께 삭제 (머지 완료 후)
git branch -d feature-auth-refactor
```

## 실전 패턴 — 코드베이스 전체 감사

복잡한 레포의 전체 감사 태스크를 병렬 서브에이전트로 처리하는 예시예요.

```
"다음 작업을 서브에이전트로 동시에 실행해줘:
1. src/auth/ — JWT 만료 처리와 토큰 갱신 로직 점검
2. src/api/ — 입력값 검증 누락 엔드포인트 찾기
3. src/db/ — N+1 쿼리 패턴 탐지
4. tests/ — 커버리지 0% 모듈 목록 작성
각 서브에이전트가 결과를 파일로 저장하게 해줘:
audit-auth.md, audit-api.md, audit-db.md, audit-coverage.md"
```

### 결과 통합

```bash
# 서브에이전트 결과를 하나로 합치기
cat audit-auth.md audit-api.md audit-db.md audit-coverage.md > full-audit.md

# Claude에게 통합 분석 요청
"full-audit.md를 바탕으로 우선순위 높은 이슈 Top 10을 정리해줘"
```

## 병렬 실행 시 흔한 실수

| 실수 | 결과 | 해결 |
|------|------|------|
| 같은 파일을 여러 에이전트가 수정 | 충돌 | Worktree 분리 또는 파일 분할 |
| 태스크 경계 불명확 | 중복 작업 | 각 에이전트 범위를 파일 경로로 명시 |
| 결과물 없이 "완료" | 내용 손실 | 항상 파일 저장 요청 |
| 너무 많은 에이전트 (7개 초과) | 오류 | 5개 이하로 묶기 |
| 의존성 있는 태스크 병렬화 | 잘못된 결과 | Plan Mode로 순서 확인 후 실행 |

## 서브에이전트 전용 AGENTS.md 작성

각 서브에이전트에게 역할을 명확하게 부여하고 싶다면 디렉토리별 `AGENTS.md`를 활용해요.

```markdown
# src/auth/AGENTS.md

## 이 디렉토리를 담당하는 에이전트 지침

- 인증 로직만 수정하세요. 비즈니스 로직은 건드리지 않아요
- 변경 시 기존 테스트 suite를 반드시 통과해야 해요
- JWT_SECRET은 절대 하드코딩하지 않아요
- 결과는 audit-auth.md에 기록해요
```

서브에이전트는 작업 디렉토리의 `AGENTS.md`를 자동으로 읽어요.

## 다음 단계

→ [39-codebase-health-check.md](./39-codebase-health-check.md) — AI로 코드베이스 전체 진단하기
→ [41-multi-file-coherent-editing.md](./41-multi-file-coherent-editing.md) — 여러 파일 일관성 있게 동시 수정

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
