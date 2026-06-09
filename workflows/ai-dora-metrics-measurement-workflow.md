# AI 시대 DORA 메트릭 측정 워크플로우 — AI 코드 기여 영향 추적

> AI가 코드를 대신 작성하는 시대에 팀 생산성을 정확히 측정하려면 기존 DORA 메트릭만으로 부족합니다. AI Code Share, 코드 변동률, AI PR 사이클 타임 등 새로운 지표를 자동으로 수집하고 시각화하는 워크플로우를 소개합니다.

## 왜 기존 DORA가 부족한가

2026년 기준 개발팀의 84%가 AI 코딩 도구를 사용합니다. 문제는 AI가 배포 빈도를 높이면서 동시에 코드 변동률도 높인다는 점입니다. 전통적 DORA만 보면 "배포 잘 되고 있네"처럼 보이지만, 실제로는 AI가 작성한 코드가 2-3주 안에 대거 수정되는 상황이 발생합니다.

AI 시대에는 두 가지 레이어로 나눠서 봐야 합니다:

| 레이어 | 지표 | 측정 목적 |
|--------|------|-----------|
| 기존 DORA | 배포 빈도, 리드 타임, 장애 복구 시간, 변경 실패율 | 전체 팀 배포 성과 |
| AI 확장 메트릭 | AI Code Share, AI 코드 변동률, AI PR 사이클 타임 | AI 도구 실질 효과 측정 |

## 사전 준비

- GitHub API 접근 권한 (GITHUB_TOKEN)
- Python 3.11+ 또는 Node.js 20+
- Datadog, Grafana, 또는 Metabase (선택)
- git log 접근 가능한 저장소

## Step 1: AI PR 분류 시스템 구성

먼저 AI가 작성한 PR과 사람이 작성한 PR을 구분합니다.

### 방법 1: PR 라벨 자동화 (권장)

```yaml
# .github/workflows/label-ai-prs.yml
name: Label AI-assisted PRs

on:
  pull_request:
    types: [opened, edited]

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const { data: pr } = await github.rest.pulls.get({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number
            });

            const aiPatterns = [
              /claude code/i,
              /cursor/i,
              /copilot/i,
              /ai-generated/i,
              /codex/i
            ];

            const isAI = aiPatterns.some(p =>
              p.test(pr.body || '') || p.test(pr.title)
            );

            if (isAI) {
              await github.rest.issues.addLabels({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                labels: ['ai-assisted']
              });
            }
```

### 방법 2: 커밋 트레일러 기반 분류

```bash
# Claude Code, Cursor 등은 커밋에 트레일러를 남기는 경우가 많습니다
git log --format="%H %s %b" | grep -i "co-authored-by.*claude\|co-authored-by.*cursor"
```

## Step 2: 핵심 AI 확장 메트릭 수집 스크립트

```python
# scripts/collect_ai_metrics.py
import os
import requests
from datetime import datetime, timedelta, timezone
from collections import defaultdict

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
REPO = os.environ.get("REPO", "your-org/your-repo")
DAYS = int(os.environ.get("DAYS", 30))

headers = {"Authorization": f"Bearer {GITHUB_TOKEN}"}
base = "https://api.github.com"
since = (datetime.now(timezone.utc) - timedelta(days=DAYS)).isoformat()


def fetch_prs(state="closed"):
    prs = []
    page = 1
    while True:
        res = requests.get(
            f"{base}/repos/{REPO}/pulls",
            headers=headers,
            params={"state": state, "per_page": 100, "page": page, "sort": "updated", "direction": "desc"}
        )
        data = res.json()
        if not data:
            break
        filtered = [p for p in data if p["updated_at"] > since]
        prs.extend(filtered)
        if len(filtered) < len(data):
            break
        page += 1
    return prs


def is_ai_pr(pr):
    ai_labels = {"ai-assisted", "claude-code", "cursor", "copilot"}
    pr_labels = {l["name"].lower() for l in pr.get("labels", [])}
    return bool(ai_labels & pr_labels)


def pr_cycle_time_hours(pr):
    if not pr.get("merged_at"):
        return None
    created = datetime.fromisoformat(pr["created_at"].replace("Z", "+00:00"))
    merged = datetime.fromisoformat(pr["merged_at"].replace("Z", "+00:00"))
    return (merged - created).total_seconds() / 3600


def main():
    prs = fetch_prs("closed")
    merged = [p for p in prs if p.get("merged_at")]

    ai_prs = [p for p in merged if is_ai_pr(p)]
    human_prs = [p for p in merged if not is_ai_pr(p)]

    # AI Code Share
    ai_share = len(ai_prs) / len(merged) * 100 if merged else 0

    # PR Cycle Time 비교
    ai_cycle = [t for p in ai_prs if (t := pr_cycle_time_hours(p))]
    human_cycle = [t for p in human_prs if (t := pr_cycle_time_hours(p))]

    ai_avg = sum(ai_cycle) / len(ai_cycle) if ai_cycle else 0
    human_avg = sum(human_cycle) / len(human_cycle) if human_cycle else 0

    print(f"=== AI 메트릭 리포트 (최근 {DAYS}일) ===")
    print(f"전체 머지 PR: {len(merged)}개")
    print(f"AI Code Share: {ai_share:.1f}% ({len(ai_prs)}개)")
    print(f"AI PR 평균 사이클 타임: {ai_avg:.1f}시간")
    print(f"사람 PR 평균 사이클 타임: {human_avg:.1f}시간")
    if human_avg > 0:
        ratio = ai_avg / human_avg
        print(f"AI PR이 {ratio:.1f}배 {'빠름' if ratio < 1 else '느림'}")

    return {
        "ai_code_share": ai_share,
        "ai_pr_cycle_time_avg": ai_avg,
        "human_pr_cycle_time_avg": human_avg,
        "total_merged": len(merged),
        "ai_pr_count": len(ai_prs)
    }


if __name__ == "__main__":
    main()
```

