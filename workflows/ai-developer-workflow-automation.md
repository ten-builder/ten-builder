# AI 에이전트 기반 개발자 일상 워크플로우 자동화

> 코드 리뷰·온콜·스프린트 기획 등 반복적인 개발 업무를 AI 에이전트로 줄이고, 실제 코딩 시간을 확보하는 실전 워크플로우

## 개요

2026년 개발자 설문에 따르면 주간 업무 시간의 38%가 AI 생성 코드 리뷰에 쓰이고 있어요. 코드를 직접 짜는 시간보다 오히려 관리 업무가 늘어나는 역설이 생겼죠.

이 워크플로우는 코드 리뷰 요약, 스프린트 기획 초안, 온콜 알림 트리아지, 릴리스 노트 작성 등 반복되는 네 가지 개발 업무를 AI 에이전트로 처리하는 방법을 다뤄요.

## 사전 준비

- Claude Code 또는 Gemini CLI 설치
- GitHub CLI (`gh`) 인증
- 프로젝트에 `CLAUDE.md` 파일 존재
- 팀 Slack 또는 Discord Webhook URL (알림용)

## Step 1: PR 리뷰 요약 자동화

하루에 열리는 PR이 많을 때 AI가 각 PR의 변경 요약과 리뷰 포인트를 먼저 정리해 주면 리뷰 시간이 크게 줄어요.

### GitHub Actions 설정

```yaml
# .github/workflows/pr-summary.yml
name: PR Summary

on:
  pull_request:
    types: [opened, ready_for_review]

jobs:
  summarize:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate PR Summary
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          DIFF=$(git diff origin/main...HEAD --stat)
          FILES=$(git diff origin/main...HEAD --name-only | head -20)
          
          SUMMARY=$(curl -s https://api.anthropic.com/v1/messages \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "{
              \"model\": \"claude-sonnet-4-5\",
              \"max_tokens\": 500,
              \"messages\": [{
                \"role\": \"user\",
                \"content\": \"다음 PR 변경사항을 한국어로 3줄 요약하고 리뷰 시 주의점 2가지를 알려줘:\n\n파일 통계:\n$DIFF\n\n변경 파일:\n$FILES\"
              }]
            }" | python3 -c "import json,sys; print(json.load(sys.stdin)['content'][0]['text'])")
          
          gh pr comment ${{ github.event.pull_request.number }} \
            --body "## 자동 리뷰 요약\n\n$SUMMARY"
```

### CLAUDE.md에 리뷰 규칙 추가

```markdown
## PR Review Checklist
- 단위 테스트 커버리지 70% 이상
- API 변경 시 하위 호환성 확인
- 환경변수 하드코딩 여부 체크
- SQL N+1 쿼리 패턴 확인
```

## Step 2: 온콜 알림 트리아지 자동화

새벽에 울리는 알림 중 실제로 즉시 대응이 필요한 것은 20%가 안 되는 경우가 많아요. AI가 심각도를 분류해서 불필요한 호출을 줄일 수 있어요.

```python
# oncall_triage.py
import anthropic
import json

def triage_alert(alert_data: dict) -> dict:
    """온콜 알림 심각도 분류 및 초기 대응 제안"""
    client = anthropic.Anthropic()
    
    alert_summary = f"""
    서비스: {alert_data.get('service')}
    에러 메시지: {alert_data.get('message')}
    발생 시각: {alert_data.get('timestamp')}
    영향 사용자 수: {alert_data.get('affected_users', 0)}
    최근 배포: {alert_data.get('last_deploy', '없음')}
    """
    
    response = client.messages.create(
        model="claude-haiku-4-5",  # 비용 절감을 위해 빠른 모델 사용
        max_tokens=300,
        messages=[{
            "role": "user",
            "content": f"""다음 온콜 알림을 분석해서 JSON으로 응답해줘:
1. severity: critical/high/medium/low
2. immediate_action: 지금 당장 해야 할 일 1줄
3. can_wait: 아침까지 기다려도 되는지 (true/false)

알림 정보:
{alert_summary}"""
        }]
    )
    
    return json.loads(response.content[0].text)


# 사용 예시
alert = {
    "service": "payment-api",
    "message": "DB 연결 타임아웃 빈발 (5분간 12건)",
    "timestamp": "2026-05-22T03:15:00Z",
    "affected_users": 45,
    "last_deploy": "2026-05-22T01:30:00Z"
}

result = triage_alert(alert)
# {"severity": "high", "immediate_action": "최근 배포와 DB 연결 풀 설정 확인", "can_wait": false}
```

