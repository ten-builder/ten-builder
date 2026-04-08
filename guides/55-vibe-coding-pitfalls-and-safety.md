# 가이드 55: 바이브 코딩 함정 피하기

> 92%가 AI 코딩 도구를 쓰는 시대 — 실제 프로덕션 사고 사례로 배우는 안전한 AI 코딩

## 바이브 코딩의 현실

"느낌 가는 대로 AI에게 맡기고 빠르게 만든다"는 바이브 코딩은 개인 프로젝트에서 높은 생산성을 보여줍니다. 하지만 프로덕션 환경에서는 다른 이야기가 됩니다.

2026년 기준으로 AI 코딩 도구 사용 중 발생한 실제 보안 사고들이 보고되고 있습니다:

- API 키가 클라이언트 코드에 하드코딩된 채 배포
- 인증 로직이 없는 상태로 API 엔드포인트 공개
- 사용자 입력 검증 없이 쿼리 직접 실행

이 가이드는 바이브 코딩을 포기하라는 게 아닙니다. **안전하게, 더 잘 하는 방법**을 다룹니다.

## 4가지 핵심 함정

### 함정 1: 비밀값 노출

AI 에이전트는 기능 구현에 집중하다 보면 시크릿 관리를 후순위로 미루는 경향이 있습니다.

**흔한 실수:**

```javascript
// AI가 자주 생성하는 패턴 — 절대 사용 금지
const apiKey = "sk-proj-xxxx...";
const response = await fetch("https://api.openai.com/v1/...", {
  headers: { Authorization: `Bearer ${apiKey}` }
});
```

**안전한 패턴:**

```javascript
// 환경변수로 분리
const apiKey = process.env.OPENAI_API_KEY;
if (!apiKey) throw new Error("OPENAI_API_KEY is required");

const response = await fetch("https://api.openai.com/v1/...", {
  headers: { Authorization: `Bearer ${apiKey}` }
});
```

**실전 가드레일 추가:**

```bash
# .env.example에 키 이름만 명시 (값 없이)
echo "OPENAI_API_KEY=" >> .env.example
echo ".env" >> .gitignore

# pre-commit 훅으로 시크릿 유출 차단
npx @commitlint/cli --install
# 또는 git-secrets 사용
git secrets --install
git secrets --register-aws
```

---

### 함정 2: 인증 로직 부재

AI는 "동작하는 코드"를 만드는 데 탁월하지만, 보안 경계를 스스로 설정하지 않습니다.

**흔한 실수:**

```python
# 인증 없이 열린 API 엔드포인트
@app.route("/api/users")
def get_users():
    return jsonify(User.query.all())
```

**요청해야 할 내용:**

```
CLAUDE.md 또는 프롬프트에 추가:
"모든 API 엔드포인트에 인증 미들웨어를 기본으로 적용할 것.
Public 엔드포인트는 @public_endpoint 데코레이터로 명시적으로 표시."
```

**안전한 패턴:**

```python
from functools import wraps

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get("Authorization")
        if not token or not verify_token(token):
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated

@app.route("/api/users")
@require_auth
def get_users():
    return jsonify(User.query.all())
```

---

### 함정 3: 입력값 미검증

AI가 생성한 코드는 이상적인 입력을 가정하고 작성됩니다. 실제 사용자는 그렇지 않습니다.

**흔한 실수:**

```python
# SQL 인젝션 취약점
def get_user(username):
    query = f"SELECT * FROM users WHERE username = '{username}'"
    return db.execute(query)
```

**안전한 패턴:**

```python
# 파라미터화된 쿼리 사용
def get_user(username: str) -> dict | None:
    if not username or len(username) > 50:
        raise ValueError("Invalid username")
    
    query = "SELECT * FROM users WHERE username = ?"
    return db.execute(query, (username,)).fetchone()
```

**CLAUDE.md에 추가할 규칙:**

```markdown
## 보안 규칙
- 모든 사용자 입력은 반드시 타입 검증 + 길이 제한 적용
- 데이터베이스 쿼리는 파라미터화 필수
- 외부 API 응답도 검증 후 사용
```

