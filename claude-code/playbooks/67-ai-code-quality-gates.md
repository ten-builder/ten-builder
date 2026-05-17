# 플레이북 67: AI 에이전트 코드 생성 품질 게이트 자동화

> AI가 만든 코드를 또 다른 AI가 검증한다 — 소프트웨어 품질의 새로운 기준

## 소요 시간

30-45분

## 사전 준비

- GitHub Actions 또는 CI/CD 파이프라인 환경
- Claude API 키 또는 Claude Code 설치
- 테스트 프레임워크 (Jest, pytest 등)
- `gh` CLI 설치 (PR 연동 시)

## 왜 AI 코드에는 별도 품질 게이트가 필요한가

AI 코딩 에이전트는 기능 구현 속도를 크게 높여준다. 하지만 한 가지 구조적 문제가 있다: **AI는 자신이 생성한 코드를 같은 컨텍스트에서 검토하면 blind spot이 생긴다.**

```
# 검증 취약 패턴 (피해야 할 방식)
[Claude Code 세션 A]
  → 코드 생성
  → "이 코드 괜찮아?" 질문  ← 같은 컨텍스트에서 검토 = 의미 없음
  → "네, 좋습니다" 응답

# 올바른 패턴
[Claude Code 세션 A]  →  코드 생성
[Claude Code 세션 B]  →  독립 검토 (별도 컨텍스트)
[자동화 테스트]       →  실제 실행 검증
```

2026년 기준으로 AI 생성 코드 비율이 50% 이상이 된 팀에서 별도 리뷰 에이전트를 도입한 후 버그 탈출률이 평균 40% 줄었다는 데이터가 있다.

## Step 1: 리뷰 에이전트 패턴 이해하기

**Review Agent Pattern** — CI 파이프라인에 두 번째 AI 에이전트를 배치해 품질 게이트를 만드는 방식:

```
개발자/AI → 코드 생성 → PR 생성
                            ↓
                  [Review Agent (별도 컨텍스트)]
                    - 보안 취약점 스캔
                    - 로직 오류 탐지
                    - 테스트 누락 확인
                    - 성능 병목 가능성
                            ↓
               통과 → 머지 가능 / 실패 → PR 코멘트
```

| 게이트 유형 | 설명 | 자동화 수준 |
|------------|------|------------|
| 정적 분석 | ESLint, Ruff 등 기존 린터 | 완전 자동 |
| AI 리뷰 게이트 | 별도 컨텍스트 AI 검토 | 완전 자동 |
| 테스트 커버리지 | 최소 커버리지 미달 시 차단 | 완전 자동 |
| 인간 검토 | 고위험 변경 시 필수 | 반자동 |

## Step 2: GitHub Actions에 AI 리뷰 에이전트 연동

```yaml
# .github/workflows/ai-quality-gate.yml
name: AI Quality Gate

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get PR diff
        run: |
          git diff origin/main...HEAD > /tmp/pr_diff.txt
          echo "DIFF_SIZE=$(wc -l < /tmp/pr_diff.txt)" >> $GITHUB_ENV

      - name: Run AI Review Agent
        if: env.DIFF_SIZE < 500
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          python3 scripts/ai_review_agent.py \
            --diff /tmp/pr_diff.txt \
            --output /tmp/review_result.json

      - name: Post Review Comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const result = JSON.parse(
              fs.readFileSync('/tmp/review_result.json', 'utf8')
            );
            if (result.issues.length > 0) {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: result.formatted_comment
              });
            }
```

## Step 3: AI 리뷰 에이전트 스크립트 작성

