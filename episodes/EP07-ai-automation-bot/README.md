# EP07: AI 자동화 봇 — 개발자의 24시간 비서 만들기

> 크론 스케줄링, 콘텐츠 파이프라인, 모니터링까지 직접 구축하는 AI 자동화 실전 가이드

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- AI 에이전트를 정기적으로 실행하는 크론 스케줄링 패턴
- 리서치 → 콘텐츠 생성 → PR 생성까지 이어지는 자동화 파이프라인
- 에러 감지와 자동 복구로 안정적인 봇 운영하기
- 실제 운영 중인 자동화 봇의 설정 파일과 코드

## 왜 AI 자동화 봇인가

AI 코딩 도구를 매번 수동으로 실행하는 건 비효율적이에요. 반복되는 작업이 있다면 봇으로 만들어서 자동으로 돌리는 게 맞아요.

예를 들면 이런 작업들이에요:

| 수동 작업 | 자동화 후 |
|-----------|-----------|
| 매일 뉴스 검색해서 정리 | 크론으로 4시간마다 수집 → 요약 |
| PR이 머지되면 README 업데이트 | 머지 감지 → 자동 동기화 PR |
| 새 콘텐츠 아이디어 리서치 | 주 1회 트렌드 검색 → 후보 생성 |
| 채널 구독자 수 확인 | 매시간 API 호출 → 로그 기록 |

한 번 만들어두면 사람이 자는 동안에도 봇이 일해요.

## 핵심 아키텍처

AI 자동화 봇은 크게 3개 계층으로 나뉘어요.

```
┌─────────────────────────────────────────────┐
│  스케줄러 (Cron / Event Trigger)             │
│  → "언제 실행할 것인가"                       │
├─────────────────────────────────────────────┤
│  파이프라인 (Research → Generate → Push)      │
│  → "무엇을 할 것인가"                         │
├─────────────────────────────────────────────┤
│  상태 관리 (State / Catalog / Log)            │
│  → "어디까지 했는가"                           │
└─────────────────────────────────────────────┘
```

### 1계층: 스케줄러

크론 표현식으로 실행 주기를 정해요.

```bash
# 매시간 3분에 실행
3 * * * * /path/to/run-bot.sh

# 4시간마다 실행
0 */4 * * * /path/to/radar-bot.sh

# 매일 오전 9시에 실행
0 9 * * * /path/to/daily-digest.sh

# 매주 토요일 오전 10시에 실행
0 10 * * 6 /path/to/weekly-report.sh
```

OpenClaw 같은 에이전트 런타임을 쓰면 크론 설정이 더 간단해져요:

```yaml
# 크론 작업 정의 예시
schedule:
  kind: cron
  expr: "3 * * * *"
  tz: Asia/Seoul

payload:
  kind: agentTurn
  message: "콘텐츠 파이프라인을 실행해줘"

sessionTarget: isolated
```

### 2계층: 파이프라인

자동화 봇의 실제 작업 흐름이에요. 콘텐츠 생성 봇을 예로 들면:

```
Phase 0: 토픽 보충 (카탈로그 소진 시)
  ↓
Phase 1: 사전 점검 (에러 횟수, 카탈로그 잔량)
  ↓
Phase 2: 토픽 선정 (우선순위, 쿨다운 체크)
  ↓
Phase 3: 리서치 (검색 API 호출)
  ↓
Phase 4: 콘텐츠 생성 (템플릿 기반)
  ↓
Phase 5: 품질 검증 (포맷, 분량, 중복)
  ↓
Phase 6: PR 생성 + 알림
```

각 단계가 독립적이라서, 중간에 실패하면 해당 단계에서 멈추고 다음 실행에서 이어가요.

### 3계층: 상태 관리

봇이 "지금 어디까지 했는지" 기억하는 게 핵심이에요.

```yaml
# state.yaml — 봇 실행 상태
last_run: "2026-03-18T09:03:00"
last_success: "2026-03-18T09:03:00"
last_category: episode
consecutive_errors: 0
total_pushes: 60
```

## 따라하기: 콘텐츠 자동화 봇