---

### 함정 4: 에러 정보 노출

AI는 디버깅을 돕기 위해 상세한 에러 메시지를 생성하는데, 프로덕션에서 그대로 유지되면 위험합니다.

**흔한 실수:**

```javascript
app.use((err, req, res, next) => {
  res.status(500).json({
    error: err.message,
    stack: err.stack,  // 내부 경로, 라이브러리 버전 노출!
    query: req.query   // 사용자 데이터 노출!
  });
});
```

**안전한 패턴:**

```javascript
app.use((err, req, res, next) => {
  // 내부 로깅
  logger.error({ err, req: { url: req.url, method: req.method } });
  
  // 클라이언트에는 최소 정보만
  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    error: statusCode >= 500 ? "Internal Server Error" : err.message,
    requestId: req.id  // 로그 추적용 ID만 노출
  });
});
```

## 바이브 코딩을 안전하게 만드는 3단계

### Step 1: 보안 CLAUDE.md 설정

프로젝트 루트에 보안 규칙이 담긴 CLAUDE.md를 먼저 작성하세요:

```markdown
# 보안 요구사항 (AI 코딩 에이전트 필독)

## 절대 금지
- 하드코딩된 시크릿, API 키, 비밀번호
- 인증 없는 상태 변경 API
- SQL 쿼리 직접 문자열 조합

## 항상 적용
- 모든 입력값 타입 검증
- 에러 응답에 내부 정보 미포함
- 환경변수를 통한 설정값 관리
```

### Step 2: 체크리스트 기반 검토

바이브 코딩으로 만든 기능을 배포 전에 확인:

| 항목 | 확인 방법 |
|------|-----------|
| 시크릿 노출 없음 | `git diff --stat` + `git secrets --scan` |
| 인증 미들웨어 적용 | 새 엔드포인트 목록 수동 검토 |
| 입력 검증 존재 | 각 핸들러 함수 파라미터 확인 |
| 에러 메시지 안전 | 개발/프로덕션 설정 분리 여부 |
| 의존성 취약점 없음 | `npm audit` / `pip audit` |

### Step 3: AI 에이전트에게 직접 검토 요청

코드를 완성한 후 Claude에게 요청:

```
방금 작성한 [기능명] 코드의 보안 취약점을 검토해줘.
다음 항목 중심으로:
1. 시크릿/자격증명 하드코딩
2. 인증/인가 누락
3. 입력 검증 미흡
4. 에러 정보 노출
각 문제점과 수정 방법을 알려줘.
```

## 스펙 주도 개발로의 전환

바이브 코딩의 한계를 반복적으로 경험한 팀들은 **스펙 주도 개발**로 전환하고 있습니다.

차이점:

| 바이브 코딩 | 스펙 주도 개발 |
|------------|--------------|
| "로그인 기능 만들어줘" | 스펙 문서 → AI 구현 |
| 결과물 검토 후 수정 반복 | 스펙 검토 → 한 번에 구현 |
| 보안은 나중에 추가 | 스펙에 보안 요구사항 포함 |
| 빠르게 시작, 느리게 완성 | 느리게 시작, 빠르게 완성 |

작은 기능이라면 바이브 코딩이 효과적입니다. 인증, 결제, 데이터 처리처럼 복잡하고 보안이 중요한 기능은 스펙을 먼저 작성하세요.

스펙 주도 개발 패턴은 **가이드 22: 스펙 주도 AI 개발**에서 자세히 다룹니다.

## 체크리스트

- [ ] CLAUDE.md에 보안 규칙 명시
- [ ] `.gitignore`에 `.env` 추가
- [ ] 배포 전 `git secrets --scan` 실행
- [ ] 새 엔드포인트마다 인증 미들웨어 확인
- [ ] 프로덕션 에러 핸들러 설정 분리

## 다음 단계

→ [가이드 22: 스펙 주도 AI 개발](./22-spec-driven-ai-development.md)
→ [가이드 09: 보안](./9-security.md)
→ [플레이북 34: AI 코드 생성 검증](../claude-code/playbooks/34-ai-code-generation-validation.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
