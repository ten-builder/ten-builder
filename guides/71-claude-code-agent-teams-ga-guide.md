# Claude Code Agent Teams GA 실전 가이드

> 2026년 4월 정식 출시된 Agent Teams — 혼자 개발하던 방식에서 AI 팀과 협업하는 방식으로 바뀌는 전환점

## Agent Teams가 뭐가 다른가요?

기존 Claude Code 서브에이전트는 사용자가 명시적으로 `Task()` 도구를 호출해야 했어요. Agent Teams GA 이후로는 세 가지가 달라졌습니다.

1. **역할 기반 스폰**: 오케스트레이터가 리뷰어·구현자·테스터 등 역할을 정의하면, 팀원 에이전트가 자동 스폰
2. **Channels 기반 조율**: 에이전트 간 통신 채널이 표준화되어 결과 공유·충돌 방지가 자동 처리
3. **Permission Presets**: 팀 스폰 전에 파일 경계와 허용 명령어를 미리 설정해두면 매번 승인 대화 없이 실행

세 기능이 결합되면서 "여러 에이전트가 동시에 다른 파일을 수정해도 충돌 없이 완성된 결과를 받는" 플로우가 현실적으로 됩니다.

---

## 기본 팀 구성 패턴

### 구현 팀 (Implementation Team)

```
오케스트레이터
├── 구현자(Implementer) — src/ 파일 수정 전담
├── 테스터(Tester) — tests/ 파일 작성 전담
└── 리뷰어(Reviewer) — 읽기 전용, 피드백 생성
```

CLAUDE.md에 팀 구성 템플릿을 정의해두면 매 세션에서 재사용할 수 있어요.

```markdown
## Agent Teams: 기본 구현 팀

스폰 방법:
1. 오케스트레이터: "구현 팀 구성해줘 — [기능명]"
2. 구현자: src/, lib/ 파일만 수정
3. 테스터: tests/, __tests__/ 파일만 수정
4. 리뷰어: 읽기 전용 (파일 수정 불가)

팀 완료 기준: 구현자 완료 + 테스터 통과 + 리뷰어 승인
```

### 리뷰 팀 (Review Team)

PR이 열리면 세 역할이 동시에 분석하는 패턴:

```
오케스트레이터 (PR diff 수신)
├── 보안 리뷰어 — OWASP Top 10 기준 분석
├── 성능 리뷰어 — DB 쿼리, N+1, 캐시 분석
└── 테스트 커버리지 분석기 — 미처리 케이스 탐색
```

---

## Permission Presets 설정

Agent Teams에서 가장 많이 막히는 지점이 스폰 시마다 나타나는 승인 팝업이에요. CLAUDE.md로 미리 허용 범위를 정의하면 이 대화를 없앨 수 있습니다.

```markdown
## Permission Presets

### 구현자 에이전트
허용: Read, Write, Edit (src/, lib/, app/ 한정)
허용: Bash (npm test, pytest, cargo test만)
금지: Write (tests/, *.config.* 파일)
금지: Bash (git push, rm, curl)

### 테스터 에이전트
허용: Read (전체)
허용: Write, Edit (tests/, __tests__, spec/ 한정)
허용: Bash (테스트 실행 명령만)
금지: Write (src/ 파일)

### 리뷰어 에이전트
허용: Read (전체)
금지: Write, Edit, Bash (모든 수정 작업)
```

---

## Channels — 에이전트 간 조율

여러 에이전트가 동시에 실행될 때 서로의 진행 상황을 어떻게 공유할까요? Channels가 이 문제를 해결해요.

```
에이전트 A (구현자)
  └─ channel.send("feat/auth 완료, 검토 요청")

에이전트 B (리뷰어)
  └─ channel.listen("feat/auth")
  └─ channel.send("LGTM, 타입 누락 2건 발견")

오케스트레이터
  └─ channel.aggregate() → 최종 요약 생성
```

Channels 없이는 에이전트 B가 에이전트 A의 완료 시점을 모르기 때문에, 타이밍 문제로 불완전한 코드를 리뷰하는 일이 잦았어요.

실제 운영에서 유용한 Channel 패턴:

| 채널명 | 발신자 | 수신자 | 내용 |
|--------|--------|--------|------|
| `implementation` | 구현자 | 리뷰어 | 완료된 파일 목록 |
| `test-results` | 테스터 | 오케스트레이터 | 통과/실패 요약 |
| `review-feedback` | 리뷰어 | 구현자 | 수정 요청 사항 |
| `gate-status` | 오케스트레이터 | 전체 | 단계 전환 신호 |

---

## AutoDream — 복잡한 계획을 위한 보조 모드

