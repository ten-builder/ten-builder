# 가이드 16: AI 코딩 보안 실전 가이드

> AI가 생성한 코드를 그냥 믿으면 안 돼요 — 시크릿 노출, 취약한 의존성, 인젝션까지, 실전에서 만나는 보안 위험과 방어 전략

## 소요 시간

20-30분

## 사전 준비

- AI 코딩 도구 사용 경험 (Claude Code, Cursor, Copilot 등)
- Git + CI/CD 기본 개념 이해
- 웹 애플리케이션 개발 경험

## 왜 AI 코드에 보안이 중요한가요?

AI 코딩 도구가 생성하는 코드는 빠르고 편하지만, 보안 관점에서는 "경험 없는 주니어가 Stack Overflow에서 복붙한 코드"와 비슷한 위험을 가지고 있어요. 실제로 2025-2026년 보고서들을 보면 AI 생성 코드의 취약점 비율이 사람이 작성한 코드와 거의 같거나, 경우에 따라 더 높아요.

특히 "바이브 코딩"처럼 코드 리뷰 없이 AI 출력을 그대로 쓰는 경우, 시크릿 하드코딩이나 SQL 인젝션 같은 기초적인 취약점이 프로덕션까지 올라갈 수 있어요.

**핵심 원칙: AI가 생성한 코드는 신뢰할 수 없는 코드로 취급하세요.**

## 자주 발생하는 보안 위험 5가지

| 위험 유형 | 설명 | 발생 빈도 |
|----------|------|----------|
| **시크릿 하드코딩** | API 키, DB 비밀번호가 코드에 직접 포함 | 매우 높음 |
| **SQL/NoSQL 인젝션** | 사용자 입력을 검증 없이 쿼리에 삽입 | 높음 |
| **취약한 의존성** | 오래되거나 알려진 CVE가 있는 패키지 설치 | 높음 |
| **불충분한 인증/인가** | 권한 체크 누락, 토큰 검증 생략 | 중간 |
| **XSS/CSRF** | 사용자 입력 이스케이프 미처리 | 중간 |

## Step 1: 시크릿 노출 방지

AI 도구는 예제 코드를 만들 때 환경 변수 대신 직접 값을 넣는 경우가 있어요.

### 문제 코드

```python
# AI가 생성한 코드 — 이러면 안 돼요
import boto3

client = boto3.client(
    's3',
    aws_access_key_id='AKIAIOSFODNN7EXAMPLE',
    aws_secret_access_key='wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
)
```

### 안전한 코드

```python
import os
import boto3

client = boto3.client(
    's3',
    aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
    aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY']
)
```

### pre-commit 훅으로 자동 감지

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

```bash
# 설치 & 실행
pip install pre-commit
pre-commit install

# 수동 전체 스캔
gitleaks detect --source . --verbose
```

| 도구 | 용도 | 설치 |
|------|------|------|
| **gitleaks** | 커밋 히스토리 전체 시크릿 스캔 | `brew install gitleaks` |
| **trufflehog** | 엔트로피 기반 시크릿 탐지 | `brew install trufflehog` |
| **git-secrets** | AWS 키 패턴 특화 | `brew install git-secrets` |

## Step 2: 인젝션 취약점 차단

AI는 빠른 프로토타입을 만들 때 파라미터 바인딩 대신 문자열 포맷팅을 쓰는 코드를 자주 생성해요.

### SQL 인젝션 — 문제 vs 안전

```python
# 위험한 코드: f-string으로 쿼리 조합
def get_user(username):
    query = f"SELECT * FROM users WHERE name = '{username}'"
    cursor.execute(query)

# 안전한 코드: 파라미터 바인딩
def get_user(username):
    query = "SELECT * FROM users WHERE name = %s"
    cursor.execute(query, (username,))
```

### NoSQL 인젝션 — MongoDB 예시

```javascript
// 위험한 코드: 사용자 입력을 그대로 쿼리에 사용
app.get('/user', async (req, res) => {
  const user = await db.collection('users')
    .findOne({ username: req.query.username });
  res.json(user);
});

// 안전한 코드: 타입 검증 추가
app.get('/user', async (req, res) => {
  const username = String(req.query.username); // 문자열로 강제 변환
  const user = await db.collection('users')
    .findOne({ username });
  res.json(user);
});
```

