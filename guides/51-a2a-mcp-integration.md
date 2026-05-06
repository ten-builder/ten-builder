# 가이드 51: A2A + MCP 통합 실전 가이드

> 에이전트끼리 말을 걸고, 도구에 손을 뻗는 — A2A와 MCP를 함께 쓰는 방법

## 소요 시간

30-40분

## 사전 준비

- AI 코딩 에이전트 기본 사용 경험 (Claude Code, Cursor 등)
- MCP가 뭔지 대략 알고 있음 ([MCP 생태계 치트시트](../cheatsheets/mcp-ecosystem-cheatsheet.md) 참고)
- Python 또는 Node.js 기본 지식

## 왜 두 프로토콜이 필요한가요?

에이전트를 여럿 굴리다 보면 두 종류의 연결이 필요하다는 걸 금방 알게 돼요.

1. **에이전트 → 도구**: 파일 읽기, GitHub PR 열기, DB 쿼리
2. **에이전트 → 에이전트**: "이 코드 리뷰해줘", "테스트 짜줘"

MCP는 (1)번 문제를, A2A는 (2)번 문제를 풀어요. 하나만 써도 어느 정도 돌아가지만, 둘을 같이 쓰면 진짜 멀티 에이전트 시스템이 돼요.

```
A2A 레이어 (에이전트 ↔ 에이전트)
─────────────────────────────────────
  Orchestrator
      │ A2A (태스크 위임)
  ┌───▼──────────┬──────────────┐
  │  Coder Agent │ Reviewer     │
  │  (MCP 클라이언트) │  Agent        │
  └──────┬───────┴───────┬──────┘
         │               │
MCP 레이어 (에이전트 ↔ 도구)
─────────────────────────────────────
   GitHub   파일시스템    웹 검색
```

## 핵심 개념 비교

| 항목 | MCP | A2A |
|------|-----|-----|
| **누가 연결되나** | 에이전트 → 도구/데이터 | 에이전트 → 에이전트 |
| **작업 단위** | 툴 호출 (동기, 단발) | 태스크 (멀티턴, 스트리밍) |
| **발견 방법** | 툴 목록 조회 | Agent Card (JSON 명세) |
| **통신 방식** | HTTP/stdio | JSON-RPC over HTTP |
| **상태 관리** | Stateless | Stateful (태스크 ID) |
| **언제 쓰나** | 툴 접근 | 에이전트 협업 |

> **한 줄 요약:** MCP는 에이전트의 손(도구 접근), A2A는 에이전트의 입(에이전트 간 소통)이에요.

## Step 1: Agent Card 만들기

A2A에서 에이전트는 자기 소개서인 Agent Card를 발행해요. 다른 에이전트나 오케스트레이터가 이 카드를 보고 "얘한테 뭘 맡길 수 있구나"를 판단해요.

```json
{
  "name": "CodeReviewAgent",
  "description": "Python 코드 리뷰 및 개선 제안 전문 에이전트",
  "version": "1.0.0",
  "url": "http://localhost:8001",
  "capabilities": {
    "tasks": ["code_review", "security_check", "style_check"],
    "streaming": true,
    "authentication": "oauth2"
  },
  "skills": [
    {
      "id": "review_python",
      "name": "Python 코드 리뷰",
      "description": "Python 코드의 버그, 보안 취약점, 스타일 문제를 분석해요",
      "inputSchema": {
        "type": "object",
        "properties": {
          "code": { "type": "string" },
          "context": { "type": "string" }
        },
        "required": ["code"]
      }
    }
  ]
}
```

Agent Card는 `/.well-known/agent.json` 경로에 노출해요. 오케스트레이터가 이 경로를 읽어서 에이전트를 자동으로 발견해요.

## Step 2: A2A 서버 구현 (Python ADK)

Google ADK를 쓰면 A2A 서버를 빠르게 만들 수 있어요.

