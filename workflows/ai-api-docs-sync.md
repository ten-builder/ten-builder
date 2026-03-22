# AI 기반 API 문서 자동 동기화 워크플로우

> 코드를 바꾸면 API 문서도 알아서 따라오는 CI/CD 연동 워크플로우

## 개요

API 엔드포인트를 수정했는데 문서 업데이트를 깜빡하는 일은 모든 팀에서 반복돼요. OpenAPI 스펙과 README를 코드 변경에 맞춰 자동으로 동기화하면 이 문제를 구조적으로 해결할 수 있어요.

이 워크플로우가 해결하는 문제:
- 코드와 API 문서 사이의 drift(불일치)
- PR 리뷰에서 "문서 업데이트했나요?" 반복 질문
- 신규 엔드포인트 추가 시 OpenAPI 스펙 누락

## 사전 준비

- OpenAPI 3.0+ 스펙 파일 (`openapi.yaml` 또는 `openapi.json`)
- GitHub Actions 또는 동등한 CI/CD 환경
- AI 코딩 에이전트 (Claude Code, Cursor 등)
- Node.js 18+ 또는 Python 3.10+

## 설정

### Step 1: OpenAPI 스펙 기본 구조 준비

프로젝트 루트에 `docs/openapi.yaml`을 관리해요:

```yaml
# docs/openapi.yaml
openapi: 3.1.0
info:
  title: My API
  version: 1.0.0
  description: 프로젝트 API 문서

paths:
  /users:
    get:
      summary: 사용자 목록 조회
      operationId: listUsers
      tags: [users]
      responses:
        '200':
          description: 성공
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/User'

components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: string
        name:
          type: string
        email:
          type: string
          format: email
```

### Step 2: 코드에서 스펙을 자동 추출하는 스크립트

프레임워크별 OpenAPI 추출 방법이 달라요. 가장 일반적인 패턴을 정리하면:

**FastAPI (Python):**

```python
# scripts/extract_openapi.py
import json
import sys
sys.path.insert(0, '.')
from app.main import app

spec = app.openapi()
with open('docs/openapi.json', 'w') as f:
    json.dump(spec, f, indent=2, ensure_ascii=False)

print(f"Extracted {len(spec.get('paths', {}))} endpoints")
```

**Express + swagger-jsdoc (Node.js):**

```javascript
// scripts/extract-openapi.js
const swaggerJsdoc = require('swagger-jsdoc');
const fs = require('fs');
const yaml = require('js-yaml');

const options = {
  definition: {
    openapi: '3.1.0',
    info: { title: 'My API', version: '1.0.0' },
  },
  apis: ['./src/routes/*.js'],
};

const spec = swaggerJsdoc(options);
fs.writeFileSync(
  'docs/openapi.yaml',
  yaml.dump(spec, { lineWidth: -1 })
);
console.log(`Extracted ${Object.keys(spec.paths || {}).length} endpoints`);
```

### Step 3: AI 문서 동기화 스크립트

코드 변경 diff를 읽고 API 문서를 업데이트하는 스크립트예요:

```bash
#!/bin/bash
# scripts/sync-api-docs.sh

set -euo pipefail

DIFF_FILE=$(mktemp)
SPEC_FILE="docs/openapi.yaml"
README_FILE="docs/API.md"

# 1. 변경된 API 관련 파일 diff 추출
git diff main --name-only | grep -E '(routes|controllers|handlers|schemas)' > "$DIFF_FILE" || true

if [ ! -s "$DIFF_FILE" ]; then
  echo "API 관련 변경 없음 — 스킵"
  exit 0
fi

echo "변경된 API 파일:"
cat "$DIFF_FILE"

# 2. OpenAPI 스펙 재생성 (프레임워크에 맞게 선택)
python scripts/extract_openapi.py 2>/dev/null || \
  node scripts/extract-openapi.js 2>/dev/null || \
  echo "스펙 추출 스크립트 없음 — 수동 동기화 필요"

# 3. 스펙 검증
npx @redocly/cli lint "$SPEC_FILE" --format=stylish || {
  echo "OpenAPI 스펙 검증 실패"
  exit 1
}

# 4. README 자동 생성
npx @redocly/cli build-docs "$SPEC_FILE" -o docs/api-reference.html

echo "API 문서 동기화 완료"
```

### Step 4: GitHub Actions 워크플로우

PR이 열릴 때마다 API 문서 동기화를 자동 실행해요:

