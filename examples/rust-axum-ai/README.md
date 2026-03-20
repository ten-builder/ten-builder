# Rust Axum + AI API 예제

> Axum 프레임워크로 타입 안전한 REST API를 AI 코딩 도구와 함께 만드는 실전 예제

## 이 예제에서 배울 수 있는 것

- Axum의 핵심 패턴: Router, Handler, Extractor 구조
- AI 코딩 도구로 Rust 보일러플레이트를 빠르게 생성하는 방법
- 컴파일러 에러를 AI에게 넘겨서 해결하는 워크플로우
- SQLx를 사용한 데이터베이스 연동과 마이그레이션
- 에러 핸들링과 응답 타입을 체계적으로 설계하는 패턴

## 프로젝트 구조

```
rust-axum-ai/
├── Cargo.toml
├── src/
│   ├── main.rs          # 서버 진입점, 라우터 설정
│   ├── handlers/        # 요청 핸들러
│   │   ├── mod.rs
│   │   ├── health.rs
│   │   └── tasks.rs
│   ├── models/          # 데이터 모델 & DB 스키마
│   │   ├── mod.rs
│   │   └── task.rs
│   ├── errors.rs        # 통합 에러 타입
│   └── db.rs            # DB 연결 풀 설정
├── migrations/
│   └── 001_create_tasks.sql
└── tests/
    └── api_tests.rs
```

## 시작하기

```bash
# 프로젝트 생성
cargo init rust-axum-api
cd rust-axum-api

# 의존성 추가
cargo add axum tokio --features tokio/full
cargo add serde --features derive
cargo add serde_json
cargo add sqlx --features runtime-tokio,sqlite
cargo add tower-http --features cors,trace
cargo add tracing tracing-subscriber
cargo add uuid --features v4,serde
cargo add chrono --features serde
```

## 핵심 코드

### Cargo.toml — 의존성 설정

```toml
[package]
name = "rust-axum-api"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = "0.8"
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
sqlx = { version = "0.8", features = ["runtime-tokio", "sqlite"] }
tower-http = { version = "0.6", features = ["cors", "trace"] }
tracing = "0.1"
tracing-subscriber = "0.3"
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
```

### main.rs — 서버 진입점

```rust
use axum::{Router, routing::{get, post}};
use sqlx::sqlite::SqlitePoolOptions;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use tracing_subscriber;

mod handlers;
mod models;
mod errors;
mod db;

#[tokio::main]
async fn main() {
    tracing_subscriber::init();

    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect("sqlite:tasks.db?mode=rwc")
        .await
        .expect("DB 연결 실패");

    // 마이그레이션 실행
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("마이그레이션 실패");

    let app = Router::new()
        .route("/health", get(handlers::health::check))
        .route("/tasks", get(handlers::tasks::list))
        .route("/tasks", post(handlers::tasks::create))
        .route("/tasks/{id}", get(handlers::tasks::get_by_id))
        .route("/tasks/{id}", axum::routing::put(handlers::tasks::update))
        .route("/tasks/{id}", axum::routing::delete(handlers::tasks::delete))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(pool);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
        .await
        .unwrap();

    tracing::info!("서버 시작: http://localhost:3000");
    axum::serve(listener, app).await.unwrap();
}
```

### models/task.rs — 데이터 모델

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Task {
    pub id: String,
    pub title: String,
    pub description: Option<String>,
    pub status: String,       // "pending" | "in_progress" | "done"
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateTask {
    pub title: String,
    pub description: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateTask {
    pub title: Option<String>,
    pub description: Option<String>,
    pub status: Option<String>,
}

impl Task {
    pub fn new(input: CreateTask) -> Self {
        let now = Utc::now().to_rfc3339();
        Self {
            id: Uuid::new_v4().to_string(),
            title: input.title,
            description: input.description,
            status: "pending".to_string(),
            created_at: now.clone(),
            updated_at: now,
        }
    }
}
```

### handlers/tasks.rs — CRUD 핸들러

```rust
use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use sqlx::SqlitePool;

use crate::errors::AppError;
use crate::models::task::{CreateTask, Task, UpdateTask};

pub async fn list(
    State(pool): State<SqlitePool>,
) -> Result<Json<Vec<Task>>, AppError> {
    let tasks = sqlx::query_as::<_, Task>("SELECT * FROM tasks ORDER BY created_at DESC")
        .fetch_all(&pool)
        .await?;
    Ok(Json(tasks))
}

pub async fn create(
    State(pool): State<SqlitePool>,
    Json(input): Json<CreateTask>,
) -> Result<(StatusCode, Json<Task>), AppError> {
    let task = Task::new(input);
    sqlx::query(
        "INSERT INTO tasks (id, title, description, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)"
    )
    .bind(&task.id)
    .bind(&task.title)
    .bind(&task.description)
    .bind(&task.status)
    .bind(&task.created_at)
    .bind(&task.updated_at)
    .execute(&pool)
    .await?;

    Ok((StatusCode::CREATED, Json(task)))
}

pub async fn get_by_id(
    State(pool): State<SqlitePool>,
    Path(id): Path<String>,
) -> Result<Json<Task>, AppError> {
    let task = sqlx::query_as::<_, Task>("SELECT * FROM tasks WHERE id = ?")
        .bind(&id)
        .fetch_optional(&pool)
        .await?
        .ok_or(AppError::NotFound)?;
    Ok(Json(task))
}

pub async fn update(
    State(pool): State<SqlitePool>,
    Path(id): Path<String>,
    Json(input): Json<UpdateTask>,
) -> Result<Json<Task>, AppError> {
    let existing = sqlx::query_as::<_, Task>("SELECT * FROM tasks WHERE id = ?")
        .bind(&id)
        .fetch_optional(&pool)
        .await?
        .ok_or(AppError::NotFound)?;

    let title = input.title.unwrap_or(existing.title);
    let description = input.description.or(existing.description);
    let status = input.status.unwrap_or(existing.status);
    let now = chrono::Utc::now().to_rfc3339();

    sqlx::query("UPDATE tasks SET title = ?, description = ?, status = ?, updated_at = ? WHERE id = ?")
        .bind(&title)
        .bind(&description)
        .bind(&status)
        .bind(&now)
        .bind(&id)
        .execute(&pool)
        .await?;

    let updated = sqlx::query_as::<_, Task>("SELECT * FROM tasks WHERE id = ?")
        .bind(&id)
        .fetch_one(&pool)
        .await?;

    Ok(Json(updated))
}

pub async fn delete(
    State(pool): State<SqlitePool>,
    Path(id): Path<String>,
) -> Result<StatusCode, AppError> {
    let result = sqlx::query("DELETE FROM tasks WHERE id = ?")
        .bind(&id)
        .execute(&pool)
        .await?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound);
    }
    Ok(StatusCode::NO_CONTENT)
}
```

### errors.rs — 통합 에러 타입

Rust의 타입 시스템을 사용하면 API 에러를 컴파일 타임에 잡을 수 있어요. AI에게 "에러 타입을 만들어줘"라고 요청하면 `From` trait 구현까지 생성해줍니다.

```rust
use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

