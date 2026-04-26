# AI 에이전트 기반 실시간 코드 리뷰 봇 구현 (GitHub App)

> PR이 열리는 순간, AI 에이전트가 코드 품질·보안·테스트 커버리지를 분석하고 인라인 코멘트를 자동으로 남기는 GitHub App

## 이 예제에서 배울 수 있는 것

- GitHub App 등록 및 Webhook 이벤트 처리 방법
- FastAPI로 Webhook 서버를 구축하는 패턴
- Claude API로 PR diff를 분석하고 인라인 코멘트를 작성하는 방법
- 시크릿 검증으로 Webhook 보안을 강화하는 방법
- 코드 품질·보안·테스트 세 가지 관점의 리뷰를 자동화하는 전략

## 프로젝트 구조

```
ai-github-app-reviewer/
├── app/
│   ├── main.py          # FastAPI 앱 진입점
│   ├── webhook.py       # Webhook 이벤트 핸들러
│   ├── reviewer.py      # Claude API 기반 리뷰 로직
│   └── github_client.py # PyGithub 래퍼
├── tests/
│   └── test_reviewer.py
├── .env.example
├── requirements.txt
└── README.md
```

## 시작하기

### 1. 의존성 설치

```bash
git clone https://github.com/your-org/ai-github-app-reviewer
cd ai-github-app-reviewer
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

**requirements.txt:**

```
fastapi==0.115.0
uvicorn==0.30.0
PyGithub==2.4.0
anthropic==0.34.0
python-dotenv==1.0.0
httpx==0.27.0
```

### 2. GitHub App 등록

1. GitHub → Settings → Developer settings → GitHub Apps → New GitHub App
2. 아래 권한 설정:

| 권한 | 레벨 |
|------|------|
| Pull requests | Read & Write |
| Contents | Read |
| Issues | Read & Write |

3. Subscribe to events: `pull_request`
4. Webhook URL: `https://your-server.com/webhook`
5. App ID와 Private Key 저장

### 3. 환경변수 설정

```bash
cp .env.example .env
```

```env
GITHUB_APP_ID=your_app_id
GITHUB_APP_PRIVATE_KEY_PATH=./private-key.pem
GITHUB_WEBHOOK_SECRET=your_webhook_secret
ANTHROPIC_API_KEY=your_anthropic_api_key
```

## 핵심 코드

### Webhook 서버 (app/main.py)

```python
from fastapi import FastAPI, Request, HTTPException
from dotenv import load_dotenv
from app.webhook import handle_pull_request_event
import hmac, hashlib, os

load_dotenv()
app = FastAPI()

@app.post("/webhook")
async def webhook(request: Request):
    # 시크릿 검증
    body = await request.body()
    signature = request.headers.get("X-Hub-Signature-256", "")
    secret = os.getenv("GITHUB_WEBHOOK_SECRET", "").encode()

    expected = "sha256=" + hmac.new(
        secret, body, hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected, signature):
        raise HTTPException(status_code=403, detail="서명 불일치")

    payload = await request.json()
    event_type = request.headers.get("X-GitHub-Event")

    if event_type == "pull_request" and payload["action"] in ("opened", "synchronize"):
        await handle_pull_request_event(payload)

    return {"status": "ok"}
```

### PR 이벤트 핸들러 (app/webhook.py)

```python
from app.reviewer import review_pull_request
from app.github_client import get_github_client

async def handle_pull_request_event(payload: dict):
    repo_full_name = payload["repository"]["full_name"]
    pr_number = payload["pull_request"]["number"]
    installation_id = payload["installation"]["id"]

    gh = get_github_client(installation_id)
    repo = gh.get_repo(repo_full_name)
    pr = repo.get_pull(pr_number)

    # diff 수집 (최대 50KB)
    diff = pr.get_files()
    file_diffs = []
    total_size = 0

    for f in diff:
        if total_size > 50_000:
            break
        if f.patch:
            file_diffs.append({
                "filename": f.filename,
                "patch": f.patch,
                "additions": f.additions,
                "deletions": f.deletions,
            })
            total_size += len(f.patch)

    # Claude 리뷰 요청
    comments = await review_pull_request(file_diffs, pr.title, pr.body)

    # 인라인 코멘트 작성
    commit = pr.get_commits().reversed[0]
    for c in comments:
        try:
            pr.create_review_comment(
                body=c["body"],
                commit=commit,
                path=c["path"],
                line=c["line"],
            )
        except Exception:
            pass  # 해당 줄이 diff에 없는 경우 스킵
```

### Claude 기반 리뷰 로직 (app/reviewer.py)

```python
import anthropic, json

client = anthropic.Anthropic()

REVIEW_PROMPT = """PR diff를 분석하여 다음 세 관점에서 코멘트를 작성하세요:
1. 코드 품질: 가독성, 중복, 복잡도
2. 보안: SQL 인젝션, 하드코딩 시크릿, 인증 누락
3. 테스트: 커버리지 부족, 엣지 케이스 미처리

응답 형식 (JSON 배열):
[{"path": "파일경로", "line": 줄번호(정수), "body": "코멘트 내용"}]

심각한 문제만 코멘트. 스타일 지적은 하지 않는다.
3개 이하로 제한."""

async def review_pull_request(
    file_diffs: list[dict],
    pr_title: str,
    pr_body: str | None,
) -> list[dict]:
    diff_text = "\n\n".join(
        f"## {f['filename']}\n```diff\n{f['patch']}\n```"
        for f in file_diffs
    )

    message = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"{REVIEW_PROMPT}\n\nPR 제목: {pr_title}\n\n{diff_text}"
        }]
    )

    raw = message.content[0].text.strip()
    # JSON 블록만 추출
    if "```json" in raw:
        raw = raw.split("```json")[1].split("```")[0].strip()
    elif "```" in raw:
        raw = raw.split("```")[1].split("```")[0].strip()

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return []
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 보안 집중 리뷰 | `이 diff에서 OWASP Top 10 기준 취약점만 찾아줘` |
| 성능 분석 | `O(n²) 이상의 복잡도가 있는 코드를 찾고 개선안을 제시해줘` |
| 테스트 제안 | `이 변경사항에서 테스트가 필요한 엣지 케이스 3개를 제안해줘` |
| 코멘트 요약 | `이 PR의 전반적인 구조 변경을 한 문단으로 요약해줘` |

## 로컬 테스트

```bash
# 서버 시작
uvicorn app.main:app --reload --port 8000

# ngrok으로 외부 노출 (GitHub Webhook 테스트용)
ngrok http 8000

# GitHub App Webhook URL을 ngrok URL로 설정 후
# 테스트 PR 생성하면 자동 리뷰 동작 확인 가능
```

## 배포 고려사항

- **비동기 처리:** PR이 동시에 여러 개 열릴 때를 위해 Celery 또는 `asyncio.Queue` 적용 권장
- **Rate Limiting:** GitHub API는 설치당 5,000 req/h, Claude API는 분당 요청 제한 확인
- **Diff 크기 제한:** 5만 자 이상 diff는 파일별로 분할 처리
- **재시도 로직:** Webhook 전달 실패 시 GitHub가 자동 재시도 — 멱등성 보장 필요

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
