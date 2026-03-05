# 플레이북 11: AI 보안 감사

> 코드베이스의 취약점을 체계적으로 찾아내는 3단계 보안 점검 가이드 — 시크릿 탐지, 의존성 감사, 코드 레벨 분석

## 소요 시간

30-60분 (프로젝트 규모에 따라 다름)

## 사전 준비

- Claude Code 또는 AI 코딩 도구 설치
- Node.js/Python 프로젝트 (package.json 또는 requirements.txt)
- Git 히스토리가 있는 레포지토리

## Step 1: 시크릿 & 크리덴셜 탐지

하드코딩된 API 키, 비밀번호, 토큰을 찾아내는 것이 첫 번째 단계예요.

### 1-1. git 히스토리 전체 스캔

```bash
# git 히스토리에서 민감 정보 패턴 검색
git log -p --all -S 'password' --oneline | head -20
git log -p --all -S 'api_key' --oneline | head -20
git log -p --all -S 'secret' --oneline | head -20
```

### 1-2. AI에게 시크릿 스캔 요청

```
프로젝트 전체에서 하드코딩된 시크릿을 찾아줘.
API 키, 비밀번호, 토큰, 인증서 등 민감 정보를 포함한
파일 목록과 라인 번호를 알려줘.
.env.example은 제외하고 실제 값이 노출된 곳만 찾아줘.
```

### 1-3. 자동화 도구 병행

```bash
# GitGuardian ggshield (무료 CLI)
pip install ggshield
ggshield secret scan repo .

# truffleHog (git 히스토리 포함 스캔)
pip install trufflehog
trufflehog git file://. --only-verified
```

| 도구 | 특징 | 비용 |
|------|------|------|
| `ggshield` | 350+ 패턴, CI 연동 쉬움 | 무료 (개인) |
| `trufflehog` | git 히스토리 전체 스캔 | 오픈소스 |
| `gitleaks` | 빠른 속도, GitHub Actions 지원 | 오픈소스 |

## Step 2: 의존성 취약점 감사

설치된 패키지에 알려진 취약점이 있는지 확인해요.

### 2-1. 패키지 매니저 내장 감사

```bash
# Node.js
npm audit
npm audit --json | jq '.vulnerabilities | to_entries[] | select(.value.severity == "critical" or .value.severity == "high") | .key'

# Python
pip install pip-audit
pip-audit -r requirements.txt

# Go
govulncheck ./...
```

### 2-2. AI로 감사 결과 분석

```
npm audit 결과를 분석해줘.
critical/high 취약점 중 실제로 우리 코드에서
영향받는 것만 골라서 수정 방법을 알려줘.
간접 의존성(transitive)은 업그레이드 경로도 같이 보여줘.
```

### 2-3. 의존성 업데이트 전략

| 심각도 | 대응 | 시간 |
|--------|------|------|
| Critical | 즉시 패치, 배포 | 당일 |
| High | 이번 스프린트 내 수정 | 1주 |
| Medium | 다음 정기 업데이트에 포함 | 2-4주 |
| Low | 모니터링, 필요시 수정 | 분기별 |

```bash
# 안전한 마이너/패치 업데이트만 적용
npx npm-check-updates -t patch -u
npm install
npm test
```

## Step 3: 코드 레벨 보안 분석

비즈니스 로직의 보안 취약점을 찾아요.

### 3-1. OWASP Top 10 기준 점검

```
OWASP Top 10 기준으로 이 프로젝트의 보안 취약점을 점검해줘.
특히 다음 항목을 중점적으로 봐줘:
1. SQL Injection / NoSQL Injection
2. XSS (Cross-Site Scripting)
3. 인증/인가 우회
4. SSRF (Server-Side Request Forgery)
5. 안전하지 않은 역직렬화

각 항목별로 해당하는 코드 위치와 수정 방법을 알려줘.
```

### 3-2. 입력 검증 패턴 체크

```typescript
// ❌ 위험: 사용자 입력 직접 사용
app.get('/user/:id', (req, res) => {
  db.query(`SELECT * FROM users WHERE id = ${req.params.id}`);
});

// ✅ 안전: 파라미터 바인딩
app.get('/user/:id', (req, res) => {
  db.query('SELECT * FROM users WHERE id = ?', [req.params.id]);
});
```

```python
# ❌ 위험: eval 사용
result = eval(user_input)

# ✅ 안전: ast.literal_eval 또는 명시적 파싱
import ast
result = ast.literal_eval(user_input)
```

### 3-3. 인증/인가 체크리스트

| 점검 항목 | 확인 |
|-----------|------|
| JWT 시크릿이 충분히 긴가 (256bit+) | ☐ |
| 토큰 만료 시간이 설정되어 있는가 | ☐ |
| 비밀번호 해싱에 bcrypt/argon2 사용하는가 | ☐ |
| Rate limiting이 적용되어 있는가 | ☐ |
| CORS 설정이 제한적인가 | ☐ |
| 민감 API에 인가 체크가 있는가 | ☐ |

### 3-4. CI/CD 보안 게이트 설정

```yaml
# .github/workflows/security.yml
name: Security Audit
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Secret Scanning
        uses: gitleaks/gitleaks-action@v2

      - name: Dependency Audit
        run: npm audit --audit-level=high

      - name: SAST Scan
        uses: github/codeql-action/analyze@v3
        with:
          languages: javascript
```

## 체크리스트

- [ ] git 히스토리에 노출된 시크릿 없음
- [ ] .env 파일이 .gitignore에 포함됨
- [ ] critical/high 의존성 취약점 0개
- [ ] SQL Injection 방어 (파라미터 바인딩)
- [ ] XSS 방어 (출력 이스케이프)
- [ ] 인증 토큰 안전하게 관리
- [ ] CI에 보안 스캔 자동화 적용
- [ ] Rate limiting 적용

## 정기 보안 감사 일정

| 주기 | 작업 |
|------|------|
| 매 커밋 | gitleaks + npm audit (CI) |
| 매주 | 의존성 업데이트 확인 |
| 매월 | 전체 코드 보안 리뷰 |
| 분기별 | 외부 취약점 스캐너 실행 |

## 다음 단계

→ [AI 디버깅 플레이북](04-debugging.md)에서 보안 이슈 디버깅 방법도 확인해보세요.

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
