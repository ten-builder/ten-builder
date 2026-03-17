# Go 마이크로서비스 + AI 코딩 실전 예제

> AI 코딩 도구로 Go 마이크로서비스를 처음부터 만드는 단계별 가이드

## 이 예제에서 배울 수 있는 것

- Go 마이크로서비스의 Clean Architecture 구조를 AI 도구로 빠르게 잡는 방법
- CLAUDE.md로 Go 프로젝트 컨텍스트를 정확하게 전달하는 패턴
- 미들웨어, 에러 핸들링, 테스트를 AI와 함께 단계적으로 구현하는 워크플로우
- Docker 배포까지 한 번에 완성하는 실전 흐름

## 프로젝트 구조

```
go-microservice-ai/
├── CLAUDE.md                # AI 코딩 도구 프로젝트 설정
├── cmd/
│   └── server/
│       └── main.go          # 엔트리포인트
├── internal/
│   ├── handler/
│   │   └── task.go          # HTTP 핸들러
│   ├── service/
│   │   └── task.go          # 비즈니스 로직
│   ├── repository/
│   │   └── task.go          # 데이터 접근 계층
│   ├── model/
│   │   └── task.go          # 도메인 모델
│   └── middleware/
│       ├── logging.go       # 구조화된 로깅
│       └── recovery.go      # 패닉 복구
├── pkg/
│   └── response/
│       └── json.go          # 표준 응답 포맷
├── tests/
│   ├── handler_test.go      # 핸들러 테스트
│   └── service_test.go      # 서비스 테스트
├── Dockerfile
├── docker-compose.yml
├── go.mod
└── Makefile
```

## 시작하기

### Step 1: 프로젝트 초기화

```bash
mkdir go-microservice && cd go-microservice
go mod init github.com/yourname/go-microservice
```

### Step 2: CLAUDE.md 작성

프로젝트 루트에 `CLAUDE.md`를 만들어서 AI 코딩 도구에 컨텍스트를 전달해요.

```markdown
# CLAUDE.md

## Project
- Go 1.23+ 마이크로서비스
- Clean Architecture (handler → service → repository)
- 표준 라이브러리 net/http 기반 (프레임워크 최소화)
- PostgreSQL + sqlx

## Rules
- internal/ 패키지로 캡슐화
- 에러는 fmt.Errorf("context: %w", err) 패턴으로 래핑
- 모든 핸들러에 구조화된 로깅 적용
- 테이블 드리븐 테스트 사용
- context.Context를 첫 번째 인자로 전달

## Commands
- run: go run cmd/server/main.go
- test: go test ./...
- lint: golangci-lint run
- build: docker build -t microservice .
```

이 파일 하나로 AI가 Go 프로젝트의 구조, 규칙, 실행 방법을 정확히 파악해요.

### Step 3: 도메인 모델 정의

AI에게 다음과 같이 요청해요:

```
Task 도메인 모델을 만들어줘. ID, Title, Status, CreatedAt 필드.
internal/model/task.go에 생성해줘.
```

생성 결과:

```go
package model

import "time"

type TaskStatus string

const (
    TaskStatusPending    TaskStatus = "pending"
    TaskStatusInProgress TaskStatus = "in_progress"
    TaskStatusDone       TaskStatus = "done"
)

type Task struct {
    ID        string     `json:"id" db:"id"`
    Title     string     `json:"title" db:"title"`
    Status    TaskStatus `json:"status" db:"status"`
    CreatedAt time.Time  `json:"created_at" db:"created_at"`
    UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
}

type CreateTaskInput struct {
    Title string `json:"title" validate:"required,min=1,max=200"`
}

type UpdateTaskInput struct {
    Title  *string     `json:"title,omitempty"`
    Status *TaskStatus `json:"status,omitempty"`
}
```

**핵심 포인트:** Go에서는 입력 DTO를 별도 struct로 분리하면 AI가 validation 로직을 자동으로 추가해요.

### Step 4: Repository 계층

```
Task의 CRUD repository를 만들어줘.
internal/repository/task.go에 인터페이스와 PostgreSQL 구현체 둘 다 만들어줘.
```

```go
package repository

import (
    "context"
    "github.com/yourname/go-microservice/internal/model"
)

type TaskRepository interface {
    Create(ctx context.Context, input model.CreateTaskInput) (*model.Task, error)
    GetByID(ctx context.Context, id string) (*model.Task, error)
    List(ctx context.Context, limit, offset int) ([]model.Task, error)
    Update(ctx context.Context, id string, input model.UpdateTaskInput) (*model.Task, error)
    Delete(ctx context.Context, id string) error
}
```

**왜 인터페이스를 먼저 정의하나요?**

Go의 인터페이스를 먼저 작성하면 AI가 구현체를 만들 때 계약을 정확히 따라요. 테스트용 mock도 바로 생성할 수 있어요.

### Step 5: 서비스 계층 + 비즈니스 로직

```
Task 서비스를 만들어줘. Repository를 주입받고 비즈니스 규칙을 적용해.
상태 전환 규칙: pending → in_progress → done (역방향 불가)
```

