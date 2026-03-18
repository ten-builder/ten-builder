# 서브에이전트 병렬 개발 예제

> 여러 AI 에이전트를 동시에 돌려서 대규모 프로젝트를 빠르게 처리하는 실전 패턴

## 이 예제에서 배울 수 있는 것

- Claude Code의 서브에이전트 기능으로 작업을 병렬 분배하는 방법
- 태스크를 독립적인 단위로 쪼개는 기준과 패턴
- 병렬 결과를 안전하게 통합하고 충돌을 해결하는 전략
- 에러 핸들링과 재시도 패턴

## 프로젝트 구조

```
subagent-parallel-dev/
├── CLAUDE.md                    # 메인 오케스트레이터 설정
├── prompts/
│   ├── orchestrator.md          # 오케스트레이터 프롬프트
│   ├── backend-agent.md         # 백엔드 담당 에이전트
│   ├── frontend-agent.md        # 프론트엔드 담당 에이전트
│   └── test-agent.md            # 테스트 담당 에이전트
├── scripts/
│   ├── parallel-run.sh          # 병렬 실행 스크립트
│   └── merge-results.sh         # 결과 통합 스크립트
└── examples/
    ├── task-split-api.md        # API 서버 분할 예시
    └── task-split-fullstack.md  # 풀스택 분할 예시
```

## 핵심 개념: 왜 병렬인가?

AI 코딩 에이전트 하나로 전체 프로젝트를 처리하면 컨텍스트 윈도우가 빠르게 소진돼요. 서브에이전트를 활용하면:

| 방식 | 컨텍스트 사용 | 소요 시간 | 적합한 상황 |
|------|-------------|----------|------------|
| 단일 에이전트 | 전체 프로젝트 로드 | 30분+ | 작은 프로젝트, 파일 10개 이하 |
| 병렬 서브에이전트 | 각자 담당 범위만 | 10분 내외 | 중~대규모 프로젝트, 모듈 분리 가능 |

## 시작하기

### Step 1: 태스크 분할 기준 정하기

병렬 처리에 적합한 작업과 그렇지 않은 작업을 먼저 구분해요.

**병렬 처리에 적합한 작업:**
- 독립적인 API 엔드포인트 구현
- 서로 다른 페이지/컴포넌트 개발
- 테스트 코드 작성 (구현 코드가 이미 있을 때)
- 문서 생성, 타입 정의

**순차 처리가 필요한 작업:**
- 공유 상태나 전역 설정 변경
- 데이터베이스 스키마 마이그레이션
- 빌드 설정 수정

### Step 2: 오케스트레이터 프롬프트 작성

메인 에이전트가 서브에이전트를 관리하는 구조를 만들어요.

```markdown
# orchestrator.md

## 역할
너는 프로젝트 오케스트레이터야. 작업을 분석해서 서브에이전트에게 분배해.

## 분배 규칙
1. 파일 의존성 그래프를 먼저 그려
2. 독립적인 모듈 단위로 태스크를 나눠
3. 공유 타입/인터페이스는 먼저 확정한 뒤 분배
4. 각 서브에이전트에게 정확한 파일 범위를 지정

## 분배 형식
각 서브에이전트에게 다음 정보를 전달:
- 담당 파일 목록
- 입출력 인터페이스 (타입 정의)
- 의존하는 파일 (읽기 전용)
- 완료 기준
```

### Step 3: 서브에이전트 프롬프트 작성

각 역할별로 범위가 명확한 프롬프트를 준비해요.

**백엔드 에이전트:**

```markdown
# backend-agent.md

## 담당 범위
- src/api/ 디렉토리 전체
- src/lib/db/ 디렉토리
- src/types/api.ts (읽기 전용 — 오케스트레이터가 확정한 타입)

## 규칙
- API 라우트는 REST 규칙을 따름
- 에러 응답은 { error: string, code: number } 형태
- 모든 엔드포인트에 입력 검증 포함
- 다른 에이전트 담당 파일은 수정 금지

## 완료 기준
- [ ] 모든 엔드포인트 구현
- [ ] 에러 핸들링 미들웨어 적용
- [ ] 타입 안전성 확보 (any 금지)
```

