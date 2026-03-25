# CrewAI 멀티 에이전트 코딩 예제

> 여러 AI 에이전트가 역할을 나눠 코드를 함께 생성하는 실전 패턴 — CrewAI로 리서치, 설계, 구현, 리뷰를 자동화하는 방법

## 이 예제에서 배울 수 있는 것

- CrewAI의 역할 기반 에이전트 설계와 태스크 체이닝 원리
- 4개 에이전트(리서처, 설계자, 개발자, 리뷰어)가 순차 협업하는 코딩 파이프라인
- 실제 프로젝트에 적용할 수 있는 프롬프트와 도구 설정 패턴
- CrewAI 실행 결과를 파일로 저장하고 CI에 연동하는 방법

## 프로젝트 구조

```
crewai-multi-agent/
├── README.md                  # 이 문서
├── pyproject.toml             # 의존성 (crewai, crewai-tools)
├── src/
│   ├── crew.py                # Crew 정의 (에이전트 + 태스크 + 실행)
│   ├── agents.py              # 4개 에이전트 역할 정의
│   ├── tasks.py               # 순차 태스크 체인 정의
│   └── tools/
│       ├── file_writer.py     # 코드 파일 저장 도구
│       └── code_analyzer.py   # 정적 분석 도구
├── config/
│   ├── agents.yaml            # 에이전트 설정 (YAML 방식)
│   └── tasks.yaml             # 태스크 설정 (YAML 방식)
├── output/                    # 생성된 코드 저장 디렉토리
└── tests/
    └── test_crew.py           # Crew 통합 테스트
```

## 핵심 개념: 역할 기반 에이전트 협업

CrewAI는 사람 팀처럼 에이전트에게 역할(Role), 목표(Goal), 배경(Backstory)을 부여해요. 각 에이전트가 자기 전문 영역에 집중하면서 태스크 결과를 다음 에이전트에게 넘기는 구조예요.

| 에이전트 | 역할 | 담당 | 출력 |
|----------|------|------|------|
| Researcher | 기술 리서처 | 요구사항 분석, 기술 스택 조사 | 기술 보고서 |
| Architect | 설계자 | 아키텍처 설계, 파일 구조 정의 | 설계 문서 |
| Developer | 개발자 | 코드 구현 | 소스 코드 파일 |
| Reviewer | 코드 리뷰어 | 품질 검증, 개선 제안 | 리뷰 리포트 |

```
[요구사항 입력]
    │
    ▼
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Researcher├───▶│ Architect├───▶│ Developer├───▶│ Reviewer │
│ (분석)    │    │ (설계)    │    │ (구현)    │    │ (검증)    │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                                                      │
                                                      ▼
                                               [최종 코드 + 리포트]
```

## 시작하기

### Step 1: 프로젝트 초기화

```bash
# CrewAI CLI로 프로젝트 생성
pip install crewai crewai-tools
crewai create crew coding-crew
cd coding-crew
```

또는 기존 프로젝트에 추가:

```bash
pip install crewai crewai-tools
```

### Step 2: 에이전트 정의

에이전트마다 명확한 역할과 경계를 설정하는 게 핵심이에요.

```python
# src/agents.py
from crewai import Agent

researcher = Agent(
    role="기술 리서처",
    goal="요구사항을 분석하고 최적의 기술 스택과 패턴을 조사한다",
    backstory=(
        "10년 경력의 시니어 개발자. 새 프로젝트를 시작할 때 "
        "항상 기술 선택의 근거를 문서화하는 습관이 있다."
    ),
    verbose=True,
    allow_delegation=False,
)

architect = Agent(
    role="소프트웨어 설계자",
    goal="리서치 결과를 바탕으로 확장 가능한 아키텍처를 설계한다",
    backstory=(
        "대규모 시스템을 여러 번 설계한 아키텍트. "
        "SOLID 원칙과 실용성 사이의 균형을 중시한다."
    ),
    verbose=True,
    allow_delegation=False,
)

developer = Agent(
    role="백엔드 개발자",
    goal="설계 문서에 따라 깨끗하고 테스트 가능한 코드를 작성한다",
    backstory=(
        "클린 코드를 중요시하는 개발자. 타입 힌트와 독스트링을 "
        "빠뜨리지 않고, 엣지케이스를 먼저 생각한다."
    ),
    verbose=True,
    allow_delegation=False,
    tools=[],  # 필요 시 file_writer, code_analyzer 추가
)

reviewer = Agent(
    role="코드 리뷰어",
    goal="생성된 코드의 품질, 보안, 성능을 검증하고 개선점을 제안한다",
    backstory=(
        "오픈소스 프로젝트 메인테이너 경험이 있는 시니어 리뷰어. "
        "코드 리뷰 체크리스트를 꼼꼼히 따른다."
    ),
    verbose=True,
    allow_delegation=False,
)
```