```go
package service

import (
    "context"
    "errors"
    "github.com/yourname/go-microservice/internal/model"
    "github.com/yourname/go-microservice/internal/repository"
)

var (
    ErrInvalidTransition = errors.New("invalid status transition")
    ErrTaskNotFound      = errors.New("task not found")
)

type TaskService struct {
    repo repository.TaskRepository
}

func NewTaskService(repo repository.TaskRepository) *TaskService {
    return &TaskService{repo: repo}
}

func (s *TaskService) Create(ctx context.Context, input model.CreateTaskInput) (*model.Task, error) {
    return s.repo.Create(ctx, input)
}

func (s *TaskService) UpdateStatus(ctx context.Context, id string, newStatus model.TaskStatus) (*model.Task, error) {
    task, err := s.repo.GetByID(ctx, id)
    if err != nil {
        return nil, ErrTaskNotFound
    }

    if !isValidTransition(task.Status, newStatus) {
        return nil, ErrInvalidTransition
    }

    return s.repo.Update(ctx, id, model.UpdateTaskInput{Status: &newStatus})
}

func isValidTransition(from, to model.TaskStatus) bool {
    transitions := map[model.TaskStatus]model.TaskStatus{
        model.TaskStatusPending:    model.TaskStatusInProgress,
        model.TaskStatusInProgress: model.TaskStatusDone,
    }
    allowed, ok := transitions[from]
    return ok && allowed == to
}
```

### Step 6: HTTP 핸들러 + 미들웨어

```
Task CRUD 핸들러를 만들어줘. 표준 net/http 사용하고 JSON 응답 표준 포맷으로.
로깅 미들웨어도 같이 만들어줘.
```

```go
package middleware

import (
    "log/slog"
    "net/http"
    "time"
)

func Logging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()

        wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
        next.ServeHTTP(wrapped, r)

        slog.Info("request completed",
            "method", r.Method,
            "path", r.URL.Path,
            "status", wrapped.statusCode,
            "duration_ms", time.Since(start).Milliseconds(),
        )
    })
}

type responseWriter struct {
    http.ResponseWriter
    statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.statusCode = code
    rw.ResponseWriter.WriteHeader(code)
}
```

**Go 1.21+ slog 사용 포인트:** `log/slog`는 구조화된 로깅의 표준이에요. AI에게 "slog 사용해줘"라고 하면 바로 적용해요.

### Step 7: 테이블 드리븐 테스트

```
서비스 계층 테스트를 만들어줘. 테이블 드리븐 패턴으로.
상태 전환 규칙 검증에 집중해줘.
```

```go
func TestTaskService_UpdateStatus(t *testing.T) {
    tests := []struct {
        name       string
        current    model.TaskStatus
        next       model.TaskStatus
        wantErr    error
    }{
        {
            name:    "pending to in_progress",
            current: model.TaskStatusPending,
            next:    model.TaskStatusInProgress,
            wantErr: nil,
        },
        {
            name:    "in_progress to done",
            current: model.TaskStatusInProgress,
            next:    model.TaskStatusDone,
            wantErr: nil,
        },
        {
            name:    "done to pending is invalid",
            current: model.TaskStatusDone,
            next:    model.TaskStatusPending,
            wantErr: service.ErrInvalidTransition,
        },
        {
            name:    "pending to done skips step",
            current: model.TaskStatusPending,
            next:    model.TaskStatusDone,
            wantErr: service.ErrInvalidTransition,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            repo := &mockRepo{task: &model.Task{Status: tt.current}}
            svc := service.NewTaskService(repo)

            _, err := svc.UpdateStatus(context.Background(), "task-1", tt.next)

            if !errors.Is(err, tt.wantErr) {
                t.Errorf("got %v, want %v", err, tt.wantErr)
            }
        })
    }
}
```

### Step 8: Docker 배포

```
멀티스테이지 Dockerfile을 만들어줘. 최종 이미지는 scratch 기반으로.
```

```dockerfile
FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server cmd/server/main.go

FROM scratch
COPY --from=builder /app/server /server
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
EXPOSE 8080
ENTRYPOINT ["/server"]
```

```yaml
# docker-compose.yml
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/tasks?sslmode=disable
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: tasks
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user"]
      interval: 5s
      timeout: 3s
      retries: 5
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 구조 잡기 | `Clean Architecture로 Go 마이크로서비스 구조를 잡아줘` |
| 에러 핸들링 | `이 핸들러에 적절한 에러 핸들링과 HTTP 상태 코드를 추가해줘` |
| 미들웨어 | `rate limiting 미들웨어를 표준 라이브러리로 만들어줘` |
| 테스트 | `이 서비스의 테이블 드리븐 테스트를 작성해줘. 엣지 케이스 포함` |
| 최적화 | `이 쿼리의 N+1 문제를 해결해줘` |
| Docker | `멀티스테이지 빌드로 최적화해줘. 최종 이미지 10MB 이하` |

## Makefile

```makefile
.PHONY: run test lint build docker

run:
	go run cmd/server/main.go

test:
	go test -v -race -cover ./...

lint:
	golangci-lint run ./...

build:
	CGO_ENABLED=0 go build -ldflags="-s -w" -o bin/server cmd/server/main.go

docker:
	docker compose up --build
```

## 핵심 설계 원칙

| 원칙 | 적용 방법 |
|------|----------|
| 의존성 역전 | Repository 인터페이스로 DB 구현 분리 |
| 단일 책임 | handler(HTTP) → service(규칙) → repo(저장) |
| 표준 라이브러리 우선 | net/http, log/slog, errors 패키지 활용 |
| 테스트 용이성 | 인터페이스 기반 mock 주입 |
| 최소 의존성 | 외부 라이브러리는 sqlx, validator 정도만 사용 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
