# EP27: AI 에이전트로 Rust 백엔드 처음부터 만들기 — Axum 실전

> Claude Code와 함께 Axum 웹 서버를 처음부터 구현하고 Docker로 배포합니다. Rust의 타입 안전성과 async/await로 프로덕션 수준의 REST API를 만드는 전 과정을 다룹니다.

## 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- Axum 0.8 + Tokio 기반 REST API 서버 설계 — 라우팅, 미들웨어, 에러 핸들링
- SQLx + PostgreSQL 연동 — 타입 안전한 쿼리와 마이그레이션 자동화
- JWT 인증 미들웨어 직접 구현 — `FromRequestParts` 패턴
- Docker 멀티 스테이지 빌드로 최적화된 프로덕션 이미지 만들기
- Claude Code로 Rust 작업하는 실전 워크플로우 — 컴파일 에러 자동 수정 패턴

---

## 1. 전체 아키텍처

```
클라이언트
    ↕ HTTP/JSON
Axum 서버 (Tokio 런타임)
    ↕ JWT 미들웨어 (인증)
라우터
    ├── /api/users    → users 핸들러
    ├── /api/items    → items 핸들러
    └── /api/auth     → auth 핸들러
         ↕ SQLx
PostgreSQL
```

Axum은 Tokio 팀이 만든 Rust 웹 프레임워크예요. Tower 미들웨어 생태계를 그대로 쓸 수 있어서, 인증·로깅·속도 제한 같은 레이어를 깔끔하게 쌓을 수 있습니다.

---

## 2. 프로젝트 구조

```
axum-api/
├── src/
│   ├── main.rs           # 서버 진입점
│   ├── routes/
│   │   ├── mod.rs        # 라우터 조합
│   │   ├── auth.rs       # 로그인/회원가입
│   │   └── items.rs      # 리소스 CRUD
│   ├── middleware/
│   │   └── auth.rs       # JWT 검증 레이어
│   ├── models/
│   │   ├── user.rs
│   │   └── item.rs
│   └── db.rs             # DB 커넥션 풀
├── migrations/
│   └── 20260525_init.sql
├── Cargo.toml
├── Dockerfile
└── docker-compose.yml
```

---

## 3. 시작하기

```bash
# Rust 설치 (최신)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# sqlx-cli 설치
cargo install sqlx-cli --features postgres

# 프로젝트 생성
cargo new axum-api && cd axum-api

# DB 실행
docker run -d --name pg \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 postgres:16-alpine

# 마이그레이션 실행
export DATABASE_URL=postgres://postgres:secret@localhost:5432/axumdb
sqlx database create
sqlx migrate run
```

---

## 4. 핵심 코드

### Cargo.toml — 의존성 설정

```toml
[dependencies]
axum       = "0.8"
tokio      = { version = "1", features = ["macros", "rt-multi-thread"] }
sqlx       = { version = "0.8", features = ["postgres", "runtime-tokio", "uuid", "chrono"] }
serde      = { version = "1", features = ["derive"] }
serde_json = "1"
jsonwebtoken = "9"
bcrypt     = "0.16"
tower-http = { version = "0.6", features = ["trace", "cors"] }
uuid       = { version = "1", features = ["v4"] }
tracing-subscriber = "0.3"
anyhow     = "1"
```

### main.rs — 서버 조립

```rust
use axum::{Router, serve};
use std::net::SocketAddr;
use sqlx::postgres::PgPoolOptions;
use tokio::net::TcpListener;
use tower_http::trace::TraceLayer;

mod db;
mod middleware;
mod models;
mod routes;

#[derive(Clone)]
pub struct AppState {
    pub db: sqlx::PgPool,
    pub jwt_secret: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let database_url = std::env::var("DATABASE_URL")?;
    let jwt_secret   = std::env::var("JWT_SECRET")?;

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await?;

    let state = AppState { db: pool, jwt_secret };

    let app = Router::new()
        .nest("/api", routes::router())
        .with_state(state)
        .layer(TraceLayer::new_for_http());

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    let listener = TcpListener::bind(addr).await?;
    tracing::info!("서버 시작: {addr}");
    serve(listener, app).await?;
    Ok(())
}
```

### JWT 인증 미들웨어

```rust
// middleware/auth.rs
use axum::{
    extract::{FromRequestParts, State},
    http::{request::Parts, StatusCode},
};
use jsonwebtoken::{decode, DecodingKey, Validation};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String, // user_id
    pub exp: usize,
}

pub struct AuthUser(pub Claims);

#[axum::async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
    crate::AppState: axum::extract::FromRef<S>,
{
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(
        parts: &mut Parts,
        state: &S,
    ) -> Result<Self, Self::Rejection> {
        use axum::extract::FromRef;
        let app_state = crate::AppState::from_ref(state);

        let token = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or((StatusCode::UNAUTHORIZED, "토큰이 없습니다"))?;

        let key = DecodingKey::from_secret(app_state.jwt_secret.as_bytes());
        let data = decode::<Claims>(token, &key, &Validation::default())
            .map_err(|_| (StatusCode::UNAUTHORIZED, "유효하지 않은 토큰"))?;

        Ok(AuthUser(data.claims))
    }
}
```

