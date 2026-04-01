# AI 프롬프트 테스트 자동화 예제

> AI 코딩 에이전트에 보내는 프롬프트를 체계적으로 테스트하고 버전 관리하는 실전 프레임워크

## 이 예제에서 배울 수 있는 것

- 프롬프트를 코드처럼 버전 관리하고 회귀 테스트하는 방법
- promptfoo로 여러 모델/프롬프트 변형을 자동 비교하는 워크플로우
- CI/CD 파이프라인에 프롬프트 품질 게이트를 통합하는 패턴

## 프로젝트 구조

```
ai-prompt-testing/
├── CLAUDE.md              # 프로젝트 컨텍스트 설정
├── prompts/
│   ├── v1/
│   │   └── code-review.yaml    # 코드 리뷰 프롬프트 v1
│   ├── v2/
│   │   └── code-review.yaml    # 개선된 v2
│   └── helpers/
│       └── system-context.yaml # 공통 시스템 프롬프트
├── tests/
│   ├── promptfooconfig.yaml    # promptfoo 설정
│   ├── datasets/
│   │   ├── code-review-cases.yaml   # 테스트 케이스
│   │   └── edge-cases.yaml          # 엣지케이스 모음
│   └── assertions/
│       └── code-review-checks.yaml  # 검증 규칙
├── scripts/
│   ├── run-eval.sh            # 로컬 평가 실행
│   └── compare-versions.sh    # 버전 간 비교
├── .github/
│   └── workflows/
│       └── prompt-eval.yml    # CI 프롬프트 평가
├── results/                   # 평가 결과 저장
└── package.json
```

## 왜 프롬프트를 테스트해야 하나요?

코드를 배포하기 전에 테스트하듯이, 프롬프트도 운영에 반영하기 전에 검증이 필요해요.

| 문제 상황 | 프롬프트 테스트 없이 | 테스트 있을 때 |
|-----------|---------------------|---------------|
| 프롬프트 수정 후 기존 기능이 깨짐 | 운영에서 발견 | 회귀 테스트에서 즉시 감지 |
| 어떤 모델이 더 좋은지 비교 | 수동으로 일일이 확인 | 자동 비교 리포트 |
| 팀원마다 다른 프롬프트 사용 | 혼란, 품질 편차 | Git으로 단일 버전 관리 |
| 비용 최적화 | 감으로 판단 | 비용 대비 품질 데이터 기반 결정 |

## 시작하기

### Step 1: 프로젝트 초기화

```bash
mkdir ai-prompt-testing && cd ai-prompt-testing
npm init -y
npm install -D promptfoo
```

### Step 2: CLAUDE.md 작성

프로젝트 루트에 CLAUDE.md를 만들어서 컨텍스트를 설정해요.

```markdown
# CLAUDE.md

## Project
- promptfoo 기반 프롬프트 평가 프레임워크
- Node.js 20+ / TypeScript

## 프롬프트 관리 규칙
- 모든 프롬프트는 prompts/ 디렉토리에 YAML로 관리
- 버전별 폴더 분리 (v1/, v2/, ...)
- 프롬프트 변경 시 반드시 테스트 실행 후 커밋
- 평가 결과는 results/에 저장하되 Git에는 커밋하지 않음
```

### Step 3: 프롬프트 파일 작성

코드 리뷰용 프롬프트를 YAML로 관리해요.

```yaml
# prompts/v1/code-review.yaml
id: code-review-v1
metadata:
  author: team
  created: 2026-03-15
  description: PR 코드 리뷰 프롬프트 첫 번째 버전

system: |
  당신은 시니어 개발자입니다. 코드를 리뷰할 때 다음 기준을 따르세요:
  - 버그 가능성이 있는 부분을 찾아 구체적으로 설명
  - 성능 이슈가 있다면 대안을 제시
  - 보안 취약점 체크

prompt: |
  다음 코드를 리뷰해주세요.

  ```{{language}}
  {{code}}
  ```

  리뷰 결과를 JSON으로 반환하세요:
  {
    "issues": [{"severity": "high|medium|low", "line": N, "message": "...", "suggestion": "..."}],
    "summary": "..."
  }
```

