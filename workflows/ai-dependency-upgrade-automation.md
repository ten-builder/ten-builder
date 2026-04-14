# AI 에이전트 기반 의존성 업그레이드 자동화 워크플로우

> npm, pip, cargo 등 패키지 의존성 업그레이드를 AI 에이전트가 자동 분석하고, 호환성 테스트 후 안전하게 PR을 생성하는 워크플로우

## 개요

프로젝트를 운영하다 보면 의존성 업그레이드가 쌓입니다. 패치 버전은 그냥 올려도 되고, 마이너는 조심스럽고, 메이저는 브레이킹 체인지 확인이 필요합니다. 이 판단을 사람이 매번 직접 하는 건 비용이 큽니다.

AI 에이전트를 활용하면 이 과정을 단계별로 자동화할 수 있습니다. 업그레이드 가능 목록 탐지 → 위험도 분류 → 호환성 검증 → PR 생성까지 한 번에 처리합니다.

## 사전 준비

- Node.js 프로젝트(npm/yarn/pnpm), Python 프로젝트(pip), 또는 Rust 프로젝트(cargo)
- Claude Code 또는 동등한 AI 코딩 에이전트
- GitHub Actions (선택 — CI 연동 시)
- Renovate 또는 Dependabot (트리거 소스로 활용 가능)

## 워크플로우 전체 구조

```
패키지 매니저 outdated 목록
        ↓
업그레이드 위험도 분류 (AI)
  patch  → 자동 머지
  minor  → 테스트 후 PR
  major  → 브레이킹 체인지 분석 + PR
        ↓
호환성 테스트 실행
        ↓
PR 생성 (위험도별 라벨 포함)
```

## 설정

### Step 1: 의존성 현황 파악

```bash
# npm
npx npm-check-updates --format group

# pip
pip list --outdated --format=json | python3 -c "
import json, sys
pkgs = json.load(sys.stdin)
for p in pkgs:
    print(f\"{p['name']}: {p['version']} → {p['latest_version']}\")
"

# cargo
cargo outdated --depth 1
```

### Step 2: AI 에이전트 분석 프롬프트

```
현재 프로젝트의 의존성 업그레이드 목록을 분석해줘.

1. 각 패키지를 patch/minor/major 변경으로 분류해
2. major 변경이 있는 패키지는 공식 변경 로그에서 브레이킹 체인지를 요약해
3. 브레이킹 체인지가 현재 코드베이스에 영향을 주는지 확인해
4. 영향받는 코드가 있으면 수정 방법도 제안해
5. 안전하게 업그레이드 가능한 것과 수동 검토가 필요한 것을 분리해줘
```

### Step 3: 업그레이드 스크립트 (npm 기준)

```bash
#!/bin/bash
# upgrade-deps.sh

# Patch 업그레이드 — 자동 처리
echo "=== Patch 업그레이드 ==="
npx npm-check-updates --target patch --upgrade
npm install
npm test

if [ $? -eq 0 ]; then
  git add package.json package-lock.json
  git commit -m "chore(deps): bump patch dependencies"
fi

# Minor 업그레이드 — 테스트 통과 시 PR
echo "=== Minor 업그레이드 ==="
npx npm-check-updates --target minor --upgrade
npm install
npm test

if [ $? -eq 0 ]; then
  git checkout -b chore/deps-minor-$(date +%Y%m%d)
  git add package.json package-lock.json
  git commit -m "chore(deps): bump minor dependencies"
  gh pr create --title "chore(deps): minor dependency updates" \
    --body "자동 감지된 minor 버전 업그레이드\n\n테스트: 통과" \
    --label "dependencies"
fi
```

### Step 4: Major 업그레이드 — AI 분석 포함

