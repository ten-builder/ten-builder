# 플레이북 77: AI 생성 코드 보안 검토 플레이북

> AI가 만든 코드, 믿기 전에 검증하세요 — AI 생성 코드의 보안 취약점을 탐지하고 자동으로 수정하는 단계별 플레이북

## 왜 지금 이게 필요한가요?

2026년 현재 AI 코딩 도구 없이 개발하는 팀은 거의 없습니다. 문제는 속도입니다.

Sherlock Forensics의 2026 AI Code Security Report에 따르면 AI 생성 코드베이스의 **92%에 하나 이상의 치명적 취약점**이 포함되어 있습니다. Veracode는 AI 코드의 보안 통과율이 **55% 수준에서 2년째 정체** 중이라고 밝혔습니다. AI가 코드를 빠르게 만들수록 취약점도 빠르게 쌓입니다.

이 플레이북은 AI 에이전트로 생성한 코드를 PR 단계에서 체계적으로 검토하고, 발견된 취약점을 자동으로 수정하는 파이프라인을 구성하는 방법을 다룹니다.

## 소요 시간

초기 설정: 60-90분
운영 후 PR당 자동 검토: 3-5분

## 사전 준비

- Claude Code 또는 다른 AI 코딩 에이전트 사용 중인 프로젝트
- GitHub 저장소 (GitHub Actions 사용)
- Node.js 18+ 또는 Python 3.10+

## Step 1: 보안 검토 레이어 설계

AI 생성 코드 보안 검토는 세 레이어로 나뉩니다.

| 레이어 | 도구 | 타이밍 |
|--------|------|--------|
| 정적 분석(SAST) | Semgrep, CodeQL | PR 생성 시 |
| 의존성 검사 | Snyk, Dependabot | PR 생성 시 |
| AI 보안 리뷰 | Claude API | PR 생성 시 |
| 동적 분석(DAST) | OWASP ZAP | 스테이징 배포 후 |

SAST는 코드 패턴을 정적으로 분석합니다. AI 생성 코드에 자주 등장하는 문제 — SQL 인젝션 패턴, 시크릿 하드코딩, 안전하지 않은 역직렬화 — 를 빠르게 잡습니다. 그 위에 AI 보안 리뷰를 올려서 SAST가 놓친 비즈니스 로직 취약점을 보완합니다.

## Step 2: Semgrep 설정

Semgrep은 AI 생성 코드 특화 룰셋이 있는 SAST 도구입니다.

```bash
# Semgrep 설치
pip install semgrep

# AI 에이전트 코드 특화 룰셋 확인
semgrep --config "p/owasp-top-ten" .
semgrep --config "p/secrets" .
semgrep --config "p/security-audit" .
```

프로젝트 루트에 `.semgrepignore` 파일을 만들어 테스트 코드와 문서를 제외합니다.

```
# .semgrepignore
node_modules/
*.test.js
*.spec.ts
docs/
```

팀 공유 룰셋은 `semgrep.yml`로 관리합니다.

```yaml
# semgrep.yml
rules:
  - id: ai-hardcoded-secret
    pattern: |
      $KEY = "..."
    message: 하드코딩된 시크릿이 감지됐습니다. 환경변수를 사용하세요.
    languages: [python, javascript, typescript]
    severity: ERROR
    metadata:
      category: security
      ai-generated-risk: high

  - id: sql-injection-risk
    pattern: |
      $DB.query("..." + $INPUT)
    message: SQL 인젝션 위험 — 파라미터 바인딩을 사용하세요.
    languages: [python, javascript, typescript]
    severity: ERROR
```

## Step 3: AI 보안 리뷰 에이전트 구성

SAST로 잡기 어려운 비즈니스 로직 취약점과 컨텍스트 의존적 보안 문제를 AI가 보완합니다.

CLAUDE.md에 보안 검토 지시사항을 추가합니다.

```markdown
## 보안 검토 지침

코드를 검토할 때 다음 사항을 항상 확인하세요:

1. **인증 우회 가능성** — 권한 체크 없이 민감한 작업 접근 가능 여부
2. **입력값 검증 누락** — 사용자 입력이 그대로 DB 쿼리나 명령어에 사용되는지
3. **에러 메시지 정보 노출** — 스택 트레이스나 내부 구조가 외부에 노출되는지
4. **경쟁 조건(Race Condition)** — 동시 요청 처리 시 데이터 무결성 위반 가능성
5. **하드코딩된 자격증명** — API 키, 비밀번호가 코드에 포함되어 있는지
```

## Step 4: GitHub Actions 파이프라인 구성

```yaml
# .github/workflows/ai-code-security-review.yml
name: AI Code Security Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  sast-scan:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Semgrep 스캔
        uses: semgrep/semgrep-action@v1
        with:
          config: >-
            p/owasp-top-ten
            p/secrets
            semgrep.yml
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}

      - name: Snyk 의존성 취약점 검사
        uses: snyk/actions/node@master
        with:
          args: --severity-threshold=high
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

  ai-security-review:
    runs-on: ubuntu-latest
    needs: sast-scan
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 변경된 파일 목록 추출
        id: changed-files
        run: |
          git diff --name-only origin/main...HEAD > changed_files.txt
          cat changed_files.txt

      - name: AI 보안 리뷰 실행
        run: |
          python3 .github/scripts/ai-security-review.py
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
```

AI 보안 리뷰 스크립트를 만듭니다.