개선된 v2에서는 맥락 정보를 추가해요.

```yaml
# prompts/v2/code-review.yaml
id: code-review-v2
metadata:
  author: team
  created: 2026-03-20
  description: 파일 컨텍스트와 PR 설명을 추가한 개선 버전
  changelog: v1 대비 파일 맥락, PR 설명 추가

system: |
  당신은 시니어 개발자입니다. 코드를 리뷰할 때 다음 기준을 따르세요:
  - 버그 가능성이 있는 부분을 찾아 구체적으로 설명
  - 성능 이슈가 있다면 대안을 제시
  - 보안 취약점 체크
  - PR의 목적에 맞는 변경인지 확인

prompt: |
  ## PR 정보
  - 제목: {{pr_title}}
  - 설명: {{pr_description}}
  - 파일 경로: {{file_path}}

  ## 코드
  ```{{language}}
  {{code}}
  ```

  리뷰 결과를 JSON으로 반환하세요:
  {
    "issues": [{"severity": "high|medium|low", "line": N, "message": "...", "suggestion": "..."}],
    "summary": "...",
    "approval": "approve|request_changes|comment"
  }
```

## 핵심 코드: 테스트 설정

### promptfoo 설정 파일

```yaml
# tests/promptfooconfig.yaml
description: 코드 리뷰 프롬프트 평가

providers:
  - id: openai:gpt-4o
    label: GPT-4o
  - id: anthropic:messages:claude-sonnet-4-20250514
    label: Claude Sonnet

prompts:
  - file://prompts/v1/code-review.yaml
  - file://prompts/v2/code-review.yaml

tests:
  - file://tests/datasets/code-review-cases.yaml
  - file://tests/datasets/edge-cases.yaml

defaultTest:
  assert:
    # JSON 형식 검증
    - type: is-json
    # 필수 키 존재 확인
    - type: javascript
      value: |
        const result = JSON.parse(output);
        return result.issues !== undefined && result.summary !== undefined;
    # 비용 임계값
    - type: cost
      threshold: 0.05

outputPath: results/eval-{{date}}.json
```

### 테스트 케이스 작성

```yaml
# tests/datasets/code-review-cases.yaml
- vars:
    language: python
    code: |
      def get_user(user_id):
          query = f"SELECT * FROM users WHERE id = {user_id}"
          return db.execute(query)
    pr_title: "사용자 조회 API 추가"
    pr_description: "사용자 ID로 조회하는 엔드포인트"
    file_path: "app/services/user.py"
  assert:
    # SQL 인젝션을 반드시 감지해야 함
    - type: contains
      value: "injection"
    - type: javascript
      value: |
        const result = JSON.parse(output);
        return result.issues.some(i => i.severity === 'high');

- vars:
    language: typescript
    code: |
      async function fetchData(url: string) {
        const res = await fetch(url);
        const data = await res.json();
        return data;
      }
    pr_title: "데이터 가져오기 유틸 함수"
    pr_description: "외부 API 호출 유틸"
    file_path: "src/utils/fetch.ts"
  assert:
    # 에러 핸들링 누락 감지
    - type: javascript
      value: |
        const result = JSON.parse(output);
        return result.issues.some(i =>
          i.message.toLowerCase().includes('error') ||
          i.message.toLowerCase().includes('예외') ||
          i.message.toLowerCase().includes('에러')
        );
```

### 엣지케이스 테스트

```yaml
# tests/datasets/edge-cases.yaml
- description: 빈 코드 입력
  vars:
    language: python
    code: ""
    pr_title: "빈 파일"
    pr_description: "테스트"
    file_path: "test.py"
  assert:
    - type: is-json
    - type: javascript
      value: |
        const result = JSON.parse(output);
        return result.summary.length > 0;

- description: 1000줄 이상 긴 코드
  vars:
    language: javascript
    code: "function a() { return 1; }\n".repeat(1000)
    pr_title: "대규모 리팩토링"
    pr_description: "함수 분리"
    file_path: "src/legacy.js"
  assert:
    - type: is-json
    - type: latency
      threshold: 30000  # 30초 이내 응답
```