### 심각도별 알림 라우팅

| 심각도 | 대응 | 담당자 호출 |
|--------|------|-------------|
| critical | 즉시 | 온콜 담당자 + 리드 |
| high | 30분 내 | 온콜 담당자만 |
| medium | 업무 시간 내 | 슬랙 채널 알림 |
| low | 다음 스프린트 | 티켓 자동 생성 |

## Step 3: 스프린트 기획 초안 자동화

스프린트 기획 전에 AI가 이슈 목록을 분석해서 우선순위 초안과 예상 소요 시간을 제안하면 기획 회의 시간을 줄일 수 있어요.

```bash
#!/bin/bash
# sprint_plan.sh — 다음 스프린트 기획 초안 생성

GH_REPO="your-org/your-repo"
SPRINT_CAPACITY=40  # 팀 스프린트 가용 시간 (시간)

# 백로그 이슈 수집
ISSUES=$(gh api "repos/$GH_REPO/issues?state=open&labels=backlog&per_page=20" \
  --jq '[.[] | {number: .number, title: .title, labels: [.labels[].name]}]')

# AI로 스프린트 계획 초안 생성
PLAN=$(cat << EOF | python3 sprint_ai.py
{
  "issues": $ISSUES,
  "capacity_hours": $SPRINT_CAPACITY,
  "goal": "안정성 개선과 성능 최적화"
}
EOF
)

echo "$PLAN" | gh issue create \
  --title "[Sprint Draft] $(date +%Y-%m-%d) 스프린트 기획 초안" \
  --body "$PLAN" \
  --label "sprint-planning"
```

```python
# sprint_ai.py
import anthropic, json, sys

data = json.load(sys.stdin)
client = anthropic.Anthropic()

response = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=1000,
    messages=[{
        "role": "user",
        "content": f"""다음 백로그 이슈들로 스프린트 계획 초안을 작성해줘.
총 가용 시간: {data['capacity_hours']}h
스프린트 목표: {data['goal']}

이슈 목록:
{json.dumps(data['issues'], ensure_ascii=False, indent=2)}

출력 형식:
1. 우선순위 TOP 5 이슈 (각 이슈당 예상 시간 포함)
2. 이번 스프린트에서 제외할 이유가 있는 이슈
3. 주의가 필요한 의존성
"""
    }]
)

print(response.content[0].text)
```

## Step 4: 릴리스 노트 자동 생성

머지된 PR 목록에서 사용자 관점의 릴리스 노트를 자동으로 만들어요.

```bash
#!/bin/bash
# release_notes.sh

PREV_TAG=${1:-$(git describe --tags --abbrev=0 HEAD^)}
CURR_TAG=${2:-HEAD}

# 머지된 PR 제목 수집
COMMITS=$(git log "$PREV_TAG..$CURR_TAG" --merges \
  --pretty=format:"%s" | grep -v "Merge branch")

# AI로 사용자 관점 릴리스 노트 생성
cat << PROMPT | curl -s -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d @- | python3 -c "import json,sys; print(json.load(sys.stdin)['content'][0]['text'])"
{
  "model": "claude-sonnet-4-5",
  "max_tokens": 600,
  "messages": [{
    "role": "user",
    "content": "다음 커밋 목록을 사용자가 이해하기 쉬운 한국어 릴리스 노트로 변환해줘. 기술적 세부사항 대신 사용자 영향 중심으로 작성해:\n\n$COMMITS"
  }]
}
PROMPT
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| AI 요약을 검증 없이 공유 | 중요 PR은 요약 후 직접 확인 |
| 온콜 트리아지를 너무 신뢰 | critical 알림은 항상 사람이 최종 판단 |
| 릴리스 노트에 보안 이슈 노출 | CVE 관련 커밋은 수동으로 별도 처리 |
| 스프린트 초안을 그대로 확정 | 팀 회의에서 맥락 추가 후 확정 |

## 적용 효과 기대치

- 코드 리뷰 준비 시간 **40~50% 감소** (PR 요약으로 우선순위 파악)
- 온콜 불필요 호출 **20~30% 감소** (low/medium 알림 자동 분류)
- 스프린트 기획 회의 **30분 단축** (초안 준비 시간 제거)
- 릴리스 노트 작성 **80% 자동화** (커밋 → 노트 변환)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
