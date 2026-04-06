# 플레이북 41: AI 에이전트 멀티 파일 동시 편집

> 여러 파일을 일관성 있게 수정하는 전략 — 의존성 순서 제어, 트랜잭션 커밋, 롤백 패턴

## 소요 시간

15-25분

## 사전 준비

- Claude Code 또는 Cursor 에이전트 모드 설정 완료
- 프로젝트 CLAUDE.md 또는 .cursorrules 파일에 코드 규칙 명시
- Git 브랜치 생성 후 작업 시작 (main 직접 수정 금지)

## 왜 멀티 파일 편집이 어려운가

AI 에이전트에게 "결제 API 추가해줘"라고 요청하면 라우터, 컨트롤러, 모델, 테스트, 타입 정의까지 5~10개 파일을 동시에 건드린다. 문제는 에이전트가 각 파일을 순차적으로 수정하면서 **중간 상태에서 빌드가 깨지거나**, 타입이 꼬이거나, import 경로가 어긋나는 상황이 자주 발생한다는 점이다.

해결 핵심: **수정 순서를 의존성 기준으로 제어하고, 전체 변경을 하나의 논리적 단위로 커밋하는 것**.

## Step 1: 변경 범위 스캔

프롬프트를 보내기 전에 에이전트가 수정할 파일 범위를 먼저 파악한다.

```bash
# 에이전트에게 변경 계획부터 요청
"결제 API를 추가하려고 해. 코드를 수정하지 말고,
어떤 파일을 어떤 순서로 변경해야 하는지 계획만 먼저 보여줘."
```

에이전트가 제시하는 변경 계획 예시:

```markdown
## 변경 계획: 결제 API

1. types/payment.ts — 타입 정의 (의존성: 없음)
2. models/payment.ts — DB 모델 (의존성: types)
3. services/payment.ts — 비즈니스 로직 (의존성: models, types)
4. routes/payment.ts — API 라우트 (의존성: services)
5. routes/index.ts — 라우터 등록 (의존성: routes/payment)
6. tests/payment.test.ts — 테스트 (의존성: 전체)
```

| 확인 항목 | 기준 |
|-----------|------|
| 파일 수 | 10개 이하가 이상적. 초과 시 태스크 분할 |
| 의존성 방향 | 반드시 하위 → 상위 순서로 수정 |
| 기존 파일 수정 | 신규 파일과 기존 파일 수정을 구분 |
| 타입 일관성 | 공유 타입은 가장 먼저 정의 |

## Step 2: 의존성 기반 편집 순서 지정

에이전트가 파일을 수정하는 순서를 명시적으로 지정한다. 원칙: **리프 노드(의존성 없는 파일)부터 시작해서 루트(모든 것을 조합하는 파일)로 올라간다.**

```bash
# 프롬프트에 순서를 명시
"다음 순서대로 파일을 수정해줘:
1단계: types/payment.ts (타입 정의)
2단계: models/payment.ts (DB 모델)
3단계: services/payment.ts (비즈니스 로직)
4단계: routes/payment.ts (API 엔드포인트)
5단계: routes/index.ts (라우터 등록)
6단계: tests/payment.test.ts (테스트)

각 단계 완료 후 해당 파일만 저장하고 다음으로 넘어가."
```

### 의존성 레이어 패턴

```
Layer 0: 타입/인터페이스  ← 의존성 없음, 먼저 작성
Layer 1: 모델/스키마      ← Layer 0에만 의존
Layer 2: 서비스/유틸      ← Layer 0-1에 의존
Layer 3: 라우트/컨트롤러  ← Layer 0-2에 의존
Layer 4: 테스트/설정      ← 모든 레이어에 의존, 마지막에 작성
```

## Step 3: 체크포인트 커밋 전략

멀티 파일 편집에서 가장 중요한 안전장치는 **체크포인트 커밋**이다.

```bash
# 작업 전 체크포인트 생성
git stash push -m "before-payment-api"

# 또는 WIP 커밋 활용
git add -A && git commit -m "wip: checkpoint before payment API"
```

### 단계별 커밋 vs 원자적 커밋

| 전략 | 사용 시점 | 장점 |
|------|----------|------|
| 단계별 커밋 | 파일 10개 이상의 대규모 변경 | 문제 발생 시 특정 단계로 롤백 가능 |
| 원자적 커밋 | 파일 5개 이하의 밀접한 변경 | 깔끔한 커밋 히스토리 유지 |
| 스쿼시 커밋 | 단계별로 작업 후 PR 머지 시 | 작업 중엔 단계별, 머지 시엔 하나로 |

