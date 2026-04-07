# AI 에이전트 자율 에러 복구 워크플로우

> 빌드/테스트 실패를 AI 에이전트가 자동으로 감지하고 수정하는 자율 복구 루프 설계

## 개요

CI 파이프라인이 깨지면 개발자는 로그를 읽고, 원인을 파악하고, 코드를 수정하고, 다시 푸시하는 과정을 반복해요. 이 과정이 하루에 여러 번 반복되면 생산성이 크게 떨어집니다.

이 워크플로우는 빌드 실패 → 원인 분석 → 수정 생성 → 검증 → PR 제출까지를 AI 에이전트가 자율적으로 수행하는 복구 루프를 구성합니다. 사람은 최종 PR만 리뷰하면 되고, 단순한 실패는 자동으로 해결됩니다.

핵심은 **실패 패턴별 분기 처리**와 **최대 재시도 횟수 제한**이에요. 무한 루프에 빠지지 않으면서도 대부분의 일상적인 실패를 자동으로 처리할 수 있습니다.

## 사전 준비

- CI/CD 파이프라인 (GitHub Actions, GitLab CI 등)
- AI 코딩 에이전트 (Claude Code, Aider 등)
- GitHub CLI (`gh`) 설치 및 인증
- 실패 로그에 접근 가능한 환경

## 설정

### Step 1: 실패 감지 스크립트

CI 실패를 감지하고 에이전트를 호출하는 진입점을 만듭니다.

```bash
#!/bin/bash
# scripts/auto-fix.sh — CI 실패 시 자동 복구 진입점

MAX_RETRIES=3
RETRY_COUNT=0

run_checks() {
  npm run build 2>&1 | tee /tmp/build-output.log
  BUILD_EXIT=${PIPESTATUS[0]}
  
  if [ $BUILD_EXIT -ne 0 ]; then
    echo "BUILD_FAIL"
    return 1
  fi
  
  npm test 2>&1 | tee /tmp/test-output.log
  TEST_EXIT=${PIPESTATUS[0]}
  
  if [ $TEST_EXIT -ne 0 ]; then
    echo "TEST_FAIL"
    return 2
  fi
  
  echo "ALL_PASS"
  return 0
}

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  RESULT=$(run_checks)
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 0 ]; then
    echo "모든 체크 통과"
    exit 0
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "실패 감지: $RESULT (시도 $RETRY_COUNT/$MAX_RETRIES)"
  
  # AI 에이전트에게 수정 요청
  scripts/request-fix.sh "$RESULT" "$RETRY_COUNT"
done

echo "최대 재시도 초과 — 수동 확인 필요"
exit 1
```

### Step 2: 실패 유형 분류기

실패 로그를 분석해서 수정 가능한 유형인지 판단합니다.

```yaml
# .ai-recovery/config.yaml
failure_categories:
  auto_fixable:
    - type_error          # 타입 불일치
    - import_missing      # 누락된 import
    - lint_violation      # 린트 규칙 위반
    - test_assertion      # 테스트 기대값 불일치
    - dependency_version  # 의존성 버전 충돌
    - syntax_error        # 구문 오류

  needs_review:
    - logic_error         # 비즈니스 로직 오류
    - security_issue      # 보안 관련 실패
    - performance_regression  # 성능 회귀
    - flaky_test          # 비결정적 테스트 실패

  skip:
    - infra_issue         # CI 인프라 문제
    - network_timeout     # 네트워크 타임아웃
    - rate_limit          # API 제한 초과

max_retries: 3
retry_delay_seconds: 10
```

### Step 3: 로그 분석 + 수정 요청 스크립트

```bash
#!/bin/bash
# scripts/request-fix.sh — 실패 로그를 AI 에이전트에게 전달

FAIL_TYPE=$1
RETRY_NUM=$2

# 로그 파일 선택
if [ "$FAIL_TYPE" = "BUILD_FAIL" ]; then
  LOG_FILE="/tmp/build-output.log"
else
  LOG_FILE="/tmp/test-output.log"
fi

# 로그 마지막 100줄 추출 (토큰 절약)
ERROR_LOG=$(tail -100 "$LOG_FILE")

# 이전 수정 이력 로드 (같은 실수 반복 방지)
HISTORY_FILE=".ai-recovery/fix-history.json"

# AI 에이전트에게 수정 요청
claude -p "
다음 CI 실패를 분석하고 수정해주세요.

실패 유형: $FAIL_TYPE
재시도 횟수: $RETRY_NUM

에러 로그:
$ERROR_LOG

규칙:
1. 에러 메시지에서 정확한 파일과 라인을 찾아서 수정
2. 수정은 최소 범위로 — 관련 없는 코드는 건드리지 않기
3. 수정 후 같은 테스트가 통과하는지 로컬에서 확인
4. 수정 이유를 한 줄로 설명
" --allowedTools Edit,Read,Bash
```

## 사용 방법

### GitHub Actions 연동

CI 파이프라인에 자동 복구 단계를 추가합니다.

```yaml
# .github/workflows/auto-recovery.yml
name: Auto Recovery

on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

jobs:
  auto-fix:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.head_branch }}

      - name: 실패 로그 다운로드
        run: |
          gh run view ${{ github.event.workflow_run.id }} \
            --log-failed > /tmp/ci-failure.log

      - name: 실패 유형 분류
        id: classify
        run: |
          python3 scripts/classify-failure.py /tmp/ci-failure.log

      - name: AI 자동 수정
        if: steps.classify.outputs.fixable == 'true'
        run: |
          scripts/auto-fix.sh

      - name: 수정 PR 생성
        if: success()
        run: |
          BRANCH="fix/auto-recovery-$(date +%s)"
          git checkout -b "$BRANCH"
          git add -A
          git commit -m "fix: auto-recovery for CI failure"
          git push origin "$BRANCH"
          gh pr create \
            --title "fix: CI 실패 자동 복구" \
            --body "자동 복구 워크플로우가 생성한 수정입니다." \
            --label "auto-fix"
```

