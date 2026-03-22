# 가이드 29: AI 코딩 에이전트 옵저버빌리티 실전 가이드

> AI 에이전트가 코드를 짜는 건 좋은데, 얼마나 쓰고 있는지 모르면 곤란해요. 토큰 사용량, 비용, 세션 로그를 추적하는 실전 방법을 정리합니다.

## 이 가이드가 필요한 경우

- AI 코딩 도구 월 청구서가 예상보다 높을 때
- 어떤 작업에 토큰이 얼마나 소비되는지 감이 안 잡힐 때
- 에이전트 세션이 실패하는 패턴을 분석하고 싶을 때
- 팀에서 AI 도구 사용 현황을 리포팅해야 할 때

## 핵심 원칙: 측정하지 않으면 개선할 수 없다

AI 코딩 도구는 편리하지만, 무한정 무료가 아니에요. Claude Code, Cursor, Codex 모두 토큰 또는 구독 기반 과금이고, 사용 패턴에 따라 비용 차이가 10배까지 벌어져요.

| 추적 대상 | 왜 중요한가 | 측정 방법 |
|-----------|-------------|-----------|
| 토큰 사용량 | 비용의 직접적 원인 | API 로그, 세션 통계 |
| 세션 시간 | 에이전트 효율성 지표 | 세션 메타데이터 |
| 실패율 | 재시도 비용 + 시간 낭비 | 에러 로그 분석 |
| 컨텍스트 크기 | 토큰 절약의 핵심 | 입력 토큰 추적 |
| 도구 호출 횟수 | MCP/도구 병목 발견 | 도구별 호출 로그 |

## Step 1: Claude Code 사용량 추적

Claude Code는 세션별 토큰 통계를 제공해요. 이걸 체계적으로 수집하면 패턴이 보입니다.

### 세션 기본 통계 확인

```bash
# 현재 세션 통계 확인
claude --print-stats

# 세션 로그 디렉토리
ls ~/.claude/sessions/

# 특정 세션의 상세 정보
cat ~/.claude/sessions/<session-id>/metadata.json | jq '{
  total_input_tokens: .totalInputTokens,
  total_output_tokens: .totalOutputTokens,
  duration_minutes: (.durationMs / 60000 | floor),
  tool_calls: .toolCallCount
}'
```

### 일일 사용량 집계 스크립트

```bash
#!/bin/bash
# daily-usage.sh — 오늘 사용한 Claude Code 세션 요약

TODAY=$(date +%Y-%m-%d)
TOTAL_INPUT=0
TOTAL_OUTPUT=0
SESSION_COUNT=0

for session in ~/.claude/sessions/*/metadata.json; do
  created=$(jq -r '.createdAt // empty' "$session" 2>/dev/null)
  [[ "$created" == "$TODAY"* ]] || continue
  
  input=$(jq '.totalInputTokens // 0' "$session")
  output=$(jq '.totalOutputTokens // 0' "$session")
  TOTAL_INPUT=$((TOTAL_INPUT + input))
  TOTAL_OUTPUT=$((TOTAL_OUTPUT + output))
  SESSION_COUNT=$((SESSION_COUNT + 1))
done

echo "=== $TODAY Claude Code 사용 요약 ==="
echo "세션 수: $SESSION_COUNT"
echo "입력 토큰: $(printf '%\,d' $TOTAL_INPUT)"
echo "출력 토큰: $(printf '%\,d' $TOTAL_OUTPUT)"
echo "예상 비용: \$$(echo "scale=2; ($TOTAL_INPUT * 0.003 + $TOTAL_OUTPUT * 0.015) / 1000" | bc)"
```

## Step 2: 비용 최적화 패턴 분석

### 토큰 소비 Top 5 확인

어떤 작업 유형이 토큰을 가장 많이 먹는지 파악하면 절약 포인트가 보여요.

| 작업 유형 | 평균 토큰 | 비용 효율 팁 |
|-----------|-----------|--------------|
| 코드베이스 온보딩 | 50K~200K | CLAUDE.md로 컨텍스트 사전 제공 |
| 대규모 리팩토링 | 30K~100K | 파일 단위로 나눠서 처리 |
| 테스트 생성 | 10K~40K | 템플릿 제공으로 토큰 절약 |
| 버그 수정 | 5K~20K | 에러 로그를 직접 붙여넣기 |
| 문서 작성 | 5K~15K | 기존 예시를 참조로 제공 |

### 컨텍스트 크기 관리

```bash
# 프로젝트의 토큰 크기 추정 (1 토큰 ≈ 4자)
find . -name '*.ts' -o -name '*.py' | xargs wc -c | tail -1 | awk '{printf "예상 토큰: %d\n", $1/4}'

# .claudeignore로 불필요한 파일 제외
cat > .claudeignore << 'EOF'
node_modules/
dist/
build/
*.lock
*.min.js
coverage/
.next/
EOF
```

## Step 3: 세션 실패 패턴 모니터링

에이전트가 실패하는 패턴을 알면 시간과 토큰을 모두 절약할 수 있어요.

### 흔한 실패 유형과 대응

| 실패 패턴 | 증상 | 대응 방법 |
|-----------|------|-----------|
| 컨텍스트 초과 | "context window exceeded" | 파일 분할, `.claudeignore` 강화 |
| 무한 루프 | 같은 수정을 반복 | 명확한 종료 조건 프롬프트 |
| 도구 타임아웃 | MCP 서버 응답 없음 | 타임아웃 설정, 헬스체크 추가 |
| 권한 오류 | 파일 쓰기/명령 실행 거부 | 사전 권한 설정 확인 |
| 잘못된 경로 참조 | 존재하지 않는 파일 수정 시도 | CLAUDE.md에 디렉토리 구조 명시 |