### Step 1: 상태 파일 구조 만들기

봇이 사용할 파일 3개를 준비해요.

```bash
mkdir -p ~/.bot/output

# 실행 상태 파일
cat > ~/.bot/output/state.yaml << 'EOF'
last_run: null
last_success: null
last_category: null
consecutive_errors: 0
total_pushes: 0
EOF

# 토픽 카탈로그
cat > ~/.bot/output/catalog.yaml << 'EOF'
topics:
  - id: topic-001
    category: guide
    title: "첫 번째 가이드"
    file_path: guides/first-guide.md
    status: pending
    priority: 1
    search_keywords:
      - "keyword 1"
      - "keyword 2"
EOF

# 실행 로그
cat > ~/.bot/output/push-log.yaml << 'EOF'
# PR 생성 이력
EOF
```

### Step 2: 사전 점검 스크립트

실행 전에 안전 장치부터 확인해요.

```bash
#!/bin/bash
# pre-check.sh — 사전 점검

STATE_FILE="$HOME/.bot/output/state.yaml"

# 연속 에러 확인
ERRORS=$(grep 'consecutive_errors' "$STATE_FILE" | awk '{print $2}')
if [ "$ERRORS" -ge 3 ]; then
  echo "연속 에러 ${ERRORS}회 — 수동 점검 필요"
  exit 1
fi

# pending 토픽 존재 여부
PENDING=$(grep -c 'status: pending' "$HOME/.bot/output/catalog.yaml")
if [ "$PENDING" -eq 0 ]; then
  echo "카탈로그 소진 — 토픽 보충 필요"
  exit 1
fi

echo "사전 점검 통과 — pending ${PENDING}개"
```

### Step 3: 리서치 함수

검색 API를 호출해서 최신 정보를 가져와요.

```bash
#!/bin/bash
# research.sh — Tavily 검색 래퍼

search_topic() {
  local query="$1"
  local api_key="$TAVILY_API_KEY"

  curl -s -X POST "https://api.tavily.com/search" \
    -H "Content-Type: application/json" \
    -d "{
      \"api_key\": \"${api_key}\",
      \"query\": \"${query}\",
      \"search_depth\": \"advanced\",
      \"max_results\": 5,
      \"include_answer\": true
    }" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('=== 요약 ===')
print(data.get('answer', 'N/A'))
print()
print('=== 소스 ===')
for r in data.get('results', [])[:3]:
    print(f\"- {r['title']}\")
"
}

# 사용 예시
search_topic "AI coding automation workflow 2026"
```

### Step 4: PR 기반 배포

생성된 콘텐츠는 항상 PR로 올려요. main에 직접 push하면 안 돼요.

```bash
#!/bin/bash
# deploy.sh — PR 기반 콘텐츠 배포

REPO_DIR="$HOME/projects/my-repo"
CATEGORY="guide"
SLUG="my-new-guide"
FILE_PATH="guides/my-new-guide.md"

cd "$REPO_DIR"

# main 최신화
git checkout main
git pull origin main

# 토픽별 브랜치 생성
BRANCH="content/${CATEGORY}-${SLUG}"
git checkout -b "$BRANCH"

# 콘텐츠 커밋
git add "$FILE_PATH"
git commit -m "content(${CATEGORY}): add ${SLUG}"
git push origin HEAD

# PR 생성
PR_URL=$(gh pr create \
  --title "content(${CATEGORY}): ${SLUG}" \
  --body "## Summary
- **카테고리:** ${CATEGORY}
- **파일:** \`${FILE_PATH}\`")

echo "PR 생성 완료: $PR_URL"

# main 복귀
git checkout main
```

### Step 5: 에러 핸들링

봇이 실패했을 때 자동으로 복구하는 패턴이에요.

