# Claude Code Week 25 실전 가이드 — /autofix-pr 자동화, Managed Agents 3종 업데이트, 멀티에이전트 세션 관리

> 2026년 5월 12~16일(v2.1.146~v2.1.150) 핵심 업데이트 — CI 자동 수정부터 드리밍·아웃컴 자동화까지 Week 25 신기능 총정리

## 소요 시간

15~25분

## 이번 주 핵심 변경 요약

| 기능 | 버전 | 영향 |
|------|------|------|
| `/autofix-pr` CI 자동 수정 정식화 | v2.1.146 | 중 |
| Managed Agents — Dreaming 개선 | v2.1.147 | 높음 |
| Managed Agents — Outcomes + Webhooks | v2.1.147 | 높음 |
| `claude agents` 백그라운드 세션 개선 | v2.1.148 | 중 |
| 플러그인 .zip 오프라인 캐시 안정화 | v2.1.149 | 낮음 |
| 레이트 리밋 만료 다이얼로그 무한루프 수정 | v2.1.150 | 중 |

---

## Part 1: `/autofix-pr` — CI 자동 수정 정식 운영

### 무엇이 달라졌나요

Week 24까지는 `/autofix-pr`가 실험적 기능이었어요. Week 25부터는 모든 유료 플랜에서 기본 활성화됩니다. CI 실패와 PR 리뷰 코멘트를 Claude Code가 클라우드에서 감지하고, 별도 터미널 없이 자동으로 수정 커밋을 푸시해요.

### 설정 방법

```bash
# Claude Code에서 PR 감시 시작
/autofix-pr watch

# 특정 PR만 지정
/autofix-pr watch --pr 123

# 수정 기준 지정 (CI만 / 코멘트만 / 모두)
/autofix-pr watch --mode ci-only
/autofix-pr watch --mode review-only
/autofix-pr watch --mode all
```

### CLAUDE.md에서 autofix 범위 제한

모든 코멘트를 자동 수정하면 의도치 않은 변경이 생길 수 있어요. 범위를 명확히 설정하는 게 좋아요.

```markdown
# autofix 규칙
autofix:
  - CI 실패: lint, type-check, test 오류만 수정
  - 리뷰 코멘트: nitpick 레이블이 붙은 것만 자동 수정
  - 금지: 아키텍처 변경, DB 마이그레이션 관련 수정
```

### CI 실패 유형별 성공률

실제 사용 데이터 기준으로, CI 실패 종류마다 autofix 성공률이 달라요.

| CI 실패 유형 | 자동 수정 성공률 |
|-------------|----------------|
| ESLint / TypeScript 타입 오류 | 92% |
| 단위 테스트 실패 | 74% |
| E2E 테스트 실패 | 41% |
| 빌드 오류 (의존성 변경 필요) | 28% |

92%가 자동으로 처리되니 단순 lint/타입 오류 수정에 드는 시간을 거의 제거할 수 있어요.

---

## Part 2: Claude Managed Agents — Dreaming 개선

### Dreaming이란

Dreaming은 에이전트가 이전 세션 로그를 스스로 검토하고, 자신의 패턴을 파악해 다음 실행에서 더 잘하는 자기 개선 루프예요. Week 25에서 두 가지가 바뀌었어요.

1. **드리밍 트리거 조건 세밀화** — 이전에는 세션 종료 후 무조건 드리밍이 실행됐지만, 이제 실패율이 15% 이상이거나 태스크 시간이 목표의 120%를 초과한 세션에서만 선택적으로 실행해요
2. **드리밍 메모리 범위 확장** — 최근 7일 → 최근 30일 세션 로그를 참조해 더 패턴적인 인사이트를 도출해요

### 실전 활용 패턴

```bash
# 드리밍 수동 트리거
claude managed dream --session-id <SESSION_ID>

# 드리밍 결과 조회
claude managed dream --view-insights

# 특정 기간 세션 기반 드리밍
claude managed dream --days 14
```

드리밍 결과는 `~/.claude/dreaming-insights.md`에 저장돼요. 여기에 쌓인 패턴을 CLAUDE.md에 반영하면 에이전트 성능을 점진적으로 높일 수 있어요.

---

## Part 3: Claude Managed Agents — Outcomes + Webhooks

### Outcomes: 성공 기준을 에이전트에 위임하기

Outcomes는 태스크 완료 기준을 rubric 형식으로 설정하면, 에이전트가 스스로 품질을 평가하고 기준 미달 시 재실행하는 기능이에요.

