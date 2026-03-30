# 42. AI 코딩 벤치마크 실전 측정 가이드

> 숫자를 읽는 데서 그치지 말고, 직접 돌려보세요. 팀에 맞는 에이전트를 고르는 가장 확실한 방법이에요.

## 왜 직접 측정해야 하나

벤치마크 리더보드 점수만으로 도구를 고르면 실패하기 쉬워요. SWE-bench에서 1등인 에이전트가 우리 프로젝트에서는 3등일 수 있어요. 이유는 간단합니다 — 벤치마크 태스크와 실제 업무 태스크는 다르기 때문이에요.

이 가이드에서는 주요 벤치마크를 직접 실행하고, 나만의 평가 셋을 만들어서 팀에 최적인 에이전트를 고르는 과정을 다뤄요.

## 소요 시간

60-90분 (환경 설정 포함)

## 사전 준비

- Python 3.10 이상
- Docker Desktop (SWE-bench 실행 시 필요)
- AI 코딩 에이전트 2개 이상 (비교 대상)
- GitHub Personal Access Token (SWE-bench 데이터셋 접근)

## Step 1: 벤치마크 환경 구축

### BigCode Evaluation Harness (HumanEval + MBPP)

```bash
# 설치
git clone https://github.com/bigcode-project/bigcode-evaluation-harness
cd bigcode-evaluation-harness
pip install -e .

# HumanEval 실행 (예: 로컬 모델)
accelerate launch main.py \
  --model your-model-name \
  --tasks humaneval \
  --do_sample True \
  --temperature 0.2 \
  --n_samples 1 \
  --batch_size 1 \
  --allow_code_execution
```

### SWE-bench Lite 로컬 실행

```bash
# SWE-bench 설치
git clone https://github.com/princeton-nlp/SWE-bench
cd SWE-bench
pip install -e .

# Docker 기반 평가 환경 (추천)
pip install swebench[docker]

# 데이터셋 다운로드 (Lite: 300개 태스크)
python -c "
from datasets import load_dataset
ds = load_dataset('princeton-nlp/SWE-bench_Lite')
print(f'태스크 수: {len(ds[\"test\"])}')
"
```

### BigCodeBench (HumanEval 후속)

```bash
# BigCodeBench는 실무에 가까운 태스크를 포함
pip install bigcodebench

# 실행
bigcodebench.evaluate \
  --model your-model \
  --subset full \
  --backend openai
```

## Step 2: 나만의 평가 셋 만들기

리더보드 벤치마크보다 실무에 가까운 평가 셋을 만드는 것이 핵심이에요.

### 평가 태스크 설계 기준

| 기준 | 설명 | 예시 |
|------|------|------|
| 실제 코드베이스 | 우리 레포의 실제 이슈 | `fix: login API 500 error` |
| 난이도 분산 | 쉬움/보통/어려움 균등 배분 | 함수 1개 ~ 파일 5개 변경 |
| 검증 가능 | 테스트로 통과/실패 판단 가능 | 기존 테스트 스위트 활용 |
| 반복 가능 | 같은 조건에서 재실행 가능 | Docker 환경, 고정 프롬프트 |

### 평가 셋 YAML 템플릿

```yaml
# eval-tasks.yaml
tasks:
  - id: task-001
    difficulty: easy
    description: "UserService에 이메일 중복 체크 메서드 추가"
    repo: our-project
    branch: main
    commit: abc1234
    test_command: "pytest tests/test_user_service.py -k test_email_duplicate"
    expected_files_changed:
      - src/services/user_service.py
    max_time_seconds: 120

  - id: task-002
    difficulty: medium
    description: "주문 API에서 동시성 이슈로 재고가 음수가 되는 버그 수정"
    repo: our-project
    branch: main
    commit: def5678
    test_command: "pytest tests/test_order_concurrency.py"
    expected_files_changed:
      - src/services/order_service.py
      - src/models/inventory.py
    max_time_seconds: 300

  - id: task-003
    difficulty: hard
    description: "결제 모듈을 Strategy 패턴으로 리팩토링하고 새 PG사 추가"
    repo: our-project
    branch: main
    commit: ghi9012
    test_command: "pytest tests/test_payment/ -v"
    expected_files_changed:
      - src/payment/strategy.py
      - src/payment/providers/*.py
      - tests/test_payment/test_new_provider.py
    max_time_seconds: 600
```

### 태스크 수집 방법