### 검증 체크리스트

- [ ] 모든 DB 쿼리에 파라미터 바인딩 사용
- [ ] 사용자 입력은 항상 타입 검증 후 사용
- [ ] ORM 사용 시에도 raw query 부분 확인
- [ ] URL 파라미터, 헤더, 쿠키 모두 검증 대상

## Step 3: 의존성 보안 관리

AI 도구가 제안하는 패키지가 최신이 아니거나, 이미 알려진 취약점을 포함할 수 있어요. 학습 데이터의 시점 차이 때문이에요.

### 자동 감사 설정

```bash
# npm 프로젝트
npm audit
npm audit fix

# Python 프로젝트
pip install pip-audit
pip-audit

# Go 프로젝트
govulncheck ./...
```

### GitHub Dependabot 설정

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    reviewers:
      - "tenbuilder10x"

  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
```

### CI 파이프라인에 보안 스캔 추가

```yaml
# .github/workflows/security.yml
name: Security Scan
on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run npm audit
        run: npm audit --audit-level=high

      - name: Run Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'HIGH,CRITICAL'
```

| 도구 | 언어/생태계 | 특징 |
|------|-----------|------|
| **npm audit** | JavaScript | 내장, 자동 fix 지원 |
| **pip-audit** | Python | PyPI 취약점 DB 연동 |
| **govulncheck** | Go | 공식 Go 보안 도구 |
| **Trivy** | 다중 언어 | 컨테이너 이미지까지 스캔 |
| **Snyk** | 다중 언어 | 무료 플랜 제공, CI 연동 |

## Step 4: 인증/인가 검증

AI가 만든 API 엔드포인트에서 가장 많이 빠지는 게 권한 체크예요. "동작하는 코드"를 만드는 건 잘하지만, "누가 접근할 수 있는지"는 자주 생략해요.

### 미들웨어 기반 인증 패턴

```typescript
// middleware/auth.ts
import { NextRequest, NextResponse } from 'next/server';
import { verifyToken } from '@/lib/jwt';

export async function authMiddleware(req: NextRequest) {
  const token = req.headers.get('authorization')?.replace('Bearer ', '');

  if (!token) {
    return NextResponse.json(
      { error: 'Authentication required' },
      { status: 401 }
    );
  }

  try {
    const payload = await verifyToken(token);
    // 요청 헤더에 사용자 정보 추가
    const headers = new Headers(req.headers);
    headers.set('x-user-id', payload.sub);
    headers.set('x-user-role', payload.role);

    return NextResponse.next({ headers });
  } catch {
    return NextResponse.json(
      { error: 'Invalid token' },
      { status: 401 }
    );
  }
}
```

### 리소스 수준 인가 체크

```typescript
// 위험: 인증만 하고 인가를 안 함
app.delete('/api/posts/:id', authenticate, async (req, res) => {
  await db.post.delete({ where: { id: req.params.id } }); // 누구나 삭제 가능
});

// 안전: 소유자 확인
app.delete('/api/posts/:id', authenticate, async (req, res) => {
  const post = await db.post.findUnique({ where: { id: req.params.id } });

  if (post.authorId !== req.user.id) {
    return res.status(403).json({ error: 'Not authorized' });
  }

  await db.post.delete({ where: { id: req.params.id } });
});
```

## Step 5: XSS/CSRF 방어

### XSS 방어 — React에서의 주의점

```tsx
// 위험: dangerouslySetInnerHTML 사용
function Comment({ html }: { html: string }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}

// 안전: 텍스트로 렌더링하거나, sanitize 후 사용
import DOMPurify from 'dompurify';

function Comment({ html }: { html: string }) {
  const clean = DOMPurify.sanitize(html);
  return <div dangerouslySetInnerHTML={{ __html: clean }} />;
}
```

### CSRF 방어 — 토큰 패턴

```typescript
// Next.js API Route에서 CSRF 토큰 검증
import { verifyCsrfToken } from '@/lib/csrf';