AutoDream은 Agent Teams와 별도이지만 함께 쓸 때 효과가 큽니다. 복잡한 피처 요청이 들어올 때 오케스트레이터가 직접 태스크를 분배하는 대신, AutoDream이 먼저 계획을 세우고 팀을 구성해요.

```
사용자: "OAuth2 소셜 로그인 3종 추가해줘"

AutoDream 계획 단계:
1. 의존성 분석 (passport.js, OAuth 라이브러리)
2. 파일 경계 정의 (auth/, routes/, tests/auth/)
3. 병렬 실행 가능 여부 판단
4. 팀 구성: Google 구현자, GitHub 구현자, Kakao 구현자, 통합 테스터

팀 실행 단계:
- 세 구현자가 각 provider 파일 동시 작성
- 통합 테스터가 세 파일 완료 후 E2E 실행
```

**AutoDream이 필요한 상황:**
- 기능 요청이 5개 이상 파일에 걸쳐 있을 때
- 어느 에이전트에 어떤 파일을 맡길지 판단이 어려울 때
- 의존성 순서가 복잡해서 직렬 실행이 필요할 때

**AutoDream을 건너뛰어도 되는 상황:**
- 수정 파일이 명확할 때 (2~3개 이하)
- 이미 CLAUDE.md에 팀 템플릿이 있을 때
- 간단한 버그 수정이나 스타일 변경

AutoDream은 토큰을 많이 씁니다. 단순한 작업에 쓰면 시간과 비용이 낭비돼요.

---

## Remote Control + Dispatch로 팀 자동화

Agent Teams를 CI/CD와 연결하는 방식도 4월 업데이트에서 안정화됐어요.

```yaml
# GitHub Actions 예시 — PR 오픈 시 리뷰 팀 자동 실행
name: AI Review Team

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Dispatch Review Team
        env:
          CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
        run: |
          claude dispatch \
            --team review \
            --context "PR #${{ github.event.pull_request.number }}" \
            --channel pr-review-${{ github.event.pull_request.number }} \
            --auto-mode \
            "이 PR의 보안, 성능, 테스트 커버리지를 분석하고 GitHub에 코멘트로 올려줘"
```

Dispatch의 핵심은 `--auto-mode`예요. 이 플래그가 있으면 Agent Teams가 사람의 확인 없이 전체 리뷰를 완료하고 결과를 채널로 돌려보내요.

---

## 실전 운영 팁

### 팀 크기는 작게 유지하세요

에이전트가 많을수록 Channels 조율 비용이 늘어나요. 대부분의 경우 오케스트레이터 포함 3~4명이 최적입니다.

| 팀 규모 | 적합한 작업 |
|---------|------------|
| 2명 (오케스트레이터 + 실행자) | 단일 파일 리팩토링, 빠른 수정 |
| 3명 (오케스트레이터 + 구현자 + 리뷰어) | 대부분의 피처 개발 |
| 4명 (+ 테스터 추가) | 복잡한 기능, E2E 테스트 필요 |
| 5명 이상 | 대규모 마이그레이션, 모노레포 전체 작업 |

### Git Worktree와 함께 쓰세요

여러 에이전트가 같은 파일을 수정하면 충돌이 나요. Git Worktree로 각 에이전트에 독립 체크아웃을 주면 이 문제가 없어집니다.

```bash
# 구현자용 worktree
git worktree add ../feat-auth-implementer feat/auth

# 테스터용 worktree
git worktree add ../feat-auth-tester feat/auth
```

두 에이전트가 같은 브랜치의 다른 파일을 작업하다가 끝나면 오케스트레이터가 최종 병합 처리를 합니다.

### 채널 이름을 세션별로 분리하세요

같은 프로젝트에서 여러 Agent Teams가 동시에 돌아갈 때, 채널 이름이 겹치면 메시지가 뒤섞여요. 날짜나 피처명을 prefix로 쓰면 안전합니다.

```
좋은 예: auth-2026-04-24-implementation
나쁜 예: implementation (다른 팀과 충돌 가능)
```

---

## 체크리스트

- [ ] CLAUDE.md에 팀 역할과 파일 경계 정의
- [ ] Permission Presets로 반복 승인 제거
- [ ] 채널 이름 규칙 정해두기 (prefix 권장)
- [ ] Git Worktree 설정 (동시 파일 수정 시 필수)
- [ ] AutoDream은 복잡한 기획 태스크에만 사용
- [ ] 팀 크기 4명 이하로 시작, 필요시 확장

---

## 다음 단계

→ [오케스트레이터-워커 패턴 심화 가이드](./58-ai-agent-orchestrator-patterns.md)
→ [Claude Code 서브에이전트 병렬 실행](./56-claude-code-subagent-parallel-guide.md)
→ [백그라운드 에이전트 실행](./53-background-agent-execution.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
