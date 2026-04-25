# 플레이북 54: AI 에이전트 프롬프트 버전 관리

> 시스템 프롬프트를 Git으로 추적하고 변경이 결과물에 미치는 영향을 측정하는 실전 워크플로우

## 소요 시간

30-45분 (초기 설정 기준)

## 사전 준비

- Git 기본 사용 가능
- AI 코딩 에이전트 (Claude Code, Cursor, Copilot 등) 사용 중
- 반복적으로 쓰는 시스템 프롬프트가 1개 이상 있는 상태

---

## 왜 프롬프트도 코드처럼 관리해야 하나요?

프롬프트를 텍스트 파일에 저장해두고 쓰다 보면 언제부터 결과가 달라졌는지 추적하기가 어려워요. 코드는 git diff로 바로 비교하는데, 프롬프트는 그냥 덮어쓰고 끝나는 경우가 많죠.

문제는 프롬프트 변경이 에이전트 행동에 예상치 못한 영향을 줄 수 있다는 점이에요. 모델 버전 업데이트, 약간의 표현 변경, 지시 순서 조정 — 이런 것들이 누적되면 결과물 품질이 눈에 띄게 달라져요.

---

## Step 1: 프롬프트 저장 구조 잡기

프로젝트 루트에 `prompts/` 폴더를 만들고 역할별로 분류해요.

```
project/
├── prompts/
│   ├── agents/
│   │   ├── code-reviewer.md
│   │   ├── refactor-assistant.md
│   │   └── test-generator.md
│   ├── tasks/
│   │   ├── pr-description.md
│   │   └── commit-message.md
│   └── meta.yaml          # 모델 설정, 버전 태그
└── CLAUDE.md
```

**meta.yaml 예시:**

```yaml
version: "1.3.0"
model: claude-sonnet-4-5
temperature: 1.0
last_tested: "2026-04-20"
prompts:
  code-reviewer: "v1.2"
  refactor-assistant: "v1.0"
  test-generator: "v2.1"
```

> **핵심:** 프롬프트 텍스트뿐 아니라 모델 설정(temperature, model ID)도 함께 버전 관리해요. 동일한 프롬프트라도 모델이 달라지면 출력이 바뀔 수 있어요.

---

## Step 2: Git 커밋 규칙 정하기

프롬프트 변경은 코드 커밋과 구분해서 명확하게 표시해요.

```bash
# 프롬프트 변경 전용 커밋 메시지 형식
git commit -m "prompt(code-reviewer): add instruction for test coverage check"
git commit -m "prompt(test-generator): v2.0 — restructure output format to JSON"
git commit -m "prompt(meta): bump model to claude-sonnet-4-5"
```

**커밋 메시지에 꼭 포함할 내용:**

| 항목 | 예시 |
|------|------|
| 어떤 프롬프트를 | `code-reviewer`, `test-generator` |
| 무엇을 바꿨는지 | "add instruction", "restructure output" |
| 왜 바꿨는지 | "to reduce hallucination", "for JSON parsing" |
| 이전 버전 대비 | "v1.2 → v1.3" |

---

## Step 3: 프롬프트 리그레션 테스트 셋 만들기

버전 비교를 위한 "황금 케이스(golden test cases)"를 관리해요.

```
prompts/
└── tests/
    ├── code-reviewer/
    │   ├── input-01-simple-function.md
    │   ├── expected-01.md
    │   ├── input-02-security-issue.md
    │   └── expected-02.md
    └── test-runner.sh
```

**test-runner.sh 예시 (Claude Code CLI 사용):**