### 실패 분류 스크립트

```python
# scripts/classify-failure.py
import sys
import re
import json

PATTERNS = {
    "type_error": [
        r"TypeError:", r"Type '.*' is not assignable",
        r"TS\d{4}:", r"Property .* does not exist"
    ],
    "import_missing": [
        r"Cannot find module", r"ModuleNotFoundError",
        r"ImportError:", r"Module not found"
    ],
    "lint_violation": [
        r"eslint", r"prettier", r"Lint error",
        r"flake8", r"ruff"
    ],
    "test_assertion": [
        r"AssertionError", r"Expected .* but received",
        r"expect\(.*\)\.to", r"assert .* =="
    ],
    "syntax_error": [
        r"SyntaxError:", r"Unexpected token",
        r"IndentationError:"
    ],
    "dependency_version": [
        r"peer dep", r"ERESOLVE", r"version conflict",
        r"incompatible"
    ]
}

AUTO_FIXABLE = {
    "type_error", "import_missing", "lint_violation",
    "test_assertion", "syntax_error", "dependency_version"
}

def classify(log_path):
    with open(log_path) as f:
        log = f.read()

    detected = []
    for category, patterns in PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, log, re.IGNORECASE):
                detected.append(category)
                break

    fixable = any(c in AUTO_FIXABLE for c in detected)

    print(f"::set-output name=categories::{json.dumps(detected)}")
    print(f"::set-output name=fixable::{'true' if fixable else 'false'}")

    return detected, fixable

if __name__ == "__main__":
    classify(sys.argv[1])
```

## 복구 루프 아키텍처

전체 흐름을 정리하면 이렇습니다.

| 단계 | 동작 | 실패 시 |
|------|------|---------|
| 1. 감지 | CI 실패 이벤트 수신 | — |
| 2. 분류 | 로그 패턴 매칭으로 유형 판별 | skip 유형이면 종료 |
| 3. 수정 | AI 에이전트가 코드 수정 생성 | 재시도 카운터 +1 |
| 4. 검증 | 로컬에서 빌드/테스트 재실행 | 3회 초과 시 수동 전환 |
| 5. 제출 | 수정 브랜치 + PR 생성 | PR 생성 실패 시 알림 |
| 6. 알림 | Slack/Discord로 결과 통보 | — |

## 가드레일 설정

자율 복구가 오히려 문제를 만들지 않도록 제한을 둡니다.

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 최대 재시도 | 3회 | 같은 실패에 대한 수정 시도 제한 |
| 수정 범위 제한 | 5파일 | 한 번에 수정할 수 있는 파일 수 상한 |
| diff 크기 제한 | 200줄 | 수정 diff가 이 이상이면 수동 전환 |
| 보안 파일 제외 | true | .env, secrets, 인증 관련 파일 수정 금지 |
| 자동 머지 | false | PR은 항상 사람이 리뷰 후 머지 |
| 쿨다운 | 10분 | 같은 브랜치에 대한 재시도 간격 |

```yaml
# .ai-recovery/guardrails.yaml
limits:
  max_retries: 3
  max_files_changed: 5
  max_diff_lines: 200
  cooldown_minutes: 10

excluded_paths:
  - "*.env*"
  - "*secret*"
  - "*credential*"
  - ".github/workflows/*"
  - "package-lock.json"
  - "yarn.lock"

require_human_review: true
auto_merge: false
```

## 수정 이력 추적

같은 실패를 반복 수정하지 않도록 이력을 관리합니다.

```json
// .ai-recovery/fix-history.json
{
  "fixes": [
    {
      "timestamp": "2026-04-07T12:00:00Z",
      "failure_type": "type_error",
      "file": "src/api/handler.ts",
      "line": 42,
      "fix_description": "Optional chaining 추가 — null 체크 누락",
      "retry_count": 1,
      "result": "pass"
    }
  ],
  "stats": {
    "total_fixes": 47,
    "success_rate": 0.83,
    "avg_retries": 1.4,
    "most_common_type": "type_error"
  }
}
```

이력 데이터가 쌓이면 어떤 유형의 실패가 자주 발생하는지, AI 수정 성공률은 얼마인지 파악할 수 있어요. 이 데이터를 바탕으로 프로젝트의 취약 포인트를 개선하는 게 진짜 목표입니다.

## 문제 해결

| 문제 | 해결 |
|------|------|
| AI가 같은 수정을 반복 | fix-history.json을 프롬프트에 포함해서 이전 시도를 알려주기 |
| 수정이 다른 테스트를 깨뜨림 | 수정 후 전체 테스트 스위트 실행, 실패 시 수정 롤백 |
| 린트 수정이 끝없이 반복 | 린트 자동 수정(`--fix`)을 먼저 시도하고 AI는 나머지만 처리 |
| 타임아웃으로 수정 미완료 | 복잡한 실패는 needs_review로 분류해서 수동 전환 |
| PR이 너무 많이 생성됨 | 같은 브랜치에 대한 수정은 기존 PR에 커밋 추가 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
