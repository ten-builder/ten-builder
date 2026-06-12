# Cursor Background Agents 치트시트 2026 — 비동기 에이전트로 병렬 개발하기

> 코딩하는 동안 에이전트가 뒤에서 일하게 만드는 방법 — 한 페이지 요약

## Background Agents란?

Cursor의 Background Agents는 메인 세션에서 분리된 클라우드 환경에서 실행되는 비동기 AI 에이전트다. 작업을 지시하고 다른 일을 하다가, 에이전트가 PR을 만들어두면 나중에 확인하는 방식으로 쓴다.

---

## 빠른 시작

| 단계 | 방법 |
|------|------|
| 에이전트 실행 | `Ctrl+Shift+A` 또는 Sidebar > Agents |
| 작업 지시 | 자연어로 태스크 설명 (이슈 번호, 브랜치 지정 가능) |
| 진행 확인 | Agents 패널에서 실시간 로그 확인 |
| 결과 적용 | PR 생성 확인 후 리뷰·머지 |

---

## 핵심 사용 패턴

### 패턴 1: 긴 작업 위임

```
/agent
GitHub 이슈 #142 — 사용자 인증 JWT 만료 처리 버그 수정
- auth/middleware.ts 에서 토큰 갱신 로직 확인
- 테스트 추가
- PR 생성
```

### 패턴 2: 반복 작업 자동화

```
/agent
cheatsheets/ 폴더의 모든 .md 파일에서
깨진 내부 링크를 찾아 수정하고 PR 생성
```

### 패턴 3: 코드베이스 전반 리팩토링

```
/agent
tsconfig.strict 활성화 후 발생하는
TypeScript 타입 오류 전부 수정
변경 파일이 많으면 디렉토리별로 커밋 분리
```

---

## 작업 유형별 적합도

| 작업 유형 | Background Agent | 메인 세션 |
|-----------|-----------------|-----------|
| 이슈 기반 버그 수정 | ✅ 최적 | — |
| 대규모 리팩토링 | ✅ 최적 | — |
| 의존성 업그레이드 | ✅ 최적 | — |
| 테스트 커버리지 추가 | ✅ 좋음 | — |
| 문서 자동화 | ✅ 좋음 | — |
| 실시간 피드백 필요 | — | ✅ 최적 |
| 복잡한 아키텍처 설계 | — | ✅ 최적 |
| 디버깅 (단계별) | — | ✅ 최적 |

---

## 효과적인 프롬프트 구성

```
[배경 컨텍스트]
프로젝트: Next.js 15 App Router + Prisma + PostgreSQL

[태스크]
결제 모듈(app/billing/)에서 Stripe 웹훅 서명 검증이
누락된 엔드포인트 2곳을 찾아 수정

[기준]
- stripe-signature 헤더 검증 필수
- 실패 시 400 반환
- 단위 테스트 추가 (vitest)

[결과물]
PR 생성 — 제목: fix(billing): add webhook signature validation
```

**핵심:** 배경 → 태스크 → 기준 → 결과물 순서로 구체적으로 작성할수록 품질이 높아진다.

---

## CLAUDE.md / .cursorrules 연동

Background Agent도 레포의 `.cursorrules`와 `CLAUDE.md`를 읽는다. 에이전트 전용 섹션을 추가하면 일관성을 유지할 수 있다.

```markdown
## Background Agent Rules
- PR 제목: feat/fix/chore(scope): description 형식 사용
- 커밋은 작업 단위로 분리 (atomic commits)
- 테스트 없는 기능 PR 금지
- 변경 파일 20개 초과 시 태스크를 분리해 여러 PR 생성
```

---

## 병렬 에이전트 전략

동시에 여러 에이전트를 실행할 수 있다. Git 워크트리를 활용하면 충돌 없이 병렬 작업이 가능하다.

```bash
# 워크트리 준비 (에이전트별 독립 디렉토리)
git worktree add ../feature-auth feature/auth-refactor
git worktree add ../feature-billing feature/billing-fix

# 에이전트 1: auth 작업
# 에이전트 2: billing 작업 (동시 실행)
```

| 에이전트 | 브랜치 | 작업 |
|----------|--------|------|
| Agent 1 | feature/auth-refactor | 인증 모듈 리팩토링 |
| Agent 2 | feature/billing-fix | 결제 버그 수정 |
| Agent 3 | chore/dep-update | 의존성 업그레이드 |

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 프롬프트가 너무 모호함 | 파일 경로, 함수명, 기대 결과를 구체적으로 명시 |
| 너무 큰 태스크 한 번에 지시 | 500줄 이상 변경이 예상되면 태스크를 나누기 |
| 결과 검증 없이 머지 | PR 코드 리뷰 후 머지, 테스트 통과 확인 필수 |
| 에이전트 무한 루프 | 에러 발생 시 재시도 제한 지시: "3회 이상 실패하면 중단하고 현황 보고" |
| 컨텍스트 누락 | 관련 파일 경로, 기술 스택, 제약 조건을 프롬프트에 포함 |

---

## Claude Code와 역할 분담

```
Claude Code (메인 세션)          Cursor Background Agent
─────────────────────            ──────────────────────────
아키텍처 설계, 복잡한 로직        이슈 해결, 버그 수정
실시간 디버깅                     대규모 리팩토링
PR 리뷰, 코드 검토               의존성 업그레이드
빠른 수정 (< 5분)                반복 작업, 테스트 생성
```

---

**더 자세한 가이드:** [guides/73-cursor-ide-practical-guide-2026.md](../guides/73-cursor-ide-practical-guide-2026.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
