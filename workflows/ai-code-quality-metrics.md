# AI 코드 품질 측정 워크플로우

> AI 코딩 에이전트가 생성한 코드의 품질을 자동으로 측정하고, 피드백 루프를 구축하는 워크플로우

## 개요

AI 에이전트가 코드를 생성하는 건 이제 일상이 됐어요. 하지만 **생성된 코드가 실제로 얼마나 좋은지** 측정하고 있나요? "잘 되는 것 같다"는 느낌이 아니라, 수치로 품질을 추적하고 개선하는 체계가 필요해요.

이 워크플로우는 AI가 만든 코드의 수용률, 생존율, 버그 밀도 같은 핵심 지표를 자동으로 수집하고, 그 데이터를 기반으로 프롬프트와 워크플로우를 개선하는 피드백 루프를 만들어요.

## 사전 준비

- Claude Code, Codex CLI, 또는 Cursor Agent 중 하나
- Git 레포 (로컬 클론, 최소 1달 이상의 커밋 히스토리)
- GitHub CLI (`gh`) 설치
- jq (JSON 처리용)
- 선택: ESLint, Pylint 등 정적 분석 도구

## 핵심 메트릭 정의

AI 코드 품질을 측정하는 5가지 핵심 지표예요.

| 메트릭 | 정의 | 측정 방법 | 목표 |
|--------|------|-----------|------|
| **수용률** (Acceptance Rate) | PR이 수정 없이 머지된 비율 | 머지 PR / 전체 PR | 70%+ |
| **생존율** (Survival Rate) | 머지 후 7일 내 되돌려지지 않은 비율 | (머지 - 리버트) / 머지 | 95%+ |
| **첫 리뷰 통과율** | 리뷰 코멘트 없이 approve된 비율 | approve PR / 리뷰 요청 PR | 50%+ |
| **버그 밀도** | AI 코드에서 발생한 버그 수 / KLOC | 이슈 태그 분석 | < 2.0 |
| **코드 체류 시간** | PR 생성 → 머지까지 평균 시간 | PR 타임스탬프 차이 | < 24h |

## Step 1: 메트릭 수집 스크립트

### PR 기반 메트릭 수집

```bash
#!/bin/bash
# ai-code-metrics.sh — AI 생성 PR의 품질 지표 수집

REPO="owner/repo"
SINCE="2026-02-01"

echo "=== AI 코드 품질 리포트 ==="
echo "기간: $SINCE ~ $(date +%Y-%m-%d)"
echo ""

# 전체 PR 수
TOTAL=$(gh api "repos/$REPO/pulls?state=all&per_page=100" \
  --jq "[.[] | select(.created_at >= \"$SINCE\")] | length")

# 머지된 PR 수
MERGED=$(gh api "repos/$REPO/pulls?state=closed&per_page=100" \
  --jq "[.[] | select(.merged_at != null and .created_at >= \"$SINCE\")] | length")

# 수용률 계산
if [ "$TOTAL" -gt 0 ]; then
  RATE=$(echo "scale=1; $MERGED * 100 / $TOTAL" | bc)
  echo "수용률: $RATE% ($MERGED/$TOTAL)"
else
  echo "수용률: N/A (PR 없음)"
fi
```

### 코드 생존율 체크

```bash
#!/bin/bash
# survival-check.sh — 머지 후 7일 내 리버트 여부 확인

REPO="owner/repo"
LOOKBACK_DAYS=30

# 최근 머지된 PR 목록
MERGED_PRS=$(gh api "repos/$REPO/pulls?state=closed&sort=updated&per_page=50" \
  --jq '.[] | select(.merged_at != null) | "\(.number)|\(.merged_at)|\(.title)"')

REVERT_COUNT=0
TOTAL_COUNT=0

while IFS='|' read -r PR_NUM MERGE_DATE TITLE; do
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  # 리버트 커밋 검색
  REVERTS=$(gh api "repos/$REPO/commits?since=$MERGE_DATE&per_page=100" \
    --jq "[.[] | select(.commit.message | test(\"revert.*#$PR_NUM\"; \"i\"))] | length")

  if [ "$REVERTS" -gt 0 ]; then
    REVERT_COUNT=$((REVERT_COUNT + 1))
    echo "  리버트 감지: PR #$PR_NUM — $TITLE"
  fi
done <<< "$MERGED_PRS"

SURVIVED=$((TOTAL_COUNT - REVERT_COUNT))
echo "생존율: $(echo "scale=1; $SURVIVED * 100 / $TOTAL_COUNT" | bc)%"
```

## Step 2: 정적 분석 자동화

AI가 만든 코드에 린터와 타입 체커를 자동으로 돌려서 문제를 조기에 잡아요.

### GitHub Actions 통합

```yaml
# .github/workflows/ai-code-quality.yml
name: AI Code Quality Gate

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  quality-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: 정적 분석
        run: |
          # 변경된 파일만 대상
          FILES=$(git diff --name-only origin/main -- '*.ts' '*.tsx' '*.js')

          if [ -n "$FILES" ]; then
            npx eslint $FILES --format json > eslint-report.json
            ERRORS=$(jq '[.[].errorCount] | add // 0' eslint-report.json)
            WARNINGS=$(jq '[.[].warningCount] | add // 0' eslint-report.json)

            echo "## 정적 분석 결과" >> $GITHUB_STEP_SUMMARY
            echo "- 에러: $ERRORS" >> $GITHUB_STEP_SUMMARY
            echo "- 경고: $WARNINGS" >> $GITHUB_STEP_SUMMARY
          fi

      - name: 복잡도 체크
        run: |
          # 순환 복잡도 측정
          npx complexity-report --format json src/ > complexity.json
          HIGH=$(jq '[.[] | select(.cyclomatic > 15)] | length' complexity.json)

          if [ "$HIGH" -gt 0 ]; then
            echo "::warning::복잡도 높은 함수 ${HIGH}개 감지"
          fi
```