**에이전트 설계 팁:**

- `allow_delegation=False`로 설정하면 에이전트가 다른 에이전트에게 임의로 작업을 넘기지 않아요
- `backstory`가 구체적일수록 출력 품질이 올라가요 — 역할에 맞는 경험과 성향을 적어주세요
- `verbose=True`는 개발 중에만 켜두고, 프로덕션에서는 끄세요

### Step 3: 태스크 체인 정의

태스크 순서가 곧 워크플로우예요. `context` 파라미터로 이전 태스크 결과를 다음 태스크에 전달해요.

```python
# src/tasks.py
from crewai import Task

def create_tasks(researcher, architect, developer, reviewer, requirement):
    """순차 실행 태스크 체인을 생성한다."""

    research_task = Task(
        description=f"""
        다음 요구사항을 분석하고 기술 보고서를 작성하세요:
        ---
        {requirement}
        ---
        포함할 내용:
        1. 요구사항 핵심 정리 (기능/비기능)
        2. 추천 기술 스택과 선택 근거
        3. 유사 프로젝트 레퍼런스 (있다면)
        4. 예상 리스크와 대응 방안
        """,
        expected_output="기술 스택 추천과 근거가 포함된 분석 보고서",
        agent=researcher,
    )

    design_task = Task(
        description="""
        리서치 보고서를 바탕으로 아키텍처를 설계하세요:
        1. 디렉토리 구조 (tree 형식)
        2. 핵심 모듈과 책임 분리
        3. 데이터 흐름 다이어그램
        4. API 엔드포인트 명세 (있다면)
        5. 에러 핸들링 전략
        """,
        expected_output="디렉토리 구조와 모듈 설계가 포함된 설계 문서",
        agent=architect,
        context=[research_task],
    )

    coding_task = Task(
        description="""
        설계 문서에 따라 코드를 작성하세요:
        1. 설계 문서의 디렉토리 구조를 정확히 따를 것
        2. 모든 함수에 타입 힌트와 독스트링 포함
        3. 핵심 비즈니스 로직에 단위 테스트 포함
        4. 설정값은 환경변수나 config 파일로 분리
        """,
        expected_output="실행 가능한 코드 파일 전체",
        agent=developer,
        context=[design_task],
    )

    review_task = Task(
        description="""
        생성된 코드를 다음 기준으로 리뷰하세요:
        1. 코드 품질: 가독성, 네이밍, 중복 여부
        2. 보안: 입력 검증, 시크릿 노출, SQL 인젝션
        3. 성능: 불필요한 루프, N+1 쿼리, 메모리 누수
        4. 테스트: 커버리지, 엣지케이스, 모킹 적절성
        5. 각 이슈에 대한 구체적인 수정 제안
        """,
        expected_output="이슈 목록과 수정 제안이 포함된 코드 리뷰 리포트",
        agent=reviewer,
        context=[coding_task],
    )

    return [research_task, design_task, coding_task, review_task]
```

### Step 4: Crew 구성 및 실행

```python
# src/crew.py
from crewai import Crew, Process
from agents import researcher, architect, developer, reviewer
from tasks import create_tasks

def run_coding_crew(requirement: str) -> str:
    """코딩 Crew를 실행하고 결과를 반환한다."""

    tasks = create_tasks(
        researcher, architect, developer, reviewer, requirement
    )

    crew = Crew(
        agents=[researcher, architect, developer, reviewer],
        tasks=tasks,
        process=Process.sequential,  # 순차 실행
        verbose=True,
    )

    result = crew.kickoff()
    return result.raw


if __name__ == "__main__":
    requirement = """
    Python FastAPI로 할 일 관리 REST API를 만들어줘.
    - CRUD 엔드포인트 (생성, 조회, 수정, 삭제)
    - SQLite 데이터베이스 사용
    - Pydantic 모델로 입출력 검증
    - pytest로 핵심 로직 테스트
    """

    result = run_coding_crew(requirement)
    print(result)
```

## 실행 모드 비교

CrewAI는 세 가지 실행 모드를 지원해요. 상황에 따라 골라 쓰세요.

| 모드 | 설정 | 특징 | 적합한 상황 |
|------|------|------|------------|
| Sequential | `Process.sequential` | 태스크를 순서대로 실행 | 의존성이 있는 작업 (설계→구현→리뷰) |
| Hierarchical | `Process.hierarchical` | 매니저 에이전트가 분배 | 복잡한 프로젝트, 동적 태스크 할당 |
| Consensual | `Process.consensual` | 에이전트 간 투표로 결정 | 의견 수렴이 필요한 설계 결정 |