**프론트엔드 에이전트:**

```markdown
# frontend-agent.md

## 담당 범위
- src/components/ 디렉토리 전체
- src/app/ 페이지 컴포넌트
- src/hooks/ 커스텀 훅

## 규칙
- 컴포넌트는 Server Component 기본
- API 호출 타입은 src/types/api.ts 참조 (읽기 전용)
- Tailwind CSS 사용
- 접근성(a11y) 기본 준수

## 완료 기준
- [ ] 모든 페이지 컴포넌트 구현
- [ ] 로딩/에러 상태 처리
- [ ] 반응형 레이아웃 적용
```

**테스트 에이전트:**

```markdown
# test-agent.md

## 담당 범위
- __tests__/ 디렉토리 전체
- src/**/*.test.ts 파일

## 규칙
- 구현 코드를 읽기 전용으로 참조
- 유닛 테스트 + 통합 테스트 모두 작성
- 엣지 케이스 최소 2개씩 포함
- 모킹은 최소한으로

## 완료 기준
- [ ] 각 API 엔드포인트 테스트
- [ ] 주요 컴포넌트 렌더링 테스트
- [ ] 에러 시나리오 테스트
```

### Step 4: 병렬 실행

tmux를 사용해서 여러 에이전트를 동시에 실행해요.

```bash
#!/bin/bash
# parallel-run.sh — 서브에이전트 병렬 실행

PROJECT_DIR=$(pwd)
SESSION="parallel-dev"

# tmux 세션 생성
tmux new-session -d -s $SESSION -n orchestrator

# 공유 타입 먼저 확정 (순차)
echo "Step 1: 공유 인터페이스 확정..."
claude -p "src/types/api.ts를 분석해서 모든 API 타입을 확정해줘. \
  다른 에이전트들이 이 타입을 기준으로 작업할 거야." \
  --allowedTools "Read,Write" \
  2>&1 | tee /tmp/types-result.log

# 병렬 실행 (백엔드 + 프론트엔드 + 테스트)
echo "Step 2: 서브에이전트 병렬 실행..."

tmux new-window -t $SESSION -n backend
tmux send-keys -t $SESSION:backend \
  "cd $PROJECT_DIR && claude -p '$(cat prompts/backend-agent.md)'" Enter

tmux new-window -t $SESSION -n frontend
tmux send-keys -t $SESSION:frontend \
  "cd $PROJECT_DIR && claude -p '$(cat prompts/frontend-agent.md)'" Enter

tmux new-window -t $SESSION -n testing
tmux send-keys -t $SESSION:testing \
  "cd $PROJECT_DIR && claude -p '$(cat prompts/test-agent.md)'" Enter

echo "3개 에이전트 실행 중 — tmux attach -t $SESSION 으로 확인"
```

### Step 5: 결과 통합

병렬 작업 후 충돌을 확인하고 통합해요.

```bash
#!/bin/bash
# merge-results.sh — 결과 확인 및 통합

echo "=== 변경된 파일 확인 ==="
git status --short

echo ""
echo "=== 충돌 가능성 체크 ==="
# 같은 파일을 여러 에이전트가 수정했는지 확인
git diff --name-only | sort | uniq -d

echo ""
echo "=== 타입 체크 ==="
npx tsc --noEmit 2>&1 | head -20

echo ""
echo "=== 테스트 실행 ==="
npm test 2>&1 | tail -10
```

## 핵심 코드: 태스크 분할 패턴

### 패턴 1: API 서버 분할

```
전체 태스크: "사용자 관리 API 구현"

오케스트레이터가 분할:
├── 에이전트 A: POST /users, GET /users/:id, PATCH /users/:id
├── 에이전트 B: POST /auth/login, POST /auth/refresh, POST /auth/logout  
└── 에이전트 C: 위 6개 엔드포인트 전체 테스트 코드

공유 계약:
- User 타입: { id, email, name, createdAt }
- AuthToken 타입: { accessToken, refreshToken, expiresAt }
- 에러 형식: { error: string, code: number }
```

