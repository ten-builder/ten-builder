# AI 에이전트 팀 구성 가이드 — 역할 분담으로 복잡한 기능 완성하기

> 혼자 일하는 에이전트 하나보다 역할이 나뉜 팀이 낫다. 플래너, 아키텍트, 구현자, 테스터, 리뷰어가 각자 맡은 일에 집중할 때 결과물의 품질이 달라진다.

## 왜 팀인가

단일 에이전트로 복잡한 기능을 처음부터 끝까지 맡기면 두 가지 문제가 생깁니다.

첫째, 컨텍스트 오염. 플래닝 단계의 판단이 구현 단계에 섞이면 "계획은 그랬는데 코드가 달라졌어요" 상황이 반복됩니다. 둘째, 책임 분산 실패. 테스트 작성과 기능 구현을 같은 에이전트가 하면 자기 코드의 버그를 스스로 찾기 어렵습니다.

2026년 AI 코딩 환경에서 실제로 작동하는 팀 구조는 단순합니다.

```
플래너 → 아키텍트 → 구현자 → 테스터 → 리뷰어
```

각 역할이 전 단계의 결과물을 입력으로 받아 작업하고, 다음 단계로 넘깁니다.

## 역할별 책임

### 플래너 (Planner)

**입력:** 기능 요구사항 (이슈, 티켓, 자연어 설명)
**출력:** 구조화된 태스크 목록 + 의존성 맵

```markdown
## 플래너 프롬프트 패턴
당신은 시니어 PM입니다.
다음 기능 요구사항을 실행 가능한 개발 태스크로 분해하세요.
각 태스크는 독립적으로 구현 가능해야 합니다.

요구사항: {feature_description}

출력 형식:
- 태스크 목록 (의존성 명시)
- 예상 복잡도 (S/M/L)
- 리스크 요소
```

### 아키텍트 (Architect)

**입력:** 플래너 태스크 목록 + 기존 코드베이스 구조
**출력:** 설계 문서 (파일 경로, 인터페이스, 데이터 흐름)

아키텍트 에이전트는 구현하지 않습니다. 파일명, 함수 시그니처, 모듈 경계만 결정합니다.

```bash
# 아키텍트 에이전트 실행 예시 (Claude Code)
claude --model claude-opus-4-7 \
  --system "You are a software architect. Design only, do not implement." \
  "Analyze the codebase and design the file structure for: {task_list}"
```

### 구현자 (Implementer)

**입력:** 아키텍트 설계 문서 + 개별 태스크
**출력:** 실제 코드

구현자는 설계를 벗어나지 않습니다. 불확실한 부분은 코드 주석으로 표시하고 다음 단계로 넘깁니다.

```bash
# Git Worktree로 태스크별 격리 실행
git worktree add ../task-auth feature/auth-module
cd ../task-auth
claude "Implement auth module following: {design_doc}"
```

여러 태스크가 의존성이 없을 때 병렬 실행도 됩니다.

```bash
# 병렬 구현 (의존성 없는 태스크)
git worktree add ../task-ui feature/ui-components &
git worktree add ../task-api feature/api-endpoints &
wait
```

### 테스터 (Tester)

**입력:** 구현자 코드 + 원래 요구사항
**출력:** 테스트 파일 + 테스트 결과

테스터는 구현자가 작성한 코드를 보지 않고 **요구사항만 보고** 테스트를 먼저 작성하는 게 이상적입니다.

```bash
# 테스터 에이전트 — 요구사항 기반 테스트 생성
claude --system "You are a QA engineer. Write tests based on requirements, not implementation." \
  "Requirements: {requirements}
   Code to test: {implementation}
   Write comprehensive tests covering: happy path, edge cases, error handling"
```

| 테스트 유형 | 담당 에이전트 | 도구 |
|------------|-------------|------|
| 단위 테스트 | 테스터 | Jest/pytest/go test |
| 통합 테스트 | 테스터 | Playwright/Supertest |
| 성능 테스트 | 별도 스페셜리스트 | k6/locust |
| 보안 스캔 | 별도 스페셜리스트 | Semgrep/Trivy |

