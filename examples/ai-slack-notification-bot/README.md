# AI 에이전트 기반 Slack 알림 봇

> 코드 리뷰, 빌드 실패, 배포 이벤트를 Slack 채널에 맥락 있게 요약 전송하는 봇 구현 예제

## 이 예제에서 배울 수 있는 것

- GitHub Actions에서 AI 요약 알림을 Slack으로 전송하는 구조
- 빌드 실패 원인을 LLM으로 분석해 요점만 추출하는 패턴
- PR 리뷰 상태를 팀 채널에 자동으로 알리는 워크플로
- 알림 피로도를 줄이는 노이즈 필터링 전략

## 프로젝트 구조

```
ai-slack-notification-bot/
├── .github/
│   └── workflows/
│       ├── notify-build.yml      # 빌드 결과 알림
│       ├── notify-deploy.yml     # 배포 이벤트 알림
│       └── notify-review.yml     # PR 코드 리뷰 알림
├── scripts/
│   ├── summarize-build.py        # 빌드 로그 AI 요약
│   ├── summarize-review.py       # 코드 리뷰 AI 요약
│   └── send-slack.py             # Slack 메시지 전송
├── templates/
│   ├── build-failure.json        # 빌드 실패 메시지 템플릿
│   ├── deploy-success.json       # 배포 성공 메시지 템플릿
│   └── review-summary.json       # 리뷰 요약 메시지 템플릿
└── README.md
```

## 시작하기

```bash
# 레포 클론
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-slack-notification-bot

# 필요한 패키지 설치
pip install anthropic requests

# GitHub Secrets에 등록
# ANTHROPIC_API_KEY — Claude API 키
# SLACK_WEBHOOK_URL — Slack Incoming Webhook URL
# SLACK_BOT_TOKEN   — Slack Bot Token (채널별 전송 시)
```

## 핵심 코드

### 빌드 실패 AI 요약 (`scripts/summarize-build.py`)

```python
import anthropic
import os
import sys

def summarize_build_failure(log: str, pr_title: str, branch: str) -> dict:
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    message = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=400,
        messages=[
            {
                "role": "user",
                "content": f"""다음 빌드 실패 로그를 분석해서 핵심 원인과 해결 방향을 요약해줘.

PR: {pr_title}
브랜치: {branch}

로그:
{log[-3000:]}  # 마지막 3000자만 사용

응답 형식:
- 실패 원인 (1줄)
- 에러 위치 (파일:라인)
- 빠른 해결 방법 (1~2줄)"""
            }
        ]
    )

    summary = message.content[0].text

    # 구조화된 결과 파싱
    lines = summary.strip().split('\n')
    return {
        "cause": lines[0].replace("- 실패 원인:", "").strip() if lines else "파악 중",
        "location": lines[1].replace("- 에러 위치:", "").strip() if len(lines) > 1 else "",
        "fix": lines[2].replace("- 빠른 해결 방법:", "").strip() if len(lines) > 2 else ""
    }

if __name__ == "__main__":
    log = sys.stdin.read()
    pr_title = os.environ.get("PR_TITLE", "Unknown PR")
    branch = os.environ.get("BRANCH_NAME", "unknown")

    result = summarize_build_failure(log, pr_title, branch)
    print(f"CAUSE={result['cause']}")
    print(f"LOCATION={result['location']}")
    print(f"FIX={result['fix']}")
```

**왜 이렇게 했나요?**

로그 전체를 보내면 토큰이 낭비됩니다. 빌드 실패는 마지막 3000자에 원인이 모여있는 경우가 많아요. LLM에게 구조화된 응답 형식을 지정하면 파싱이 쉬워집니다.

### Slack 메시지 전송 (`scripts/send-slack.py`)