```yaml
# .github/workflows/api-docs-sync.yml
name: API Docs Sync

on:
  pull_request:
    paths:
      - 'src/routes/**'
      - 'src/controllers/**'
      - 'src/schemas/**'
      - 'app/routers/**'
      - 'app/models/**'

jobs:
  sync-docs:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.head_ref }}
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Extract OpenAPI spec
        run: |
          python scripts/extract_openapi.py || \
          node scripts/extract-openapi.js

      - name: Lint OpenAPI spec
        run: npx @redocly/cli lint docs/openapi.yaml

      - name: Check for spec changes
        id: check
        run: |
          if git diff --quiet docs/; then
            echo "changed=false" >> $GITHUB_OUTPUT
          else
            echo "changed=true" >> $GITHUB_OUTPUT
          fi

      - name: Commit updated docs
        if: steps.check.outputs.changed == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add docs/
          git commit -m "docs: sync API documentation with code changes"
          git push

      - name: Comment on PR
        if: steps.check.outputs.changed == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '📄 API 문서가 코드 변경에 맞춰 자동 업데이트되었어요.\n\n변경된 파일을 확인해 주세요.'
            });
```

## AI 에이전트로 문서 품질 높이기

자동 추출만으로는 설명이 부족한 경우가 많아요. AI 에이전트를 추가해서 문서 품질을 올릴 수 있어요.

### 패턴 1: PR diff 기반 문서 보강

```bash
# AI에게 diff와 기존 스펙을 함께 전달
claude -p "다음 코드 변경사항을 분석하고, 
docs/openapi.yaml의 해당 엔드포인트 description과 
example을 업데이트해줘.

변경된 코드:
$(git diff main -- src/routes/)

현재 스펙:
$(cat docs/openapi.yaml)

규칙:
- description은 한국어로
- example은 실제 사용 가능한 값으로
- 기존 스펙 구조는 유지"
```

### 패턴 2: 엔드포인트 변경 감지 + 알림

```yaml
# .github/workflows/api-change-detect.yml
name: API Change Detection

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  detect:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect API changes
        run: |
          CHANGED=$(git diff origin/main --name-only | \
            grep -cE '(routes|controllers|handlers)' || echo 0)
          
          SPEC_CHANGED=$(git diff origin/main --name-only | \
            grep -c 'openapi' || echo 0)
          
          if [ "$CHANGED" -gt 0 ] && [ "$SPEC_CHANGED" -eq 0 ]; then
            echo "⚠️ API 코드 변경 감지, 하지만 OpenAPI 스펙 미갱신"
            echo "NEEDS_UPDATE=true" >> $GITHUB_ENV
          fi

      - name: Warn on PR
        if: env.NEEDS_UPDATE == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '⚠️ API 관련 코드가 변경되었지만 `docs/openapi.yaml`이 업데이트되지 않았어요.\n\n문서 동기화가 필요한지 확인해 주세요.'
            });
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 스펙 파일 경로 | `docs/openapi.yaml` | 프로젝트에 맞게 변경 |
| 트리거 경로 | `src/routes/**` | API 코드가 위치한 디렉토리 |
| 스펙 추출 방식 | 프레임워크별 | FastAPI는 자동, Express는 JSDoc 필요 |
| 문서 생성 도구 | Redocly | Swagger UI, Stoplight 등 대안 가능 |
| AI 보강 | 선택 사항 | description/example 자동 작성 |

## 도구 비교

| 도구 | 특징 | 적합한 경우 |
|------|------|------------|
| **Redocly** | OpenAPI 린트 + 빌드 통합 | 스펙 품질 관리가 중요할 때 |
| **Fern** | SDK + 문서 동시 생성 | 클라이언트 SDK도 자동화할 때 |
| **Mintlify** | 마크다운 기반 예쁜 문서 | 외부 공개 문서가 필요할 때 |
| **Swagger UI** | 인터랙티브 API 탐색 | 개발 중 빠른 테스트용 |
| **Stoplight** | 디자인 퍼스트 접근 | 스펙을 먼저 설계하고 코딩할 때 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 스펙 추출 시 import 에러 | 가상 환경 활성화 확인, `sys.path` 수정 |
| GitHub Actions 권한 부족 | `permissions: contents: write` 추가 |
| 스펙 린트 실패 | `npx @redocly/cli lint --format=stylish`로 상세 에러 확인 |
| diff 감지가 안 됨 | `fetch-depth: 0` 설정 확인 (전체 히스토리 필요) |
| AI 생성 문서 톤 불일치 | 프롬프트에 기존 문서 예시를 포함해서 톤 통일 |

## 실전 체크리스트

- [ ] `openapi.yaml` (또는 `.json`)이 버전 관리에 포함되어 있는지 확인
- [ ] 스펙 추출 스크립트가 로컬에서 정상 동작하는지 테스트
- [ ] CI에서 API 코드 변경 시 스펙 동기화가 트리거되는지 확인
- [ ] 스펙 린트를 PR 체크에 포함했는지 확인
- [ ] README 또는 API.md에 OpenAPI 스펙 링크가 있는지 확인

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