```bash
#!/bin/bash
PROMPT_FILE="$1"
INPUT_FILE="$2"
EXPECTED_FILE="$3"

# 프롬프트 + 입력으로 에이전트 실행
ACTUAL=$(cat "$PROMPT_FILE" "$INPUT_FILE" | claude --print --no-markdown 2>/dev/null)

# 핵심 키워드 포함 여부 확인
KEYWORDS=$(cat "$EXPECTED_FILE" | grep "^MUST_CONTAIN:" | sed 's/MUST_CONTAIN: //')
PASS=true

while IFS= read -r keyword; do
  if ! echo "$ACTUAL" | grep -q "$keyword"; then
    echo "FAIL: missing '$keyword'"
    PASS=false
  fi
done <<< "$KEYWORDS"

if $PASS; then
  echo "PASS: $PROMPT_FILE"
fi
```

**expected 파일 형식:**

```
MUST_CONTAIN: security
MUST_CONTAIN: SQL injection
MUST_CONTAIN: sanitize
NOTES: 보안 취약점을 반드시 지적해야 함
```

---

## Step 4: 변경 영향 비교 워크플로우

프롬프트를 바꾸기 전후 출력을 나란히 비교하는 루틴이에요.

```bash
# 1. 현재 버전으로 테스트 결과 저장
./prompts/tests/test-runner.sh \
  prompts/agents/code-reviewer.md \
  prompts/tests/code-reviewer/input-01-simple-function.md \
  > results/baseline.txt

# 2. 프롬프트 수정
vim prompts/agents/code-reviewer.md

# 3. 변경 후 결과 저장
./prompts/tests/test-runner.sh \
  prompts/agents/code-reviewer.md \
  prompts/tests/code-reviewer/input-01-simple-function.md \
  > results/after-change.txt

# 4. 차이 확인
diff results/baseline.txt results/after-change.txt
```

---

## Step 5: 브랜치 전략 — 실험 vs 안정

프롬프트 실험도 코드와 동일하게 브랜치로 격리해요.

```bash
# 실험용 프롬프트 브랜치
git checkout -b prompt/try-chain-of-thought

# 작업 후 결과가 좋으면
git checkout main
git merge prompt/try-chain-of-thought

# 결과가 나쁘면 그냥 버림
git branch -D prompt/try-chain-of-thought
```

**실전 브랜치 네이밍:**

| 패턴 | 사용 케이스 |
|------|-------------|
| `prompt/try-{feature}` | 새 지시 추가 실험 |
| `prompt/fix-{issue}` | 특정 오류 수정 |
| `prompt/model-{version}` | 모델 변경 대응 |

---

## Step 6: CI에 프롬프트 테스트 추가 (선택)

GitHub Actions로 PR마다 프롬프트 리그레션 테스트를 자동으로 돌릴 수 있어요.

```yaml
# .github/workflows/prompt-test.yml
name: Prompt Regression Test

on:
  pull_request:
    paths:
      - 'prompts/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run prompt tests
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          chmod +x prompts/tests/test-runner.sh
          bash prompts/tests/run-all.sh
```

---

## 체크리스트

- [ ] `prompts/` 폴더 생성 및 `.gitignore` 제외 확인
- [ ] `meta.yaml`에 모델 ID와 temperature 기록
- [ ] 자주 쓰는 프롬프트 3개 이상 파일로 분리
- [ ] 황금 테스트 케이스 각 프롬프트당 2개 이상 작성
- [ ] 프롬프트 전용 커밋 메시지 규칙 팀 내 공유
- [ ] 실험 브랜치 병합 전 테스트 결과 비교 습관화

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 프롬프트를 코드에 하드코딩 | 별도 파일로 분리, git으로 추적 |
| 모델 설정 기록 안 함 | meta.yaml에 model, temperature 항상 기록 |
| 테스트 없이 프롬프트 수정 | 변경 전 baseline 결과 먼저 저장 |
| 브랜치 안 쓰고 main에 직접 실험 | `prompt/try-*` 브랜치 습관화 |
| 리그레션 무시 | diff 결과 확인 후에만 머지 |

---

## 다음 단계

→ [플레이북 55: AI 멀티에이전트 오케스트레이션](55-multi-agent-orchestration.md) (예정)

→ [AI 에이전트 디버깅 플로우 치트시트](../../cheatsheets/ai-agent-debug-flow-cheatsheet.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
