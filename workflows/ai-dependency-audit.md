# AI 의존성 감사 자동화 워크플로우

> AI 에이전트로 프로젝트 의존성을 자동 감사하고, 취약점을 탐지하고, 업데이트 PR까지 생성하는 워크플로우

## 개요

프로젝트 의존성은 시간이 지나면서 조용히 위험해져요. 새 CVE가 발표되고, 메이저 버전이 올라가고, deprecated 경고가 쌓여요. 문제는 이걸 **정기적으로 확인하고 조치하는 게** 번거롭다는 거예요.

Dependabot이나 Renovate 같은 도구가 있지만, 단순히 버전만 올리는 것과 **실제로 안전한지 판단하고 대응하는 것**은 다른 문제예요. AI 코딩 에이전트를 결합하면 취약점 분석, 호환성 검증, 마이그레이션 코드 수정까지 한 워크플로우로 처리할 수 있어요.

## 사전 준비

- Claude Code, Codex CLI, 또는 Cursor Agent 중 하나
- Node.js (`npm audit`, `npx npm-check-updates`) 또는 Python (`pip-audit`, `safety`)
- Git 레포 (로컬 클론)
- GitHub CLI (`gh`) — PR 생성 자동화
- (선택) Snyk CLI — 심층 취약점 분석

## Step 1: 현재 의존성 상태 스캔

AI 에이전트에게 프로젝트 전체 의존성 상태를 점검하게 해요.

### npm/yarn 프로젝트

```bash
# 취약점 스캔
npm audit --json > /tmp/npm-audit.json

# 오래된 패키지 확인
npx npm-check-updates --format group

# 사용되지 않는 의존성 탐지
npx depcheck
```

### Python 프로젝트

```bash
# 취약점 스캔
pip-audit --format json --output /tmp/pip-audit.json

# 오래된 패키지 확인
pip list --outdated --format json

# requirements.txt 기준 호환성 체크
pip check
```

### AI 분석 프롬프트

```
npm audit 결과와 outdated 패키지 목록을 분석해줘.
다음 기준으로 분류하고 조치 방안을 제안해줘:

1. 즉시 조치: CVSS 7.0+ 취약점, 알려진 exploit 존재
2. 이번 주 조치: CVSS 4.0-6.9, 메이저 버전 2개+ 뒤처짐
3. 모니터링: 경미한 취약점, 패치 버전만 뒤처짐
4. 무시 가능: 개발 의존성의 경미한 이슈

각 항목에 breaking change 가능성도 표시해줘.
```

## Step 2: 취약점 심각도 평가

스캔 결과를 AI가 분석해서 실제 영향을 판단해요.

### 평가 기준

| 등급 | CVSS 점수 | 조건 | 조치 |
|------|-----------|------|------|
| Critical | 9.0+ | 원격 코드 실행, 인증 우회 | 즉시 패치 |
| High | 7.0-8.9 | 데이터 노출, 권한 상승 | 24시간 내 |
| Medium | 4.0-6.9 | DoS, 정보 유출 | 1주 내 |
| Low | 0.1-3.9 | 경미한 이슈 | 다음 정기 업데이트 |

### AI 심층 분석 프롬프트

```
이 취약점(CVE-XXXX-XXXX)이 우리 프로젝트에 실제로 영향을 미치는지 분석해줘.

확인할 것:
1. 취약한 함수/모듈을 실제로 사용하는지
2. 해당 코드 경로가 사용자 입력을 받는지
3. 네트워크에 노출되는 컨텍스트인지
4. 다른 보안 레이어로 이미 방어되는지

영향도: 실제 영향 있음 / 간접 영향 / 영향 없음 중 판단해줘.
```

## Step 3: 자동 업데이트 전략 수립

### 패치 버전 업데이트 (자동화 안전)

```bash
# npm: 패치 버전만 업데이트 (breaking change 최소)
npx npm-check-updates --target patch -u
npm install
npm test
```

```bash
# Python: 호환 범위 내 업데이트
pip install --upgrade-strategy only-if-needed -r requirements.txt
python -m pytest
```

