# 플레이북 42: AI 생성 코드 신뢰성 검증 파이프라인

> 84%가 쓰지만 29%만 신뢰하는 AI 생성 코드 — 체계적인 검증 파이프라인으로 품질을 보증하는 실전 가이드

## 소요 시간

20-30분 (프로젝트 규모에 따라 조정)

## 사전 준비

- AI 코딩 에이전트 설치 완료 (Claude Code, Cursor, Aider 등)
- 프로젝트에 테스트 프레임워크 설정 완료 (Jest, pytest, Go test 등)
- Git 기본 워크플로우 이해
- CI/CD 파이프라인 접근 권한

## 왜 이 플레이북이 필요한가

2026년 기준, 개발자의 84%가 AI 코딩 도구를 사용하고 있지만 AI가 생성한 코드를 신뢰한다는 응답은 29%에 불과해요. Sonar의 조사에 따르면 96%의 개발자가 AI 코드를 수동으로 검증하고 있고, 이 검증 과정이 오히려 생산성 병목이 되고 있죠.

문제는 "AI 코드를 안 쓸 수 없다"는 점이에요. 속도 이점이 너무 크기 때문에. 대신 검증을 체계화해서 빠르게 신뢰할 수 있는 구조를 만들어야 해요.

## Step 1: 검증 레벨 정의

모든 AI 생성 코드에 동일한 수준의 검증을 적용하면 비효율적이에요. 변경의 위험도에 따라 3단계로 구분해요.

| 레벨 | 대상 | 검증 항목 | 예시 |
|------|------|----------|------|
| **L1 (경량)** | 설정, 문서, 포맷팅 | 린트 + 빌드 | `.gitignore`, README, CSS 조정 |
| **L2 (표준)** | 일반 기능 코드 | L1 + 단위 테스트 + 타입 체크 | API 엔드포인트, 컴포넌트, 유틸 |
| **L3 (심층)** | 보안, 인프라, 결제 | L2 + 통합 테스트 + 수동 리뷰 | 인증 로직, DB 마이그레이션, 결제 |

```bash
# 변경 파일 기준으로 검증 레벨 자동 판별하는 스크립트 예시
#!/bin/bash
changed_files=$(git diff --name-only HEAD~1)

for file in $changed_files; do
  case "$file" in
    *.md|*.txt|*.css|.gitignore)
      echo "L1: $file"
      ;;
    *auth*|*payment*|*migration*|*security*)
      echo "L3: $file"
      ;;
    *)
      echo "L2: $file"
      ;;
  esac
done
```

## Step 2: 자동 검증 게이트 구성

AI가 코드를 생성한 직후, 커밋 전에 자동으로 실행되는 검증 게이트를 설정해요.

### Pre-commit 훅 설정

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: ai-code-verify
        name: AI 코드 검증
        entry: ./scripts/verify-ai-code.sh
        language: script
        stages: [commit]
```

### 검증 스크립트

```bash
#!/bin/bash
# scripts/verify-ai-code.sh
set -e

echo "=== AI 코드 검증 시작 ==="

# 1단계: 정적 분석
echo "[1/4] 린트 검사..."
npm run lint 2>&1 | tail -5

# 2단계: 타입 체크
echo "[2/4] 타입 검사..."
npx tsc --noEmit 2>&1 | tail -5

# 3단계: 변경된 파일 관련 테스트 실행
echo "[3/4] 관련 테스트 실행..."
changed=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ts|tsx|js|jsx)$' || true)
if [ -n "$changed" ]; then
  npx jest --findRelatedTests $changed --passWithNoTests
fi

# 4단계: 보안 패턴 스캔
echo "[4/4] 보안 패턴 검사..."
patterns="eval(|exec(|__import__|subprocess\.call|os\.system"
if echo "$changed" | xargs grep -lE "$patterns" 2>/dev/null; then
  echo "⚠️ 위험 패턴 감지 — L3 수동 리뷰 필요"
  exit 1
fi

echo "=== 검증 통과 ==="
```

## Step 3: AI 에이전트에게 테스트 생성 위임

AI가 코드를 만들었다면, 테스트도 AI가 만들게 하되 검증 기준은 사람이 정해요.

```bash
# Claude Code에서 테스트 생성 + 검증 프롬프트 패턴

# 1. 기능 코드 생성 후 즉시 테스트 요청
"방금 만든 UserService에 대해 테스트를 작성해줘.
조건:
- 정상 케이스 3개 이상
- 에러 케이스 2개 이상 (잘못된 입력, 네트워크 실패)
- 엣지 케이스 1개 이상 (빈 배열, null, 경계값)
- 모든 public 메서드 커버"

