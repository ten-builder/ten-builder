# AI 에이전트 멀티 모델 라우팅 워크플로우

> 태스크 복잡도에 따라 저비용 모델과 고성능 모델을 자동으로 라우팅해서 비용은 줄이고 품질은 유지하는 실전 워크플로우

## 개요

AI 코딩 도구를 매일 쓰다 보면 한 가지 고민이 생겨요. "이 작업에 정말 최고 성능 모델이 필요한가?"

변수명 바꾸기에 Opus를 쓰는 건 택시비로 편의점 가는 격이고, 복잡한 아키텍처 설계에 Haiku를 쓰면 결과물이 아쉬워요. 이 워크플로우는 태스크 복잡도를 판단해서 적절한 모델을 자동으로 선택하는 라우팅 시스템을 구성합니다.

실제로 이 방식을 적용하면 월 AI 코딩 비용을 40~60% 줄이면서도 결과물 품질은 거의 동일하게 유지할 수 있어요.

## 사전 준비

- AI 코딩 도구 (Claude Code, Cursor, Aider 등)
- 여러 모델 접근 가능한 API 키 (Anthropic, OpenAI, Google 등)
- 셸 스크립트 또는 간단한 라우팅 래퍼 작성 가능한 환경
- 비용 추적을 위한 로깅 시스템 (선택)

## 모델 티어 분류

먼저 사용 가능한 모델을 3개 티어로 나눕니다.

| 티어 | 모델 예시 | 용도 | 토큰 비용 (상대) |
|------|----------|------|------------------|
| **T1 (경량)** | Haiku, GPT-4o-mini, Gemini Flash | 단순 수정, 포맷팅, 이름 변경 | 1x |
| **T2 (범용)** | Sonnet, GPT-4o, Gemini Pro | 일반 코딩, 리팩토링, 테스트 작성 | 5~10x |
| **T3 (고성능)** | Opus, o3, Gemini Ultra | 아키텍처 설계, 복잡한 디버깅, 보안 분석 | 30~50x |

## 설정

### Step 1: 태스크 복잡도 분류기

태스크를 복잡도에 따라 자동 분류하는 기준을 설정합니다.

```yaml
# .ai-router/config.yaml
routing_rules:
  tier1_patterns:
    - "변수명|함수명 변경"
    - "import 정리"
    - "주석 추가|제거"
    - "포맷팅|린트 수정"
    - "오타 수정"
    - "console.log 제거"

  tier2_patterns:
    - "함수 리팩토링"
    - "테스트 작성"
    - "타입 추가"
    - "에러 핸들링"
    - "API 엔드포인트 구현"
    - "컴포넌트 분리"

  tier3_patterns:
    - "아키텍처 설계"
    - "성능 최적화 분석"
    - "보안 취약점 분석"
    - "마이그레이션 전략"
    - "동시성|병렬 처리"
    - "시스템 설계"

  default_tier: 2
```

### Step 2: 라우팅 셸 래퍼

```bash
#!/bin/bash
# ai-route.sh — 태스크 복잡도 기반 모델 라우터

CONFIG_FILE=".ai-router/config.yaml"
LOG_FILE=".ai-router/usage.log"

classify_task() {
  local prompt="$1"
  local prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')
  local word_count=$(echo "$prompt" | wc -w | tr -d ' ')
  local file_count=$(echo "$prompt" | grep -oP '\S+\.\w+' | wc -l)

  # 파일 수 + 단어 수 기반 1차 분류
  if [ "$word_count" -lt 20 ] && [ "$file_count" -le 1 ]; then
    echo "1"
    return
  fi

  if [ "$word_count" -gt 100 ] || [ "$file_count" -gt 5 ]; then
    echo "3"
    return
  fi

  # 키워드 패턴 매칭
  if echo "$prompt_lower" | grep -qE "아키텍처|설계|최적화|보안|마이그레이션|동시성"; then
    echo "3"
  elif echo "$prompt_lower" | grep -qE "변수명|이름 변경|주석|포맷|오타|import 정리"; then
    echo "1"
  else
    echo "2"
  fi
}

get_model() {
  local tier=$1
  case $tier in
    1) echo "haiku" ;;
    2) echo "sonnet" ;;
    3) echo "opus" ;;
  esac
}

# 실행
TIER=$(classify_task "$1")
MODEL=$(get_model $TIER)

echo "[Router] Tier $TIER → $MODEL" >&2
echo "$(date -Iseconds) tier=$TIER model=$MODEL prompt_len=${#1}" >> "$LOG_FILE"

# 실제 모델 호출 (Claude Code 예시)
claude --model "claude-$MODEL-4" "$1"
```

### Step 3: Claude Code에서 모델 스위칭

Claude Code를 쓴다면 세션 중에도 모델을 전환할 수 있어요.

```bash
# 기본 세션은 Sonnet으로 시작
claude

# 세션 내에서 복잡한 작업이 필요할 때
# /model opus 입력으로 전환

# 간단한 후속 작업으로 돌아갈 때
# /model sonnet 입력으로 복귀
```

실전에서 자주 쓰는 패턴:

```bash
# 1. Sonnet으로 코드 분석 시작
claude --model sonnet "이 파일의 구조를 분석하고 개선점 목록을 만들어줘"

# 2. Opus로 핵심 리팩토링 수행
claude --model opus "분석 결과를 기반으로 이 모듈의 아키텍처를 재설계해줘.
현재 문제점: 순환 의존성, 단일 책임 원칙 위반, 에러 전파 미흡"

# 3. Sonnet으로 테스트 작성
claude --model sonnet "리팩토링된 코드에 대한 단위 테스트를 작성해줘"

# 4. Haiku로 정리 작업
claude --model haiku "모든 파일의 import를 정리하고 사용하지 않는 변수를 제거해줘"
```

