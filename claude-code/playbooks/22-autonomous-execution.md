# 22. AI 에이전트 자율 실행 설계 플레이북

> AI 코딩 에이전트의 자율 실행 범위를 설계하고, 안전 장치를 갖춘 승인 워크플로우를 구축하는 6단계 가이드

## 왜 자율 실행 설계가 필요한가?

AI 코딩 에이전트가 코드 생성부터 테스트, 배포까지 수행하는 시대가 왔어요. 하지만 "전부 자동화하자"와 "하나하나 확인하자" 사이 어딘가에 정답이 있습니다:

- **과도한 승인** → 생산성 하락, 에이전트 활용 의미 퇴색
- **무분별한 자율 실행** → 시스템 장애, 데이터 손실, 보안 사고
- **적절한 설계** → 반복 작업은 자동화하고, 위험한 작업은 사람이 검수

```
┌──────────────────────────────────────────────────────────────┐
│  자율 실행 설계 6단계                                         │
│                                                              │
│  1. 액션 인벤토리 — 에이전트가 하는 모든 행동 목록화            │
│  2. 위험도 분류 — Low / Medium / High / Critical 등급 부여     │
│  3. 권한 매트릭스 — 등급별 실행 정책 설계                      │
│  4. 승인 워크플로우 — 사람 개입 지점과 흐름 구축                │
│  5. 안전 장치 — 롤백, 드라이런, 제한 시간 설정                  │
│  6. 모니터링 & 감사 — 실행 로그, 알림, 주기적 리뷰             │
└──────────────────────────────────────────────────────────────┘
```

## Step 1: 액션 인벤토리 작성

에이전트가 수행할 수 있는 모든 액션을 목록화하세요. 누락되면 통제 밖의 행동이 생깁니다.

### 전형적인 AI 코딩 에이전트 액션 목록

| 카테고리 | 액션 예시 | 비고 |
|----------|----------|------|
| **파일 읽기** | 소스 코드 읽기, 설정 파일 확인 | 대부분 안전 |
| **파일 쓰기** | 코드 생성, 설정 수정, 로그 작성 | 범위에 따라 위험도 변동 |
| **셸 명령** | `npm install`, `python -m pytest` | 실행 범위 제한 필요 |
| **Git 작업** | 커밋, 브랜치 생성, push | PR 기반이면 안전 |
| **외부 API** | HTTP 요청, DB 쿼리 | 환경(prod/dev) 구분 필수 |
| **시스템 변경** | 패키지 설치, 서비스 재시작 | 높은 위험도 |
| **배포** | CI 트리거, 컨테이너 배포 | 최고 위험도 |

```bash
# Claude Code에서 허용된 도구 확인
cat .claude/settings.json | jq '.allowedTools'

# 실제 사용 내역 확인 (최근 세션 로그)
grep -r "tool_use" ~/.claude/projects/ | head -20
```

## Step 2: 위험도 분류 체계

### 4단계 위험도 등급

| 등급 | 정의 | 실행 정책 | 예시 |
|------|------|----------|------|
| **Low** | 읽기 전용, 되돌리기 쉬운 작업 | 자동 승인 | 코드 읽기, lint, 타입 체크 |
| **Medium** | 로컬 파일 변경, Git 워킹 트리 수정 | 자동 + 사후 알림 | 코드 생성, 테스트 파일 작성 |
| **High** | 외부 시스템 영향, 되돌리기 어려운 작업 | 사전 승인 필요 | PR 생성, 패키지 설치, DB 스키마 변경 |
| **Critical** | 프로덕션 영향, 비가역적 작업 | 이중 승인 + 드라이런 필수 | 프로덕션 배포, 데이터 마이그레이션 |

### 분류 기준 체크리스트

```yaml
# risk-classification.yaml
criteria:
  reversibility:
    easy: -1        # git reset으로 복구 가능
    hard: +1        # 수동 복구 필요
    impossible: +2  # 데이터 손실 가능

  scope:
    local_file: 0       # 로컬 파일만 영향
    repository: +1      # 레포 전체 영향
    external_service: +2 # 외부 서비스 영향
    production: +3       # 프로덕션 환경 영향

  data_sensitivity:
    none: 0         # 민감 데이터 없음
    config: +1      # 설정값 포함
    credentials: +3 # 시크릿/인증 정보
```