```bash
# 단계별 커밋 패턴
git add types/payment.ts models/payment.ts
git commit -m "feat(payment): add type definitions and model"

git add services/payment.ts routes/payment.ts routes/index.ts
git commit -m "feat(payment): add service and route layer"

git add tests/payment.test.ts
git commit -m "test(payment): add unit tests"

# PR 머지 시 스쿼시
gh pr merge --squash
```

## Step 4: 빌드 검증 루프

멀티 파일 편집의 핵심 가드레일. **에이전트가 모든 파일 수정을 끝낸 직후** 빌드와 타입 체크를 실행한다.

```bash
# 타입 체크 (TypeScript 프로젝트)
npx tsc --noEmit

# 린트
npx eslint src/ --ext .ts

# 테스트
npm test -- --bail

# 빌드
npm run build
```

### 에이전트에게 검증 루프 지시하기

```bash
"모든 파일 수정이 끝나면 다음 명령어를 순서대로 실행해줘:
1. npx tsc --noEmit (타입 체크)
2. npm test -- --bail (테스트)
에러가 나면 수정하고 다시 실행해. 3번까지 시도하고 안 되면 멈춰."
```

| 검증 단계 | 목적 | 실패 시 대응 |
|-----------|------|-------------|
| 타입 체크 | import/export 정합성 확인 | 타입 정의 파일부터 재점검 |
| 린트 | 코드 규칙 위반 잡기 | 자동 수정 (`--fix`) 먼저 시도 |
| 유닛 테스트 | 로직 정확성 확인 | 실패 테스트 기준으로 코드 수정 |
| 빌드 | 배포 가능 상태 확인 | 전체 에러 로그 에이전트에 전달 |

## Step 5: 롤백 패턴

멀티 파일 편집이 실패했을 때 깔끔하게 되돌리는 방법.

### 전체 롤백 (가장 안전)

```bash
# stash로 저장해둔 경우
git stash pop

# WIP 커밋으로 저장한 경우
git reset --soft HEAD~1

# 모든 변경 폐기
git checkout -- .
git clean -fd
```

### 부분 롤백 (특정 파일만)

```bash
# 특정 파일만 원래 상태로
git checkout HEAD -- routes/payment.ts

# 특정 커밋 시점으로
git checkout abc1234 -- services/payment.ts
```

### 롤백 판단 기준

```
빌드 에러 3회 연속 실패 → 전체 롤백 후 태스크 재분할
타입 에러 10개 이상 → 타입 정의 레이어부터 다시 시작
테스트 실패 50% 이상 → 서비스 레이어 롤백 후 재작업
```

## Step 6: 실전 프롬프트 템플릿

멀티 파일 편집을 안전하게 실행하기 위한 프롬프트 구조.

```markdown
## 태스크: {기능명}

### 변경 계획
수정할 파일 목록과 순서를 먼저 제시해줘. 코드 수정은 하지 마.

### 실행 규칙
1. 타입/인터페이스 파일부터 시작
2. 각 레이어 완료 후 `npx tsc --noEmit` 실행
3. import 경로는 기존 프로젝트 패턴을 따름
4. 새 파일 생성 시 기존 파일의 네이밍 규칙 유지
5. 전체 수정 완료 후 `npm test -- --bail` 실행

### 실패 시
- 타입 에러: 해당 타입 정의 파일 수정 후 재시도
- 테스트 실패: 실패 원인 분석 후 서비스 로직 수정
- 3회 실패: 작업 중단하고 현재 상태 보고
```

## 체크리스트

- [ ] 변경 범위를 파악하고 파일 목록을 확인했는가
- [ ] 의존성 순서(리프 → 루트)를 지정했는가
- [ ] 작업 전 체크포인트(stash 또는 WIP 커밋)를 만들었는가
- [ ] 빌드/타입 검증 명령어를 프롬프트에 포함했는가
- [ ] 롤백 기준을 정했는가 (에러 N회 시 전체 롤백)
- [ ] 최종 커밋 전 전체 테스트를 통과했는가

## 다음 단계

→ [플레이북 37: 컨텍스트 윈도우 관리](37-context-window-management.md)
→ [플레이북 40: 인텐트 기반 태스크 분해](40-intent-based-task-decomposition.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