```bash
# 최근 머지된 PR에서 태스크 후보 추출
gh pr list --repo our-org/our-project \
  --state merged \
  --limit 50 \
  --json number,title,changedFiles,additions,deletions \
  --jq '.[] | select(.additions < 200) | "\(.number) \(.title) (+\(.additions)/-\(.deletions))"'
```

좋은 태스크 후보:
- 변경 파일 1~5개
- 추가/삭제 합계 200줄 이하
- 테스트가 포함된 PR
- 버그 수정 또는 기능 추가

## Step 3: 에이전트별 실행 자동화

### 실행 스크립트

```bash
#!/bin/bash
# run-eval.sh — 에이전트별 벤치마크 실행

AGENTS=("claude-code" "cursor" "codex-cli")
TASKS_FILE="eval-tasks.yaml"
RESULTS_DIR="eval-results/$(date +%Y%m%d)"

mkdir -p "$RESULTS_DIR"

for agent in "${AGENTS[@]}"; do
  echo "=== $agent 평가 시작 ==="

  # 태스크별 실행
  for task_id in $(yq '.tasks[].id' "$TASKS_FILE"); do
    echo "  Task: $task_id"

    # 클린 환경 준비 (Docker)
    docker run --rm -v "$(pwd):/workspace" eval-env:latest \
      bash -c "
        cd /workspace
        git checkout \$(yq \".tasks[] | select(.id == \\\"$task_id\\\") | .commit\" $TASKS_FILE)

        # 시작 시간 기록
        START=\$(date +%s)

        # 에이전트 실행 (에이전트별 래퍼)
        ./agent-wrapper.sh $agent \"\$(yq \".tasks[] | select(.id == \\\"$task_id\\\") | .description\" $TASKS_FILE)\"

        # 종료 시간
        END=\$(date +%s)
        ELAPSED=\$((END - START))

        # 테스트 실행
        TEST_CMD=\$(yq \".tasks[] | select(.id == \\\"$task_id\\\") | .test_command\" $TASKS_FILE)
        eval \$TEST_CMD > /tmp/test-result.txt 2>&1
        TEST_EXIT=\$?

        # 결과 저장
        echo \"{
          \\\"agent\\\": \\\"$agent\\\",
          \\\"task\\\": \\\"$task_id\\\",
          \\\"passed\\\": \$([[ \$TEST_EXIT -eq 0 ]] && echo true || echo false),
          \\\"time_seconds\\\": \$ELAPSED,
          \\\"test_output\\\": \\\"\$(cat /tmp/test-result.txt | head -20)\\\"
        }\" > /workspace/$RESULTS_DIR/${agent}_${task_id}.json
      "
  done
done
```

### 에이전트 래퍼 예시

```bash
#!/bin/bash
# agent-wrapper.sh — 에이전트별 실행 추상화

AGENT=$1
PROMPT=$2

case $AGENT in
  "claude-code")
    echo "$PROMPT" | claude --dangerously-skip-permissions
    ;;
  "codex-cli")
    echo "$PROMPT" | codex --approval-mode full-auto
    ;;
  "aider")
    aider --message "$PROMPT" --yes-always --no-auto-commits
    ;;
esac
```

## Step 4: 결과 분석

### 핵심 메트릭 5가지

| 메트릭 | 계산 방법 | 좋은 기준 |
|--------|----------|----------|
| Pass Rate | 통과 태스크 / 전체 태스크 | 60% 이상 |
| 평균 소요 시간 | 통과 태스크만의 평균 시간 | 난이도별 상이 |
| First-try Pass | 재시도 없이 통과한 비율 | 40% 이상 |
| 토큰 효율성 | 통과당 사용 토큰 수 | 낮을수록 좋음 |
| 비용 효율성 | 통과당 API 비용 (USD) | 팀 예산에 따라 |

### 분석 스크립트

```python
import json
import glob
from collections import defaultdict

def analyze_results(results_dir: str) -> dict:
    """에이전트별 벤치마크 결과를 분석합니다."""
    results = defaultdict(lambda: {"passed": 0, "failed": 0, "times": []})

    for filepath in glob.glob(f"{results_dir}/*.json"):
        with open(filepath) as f:
            data = json.load(f)

        agent = data["agent"]
        if data["passed"]:
            results[agent]["passed"] += 1
            results[agent]["times"].append(data["time_seconds"])
        else:
            results[agent]["failed"] += 1

    # 요약 출력
    print(f"{'에이전트':<15} {'Pass Rate':<12} {'평균 시간':<12} {'총 비용'}")
    print("-" * 55)

    for agent, stats in sorted(results.items()):
        total = stats["passed"] + stats["failed"]
        rate = stats["passed"] / total * 100 if total > 0 else 0
        avg_time = (
            sum(stats["times"]) / len(stats["times"])
            if stats["times"]
            else 0
        )
        print(f"{agent:<15} {rate:>5.1f}%      {avg_time:>6.1f}s")

    return dict(results)

# 사용
analyze_results("eval-results/20260331")
```

