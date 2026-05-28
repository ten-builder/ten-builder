# 플레이북 73: AI 에이전트 코드 리뷰 자동화

> PR이 열릴 때마다 AI 에이전트가 리뷰하는 파이프라인 구축 — GitHub Actions 연동부터 품질 게이트까지

## 소요 시간

30-60분 (초기 설정), 이후 완전 자동

## 사전 준비

- GitHub 레포 접근 권한 (Actions 설정 가능)
- Anthropic API 키 또는 Claude Code 설정
- 기본 GitHub Actions 이해

## Step 1: 리뷰 기준 파일 작성

AI 리뷰어가 일관성 있게 동작하려면 명확한 기준이 필요해요. 프로젝트 루트에 리뷰 기준을 작성합니다.

```markdown
# .claude/review-criteria.md

## 필수 확인 항목 (FAIL 조건)
- 하드코딩된 API 키, 비밀번호, 토큰
- SQL 인젝션, XSS, CSRF 취약점
- 처리되지 않은 예외 (프로덕션 영향 코드)
- 무한 루프 또는 메모리 누수 가능성

## 품질 확인 항목 (WARNING 조건)
- 100줄 초과 단일 함수
- 테스트 없는 새 비즈니스 로직
- 하드코딩된 상수 (환경 변수로 분리 권장)
- 중복 코드 (DRY 원칙 위반)

## 스킵 대상
- 생성된 파일 (*.generated.ts, migrations/)
- 패키지 잠금 파일 (package-lock.json, yarn.lock)
- 빌드 아티팩트
```

## Step 2: GitHub Actions 워크플로우 설정

PR이 열리거나 업데이트될 때 자동으로 AI 리뷰가 실행되는 워크플로우를 구성합니다.

```yaml
# .github/workflows/ai-code-review.yml
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize, ready_for_review]
    branches: [main, develop]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get PR diff
        id: diff
        run: |
          git diff origin/${{ github.base_ref }}...HEAD \
            -- '*.ts' '*.tsx' '*.js' '*.py' '*.go' \
            ':!*.generated.*' ':!*lock*' > /tmp/pr.diff
          echo "lines=$(wc -l < /tmp/pr.diff)" >> $GITHUB_OUTPUT

      - name: AI Review (Claude Code)
        if: steps.diff.outputs.lines < 2000
        uses: anthropics/claude-code-action@v1
        with:
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            다음 PR diff를 리뷰해줘.

            리뷰 기준: .claude/review-criteria.md 참조

            출력 형식:
            ## 리뷰 결과
            **판정**: PASS / WARNING / FAIL

            ### 발견된 문제
            각 문제를 아래 형식으로 작성:
            - **[심각도]** 파일명:라인 — 문제 설명
              - 수정 제안: ...

            ### 개선 권고
            필수가 아닌 권고 사항만.

            PR diff:
            $(cat /tmp/pr.diff)
```

PR 규모에 따라 리뷰 범위를 조정하는 게 중요해요. 2000줄을 넘는 diff는 정확도가 떨어집니다.

## Step 3: 인라인 코멘트 패턴

AI 리뷰 결과를 PR에 인라인으로 붙이면 리뷰어가 맥락을 파악하기 쉽습니다.

```bash
# 로컬에서 인라인 코멘트 생성 (GitHub CLI 활용)
gh pr diff $PR_NUMBER > /tmp/diff.txt

claude "다음 diff를 분석해서 문제가 있는 라인에 코멘트를 달아줘.
출력은 아래 JSON 배열 형식으로:
[
  {
    \"path\": \"파일경로\",
    \"line\": 라인번호,
    \"body\": \"코멘트 내용\"
  }
]

$(cat /tmp/diff.txt)" > /tmp/comments.json

# JSON을 파싱해서 GitHub API로 인라인 코멘트 생성
python3 scripts/post-review-comments.py $PR_NUMBER /tmp/comments.json
```

인라인 코멘트 생성 스크립트:

```python
# scripts/post-review-comments.py
import json, subprocess, sys

pr_number = sys.argv[1]
comments_file = sys.argv[2]

with open(comments_file) as f:
    comments = json.load(f)

# PR의 최신 커밋 SHA 조회
result = subprocess.run(
    ['gh', 'pr', 'view', pr_number, '--json', 'headRefOid', '--jq', '.headRefOid'],
    capture_output=True, text=True
)
commit_sha = result.stdout.strip()

for comment in comments:
    subprocess.run([
        'gh', 'api', f'repos/:owner/:repo/pulls/{pr_number}/comments',
        '--method', 'POST',
        '-f', f'body={comment["body"]}',
        '-f', f'commit_id={commit_sha}',
        '-f', f'path={comment["path"]}',
        '-F', f'line={comment["line"]}'
    ])

print(f'{len(comments)}개 인라인 코멘트 추가 완료')
```

