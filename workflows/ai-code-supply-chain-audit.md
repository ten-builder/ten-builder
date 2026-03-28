# AI 코드 서플라이 체인 감사 워크플로우

> AI 에이전트가 생성한 코드와 추가한 의존성을 CI/CD 파이프라인에서 자동으로 감사하는 워크플로우

## 개요

AI 코딩 에이전트를 쓰면 생산성이 올라가지만, 한 가지 놓치기 쉬운 문제가 있어요. AI가 코드를 생성할 때 **어떤 패키지를 추가했는지**, **그 패키지가 안전한지** 확인하기 어렵다는 거예요.

사람이 직접 코드를 작성할 땐 자연스럽게 "이 라이브러리 괜찮나?" 하고 확인하지만, AI 에이전트가 자동으로 `npm install`이나 `pip install`을 실행하면 그 과정이 빠져요. 특히 typosquatting(이름이 비슷한 악성 패키지), 유지보수 중단 패키지, 라이선스 충돌 같은 서플라이 체인 리스크는 코드 리뷰에서도 놓치기 쉬워요.

이 워크플로우는 CI/CD 파이프라인에 SAST(정적 분석), SCA(소프트웨어 구성 분석), 의존성 검증을 통합해서 AI가 생성한 코드의 서플라이 체인 안전성을 자동으로 확인하는 방법을 다뤄요.

## 사전 준비

- GitHub Actions (또는 GitLab CI / Jenkins)
- Node.js 또는 Python 프로젝트
- Snyk CLI 또는 Trivy (무료 취약점 스캐너)
- GitHub CLI (`gh`) — PR 코멘트 자동화
- (선택) Semgrep — AI 생성 코드 패턴 감지

## 설정

### Step 1: 의존성 변경 감지 스크립트

AI 에이전트가 작업한 PR에서 **새로 추가된 의존성만 추출**하는 스크립트를 만들어요.

```bash
#!/bin/bash
# scripts/detect-new-deps.sh
# PR에서 추가된 의존성 목록 추출

set -euo pipefail

DIFF_TARGET="${1:-origin/main}"

# package.json 변경 감지 (npm/yarn)
if git diff "$DIFF_TARGET" -- package.json | grep -E '^\+.*"[^"]+": "[^"]+"' | grep -v '"name"\|"version"\|"description"'; then
  echo "=== 새로 추가된 npm 의존성 ==="
  git diff "$DIFF_TARGET" -- package.json \
    | grep -E '^\+.*"[^"]+": "[~^]?[0-9]' \
    | sed 's/.*"\([^"]*\)".*/\1/' \
    | sort -u
fi

# requirements.txt 변경 감지 (Python)
if git diff "$DIFF_TARGET" -- requirements*.txt | grep -E '^\+[a-zA-Z]'; then
  echo "=== 새로 추가된 Python 의존성 ==="
  git diff "$DIFF_TARGET" -- requirements*.txt \
    | grep -E '^\+[a-zA-Z]' \
    | sed 's/^\+//' | cut -d'=' -f1 | cut -d'>' -f1 | cut -d'<' -f1 \
    | sort -u
fi
```

### Step 2: GitHub Actions 워크플로우