```python
# .github/scripts/ai-security-review.py
import anthropic
import os
import subprocess
import json
from github import Github

SYSTEM_PROMPT = """당신은 시니어 보안 엔지니어입니다.
AI 코딩 에이전트가 생성한 코드를 보안 관점에서 검토하세요.

다음 취약점 유형에 집중하세요:
- OWASP Top 10 보안 취약점
- AI 코드에 자주 등장하는 하드코딩된 자격증명
- 비즈니스 로직 취약점
- 입력 검증 및 출력 이스케이프 누락

발견사항은 다음 형식으로 작성하세요:
**[심각도: HIGH/MEDIUM/LOW]** 파일명:줄번호
설명과 수정 방법"""

def get_pr_diff():
    result = subprocess.run(
        ["git", "diff", "origin/main...HEAD"],
        capture_output=True, text=True
    )
    return result.stdout

def review_with_ai(diff: str) -> str:
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    
    # 큰 diff는 분할 처리
    if len(diff) > 50000:
        diff = diff[:50000] + "\n... (이하 생략)"
    
    message = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=2000,
        system=SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"다음 코드 변경사항을 보안 관점에서 검토해 주세요:\n\n```diff\n{diff}\n```"
        }]
    )
    return message.content[0].text

def post_review_comment(review: str):
    g = Github(os.environ["GITHUB_TOKEN"])
    repo = g.get_repo(os.environ["GITHUB_REPOSITORY"])
    pr = repo.get_pull(int(os.environ["PR_NUMBER"]))
    
    comment = f"## AI 보안 검토 결과\n\n{review}\n\n---\n*자동 생성된 보안 검토입니다. 결과를 반드시 직접 확인하세요.*"
    pr.create_issue_comment(comment)

if __name__ == "__main__":
    diff = get_pr_diff()
    if not diff.strip():
        print("변경된 코드가 없습니다.")
        exit(0)
    
    review = review_with_ai(diff)
    post_review_comment(review)
    print("보안 리뷰 완료")
```

## Step 5: 자동 수정 루프 설정

취약점을 발견했을 때 AI 에이전트가 직접 수정 제안을 코드로 만들어주는 루프입니다.

```bash
# CLAUDE.md에 보안 수정 지시사항 추가
cat >> CLAUDE.md << 'EOF'

## 보안 취약점 자동 수정

보안 취약점이 발견됐을 때:
1. 취약점 유형을 분류하세요 (OWASP 분류 기준)
2. 즉시 수정 가능한 경우 코드를 수정하세요
3. 수정 시 테스트 케이스도 함께 추가하세요
4. 수정 내용을 커밋 메시지에 명시하세요: "fix(security): ..."
EOF
```

Claude Code에서 직접 실행하는 보안 수정 명령어 패턴입니다.

```bash
# 특정 파일의 보안 취약점 수정
claude "이 파일의 SQL 인젝션 취약점을 파라미터 바인딩 방식으로 수정해줘. 
기존 테스트가 깨지지 않도록 하고, 수정 사항에 대한 테스트도 추가해줘" \
  --add-file src/database/queries.ts

# 전체 코드베이스 시크릿 하드코딩 검사 및 수정
claude "프로젝트에서 하드코딩된 API 키, 비밀번호, 토큰을 찾아서 모두 환경변수로 교체해줘. 
.env.example도 업데이트해줘"
```

## Step 6: 보안 게이트 설정

CI/CD에서 심각도 HIGH 이상의 취약점이 있으면 머지를 차단합니다.

```yaml
# .github/workflows/security-gate.yml
  security-gate:
    runs-on: ubuntu-latest
    needs: [sast-scan, ai-security-review]
    steps:
      - name: 심각도 HIGH 취약점 차단
        run: |
          if [ -f semgrep-results.json ]; then
            HIGH_COUNT=$(cat semgrep-results.json | \
              jq '[.results[] | select(.extra.severity == "ERROR")] | length')
            if [ "$HIGH_COUNT" -gt "0" ]; then
              echo "HIGH 심각도 취약점 ${HIGH_COUNT}개 발견. 머지를 차단합니다."
              exit 1
            fi
          fi
```

## 체크리스트

- [ ] Semgrep 설치 및 프로젝트 전용 룰셋 작성
- [ ] GitHub Actions 파이프라인 구성
- [ ] AI 보안 리뷰 스크립트 설정 및 API 키 등록
- [ ] CLAUDE.md에 보안 검토 지침 추가
- [ ] 심각도 HIGH 취약점 머지 차단 게이트 설정
- [ ] 팀에 보안 리뷰 결과 해석 방법 공유
- [ ] 월별 취약점 트렌드 리포트 설정

## 운영 팁

**노이즈 줄이기:** 처음에는 Semgrep 결과가 많이 나옵니다. `.semgrepignore`로 불필요한 경고를 줄이고, 팀이 동의한 규칙만 ERROR로 설정하세요.

**AI 리뷰 비용:** AI 보안 리뷰는 diff 크기에 따라 토큰을 소비합니다. 큰 PR은 파일별로 분리해서 검토하는 것이 정확도와 비용 모두 유리합니다.

**False Positive 관리:** AI 리뷰가 잘못된 경고를 낼 수 있습니다. PR 코멘트에 "false positive"를 명시하면 다음 학습에 반영됩니다.

## 다음 단계

→ [보안 코드 리뷰 자동화 플레이북](./71-security-code-review-sast-dast.md)
→ [AI 에이전트 코드 생성 품질 게이트](./67-ai-code-quality-gates.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