## Step 4: 품질 게이트 자동화

AI 리뷰 결과에 따라 PR 머지를 자동으로 차단하거나 허용합니다.

```yaml
# GitHub Branch Protection Rule 설정 후 품질 게이트 추가
- name: Quality Gate Check
  run: |
    RESULT=$(cat /tmp/review-result.txt | grep "판정:" | awk '{print $2}')
    
    if [ "$RESULT" = "FAIL" ]; then
      echo "::error::AI 리뷰에서 심각한 문제가 발견되었습니다."
      echo "::error::PR 설명의 리뷰 결과를 확인하고 수정 후 재요청하세요."
      exit 1
    elif [ "$RESULT" = "WARNING" ]; then
      echo "::warning::AI 리뷰에서 개선 권고 사항이 발견되었습니다."
      echo "확인 후 머지하거나, 의도적인 경우 PR 본문에 사유를 남겨주세요."
    fi
```

| 판정 | 의미 | 처리 |
|------|------|------|
| PASS | 문제 없음 | 자동 통과 |
| WARNING | 개선 권고 | 통과 + 코멘트 |
| FAIL | 심각한 문제 | 머지 차단 |

## Step 5: @claude 멘션으로 요청 리뷰

자동 리뷰 외에 특정 상황에서 추가 리뷰가 필요할 때 멘션으로 요청합니다.

```bash
# PR 코멘트에 @claude 멘션으로 특화 리뷰 요청
# GitHub Actions에서 issue_comment 이벤트로 처리

# .github/workflows/on-demand-review.yml
on:
  issue_comment:
    types: [created]

# 코멘트에서 명령 파싱
- name: Parse Command
  if: contains(github.event.comment.body, '@claude')
  run: |
    COMMENT="${{ github.event.comment.body }}"
    
    if echo "$COMMENT" | grep -q "보안 리뷰"; then
      REVIEW_TYPE="security"
    elif echo "$COMMENT" | grep -q "성능 리뷰"; then
      REVIEW_TYPE="performance"
    else
      REVIEW_TYPE="general"
    fi
    
    echo "review_type=$REVIEW_TYPE" >> $GITHUB_ENV
```

실제 PR 코멘트 예시:
- `@claude 보안 리뷰 해줘 — 이 코드 인증 부분이 맞는지 확인해줘`
- `@claude 성능 리뷰 — 쿼리 최적화 가능한지 봐줘`
- `@claude 이 패턴이 우리 CLAUDE.md 기준에 맞는지 확인해줘`

## Step 6: 고위험 변경 자동 감지

보안에 민감한 파일이 변경될 때 추가 리뷰를 자동으로 요청합니다.

```yaml
# .github/workflows/security-review-trigger.yml
- name: Check High-Risk Files
  run: |
    HIGH_RISK_PATTERNS=(
      "auth/"
      "middleware/"
      "*payment*"
      "*.env*"
      "docker-compose*"
      "Dockerfile"
    )
    
    CHANGED=$(git diff --name-only origin/$BASE_BRANCH...HEAD)
    
    for pattern in "${HIGH_RISK_PATTERNS[@]}"; do
      if echo "$CHANGED" | grep -q "$pattern"; then
        echo "고위험 파일 변경 감지: $pattern"
        echo "requires_security_review=true" >> $GITHUB_ENV
        break
      fi
    done

- name: Request Security Review
  if: env.requires_security_review == 'true'
  uses: anthropics/claude-code-action@v1
  with:
    prompt: |
      보안에 민감한 파일이 변경되었습니다. 
      OWASP Top 10 기준으로 심층 보안 리뷰를 수행해주세요.
      특히 인증, 권한, 입력 검증, 암호화 부분을 집중적으로 확인해주세요.
```

## 체크리스트

- [ ] `.claude/review-criteria.md` 팀 기준에 맞게 작성
- [ ] `ANTHROPIC_API_KEY` GitHub Secrets에 등록
- [ ] `ai-code-review.yml` 워크플로우 배포
- [ ] Branch Protection Rule에 AI 리뷰 상태 체크 추가
- [ ] 고위험 파일 패턴 목록 프로젝트 맞게 조정
- [ ] 팀원에게 @claude 멘션 사용법 공유

## 다음 단계

→ [플레이북 67 — AI 코드 생성 품질 게이트 자동화](67-ai-code-quality-gates.md)
→ [플레이북 10 — AI 코드 리뷰 기본](10-code-review.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