```bash
# Major 업그레이드 목록 추출
MAJOR_UPDATES=$(npx npm-check-updates --target major --format json)

# Claude Code에 분석 위임
cat > /tmp/major-upgrade-prompt.md << 'EOF'
다음 major 업그레이드 목록을 분석해줘:

${MAJOR_UPDATES}

각 패키지에 대해:
1. 공식 마이그레이션 가이드 링크
2. 주요 브레이킹 체인지 (3줄 이내)
3. 현재 코드베이스에서 영향받는 파일 목록
4. 수정이 필요한 코드 패턴

분석 후 수정 가능한 것은 직접 수정하고 PR을 만들어줘.
EOF

claude "$(cat /tmp/major-upgrade-prompt.md)"
```

## 사용 방법

### 실제 시나리오: React 18 → React 19 업그레이드

```bash
# 1. 현황 확인
npx npm-check-updates react react-dom

# 출력 예시:
# react  ^18.2.0  →  ^19.0.0
# react-dom  ^18.2.0  →  ^19.0.0

# 2. Claude Code에 마이그레이션 위임
claude "React 18에서 React 19로 업그레이드하려고 해.
브레이킹 체인지를 확인하고, 우리 코드베이스에서 영향받는 부분을 
수정한 뒤 PR을 만들어줘. 테스트도 통과해야 해."

# Claude Code가 자동으로:
# - React 19 변경 로그 분석
# - deprecated API 사용 탐지
# - 코드 수정 (예: ReactDOM.render → createRoot)
# - 테스트 실행
# - PR 생성
```

### Renovate와 연동

```json
// renovate.json
{
  "extends": ["config:base"],
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "automerge": true
    },
    {
      "matchUpdateTypes": ["minor"],
      "automerge": false,
      "labels": ["minor-update", "needs-review"]
    },
    {
      "matchUpdateTypes": ["major"],
      "enabled": true,
      "labels": ["major-update", "breaking-change"],
      "postUpgradeTasks": {
        "commands": ["claude 'package.json의 major 업그레이드를 분석하고 필요한 코드 수정을 해줘'"],
        "fileFilters": ["**/*.{ts,tsx,js,jsx}"]
      }
    }
  ]
}
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| patch 자동 머지 | 활성화 | 패치 버전은 자동 처리 |
| minor 테스트 임계값 | 커버리지 80% | 이하면 수동 검토 |
| major 분석 깊이 | 직접 의존성만 | transitive 포함 가능 |
| PR 라벨 | dependencies | GitHub 라벨명 |
| 실행 주기 | 주 1회 | cron 설정으로 조절 |

## GitHub Actions 통합

```yaml
# .github/workflows/ai-dep-upgrade.yml
name: AI Dependency Upgrade

on:
  schedule:
    - cron: '0 9 * * 1'  # 매주 월요일 오전 9시
  workflow_dispatch:

jobs:
  upgrade:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Check outdated packages
        id: outdated
        run: |
          OUTDATED=$(npm outdated --json 2>/dev/null || echo '{}')
          echo "outdated=$OUTDATED" >> $GITHUB_OUTPUT

      - name: Auto-merge patches
        run: |
          npx npm-check-updates --target patch --upgrade
          npm install
          npm test
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A && git commit -m "chore(deps): auto-bump patch versions" || true

      - name: Create PR for minor/major
        if: steps.outdated.outputs.outdated != '{}'
        run: |
          git checkout -b chore/ai-dep-upgrade-$(date +%Y%m%d)
          npx npm-check-updates --target minor --upgrade
          npm install
          npm test
          gh pr create \
            --title "chore(deps): weekly dependency updates" \
            --body "## 자동 의존성 업그레이드\n\npatch: 자동 머지 완료\nminor: 검토 필요" \
            --label "dependencies"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| 테스트 실패 후 업그레이드가 진행됨 | `set -e` 추가하여 실패 시 중단 |
| peer dependency 충돌 | `--legacy-peer-deps` 대신 AI에게 의존성 트리 분석 요청 |
| 너무 많은 PR이 생성됨 | Renovate grouping 설정으로 PR 묶기 |
| major 업그레이드 분석이 부정확함 | 공식 마이그레이션 가이드 URL을 AI에게 직접 전달 |
| CI 환경에서 Claude Code 실행 안 됨 | GitHub Actions 대신 로컬에서 분석 후 결과만 커밋 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