```bash
# ADK 설치
pip install google-adk

# 프로젝트 초기화
adk new code-review-agent
cd code-review-agent
```

```python
# agent.py
from google.adk.agent import Agent, Task
from google.adk.skills import Skill

class CodeReviewAgent(Agent):
    def __init__(self):
        super().__init__(
            name="CodeReviewAgent",
            description="Python 코드 리뷰 에이전트",
        )

    async def handle_task(self, task: Task) -> Task:
        code = task.input.get("code", "")
        context = task.input.get("context", "")

        # 실제 리뷰 로직 (여기서 LLM 호출)
        review_result = await self._review_code(code, context)

        task.status = "completed"
        task.output = {
            "review": review_result,
            "issues": review_result.get("issues", []),
            "suggestions": review_result.get("suggestions", [])
        }
        return task

    async def _review_code(self, code: str, context: str) -> dict:
        # LLM 기반 코드 리뷰 구현
        prompt = f"""
코드를 리뷰해주세요.
컨텍스트: {context}

코드:
{code}

버그, 보안 취약점, 개선 포인트를 JSON으로 반환해주세요.
        """
        # ... LLM 호출 ...
        return {"issues": [], "suggestions": []}
```

```bash
# 에이전트 실행
adk run agent.py --port 8001
```

## Step 3: MCP 도구와 연결

A2A 에이전트가 코드 리뷰를 하려면 파일을 읽고 GitHub에 코멘트를 달 수 있어야 해요. 여기서 MCP가 필요해요.

```python
# agent_with_mcp.py
from google.adk.agent import Agent, Task
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
import asyncio

class CodeReviewAgent(Agent):
    def __init__(self):
        super().__init__(name="CodeReviewAgent")
        self.mcp_sessions = {}

    async def setup_mcp(self):
        # 파일시스템 MCP 연결
        fs_params = StdioServerParameters(
            command="npx",
            args=["-y", "@modelcontextprotocol/server-filesystem", "/workspace"]
        )
        self.mcp_sessions["filesystem"] = await self._connect_mcp(fs_params)

        # GitHub MCP 연결
        gh_params = StdioServerParameters(
            command="npx",
            args=["-y", "@modelcontextprotocol/server-github"],
            env={"GITHUB_PERSONAL_ACCESS_TOKEN": os.environ["GITHUB_TOKEN"]}
        )
        self.mcp_sessions["github"] = await self._connect_mcp(gh_params)

    async def read_file_via_mcp(self, path: str) -> str:
        session = self.mcp_sessions["filesystem"]
        result = await session.call_tool("read_file", {"path": path})
        return result.content[0].text

    async def post_review_via_mcp(self, pr_number: int, comment: str):
        session = self.mcp_sessions["github"]
        await session.call_tool("create_pull_request_review", {
            "owner": "ten-builder",
            "repo": "ten-builder",
            "pull_number": pr_number,
            "body": comment,
            "event": "COMMENT"
        })
```

핵심 패턴: **A2A로 태스크를 받고, MCP로 실제 작업을 수행해요.**

## Step 4: 오케스트레이터 구현

여러 에이전트를 조율하는 오케스트레이터는 A2A 클라이언트로 동작해요.

```python
# orchestrator.py
import httpx
import json
import uuid

class Orchestrator:
    def __init__(self):
        self.agents = {}

    async def discover_agent(self, base_url: str):
        """Agent Card를 읽어서 에이전트를 등록해요"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{base_url}/.well-known/agent.json")
            agent_card = resp.json()
            self.agents[agent_card["name"]] = {
                "url": base_url,
                "card": agent_card
            }

    async def delegate_task(self, agent_name: str, skill_id: str, input_data: dict) -> dict:
        """에이전트에게 태스크를 위임해요"""
        agent = self.agents[agent_name]
        task_id = str(uuid.uuid4())

        payload = {
            "jsonrpc": "2.0",
            "method": "tasks/send",
            "params": {
                "id": task_id,
                "skill": skill_id,
                "input": input_data
            },
            "id": task_id
        }

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{agent['url']}/a2a",
                json=payload,
                timeout=60.0
            )
            return resp.json()

    async def review_pr(self, pr_number: int, code: str):
        """코드 리뷰 태스크를 CodeReviewAgent에게 위임해요"""
        result = await self.delegate_task(
            agent_name="CodeReviewAgent",
            skill_id="review_python",
            input_data={
                "code": code,
                "context": f"PR #{pr_number} 리뷰 요청"
            }
        )
        return result.get("result", {}).get("output", {})
```

