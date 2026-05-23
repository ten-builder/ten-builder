# 플레이북 71: AI 에이전트 보안 코드 리뷰 플레이북 — SAST/DAST 자동화

> PR이 열릴 때마다 AI 에이전트가 정적·동적 분석을 수행하고 취약점 수정 제안까지 자동 생성하는 보안 파이프라인 구성 가이드

## 소요 시간

60-90분 (초기 설정 기준)

## 사전 준비

- GitHub Actions 또는 GitLab CI 환경
- Semgrep CLI (`pip install semgrep`) 또는 GitHub App
- Snyk 계정 (무료 플랜 사용 가능)
- Docker (OWASP ZAP DAST 실행용)
- Claude API 키 (수정 제안 생성용)

---

## Step 1: SAST 레이어 구성 (Semgrep)

AI 에이전트가 생성한 코드는 안전하게 작성된 것처럼 보이지만, SQL Injection, SSRF, 하드코딩된 시크릿 같은 취약점을 담고 있는 경우가 많습니다. Semgrep은 PR 단계에서 이를 자동으로 탐지합니다.

### GitHub Actions 기본 설정

```yaml
# .github/workflows/sast-security.yml
name: SAST Security Scan

on:
  pull_request:
    branches: [main, develop]

jobs:
  semgrep-scan:
    runs-on: ubuntu-latest
    container:
      image: semgrep/semgrep
    steps:
      - uses: actions/checkout@v4

      - name: Run Semgrep SAST
        run: |
          semgrep ci \
            --config=p/default \
            --config=p/owasp-top-ten \
            --config=p/secrets \
            --json \
            --output=semgrep-results.json \
            || true

      - name: Upload scan results
        uses: actions/upload-artifact@v4
        with:
          name: semgrep-results
          path: semgrep-results.json
```

### 커스텀 보안 룰 작성

AI 에이전트가 자주 생성하는 취약한 패턴을 직접 정의할 수 있습니다.

```yaml
# .semgrep/custom-rules.yml
rules:
  - id: unsafe-exec-call
    pattern: |
      exec($CMD, ...)
    message: "exec() 직접 호출 — 사용자 입력을 sanitize하거나 subprocess.run() + shlex.split()으로 교체"
    languages: [python]
    severity: ERROR

  - id: hardcoded-api-key
    pattern: |
      $KEY = "$VALUE"
    metavariable-regex:
      metavariable: $KEY
      regex: '(?i)(api_key|secret|password|token)'
    message: "하드코딩된 시크릿 감지 — 환경변수 또는 Vault로 이동"
    languages: [python, javascript, typescript]
    severity: ERROR

  - id: sql-injection-risk
    patterns:
      - pattern: |
          $QUERY = "..." + $INPUT + "..."
      - pattern-not: |
          $QUERY = "..." + sanitize($INPUT) + "..."
    message: "SQL 쿼리 문자열 연결 — Parameterized Query 사용"
    languages: [python, javascript, typescript]
    severity: WARNING
```

---

## Step 2: Snyk Code 통합

Snyk은 IDE 내 실시간 스캔과 PR 자동 코멘트를 모두 지원합니다.

```yaml
# .github/workflows/snyk-scan.yml
name: Snyk Security Scan

on:
  pull_request:
    branches: [main]

jobs:
  snyk-code:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Snyk Code analysis
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          command: code test
          args: >
            --severity-threshold=high
            --json-file-output=snyk-results.json

      - name: PR 결과 코멘트 게시
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const results = JSON.parse(
              fs.readFileSync('snyk-results.json', 'utf8')
            );
            const high = results.runs?.[0]?.results?.filter(
              r => r.level === 'error'
            ) || [];
            if (high.length > 0) {
              github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: `## Snyk 보안 스캔 결과\n\n심각도 높은 취약점 **${high.length}개** 감지\n\n자세한 내용은 Actions 탭에서 확인하세요.`
              });
            }
```

---

## Step 3: DAST 레이어 구성 (OWASP ZAP)

스테이징 환경이 있다면 DAST로 실행 중인 앱의 취약점도 자동 탐지할 수 있습니다.

```yaml
# .github/workflows/dast-security.yml
name: DAST Security Scan

on:
  push:
    branches: [main]

jobs:
  zap-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.12.0
        with:
          target: ${{ secrets.STAGING_URL }}
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a -j'
          fail_action: false

      - name: ZAP Full Scan (PR 외 push)
        if: github.event_name == 'push'
        uses: zaproxy/action-full-scan@v0.10.0
        with:
          target: ${{ secrets.STAGING_URL }}
          cmd_options: '-a'
