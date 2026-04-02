# AI 프롬프트 회귀 테스트 파이프라인

> 프롬프트를 바꿨는데 결과가 이상해졌다? 프롬프트 변경의 품질 영향을 자동으로 검증하는 회귀 테스트 파이프라인을 만들어 봐요.

## 개요

AI 코딩 에이전트의 프롬프트(시스템 프롬프트, 규칙 파일, 커스텀 명령)를 수정하면 예기치 않은 품질 저하가 발생할 수 있어요:

- 코드 스타일이 갑자기 달라짐
- 이전에 잘 되던 작업이 실패함
- 응답 길이나 토큰 사용량이 급변함
- 특정 언어/프레임워크 지원이 빠짐

이 워크플로우는 프롬프트 변경 시 자동으로 테스트 케이스를 실행하고 결과를 비교해서, 배포 전에 문제를 잡는 파이프라인이에요.

## 사전 준비

- AI 코딩 에이전트 (Claude Code, Cursor, Codex CLI 등)
- Python 3.10+ (테스트 러너)
- GitHub Actions 또는 CI 환경
- (선택) LLM Judge용 API 키 (GPT-4o, Claude 등)

## 아키텍처

```
프롬프트 변경 (PR)
       ↓
┌─────────────────────┐
│   테스트 케이스 실행  │ ← 골든 데이터셋 (입력 + 기대 출력)
│   (Baseline vs New)  │
└─────────┬───────────┘
          ↓
┌─────────────────────┐
│    결과 비교 & 채점   │ ← 정확 매칭 / 시맨틱 유사도 / LLM Judge
└─────────┬───────────┘
          ↓
┌─────────────────────┐
│   리포트 생성 & 게이트 │ ← 품질 점수 < 임계값이면 PR 블록
└─────────────────────┘
```

## 설정

### Step 1: 골든 데이터셋 구성

테스트 케이스는 "입력(프롬프트) → 기대 출력" 쌍으로 관리해요.

```yaml
# tests/prompt-regression/golden-dataset.yaml
test_cases:
  - id: "react-component-basic"
    description: "기본 React 컴포넌트 생성"
    input: "Create a React button component with onClick handler and loading state"
    expected_patterns:
      - "useState"
      - "onClick"
      - "loading"
      - "disabled={loading}"
    expected_language: "tsx"
    category: "code-generation"
    
  - id: "python-fastapi-endpoint"
    description: "FastAPI 엔드포인트 생성"
    input: "Create a FastAPI POST endpoint for user registration with email validation"
    expected_patterns:
      - "from fastapi"
      - "@app.post"
      - "EmailStr"
      - "BaseModel"
    expected_language: "python"
    category: "code-generation"

  - id: "debug-null-reference"
    description: "Null Reference 디버깅"
    input: |
      Fix the NullReferenceException in this C# code:
      ```csharp
      public string GetUserName(User user) {
          return user.Profile.Name.ToUpper();
      }
      ```
    expected_patterns:
      - "null"
      - "?."
    not_expected:
      - "try.*catch"
    category: "debugging"

  - id: "code-review-security"
    description: "보안 이슈 탐지"
    input: |
      Review this code for security issues:
      ```python
      query = f"SELECT * FROM users WHERE id = {user_id}"
      cursor.execute(query)
      ```
    expected_patterns:
      - "SQL injection"
      - "parameterized"
    severity: "critical"
    category: "code-review"

  - id: "refactor-extract-function"
    description: "함수 추출 리팩토링"
    input: |
      Refactor this code to extract repeated validation logic:
      ```javascript
      function createUser(name, email) {
        if (!name || name.length < 2) throw new Error('Invalid name');
        if (!email || !email.includes('@')) throw new Error('Invalid email');
        // ... create user
      }
      function updateUser(name, email) {
        if (!name || name.length < 2) throw new Error('Invalid name');
        if (!email || !email.includes('@')) throw new Error('Invalid email');
        // ... update user
      }
      ```
    expected_patterns:
      - "function validate"
    category: "refactoring"
```

