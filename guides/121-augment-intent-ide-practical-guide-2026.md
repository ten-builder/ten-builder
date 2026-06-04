# Augment Intent 실전 가이드 2026 — 리빙 스펙으로 멀티에이전트 개발 조율하기

> 단일 에이전트 프롬프트의 한계를 넘어, 여러 AI 에이전트가 하나의 살아있는 명세(Living Spec)를 공유하며 협력하는 방식이 등장했다.

## Intent가 해결하는 문제

Claude Code나 Cursor 같은 단일 에이전트 도구는 `오케스트레이터 1명 + 지시` 구조다. 복잡한 기능을 개발할 때 생기는 세 가지 문제가 있다.

| 문제 | 설명 |
|------|------|
| 에이전트 간 정렬 실패 | 백엔드·프론트엔드를 병렬로 작업할 때 서로 다른 API 계약을 구현 |
| 계획 표류 | 에이전트가 진행 중에 초기 의도에서 멀어짐 |
| 재시작 비용 | 에이전트가 막히면 컨텍스트를 다시 세팅해야 함 |

Intent는 이 세 문제를 **리빙 스펙(Living Spec)** 하나로 해결한다. 모든 에이전트가 동일한 명세를 실시간으로 읽고 업데이트하며 작업 경계를 지킨다.

## 핵심 개념 3가지

### 1. 리빙 스펙 (Living Spec)

일반 PRD나 CLAUDE.md와 다르다. 에이전트가 실행 도중 읽고 쓸 수 있는 동적 문서다.

```markdown
# 결제 모듈 명세 (리빙 스펙 예시)

## 현재 상태
- 백엔드: Stripe webhook 핸들러 완료 ✅
- 프론트엔드: 결제 폼 UI 구현 중 🔄
- 테스트: 대기 ⏳

## 합의된 API 계약
POST /api/payments/checkout
Body: { amount: number, currency: string, userId: string }
Response: { sessionId: string, redirectUrl: string }

## 에이전트 작업 경계
- Agent-A: 백엔드 API 담당
- Agent-B: 프론트엔드 컴포넌트 담당
- Agent-C: 통합 테스트 담당
```

에이전트 A가 API 스펙을 변경하면 리빙 스펙이 즉시 업데이트되고, 에이전트 B는 이를 읽어 폼 로직을 조정한다.

### 2. 코디네이터-스페셜리스트-검증자 구조

Intent의 기본 3에이전트 워크플로우다.

```
코디네이터(Coordinator)
    ├── 스페셜리스트 A (구현 담당)
    ├── 스페셜리스트 B (구현 담당)
    └── 검증자(Verifier)
```

**코디네이터:** 리빙 스펙을 기반으로 태스크를 분해하고 스페셜리스트에 배분  
**스페셜리스트:** 독립된 git worktree에서 작업하며 완료 시 스펙 업데이트  
**검증자:** 스페셜리스트 결과물이 스펙과 일치하는지 확인 후 머지 승인

### 3. 격리된 Worktree 실행

각 에이전트는 독립된 git worktree에서 실행된다. 파일 충돌 없이 동시 작업이 가능하다.

```bash
# Intent가 내부적으로 처리하는 worktree 설정
git worktree add .intent-worktrees/agent-a feature/payment-backend
git worktree add .intent-worktrees/agent-b feature/payment-frontend
git worktree add .intent-worktrees/agent-c feature/payment-tests
```

## 설치 및 시작

### 설치

Intent는 현재 Mac 데스크탑 앱으로 제공된다.

```bash
# Homebrew 설치 (2026년 기준)
brew install --cask augment-intent

# 또는 공식 사이트에서 다운로드
# https://www.augmentcode.com/intent
```

### 기존 에이전트 연결

자체 Claude Code나 Codex 구독이 있으면 그대로 연결한다.

```json
// ~/.intent/config.json
{
  "agents": {
    "coordinator": {
      "provider": "anthropic",
      "model": "claude-opus-4-8",
      "role": "coordinator"
    },
    "specialist": {
      "provider": "anthropic",
      "model": "claude-sonnet-4-6",
      "role": "specialist"
    },
    "verifier": {
      "provider": "openai",
      "model": "o3",
      "role": "verifier"
    }
  }
}
```

비용 최적화 팁: 코디네이터에는 성능 좋은 모델, 스페셜리스트에는 빠른 모델, 검증자에는 추론 특화 모델을 쓰면 품질과 비용의 균형을 잡을 수 있다.

## 실전 워크플로우

### Step 1: 스펙 작성

Intent에서 새 워크스페이스를 열고 스펙 파일을 작성한다.