# 2. 테스트 실행 확인
"테스트를 실행하고 결과를 보여줘.
실패하는 테스트가 있으면 코드를 수정해줘 (테스트를 수정하지 말고)."
```

| 상황 | 프롬프트 패턴 | 기대 효과 |
|------|-------------|----------|
| 새 기능 추가 | "기능 구현 후 테스트부터 작성해줘" | TDD 흐름 유도 |
| 버그 수정 | "버그 재현 테스트 먼저, 그다음 수정" | 회귀 방지 |
| 리팩토링 | "기존 테스트 전부 통과 확인 후 진행" | 동작 보존 확인 |

## Step 4: Diff 기반 코드 리뷰 자동화

AI가 만든 코드의 diff를 다른 AI(또는 같은 AI의 다른 세션)로 교차 검증하는 패턴이에요.

```bash
# PR 생성 시 자동으로 diff 요약 + 위험도 평가 실행
gh pr diff $PR_NUMBER | head -500 > /tmp/pr-diff.txt

# 교차 검증 프롬프트
cat <<'EOF'
이 diff를 리뷰해줘. 다음 관점에서 문제를 찾아줘:

1. **로직 오류**: 조건문, 루프, 경계값 처리
2. **보안 취약점**: 인젝션, 하드코딩 시크릿, 안전하지 않은 역직렬화
3. **성능 문제**: N+1 쿼리, 불필요한 재렌더링, 메모리 누수 패턴
4. **일관성**: 기존 코드 스타일과의 불일치

각 항목에 대해 "통과" 또는 "문제 발견: [설명]"으로 답변해줘.
EOF
```

### CI에 리뷰 봇 추가

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: 변경 규모 체크
        run: |
          ADDITIONS=$(git diff --stat origin/main...HEAD | tail -1 | awk '{print $4}')
          if [ "$ADDITIONS" -gt 500 ]; then
            echo "⚠️ 500줄 이상 변경 — 분할 PR 권장"
            echo "large_change=true" >> $GITHUB_ENV
          fi
      - name: 보안 패턴 스캔
        run: |
          git diff origin/main...HEAD -- '*.ts' '*.js' '*.py' | \
            grep -E '(eval\(|exec\(|password.*=.*["\x27]|api_key.*=)' && \
            echo "::warning::보안 민감 패턴 감지" || true
```

## Step 5: 검증 메트릭 추적

검증 파이프라인의 효과를 측정하려면 메트릭을 추적해야 해요.

| 메트릭 | 측정 방법 | 목표 |
|--------|----------|------|
| **첫 시도 통과율** | CI 통과/전체 PR 비율 | > 80% |
| **검증 소요 시간** | CI 파이프라인 실행 시간 | < 5분 |
| **사후 버그 발견율** | 머지 후 7일 내 핫픽스 비율 | < 5% |
| **L3 리뷰 비율** | L3 판정 PR / 전체 PR | < 15% |

```bash
# 간단한 추적: PR 라벨로 검증 레벨 기록
gh pr edit $PR_NUMBER --add-label "verify:L2"

# 월간 리포트 생성
gh pr list --state closed --limit 100 --json labels,mergedAt | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
levels = {'L1':0, 'L2':0, 'L3':0}
for pr in data:
  for label in pr.get('labels',[]):
    name = label.get('name','')
    if name.startswith('verify:'):
      levels[name.split(':')[1]] = levels.get(name.split(':')[1], 0) + 1
print('검증 레벨 분포:', levels)
"
```

## 체크리스트

- [ ] 검증 레벨(L1/L2/L3) 기준 팀과 합의
- [ ] Pre-commit 훅에 자동 검증 스크립트 연결
- [ ] AI 코드 생성 시 테스트 동시 생성 프롬프트 표준화
- [ ] CI에 diff 기반 자동 리뷰 게이트 추가
- [ ] 보안 민감 경로 L3 자동 분류 설정
- [ ] 월간 검증 메트릭 리뷰 일정 등록

## 핵심 원칙 정리

1. **모든 AI 코드에 같은 검증을 하지 말 것** — 위험도 기반 분류가 핵심
2. **AI가 만든 코드는 AI가 테스트도 만들게 할 것** — 단, 기준은 사람이 정함
3. **교차 검증을 자동화할 것** — 같은 AI라도 다른 세션에서 리뷰하면 실수를 잡아냄
4. **메트릭을 추적할 것** — 감이 아니라 데이터로 신뢰 수준 판단

## 다음 단계

→ [플레이북 39: 코드베이스 헬스체크](./39-codebase-health-check.md) — 검증 파이프라인과 함께 코드베이스 전체 건강 상태를 진단
→ [플레이북 34: AI 코드 생성 검증](./34-ai-code-generation-validation.md) — 개별 코드 생성 단계의 검증 전략

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