## Step 3: 코드 변동률(Code Churn) 측정

AI 코드 변동률은 AI가 작성한 코드 중 30일 이내에 수정된 비율입니다. 높을수록 AI가 "일단 돌아가는" 코드를 만들고 있다는 신호입니다.

```bash
#!/bin/bash
# scripts/measure_churn.sh
# AI 작성 파일의 변동률 측정

SINCE_DAYS=${1:-30}
SINCE=$(date -d "-${SINCE_DAYS} days" +%Y-%m-%d 2>/dev/null || date -v-${SINCE_DAYS}d +%Y-%m-%d)

# AI 커밋으로 추가된 파일 목록
git log --since="$SINCE" --grep="co-authored-by.*claude\|co-authored-by.*cursor\|ai-generated" \
  --name-only --format="" | sort -u > /tmp/ai_files.txt

# 동일 기간 수정 빈도
TOTAL_AI_FILES=$(wc -l < /tmp/ai_files.txt)
CHURNED=0

while IFS= read -r file; do
  changes=$(git log --since="$SINCE" --follow -- "$file" 2>/dev/null | grep -c "^commit" || true)
  if [ "$changes" -gt 1 ]; then
    CHURNED=$((CHURNED + 1))
  fi
done < /tmp/ai_files.txt

if [ "$TOTAL_AI_FILES" -gt 0 ]; then
  CHURN_RATE=$(echo "scale=1; $CHURNED * 100 / $TOTAL_AI_FILES" | bc)
  echo "AI 파일 변동률: ${CHURN_RATE}% (${CHURNED}/${TOTAL_AI_FILES})"
else
  echo "AI 생성 파일 없음"
fi
```

## Step 4: GitHub Actions 자동 수집 파이프라인

```yaml
# .github/workflows/ai-metrics-weekly.yml
name: Weekly AI Metrics Collection

on:
  schedule:
    - cron: '0 9 * * 1'  # 매주 월요일 9시
  workflow_dispatch:

jobs:
  collect:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install requests

      - name: Collect AI metrics
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPO: ${{ github.repository }}
          DAYS: 7
        run: python scripts/collect_ai_metrics.py > metrics_output.json

      - name: Send to webhook (optional)
        if: env.METRICS_WEBHOOK != ''
        env:
          METRICS_WEBHOOK: ${{ secrets.METRICS_WEBHOOK }}
        run: |
          curl -s -X POST "$METRICS_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d @metrics_output.json
```

## Step 5: 팀 대시보드 연동

### Datadog 연동

```python
from datadog import initialize, statsd

initialize(api_key=os.environ["DD_API_KEY"])

metrics = collect_metrics()  # Step 2 함수 호출

statsd.gauge("engineering.ai_code_share", metrics["ai_code_share"])
statsd.gauge("engineering.ai_pr_cycle_time", metrics["ai_pr_cycle_time_avg"])
statsd.gauge("engineering.human_pr_cycle_time", metrics["human_pr_cycle_time_avg"])
```

### Slack 주간 리포트

```python
import requests

def send_weekly_report(metrics, webhook_url):
    ai_share = metrics["ai_code_share"]
    ai_cycle = metrics["ai_pr_cycle_time_avg"]
    human_cycle = metrics["human_pr_cycle_time_avg"]

    diff = ((human_cycle - ai_cycle) / human_cycle * 100) if human_cycle else 0
    emoji = "🚀" if diff > 0 else "⚠️"

    requests.post(webhook_url, json={
        "text": f"""📊 *주간 AI 코딩 메트릭*
• AI Code Share: *{ai_share:.1f}%*
• AI PR 사이클 타임: *{ai_cycle:.1f}h*
• 사람 PR 사이클 타임: *{human_cycle:.1f}h*
{emoji} AI PR이 사람 PR보다 *{abs(diff):.0f}%* {'빠릅니다' if diff > 0 else '느립니다'}"""
    })
```

## 지표 해석 기준

| 지표 | 건강한 수치 | 주의 | 위험 |
|------|-----------|------|------|
| AI Code Share | 30-60% | 60-80% | 80%+ |
| AI PR 사이클 타임 | 사람의 80% 이하 | 사람과 동일 | 사람보다 느림 |
| AI 코드 변동률 | 15% 이하 | 15-30% | 30% 이상 |
| AI PR 변경 실패율 | 사람과 동일 | 사람보다 2배 | 사람보다 3배+ |

> **팁:** AI Code Share 80% 이상은 컨텍스트 부족 신호일 수 있습니다. CLAUDE.md 품질을 점검하세요.

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| AI PR 사이클 타임이 사람보다 느림 | AI 코드 리뷰 부담 | CLAUDE.md에 코드 스타일 명확화, 리뷰어 가이드 추가 |
| AI 코드 변동률 30% 이상 | 컨텍스트 부족 | 도메인 지식을 CLAUDE.md에 추가 |
| AI Code Share 급증 | 품질 게이트 없음 | CI에 자동 리뷰 게이트 추가 |
| 지표 수집 안 됨 | 라벨 미부착 | PR 라벨 자동화 GitHub Actions 확인 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