### 커밋별 메트릭 기록

```bash
#!/bin/bash
# record-metrics.sh — 각 PR의 품질 데이터를 YAML로 기록

PR_NUMBER=$1
METRICS_FILE="metrics/pr-quality-log.yaml"

# PR 정보 수집
PR_DATA=$(gh api "repos/$REPO/pulls/$PR_NUMBER")
REVIEW_COMMENTS=$(echo "$PR_DATA" | jq '.review_comments')
ADDITIONS=$(echo "$PR_DATA" | jq '.additions')
DELETIONS=$(echo "$PR_DATA" | jq '.deletions')
CHANGED_FILES=$(echo "$PR_DATA" | jq '.changed_files')

# YAML 기록
cat >> "$METRICS_FILE" << EOF
- pr: $PR_NUMBER
  date: $(date -u +%Y-%m-%dT%H:%M:%S)
  lines_added: $ADDITIONS
  lines_deleted: $DELETIONS
  files_changed: $CHANGED_FILES
  review_comments: $REVIEW_COMMENTS
  lint_errors: $(jq '[.[].errorCount] | add // 0' eslint-report.json 2>/dev/null || echo 0)
  status: recorded
EOF
```

## Step 3: 피드백 루프 구축

데이터를 모았으면 이걸 실제 워크플로우 개선에 연결해야 해요.

### 주간 품질 리포트 생성 프롬프트

```
metrics/pr-quality-log.yaml를 분석해서 주간 AI 코드 품질 리포트를 만들어줘.

포함할 내용:
1. 이번 주 핵심 지표 변화 (수용률, 리뷰 코멘트 수 추이)
2. 가장 많이 지적된 코드 패턴 Top 3
3. 개선 제안 — 어떤 프롬프트나 설정을 바꾸면 품질이 올라갈지
4. 다음 주 중점 개선 영역

YAML 데이터만 보고 판단해줘.
```

### 품질 기반 프롬프트 개선 사이클

| 단계 | 액션 | 주기 |
|------|------|------|
| **수집** | PR 메트릭, 린트 결과, 리뷰 코멘트 자동 기록 | 매 PR |
| **분석** | 주간 리포트 생성, 패턴 분류 | 주 1회 |
| **개선** | CLAUDE.md 규칙 추가, 프롬프트 템플릿 수정 | 주 1회 |
| **검증** | 다음 주 지표로 개선 효과 확인 | 격주 |

### CLAUDE.md에 품질 규칙 반영하기

```markdown
# 프로젝트 CLAUDE.md에 추가할 품질 규칙 예시

## 코드 생성 규칙
- 함수 길이: 50줄 이내 (초과 시 분리)
- 순환 복잡도: 10 이하 유지
- 에러 핸들링: 모든 async 함수에 try-catch 포함
- 타입: any 사용 금지, 구체적 타입 명시

## 주간 리뷰 피드백 반영
- (2026-03-W11) 변수명이 너무 짧은 경우 다수 → 의미 있는 이름 사용
- (2026-03-W12) import 순서 불일치 → eslint import/order 규칙 따르기
```

## Step 4: 대시보드 시각화

터미널에서 바로 확인할 수 있는 간단한 대시보드예요.

```bash
#!/bin/bash
# quality-dashboard.sh — 터미널 품질 대시보드

echo "╔══════════════════════════════════════╗"
echo "║     AI 코드 품질 대시보드             ║"
echo "╠══════════════════════════════════════╣"

# 이번 주 수치 (metrics 파일에서 읽기)
THIS_WEEK=$(yq '[.[] | select(.date >= "'$(date -v-7d +%Y-%m-%d)'")] | length' metrics/pr-quality-log.yaml)
ACCEPTED=$(yq '[.[] | select(.date >= "'$(date -v-7d +%Y-%m-%d)'" and .status == "merged")] | length' metrics/pr-quality-log.yaml)

echo "║ 이번 주 PR:        $THIS_WEEK개"
echo "║ 수용률:            $(echo "scale=0; $ACCEPTED * 100 / $THIS_WEEK" | bc)%"
echo "║ 평균 리뷰 코멘트:  $(yq '[.[] | select(.date >= "'$(date -v-7d +%Y-%m-%d)'") | .review_comments] | add / length' metrics/pr-quality-log.yaml)"
echo "╚══════════════════════════════════════╝"
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 수용률 목표 | 70% | 팀/프로젝트에 맞게 조정 |
| 리포트 주기 | 주 1회 | 빠른 반복이 필요하면 일 1회 |
| 복잡도 임계값 | 15 | 엄격한 팀은 10으로 설정 |
| 생존율 체크 기간 | 7일 | 릴리스 주기에 맞게 조정 |
| 메트릭 보존 기간 | 90일 | 장기 트렌드 분석은 365일 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| PR 데이터가 안 모아짐 | `gh auth status` 확인, API rate limit 체크 |
| 린트 결과 불일치 | ESLint 버전과 프로젝트 설정 파일 경로 확인 |
| 리포트 수치가 비현실적 | 봇 PR과 사람 PR을 필터링했는지 확인 |
| 생존율 100%인데 의심스러움 | 리버트가 직접 커밋으로 이뤄진 경우 `revert` 키워드 패턴 확인 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
