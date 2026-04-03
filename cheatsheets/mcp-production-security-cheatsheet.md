# MCP 서버 프로덕션 보안 운영 치트시트

> 프로덕션에서 MCP 서버를 안전하게 운영하기 위한 보안 체크리스트 — 한 페이지 요약

## 왜 MCP 보안이 중요한가

MCP 서버는 AI 에이전트에게 파일시스템, DB, API 접근 권한을 넘겨줘요.
편리하지만, 잘못 설정하면 민감한 데이터가 AI 세션에 그대로 노출됩니다.
특히 팀 환경이나 자동화 파이프라인에서 MCP를 쓸 때는 보안 설계가 필수예요.

| 위험 | 영향 | 빈도 |
|------|------|------|
| 과도한 DB 권한 | 전체 테이블 읽기/쓰기 가능 | 매우 흔함 |
| API 키 평문 노출 | 서버 설정 파일에 키 하드코딩 | 흔함 |
| 네트워크 무제한 노출 | 외부에서 MCP 서버 직접 접근 | 가끔 |
| 입력값 검증 미흡 | SQL 인젝션, 경로 탈출 | 간헐적 |

## 패턴 1: 최소 권한 원칙 (Least Privilege)

**MCP 서버에 부여하는 권한은 반드시 필요한 최소한으로 제한하세요.**

```yaml
# 나쁜 예 — DB 전체 읽기/쓰기 권한
database:
  connection: postgresql://admin:pass@db:5432/production
  permissions: read_write

# 좋은 예 — 읽기 전용 + 특정 스키마만 허용
database:
  connection: postgresql://readonly:pass@db:5432/production
  permissions: read_only
  allowed_schemas: ["public"]
  blocked_tables: ["users", "payments", "credentials"]
```

| 리소스 | 권장 권한 | 금지 권한 |
|--------|----------|----------|
| 데이터베이스 | `SELECT` 전용 뷰 | `DROP`, `ALTER`, `DELETE` |
| 파일시스템 | 프로젝트 디렉토리만 | `/`, `~/.ssh`, `~/.env` |
| API | 읽기 전용 토큰 | 관리자 토큰 |
| Git | 특정 레포 읽기 | org 전체 접근 |

## 패턴 2: 환경 분리 (Environment Isolation)

**개발/스테이징/프로덕션 환경별로 MCP 서버 설정을 완전히 분리하세요.**

```bash
# 프로젝트별 MCP 설정 (.claude/mcp.json)
{
  "mcpServers": {
    "db-dev": {
      "command": "mcp-server-postgres",
      "args": ["--connection", "$DB_DEV_URL"],
      "env": {
        "DB_DEV_URL": "${DEV_DATABASE_URL}"
      }
    }
  }
}
```

```bash
# 환경변수로 분리 — 프로덕션 키를 로컬에 두지 않는다
export MCP_ENV=development
export DB_URL=$(vault kv get -field=url secret/db/$MCP_ENV)
```

| 환경 | 허용 MCP 서버 | 데이터 접근 |
|------|-------------|-----------|
| 개발 | 로컬 DB, 모의 API | 시드 데이터만 |
| 스테이징 | 읽기 전용 DB | 익명화된 데이터 |
| 프로덕션 | 모니터링 전용 | 메트릭/로그만 |

## 패턴 3: 네트워크 보안

**MCP 서버는 기본적으로 localhost에서만 수신하고, 외부 노출이 필요하면 터널을 사용하세요.**

```bash
# 로컬 전용 바인딩 (기본값으로 설정)
mcp-server-postgres --host 127.0.0.1 --port 3100

# 원격 접근이 필요한 경우 — SSH 터널 사용
ssh -L 3100:localhost:3100 dev-server

# 절대 하면 안 되는 것
# mcp-server --host 0.0.0.0 --port 3100  # 외부 전체 노출
```

| 설정 | 안전도 | 사용 시나리오 |
|------|--------|-------------|
| `127.0.0.1` 바인딩 | 높음 | 로컬 개발 (기본) |
| SSH 터널 | 높음 | 원격 서버 접근 |
| VPN + 내부망 | 보통 | 팀 공유 서버 |
| `0.0.0.0` 공개 | 위험 | 사용 금지 |