```yaml
# .github/workflows/supply-chain-audit.yml
name: Supply Chain Audit

on:
  pull_request:
    paths:
      - 'package.json'
      - 'package-lock.json'
      - 'yarn.lock'
      - 'requirements*.txt'
      - 'pyproject.toml'
      - 'go.sum'

jobs:
  dependency-audit:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 새 의존성 추출
        id: detect
        run: |
          chmod +x scripts/detect-new-deps.sh
          NEW_DEPS=$(./scripts/detect-new-deps.sh origin/${{ github.base_ref }})
          echo "deps<<EOF" >> $GITHUB_OUTPUT
          echo "$NEW_DEPS" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Trivy 취약점 스캔
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'json'
          output: 'trivy-results.json'
          severity: 'CRITICAL,HIGH'

      - name: 패키지 메타데이터 검증
        if: steps.detect.outputs.deps != ''
        run: |
          echo "${{ steps.detect.outputs.deps }}" | while read -r pkg; do
            [ -z "$pkg" ] && continue
            [[ "$pkg" == "==="* ]] && continue

            echo "--- 검증 중: $pkg ---"

            # npm 패키지 메타데이터 확인
            NPM_INFO=$(npm view "$pkg" --json 2>/dev/null || echo '{}')

            # 주간 다운로드 수 (너무 적으면 경고)
            DOWNLOADS=$(echo "$NPM_INFO" | jq -r '.downloads // 0')

            # 최근 업데이트 (1년 이상 방치 경고)
            MODIFIED=$(echo "$NPM_INFO" | jq -r '.time.modified // "unknown"')

            # 유지보수자 수
            MAINTAINERS=$(echo "$NPM_INFO" | jq '.maintainers | length // 0')

            echo "  다운로드: $DOWNLOADS | 수정: $MODIFIED | 유지보수자: $MAINTAINERS"

            # 경고 조건
            if [ "$MAINTAINERS" -le 1 ] 2>/dev/null; then
              echo "  ⚠️ 단일 유지보수자 패키지"
            fi
          done

      - name: 라이선스 호환성 검사
        run: |
          npx license-checker --production --json > license-report.json
          # 비호환 라이선스 필터링
          cat license-report.json | jq '
            to_entries[]
            | select(.value.licenses
              | test("GPL|AGPL|SSPL|BSL|BUSL"; "i"))
            | {package: .key, license: .value.licenses}
          '

      - name: PR 코멘트로 결과 보고
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            let report = '## 🔍 서플라이 체인 감사 결과\n\n';

            // Trivy 결과 파싱
            try {
              const trivy = JSON.parse(fs.readFileSync('trivy-results.json'));
              const vulns = trivy.Results?.flatMap(r => r.Vulnerabilities || []) || [];
              const critical = vulns.filter(v => v.Severity === 'CRITICAL');
              const high = vulns.filter(v => v.Severity === 'HIGH');

              report += `| 심각도 | 건수 |\n|--------|------|\n`;
              report += `| CRITICAL | ${critical.length} |\n`;
              report += `| HIGH | ${high.length} |\n\n`;

              if (critical.length > 0) {
                report += '### CRITICAL 취약점\n\n';
                critical.forEach(v => {
                  report += `- **${v.VulnerabilityID}**: ${v.PkgName} (${v.InstalledVersion})\n`;
                });
              }
            } catch(e) {
              report += '취약점 스캔 결과를 파싱할 수 없습니다.\n';
            }

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: report
            });

  sast-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Semgrep 정적 분석
        uses: semgrep/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/secrets
            p/owasp-top-ten
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}
```

### Step 3: AI 에이전트 전용 제한 규칙

AI 에이전트가 의존성을 추가할 때 적용할 규칙을 프로젝트 루트에 정의해요.

```yaml
# .ai-supply-chain-policy.yml
# AI 에이전트 의존성 추가 정책

allowed_registries:
  - npmjs.org
  - pypi.org

dependency_rules:
  min_weekly_downloads: 1000      # 최소 주간 다운로드
  min_maintainers: 1              # 최소 유지보수자 수
  max_age_without_update: 365     # 최대 업데이트 미실시 일수
  blocked_licenses:               # 차단 라이선스
    - GPL-3.0
    - AGPL-3.0
    - SSPL-1.0

  blocked_packages:               # 명시적 차단 패키지
    - event-stream                # 악성 코드 사례
    - colors                      # protestware 사례
    - faker                       # protestware 사례

scan_on:
  - pull_request
  - push_to_main

severity_threshold: HIGH          # HIGH 이상 발견 시 PR 블록
```

## 사용 방법

### 일반적인 흐름

1. AI 에이전트가 코드 생성 + 의존성 추가 → PR 생성
2. GitHub Actions가 자동으로 서플라이 체인 감사 실행
3. PR 코멘트에 취약점/라이선스/메타데이터 검증 결과 표시
4. CRITICAL 취약점이 있으면 CI 실패 → 머지 차단
5. 리뷰어가 감사 결과를 확인하고 머지 판단

### Claude Code에서 정책 활용

```markdown
<!-- CLAUDE.md에 추가 -->
## 의존성 추가 규칙

새 패키지를 설치하기 전에:
1. npm view {패키지명} 으로 주간 다운로드, 유지보수자 수 확인
2. 1,000 다운로드 미만이면 대안 검토
3. GPL/AGPL 라이선스 패키지 사용 금지
4. 설치 후 npm audit 실행하여 취약점 확인
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `severity_threshold` | `HIGH` | CI 실패 기준 심각도 |
| `min_weekly_downloads` | `1000` | 최소 신뢰 기준 다운로드 수 |
| `max_age_without_update` | `365일` | 방치 패키지 경고 기준 |
| `blocked_licenses` | `GPL-3.0, AGPL-3.0` | 프로젝트 라이선스 호환성 기준 |
| `scan_on` | `pull_request` | 스캔 트리거 이벤트 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| Trivy가 너무 많은 경고를 발생시킴 | `.trivyignore`에 허용 CVE 등록, severity를 `CRITICAL`로 조정 |
| npm 프라이빗 패키지 스캔 실패 | `.npmrc`에 레지스트리 토큰 설정, Actions secrets에 `NPM_TOKEN` 추가 |
| 라이선스 체커가 서브 의존성까지 검사함 | `--direct` 옵션으로 직접 의존성만 검사 |
| Semgrep이 AI 생성 코드에서 false positive가 많음 | `.semgrepignore`에 패턴 추가, `nosemgrep` 인라인 코멘트 활용 |
| AI 에이전트가 정책 파일을 무시함 | CLAUDE.md나 .cursorrules에 정책 참조 규칙 명시 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