## Step 5: 실전 패턴 — CI/CD 연동

실제 개발 워크플로우에서 A2A + MCP를 활용하는 방법이에요.

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run A2A Orchestrator
        run: |
          python3 orchestrator.py \
            --pr-number ${{ github.event.number }} \
            --agents "http://review-agent:8001,http://security-agent:8002"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GOOGLE_API_KEY: ${{ secrets.GOOGLE_API_KEY }}
```

```python
# orchestrator_ci.py (CI 실행용)
import asyncio
import sys

async def main(pr_number: int, agent_urls: list):
    orch = Orchestrator()

    # 에이전트 발견
    for url in agent_urls:
        await orch.discover_agent(url)

    # PR diff 가져오기 (MCP via 코드 리뷰 에이전트가 내부적으로 처리)
    review_result = await orch.review_pr(pr_number, code="")

    print(f"리뷰 완료: {len(review_result.get('issues', []))}건 발견")

    # 이슈가 있으면 exit code 1 (CI 실패)
    critical_issues = [i for i in review_result.get("issues", []) if i.get("severity") == "critical"]
    if critical_issues:
        print(f"치명적 이슈 {len(critical_issues)}건 — CI 실패")
        sys.exit(1)

asyncio.run(main(
    pr_number=int(sys.argv[1]),
    agent_urls=sys.argv[2].split(",")
))
```

## 흔한 실수와 해결책

| 실수 | 문제 | 해결 |
|------|------|------|
| MCP로 에이전트 간 통신 시도 | 상태 공유가 안 됨, 스케일 불가 | A2A로 전환 |
| A2A로 도구 호출 | 지연 높음, 오버헤드 | MCP로 전환 |
| Agent Card 없이 직접 호출 | 발견 불가, 하드코딩 | Agent Card 필수 |
| 태스크 ID 없이 요청 | 중복 실행, 추적 불가 | UUID로 태스크 ID 생성 |
| 동기 방식으로 긴 태스크 | 타임아웃 발생 | 스트리밍 또는 폴링 사용 |

## 언제 어떤 프로토콜을 쓰나요?

```
작업 유형에 따른 선택 기준

도구 호출이 필요한가?
  YES → MCP 사용
    예: 파일 읽기, GitHub API, DB 쿼리

다른 AI 에이전트에게 위임하는가?
  YES → A2A 사용
    예: 코드 리뷰, 테스트 생성, 문서 작성

에이전트가 도구도 쓰고 다른 에이전트와도 협력하나?
  YES → A2A (외부 통신) + MCP (내부 도구) 동시 사용
```

## 체크리스트

- [ ] Agent Card를 `/.well-known/agent.json`에 발행했나요?
- [ ] 에이전트마다 고유한 태스크 ID를 사용하고 있나요?
- [ ] MCP 연결은 에이전트 내부에서만 사용하고 있나요?
- [ ] A2A 태스크 실패 시 재시도 로직이 있나요?
- [ ] 오케스트레이터가 에이전트를 하드코딩하지 않고 Agent Card로 발견하나요?

## 다음 단계

- [커스텀 MCP 서버 구축](../workflows/custom-mcp-server.md)
- [AI 에이전트 프로덕션 배포](../workflows/ai-agent-production-deployment.md)
- [AI 에이전트 감독 워크플로우](../workflows/ai-agent-supervision.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
