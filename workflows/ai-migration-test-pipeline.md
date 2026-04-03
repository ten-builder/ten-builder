# AI 기반 마이그레이션 테스트 파이프라인

> 프레임워크/라이브러리 업그레이드 시 AI 에이전트로 테스트 커버리지를 확보하고 안전하게 마이그레이션하는 워크플로우

## 개요

프레임워크 버전 업그레이드나 라이브러리 교체는 개발팀에서 가장 스트레스 받는 작업 중 하나예요. "이거 바꾸면 어디가 깨질까?" 하는 불안감이 항상 따라다니죠.

이 워크플로우는 AI 코딩 에이전트를 사용해서:
- 마이그레이션 전 기존 코드의 테스트 커버리지를 자동으로 보강하고
- 변경 영향 범위를 분석해서 리스크를 사전에 파악하고
- 마이그레이션 후 회귀 테스트를 자동 실행하는

전체 파이프라인을 구성합니다.

## 사전 준비

- AI 코딩 도구 (Claude Code, Cursor, Aider 등)
- Git 기반 프로젝트 (브랜치 전략 필수)
- 기존 테스트 프레임워크 (Jest, pytest, Go test 등)
- CI/CD 파이프라인 (GitHub Actions, GitLab CI 등)

## 설정

### Step 1: 마이그레이션 영향 범위 분석

먼저 AI 에이전트에게 변경 영향 범위를 파악하게 합니다.

```bash
# Claude Code 예시: React 18 → 19 마이그레이션 영향 분석
claude "프로젝트에서 React 18 → 19 마이그레이션 시 영향받는 파일을 분석해줘:
1. deprecated API를 사용하는 파일 목록
2. breaking change에 해당하는 패턴
3. 각 파일의 리스크 레벨 (high/medium/low)
결과를 migration-impact.md에 정리해줘"
```

영향 분석 결과 예시:

| 파일 | 영향 | 리스크 |
|------|------|--------|
| `src/hooks/useAuth.ts` | `useEffect` cleanup 타이밍 변경 | high |
| `src/components/Modal.tsx` | `createPortal` 시그니처 변경 | medium |
| `src/utils/render.ts` | `ReactDOM.render` → `createRoot` | high |
| `src/pages/Home.tsx` | 영향 없음 | low |

### Step 2: 테스트 갭 분석 + 자동 보강

영향받는 파일 중 테스트가 없거나 부족한 부분을 AI가 찾아서 보강합니다.

```bash
# 테스트 커버리지 기반 갭 분석
claude "migration-impact.md에서 리스크가 high/medium인 파일을 읽고:
1. 각 파일에 대응하는 테스트 파일이 있는지 확인
2. 테스트가 없으면 현재 동작을 보존하는 스냅샷 테스트를 생성
3. 테스트가 있으면 마이그레이션 영향 부분의 커버리지가 충분한지 확인
4. 부족하면 해당 부분의 테스트를 추가
모든 테스트는 현재(마이그레이션 전) 버전에서 통과해야 해"
```

```yaml
# .github/workflows/migration-test.yml
name: Migration Test Pipeline
on:
  pull_request:
    branches: [main]
    paths:
      - 'package.json'
      - 'requirements.txt'
      - 'go.mod'

jobs:
  pre-migration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run baseline tests
        run: npm test -- --coverage --coverageReporters=json-summary
      - name: Save baseline coverage
        uses: actions/upload-artifact@v4
        with:
          name: baseline-coverage
          path: coverage/coverage-summary.json

  post-migration-tests:
    needs: pre-migration-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run migration tests
        run: npm test -- --coverage --coverageReporters=json-summary
      - name: Compare coverage
        run: |
          # 마이그레이션 전후 커버리지 비교
          node scripts/compare-coverage.js
```

### Step 3: 자동 회귀 테스트 생성

```bash
# AI에게 회귀 테스트 자동 생성 요청
claude "다음 조건으로 회귀 테스트를 생성해줘:
1. migration-impact.md의 high 리스크 파일 각각에 대해
2. 현재 동작의 입출력을 캡처하는 테스트
3. 엣지 케이스 포함 (null, undefined, 빈 배열 등)
4. 테스트 파일은 __tests__/migration/ 디렉토리에 생성
5. 파일명 규칙: {원본파일명}.migration.test.ts"
```

테스트 구조 예시:

```
__tests__/migration/
├── useAuth.migration.test.ts      # 인증 훅 회귀 테스트
├── Modal.migration.test.tsx       # 모달 렌더링 회귀 테스트
└── render.migration.test.ts       # ReactDOM 래퍼 회귀 테스트
```

## 사용 방법

### 전체 파이프라인 실행 순서

```
1. 마이그레이션 브랜치 생성
   └── git checkout -b migrate/react-19

2. Phase A: 프리 마이그레이션
   ├── AI 영향 분석 실행
   ├── 테스트 갭 분석
   └── 회귀 테스트 생성 + 커밋

3. Phase B: 마이그레이션 실행
   ├── 의존성 업데이트 (package.json 등)
   ├── AI가 코드 수정 (deprecated → new API)
   └── 커밋

4. Phase C: 포스트 마이그레이션 검증
   ├── 전체 테스트 실행
   ├── 커버리지 비교 (baseline vs current)
   ├── AI 코드 리뷰 요청
   └── PR 생성
```

### AI 에이전트에게 마이그레이션 실행 요청

```bash
# 의존성 업데이트 후 자동 수정
claude "package.json에서 react를 19.x로 업데이트했어.
TypeScript 컴파일 에러와 테스트 실패를 확인하고 하나씩 수정해줘.
수정할 때마다 테스트를 실행해서 통과하는지 확인해.
migration-impact.md를 참고해서 리스크가 높은 부분은 특히 주의해줘"
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 커버리지 하한선 | 80% | 마이그레이션 후 이 수치 이하로 떨어지면 실패 |
| 리스크 분류 기준 | breaking change 여부 | high: breaking, medium: deprecated, low: 없음 |
| 테스트 타입 | unit + integration | 필요 시 E2E 추가 |
| AI 도구 | Claude Code | Cursor, Aider 등으로 대체 가능 |
| 회귀 테스트 디렉토리 | `__tests__/migration/` | 프로젝트 구조에 맞게 변경 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| AI가 생성한 테스트가 통과하지 않음 | 테스트 생성 후 반드시 실행 확인 요청 추가 ("테스트 실행해서 통과하는지 확인해줘") |
| 커버리지가 오히려 떨어짐 | 마이그레이션으로 삭제된 코드의 테스트가 남아있는지 확인. dead test 정리 |
| 영향 범위 분석이 부정확함 | `git diff --stat` 결과를 AI에게 함께 제공. AST 기반 분석 도구(ts-morph 등) 병행 |
| CI에서만 실패하고 로컬은 통과 | 환경 차이 확인 (Node 버전, OS). CI 로그를 AI에게 전달해서 분석 요청 |
| 대규모 프로젝트에서 시간이 너무 오래 걸림 | 영향 파일만 선별해서 테스트 (`--testPathPattern` 옵션). 병렬 실행 설정 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