## 패턴 4: 인증과 토큰 관리

**API 키와 인증 토큰은 반드시 환경변수나 시크릿 매니저로 관리하세요.**

```bash
# 좋은 예 — 환경변수 참조
{
  "env": {
    "GITHUB_TOKEN": "${GITHUB_TOKEN}",
    "SLACK_TOKEN": "${SLACK_BOT_TOKEN}"
  }
}

# 나쁜 예 — 설정 파일에 하드코딩
{
  "env": {
    "GITHUB_TOKEN": "ghp_xxxxxxxxxxxx"  # 절대 금지
  }
}
```

**토큰 관리 체크리스트:**

- [ ] API 키를 설정 파일에 직접 쓰지 않았는지 확인
- [ ] `.gitignore`에 MCP 설정 파일이 포함되어 있는지 확인
- [ ] 토큰에 만료일이 설정되어 있는지 확인
- [ ] 불필요한 스코프가 없는지 확인 (예: `repo` 대신 `public_repo`)

## 패턴 5: 입력값 검증과 감사 로그

**MCP 서버로 들어오는 모든 요청을 검증하고 로그로 남기세요.**

```typescript
// MCP 서버 구현 시 입력값 검증 예시
server.tool("query_database", async (params) => {
  // 1. 허용된 테이블인지 확인
  if (!ALLOWED_TABLES.includes(params.table)) {
    throw new Error(`Table ${params.table} is not allowed`);
  }

  // 2. 쿼리 길이 제한
  if (params.query.length > 1000) {
    throw new Error("Query too long");
  }

  // 3. 위험한 키워드 차단
  const blocked = ["DROP", "DELETE", "ALTER", "TRUNCATE"];
  if (blocked.some(kw => params.query.toUpperCase().includes(kw))) {
    throw new Error("Destructive operations not allowed");
  }

  // 4. 감사 로그 기록
  logger.info({
    tool: "query_database",
    user: params._meta?.user,
    query: params.query,
    timestamp: new Date().toISOString()
  });

  return await db.query(params.query);
});
```

| 검증 항목 | 구현 방법 | 우선순위 |
|----------|----------|---------|
| 테이블/경로 허용 목록 | 화이트리스트 방식 | 필수 |
| 쿼리 길이 제한 | 최대 문자 수 설정 | 필수 |
| 위험 키워드 차단 | 블랙리스트 필터 | 필수 |
| 감사 로그 | 모든 요청 기록 | 권장 |
| Rate Limiting | 분당 요청 수 제한 | 권장 |

## 프로덕션 배포 체크리스트

MCP 서버를 프로덕션 환경에 배포하기 전 반드시 확인하세요:

- [ ] **권한 최소화** — 필요한 최소한의 DB/API 권한만 부여
- [ ] **네트워크 격리** — localhost 바인딩 또는 터널 사용
- [ ] **시크릿 분리** — API 키를 환경변수/시크릿 매니저로 관리
- [ ] **입력값 검증** — 허용 목록 기반 필터링 적용
- [ ] **감사 로그** — 모든 도구 호출 기록
- [ ] **환경 분리** — 개발/스테이징/프로덕션 설정 분리
- [ ] **TLS 적용** — 원격 연결 시 암호화 필수
- [ ] **버전 고정** — MCP 서버 의존성 버전 락
- [ ] **장애 복구** — 서버 다운 시 AI 에이전트 graceful fallback

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| DB 관리자 계정으로 MCP 연결 | 읽기 전용 전용 계정 생성 |
| `.env` 파일을 Git에 커밋 | `.gitignore` + 시크릿 매니저 사용 |
| 모든 테이블을 MCP에 노출 | 필요한 뷰(View)만 생성해서 노출 |
| MCP 서버를 `0.0.0.0`에 바인딩 | `127.0.0.1` + SSH 터널 |
| 에러 메시지에 스택트레이스 노출 | 프로덕션에서는 일반 메시지만 반환 |
| 입력값 검증 없이 쿼리 실행 | 파라미터화된 쿼리 + 화이트리스트 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
