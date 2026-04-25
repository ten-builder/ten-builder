# EP15: SWE-Bench 에이전트 직접 만들기 — AI 코딩 에이전트 내부 구조 분석

> SWE-Bench 벤치마크를 직접 실행하고, 상위 에이전트의 내부 구조를 분석하여 나만의 소프트웨어 엔지니어링 에이전트를 만들어봅니다

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- SWE-Bench 벤치마크 구조와 평가 방식 이해
- Mini-SWE-Agent 내부 코드 분석 (100줄로 74% 달성하는 원리)
- 나만의 소프트웨어 엔지니어링 에이전트 직접 구현
- 실제 GitHub 이슈에 적용하는 실전 패턴

---

## SWE-Bench란?

SWE-Bench는 AI 에이전트에게 실제 GitHub 이슈와 코드베이스를 주고, 기존 테스트를 통과하는 패치를 작성하게 하는 벤치마크입니다.

Django, SymPy 등 12개 오픈소스 레포에서 가져온 2,294개의 실제 버그 수정 태스크로 구성되어 있어요.

```
입력: GitHub 이슈 텍스트 + 전체 코드베이스
출력: 이슈를 해결하는 diff 패치

평가: 기존 테스트 스위트가 전부 통과하면 성공
```

2026년 기준 상위 에이전트들은 SWE-bench Verified에서 80% 이상을 달성하고 있습니다.

---

## 핵심 코드 & 설정

### Mini-SWE-Agent 구조 분석

Mini-SWE-Agent(Princeton/Stanford)는 100줄 내외의 코드로 74%를 달성한 오픈소스 에이전트입니다. 핵심 원리는 단순합니다.

```python
# 핵심 루프 구조 (단순화)
def run_agent(issue_text: str, repo_path: str, model: str) -> str:
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"GitHub 이슈:\n{issue_text}\n\n레포 경로: {repo_path}"}
    ]

    for step in range(MAX_STEPS):
        # LLM 호출
        response = call_llm(model, messages)

        # bash 블록 파싱
        tool_call = parse_bash_block(response)
        if tool_call is None:
            break  # 완료

        # 실행 및 결과 피드백
        result = execute_bash(tool_call, cwd=repo_path)
        messages.append({"role": "assistant", "content": response})
        messages.append({"role": "user", "content": f"결과:\n{result}"})

    return extract_diff(repo_path)
```

핵심은 **bash 블록 파싱 → 실행 → 피드백** 루프 하나입니다. 복잡한 프레임워크 없이도 높은 성능을 냅니다.

### 나만의 에이전트 구현: 단계별

#### Step 1: 시스템 프롬프트 설계

```python
SYSTEM_PROMPT = """당신은 소프트웨어 엔지니어링 에이전트입니다.

주어진 GitHub 이슈를 분석하고, 코드를 수정하여 해결하세요.

사용 가능한 도구:
- bash: 셸 명령어 실행 (파일 읽기/쓰기, 테스트 실행)

작업 순서:
1. 이슈 분석 — 무엇이 문제인지 파악
2. 관련 코드 탐색 — grep, find로 관련 파일 위치
3. 코드 수정 — 실제 버그 수정
4. 테스트 실행 — 수정이 기존 테스트를 통과하는지 확인
5. 완료 — "DONE" 출력

응답 형식:
<bash>
실행할 명령어
</bash>
"""
```

#### Step 2: 도구 실행기

```python
import subprocess
import re

def parse_bash_block(text: str) -> str | None:
    """응답에서 bash 블록 추출"""
    match = re.search(r'<bash>(.*?)</bash>', text, re.DOTALL)
    return match.group(1).strip() if match else None

def execute_bash(command: str, cwd: str, timeout: int = 30) -> str:
    """명령어 실행 및 결과 반환"""
    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        output = result.stdout + result.stderr
        # 토큰 절약: 출력 길이 제한
        return output[:3000] if len(output) > 3000 else output
    except subprocess.TimeoutExpired:
        return "[타임아웃: 30초 초과]"
    except Exception as e:
        return f"[오류: {e}]"
```

#### Step 3: 로컬 SWE-Bench 실행 환경

```bash
# SWE-Bench 설치
pip install swebench

# 데이터셋 다운로드
python -c "from swebench.harness.run_evaluation import main; print('OK')"

# 개발/검증용 소규모 서브셋 실행 (5개 인스턴스)
python run_evaluation.py \
  --dataset_name princeton-nlp/SWE-bench_Verified \
  --split test \
  --instance_ids "django__django-11099" "sympy__sympy-15678" \
  --predictions_path ./predictions.jsonl \
  --run_id my_agent_v1
```

