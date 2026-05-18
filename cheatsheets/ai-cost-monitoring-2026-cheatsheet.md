# AI 에이전트 비용 모니터링 치트시트 2026 — 실시간 추적과 예산 초과 방지

> 구독료는 20달러인데 청구서는 4,200달러? 에이전트가 켜지면 비용은 10~100배 속도로 쌓인다. 한 페이지로 정리한 실시간 추적과 예산 방어 전략.

---

## 현실 파악: 2026년 AI 비용 지형

| 도구 | 월 구독 | 에이전트 사용 시 실제 지출 |
|------|---------|--------------------------|
| Cursor Pro | $20 | $80~$300 (API 오버리지 포함) |
| Claude Code Pro | $20 | $100~$250 |
| Claude Code Max | $100~$200 | 고정 (Pro 방식 대비 안정) |
| GitHub Copilot | $10~$19 | $10~$30 (채팅 중심 시 안정) |
| Gemini CLI | 사용량 기반 | $20~$150 (Gemini 3 Pro 기준) |
| API 직접 사용 | 없음 | 무제한 — 가장 위험 |

**핵심 사실**: 에이전트 모드는 채팅 대비 토큰을 50~100배 빠르게 소모한다. 파일 탐색, 툴 호출, 실패 재시도가 매번 컨텍스트를 재전송하기 때문이다.

---

## 비용 추적 방법

### 도구별 사용량 확인

```bash
# Claude Code — 현재 세션 사용량
cat ~/.claude/usage.json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'Input: {d.get(\"input_tokens\",0):,} / Output: {d.get(\"output_tokens\",0):,}')
"

# OpenAI API 사용량 (Codex CLI 사용 시)
curl -s https://api.openai.com/v1/usage \
  -H "Authorization: Bearer $OPENAI_API_KEY" | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d)"

# 월별 청구 예측 — 일간 평균으로 추정
python3 << 'EOF'
daily_cost = 8.5      # 달러 (실제 어제 지출)
days_remaining = 12   # 이번 달 남은 일수
current_month_spend = 95.0  # 이번 달 현재까지

projected = current_month_spend + (daily_cost * days_remaining)
print(f"이번 달 예상 지출: ${projected:.1f}")
EOF
```

### 간단한 비용 로그 스크립트

```bash
# ~/scripts/ai-cost-log.sh
#!/bin/bash
# 매일 23:59에 cron으로 실행

DATE=$(date +%Y-%m-%d)
LOG_FILE=~/.ai-cost/log.csv

# 헤더 생성 (최초 실행 시)
[ -f "$LOG_FILE" ] || echo "date,tool,tokens,usd" > "$LOG_FILE"

# Claude Code 사용량 기록 (예시)
claude_tokens=$(cat ~/.claude/usage.json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('total_tokens',0))
" 2>/dev/null || echo 0)

echo "$DATE,claude,$claude_tokens,$(echo "$claude_tokens * 0.000003" | bc)" >> "$LOG_FILE"

echo "[$DATE] 로그 기록 완료 — 총 ${claude_tokens} 토큰"
```

---

## 예산 알림 전략

| 임계값 | 권장 행동 |
|--------|----------|
| 월 예산의 50% 도달 | 슬랙/이메일 알림 — 현황 파악 |
| 월 예산의 80% 도달 | 비핵심 에이전트 작업 중단, 저비용 모델 전환 |
| 월 예산의 90% 도달 | 모든 경로 모델 다운그레이드 |
| 예산 초과 | 에이전트 모드 비활성화, 채팅 모드만 사용 |

### 환경변수로 일일 한도 설정

```bash
# ~/.zshrc 또는 ~/.bashrc
export AI_DAILY_BUDGET_USD=15
export AI_MONTHLY_BUDGET_USD=200

# 초과 시 경고하는 간단한 래퍼
function claude() {
  local today_spend=$(cat ~/.ai-cost/today.txt 2>/dev/null || echo 0)
  if (( $(echo "$today_spend > $AI_DAILY_BUDGET_USD" | bc -l) )); then
    echo "⚠️  오늘 AI 비용 초과: \$${today_spend} / \$${AI_DAILY_BUDGET_USD}"
    read -q "REPLY?계속하시겠어요? (y/n) " && echo
    [[ $REPLY != 'y' ]] && return 1
  fi
  command claude "$@"
}
```

---

## 비용 절감 설정

### Claude Code

```jsonc
// ~/.claude/settings.json
{
  "model": "claude-sonnet-4-5",      // 기본 모델 — Opus 대신 사용
  "maxTokens": 8192,                  // 출력 상한선 설정
  "contextWindowPercent": 70,         // 컨텍스트 70%만 사용
  "cacheEnabled": true,               // 프롬프트 캐싱 활성화 (90% 절약)
  "autoCompact": true                 // 세션 자동 압축
}
```

### Cursor

```json
// .cursor/settings.json (프로젝트별)
{
  "cursor.models.default": "claude-3-5-sonnet",
  "cursor.chat.maxTokens": 4096,
  "cursor.agent.maxSteps": 10
}
```

---

## 에이전트별 비용 특성

| 작업 유형 | 채팅 대비 토큰 배수 | 월 500회 기준 추가 비용 |
|----------|-------------------|----------------------|
| 간단한 코드 완성 | 1x | 기본 |
| 코드 리뷰 요청 | 3~5x | +$15~25 |
| 파일 탐색 + 수정 | 10~20x | +$50~100 |
| 자율 에이전트 실행 | 50~100x | +$250~500 |
| 멀티 에이전트 병렬 | 100x+ | +$500 이상 |

---

## 팀 예산 배분 가이드

```markdown
## 팀 AI 예산 템플릿 (개발자 1인당)

### 초급 (AI 도구 입문)
- 구독: $20 (Cursor Pro 또는 Copilot)
- 추가 API: $0~10
- **월 합계: $20~30**

### 중급 (일상 AI 코딩)
- 구독: $20 (Claude Code Pro)
- 추가 API: $30~50
- **월 합계: $50~70**

### 고급 (에이전트 집중 사용)
- 구독: $100~200 (Claude Code Max)
- **월 합계: $100~200 (API 오버리지 없음)**

### 주의: API 직접 사용 시
- 한도 없음 — 반드시 일일/월별 소프트 한도 설정 필수
```

---

## 흔한 비용 함정

| 함정 | 발생 원인 | 예방법 |
|------|----------|--------|
| 컨텍스트 누적 | 세션을 닫지 않고 계속 사용 | `/compact` 또는 새 세션 시작 |
| 재시도 루프 | 에이전트가 실패를 반복 | `maxSteps` 제한 설정 |
| 대용량 파일 전송 | 통째로 파일을 컨텍스트에 넣음 | 필요한 부분만 전달 |
| 멀티 에이전트 방치 | 병렬 에이전트를 끄지 않음 | 에이전트 타임아웃 설정 |
| 오버스펙 모델 | 모든 작업에 Opus 사용 | 작업 복잡도별 모델 라우팅 |

---

**관련 가이드:** [AI 코딩 에이전트 비용 최적화 플레이북](../claude-code/playbooks/38-cost-optimization-playbook.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
