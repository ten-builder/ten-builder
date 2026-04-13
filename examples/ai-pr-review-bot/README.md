# AI 에이전트 기반 GitHub PR 자동 리뷰 봇

> PR이 열릴 때마다 코드 품질, 보안 취약점, 테스트 커버리지를 자동으로 분석하고 코멘트를 남기는 GitHub Actions 봇 구현 예제

## 이 예제에서 배울 수 있는 것

- GitHub Actions에서 Claude API로 PR diff를 자동 분석하는 패턴
- 코드 품질, 보안, 테스트 커버리지를 항목별로 체계적으로 리뷰하는 구조
- PR 코멘트로 리뷰 결과를 자동 게시하는 GitHub API 활용법
- 리뷰 품질을 유지하면서 노이즈를 줄이는 필터링 전략

## 프로젝트 구조

```
ai-pr-review-bot/
├── .github/
│   └── workflows/
│       └── pr-review.yml         # PR 자동 리뷰 워크플로
├── scripts/
│   ├── review_pr.py              # PR diff 분석 및 리뷰 생성
│   ├── post_comment.py           # GitHub PR 코멘트 게시
│   └── filter_noise.py           # 사소한 리뷰 노이즈 필터링
├── prompts/
│   ├── code-quality.txt          # 코드 품질 리뷰 프롬프트
│   ├── security.txt              # 보안 취약점 검사 프롬프트
│   └── test-coverage.txt         # 테스트 커버리지 분석 프롬프트
└── README.md
```

## 시작하기

```bash
# 레포 클론
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-pr-review-bot

# 필요한 패키지 설치
pip install anthropic PyGithub

# GitHub Secrets에 등록
# ANTHROPIC_API_KEY — Claude API 키
# GH_TOKEN          — GitHub Personal Access Token (PR 코멘트 작성 권한)
```

## 핵심 코드

### GitHub Actions 워크플로 (`.github/workflows/pr-review.yml`)

```yaml
name: AI PR Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: pip install anthropic PyGithub

      - name: Run AI PR Review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GH_TOKEN: ${{ secrets.GH_TOKEN }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          REPO_NAME: ${{ github.repository }}
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: python scripts/review_pr.py
```

### PR diff 분석 및 리뷰 생성 (`scripts/review_pr.py`)

```python
import anthropic
import os
import subprocess
from post_comment import post_review_comment

def get_pr_diff() -> str:
    """PR의 변경 내용을 diff로 가져오기"""
    base_sha = os.environ["BASE_SHA"]
    head_sha = os.environ["HEAD_SHA"]
    result = subprocess.run(
        ["git", "diff", f"{base_sha}...{head_sha}", "--unified=5"],
        capture_output=True, text=True
    )
    # diff가 너무 크면 자르기 (토큰 절약)
    diff = result.stdout
    if len(diff) > 30000:
        diff = diff[:30000] + "\n\n... (이하 생략, 일부만 분석)"
    return diff

def review_pr(diff: str) -> dict:
    """Claude API로 PR 리뷰 생성"""
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    prompt = f"""다음 코드 변경사항을 리뷰해 주세요.

<diff>
{diff}
</diff>

아래 항목을 간결하게 분석하세요:

1. **코드 품질**: 가독성, 네이밍, 중복 코드, 복잡도 문제
2. **보안**: SQL 인젝션, 하드코딩된 시크릿, 입력 검증 누락 등
3. **테스트**: 테스트가 없거나 엣지 케이스가 빠진 부분
4. **개선 제안**: 리팩토링 또는 최적화할 수 있는 부분

심각도는 🔴 (블로커), 🟡 (권장), 🟢 (참고) 로 표시하세요.
문제가 없으면 "특이사항 없음"으로 표시하세요.
전체 분량은 500자 이내로 유지하세요."""

    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}]
    )
    return {"review": response.content[0].text}

def main():
    diff = get_pr_diff()
    if not diff.strip():
        print("변경사항 없음, 리뷰 스킵")
        return

    result = review_pr(diff)
    review_text = result["review"]

    # 노이즈 필터링: 모두 🟢(참고)만 있으면 코멘트 생략
    if "🔴" not in review_text and "🟡" not in review_text:
        print("사소한 참고 사항만 있어 코멘트 생략")
        return

    comment = f"## AI 코드 리뷰\n\n{review_text}\n\n---\n_자동 분석 결과입니다. 최종 판단은 리뷰어가 직접 해주세요._"
    post_review_comment(comment)

if __name__ == "__main__":
    main()
```

### GitHub PR 코멘트 게시 (`scripts/post_comment.py`)

```python
from github import Github
import os

def post_review_comment(body: str) -> None:
    """PR에 리뷰 코멘트 게시"""
    token = os.environ["GH_TOKEN"]
    repo_name = os.environ["REPO_NAME"]
    pr_number = int(os.environ["PR_NUMBER"])

    gh = Github(token)
    repo = gh.get_repo(repo_name)
    pr = repo.get_pull(pr_number)

    # 기존 봇 코멘트가 있으면 업데이트, 없으면 새로 생성
    bot_comment = None
    for comment in pr.get_issue_comments():
        if "## AI 코드 리뷰" in comment.body:
            bot_comment = comment
            break

    if bot_comment:
        bot_comment.edit(body)
        print(f"PR #{pr_number} 리뷰 코멘트 업데이트 완료")
    else:
        pr.create_issue_comment(body)
        print(f"PR #{pr_number} 리뷰 코멘트 생성 완료")
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 보안 집중 리뷰 | `"이 diff에서 OWASP Top 10 취약점 위주로 검사해 주세요"` |
| 아키텍처 리뷰 | `"레이어 간 의존성 방향이 올바른지, SOLID 원칙 위반이 있는지 확인해 주세요"` |
| 리뷰 요약 | `"전체 리뷰를 한 문단으로 요약하고, 머지 가능 여부를 판단해 주세요"` |
| 특정 파일만 | `"*.test.ts 파일을 제외한 변경사항만 분석해 주세요"` |

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `max_tokens` | 1024 | 리뷰 최대 길이 |
| diff 크기 제한 | 30,000자 | 초과 시 앞부분만 분석 |
| 노이즈 필터 | 🟢 만 있으면 스킵 | 필요시 제거 |
| 모델 | claude-sonnet-4-5 | 비용↓ 원하면 haiku |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 리뷰 코멘트가 안 올라감 | GH_TOKEN에 `pull-requests: write` 권한 확인 |
| diff가 너무 길어 분석 누락 | 크기 제한 줄이거나 파일별로 분할 분석 |
| 매 커밋마다 중복 코멘트 | `post_comment.py`의 기존 코멘트 업데이트 로직 확인 |
| 속도가 느림 | `claude-haiku-4-5` 모델로 교체 |

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