### Step 2: 테스트 러너 구현

```python
# scripts/prompt_regression_runner.py
"""프롬프트 회귀 테스트 러너 — 골든 데이터셋으로 품질 검증"""

import json
import subprocess
import time
import yaml
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


@dataclass
class TestResult:
    test_id: str
    category: str
    passed: bool
    score: float  # 0.0 ~ 1.0
    pattern_matches: dict = field(default_factory=dict)
    output_length: int = 0
    latency_ms: int = 0
    error: Optional[str] = None


def load_golden_dataset(path: str) -> list[dict]:
    """골든 데이터셋 YAML 로드"""
    with open(path) as f:
        data = yaml.safe_load(f)
    return data["test_cases"]


def run_agent_prompt(prompt: str, system_prompt_path: str = None) -> tuple[str, int]:
    """AI 에이전트에 프롬프트 전달 후 결과 수집"""
    start = time.monotonic()

    cmd = ["claude", "--print", "--no-input"]
    if system_prompt_path:
        cmd.extend(["--system-prompt", system_prompt_path])
    cmd.extend(["--prompt", prompt])

    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=120
    )
    elapsed_ms = int((time.monotonic() - start) * 1000)
    return result.stdout, elapsed_ms


def check_patterns(output: str, expected: list[str], not_expected: list[str] = None) -> dict:
    """패턴 매칭 검사 — 기대 패턴 포함 여부와 금지 패턴 미포함 여부"""
    results = {}
    output_lower = output.lower()

    for pattern in expected:
        results[f"+{pattern}"] = pattern.lower() in output_lower

    for pattern in (not_expected or []):
        results[f"-{pattern}"] = pattern.lower() not in output_lower

    return results


def calculate_score(pattern_results: dict) -> float:
    """패턴 매칭 결과로 점수 계산 (0.0 ~ 1.0)"""
    if not pattern_results:
        return 0.0
    passed = sum(1 for v in pattern_results.values() if v)
    return passed / len(pattern_results)


def run_regression_suite(
    dataset_path: str,
    system_prompt_path: str = None,
    output_path: str = "regression-results.json",
) -> list[TestResult]:
    """전체 회귀 테스트 스위트 실행"""
    cases = load_golden_dataset(dataset_path)
    results = []

    for case in cases:
        print(f"  Running: {case['id']}...", end=" ", flush=True)

        try:
            output, latency = run_agent_prompt(
                case["input"], system_prompt_path
            )
            patterns = check_patterns(
                output,
                case.get("expected_patterns", []),
                case.get("not_expected", []),
            )
            score = calculate_score(patterns)

            result = TestResult(
                test_id=case["id"],
                category=case.get("category", "general"),
                passed=score >= 0.7,
                score=score,
                pattern_matches=patterns,
                output_length=len(output),
                latency_ms=latency,
            )
            print(f"{'PASS' if result.passed else 'FAIL'} (score={score:.2f})")

        except Exception as e:
            result = TestResult(
                test_id=case["id"],
                category=case.get("category", "general"),
                passed=False,
                score=0.0,
                error=str(e),
            )
            print(f"ERROR: {e}")

        results.append(result)

    # 결과 저장
    with open(output_path, "w") as f:
        json.dump(
            [vars(r) for r in results],
            f, indent=2, ensure_ascii=False,
        )

    return results


if __name__ == "__main__":
    import sys

    dataset = sys.argv[1] if len(sys.argv) > 1 else "tests/prompt-regression/golden-dataset.yaml"
    system_prompt = sys.argv[2] if len(sys.argv) > 2 else None

    print("=== AI 프롬프트 회귀 테스트 ===\n")
    results = run_regression_suite(dataset, system_prompt)

    total = len(results)
    passed = sum(1 for r in results if r.passed)
    avg_score = sum(r.score for r in results) / total if total else 0

    print(f"\n{'='*40}")
    print(f"Results: {passed}/{total} passed")
    print(f"Average score: {avg_score:.2f}")
    print(f"{'='*40}")

    sys.exit(0 if passed == total else 1)
```