### 리뷰어 (Reviewer)

**입력:** 구현자 코드 + 테스터 결과 + 설계 문서
**출력:** 리뷰 코멘트 + 승인/거절 판단

리뷰어는 다른 모델을 쓰는 게 효과적입니다. Claude로 작성한 코드를 Gemini CLI로 리뷰하면 같은 모델의 맹점을 피할 수 있습니다.

```bash
# 교차 모델 리뷰
gemini -p "Review this code for security, performance, and correctness:
$(cat src/auth/index.ts)"
```

## 팀 구성 패턴 3가지

### 1. 순차형 파이프라인

```
[플래너] → [아키텍트] → [구현자] → [테스터] → [리뷰어]
```

가장 단순합니다. 각 단계가 완료되어야 다음으로 넘어갑니다. 기능이 명확하고 요구사항이 안정적일 때 적합합니다.

### 2. 병렬 구현형

```
[플래너] → [아키텍트] → [구현자A] + [구현자B] + [구현자C]
                                    ↓
                              [통합 테스터] → [리뷰어]
```

독립적인 모듈을 동시에 개발할 때 씁니다. Git Worktree로 격리하고 최종 통합만 직렬로 처리합니다.

### 3. 스페셜리스트 추가형

```
[플래너] → [아키텍트] → [구현자]
                              ↓
              [보안 전문가] + [성능 전문가] + [기능 테스터]
                              ↓
                         [리뷰어] → [머지]
```

고위험 기능(결제, 인증, 개인정보)에 적합합니다. 스페셜리스트는 자신의 관점만 검토합니다.

## AGENTS.md로 팀 규칙 정의하기

에이전트 팀을 일관되게 운영하려면 레포 루트에 `AGENTS.md`로 역할과 규칙을 문서화하세요.

```markdown
# 에이전트 팀 규칙

## 역할 정의
- planner: 태스크 분해만 담당. 코드 작성 금지.
- architect: 설계 문서만 작성. 구현 금지.
- implementer: architect 설계를 벗어나지 않음.
- tester: 구현자 코드를 보지 않고 테스트 작성 우선.
- reviewer: 최소 2가지 관점(보안, 품질)으로 리뷰.

## 커뮤니케이션 형식
각 단계 완료 시 HANDOFF.md 파일로 결과 전달:
- 완료 항목
- 미결 항목 (다음 단계 처리)
- 리스크 플래그
```

## 실전 예시: 로그인 기능 팀 개발

```bash
# 1. 플래너 실행
claude --system "You are a planner. Decompose tasks only." \
  "Build user login with email/password + JWT" > PLAN.md

# 2. 아키텍트 실행
claude --system "You are an architect. Design only." \
  "Design based on: $(cat PLAN.md)" > DESIGN.md

# 3. 구현자 실행 (Worktree)
git worktree add ../impl-login feature/login
cd ../impl-login
claude "Implement exactly as designed: $(cat DESIGN.md)"

# 4. 테스터 실행
cd ../impl-login
claude --system "You are a QA engineer." \
  "Write tests for requirements: $(cat PLAN.md)"
npm test

# 5. 리뷰어 실행 (다른 모델)
gemini -p "Review for security and correctness: $(git diff main)"
```

## 체크리스트

- [ ] 각 에이전트의 시스템 프롬프트에 역할 명시
- [ ] 단계별 핸드오프 형식 정의 (HANDOFF.md)
- [ ] 구현자는 Git Worktree로 격리
- [ ] 테스터는 요구사항 기반으로 먼저 실행
- [ ] 리뷰어에 다른 모델 사용 검토
- [ ] AGENTS.md에 팀 규칙 문서화

## 다음 단계

→ [오케스트레이터-워커 패턴](58-ai-agent-orchestrator-patterns.md)
→ [스페셜리스트 에이전트 역할 분담](../claude-code/playbooks/52-specialist-agent-roles.md)
→ [멀티 모델 교차 검증 워크플로우](62-multi-model-adversarial-review.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