## Step 3: 권한 매트릭스 설계

### Claude Code 기준 설정 예시

```json
{
  "permissions": {
    "allow": [
      "Read(**)",
      "Edit(**)",
      "Write(*.md)",
      "Bash(npm test)",
      "Bash(npx tsc --noEmit)",
      "Bash(npx eslint .)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push origin main)",
      "Bash(npm publish)",
      "Bash(docker push *)"
    ]
  }
}
```

### 환경별 권한 차등

| 환경 | 허용 범위 | 금지 사항 |
|------|----------|----------|
| **로컬 개발** | 파일 읽기/쓰기, 테스트 실행, lint | 시스템 패키지 설치 |
| **CI/CD** | 빌드, 테스트, 정적 분석 | 프로덕션 배포 직접 트리거 |
| **스테이징** | 배포, DB 마이그레이션(드라이런) | 프로덕션 접근 |
| **프로덕션** | 로그 조회, 헬스체크 | 코드 변경, 직접 배포 |

```bash
# .claude/settings.json — 프로젝트별 권한 관리
{
  "allowedTools": [
    "Read", "Edit", "Write",
    "Bash(npm test:*)",
    "Bash(npx prettier --write *)",
    "Bash(git add:*)",
    "Bash(git commit:*)"
  ]
}
```

## Step 4: 승인 워크플로우 설계

### 승인 흐름 패턴

```
에이전트 액션 요청
    │
    ├─ Low 등급 ───────── 즉시 실행 → 로그 기록
    │
    ├─ Medium 등급 ────── 즉시 실행 → 알림 전송 → 로그 기록
    │
    ├─ High 등급 ─────── 승인 요청 → [대기] → 승인/거절 → 실행 → 로그
    │
    └─ Critical 등급 ──── 드라이런 → 결과 리뷰 → 이중 승인 → 실행 → 검증
```

### 승인 채널 설정

```yaml
# approval-config.yaml
channels:
  slack:
    webhook: "${SLACK_WEBHOOK_URL}"
    mention: "@devops-team"
    timeout_minutes: 30

  discord:
    channel_id: "${DISCORD_CHANNEL_APPROVALS}"
    buttons: true
    timeout_minutes: 30

  cli:
    prompt: true
    timeout_minutes: 5

# 타임아웃 정책
timeout_policy:
  high: "deny"      # 시간 초과 시 거절
  critical: "deny"   # 시간 초과 시 거절
  escalation: "notify_admin"
```

### 배치 승인 지원

반복적인 High 등급 작업은 배치 승인으로 처리할 수 있어요:

```bash
# 승인 대기 목록 확인
cat pending.yaml | grep "status: pending"

# 특정 카테고리 일괄 승인
# (신뢰가 쌓인 반복 작업에만 사용)
approve --category "pr_creation" --last 5
```

## Step 5: 안전 장치 구현

### 5-1. 드라이런(Dry Run) 모드

```bash
# 실제 실행 전 결과 미리 보기
claude --dry-run "이 PR을 생성해줘"

# CI에서 드라이런 강제
if [ "$AGENT_MODE" = "autonomous" ]; then
  echo "Running in dry-run first..."
  run_agent --dry-run --output /tmp/plan.md
  # 계획 검토 후 실제 실행
  review_and_execute /tmp/plan.md
fi
```

### 5-2. 롤백 전략

| 액션 유형 | 롤백 방법 | 자동화 가능 여부 |
|----------|----------|--------------|
| 파일 변경 | `git checkout -- .` | 가능 |
| 커밋 | `git reset HEAD~1` | 가능 |
| PR 생성 | PR close + 브랜치 삭제 | 가능 |
| 패키지 설치 | `npm ci` (lockfile 복원) | 가능 |
| DB 마이그레이션 | down migration | 부분 가능 |
| 프로덕션 배포 | 이전 버전 rollback | 환경에 따라 다름 |