### 에러 로그 자동 수집

```bash
#!/bin/bash
# error-collector.sh — 실패한 세션에서 에러 패턴 추출

ERROR_LOG="$HOME/.claude/error-analysis.log"
echo "=== $(date +%Y-%m-%d) 에러 분석 ===" >> "$ERROR_LOG"

for session in ~/.claude/sessions/*/; do
  meta="$session/metadata.json"
  [ -f "$meta" ] || continue
  
  status=$(jq -r '.status // "unknown"' "$meta")
  [ "$status" = "error" ] || [ "$status" = "failed" ] || continue
  
  error_msg=$(jq -r '.lastError // "N/A"' "$meta")
  tokens=$(jq '.totalInputTokens // 0' "$meta")
  
  echo "세션: $(basename $session)" >> "$ERROR_LOG"
  echo "  에러: $error_msg" >> "$ERROR_LOG"
  echo "  낭비 토큰: $tokens" >> "$ERROR_LOG"
done
```

## Step 4: 팀 사용 현황 대시보드

### 주간 리포트 생성

팀에서 AI 코딩 도구를 쓰고 있다면, 주간 사용 현황 리포트가 필수예요.

```bash
#!/bin/bash
# weekly-report.sh — 주간 AI 코딩 사용 현황

WEEK_START=$(date -v-7d +%Y-%m-%d)
echo "# AI 코딩 도구 주간 리포트 ($WEEK_START ~ $(date +%Y-%m-%d))"
echo ""

# Claude Code
echo "## Claude Code"
echo "| 지표 | 값 |"
echo "|------|-----|"

total_sessions=0
total_tokens=0
for session in ~/.claude/sessions/*/metadata.json; do
  created=$(jq -r '.createdAt // empty' "$session" 2>/dev/null)
  [[ "$created" > "$WEEK_START" ]] || continue
  total_sessions=$((total_sessions + 1))
  tokens=$(jq '(.totalInputTokens // 0) + (.totalOutputTokens // 0)' "$session")
  total_tokens=$((total_tokens + tokens))
done

echo "| 총 세션 | $total_sessions |"
echo "| 총 토큰 | $(printf '%\,d' $total_tokens) |"
echo "| 세션당 평균 토큰 | $(( total_tokens / (total_sessions > 0 ? total_sessions : 1) )) |"
echo ""

# Cursor (설정 파일 기반 추정)
echo "## Cursor"
echo "- 구독 플랜 확인: Settings > Subscription"
echo "- Fast Request 사용량: Settings > Usage"
echo ""

# 비용 요약
echo "## 예상 비용"
echo "| 도구 | 월 예상 |"
echo "|------|---------|"
echo "| Claude Code (API) | \$$(echo "scale=0; $total_tokens * 4 * 0.009 / 1000" | bc) |"
echo "| Cursor Pro | \$20 (고정) |"
echo "| Codex CLI | API 종량제 |"
```

## Step 5: 자동 알림 설정

비용이 임계값을 넘거나, 에러가 연속 발생하면 즉시 알림을 받으세요.

### 토큰 예산 초과 경고

```bash
#!/bin/bash
# budget-alert.sh — 일일 토큰 예산 초과 시 알림

DAILY_BUDGET=500000  # 일일 토큰 예산
TODAY=$(date +%Y-%m-%d)
TOTAL=0

for session in ~/.claude/sessions/*/metadata.json; do
  created=$(jq -r '.createdAt // empty' "$session" 2>/dev/null)
  [[ "$created" == "$TODAY"* ]] || continue
  tokens=$(jq '(.totalInputTokens // 0) + (.totalOutputTokens // 0)' "$session")
  TOTAL=$((TOTAL + tokens))
done

if [ $TOTAL -gt $DAILY_BUDGET ]; then
  echo "주의: 오늘 토큰 사용량 $(printf '%\,d' $TOTAL)이 예산 $(printf '%\,d' $DAILY_BUDGET)을 초과했어요"
  # 웹훅, 이메일, 슬랙 알림 등 연동 가능
fi
```

### Claude Code Hooks로 실시간 추적

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "command": "echo \"$(date +%H:%M:%S) tool=$TOOL_NAME\" >> ~/.claude/tool-usage.log"
      }
    ],
    "SessionEnd": [
      {
        "matcher": ".*",
        "command": "bash ~/.claude/scripts/session-summary.sh"
      }
    ]
  }
}
```

## 실전 체크리스트

- [ ] `.claudeignore` 설정으로 불필요한 컨텍스트 제거
- [ ] 일일 사용량 집계 스크립트 크론 등록
- [ ] 주간 리포트 자동 생성 설정
- [ ] 토큰 예산 알림 임계값 설정
- [ ] 실패 세션 에러 패턴 주간 분석
- [ ] 팀 공유용 대시보드 구축 (선택)

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| 사용량 추적 없이 도구 도입 | 도입 첫 주부터 메트릭 수집 시작 |
| 전체 코드베이스를 매번 컨텍스트로 | `.claudeignore` + CLAUDE.md로 최적화 |
| 실패한 세션을 그냥 재시도 | 에러 원인 분석 후 프롬프트 수정 |
| 구독제만 쓰고 API가 더 싼 케이스 무시 | 월 사용량 기준으로 플랜 비교 |
| 팀원별 사용량 차이를 무시 | 베스트 프랙티스 공유 세션 운영 |

## 다음 단계

→ [비용 최적화 가이드](14-cost-optimization.md) — 토큰 절약 전략 상세

→ [하네스 엔지니어링 가이드](13-harness-engineering.md) — CLAUDE.md 최적화로 컨텍스트 줄이기

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) — 매주 AI 코딩 실전 팁을 받아보세요