#### Step 4: 예측 결과 형식

```python
# 에이전트가 생성해야 하는 출력 형식
prediction = {
    "instance_id": "django__django-11099",
    "model_patch": """
--- a/django/db/models/query.py
+++ b/django/db/models/query.py
@@ -1234,7 +1234,8 @@ class QuerySet:
     def bulk_create(self, objs, batch_size=None, ignore_conflicts=False):
-        if batch_size is not None and batch_size < 0:
+        if batch_size is not None and batch_size <= 0:
             raise ValueError('Batch size must be a positive integer.')
    """,
    "model_name_or_path": "my-swe-agent"
}
```

---

## 실전 적용: 내 프로젝트에 에이전트 연결하기

SWE-Bench 에이전트 패턴을 실제 업무에 적용하면, 팀 레포의 버그 이슈를 반자동으로 처리할 수 있어요.

```python
# 실제 GitHub 이슈에서 에이전트 실행
from github import Github
import subprocess

def auto_fix_issue(repo_name: str, issue_number: int, local_repo_path: str):
    """GitHub 이슈를 받아 에이전트로 자동 수정 시도"""
    g = Github()
    repo = g.get_repo(repo_name)
    issue = repo.get_issue(issue_number)

    issue_text = f"제목: {issue.title}\n\n내용:\n{issue.body}"

    # 에이전트 실행
    diff = run_agent(
        issue_text=issue_text,
        repo_path=local_repo_path,
        model="claude-opus-4-7"  # 또는 gemini-3-pro
    )

    # 브랜치 생성 + 커밋
    branch = f"fix/issue-{issue_number}-ai"
    subprocess.run(f"git checkout -b {branch}", shell=True, cwd=local_repo_path)
    subprocess.run("git add -p", shell=True, cwd=local_repo_path)  # 수동 확인
    subprocess.run(f'git commit -m "fix: #{issue_number} 자동 수정 시도"', 
                   shell=True, cwd=local_repo_path)

    print(f"브랜치 {branch} 생성 완료. 수동 검수 후 PR을 올려주세요.")
```

---

## 에이전트 성능을 높이는 핵심 패턴

| 패턴 | 설명 | 효과 |
|------|------|------|
| 파일 먼저 탐색 | grep으로 관련 파일 찾기 후 수정 | 불필요한 토큰 소비 방지 |
| 테스트 먼저 실행 | 수정 전 실패하는 테스트 확인 | 수정 방향 명확화 |
| 단계별 확인 | 각 수정 후 즉시 테스트 | 오류 전파 방지 |
| 출력 길이 제한 | 결과를 3000자 이하로 잘라 피드백 | 컨텍스트 윈도우 절약 |
| 타임아웃 설정 | 무한 루프 방지 | 안정성 확보 |

---

## 따라하기

### Step 1: 환경 설정

```bash
# Python 가상 환경
python -m venv swe-agent-env
source swe-agent-env/bin/activate

# 의존성 설치
pip install anthropic swebench gitpython

# API 키 설정
export ANTHROPIC_API_KEY="your-key"
```

### Step 2: 에이전트 파일 구조

```
my-swe-agent/
├── agent.py          # 메인 에이전트 루프
├── tools.py          # bash 실행기
├── prompts.py        # 시스템 프롬프트
├── evaluate.py       # SWE-Bench 평가 실행
└── results/          # 예측 결과 저장
    └── predictions.jsonl
```

### Step 3: 첫 실행

```bash
# 단일 인스턴스 테스트
python agent.py \
  --instance "django__django-11099" \
  --repo-path /tmp/django \
  --model claude-opus-4-7

# 결과 평가
python evaluate.py --predictions results/predictions.jsonl
```

---

## 더 알아보기

- [SWE-Bench 공식 GitHub](https://github.com/SWE-bench/SWE-bench) — 데이터셋 및 평가 도구
- [Mini-SWE-Agent](https://github.com/SWE-agent/mini-swe-agent) — 100줄 구현 참고
- [플레이북 40: 인텐트 기반 태스크 분해](../claude-code/playbooks/40-intent-based-task-decomposition.md)
- [가이드 56: 서브에이전트 병렬 실행](../guides/56-claude-code-subagent-parallel-guide.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