```bash
# 에이전트 실행 전 자동 체크포인트
git stash push -m "pre-agent-$(date +%s)"

# 문제 발생 시 복원
git stash pop
```

### 5-3. 실행 제한

```yaml
# agent-limits.yaml
limits:
  max_files_per_session: 20      # 세션당 최대 파일 변경 수
  max_commands_per_minute: 10    # 분당 셸 명령 제한
  max_tokens_per_session: 100000 # 세션당 토큰 제한
  max_runtime_minutes: 60        # 최대 실행 시간
  max_retries: 3                 # 실패 시 재시도 횟수

  # 비용 제한
  max_cost_per_session: 5.00     # USD
  daily_budget: 50.00            # USD
```

## Step 6: 모니터링 & 감사 로그

### 실행 로그 구조

```yaml
# agent-execution-log.yaml
- session_id: "abc123"
  timestamp: "2026-03-22T14:03:00+09:00"
  agent: "claude-code"
  action: "Bash(git push origin feature/auth)"
  risk_level: "high"
  approval:
    required: true
    approved_by: "leo"
    approved_at: "2026-03-22T14:05:00+09:00"
  result: "success"
  rollback_available: true
```

### 주간 감사 리포트 자동화

```bash
# 주간 에이전트 활동 요약
cat agent-execution-log.yaml | python3 -c "
import sys, yaml
logs = yaml.safe_load(sys.stdin)
high = sum(1 for l in logs if l['risk_level'] in ['high','critical'])
denied = sum(1 for l in logs if l.get('result') == 'denied')
print(f'이번 주 High/Critical 액션: {high}건')
print(f'거절된 요청: {denied}건')
"
```

### 알림 설정 가이드

| 이벤트 | 알림 채널 | 긴급도 |
|--------|----------|-------|
| Low/Medium 실행 | 로그만 | - |
| High 승인 요청 | Slack/Discord | 보통 |
| Critical 승인 요청 | Slack + SMS | 높음 |
| 실행 실패 (연속 3회) | 모든 채널 | 긴급 |
| 일일 예산 80% 도달 | Slack | 보통 |
| 비정상 패턴 감지 | 모든 채널 | 높음 |

## 실전 설계 체크리스트

프로젝트에 자율 실행을 도입할 때 이 체크리스트를 따라가세요:

- [ ] 에이전트가 수행하는 모든 액션을 목록화했는가?
- [ ] 각 액션에 위험도 등급을 부여했는가?
- [ ] 환경별(dev/staging/prod) 권한을 분리했는가?
- [ ] 승인 워크플로우와 타임아웃 정책을 정의했는가?
- [ ] 드라이런 모드를 지원하는가?
- [ ] 롤백 전략이 모든 액션 유형을 커버하는가?
- [ ] 실행 제한(파일 수, 시간, 비용)을 설정했는가?
- [ ] 감사 로그를 자동으로 기록하는가?
- [ ] 비정상 패턴 알림을 구성했는가?
- [ ] 주기적 리뷰 일정을 잡았는가?

## 점진적 도입 전략

자율 실행은 한 번에 전체를 도입하기보다 단계적으로 열어가는 게 안전합니다:

| 단계 | 기간 | 자율 범위 | 모니터링 |
|------|------|----------|---------|
| **1단계** | 1~2주 | Low만 자율, 나머지 전부 수동 | 모든 액션 로깅 |
| **2단계** | 2~4주 | Medium까지 자율 + 사후 알림 | 일일 리포트 |
| **3단계** | 1~2개월 | High 선별적 자율 (반복 패턴) | 주간 감사 |
| **4단계** | 3개월+ | 패턴 기반 자동 승인 확대 | 이상 탐지 중심 |

> 💡 각 단계에서 "이 정도면 괜찮다"는 확신이 들 때까지 충분히 머무르세요. 서두르면 사고가 나고, 신뢰가 무너지면 에이전트 도입 자체가 후퇴합니다.

## 다음 단계

→ [코드베이스 온보딩 플레이북](./15-codebase-onboarding.md) — 에이전트가 레포를 파악하는 첫 단계
→ [AI 보안 감사 플레이북](./11-security-audit.md) — 자율 실행과 병행할 보안 점검

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