```python
# scripts/ai_review_agent.py
import anthropic
import json
import argparse
from pathlib import Path

REVIEW_SYSTEM_PROMPT = """당신은 시니어 소프트웨어 엔지니어입니다.
PR diff를 검토하고 다음 항목을 체크하세요:

1. 보안: SQL 인젝션, XSS, 시크릿 하드코딩, 취약한 의존성
2. 로직: 엣지 케이스 누락, 오프바이원 오류, 레이스 컨디션
3. 테스트: 새 기능에 테스트 없음, 기존 테스트 삭제
4. 성능: N+1 쿼리, 불필요한 루프, 메모리 누수 가능성

JSON 형식으로만 응답하세요."""

def review_diff(diff_content: str) -> dict:
    client = anthropic.Anthropic()

    message = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=2048,
        messages=[
            {
                "role": "user",
                "content": f"다음 PR diff를 검토해주세요:\n\n```diff\n{diff_content[:8000]}\n```\n\n응답 형식: {{\"issues\": [{{\"severity\": \"high|medium|low\", \"type\": \"security|logic|test|performance\", \"description\": \"...\", \"line\": N}}], \"summary\": \"...\"}}"
            }
        ],
        system=REVIEW_SYSTEM_PROMPT
    )

    try:
        return json.loads(message.content[0].text)
    except json.JSONDecodeError:
        return {"issues": [], "summary": "리뷰 파싱 실패"}

def format_comment(result: dict) -> str:
    if not result["issues"]:
        return ""

    lines = ["## AI 코드 리뷰 결과\n"]
    high = [i for i in result["issues"] if i["severity"] == "high"]
    medium = [i for i in result["issues"] if i["severity"] == "medium"]

    if high:
        lines.append("### 주요 이슈\n")
        for issue in high:
            lines.append(f"- **[{issue['type'].upper()}]** {issue['description']}")

    if medium:
        lines.append("\n### 개선 권장\n")
        for issue in medium:
            lines.append(f"- [{issue['type']}] {issue['description']}")

    lines.append(f"\n> {result.get('summary', '')}")
    return "\n".join(lines)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--diff", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    diff = Path(args.diff).read_text()
    result = review_diff(diff)
    result["formatted_comment"] = format_comment(result)

    Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(f"검토 완료: 이슈 {len(result['issues'])}건")
```

## Step 4: 테스트 커버리지 게이트 설정

```yaml
# .github/workflows/coverage-gate.yml
- name: Run tests with coverage
  run: |
    pytest --cov=src --cov-report=json --cov-fail-under=80

- name: Check coverage delta
  run: |
    # 새 코드가 추가되면 커버리지가 낮아지지 않아야 함
    python3 scripts/coverage_guard.py \
      --min-coverage 80 \
      --fail-on-decrease true
```

```python
# scripts/coverage_guard.py
import json, sys, argparse

def check_coverage(coverage_file: str, min_coverage: float) -> bool:
    with open(coverage_file) as f:
        data = json.load(f)

    total = data["totals"]["percent_covered"]
    print(f"현재 커버리지: {total:.1f}%")

    if total < min_coverage:
        print(f"실패: 최소 기준 {min_coverage}% 미달")
        return False
    return True
```

## Step 5: 고위험 변경 자동 감지

일부 변경은 AI 리뷰만으로 부족하다. 인간 검토를 자동으로 요청하는 규칙을 설정한다:

```yaml
# .github/labeler.yml (자동 레이블 설정)
high-risk:
  - any:
    - changed-files:
      - any-glob-to-any-file:
        - 'src/auth/**'
        - 'src/payment/**'
        - 'migrations/**'
        - '*.env*'

security-review:
  - any:
    - changed-files:
      - any-glob-to-any-file:
        - 'src/**/*auth*.ts'
        - 'src/**/*crypto*.ts'
```

```yaml
# .github/CODEOWNERS
# 고위험 경로는 시니어 리뷰 필수
src/auth/          @senior-dev @security-team
src/payment/       @senior-dev @payment-team
migrations/        @dba-team
```

## 체크리스트

- [ ] AI 리뷰 에이전트 GitHub Actions에 설치
- [ ] 리뷰 스크립트 `scripts/ai_review_agent.py` 추가
- [ ] `ANTHROPIC_API_KEY` 시크릿 등록
- [ ] 테스트 커버리지 게이트 (80% 이상) 설정
- [ ] CODEOWNERS로 고위험 경로 보호
- [ ] 레이블러로 위험도 자동 분류
- [ ] diff 크기 제한 설정 (500줄 초과 시 분리 요청)

## 팀 도입 시 주의사항

| 상황 | 권장 설정 |
|------|----------|
| 소규모 팀 (1-5명) | AI 리뷰 + 테스트 게이트만 |
| 중규모 팀 (5-20명) | 위 + CODEOWNERS 설정 |
| 대규모 팀 (20명+) | 위 + 별도 보안 리뷰 파이프라인 |
| 금융/결제 서비스 | 반드시 인간 최종 검토 포함 |

## 다음 단계

→ [플레이북 42: AI 생성 코드 신뢰성 검증 파이프라인](./42-ai-code-trust-verification.md)
→ [가이드 38: AI 코드 보안 거버넌스](../guides/38-ai-code-security-governance.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