### Step 3: LLM Judge 추가 (시맨틱 평가)

패턴 매칭만으로는 한계가 있어요. LLM을 평가자로 사용하면 더 정밀한 비교가 가능해요.

```python
# scripts/llm_judge.py
"""LLM Judge — AI가 AI의 출력을 평가"""

import json
import subprocess

JUDGE_PROMPT = """You are evaluating the quality of an AI coding assistant's output.

## Task Given to the Assistant
{task}

## Assistant's Output
{output}

## Evaluation Criteria
1. **Correctness** (0-10): Does the code work correctly?
2. **Completeness** (0-10): Are all requirements addressed?
3. **Style** (0-10): Does it follow best practices?
4. **Safety** (0-10): Are there security or performance issues?

Respond in JSON:
{{"correctness": N, "completeness": N, "style": N, "safety": N, "summary": "..."}}
"""


def judge_output(task: str, output: str) -> dict:
    """LLM에게 출력 품질 평가 요청"""
    prompt = JUDGE_PROMPT.format(task=task, output=output)

    result = subprocess.run(
        ["claude", "--print", "--no-input", "--prompt", prompt],
        capture_output=True, text=True, timeout=60,
    )

    # JSON 파싱 (코드 블록으로 감싸진 경우 처리)
    text = result.stdout.strip()
    if text.startswith("```"):
        text = "\n".join(text.split("\n")[1:-1])
    return json.loads(text)


def compare_baseline_vs_new(
    task: str, baseline_output: str, new_output: str
) -> dict:
    """베이스라인과 새 출력을 비교 평가"""
    baseline_score = judge_output(task, baseline_output)
    new_score = judge_output(task, new_output)

    regression_detected = False
    for key in ["correctness", "completeness", "style", "safety"]:
        if new_score.get(key, 0) < baseline_score.get(key, 0) - 1:
            regression_detected = True
            break

    return {
        "baseline": baseline_score,
        "new": new_score,
        "regression_detected": regression_detected,
    }
```

### Step 4: GitHub Actions 연동

```yaml
# .github/workflows/prompt-regression.yml
name: Prompt Regression Test

on:
  pull_request:
    paths:
      - '.claude/**'
      - '.cursorrules'
      - '.github/copilot-instructions.md'
      - 'CLAUDE.md'
      - '.clinerules'
      - 'tests/prompt-regression/**'

jobs:
  regression-test:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: pip install pyyaml

      - name: Run regression suite
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          python scripts/prompt_regression_runner.py \
            tests/prompt-regression/golden-dataset.yaml

      - name: Generate report
        if: always()
        run: |
          python scripts/generate_regression_report.py \
            regression-results.json > regression-report.md

      - name: Comment PR with results
        if: always() && github.event_name == 'pull_request'
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          path: regression-report.md
```

### Step 5: 리포트 생성기

```python
# scripts/generate_regression_report.py
"""회귀 테스트 리포트를 마크다운으로 생성"""

import json
import sys

def generate_report(results_path: str) -> str:
    with open(results_path) as f:
        results = json.load(f)

    total = len(results)
    passed = sum(1 for r in results if r["passed"])
    failed = total - passed
    avg_score = sum(r["score"] for r in results) / total if total else 0

    # 카테고리별 집계
    categories = {}
    for r in results:
        cat = r.get("category", "general")
        if cat not in categories:
            categories[cat] = {"passed": 0, "total": 0, "scores": []}
        categories[cat]["total"] += 1
        categories[cat]["scores"].append(r["score"])
        if r["passed"]:
            categories[cat]["passed"] += 1

    status = "✅ PASSED" if failed == 0 else "❌ REGRESSION DETECTED"

    lines = [
        f"## 🧪 프롬프트 회귀 테스트 리포트",
        f"",
        f"**Status:** {status}",
        f"**Results:** {passed}/{total} passed | Average score: {avg_score:.2f}",
        f"",
        f"### 카테고리별 결과",
        f"",
        f"| Category | Passed | Score |",
        f"|----------|--------|-------|",
    ]

    for cat, data in sorted(categories.items()):
        cat_avg = sum(data["scores"]) / len(data["scores"])
        emoji = "✅" if data["passed"] == data["total"] else "⚠️"
        lines.append(
            f"| {emoji} {cat} | {data['passed']}/{data['total']} | {cat_avg:.2f} |"
        )

    if failed > 0:
        lines.extend([
            f"",
            f"### ❌ 실패한 테스트",
            f"",
        ])
        for r in results:
            if not r["passed"]:
                lines.append(f"- **{r['test_id']}** (score: {r['score']:.2f})")
                if r.get("error"):
                    lines.append(f"  - Error: `{r['error']}`")
                for pattern, matched in r.get("pattern_matches", {}).items():
                    if not matched:
                        lines.append(f"  - Missing: `{pattern}`")

    lines.extend(["", "---", f"_Generated by prompt-regression-runner_"])
    return "\n".join(lines)