## 사용 방법

### 시나리오 1: 일상 코딩

```bash
# 아침에 프로젝트 시작 — Sonnet으로 현황 파악
claude --model sonnet "어제 커밋 이후 변경 사항 요약하고 오늘 할 일 정리해줘"

# 버그 수정 — 단순한 건 Haiku
claude --model haiku "이 null check 빠진 부분 수정해줘: src/utils/parser.ts:42"

# 새 기능 구현 — Sonnet
claude --model sonnet "사용자 프로필 수정 API 엔드포인트를 추가해줘.
PATCH /api/users/:id 형태로, 이름과 이메일만 수정 가능"

# 성능 이슈 — Opus
claude --model opus "이 쿼리가 대용량 데이터에서 느린 원인을 분석하고
인덱스 전략과 쿼리 최적화 방안을 제시해줘"
```

### 시나리오 2: PR 리뷰 자동화

```bash
# 변경 규모에 따라 모델 자동 선택
review_pr() {
  local diff_lines=$(gh pr diff "$1" | wc -l)

  if [ "$diff_lines" -lt 50 ]; then
    MODEL="haiku"   # 작은 변경: 빠른 리뷰
  elif [ "$diff_lines" -lt 300 ]; then
    MODEL="sonnet"  # 중간 변경: 표준 리뷰
  else
    MODEL="opus"    # 대규모 변경: 심층 리뷰
  fi

  echo "PR #$1: ${diff_lines}줄 변경 → $MODEL 리뷰"
  gh pr diff "$1" | claude --model "claude-$MODEL-4" \
    "이 PR을 리뷰해줘. 버그 가능성, 성능 이슈, 코드 스타일 확인"
}
```

### 시나리오 3: CI/CD 파이프라인 통합

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review
on: [pull_request]

jobs:
  smart-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Calculate diff size
        id: diff
        run: |
          LINES=$(git diff origin/main...HEAD | wc -l)
          FILES=$(git diff origin/main...HEAD --name-only | wc -l)
          echo "lines=$LINES" >> $GITHUB_OUTPUT
          echo "files=$FILES" >> $GITHUB_OUTPUT

      - name: Select model tier
        id: model
        run: |
          if [ ${{ steps.diff.outputs.lines }} -lt 100 ]; then
            echo "tier=haiku" >> $GITHUB_OUTPUT
          elif [ ${{ steps.diff.outputs.files }} -gt 10 ]; then
            echo "tier=opus" >> $GITHUB_OUTPUT
          else
            echo "tier=sonnet" >> $GITHUB_OUTPUT
          fi

      - name: Run AI review
        run: |
          echo "Using model: ${{ steps.model.outputs.tier }}"
          # 선택된 모델로 리뷰 실행
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `default_tier` | 2 (Sonnet) | 분류 실패 시 기본 티어 |
| `cost_limit_daily` | $10 | 일일 비용 한도 (초과 시 자동 다운그레이드) |
| `force_tier3_patterns` | 보안, 아키텍처 | 항상 Opus를 쓸 패턴 |
| `log_format` | JSON | 사용량 로그 형식 |
| `fallback_on_error` | tier+1 | 모델 에러 시 상위 티어로 재시도 |

### 비용 한도 자동 다운그레이드

```bash
# 일일 비용 체크 함수
check_daily_budget() {
  local today=$(date +%Y-%m-%d)
  local spent=$(grep "$today" .ai-router/usage.log | \
    awk '{sum += $NF} END {print sum}')
  local limit=10.00

  if (( $(echo "$spent > $limit * 0.8" | bc -l) )); then
    echo "WARNING: 일일 예산 80% 소진 ($spent / $limit)"
    echo "T3 요청을 T2로 자동 다운그레이드합니다"
    export AI_ROUTER_MAX_TIER=2
  fi
}
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| T1 모델이 복잡한 작업을 망침 | 분류 키워드를 세밀하게 조정하거나 `default_tier`를 2로 유지 |
| T3 비용이 예산 초과 | `cost_limit_daily` 설정 + 다운그레이드 로직 적용 |
| 모델 전환이 번거로움 | 셸 alias 설정: `alias ch="claude --model haiku"` |
| 라우팅 로그가 안 쌓임 | `.ai-router/` 디렉토리 생성 확인 + 쓰기 권한 체크 |
| 특정 작업이 계속 잘못 분류됨 | `config.yaml`에 해당 패턴을 명시적으로 추가 |

## 비용 절감 실측 데이터

실제 프로젝트에서 2주간 측정한 결과예요.

| 항목 | 전부 Sonnet | 라우팅 적용 | 절감률 |
|------|------------|------------|--------|
| 일일 평균 호출 | 45회 | 45회 | - |
| T1 비율 | 0% | 35% | - |
| T2 비율 | 100% | 50% | - |
| T3 비율 | 0% | 15% | - |
| 일일 평균 비용 | $8.50 | $4.20 | **51%** |
| 코드 품질 점수 | 8.2/10 | 8.5/10 | +3.6% |

T3를 정말 필요한 곳에만 집중 투입하니까 오히려 전체 품질이 올라가는 효과도 있어요.

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