### items 핸들러 — CRUD 전체

```rust
// routes/items.rs
use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use crate::{AppState, middleware::auth::AuthUser};

#[derive(sqlx::FromRow, Serialize)]
pub struct Item {
    pub id: Uuid,
    pub name: String,
    pub owner_id: String,
}

#[derive(Deserialize)]
pub struct CreateItem {
    pub name: String,
}

// GET /api/items
pub async fn list_items(
    State(state): State<AppState>,
    AuthUser(claims): AuthUser,
) -> Result<Json<Vec<Item>>, StatusCode> {
    let items = sqlx::query_as!(
        Item,
        "SELECT id, name, owner_id FROM items WHERE owner_id = $1",
        claims.sub
    )
    .fetch_all(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(items))
}

// POST /api/items
pub async fn create_item(
    State(state): State<AppState>,
    AuthUser(claims): AuthUser,
    Json(body): Json<CreateItem>,
) -> Result<(StatusCode, Json<Item>), StatusCode> {
    let item = sqlx::query_as!(
        Item,
        "INSERT INTO items (id, name, owner_id) VALUES ($1, $2, $3) RETURNING *",
        Uuid::new_v4(),
        body.name,
        claims.sub
    )
    .fetch_one(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(item)))
}
```

---

## 5. Docker 멀티 스테이지 빌드

```dockerfile
# Dockerfile
## 1단계: 빌드
FROM rust:1.80-slim AS builder
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY migrations ./migrations
RUN apt-get update && apt-get install -y libssl-dev pkg-config && rm -rf /var/lib/apt/lists/*
RUN cargo build --release

## 2단계: 최소 실행 이미지
FROM debian:bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/axum-api /app/axum-api
COPY --from=builder /app/migrations /app/migrations
EXPOSE 3000
CMD ["./axum-api"]
```

```yaml
# docker-compose.yml
services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://postgres:secret@db:5432/axumdb
      JWT_SECRET: super-secret-key-change-in-prod
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: axumdb
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - pg_data:/var/lib/postgresql/data

volumes:
  pg_data:
```

---

## 6. Claude Code로 Rust 작업하는 요령

| 상황 | 프롬프트 예시 |
|------|-------------|
| 컴파일 에러 | `이 에러를 수정해줘 — 라이프타임 충돌` |
| 타입 추론 | `FromRequestParts 구현체를 State와 같이 쓸 때 트레이트 바운드 정리해줘` |
| 쿼리 작성 | `sqlx::query_as! 매크로로 users 조인 items 쿼리 만들어줘` |
| 테스트 | `이 핸들러 함수의 통합 테스트를 axum::test 기반으로 작성해줘` |
| Docker | `멀티 스테이지 빌드에서 바이너리 크기를 줄이는 설정 추가해줘` |

Rust는 컴파일 에러 메시지가 상세하기 때문에 에러 전체를 그대로 붙여서 물어보면 Claude Code가 정확하게 잡아줘요.

---

## 7. 따라하기 단계 요약

### Step 1: 프로젝트 초기화

```bash
cargo new axum-api && cd axum-api
# Cargo.toml에 의존성 추가 (위 내용 참고)
```

### Step 2: DB 스키마 작성 + 마이그레이션

```sql
-- migrations/20260525_init.sql
CREATE TABLE users (
    id       TEXT PRIMARY KEY,
    email    TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL
);
CREATE TABLE items (
    id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name     TEXT NOT NULL,
    owner_id TEXT REFERENCES users(id) ON DELETE CASCADE
);
```

### Step 3: 빌드 + 실행

```bash
cargo build          # 첫 빌드는 의존성 다운로드로 3~5분 소요
cargo run            # 로컬 개발 서버 실행
cargo test           # 통합 테스트 실행
docker compose up -d # 프로덕션 환경 실행
```

---

## 더 알아보기

- [Axum 공식 예제 모음](https://github.com/tokio-rs/axum/tree/main/examples)
- [SQLx 비동기 쿼리 패턴](../guides/)
- [AI 에이전트 풀스택 타입 안전성 확보 플레이북](../claude-code/playbooks/60-fullstack-type-safety-playbook.md)
- [Docker 컨테이너 기반 배포 워크플로우](../workflows/)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
