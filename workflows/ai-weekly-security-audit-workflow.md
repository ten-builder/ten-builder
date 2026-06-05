# AI 에이전트 주간 보안 감사 워크플로우 — 자동 취약점 탐지에서 수정 PR까지

> 코드베이스 보안은 한 번 설정하고 잊는 것이 아닙니다. AI 에이전트로 매주 자동으로 돌리는 보안 감사 파이프라인을 구성해보세요.

## 이 워크플로우가 해결하는 문제

보안 취약점은 대부분 "알고 있지만 못 고치는" 문제가 아닙니다. **발견이 늦는** 문제입니다. 의존성에 새 CVE가 등록되어도 개발팀이 모르는 경우가 많고, 코드베이스에 점진적으로 쌓이는 보안 약점은 바쁜 스프린트 중에 리뷰를 통과합니다.

AI 에이전트를 보안 감사에 투입하면:
- 매주 자동으로 전체 코드베이스를 스캔하고
- 발견된 취약점을 심각도별로 분류하고
- 수정 가능한 항목은 자동으로 PR을 생성합니다

## 사전 준비

- GitHub Actions 실행 가능한 레포지터리
- Snyk 계정 (무료 플랜 가능, `SNYK_TOKEN` 시크릿 등록)
- Semgrep 계정 (무료 플랜 가능, `SEMGREP_APP_TOKEN` 시크릿 등록)
- Claude API 키 (`ANTHROPIC_API_KEY` 시크릿 등록)

## 워크플로우 구조

```
매주 일요일 02:00 UTC
    ↓
Step 1: 의존성 CVE 스캔 (Snyk)
    ↓
Step 2: 코드 패턴 취약점 스캔 (Semgrep)
    ↓
Step 3: AI 에이전트 결과 분석 및 우선순위화
    ↓
Step 4: 자동 수정 가능 항목 → 수정 PR 생성
    ↓
Step 5: 감사 리포트 생성 → 팀 알림
```

## 설정

### Step 1: GitHub Actions 워크플로우 파일 생성

`.github/workflows/weekly-security-audit.yml`:

```yaml
name: Weekly Security Audit

on:
  schedule:
    - cron: '0 2 * * 0'  # 매주 일요일 02:00 UTC
  workflow_dispatch:      # 수동 실행도 가능

permissions:
  contents: write
  pull-requests: write
  security-events: write

jobs:
  security-audit:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Run Snyk vulnerability scan
        uses: snyk/actions/node@master
        continue-on-error: true
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --json --file=package.json > snyk-results.json || true

      - name: Run Semgrep SAST scan
        uses: semgrep/semgrep-action@v1
        with:
          config: 'p/security-audit'
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}

      - name: AI 에이전트 결과 분석 및 수정 PR 생성
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          node scripts/ai-security-fix.js

      - name: Upload audit report
        uses: actions/upload-artifact@v4
        with:
          name: security-audit-report
          path: security-audit-report.md
          retention-days: 30
```

### Step 2: AI 분석 스크립트 작성

`scripts/ai-security-fix.js`:

```javascript
const Anthropic = require('@anthropic-ai/sdk');
const { execSync } = require('child_process');
const fs = require('fs');

const client = new Anthropic();

async function runSecurityAudit() {
  // 1. 스캔 결과 수집
  const snykResults = JSON.parse(
    fs.readFileSync('snyk-results.json', 'utf-8')
  );
  
  const semgrepResults = JSON.parse(
    fs.readFileSync('semgrep-results.json', 'utf-8')
  );

  // 2. AI 에이전트로 결과 분석
  const analysisPrompt = `
다음은 코드베이스 보안 스캔 결과입니다.

## Snyk 의존성 취약점
${JSON.stringify(snykResults.vulnerabilities?.slice(0, 20), null, 2)}

## Semgrep 코드 취약점
${JSON.stringify(semgrepResults.results?.slice(0, 20), null, 2)}

다음을 수행해주세요:
1. 심각도(critical/high/medium/low)별로 분류
2. 즉시 수정 가능한 항목 식별 (의존성 버전 업그레이드로 해결 가능한 것)
3. 수동 검토가 필요한 항목 목록화
4. 각 항목에 대한 간단한 수정 방법 제안