if __name__ == "__main__":
    print(generate_report(sys.argv[1]))
```

## 베스트 프랙티스

### 골든 데이터셋 관리

- **카테고리 균형**: 코드 생성, 디버깅, 리뷰, 리팩토링 등 균등 배분
- **난이도 분포**: 쉬운/중간/어려운 케이스를 2:5:3 비율로 유지
- **버전 관리**: 데이터셋도 Git으로 관리하고 변경 이력 추적
- **정기 업데이트**: 월 1회 실제 사용 패턴 기반으로 케이스 추가/갱신

### 평가 전략 계층

| 계층 | 방법 | 비용 | 정확도 |
|------|------|------|--------|
| L1 | 패턴 매칭 | 무료 | 낮음 |
| L2 | 임베딩 유사도 | 저렴 | 중간 |
| L3 | LLM Judge | 비쌈 | 높음 |
| L4 | 실제 실행 검증 | 매우 비쌈 | 매우 높음 |

> **팁:** 평소에는 L1+L2로 빠르게 게이트하고, 주요 변경 시에만 L3+L4를 실행하세요.

### 임계값 설정

```yaml
# tests/prompt-regression/thresholds.yaml
global:
  min_pass_rate: 0.85
  min_avg_score: 0.75

per_category:
  code-generation:
    min_score: 0.70
  debugging:
    min_score: 0.80
  code-review:
    min_score: 0.85
  refactoring:
    min_score: 0.70

regression:
  max_score_drop: 0.10
  critical_tests:
    - "code-review-security"
    - "debug-null-reference"
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 테스트 타임아웃 | 120초/케이스 | 단일 테스트 케이스 실행 제한 |
| 최소 통과율 | 85% | 이 비율 미만이면 파이프라인 실패 |
| LLM Judge 사용 | 비활성 | `--use-judge` 플래그로 활성화 |
| 병렬 실행 수 | 3 | 동시 테스트 실행 수 |
| 리포트 포맷 | Markdown | JSON, HTML도 지원 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 비결정적 출력으로 flaky 테스트 | temperature=0 설정 + 패턴 매칭 범위 넓히기 |
| LLM Judge 비용 급증 | 변경된 파일에 관련된 카테고리만 L3 실행 |
| CI 타임아웃 | 병렬 실행 수 줄이기 + 케이스별 타임아웃 조정 |
| 새 모델 버전에서 전부 실패 | 베이스라인 갱신 필요 — `--update-baseline` 실행 |
| 패턴이 너무 엄격함 | 정규식 대신 시맨틱 유사도(L2) 사용 검토 |

## 도구 비교

| 도구 | 특징 | 적합한 경우 |
|------|------|-----------|
| promptfoo | 오픈소스, YAML 기반, 다양한 평가자 | 범용 프롬프트 테스트 |
| Braintrust | SaaS, 실험 추적, 팀 협업 | 팀 단위 프롬프트 관리 |
| DeepEval | Python 네이티브, pytest 통합 | Python 프로젝트 |
| 커스텀 파이프라인 (이 문서) | 완전한 제어, CI 통합 용이 | AI 코딩 에이전트 특화 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