### 마이너/메이저 업데이트 (AI 검증 필요)

```bash
# 마이너 업데이트 후보 확인
npx npm-check-updates --target minor

# 메이저 업데이트 후보 확인 (breaking change 주의)
npx npm-check-updates --target latest
```

### AI 마이그레이션 프롬프트

```
{패키지}를 v{현재} → v{타겟}으로 업데이트해줘.

1. CHANGELOG에서 breaking changes 확인
2. 우리 코드에서 영향받는 부분 찾기
3. 마이그레이션 코드 수정
4. 테스트 실행해서 통과 확인

수정이 필요한 파일 목록과 변경 내용을 정리해줘.
```

## Step 4: CI/CD 연동 자동화

### GitHub Actions 워크플로우

```yaml
# .github/workflows/dependency-audit.yml
name: Dependency Audit

on:
  schedule:
    - cron: '0 9 * * 1'  # 매주 월요일 9시
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run audit
        run: |
          npm audit --json > audit-result.json || true
          npx npm-check-updates --format json > outdated.json || true

      - name: Check critical vulnerabilities
        run: |
          CRITICAL=$(cat audit-result.json | jq '[.vulnerabilities | to_entries[] | select(.value.severity == "critical")] | length')
          HIGH=$(cat audit-result.json | jq '[.vulnerabilities | to_entries[] | select(.value.severity == "high")] | length')
          echo "Critical: $CRITICAL, High: $HIGH"
          if [ "$CRITICAL" -gt 0 ]; then
            echo "::error::Critical vulnerabilities found!"
          fi

      - name: Upload audit results
        uses: actions/upload-artifact@v4
        with:
          name: dependency-audit
          path: |
            audit-result.json
            outdated.json
```

### Renovate 설정 (자동 PR 생성)

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "schedule": ["every weekend"],
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "automerge": true,
      "automergeType": "branch"
    },
    {
      "matchUpdateTypes": ["minor"],
      "automerge": false,
      "labels": ["dependency-update", "needs-review"]
    },
    {
      "matchUpdateTypes": ["major"],
      "labels": ["dependency-update", "breaking-change"],
      "reviewers": ["team:frontend"]
    }
  ],
  "vulnerabilityAlerts": {
    "enabled": true,
    "labels": ["security"]
  }
}
```

## Step 5: AI + Renovate/Dependabot 하이브리드

Renovate가 PR을 올리면, AI 에이전트가 breaking change를 분석하고 수정하는 2단계 구조예요.

### 구조

```
Renovate PR 생성
    ↓
AI 에이전트가 PR 분석
    ↓
breaking change 있으면 → AI가 마이그레이션 코드 커밋
    ↓
테스트 통과 확인
    ↓
리뷰어에게 알림
```

### AI 리뷰 프롬프트

```
이 Renovate PR을 분석해줘.

1. 업데이트된 패키지와 버전 변경 확인
2. 각 패키지의 CHANGELOG에서 breaking changes 추출
3. 우리 코드에서 영향받는 파일 목록
4. 필요한 코드 수정 사항
5. 테스트 커버리지 확인

결론: 바로 머지 가능 / 코드 수정 필요 / 보류 권장
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 스캔 주기 | 주 1회 | 프로젝트 규모에 따라 조정 |
| 자동 머지 범위 | 패치만 | 테스트 커버리지 높으면 마이너까지 |
| 알림 채널 | Slack/Discord | 취약점 등급별 알림 분리 |
| AI 분석 깊이 | breaking change만 | 필요하면 성능 영향까지 확인 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| `npm audit` 오탐이 많음 | `audit-resolve.json`으로 무시 목록 관리 |
| 메이저 업데이트 후 빌드 실패 | AI에게 에러 로그와 마이그레이션 가이드 함께 전달 |
| Renovate PR이 너무 많음 | `groupName`으로 관련 패키지 묶기 |
| 패키지 간 의존성 충돌 | `overrides`/`resolutions` 필드로 버전 고정 후 단계적 해소 |
| pip-audit에서 false positive | `.pip-audit-known-vulnerabilities.toml`로 예외 관리 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
