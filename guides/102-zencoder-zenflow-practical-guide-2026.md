# Zencoder + ZenFlow 실전 가이드 2026 — 코딩 바깥의 75%를 AI로 자동화하기

> 코딩 에이전트가 25%를 처리한다면, 나머지 75%는 누가 맡을까요? ZenFlow가 그 답입니다.

## 왜 ZenFlow인가

Claude Code, Cursor, Codex CLI 같은 코딩 에이전트는 코드 작성 속도를 높여줍니다. 그런데 개발자의 실제 업무를 분석해 보면, 코드를 직접 작성하는 시간은 전체의 25% 남짓입니다.

나머지 75%는 이런 것들이에요:

- 기능 기획, 스프린트 플래닝
- PR 리뷰, 리뷰 코멘트 작성
- 진행 상황 보고, 미팅 준비
- 이슈 트리아지, 버그 우선순위 결정
- 팀 내 커뮤니케이션, 문서 업데이트

Zencoder가 2026년 4월 출시한 **Zenflow Work**는 이 75%를 AI로 자동화하는 플랫폼입니다.

## ZenFlow 핵심 개념

### 스펙 주도 개발(Spec-Driven Development)

ZenFlow의 핵심 철학은 **스펙이 코드보다 먼저**입니다.

| 기존 바이브 코딩 | ZenFlow 스펙 주도 |
|----------------|-----------------|
| 프롬프트 → 코드 생성 | 스펙 작성 → AI가 계획 → 코드 구현 |
| 결과 예측 어려움 | 스펙 기반 검증 가능 |
| 단일 모델 의존 | 멀티 모델 교차 검증 |
| 세션 단절 시 컨텍스트 소실 | 스펙 파일이 컨텍스트 역할 |

### Double-LLM 패턴

ZenFlow는 두 개의 LLM을 사용합니다:

1. **작업 모델:** 실제 코드/결과물 생성
2. **검증 모델:** 작업 모델의 결과를 스펙 기준으로 검증

검증 모델이 문제를 발견하면 인간에게 에스컬레이션합니다. 두 모델 모두 통과하면 자동으로 처리됩니다.

## 설치 및 시작

### 1. ZenFlow 설치

```bash
# npm 패키지로 설치
npm install -g @zencoder/zenflow

# 또는 Homebrew
brew install zencoder/tap/zenflow
```

### 2. 인증 설정

```bash
zenflow auth login
# 브라우저에서 Zencoder 계정으로 로그인
```

### 3. 프로젝트 초기화

```bash
cd my-project
zenflow init

# 생성되는 파일:
# .zenflow/config.yml  — 프로젝트 설정
# .zenflow/spec.md     — 프로젝트 스펙 (수동 작성)
# .zenflow/tasks/      — 태스크 큐
```

## 핵심 워크플로우

### 스펙 작성 → 플래닝

스펙 파일(`.zenflow/spec.md`)을 작성하면 ZenFlow가 태스크로 분해합니다:

```markdown
# 기능 스펙: 사용자 알림 시스템

## 목적
신규 댓글, 멘션, 구독 업데이트를 실시간으로 사용자에게 전달한다.

## 수용 기준
- 알림은 10초 이내 전달
- 읽음/안읽음 상태 추적
- 이메일 + 푸시 두 채널 지원
- 사용자별 알림 타입 설정 가능

## 기술 스택
- WebSocket: Socket.io
- DB: PostgreSQL (알림 로그)
- 이메일: Resend API
```

```bash
# 스펙을 태스크로 분해
zenflow plan --spec .zenflow/spec.md

# 출력 예시:
# Task 1: WebSocket 서버 설정 (예상 30분)
# Task 2: 알림 DB 스키마 생성 (예상 20분)
# Task 3: 알림 생성 API (예상 45분)
# Task 4: 이메일 발송 서비스 (예상 30분)
# Task 5: 프론트엔드 알림 UI (예상 60분)
```

### MCP 도구 연동

ZenFlow는 100개 이상의 도구를 MCP를 통해 연결합니다:

```yaml
# .zenflow/config.yml
integrations:
  github:
    repo: my-org/my-project
    auto_create_pr: true
  jira:
    project: PROJ
    sync_tasks: true
  linear:
    team: engineering
  sentry:
    project: my-project
    alert_threshold: error
  datadog:
    service: api-server
```

```bash
# Jira 이슈를 ZenFlow 태스크로 가져오기
zenflow import --source jira --filter "status=backlog,priority=high"

# GitHub 이슈를 태스크로 가져오기
zenflow import --source github --label "good-first-issue"
```

### 병렬 에이전트 실행

여러 태스크를 동시에 실행할 때 ZenFlow가 충돌을 방지합니다:

```bash
# 병렬 실행 (최대 4개 에이전트)
zenflow run --parallel 4 --tasks task-1,task-2,task-3,task-4

# 실시간 진행 상황 확인
zenflow status --watch
```

| 에이전트 | 태스크 | 상태 | 진행 |
|---------|--------|------|------|
| agent-1 | WebSocket 서버 | 실행 중 | 70% |
| agent-2 | DB 스키마 | 완료 | 100% |
| agent-3 | 알림 API | 검증 중 | 90% |
| agent-4 | 이메일 서비스 | 대기 중 | 0% |

### PR 리뷰 자동화

```bash
# PR이 열리면 자동 리뷰 트리거
zenflow review --pr 123

# 리뷰 항목:
# ✅ 스펙 준수 여부
# ✅ 테스트 커버리지 (임계값: 80%)
# ✅ 보안 취약점 스캔
# ✅ 코드 스타일 체크
```

## Claude Code + ZenFlow 조합 전략

두 도구를 함께 쓸 때 역할을 명확히 나누면 효과가 큽니다:

| 단계 | 담당 도구 |
|------|----------|
| 기능 스펙 작성 | ZenFlow |
| 플래닝, 태스크 분해 | ZenFlow |
| 실제 코드 구현 | Claude Code |
| 코드 품질 검증 | ZenFlow (Double-LLM) |
| PR 생성, 설명 작성 | Claude Code |
| 이슈 트리아지, 보고서 | ZenFlow Work |

```bash
# 실전 워크플로우 예시
# 1. ZenFlow로 스펙 플래닝
zenflow plan --spec feature.md

# 2. Claude Code로 구현
claude "task-3의 알림 API를 구현해줘. .zenflow/spec.md의 수용 기준을 반드시 따를 것"

# 3. ZenFlow로 검증
zenflow verify --task task-3 --against spec.md
```

## Zenflow Work — 비개발 업무 자동화

Zenflow Work는 코드 외 업무도 처리합니다:

```bash
# 주간 진행 보고서 자동 생성
zenflow report --period weekly --channel slack

# 스프린트 회고 자료 준비
zenflow retrospective --sprint 42

# 릴리스 노트 자동 작성
zenflow changelog --from v1.2.0 --to v1.3.0
```

## Claude Code와의 비교

| 항목 | Claude Code | ZenFlow |
|------|------------|---------|
| 주 용도 | 코드 작성/리팩토링 | 스펙 기반 전체 SDLC |
| UI | 터미널 TUI | 웹 UI + 터미널 |
| 멀티 에이전트 | Git Worktree 기반 | 내장 병렬 실행 |
| 검증 | 수동 or Hooks | Double-LLM 자동 |
| 도구 연동 | MCP (수동 설정) | 100+ 사전 통합 |
| 비코딩 업무 | 제한적 | Zenflow Work |

두 도구는 경쟁이 아닌 보완 관계입니다. ZenFlow가 방향을 잡고, Claude Code가 구현하는 조합이 현재 가장 효과적입니다.

## 체크리스트

- [ ] `.zenflow/spec.md`에 수용 기준 명시
- [ ] GitHub/Jira/Linear 통합 설정
- [ ] Double-LLM 검증 임계값 설정
- [ ] 병렬 에이전트 수 결정 (팀 규모 × 0.5 권장)
- [ ] Zenflow Work로 주간 보고 자동화

## 다음 단계

→ [AI 에이전트 스펙 주도 개발 치트시트](../cheatsheets/spec-driven-development-cheatsheet.md)

→ [컨텍스트 엔지니어링 가이드](./63-context-engineering-2026.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