```python
# Hierarchical 모드 예시
crew = Crew(
    agents=[researcher, architect, developer, reviewer],
    tasks=tasks,
    process=Process.hierarchical,
    manager_llm="gpt-4o",  # 매니저 에이전트 모델
    verbose=True,
)
```

## 커스텀 도구 만들기

에이전트가 코드를 파일로 저장하거나 정적 분석을 실행할 수 있도록 도구를 추가해요.

```python
# src/tools/file_writer.py
from crewai.tools import BaseTool

class FileWriterTool(BaseTool):
    name: str = "코드 파일 저장"
    description: str = "생성된 코드를 지정된 경로에 파일로 저장합니다."

    def _run(self, file_path: str, content: str) -> str:
        from pathlib import Path

        path = Path(file_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return f"파일 저장 완료: {file_path}"
```

```python
# src/tools/code_analyzer.py
from crewai.tools import BaseTool
import subprocess

class CodeAnalyzerTool(BaseTool):
    name: str = "코드 정적 분석"
    description: str = "Python 코드를 ruff로 정적 분석하고 결과를 반환합니다."

    def _run(self, file_path: str) -> str:
        result = subprocess.run(
            ["ruff", "check", file_path],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            return "정적 분석 통과 — 이슈 없음"
        return f"발견된 이슈:\n{result.stdout}"
```

## YAML 기반 설정 (대안)

코드 대신 YAML로 에이전트와 태스크를 정의할 수도 있어요. 비개발자와 협업하거나 설정을 자주 바꿀 때 유용해요.

```yaml
# config/agents.yaml
researcher:
  role: "기술 리서처"
  goal: "요구사항을 분석하고 최적의 기술 스택을 조사한다"
  backstory: "10년 경력의 시니어 개발자"

architect:
  role: "소프트웨어 설계자"
  goal: "확장 가능한 아키텍처를 설계한다"
  backstory: "대규모 시스템을 여러 번 설계한 아키텍트"

developer:
  role: "백엔드 개발자"
  goal: "깨끗하고 테스트 가능한 코드를 작성한다"
  backstory: "클린 코드를 중요시하는 개발자"

reviewer:
  role: "코드 리뷰어"
  goal: "코드의 품질, 보안, 성능을 검증한다"
  backstory: "오픈소스 메인테이너 경험이 있는 시니어 리뷰어"
```

```yaml
# config/tasks.yaml
research_task:
  description: "요구사항을 분석하고 기술 보고서를 작성하세요: {requirement}"
  expected_output: "기술 스택 추천이 포함된 분석 보고서"
  agent: researcher

design_task:
  description: "리서치 결과를 바탕으로 아키텍처를 설계하세요"
  expected_output: "디렉토리 구조와 모듈 설계 문서"
  agent: architect
  context:
    - research_task

coding_task:
  description: "설계 문서에 따라 코드를 작성하세요"
  expected_output: "실행 가능한 코드 파일"
  agent: developer
  context:
    - design_task

review_task:
  description: "생성된 코드를 리뷰하세요"
  expected_output: "코드 리뷰 리포트"
  agent: reviewer
  context:
    - coding_task
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| Crew 구조 설계 | `"이 요구사항에 맞는 CrewAI 에이전트 구성을 제안해줘"` |
| 에이전트 프롬프트 개선 | `"이 에이전트의 backstory를 더 구체적으로 만들어줘"` |
| 태스크 체인 최적화 | `"이 태스크 순서에서 병목이 될 부분을 찾아줘"` |
| 커스텀 도구 구현 | `"CrewAI BaseTool을 상속해서 DB 조회 도구를 만들어줘"` |
| 에러 디버깅 | `"CrewAI 실행 로그에서 이 에러의 원인을 분석해줘"` |

## 실전 팁

**에이전트 수는 4개 이하로 유지하세요.** 에이전트가 많아지면 컨텍스트 전달 과정에서 정보가 손실되고, 실행 시간과 비용이 빠르게 늘어나요.

**`expected_output`을 구체적으로 쓰세요.** "코드를 작성하세요"보다 "FastAPI 라우터 파일, Pydantic 모델 파일, pytest 테스트 파일을 포함한 코드"처럼 출력 형태를 명시하면 결과 품질이 올라가요.

**첫 실행은 Sequential 모드로 시작하세요.** Hierarchical 모드는 매니저 에이전트의 판단에 의존하기 때문에 결과가 불안정할 수 있어요. 파이프라인이 안정되면 그때 전환하세요.

**비용 관리:** 4개 에이전트 × Sequential 실행 = 최소 4번의 LLM 호출이에요. 개발 중에는 `gpt-4o-mini` 같은 저비용 모델로 테스트하고, 최종 실행에서만 고성능 모델을 쓰세요.

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
