# AI 에이전트 파이프라인 워크플로우

> 여러 AI 에이전트를 단계별로 연결해 코드 생성부터 리뷰, 테스트, 배포 준비까지 자동화하는 워크플로우

## 개요

AI 코딩 도구 하나로 모든 걸 해결하려고 하면 컨텍스트가 길어지고, 결과물 품질이 떨어져요. 대신 **각 단계를 전담하는 에이전트를 파이프라인으로 연결**하면 훨씬 안정적인 결과를 얻을 수 있어요.

이 워크플로우에서 다루는 파이프라인 구조:

1. **생성(Generate)** — 스펙 기반으로 코드를 작성하는 에이전트
2. **리뷰(Review)** — 생성된 코드의 보안, 패턴, 버그를 검사하는 에이전트
3. **테스트(Test)** — 누락된 테스트 케이스를 보강하는 에이전트
4. **배포 준비(Pre-deploy)** — 커밋 메시지, PR 본문, 변경 로그를 정리하는 에이전트

핵심은 에이전트 간 **입출력 포맷을 통일**하고, 실패 시 이전 단계로 되돌릴 수 있게 만드는 거예요.

## 사전 준비

- AI 코딩 도구 (Claude Code 권장, Cursor Agent 또는 Copilot Agent도 가능)
- 셸 스크립트 또는 CI 환경 (GitHub Actions, Makefile)
- 프로젝트 루트에 `CLAUDE.md` 또는 `.cursorrules` 설정
- 테스트 프레임워크 (Jest, pytest, Go test 등)

## 설정

### Step 1: 파이프라인 디렉토리 구조 만들기

각 에이전트의 입출력을 관리할 디렉토리를 먼저 만들어요.

```bash
mkdir -p .ai-pipeline/{specs,generated,review,tests,deploy}
```

| 디렉토리 | 역할 |
|----------|------|
| `specs/` | 에이전트에게 전달할 작업 스펙 |
| `generated/` | 1단계 생성 결과물 |
| `review/` | 2단계 리뷰 피드백 |
| `tests/` | 3단계 테스트 보강 결과 |
| `deploy/` | 4단계 배포 준비 산출물 |

### Step 2: 스펙 파일 작성

파이프라인의 시작점은 항상 **명확한 스펙**이에요. 에이전트에게 "알아서 해줘"가 아니라, 구체적인 요구사항을 전달해야 해요.

```yaml
# .ai-pipeline/specs/feature-auth.yaml
feature: JWT 인증 미들웨어
requirements:
  - Express.js 미들웨어로 구현
  - access token + refresh token 이중 검증
  - 만료 시 자동 갱신 로직 포함
  - 에러 응답은 RFC 7807 형식
constraints:
  - 외부 라이브러리는 jsonwebtoken만 허용
  - 환경변수로 시크릿 관리
test_criteria:
  - 유효 토큰 통과
  - 만료 토큰 갱신
  - 변조 토큰 거부
  - 시크릿 미설정 시 서버 시작 실패
```

### Step 3: 파이프라인 스크립트 구성

```bash
#!/bin/bash
# run-pipeline.sh — 4단계 AI 에이전트 파이프라인
set -euo pipefail

SPEC_FILE="${1:-.ai-pipeline/specs/feature-auth.yaml}"
FEATURE_NAME=$(basename "$SPEC_FILE" .yaml)

echo "=== Stage 1: Generate ==="
claude -p "
다음 스펙을 읽고 구현해줘. 코드만 출력해.
$(cat "$SPEC_FILE")
" --output-file ".ai-pipeline/generated/${FEATURE_NAME}.ts"

echo "=== Stage 2: Review ==="
claude -p "
다음 코드를 리뷰해줘. JSON 형식으로 결과 출력해.
{\"issues\": [{\"severity\": \"high|medium|low\", \"line\": N, \"message\": \"...\", \"fix\": \"...\"}]}
$(cat ".ai-pipeline/generated/${FEATURE_NAME}.ts")
" --output-file ".ai-pipeline/review/${FEATURE_NAME}.json"

# 리뷰에서 high severity 발견 시 중단
HIGH_COUNT=$(jq '[.issues[] | select(.severity=="high")] | length' \
  ".ai-pipeline/review/${FEATURE_NAME}.json")
if [ "$HIGH_COUNT" -gt 0 ]; then
  echo "High severity issues found. Fixing..."
  claude -p "
다음 리뷰 피드백의 high severity 항목을 모두 수정해줘.
원본: $(cat ".ai-pipeline/generated/${FEATURE_NAME}.ts")
피드백: $(cat ".ai-pipeline/review/${FEATURE_NAME}.json")
" --output-file ".ai-pipeline/generated/${FEATURE_NAME}.ts"
fi

echo "=== Stage 3: Test ==="
claude -p "
다음 코드에 대한 테스트를 작성해줘.
테스트 기준: $(yq '.test_criteria[]' "$SPEC_FILE" | tr '\n' ', ')
코드: $(cat ".ai-pipeline/generated/${FEATURE_NAME}.ts")
" --output-file ".ai-pipeline/tests/${FEATURE_NAME}.test.ts"

echo "=== Stage 4: Pre-deploy ==="
claude -p "
다음 변경사항을 요약해줘.
- conventional commit 메시지 1줄
- PR 본문 (마크다운)
- CHANGELOG 항목 1줄
코드: $(cat ".ai-pipeline/generated/${FEATURE_NAME}.ts")
스펙: $(cat "$SPEC_FILE")
" --output-file ".ai-pipeline/deploy/${FEATURE_NAME}-summary.md"

echo "Pipeline complete: ${FEATURE_NAME}"
```