JSON 형식으로 응답해주세요.
  `;

  const analysis = await client.messages.create({
    model: 'claude-opus-4-5',
    max_tokens: 4096,
    messages: [{ role: 'user', content: analysisPrompt }],
  });

  const auditData = JSON.parse(
    analysis.content[0].text.match(/```json\n([\s\S]+?)\n```/)?.[1] || '{}'
  );

  // 3. 자동 수정 가능한 의존성 업그레이드 PR 생성
  if (auditData.autoFixable?.length > 0) {
    await createFixPR(auditData.autoFixable);
  }

  // 4. 감사 리포트 생성
  await generateReport(auditData);
}

async function createFixPR(fixableItems) {
  const branch = `security/weekly-audit-${new Date().toISOString().slice(0, 10)}`;
  
  execSync(`git checkout -b ${branch}`);
  
  // 의존성 업그레이드 실행
  const upgrades = fixableItems
    .filter(item => item.type === 'dependency')
    .map(item => `${item.package}@${item.fixedVersion}`)
    .join(' ');
  
  if (upgrades) {
    execSync(`npm install ${upgrades}`);
    execSync('git add package.json package-lock.json');
    execSync(`git commit -m "security: fix ${fixableItems.length} vulnerabilities via dependency upgrades"`);
    execSync(`git push origin ${branch}`);
    
    // PR 생성
    execSync(`gh pr create \
      --title "security: weekly audit auto-fix (${new Date().toISOString().slice(0, 10)})" \
      --body "## 자동 보안 수정 PR\n\n수정된 취약점: ${fixableItems.length}개\n\n${fixableItems.map(i => \`- \${i.package}: \${i.severity} (\${i.cve || 'SAST'}\`).join('\n')}" \
      --base main`);
  }
}

async function generateReport(auditData) {
  const report = `# 주간 보안 감사 리포트

**날짜:** ${new Date().toLocaleDateString('ko-KR')}

## 요약

| 심각도 | 건수 |
|--------|------|
| Critical | ${auditData.critical?.length || 0} |
| High | ${auditData.high?.length || 0} |
| Medium | ${auditData.medium?.length || 0} |
| Low | ${auditData.low?.length || 0} |

## 자동 수정 완료

${auditData.autoFixable?.map(i => `- ${i.package}: ${i.description}`).join('\n') || '없음'}

## 수동 검토 필요

${auditData.manualReview?.map(i => `- [${i.severity}] ${i.title}: ${i.file}`).join('\n') || '없음'}
`;

  fs.writeFileSync('security-audit-report.md', report);
}

runSecurityAudit().catch(console.error);
```

### Step 3: OWASP ZAP 연동 (선택)

동적 분석(DAST)을 추가하려면 별도 job으로 구성합니다:

```yaml
  dast-scan:
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch'
    services:
      app:
        image: your-app:latest
        ports:
          - 3000:3000
    steps:
      - name: OWASP ZAP Scan
        uses: zaproxy/action-full-scan@v0.10.0
        with:
          target: 'http://localhost:3000'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
```

## 사용 방법

### 첫 실행

```bash
# 로컬에서 테스트 실행
npm install @anthropic-ai/sdk
ANTHROPIC_API_KEY=your-key node scripts/ai-security-fix.js

# GitHub Actions에서 수동 트리거
gh workflow run weekly-security-audit.yml
```

### 스캔 범위 커스터마이징

Semgrep 룰셋 선택 기준:

| 룰셋 | 대상 | 비고 |
|------|------|------|
| `p/security-audit` | 전체 보안 감사 | 기본 추천 |
| `p/owasp-top-ten` | OWASP Top 10 | 웹 앱 |
| `p/nodejs` | Node.js 특화 | JS 프로젝트 |
| `p/secrets` | 시크릿 유출 | 모든 프로젝트 |

### 심각도 임계값 설정

```yaml
# 심각도별 자동화 정책
auto_fix_threshold: high      # High 이상 자동 수정 PR 생성
block_threshold: critical     # Critical은 PR 머지 블록
notify_threshold: medium      # Medium 이상 팀 알림
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 실행 주기 | 매주 일요일 | `cron` 표현식으로 변경 가능 |
| 자동 수정 기준 | High 이상 | `auto_fix_threshold` 조정 |
| 리포트 보존 기간 | 30일 | `retention-days` 조정 |
| 스캔 대상 | 전체 코드베이스 | Semgrep `--include`/`--exclude` 사용 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| Snyk 토큰 오류 | Settings > Secrets에서 `SNYK_TOKEN` 재등록 |
| Semgrep 타임아웃 | 대형 레포는 `--timeout` 값 증가 또는 범위 축소 |
| PR 생성 권한 오류 | 워크플로우에 `pull-requests: write` 권한 추가 확인 |
| AI 분석 오류 | `ANTHROPIC_API_KEY` 유효 여부 및 API 크레딧 확인 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