```bash
#!/bin/bash
# error-handler.sh — 에러 처리

handle_error() {
  local error_msg="$1"
  local state_file="$HOME/.bot/output/state.yaml"

  # 연속 에러 카운트 증가
  current=$(grep 'consecutive_errors' "$state_file" | awk '{print $2}')
  new_count=$((current + 1))

  # state 업데이트
  sed -i '' "s/consecutive_errors: .*/consecutive_errors: ${new_count}/" "$state_file"

  # 3회 이상이면 알림
  if [ "$new_count" -ge 3 ]; then
    echo "연속 에러 ${new_count}회 — 자동 정지"
    # 여기에 알림 로직 추가 (webhook, 이메일 등)
  fi
}

handle_success() {
  local state_file="$HOME/.bot/output/state.yaml"

  # 에러 카운트 리셋
  sed -i '' "s/consecutive_errors: .*/consecutive_errors: 0/" "$state_file"

  # 마지막 성공 시각 업데이트
  local now=$(date -u +"%Y-%m-%dT%H:%M:%S")
  sed -i '' "s/last_success: .*/last_success: \"${now}\"/" "$state_file"
}
```

## 모니터링 패턴

봇이 잘 돌아가는지 확인하는 3가지 방법이에요.

### 하트비트 체크

```bash
# 마지막 실행이 2시간 이상 전이면 알림
LAST_RUN=$(grep 'last_run' state.yaml | cut -d'"' -f2)
LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_RUN" +%s 2>/dev/null)
NOW_EPOCH=$(date +%s)
DIFF=$(( (NOW_EPOCH - LAST_EPOCH) / 3600 ))

if [ "$DIFF" -gt 2 ]; then
  echo "봇이 ${DIFF}시간째 응답 없음"
fi
```

### 성공률 추적

```bash
# push-log.yaml에서 최근 10건의 성공/실패 비율
TOTAL=$(grep -c 'topic_id:' push-log.yaml)
echo "총 ${TOTAL}건 생성 완료"
```

### 카탈로그 잔량 경고

```bash
# pending 토픽이 3개 미만이면 보충 필요
PENDING=$(grep -c 'status: pending' catalog.yaml)
if [ "$PENDING" -lt 3 ]; then
  echo "카탈로그 잔량 부족: ${PENDING}개 — 보충 필요"
fi
```

## 실전 팁

### 쿨다운으로 중복 방지

같은 카테고리 콘텐츠가 연속으로 나오면 단조로워져요. 카테고리별 24시간 쿨다운을 두면 자연스럽게 다양한 콘텐츠가 나와요.

```yaml
# 쿨다운 체크 로직
last_category: playbook
last_success: "2026-03-18T08:00:00"

# 현재 시각이 last_success + 24h 이내이면
# playbook 카테고리 건너뛰기
```

### 카탈로그 자동 보충

pending 토픽이 3개 미만이면 트렌드 검색으로 새 후보를 자동 생성해요. 주 1회 쿨다운을 두면 과도한 생성을 막을 수 있어요.

### 독립 PR 원칙

토픽 1개 = PR 1개를 지키면 리뷰가 쉬워요. 마음에 안 드는 콘텐츠는 해당 PR만 닫으면 돼요.

## 주의사항

| 항목 | 권장 |
|------|------|
| 연속 에러 한계 | 3회 초과 시 자동 정지 |
| API 호출 제한 | 실행당 최대 5회 |
| 콘텐츠 최소 분량 | 500자 이상 |
| 브랜치 전략 | 토픽별 독립 브랜치 |
| 머지 방식 | 항상 PR 기반 (main 직접 push 금지) |

## 전체 프로젝트 구조

```
~/.bot/
├── output/
│   ├── state.yaml          # 실행 상태
│   ├── catalog.yaml        # 토픽 카탈로그
│   └── push-log.yaml       # PR 생성 이력
├── scripts/
│   ├── pre-check.sh        # 사전 점검
│   ├── research.sh         # 리서치
│   ├── deploy.sh           # PR 배포
│   └── error-handler.sh    # 에러 처리
└── config/
    └── schedule.yaml       # 크론 설정
```

## 더 알아보기

- [AI 에이전트 감독 워크플로우](../../workflows/ai-agent-supervision.md)
- [AI 세션 메모리 관리 워크플로우](../../workflows/ai-session-memory-management.md)
- [AI 에이전트 파이프라인 워크플로우](../../workflows/ai-agent-pipeline.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