```python
import requests
import json
import os

def send_build_failure(cause: str, location: str, fix: str,
                       pr_title: str, pr_url: str, branch: str):
    webhook_url = os.environ["SLACK_WEBHOOK_URL"]

    payload = {
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "빌드 실패"
                }
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*PR*\n<{pr_url}|{pr_title}>"},
                    {"type": "mrkdwn", "text": f"*브랜치*\n`{branch}`"}
                ]
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*원인*\n{cause}\n\n*위치*\n`{location}`\n\n*빠른 해결*\n{fix}"
                }
            }
        ]
    }

    response = requests.post(webhook_url, json=payload)
    return response.status_code == 200

def send_deploy_success(service: str, version: str, env: str, changes: list[str]):
    webhook_url = os.environ["SLACK_WEBHOOK_URL"]

    changes_text = "\n".join([f"• {c}" for c in changes[:5]])

    payload = {
        "blocks": [
            {
                "type": "header",
                "text": {"type": "plain_text", "text": f"배포 완료 — {service}"}
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*버전*\n`{version}`"},
                    {"type": "mrkdwn", "text": f"*환경*\n`{env}`"}
                ]
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*주요 변경사항*\n{changes_text}"
                }
            }
        ]
    }

    requests.post(webhook_url, json=payload)
```

### GitHub Actions 워크플로 (`.github/workflows/notify-build.yml`)

```yaml
name: Build Failure Notification

on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

jobs:
  notify-failure:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Download build logs
        uses: actions/github-script@v7
        with:
          script: |
            const logs = await github.rest.actions.downloadWorkflowRunLogs({
              owner: context.repo.owner,
              repo: context.repo.repo,
              run_id: context.payload.workflow_run.id
            });
            require('fs').writeFileSync('build.log', Buffer.from(logs.data));

      - name: AI summarize
        id: summarize
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          PR_TITLE: ${{ github.event.workflow_run.name }}
          BRANCH_NAME: ${{ github.event.workflow_run.head_branch }}
        run: |
          pip install anthropic -q
          cat build.log | python3 scripts/summarize-build.py >> $GITHUB_OUTPUT

      - name: Send Slack notification
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
          CAUSE: ${{ steps.summarize.outputs.CAUSE }}
          LOCATION: ${{ steps.summarize.outputs.LOCATION }}
          FIX: ${{ steps.summarize.outputs.FIX }}
          PR_TITLE: ${{ github.event.workflow_run.display_title }}
          PR_URL: ${{ github.event.workflow_run.html_url }}
          BRANCH_NAME: ${{ github.event.workflow_run.head_branch }}
        run: |
          pip install requests -q
          python3 scripts/send-slack.py
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 빌드 실패 분석 | `이 스택 트레이스에서 근본 원인만 한 줄로 말해줘: {log}` |
| PR 변경사항 요약 | `이 diff의 핵심 변경사항을 팀 채널용으로 3줄 이내로 요약해줘` |
| 배포 위험도 평가 | `이 변경사항이 프로덕션에 미칠 영향을 낮음/중간/높음으로 평가해줘` |
| 알림 필터링 | `이 이벤트가 즉각 팀 알림이 필요한 수준인지 판단해줘: {event}` |

## 노이즈 필터링 전략

알림 피로도를 줄이는 것이 이 봇의 핵심입니다.

```python
NOTIFY_RULES = {
    "build_failure": {
        "branches": ["main", "develop", "release/*"],  # 중요 브랜치만
        "min_severity": "error",                         # warning은 생략
        "cooldown_minutes": 30                           # 같은 실패 반복 방지
    },
    "deploy": {
        "envs": ["production", "staging"],               # 개발 환경 제외
        "notify_success": True,
        "notify_failure": True
    },
    "review": {
        "min_changes": 100,                              # 소규모 수정은 생략
        "notify_approval": True,
        "notify_request_changes": True,
        "notify_comment": False                          # 단순 코멘트는 생략
    }
}
```

## 로컬 테스트

```bash
# 빌드 실패 알림 테스트
export ANTHROPIC_API_KEY="your-key"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export PR_TITLE="feat: 결제 모듈 추가"
export BRANCH_NAME="feature/payment"

cat tests/sample-build-failure.log | python3 scripts/summarize-build.py

# Slack 메시지 확인
python3 -c "
from scripts.send_slack import send_build_failure
send_build_failure(
    cause='TypeScript 컴파일 오류 — 타입 불일치',
    location='src/payment/handler.ts:47',
    fix='PaymentRequest 타입에 amount 필드 추가 필요',
    pr_title='feat: 결제 모듈 추가',
    pr_url='https://github.com/example/repo/pull/42',
    branch='feature/payment'
)
"
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
