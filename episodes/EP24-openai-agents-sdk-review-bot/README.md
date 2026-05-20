# EP24: OpenAI Agents SDK로 자율 코드 리뷰 봇 만들기

> SandboxAgent와 핸드오프로 PR 품질·보안·테스트 커버리지를 자동 검증하는 멀티에이전트 코드 리뷰 시스템 구현

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

---

## 이 에피소드에서 다루는 것

- OpenAI Agents SDK v0.15.1의 SandboxAgent — 격리된 셸 환경에서 코드를 직접 실행해 검증하는 패턴
- 코드 분석 에이전트 → SandboxAgent 핸드오프 — 역할별 에이전트를 연결하는 방법
- PR이 열릴 때 GitHub Actions가 봇을 자동 실행하고 인라인 코멘트를 남기는 파이프라인 설계
- 코드 품질, 보안, 테스트 커버리지를 각각 담당하는 3개 에이전트의 역할 분담
- 리뷰 결과를 PR 코멘트로 구조화해서 올리는 포맷팅 패턴

---

## 스택

| 항목 | 내용 |
|------|------|
| AI 프레임워크 | OpenAI Agents SDK v0.15.1 (Python) |
| 샌드박스 | SandboxAgent (격리 실행 환경) |
| CI/CD | GitHub Actions |
| 핵심 기능 | 핸드오프, SandboxAgent, Shell 도구, 트레이싱 |
| 리뷰 타깃 | Python/TypeScript 프로젝트 |

---

## 배경: 왜 멀티에이전트 리뷰인가

단일 프롬프트로 AI에게 PR을 리뷰해달라고 하면 어떤 문제가 생길까요?

| 문제 | 단일 에이전트 | 멀티에이전트 |
|------|-------------|------------|
| 컨텍스트 한계 | 큰 PR에서 중요 변경 누락 | 에이전트별 집중 영역으로 분산 |
| 보안 점검 깊이 | 표면적 패턴 매칭 수준 | SandboxAgent가 실제 실행해 검증 |
| 일관성 | 실행마다 결과가 다름 | 구조화된 핸드오프로 안정적 결과 |
| 검증 가능성 | "아마도" 수준 의견 | 실제 테스트 실행 결과 기반 |

핸드오프 패턴은 각 에이전트가 자신의 강점에만 집중하게 해요. 코드 읽기, 실행 검증, 보안 점검 — 이 세 가지를 같은 컨텍스트에 욱여넣지 않아도 됩니다.

---

## 아키텍처

```
GitHub PR Open
    ↓
GitHub Actions 트리거
    ↓
[Intake Agent] ← PR diff 파싱, 리뷰 대상 파일 분류
    ↓ 핸드오프
[Quality Agent] ← 코드 스타일, 복잡도, 중복 패턴 분석
    ↓ 핸드오프
[Security SandboxAgent] ← 격리 환경에서 코드 직접 실행, 취약점 확인
    ↓ 핸드오프
[Coverage Agent] ← 테스트 커버리지 실행, 누락된 엣지 케이스 탐지
    ↓
리뷰 결과 집계 → PR 코멘트 작성
```

---

## 핵심 코드

### 1. 에이전트 정의

```python
from agents import Agent, Runner
from agents.run import RunConfig
from agents.sandbox import Manifest, SandboxAgent, SandboxRunConfig
from agents.sandbox.capabilities import Shell, Filesystem

# PR 파싱 + 분류 담당 (샌드박스 불필요)
intake_agent = Agent(
    name="intake",
    instructions="""
    PR diff를 분석해서 변경된 파일을 분류해요.
    각 파일의 변경 유형(로직, 설정, 테스트)과 위험도를 판단하고
    Security Agent로 핸드오프가 필요한지 결정합니다.
    """,
    handoffs=["quality", "security_sandbox"],
)

# 코드 품질 분석 (샌드박스 불필요)
quality_agent = Agent(
    name="quality",
    instructions="""
    코드 품질을 검토해요.
    - 함수 복잡도가 10을 넘는 곳
    - 중복된 로직 블록
    - 명확하지 않은 변수명
    - 불필요한 중첩 구조
    구체적인 줄 번호와 개선 제안을 포함해 주세요.
    """,
    handoffs=["security_sandbox"],
)

# 보안 검증 (SandboxAgent — 실제 실행 포함)
security_sandbox = SandboxAgent(
    name="security_sandbox",
    instructions="""
    격리 환경에서 보안 관련 코드를 직접 실행해 검증해요.
    - 시크릿 하드코딩 여부 (환경변수 대신 직접 값 사용)
    - SQL 인젝션 취약점 패턴
    - 의존성 패키지의 알려진 CVE
    - 인증 로직의 우회 가능성
    발견된 문제는 심각도(critical/high/medium)와 함께 보고해요.
    """,
    sandbox=Manifest(
        capabilities=[Shell(), Filesystem(read_write=["/workspace"])],
        network_access=False,  # 네트워크 차단 — 외부 유출 방지
    ),
    handoffs=["coverage"],
)

# 테스트 커버리지 실행
coverage_agent = SandboxAgent(
    name="coverage",
    instructions="""
    테스트를 실제로 실행하고 커버리지를 측정해요.
    - 변경된 코드가 기존 테스트를 통과하는지
    - 새로 추가된 로직에 테스트가 있는지
    - 엣지 케이스(빈 입력, 경계값, 에러 경로)가 커버되는지
    커버리지가 80% 미만인 영역은 구체적인 테스트 케이스를 제안해요.
    """,
    sandbox=Manifest(
        capabilities=[Shell(), Filesystem(read_write=["/workspace"])],
        network_access=False,
    ),
)
```