pub enum AppError {
    NotFound,
    BadRequest(String),
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AppError::NotFound => (StatusCode::NOT_FOUND, "리소스를 찾을 수 없습니다".to_string()),
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            AppError::Internal(msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg),
        };

        let body = Json(json!({
            "error": message,
            "status": status.as_u16()
        }));

        (status, body).into_response()
    }
}

impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        AppError::Internal(format!("DB 에러: {}", err))
    }
}
```

### migrations/001_create_tasks.sql — DB 스키마

```sql
CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

### tests/api_tests.rs — 통합 테스트

```rust
use axum::{body::Body, http::{Request, StatusCode}};
use tower::ServiceExt;
use serde_json::json;

// AI에게 "이 Axum 핸들러의 통합 테스트를 작성해줘"라고 요청하면
// 아래와 같은 패턴으로 생성해요

#[tokio::test]
async fn test_health_check() {
    let app = create_test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap()
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}

#[tokio::test]
async fn test_create_and_get_task() {
    let app = create_test_app().await;

    // 태스크 생성
    let create_response = app.clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/tasks")
                .header("content-type", "application/json")
                .body(Body::from(
                    serde_json::to_string(&json!({
                        "title": "테스트 태스크",
                        "description": "AI가 생성한 테스트"
                    })).unwrap()
                ))
                .unwrap()
        )
        .await
        .unwrap();

    assert_eq!(create_response.status(), StatusCode::CREATED);
}
```

## AI 코딩 도구로 Rust 개발할 때 유용한 패턴

### 컴파일러 에러 → AI 해결 루프

Rust에서 가장 효과적인 AI 활용법은 **컴파일러 에러를 그대로 AI에게 넘기는 것**이에요.

```bash
# 1. 빌드 시도
cargo build 2>&1 | head -30

# 2. 에러가 나면 AI에게 전달
# "이 컴파일러 에러를 수정해줘: [에러 메시지 붙여넣기]"
```

Rust 컴파일러의 에러 메시지가 상세하기 때문에 AI가 정확한 수정을 제안하는 확률이 높아요.

### Trait 구현 자동 생성

```
// AI 프롬프트: "Task 구조체에 Display trait을 구현해줘. 
// id와 title을 'Task(id): title' 형식으로 출력해줘"
```

| 상황 | 프롬프트 예시 |
|------|-------------|
| 새 핸들러 추가 | `"PATCH /tasks/{id}/status 핸들러를 추가해줘. status만 변경하는 엔드포인트"` |
| 미들웨어 작성 | `"인증 토큰을 검증하는 Tower 미들웨어를 만들어줘"` |
| 에러 타입 확장 | `"Unauthorized 에러 variant를 AppError에 추가하고 401을 반환하게 해줘"` |
| 테스트 생성 | `"tasks 핸들러 전체의 통합 테스트를 작성해줘. 인메모리 SQLite 사용"` |
| 쿼리 최적화 | `"status별로 태스크를 필터링하는 쿼리 파라미터를 추가해줘"` |

## Rust + AI 개발 팁

### 1. 소유권 문제는 AI에게 맡기기

Rust의 소유권/차용 시스템은 AI 코딩 도구가 잘 처리하는 영역이에요. `Clone`, `Arc`, 라이프타임 등의 해결책을 빠르게 제안받을 수 있어요.

### 2. Derive 매크로 조합 요청

```rust
// "이 구조체에 필요한 derive 매크로를 모두 추가해줘"
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Task { /* ... */ }
```

### 3. 점진적 타입 강화

처음에는 `String`으로 시작하고, 이후 AI에게 뉴타입 패턴을 요청하면 좋아요.

```rust
// Before: status: String
// After:
#[derive(Debug, Serialize, Deserialize)]
pub enum TaskStatus {
    Pending,
    InProgress,
    Done,
}
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