### 패턴 2: 풀스택 분할

```
전체 태스크: "대시보드 페이지 구현"

오케스트레이터가 분할:
├── 에이전트 A: API 라우트 (GET /api/stats, GET /api/charts)
├── 에이전트 B: 대시보드 UI (StatsCard, ChartPanel, Layout)
├── 에이전트 C: 데이터 훅 (useStats, useCharts) + 캐싱 로직
└── 에이전트 D: E2E 테스트 시나리오

공유 계약:
- StatsResponse 타입
- ChartData 타입
- API 경로 상수
```

### 패턴 3: 리팩토링 분할

```
전체 태스크: "JavaScript → TypeScript 마이그레이션"

오케스트레이터가 분할:
├── 에이전트 A: src/utils/*.js → *.ts (유틸 함수)
├── 에이전트 B: src/components/*.jsx → *.tsx (컴포넌트)
├── 에이전트 C: src/api/*.js → *.ts (API 레이어)
└── 에이전트 D: tsconfig.json 설정 + 빌드 검증

의존성 순서:
tsconfig(D) → utils(A) → api(C) → components(B)
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 태스크 분할 | `이 프로젝트를 3개 서브에이전트로 나눠줘. 각각의 파일 범위와 공유 인터페이스를 정의해줘` |
| 의존성 분석 | `src/ 디렉토리의 import 그래프를 분석해서 독립 모듈을 찾아줘` |
| 충돌 해결 | `두 에이전트가 수정한 파일을 비교해서 충돌 없이 합쳐줘` |
| 품질 검증 | `병렬 작업 결과물의 타입 일관성과 인터페이스 호환성을 검증해줘` |

## 자주 하는 실수와 해결법

| 실수 | 해결 |
|------|------|
| 공유 타입을 확정하지 않고 병렬 실행 | 오케스트레이터가 먼저 인터페이스를 확정한 뒤 분배 |
| 너무 잘게 쪼개서 오버헤드 증가 | 에이전트 2~4개가 적정, 5개 넘으면 통합 비용이 커짐 |
| 에이전트 간 파일 범위 겹침 | 각 에이전트에 정확한 파일 목록을 지정하고 나머지는 읽기 전용 |
| 결과 통합 시 타입 에러 | 통합 후 반드시 `tsc --noEmit`으로 전체 타입 체크 |
| 한 에이전트 실패 시 전체 중단 | 실패한 에이전트만 재시도, 나머지 결과는 보존 |

## 실전 팁

### 1. 공유 계약(Contract)을 먼저 만들어라

병렬 작업의 핵심은 에이전트 간 인터페이스를 사전에 합의하는 거예요. TypeScript 타입 파일이나 API 스키마를 먼저 확정하면 통합이 쉬워져요.

```typescript
// types/contract.ts — 오케스트레이터가 먼저 확정
export interface UserCreateRequest {
  email: string;
  name: string;
  password: string;
}

export interface UserResponse {
  id: string;
  email: string;
  name: string;
  createdAt: string;
}

// 이 타입을 기준으로 백엔드는 API를, 프론트엔드는 UI를 구현
```

### 2. 읽기 전용 경계를 명확히 하라

각 에이전트에게 "이 파일은 수정 가능", "이 파일은 읽기만" 을 명확히 지정해야 충돌을 막을 수 있어요.

### 3. 결과를 단계적으로 통합하라

전부 끝난 뒤 한 번에 합치지 말고, 먼저 끝난 에이전트의 결과부터 순차적으로 통합하면 문제를 일찍 발견할 수 있어요.

```bash
# 1단계: 타입 + 백엔드 통합 → tsc 체크
# 2단계: + 프론트엔드 통합 → tsc + 빌드 체크
# 3단계: + 테스트 통합 → 전체 테스트 실행
```

### 4. 에이전트 수는 2~4개가 적정

에이전트가 많을수록 통합 비용이 기하급수적으로 늘어나요. 대부분의 프로젝트는 백엔드/프론트엔드/테스트 3개면 충분해요.

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