### 2. 리뷰 실행 + 핸드오프

```python
import asyncio

async def run_pr_review(pr_diff: str, repo_path: str) -> dict:
    """PR 리뷰 전체 파이프라인을 실행해요."""
    
    result = await Runner.run(
        intake_agent,
        input=f"""
다음 PR을 리뷰해 주세요.

## PR Diff
{pr_diff}

## 레포지터리 경로
{repo_path}

전체 리뷰를 완료하고 JSON 형태로 결과를 반환해 주세요.
        """,
        run_config=RunConfig(
            workflow_name="pr-review",
            trace=True,  # 핸드오프 과정 추적
        ),
        sandbox_run_config=SandboxRunConfig(
            timeout_seconds=120,
        ),
    )
    
    return result.final_output
```

### 3. GitHub Actions 연동

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: PR diff 추출
        id: diff
        run: |
          git diff origin/${{ github.base_ref }}...HEAD > pr_diff.txt
          echo "diff_path=pr_diff.txt" >> $GITHUB_OUTPUT
      
      - name: AI 리뷰 실행
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          pip install openai-agents
          python scripts/run_review.py \
            --diff pr_diff.txt \
            --repo . \
            --output review_result.json
      
      - name: PR 코멘트 작성
        uses: actions/github-script@v7
        with:
          script: |
            const result = require('./review_result.json');
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: formatReviewComment(result)
            });
```

### 4. 리뷰 결과 포맷팅

```python
def format_review_comment(result: dict) -> str:
    """리뷰 결과를 PR 코멘트 형식으로 변환해요."""
    
    lines = ["## AI 코드 리뷰 결과\n"]
    
    # 전체 요약
    score = result.get("overall_score", 0)
    emoji = "✅" if score >= 80 else "⚠️" if score >= 60 else "🔴"
    lines.append(f"{emoji} **종합 점수: {score}/100**\n")
    
    # 보안 이슈 (있으면 최상단)
    if result.get("security_issues"):
        lines.append("### 🔒 보안 이슈\n")
        for issue in result["security_issues"]:
            severity = issue["severity"]
            icon = {"critical": "🚨", "high": "❗", "medium": "⚠️"}.get(severity, "ℹ️")
            lines.append(f"- {icon} **{severity.upper()}**: {issue['description']}")
            if issue.get("line"):
                lines.append(f"  - 위치: `{issue['file']}:{issue['line']}`")
        lines.append("")
    
    # 커버리지
    coverage = result.get("coverage", {})
    if coverage:
        lines.append("### 🧪 테스트 커버리지\n")
        lines.append(f"- 전체: **{coverage.get('total', 0)}%**")
        for uncovered in coverage.get("uncovered_areas", []):
            lines.append(f"- 미커버: `{uncovered}`")
        lines.append("")
    
    return "\n".join(lines)
```

---

## 실습 흐름

### 준비 (5분)

```bash
# 프로젝트 초기화
git clone https://github.com/your-org/your-repo
cd your-repo

# 의존성 설치
pip install openai-agents python-dotenv

# 환경변수 설정
echo "OPENAI_API_KEY=sk-..." > .env
```

### 에이전트 테스트 (10분)

```bash
# 단일 파일로 에이전트 동작 확인
python scripts/run_review.py \
  --diff tests/sample_diff.txt \
  --repo . \
  --output result.json

# 결과 확인
cat result.json | python -m json.tool
```

### GitHub Actions 설정 (10분)

```bash
# secrets 설정 (GitHub 레포 → Settings → Secrets)
# OPENAI_API_KEY 추가

# 워크플로우 파일 추가
mkdir -p .github/workflows
cp examples/ai-review.yml .github/workflows/

# 테스트 PR 생성
git checkout -b test/ai-review-setup
echo "# test" >> TEST.md
git add TEST.md
git commit -m "test: AI 리뷰 봇 연동 테스트"
git push origin HEAD
```

---

## SandboxAgent 사용 시 주의할 점

| 상황 | 올바른 방법 |
|------|------------|
| 외부 API 호출 필요 | `network_access=True` + allowlist 설정 |
| 임시 파일 작성 | `/workspace` 경로만 사용 |
| 긴 테스트 실행 | `timeout_seconds` 충분히 설정 (기본 60초) |
| 기밀 코드 처리 | 자체 호스팅 또는 온프레미스 샌드박스 고려 |

---

## 다음 단계

- 인라인 코멘트 기능 추가 (파일별 줄 번호 기반 리뷰)
- 커스텀 리뷰 규칙 파일(`.review-rules.yaml`) 지원
- 팀 히스토리 기반 학습 — 자주 지적되는 패턴 우선 감지

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