### 레이더 차트 비교

```python
import matplotlib.pyplot as plt
import numpy as np

def radar_chart(agents_data: dict):
    """에이전트별 5축 레이더 차트를 그립니다."""
    categories = ["Pass Rate", "속도", "토큰 효율", "비용 효율", "난이도 커버리지"]
    N = len(categories)

    angles = [n / float(N) * 2 * np.pi for n in range(N)]
    angles += angles[:1]

    fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(polar=True))

    for agent, scores in agents_data.items():
        values = scores + scores[:1]
        ax.plot(angles, values, linewidth=2, label=agent)
        ax.fill(angles, values, alpha=0.1)

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(categories, size=11)
    ax.legend(loc="upper right", bbox_to_anchor=(1.3, 1.1))
    plt.title("AI 코딩 에이전트 비교", size=14, y=1.08)
    plt.savefig("agent-comparison-radar.png", dpi=150, bbox_inches="tight")

# 사용 예시 (각 축 0-100 스케일)
radar_chart({
    "Claude Code": [85, 70, 75, 60, 90],
    "Cursor Agent": [75, 85, 65, 70, 80],
    "Codex CLI": [70, 90, 80, 85, 65],
})
```

## Step 5: 팀 내 벤치마크 운영

### 월간 벤치마크 루틴

```yaml
# .github/workflows/monthly-eval.yml
name: Monthly AI Agent Evaluation
on:
  schedule:
    - cron: '0 9 1 * *'  # 매월 1일 09:00
  workflow_dispatch:

jobs:
  evaluate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup evaluation environment
        run: |
          pip install -r eval-requirements.txt
          docker pull eval-env:latest

      - name: Run benchmarks
        run: python run_eval.py --agents all --tasks eval-tasks.yaml

      - name: Generate report
        run: python analyze_results.py --format markdown > report.md

      - name: Post to Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload-file-path: report.md
```

### 태스크 셋 관리 원칙

| 원칙 | 설명 |
|------|------|
| 분기 갱신 | 3개월마다 태스크 20% 교체 (새 이슈 반영) |
| 난이도 균형 | easy 40% / medium 40% / hard 20% 유지 |
| 언어 비율 | 프로젝트 실제 비율과 일치시키기 |
| 시크릿 분리 | API 키, DB 크레덴셜은 평가 환경에서 모킹 |
| 결과 보관 | 최소 6개월 히스토리 유지 (트렌드 분석) |

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| 리더보드 점수만 보고 도입 | 우리 코드베이스로 직접 테스트 |
| 동일 프롬프트로 비교 안 함 | 모든 에이전트에 같은 태스크 설명 사용 |
| 네트워크 상태 무시 | Docker로 환경 고정, API 응답 시간 별도 측정 |
| 비용 계산 빠뜨림 | 토큰 사용량 + API 호출 횟수 함께 기록 |
| 한 번만 실행 | 최소 3회 실행 후 평균값 사용 (LLM 비결정성) |
| 쉬운 태스크만 테스트 | 난이도 분산 필수, hard 태스크에서 차이가 큼 |

## 체크리스트

- [ ] BigCode Evaluation Harness 또는 SWE-bench 환경 구축 완료
- [ ] 우리 프로젝트 기반 커스텀 평가 태스크 10개 이상 작성
- [ ] 비교 대상 에이전트 2개 이상 선정
- [ ] 동일 프롬프트 + Docker 환경에서 3회 이상 실행
- [ ] 5축 메트릭(Pass Rate, 속도, 토큰, 비용, 난이도 커버리지) 측정 완료
- [ ] 결과 분석 리포트 작성 및 팀 공유

## 다음 단계

→ [AI 코딩 에이전트 벤치마크 해석 가이드](./34-ai-benchmark-guide.md) — 리더보드 점수를 올바르게 읽는 법
→ [AI 코딩 에이전트 평가 프레임워크](./32-ai-agent-evaluation-framework.md) — 5축 모델로 체계적 비교

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