## 사용 방법

### 기본 실행

```bash
# 단일 기능 파이프라인 실행
./run-pipeline.sh .ai-pipeline/specs/feature-auth.yaml

# 여러 스펙 일괄 실행
for spec in .ai-pipeline/specs/*.yaml; do
  ./run-pipeline.sh "$spec"
done
```

### GitHub Actions 통합

CI에서 PR 이벤트에 반응해 자동 리뷰 + 테스트 보강을 실행할 수도 있어요.

```yaml
# .github/workflows/ai-pipeline.yml
name: AI Agent Pipeline
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: AI Review
        run: |
          # 변경된 파일에 대해 리뷰 에이전트 실행
          git diff origin/main --name-only -- '*.ts' '*.py' | while read file; do
            claude -p "이 파일을 리뷰해줘: $(cat $file)" \
              >> .ai-pipeline/review/pr-review.md
          done

      - name: AI Test Gap Analysis
        run: |
          # 커버리지 빈틈 분석
          npm test -- --coverage
          claude -p "커버리지 리포트를 분석하고 누락된 테스트를 제안해줘: \
            $(cat coverage/coverage-summary.json)"

      - name: Post Review Comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const review = fs.readFileSync('.ai-pipeline/review/pr-review.md', 'utf8');
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: review
            });
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `SPEC_FORMAT` | YAML | 스펙 파일 형식 (YAML, JSON, Markdown) |
| `MAX_RETRIES` | 2 | high severity 리뷰 발견 시 재생성 횟수 |
| `REVIEW_MODEL` | claude-sonnet | 리뷰 단계에 쓸 모델 (비용 절약용) |
| `SKIP_STAGES` | 없음 | 건너뛸 단계 (예: `review,test`) |
| `OUTPUT_DIR` | `.ai-pipeline/` | 산출물 저장 경로 |

### 단계별 모델 분리

비용을 줄이려면 각 단계에 다른 모델을 배정하는 것도 방법이에요.

```bash
# 생성은 고성능 모델, 리뷰와 테스트는 경량 모델
GENERATE_MODEL="claude-opus"
REVIEW_MODEL="claude-sonnet"
TEST_MODEL="claude-sonnet"
DEPLOY_MODEL="claude-haiku"
```

생성 단계에서만 비용을 집중하고, 나머지는 빠르고 저렴한 모델로 처리하면 전체 비용을 40~60% 줄일 수 있어요.

### 실패 시 롤백 전략

파이프라인 중간에 실패하면 어떻게 할지도 미리 정해둬야 해요.

```bash
# 각 단계의 출력을 git stash로 보호
git stash push -m "pipeline-${FEATURE_NAME}-stage-${STAGE}"

# 실패 시 복원
git stash pop
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| 생성 결과가 스펙과 다름 | 스펙 파일에 `constraints` 섹션을 더 구체적으로 작성 |
| 리뷰 에이전트가 false positive 다수 | 프로젝트 `CLAUDE.md`에 허용 패턴을 명시 |
| 테스트 생성이 기존 테스트와 충돌 | 기존 테스트 파일 경로를 컨텍스트로 함께 전달 |
| CI에서 타임아웃 | `--max-tokens` 제한 + 단계별 타임아웃 설정 |
| 여러 스펙 실행 시 컨텍스트 오염 | 각 스펙마다 새 세션으로 실행 (`claude -p`는 자동으로 분리) |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
