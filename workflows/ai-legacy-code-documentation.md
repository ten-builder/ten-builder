# AI 에이전트 기반 레거시 코드 문서화 파이프라인

> 문서 없는 레거시 코드베이스를 AI 에이전트로 체계적으로 분석하고, 실용적인 문서를 자동 생성하는 워크플로우

## 개요

5년 된 프로젝트에 투입됐는데 README는 3줄, 주석은 "TODO: fix later"뿐인 상황. 익숙한 시나리오죠. 이 워크플로우는 AI 코딩 에이전트를 사용해서 레거시 코드를 체계적으로 분석하고, 온보딩부터 아키텍처 문서까지 자동 생성하는 파이프라인을 다룹니다.

수동으로 코드를 읽으며 문서를 작성하면 며칠이 걸리는 작업을, AI 에이전트와 함께 몇 시간 안에 처리할 수 있어요.

## 사전 준비

- AI 코딩 에이전트 (Claude Code, Cursor, Windsurf 등)
- 대상 레거시 프로젝트 로컬 클론
- 기본적인 프로젝트 빌드 환경 (의존성 설치 완료 상태)

## 설정

### Step 1: 프로젝트 구조 스캔

먼저 AI 에이전트가 프로젝트 전체 구조를 파악할 수 있도록 디렉토리 맵을 생성합니다.

```bash
# 프로젝트 구조 트리 생성 (node_modules 등 제외)
find . -type f \
  -not -path './node_modules/*' \
  -not -path './.git/*' \
  -not -path './dist/*' \
  -not -path './build/*' \
  -not -path './__pycache__/*' \
  | head -200 > .project-structure.txt

# 파일별 라인 수 통계
wc -l $(cat .project-structure.txt) | sort -rn | head -30
```

### Step 2: 에이전트 지시 파일 구성

AI 에이전트가 문서화 작업에 집중할 수 있도록 지시 파일을 작성합니다.

```markdown
# CLAUDE.md (또는 .cursorrules)

## 프로젝트 컨텍스트
이 프로젝트는 레거시 코드베이스입니다.
현재 문서가 부족하며, 코드 분석을 통해 문서를 생성하는 것이 목표입니다.

## 문서화 규칙
- 코드에서 발견한 패턴을 있는 그대로 기술 (추측 최소화)
- 불확실한 부분은 `[확인 필요]` 태그 표시
- 함수/클래스의 실제 사용처를 함께 표기
- 비즈니스 로직과 인프라 코드 구분
```

### Step 3: 분석 순서 설정

```yaml
# .doc-pipeline.yaml
stages:
  - name: entry-points
    description: "진입점 식별 (main, index, app 등)"
    priority: 1

  - name: data-models
    description: "데이터 모델/스키마 분석"
    priority: 2

  - name: api-surface
    description: "외부 API/라우트 매핑"
    priority: 3

  - name: business-logic
    description: "핵심 비즈니스 로직 문서화"
    priority: 4

  - name: dependencies
    description: "외부 의존성 & 통합 포인트"
    priority: 5
```

## 사용 방법

### Phase 1: 진입점 분석

AI 에이전트에게 프로젝트의 시작점을 찾도록 요청합니다.

```
프롬프트 예시:
"이 프로젝트의 진입점(entry point)을 모두 찾아줘.
main 함수, HTTP 서버 시작점, CLI 명령어 등록 위치,
스케줄러/워커 시작점을 각각 식별하고,
각 진입점에서 호출하는 주요 모듈을 트리 형태로 정리해줘."
```

출력 예시:

```
진입점 분석 결과
├── src/index.ts          → Express 서버 시작
│   ├── routes/auth.ts    → 인증 라우트
│   ├── routes/api.ts     → API 라우트
│   └── middleware/       → 미들웨어 체인
├── src/worker.ts         → Bull 큐 워커
│   └── jobs/            → 작업 핸들러 5개
└── scripts/migrate.ts    → DB 마이그레이션 스크립트
```

### Phase 2: 데이터 모델 역공학