```

### ZAP 예외 규칙 설정

```tsv
# .zap/rules.tsv
# Rule ID	IGNORE/WARN/FAIL	설명
10015	WARN	Incomplete or No Cache-control Header Set
10016	WARN	Web Browser XSS Protection Not Enabled
10096	IGNORE	Timestamp Disclosure
```

---

## Step 4: AI 에이전트 수정 제안 생성

스캔 결과를 AI 에이전트에게 전달하여 구체적인 수정 코드를 자동 생성합니다.

```python
# scripts/ai-security-fix.py
import json
import subprocess
import anthropic

def analyze_and_fix(semgrep_results_path: str, repo_root: str):
    """Semgrep 결과를 분석하고 AI 수정 제안을 생성합니다."""
    client = anthropic.Anthropic()

    with open(semgrep_results_path) as f:
        results = json.load(f)

    findings = results.get("results", [])
    if not findings:
        print("취약점 없음")
        return

    for finding in findings[:5]:  # 상위 5개 처리
        file_path = finding["path"]
        line_start = finding["start"]["line"]
        rule_id = finding["check_id"]
        message = finding["extra"]["message"]

        # 해당 파일의 컨텍스트 읽기
        with open(f"{repo_root}/{file_path}") as f:
            lines = f.readlines()

        context_start = max(0, line_start - 5)
        context_end = min(len(lines), line_start + 10)
        code_context = "".join(lines[context_start:context_end])

        # AI 수정 제안 요청
        response = client.messages.create(
            model="claude-opus-4-5",
            max_tokens=1024,
            messages=[{
                "role": "user",
                "content": f"""다음 보안 취약점을 수정하는 코드를 작성해주세요.

파일: {file_path} (라인 {line_start})
취약점: {rule_id}
설명: {message}

현재 코드:
```
{code_context}
```

수정된 코드와 변경 이유를 한국어로 설명해주세요."""
            }]
        )

        print(f"\n=== {file_path}:{line_start} ({rule_id}) ===")
        print(response.content[0].text)
```

```yaml
# GitHub Actions에 수정 제안 단계 추가
      - name: AI 수정 제안 생성
        if: steps.semgrep-scan.outputs.findings > 0
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          python3 scripts/ai-security-fix.py \
            semgrep-results.json \
            . \
            > ai-fix-suggestions.md

      - name: PR에 AI 수정 제안 코멘트 추가
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const suggestions = fs.readFileSync('ai-fix-suggestions.md', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## AI 에이전트 보안 수정 제안\n\n${suggestions}`
            });
```

---

## Step 5: 통합 보안 게이트 설정

| 도구 | 용도 | 차단 기준 |
|------|------|-----------|
| Semgrep | SAST — 코드 패턴 분석 | HIGH 이상 1건 이상 |
| Snyk Code | SAST — 종속성 + 코드 | CRITICAL 1건 이상 |
| OWASP ZAP | DAST — 런타임 취약점 | HIGH 이상 1건 이상 |
| AI 수정 제안 | 수정 가이드 | 차단 안 함 (참고용) |

```yaml
# .github/workflows/security-gate.yml
name: Security Gate

on:
  pull_request:
    branches: [main]

jobs:
  security-check:
    runs-on: ubuntu-latest
    steps:
      - name: 보안 스캔 결과 평가
        run: |
          HIGH_COUNT=$(cat semgrep-results.json | \
            jq '[.results[] | select(.extra.severity == "ERROR")] | length')

          if [ "$HIGH_COUNT" -gt "0" ]; then
            echo "::error::HIGH 심각도 취약점 ${HIGH_COUNT}개 감지 — 머지 차단"
            exit 1
          fi

          echo "보안 게이트 통과"
```

---

## 체크리스트

- [ ] Semgrep 기본 룰셋 (`p/default`, `p/owasp-top-ten`, `p/secrets`) 적용
- [ ] 프로젝트 특화 커스텀 룰 최소 3개 작성
- [ ] Snyk Token GitHub Secrets에 등록
- [ ] 스테이징 환경 URL 설정 (DAST용)
- [ ] AI 수정 제안 스크립트 테스트
- [ ] HIGH 이상 취약점에 대한 머지 차단 게이트 활성화
- [ ] 팀에 false positive 처리 절차 공유

---

## 흔한 문제와 해결

| 문제 | 해결 |
|------|------|
| False positive 과다 | `.semgrepignore` 파일로 제외 경로 지정, 커스텀 룰 정밀도 개선 |
| ZAP 스캔 시간 초과 | `action-baseline` 사용 (Full Scan 대비 빠름), 타임아웃 설정 조정 |
| AI 수정 제안이 부정확 | 더 많은 코드 컨텍스트 전달 (±20줄), 프로젝트 스택 정보 포함 |
| Snyk 무료 플랜 제한 | 월 200건 제한 — PR 이벤트만 트리거하도록 `on` 조건 조정 |

---

## 다음 단계

→ [플레이북 67: AI 에이전트 코드 생성 품질 게이트 자동화](./67-ai-code-quality-gates.md)
→ [플레이북 53: AI 에이전트 보안 취약점 자동 패치](./48-security-vulnerability-auto-patch.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