## 평가 실행

### 로컬에서 실행

```bash
# scripts/run-eval.sh
#!/bin/bash
set -e

echo "프롬프트 평가 시작..."
npx promptfoo eval -c tests/promptfooconfig.yaml

echo "결과 뷰어 실행..."
npx promptfoo view
```

```bash
chmod +x scripts/run-eval.sh
./scripts/run-eval.sh
```

### 버전 간 비교

```bash
# scripts/compare-versions.sh
#!/bin/bash
set -e

V1_RESULT=$(npx promptfoo eval \
  -c tests/promptfooconfig.yaml \
  --prompts prompts/v1/code-review.yaml \
  --output results/v1-eval.json 2>&1 | tail -1)

V2_RESULT=$(npx promptfoo eval \
  -c tests/promptfooconfig.yaml \
  --prompts prompts/v2/code-review.yaml \
  --output results/v2-eval.json 2>&1 | tail -1)

echo "=== 버전 비교 결과 ==="
echo "V1: $V1_RESULT"
echo "V2: $V2_RESULT"

npx promptfoo view
```

## CI/CD 통합

### GitHub Actions 워크플로우

```yaml
# .github/workflows/prompt-eval.yml
name: Prompt Evaluation

on:
  pull_request:
    paths:
      - 'prompts/**'

jobs:
  evaluate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - run: npm ci

      - name: Run prompt evaluation
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          npx promptfoo eval \
            -c tests/promptfooconfig.yaml \
            --output results/ci-eval.json \
            --grader openai:gpt-4o

      - name: Check pass rate
        run: |
          PASS_RATE=$(cat results/ci-eval.json | \
            jq '.results.stats.successes / .results.stats.count * 100')
          echo "Pass rate: ${PASS_RATE}%"
          if (( $(echo "$PASS_RATE < 80" | bc -l) )); then
            echo "통과율이 80% 미만입니다. PR을 검토해주세요."
            exit 1
          fi

      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: prompt-eval-results
          path: results/ci-eval.json
```

이렇게 설정하면 `prompts/` 디렉토리에 변경이 있는 PR이 올라올 때마다 자동으로 평가가 실행돼요. 통과율이 80% 미만이면 PR이 실패 처리되어서 의도치 않은 품질 하락을 막을 수 있어요.

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 테스트 케이스 확장 | `이 프롬프트에 대한 엣지케이스 5개를 추가해줘. 보안 취약점 감지 능력을 테스트하는 케이스 위주로` |
| 검증 규칙 작성 | `code-review 프롬프트의 출력을 검증하는 assertion을 작성해줘. JSON 스키마 검증 포함` |
| 프롬프트 개선 | `v1 프롬프트의 평가 결과를 분석하고, 실패 케이스를 통과할 수 있도록 v2를 작성해줘` |
| 비용 최적화 | `현재 프롬프트의 토큰 사용량을 분석하고, 품질 유지하면서 토큰을 줄이는 방안을 제안해줘` |

## 실전 팁

### 1. 프롬프트 변경 이력 추적

```bash
# 프롬프트 변경 diff 확인
git log --oneline --follow prompts/v2/code-review.yaml

# 특정 버전 간 차이 비교
git diff v1.0..v2.0 -- prompts/
```

### 2. 평가 메트릭 기준표

| 메트릭 | 기준값 | 설명 |
|--------|--------|------|
| 통과율 | 80% 이상 | 전체 테스트 케이스 대비 통과 비율 |
| 응답 시간 | 30초 이하 | 단일 프롬프트 실행 시간 |
| 비용 | $0.05 이하 | 단일 평가 비용 |
| JSON 유효성 | 100% | 출력 형식 준수율 |

### 3. 팀 워크플로우

```
프롬프트 수정 → 로컬 평가 → PR 생성 → CI 평가 → 리뷰 → 머지 → 스테이징 배포
```

프롬프트를 코드와 동일한 리뷰 프로세스로 관리하면 품질을 일정하게 유지할 수 있어요.

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