```markdown
# 사용자 인증 시스템

## 범위
- 이메일/비밀번호 로그인
- JWT 토큰 발급 및 갱신
- 비밀번호 재설정 이메일

## 기술 스택
- 백엔드: Node.js + Express + Prisma
- 프론트엔드: Next.js App Router
- DB: PostgreSQL

## 완료 기준
- [ ] 로그인 API 테스트 통과
- [ ] 프론트엔드 폼 컴포넌트 완성
- [ ] E2E 테스트 3개 통과
```

### Step 2: 코디네이터 실행

스펙을 확정하면 코디네이터가 태스크를 분해한다.

```
코디네이터 출력 예시:
1. Agent-A: POST /auth/login API 구현 (예상 30분)
2. Agent-B: LoginForm 컴포넌트 + 유효성 검사 UI (예상 25분)
3. Agent-C: Prisma 스키마 + 마이그레이션 (예상 15분)
4. Agent-D: 통합 테스트 작성 (Agent A, B, C 완료 후)
```

의존성이 없는 A, B, C는 병렬로 실행되고, D는 세 작업이 끝난 후 순차 실행된다.

### Step 3: 실시간 모니터링

Intent의 Agent Cards 패널에서 각 에이전트 상태를 실시간으로 볼 수 있다.

| 에이전트 | 상태 | 완료 비율 | 현재 작업 |
|---------|------|---------|---------|
| Agent-A | 실행 중 | 60% | POST /auth/login 라우터 작성 |
| Agent-B | 실행 중 | 40% | 폼 유효성 검사 훅 작성 |
| Agent-C | 완료 | 100% | - |
| Agent-D | 대기 | 0% | A, B 완료 대기 중 |

### Step 4: 스펙 갱신 처리

에이전트가 구현 중 설계 결정이 필요하면 리빙 스펙에 질문을 남긴다.

```markdown
## 미결 사항
- [Agent-A] JWT 만료 시간: 1시간 vs 24시간? → 결정 필요
```

개발자가 스펙을 직접 수정하면 에이전트가 즉시 반영한다. 에이전트를 재시작할 필요 없다.

## Cursor / Claude Code와의 역할 분담

Intent가 모든 것을 대체하지 않는다. 각 도구의 강점이 다르다.

| 상황 | 적합한 도구 |
|------|-----------|
| 단일 파일 빠른 수정 | Claude Code 또는 Cursor |
| 새 기능 전체 구현 (다수 파일) | Intent |
| 레거시 리팩토링 (범위 큰 경우) | Intent |
| 빠른 프로토타입 탐색 | Claude Code |
| 팀 협업, 역할 분리 필요 | Intent |

실제 팀 사용 패턴: 개인 탐색 단계는 Claude Code, 기능 구현은 Intent, 코드 리뷰·수정은 다시 Claude Code.

## Kiro와의 비교

아마존의 Kiro도 스펙 주도 개발을 지향한다. 두 도구의 차이를 파악해두면 선택이 쉬워진다.

| 항목 | Augment Intent | Kiro |
|------|---------------|------|
| 멀티에이전트 | 실시간 조율 | 단일 에이전트 |
| 인프라 | 에이전트 독립 | AWS 네이티브 |
| 스펙 방식 | 리빙(동적) 스펙 | 정적 요구사항 |
| 에이전트 선택 | BYOA (자유 선택) | Kiro 내장 |
| 적합한 경우 | 복잡한 멀티에이전트 협업 | AWS 중심 프로젝트 |

## 자주 묻는 질문

**Q. Claude Code 구독이 있으면 따로 비용이 드나요?**  
A. Intent 자체는 별도 플랜이 있고, 에이전트로 기존 Claude Code나 OpenAI API를 BYOA(Bring Your Own Agent)로 연결할 수 있다. API 사용량은 기존 구독 또는 직접 청구된다.

**Q. 에이전트가 서로 파일을 덮어쓸 수 있나요?**  
A. 각 에이전트는 독립된 git worktree에서 실행되므로 기본적으로 충돌이 없다. 코디네이터가 작업 경계를 스펙 단위로 명시하여 overlap을 방지한다.

**Q. 에이전트 하나가 실패하면?**  
A. 해당 태스크만 재실행된다. 리빙 스펙에 실패 이유가 기록되고 코디네이터가 복구 계획을 세운다.

## 체크리스트

- [ ] Intent 앱 설치 및 에이전트 연결 확인
- [ ] 첫 리빙 스펙 작성 (5줄 이상, 완료 기준 포함)
- [ ] 코디네이터 실행 후 태스크 분해 결과 검토
- [ ] Agent Cards 패널에서 병렬 실행 확인
- [ ] 미결 사항 처리 패턴 1회 실습

## 다음 단계

→ [오케스트레이터-워커 패턴 심화 가이드](58-ai-agent-orchestrator-patterns.md)  
→ [Claude Code Agent Teams GA 실전 가이드](71-claude-code-agent-teams-ga-guide.md)  
→ [멀티에이전트 세션 병렬 관리](../claude-code/playbooks/66-multitasking-agents-session-management.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)  
**YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
