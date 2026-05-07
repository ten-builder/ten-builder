# AI 에이전트 기반 코드 공급망 보안 워크플로우 2026

> npm/pip/cargo 패키지의 공급망 공격을 탐지하고, 의심스러운 의존성을 자동 격리하고, SBOM을 생성하는 보안 워크플로우

## 개요

2026년 기준으로 소프트웨어 공급망 공격은 전체 보안 침해의 45% 이상을 차지해요. AI 에이전트가 코드를 작성하면서 외부 패키지를 자동으로 설치하는 시대에, 의존성 하나가 전체 프로덕션 시스템을 위협할 수 있어요.

이 워크플로우는 세 가지를 한꺼번에 다뤄요:
- **탐지**: 공급망 공격 패턴(typosquatting, 악성 postinstall 스크립트, 갑작스러운 오너 변경)을 AI 에이전트로 자동 감지
- **격리**: 의심스러운 패키지를 CI에서 즉시 차단하고 격리 레지스트리로 라우팅
- **추적**: SBOM 생성 + Sigstore 서명으로 빌드 출처를 SLSA Level 2 수준으로 보장

## 사전 준비

- GitHub Actions (또는 GitLab CI)
- Node.js 18+, Python 3.11+, 또는 Rust 1.75+ 프로젝트
- `syft` — SBOM 생성 ([anchore/syft](https://github.com/anchore/syft))
- `cosign` — Sigstore 아티팩트 서명 ([sigstore/cosign](https://github.com/sigstore/cosign))
- `osv-scanner` — Google OSV 기반 취약점 스캔 ([google/osv-scanner](https://github.com/google/osv-scanner))
- (선택) 사설 레지스트리 — Verdaccio(npm), devpi(pip), Cargo Crate Mirror

## Step 1: 공급망 공격 탐지 스크립트

의존성이 추가될 때마다 자동으로 위험 신호를 체크하는 스크립트예요.

```bash
#!/bin/bash
# scripts/supply-chain-detector.sh
# 공급망 공격 위험 신호 탐지

set -euo pipefail

PACKAGE_NAME="${1}"
PACKAGE_MANAGER="${2:-npm}"  # npm | pip | cargo

echo "=== 공급망 보안 탐지 시작: $PACKAGE_NAME ==="

# 1. 패키지 이름 typosquatting 체크 (유사 이름 탐지)
check_typosquatting() {
  local name="$1"
  # 인기 패키지 목록과 유사도 비교 (레벤슈타인 거리 2 이하)
  python3 -c "
import sys
popular = ['react','lodash','express','axios','moment','webpack','babel','eslint','typescript','jest']
name = '$name'
def levenshtein(a, b):
    m, n = len(a), len(b)
    dp = [[0]*(n+1) for _ in range(m+1)]
    for i in range(m+1): dp[i][0] = i
    for j in range(n+1): dp[0][j] = j
    for i in range(1,m+1):
        for j in range(1,n+1):
            dp[i][j] = min(dp[i-1][j]+1, dp[i][j-1]+1,
                          dp[i-1][j-1]+(0 if a[i-1]==b[j-1] else 1))
    return dp[m][n]
for p in popular:
    dist = levenshtein(name.lower(), p.lower())
    if 0 < dist <= 2:
        print(f'WARNING: {name} 이름이 {p}와 유사 (거리={dist}) — typosquatting 가능성')
"
}

# 2. npm postinstall 스크립트 탐지 (악성 스크립트 실행 위험)
check_postinstall() {
  if [ "$PACKAGE_MANAGER" = "npm" ]; then
    npm pack "$PACKAGE_NAME" --dry-run 2>/dev/null | grep -i "postinstall\|install\|preinstall" && \
      echo "WARNING: $PACKAGE_NAME 에 설치 스크립트가 있습니다. 내용을 반드시 확인하세요." || true
  fi
}

# 3. 패키지 오너 최근 변경 여부 (npm)
check_ownership_change() {
  if [ "$PACKAGE_MANAGER" = "npm" ]; then
    PUBLISH_DATE=$(npm view "$PACKAGE_NAME" time.modified 2>/dev/null || echo "unknown")
    LATEST_VERSION=$(npm view "$PACKAGE_NAME" version 2>/dev/null || echo "unknown")
    echo "최신 버전: $LATEST_VERSION (마지막 수정: $PUBLISH_DATE)"
  fi
}

check_typosquatting "$PACKAGE_NAME"
check_postinstall
check_ownership_change
echo "=== 탐지 완료 ==="
```

## Step 2: OSV 기반 취약점 스캔 + 격리

의심스러운 패키지를 발견하면 CI를 즉시 중단하고, 허용 여부를 명시적으로 결정해요.

```yaml
# .github/workflows/supply-chain-security.yml
name: Supply Chain Security Check

on:
  pull_request:
    paths:
      - 'package*.json'
      - 'requirements*.txt'
      - 'Cargo.toml'
      - 'Cargo.lock'

jobs:
  osv-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: OSV 취약점 스캔
        uses: google/osv-scanner-action@v1
        with:
          scan-args: |-
            --lockfile=package-lock.json
            --lockfile=requirements.txt
            --lockfile=Cargo.lock
            --format=json
            --output=osv-results.json
        continue-on-error: true

      - name: 결과 분석 + Critical 격리
        run: |
          python3 - <<'EOF'
          import json, sys

          with open('osv-results.json') as f:
              results = json.load(f)

          critical = []
          for result in results.get('results', []):
              for pkg in result.get('packages', []):
                  for vuln in pkg.get('vulnerabilities', []):
                      severity = vuln.get('database_specific', {}).get('severity', 'UNKNOWN')
                      if severity in ('CRITICAL', 'HIGH'):
                          critical.append({
                              'package': pkg['package']['name'],
                              'version': pkg['package']['version'],
                              'vuln_id': vuln['id'],
                              'severity': severity
                          })

          if critical:
              print(f"[BLOCK] Critical/High 취약점 {len(critical)}개 발견:")
              for c in critical:
                  print(f"  - {c['package']}@{c['version']}: {c['vuln_id']} ({c['severity']})")
              sys.exit(1)
          else:
              print("[PASS] Critical/High 취약점 없음")
          EOF

      - name: 공급망 공격 탐지 스크립트 실행
        run: |
          # 이번 PR에서 새로 추가된 패키지만 체크
          git diff origin/main -- package-lock.json \
            | grep '"resolved"' \
            | grep '^\+' \
            | sed 's/.*"resolved": "https:\/\/registry.npmjs.org\/\([^/-]*\).*/\1/' \
            | sort -u \
            | while read pkg; do
                bash scripts/supply-chain-detector.sh "$pkg" npm
              done
```

## Step 3: SBOM 생성

모든 의존성을 추적할 수 있도록 빌드마다 SBOM(소프트웨어 부품 목록)을 자동 생성해요.

```bash
# syft로 SBOM 생성 (SPDX 형식)
syft dir:. -o spdx-json=sbom.spdx.json

# 또는 CycloneDX 형식 (더 많은 도구 지원)
syft dir:. -o cyclonedx-json=sbom.cdx.json

# Docker 이미지 SBOM
syft your-image:latest -o spdx-json=image-sbom.spdx.json

# SBOM 내용 확인 — 패키지 목록 추출
cat sbom.cdx.json | python3 -c "
import json, sys
sbom = json.load(sys.stdin)
components = sbom.get('components', [])
print(f'총 {len(components)}개 컴포넌트')
for c in components[:10]:
    name = c.get('name', '')
    version = c.get('version', '')
    purl = c.get('purl', '')
    print(f'  {name}@{version} — {purl}')
print('...')
"
```

## Step 4: Sigstore 서명으로 SLSA Level 2 달성

SBOM과 빌드 아티팩트에 Sigstore 서명을 붙여 빌드 출처를 검증 가능하게 만들어요.

```bash
# GitHub Actions 환경에서 keyless 서명 (OIDC 기반)
# cosign은 GitHub Actions의 OIDC 토큰을 자동으로 사용해요

# 컨테이너 이미지 서명
cosign sign --yes your-registry/your-image:latest

# SBOM 파일 서명
cosign sign-blob --yes sbom.cdx.json \
  --bundle sbom.cdx.json.bundle

# 서명 검증 (다운스트림에서 사용)
cosign verify \
  --certificate-identity "https://github.com/your-org/your-repo/.github/workflows/release.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  your-registry/your-image:latest
```

GitHub Actions 워크플로우에 통합:

```yaml
  sign-and-attest:
    needs: [osv-scan, build]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # Sigstore keyless 서명에 필수

    steps:
      - name: cosign 설치
        uses: sigstore/cosign-installer@v3

      - name: SBOM 생성
        run: syft dir:. -o cyclonedx-json=sbom.cdx.json

      - name: SBOM 서명
        run: |
          cosign sign-blob --yes sbom.cdx.json \
            --bundle sbom.cdx.json.bundle

      - name: SBOM 아티팩트 업로드
        uses: actions/upload-artifact@v4
        with:
          name: sbom-signed
          path: |
            sbom.cdx.json
            sbom.cdx.json.bundle
```

## Step 5: 사설 레지스트리 연동 (선택)

프라이빗 환경에서는 외부 레지스트리 직접 접근을 막고, 검증된 패키지만 사용하도록 라우팅할 수 있어요.

```bash
# Verdaccio (npm 프록시 레지스트리) 설정
# config.yaml
packages:
  '@my-org/*':
    access: $authenticated
    publish: $authenticated
    proxy: false          # 외부 접근 차단

  '**':
    access: $authenticated
    publish: $authenticated
    proxy: npmjs          # 허용된 외부 소스만 프록시

# 프로젝트 .npmrc에서 사설 레지스트리 지정
registry=https://your-verdaccio.internal
```

```bash
# pip의 경우 devpi 또는 PyPI 미러 사용
# pip.conf
[global]
index-url = https://your-pypi-mirror.internal/simple/
trusted-host = your-pypi-mirror.internal
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| OSV 스캔 severity 기준 | CRITICAL, HIGH | MEDIUM 포함 시 false positive 증가 |
| SBOM 형식 | CycloneDX JSON | SPDX는 법적 준수(NTIA) 요건에 더 적합 |
| Sigstore 서명 모드 | keyless (OIDC) | 장기 키 관리 불필요, CI에 적합 |
| 격리 정책 | CI 블록 | Slack 알림만으로 완화할 수도 있음 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| `cosign sign` OIDC 실패 | GitHub Actions `id-token: write` 권한 확인 |
| OSV 스캔 결과 없음 | lockfile 경로가 맞는지 확인 (`.json`, `.lock` 등) |
| syft가 의존성 누락 | `--scope all-layers` 옵션 추가 (Docker 이미지) |
| Verdaccio 연결 실패 | `.npmrc` 레지스트리 URL + 인증 토큰 확인 |
| typosquatting 오탐 | `popular` 목록을 프로젝트 실제 의존성 기준으로 업데이트 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