```
프롬프트 예시:
"프로젝트의 모든 데이터 모델(DB 스키마, 타입 정의, 인터페이스)을
찾아서 ER 다이어그램 형태로 정리해줘.
각 모델 간 관계(1:N, N:M)와 실제 사용되는 쿼리 패턴도 함께 분석해줘."
```

### Phase 3: API 표면 매핑

```
프롬프트 예시:
"모든 HTTP 엔드포인트를 찾아서 다음 형식으로 정리해줘:
- 메서드 + 경로
- 필수/선택 파라미터
- 응답 형태 (실제 코드 기반)
- 인증 필요 여부
- 실제 호출하는 서비스 함수"
```

### Phase 4: 비즈니스 로직 추출

```
프롬프트 예시:
"src/services/ 디렉토리의 각 서비스 파일을 분석해서,
핵심 비즈니스 규칙을 자연어로 설명해줘.
조건 분기, 예외 처리, 외부 API 호출 지점을 빠짐없이 포함해줘.
불확실한 부분은 [확인 필요]로 표시."
```

### Phase 5: 문서 조합 및 출력

각 단계의 분석 결과를 하나의 문서 세트로 조합합니다.

```bash
# 문서 디렉토리 구조
docs/
├── ARCHITECTURE.md     # 전체 아키텍처 개요
├── API.md              # API 레퍼런스
├── DATA-MODELS.md      # 데이터 모델 & 관계도
├── ONBOARDING.md       # 신규 개발자 온보딩 가이드
└── DECISIONS.md        # 코드에서 발견한 설계 결정 기록
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 분석 깊이 | 서비스 레이어까지 | 유틸 함수까지 내려가려면 depth 추가 |
| 문서 언어 | 한국어 | 영어 프로젝트는 영어 문서 권장 |
| 다이어그램 형식 | Mermaid | PlantUML, ASCII 아트 대체 가능 |
| 불확실성 표기 | `[확인 필요]` | `TODO`, `QUESTION` 등으로 변경 가능 |

## 실전 팁

### 컨텍스트 윈도우 관리

대규모 코드베이스는 한 번에 전체를 넣을 수 없어요. 디렉토리 단위로 분석 범위를 잘라서 순차적으로 진행하세요.

```bash
# 디렉토리별 코드 규모 확인
find src -name '*.ts' -exec wc -l {} + | sort -rn | head -10
```

규모가 큰 디렉토리(3000줄 이상)는 파일 단위로 한 번 더 분할합니다.

### 검증 루프

AI가 생성한 문서는 반드시 코드와 대조 검증하세요. 특히 주의할 점:

| 흔한 오류 | 검증 방법 |
|-----------|----------|
| 없는 함수를 문서에 포함 | `grep -r "함수명" src/` 실행 |
| 파라미터 타입 불일치 | 실제 타입 정의 파일 확인 |
| 사용하지 않는 엔드포인트 포함 | 라우트 등록 코드 확인 |
| 관계 방향 오류 (1:N ↔ N:1) | FK 컬럼과 실제 쿼리 비교 |

### 점진적 업데이트

한 번 만들고 끝이 아니라, CI에 문서 검증 단계를 추가해서 코드와 문서의 동기화를 유지합니다.

```yaml
# .github/workflows/doc-check.yml
name: Doc Freshness Check
on:
  pull_request:
    paths: ['src/**']
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check doc coverage
        run: |
          # 새로 추가된 라우트가 API.md에 반영됐는지 확인
          NEW_ROUTES=$(git diff origin/main --name-only | grep 'routes/')
          if [ -n "$NEW_ROUTES" ]; then
            echo "새 라우트 파일 감지 — API.md 업데이트 필요 여부 확인"
          fi
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| 코드베이스가 너무 커서 분석이 안 됨 | 모듈/패키지 단위로 분할하여 순차 분석 |
| AI가 잘못된 관계를 추론함 | 실제 쿼리 코드와 FK 정의를 함께 제공 |
| 동적 라우트를 놓침 | 미들웨어 등록 코드, 플러그인 로더 포함하여 분석 |
| 환경변수 의존성 누락 | `.env.example` 또는 config 파일 함께 분석 |
| 테스트 코드가 비즈니스 로직과 섞임 | `**/*.test.*` 패턴 제외 후 분석 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