export async function POST(req: Request) {
  const csrfToken = req.headers.get('x-csrf-token');

  if (!verifyCsrfToken(csrfToken)) {
    return Response.json({ error: 'Invalid CSRF token' }, { status: 403 });
  }

  // 정상 처리
}
```

### 보안 헤더 설정

```typescript
// next.config.js
const securityHeaders = [
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-XSS-Protection', value: '1; mode=block' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  {
    key: 'Content-Security-Policy',
    value: "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';"
  },
];

module.exports = {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }];
  },
};
```

## AI 코드 보안 리뷰 체크리스트

AI가 생성한 코드를 머지하기 전에 이 체크리스트를 확인하세요:

| 카테고리 | 체크 항목 | 도구 |
|----------|----------|------|
| **시크릿** | 하드코딩된 API 키/비밀번호 없음 | gitleaks |
| **인젝션** | 모든 쿼리에 파라미터 바인딩 사용 | SAST 도구 |
| **의존성** | 알려진 CVE 없는 패키지만 사용 | npm audit, Trivy |
| **인증** | 모든 API에 인증 미들웨어 적용 | 수동 리뷰 |
| **인가** | 리소스 접근 시 소유자/권한 확인 | 수동 리뷰 |
| **입력 검증** | 사용자 입력 타입/길이/범위 검증 | Zod, Joi |
| **출력 인코딩** | HTML 렌더링 시 이스케이프 처리 | DOMPurify |
| **에러 처리** | 스택 트레이스/내부 정보 미노출 | 수동 리뷰 |
| **로깅** | 민감 정보(PII) 로그 미포함 | 수동 리뷰 |

## 프롬프트 단계에서 보안 요청하기

AI 도구에 보안 요구사항을 미리 명시하면 취약한 코드 생성을 줄일 수 있어요.

```markdown
# CLAUDE.md 또는 프로젝트 규칙 파일에 추가

## 보안 규칙
- 환경 변수는 반드시 process.env 또는 os.environ으로 접근
- DB 쿼리는 파라미터 바인딩만 사용 (문자열 보간 금지)
- 사용자 입력은 Zod 스키마로 검증 후 사용
- API 엔드포인트는 인증 미들웨어 필수 적용
- dangerouslySetInnerHTML 사용 시 DOMPurify 필수
```

| 프로젝트 규칙 파일 | 도구 |
|------------------|------|
| `CLAUDE.md` | Claude Code |
| `.cursorrules` | Cursor |
| `.github/copilot-instructions.md` | GitHub Copilot |

## 자동화 보안 파이프라인 구성

수동 리뷰만으로는 한계가 있어요. CI/CD에 보안 도구를 통합해서 자동으로 잡을 수 있는 건 자동으로 잡으세요.

```
코드 생성 → pre-commit(gitleaks) → PR 생성 → CI(SAST + audit) → 코드 리뷰 → 머지
     ↓              ↓                            ↓                    ↓
  AI 도구      시크릿 차단            취약점 자동 감지        사람이 최종 확인
```

### 추천 도구 조합 (무료)

| 단계 | 도구 | 역할 |
|------|------|------|
| **로컬** | gitleaks + pre-commit | 커밋 전 시크릿 감지 |
| **CI** | GitHub CodeQL | SAST (코드 정적 분석) |
| **CI** | npm audit / pip-audit | 의존성 취약점 |
| **CI** | Trivy | 컨테이너 + 파일시스템 스캔 |
| **리뷰** | GitHub Dependabot | 자동 보안 업데이트 PR |

## 다음 단계

→ [AI 보안 감사 플레이북](../claude-code/playbooks/11-security-audit.md) — 기존 코드베이스 전체를 감사하는 방법

→ [Pre-commit AI 훅](../workflows/pre-commit-ai-hooks.md) — 커밋 전 자동 품질 검사 설정

→ [GitHub Actions + AI 코드 리뷰](../workflows/github-actions-ai-review.md) — PR 단계 자동 리뷰

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