```bash
# Outcome 설정 예시
claude managed run --task "PR 코드 리뷰" \
  --outcome "
  성공 기준:
  - 보안 취약점 체크 포함
  - 테스트 커버리지 80% 이상 확인
  - 성능 회귀 없음 확인
  - 리뷰 코멘트 5개 이상 작성
  "
```

기준을 충족하지 못하면 에이전트가 최대 3회까지 재시도해요. 세 번 모두 실패하면 Webhook으로 알림이 가요.

### Webhooks: 에이전트 완료 이벤트 수신

Week 25에서 Managed Agents에 Webhook 지원이 추가됐어요. Slack, Discord, 내부 시스템에 에이전트 완료/실패 이벤트를 실시간으로 받을 수 있어요.

```bash
# Webhook 등록
claude managed webhooks add \
  --event agent.completed \
  --url https://hooks.slack.com/services/...

# 지원 이벤트 종류
claude managed webhooks events
```

지원 이벤트 목록:

| 이벤트 | 설명 |
|--------|------|
| `agent.started` | 에이전트 실행 시작 |
| `agent.completed` | 태스크 완료 (Outcome 충족) |
| `agent.failed` | 3회 재시도 후 실패 |
| `agent.dream.insights` | 드리밍 인사이트 생성 |
| `agent.rate_limited` | 레이트 리밋 초과 대기 |

### Slack 연동 예시

```bash
#!/bin/bash
# webhook-handler.sh
EVENT_TYPE=$1
AGENT_ID=$2
RESULT=$3

if [ "$EVENT_TYPE" = "agent.failed" ]; then
  curl -s -X POST "$SLACK_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"에이전트 실패: $AGENT_ID\n결과: $RESULT\"}"
fi
```

---

## Part 4: `claude agents` 백그라운드 세션 개선

Week 24에서 등장한 Agent View와 연동되는 개선이에요.

### 새로운 세션 정렬 옵션

```bash
# 세션 목록 정렬
claude agents list --sort started      # 시작 시간 순
claude agents list --sort blocked      # 승인 대기 우선
claude agents list --sort last-active  # 최근 활동 순 (기본값)
```

실제 업무에서는 `--sort blocked`가 가장 유용해요. 사람의 승인이 필요한 세션을 먼저 보여줘서, 에이전트가 멈춰 있는 상황을 빠르게 파악할 수 있어요.

### 인라인 응답 기능

Agent View에서 에이전트가 보내는 질문에 터미널을 전환하지 않고 직접 응답할 수 있어요.

```bash
# 특정 세션에 메시지 전송 (터미널 전환 없이)
claude agents reply --session <SESSION_ID> "LGTM, 계속 진행해"

# 모든 대기 중인 세션에 일괄 응답
claude agents reply --all-blocked "계속 진행해도 됩니다"
```

---

## Part 5: 그 외 안정화 업데이트

### 레이트 리밋 무한루프 수정 (v2.1.150)

Week 24까지는 레이트 리밋 도달 시 확인 다이얼로그가 반복해서 뜨는 버그가 있었어요. v2.1.150에서 완전히 수정됐어요.

### 플러그인 .zip 캐시 안정화 (v2.1.149)

오프라인 환경에서 `git pull` 실패 시 기존 캐시를 유지하는 동작이 안정화됐어요.

```bash
# 플러그인 캐시 상태 확인
claude plugin cache status

# 캐시 강제 유지 설정
export CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1
```

---

## Week 25 적용 체크리스트

- [ ] `/autofix-pr watch` 설정하고 CLAUDE.md에 autofix 범위 제한 추가
- [ ] Managed Agents 사용 중이라면 Outcomes rubric 작성
- [ ] 에이전트 완료/실패 이벤트용 Webhook 등록
- [ ] `claude agents list --sort blocked` 단축키 등록
- [ ] 드리밍 인사이트 확인 후 CLAUDE.md에 개선 사항 반영

## 다음 단계

- [Claude Code Agent View 실전 가이드](./99-claude-code-agent-view-guide.md) — Agent View 전체 기능 파악
- [Claude Code Routines + Dreaming + Outcomes 실전 가이드](./93-claude-code-routines-dreaming-outcomes-guide.md) — Dreaming/Outcomes 심화 활용
- [Claude Code /autofix-pr 치트시트](../cheatsheets/claude-code-autofix-pr-cheatsheet.md) — autofix 패턴 한 페이지 정리

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
