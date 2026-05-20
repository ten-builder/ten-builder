# 에이전틱 테스팅 완전 가이드 2026 — AI가 테스트를 직접 설계하고 실행하는 새 패러다임

> 프롬프트를 던지면 테스트가 만들어지던 시대는 끝났다. 2026년의 에이전틱 테스팅은 AI 에이전트가 코드를 분석하고, 커버리지 공백을 찾아내고, 셀프힐링 테스트를 자율 실행한다.

## 에이전틱 테스팅이란

기존 AI 테스트 도구가 "테스트 코드를 생성"했다면, 에이전틱 테스팅은 한 단계 더 나아간다.

| 구분 | 기존 AI 테스트 | 에이전틱 테스팅 |
|------|----------------|----------------|
| 접근 방식 | 사람이 시나리오 제공 → AI가 코드 작성 | AI가 코드 분석 → 시나리오 자율 설계 |
| 실패 대응 | 사람이 수동 수정 | 셀프힐링: 로케이터 변경 자동 감지·수정 |
| 커버리지 | 사람이 지정한 영역만 | 공백 자동 탐지 후 보완 |
| CI 통합 | 스크립트 실행 | 에이전트가 실패 분석·PR 자동 수정 |

핵심 차이: **테스트를 "작성"하는 것에서 "운영"하는 것으로 바뀌었다**.

## 에이전틱 테스팅의 3가지 레이어

### Layer 1: 자율 테스트 생성 (Autonomous Generation)

AI 에이전트가 코드베이스를 분석하고 테스트 대상을 스스로 결정한다.

```bash
# Claude Code로 커버리지 공백 분석 후 테스트 자동 생성
claude "현재 테스트 커버리지를 분석하고,
커버되지 않은 경계값(edge cases)을 찾아서
Vitest + Testing Library 기반 테스트를 작성해줘.
실패 케이스와 비동기 에러 처리에 집중해줘."
```

Claude Code는 `src/` 디렉토리를 탐색하고, 기존 `*.test.ts` 파일과 비교해 누락된 케이스를 파악한다.

실전 예시 — 커버리지 리포트 기반 자동 보완:

```bash
# 1단계: 커버리지 리포트 생성
pnpm test --coverage --reporter=json > coverage-report.json

# 2단계: 에이전트에게 분석 위임
claude "coverage-report.json을 분석해서
함수 커버리지가 80% 미만인 모듈을 찾고,
각 모듈의 테스트를 작성해줘."
```

### Layer 2: 셀프힐링 테스트 (Self-Healing)

UI 변경 시 로케이터가 깨지는 문제는 개발팀의 고질적인 고통이다. 에이전틱 테스팅은 이를 자동 감지·복구한다.

```typescript
// playwright.config.ts — AI 힐링 훅 설정
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    // ARIA 기반 로케이터 우선 사용 (셀프힐링 기반)
    // getByRole > getByLabel > getByText 순서 권장
  },
  reporter: [
    ['json', { outputFile: 'playwright-results.json' }]
  ],
});
```

```bash
# CI 실패 시 Claude Code로 자동 수정
claude "/autofix-pr
playwright-results.json을 분석해서
실패한 테스트의 로케이터를 현재 DOM 구조에 맞게 수정해줘.
CSS 셀렉터 대신 getByRole, getByLabel을 우선 사용할 것."
```

**핵심 원칙**: 셀프힐링이 잘 되려면 기반이 탄탄해야 한다. CSS 셀렉터 기반 테스트는 AI도 고치기 어렵다. ARIA 로케이터로 작성된 테스트가 셀프힐링 성공률이 3배 이상 높다.

### Layer 3: 에이전틱 테스트 운영 (Agentic Operations)

테스트가 CI에서 실패했을 때 사람이 PR에서 에러를 분석하던 방식에서, 에이전트가 자율적으로 원인 분석 → 수정 → PR 업데이트를 처리한다.

```yaml
# .github/workflows/ai-test-fix.yml
name: AI Test Auto-Fix

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        id: test
        run: pnpm test 2>&1 | tee test-output.txt
        continue-on-error: true

      - name: AI Fix on Failure
        if: steps.test.outcome == 'failure'
        run: |
          # Claude Code가 실패 로그 분석 후 수정
          claude --non-interactive \
            "test-output.txt의 실패 원인을 분석하고
            코드를 수정해줘. 단, 테스트 로직이 아닌
            구현 코드를 우선 수정할 것."
```

## 테스트 유형별 에이전틱 전략

### 단위 테스트 (Vitest)

```bash
# AI 에이전트로 테스트 파일 생성
claude "src/lib/payment.ts를 분석하고
다음 기준으로 Vitest 테스트를 작성해줘:
1. 정상 결제 플로우
2. 결제 실패 시나리오 (네트워크 에러, 잔액 부족)
3. 금액 경계값 (0원, 최대금액, 음수)
4. 외부 결제 API는 vi.mock()으로 처리"
```

결과물 예시:

```typescript
// src/lib/__tests__/payment.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { processPayment } from '../payment';
import * as paymentApi from '../payment-api';

vi.mock('../payment-api');

describe('processPayment', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('정상 결제 처리', async () => {
    vi.mocked(paymentApi.charge).mockResolvedValue({ success: true, txId: 'tx_123' });
    const result = await processPayment({ amount: 10000, userId: 'user_1' });
    expect(result.success).toBe(true);
  });

  it('잔액 부족 시 적절한 에러 반환', async () => {
    vi.mocked(paymentApi.charge).mockRejectedValue(new Error('INSUFFICIENT_FUNDS'));
    await expect(processPayment({ amount: 999999, userId: 'user_1' }))
      .rejects.toThrow('INSUFFICIENT_FUNDS');
  });

  it.each([
    [0, '금액이 0이면 거부'],
    [-1000, '음수 금액 거부'],
  ])('경계값: %i원 → %s', async (amount, _desc) => {
    await expect(processPayment({ amount, userId: 'user_1' }))
      .rejects.toThrow();
  });
});
```

### E2E 테스트 (Playwright + AI)

```bash
# 사용자 스토리 기반 E2E 자동 생성
claude "다음 사용자 스토리를 Playwright 테스트로 변환해줘:
'사용자가 상품을 장바구니에 담고 결제를 완료한다'
- getByRole, getByLabel 로케이터 우선 사용
- 네트워크 인터셉트로 결제 API 모킹 포함
- 모바일 뷰포트(375px)에서도 실행되도록 설정"
```

```typescript
// e2e/checkout.spec.ts
import { test, expect } from '@playwright/test';

test.describe('결제 플로우', () => {
  test('상품 선택 → 장바구니 → 결제 완료', async ({ page }) => {
    // 결제 API 모킹
    await page.route('**/api/checkout', async route => {
      await route.fulfill({
        status: 200,
        body: JSON.stringify({ orderId: 'order_123', status: 'success' })
      });
    });

    await page.goto('/products');
    await page.getByRole('button', { name: '장바구니 담기' }).first().click();
    await page.getByRole('link', { name: '장바구니 보기' }).click();
    await page.getByRole('button', { name: '결제하기' }).click();

    await expect(page.getByRole('heading', { name: '주문 완료' })).toBeVisible();
  });
});
```

## 비용 기반 테스트 전략 선택

테스트 유형마다 AI 에이전트 투자 대비 효과가 다르다.

| 테스트 유형 | 에이전틱 효과 | 권장 전략 |
|-------------|--------------|-----------|
| 단위 테스트 | 높음 — 경계값·에러 케이스 자동 발견 | AI 우선 생성, 사람 검토 |
| 통합 테스트 | 중간 — API 계약 검증 효과적 | AI 생성 후 비즈니스 로직 사람 보완 |
| E2E 테스트 | 중간 — 해피패스 생성은 잘 되나 유지 비용 주의 | ARIA 로케이터 기반, 셀프힐링 설정 필수 |
| 시각적 회귀 | 낮음 — 스냅샷 비교는 AI 도움 제한적 | Chromatic 등 전용 도구 병행 |
| 성능 테스트 | 높음 — 병목 탐지 자동화 가능 | AI 워크플로우와 통합 |

**실용 기준**: 반복 실행이 많고, 실패 시 수정이 번거로운 테스트일수록 에이전틱 접근의 ROI가 높다.

## CLAUDE.md에 테스팅 규칙 정의하기

에이전트가 프로젝트에 맞는 테스트를 생성하려면 테스팅 규칙을 CLAUDE.md에 명시해야 한다.

```markdown
## 테스팅 규칙

### 테스트 프레임워크
- 단위/통합: Vitest
- E2E: Playwright
- 컴포넌트: Testing Library

### 로케이터 우선순위 (Playwright)
1. getByRole — ARIA 역할 기반 (최우선)
2. getByLabel — 레이블 텍스트 기반
3. getByText — 텍스트 기반
4. getByTestId — data-testid (마지막 수단)
❌ CSS 셀렉터, XPath 사용 금지

### 커버리지 기준
- 함수 커버리지: 80% 이상
- 신규 기능: 테스트 없이 PR 불가

### 모킹 규칙
- 외부 API: 반드시 모킹
- 데이터베이스: in-memory SQLite 사용
- 시간 관련: vi.useFakeTimers() 사용
```

## 에이전틱 테스팅 파이프라인 구성

```
코드 변경
    ↓
[AI 커버리지 분석]
    ↓
부족한 케이스 탐지
    ↓
[AI 테스트 생성]
    ↓
PR에 테스트 포함
    ↓
CI 실행
    ↓
실패 발생?
    ├─ 예 → [/autofix-pr] → 자동 수정 → 재실행
    └─ 아니오 → 머지
```

## 흔한 함정과 해결법

| 함정 | 증상 | 해결 |
|------|------|------|
| 테스트 과잉 생성 | AI가 유사 케이스를 수십 개 생성 | CLAUDE.md에 "중복 최소화" 명시 |
| 구현 세부사항 테스트 | 내부 함수 직접 테스트 → 리팩토링 시 전부 깨짐 | "인터페이스 기반 테스트" 규칙 추가 |
| 셀프힐링 오남용 | AI가 로케이터 대신 테스트 로직을 바꿈 | 수정 범위를 "로케이터·셀렉터만"으로 제한 |
| 플레이키(flaky) 테스트 | 비결정적 타이밍 의존 | `page.waitForResponse()` 사용 규칙 명시 |

## 체크리스트

- [ ] CLAUDE.md에 테스팅 프레임워크·로케이터 우선순위 명시
- [ ] Playwright 설정에서 ARIA 기반 로케이터 강제
- [ ] CI 실패 시 `/autofix-pr` 자동 실행 워크플로우 구성
- [ ] 커버리지 리포트를 JSON으로 출력하여 AI 분석 가능하게 설정
- [ ] 주 1회 이상 에이전트로 커버리지 공백 점검

## 다음 단계

→ [AI 에이전트 기반 API 계약 테스트 자동화](../workflows/ai-api-contract-testing.md)  
→ [AI 에이전트 CI/CD 파이프라인 자동 최적화 워크플로우](../workflows/ai-cicd-pipeline-optimization.md)  
→ [AI 에이전트 코드 생성 품질 게이트 자동화 플레이북](../claude-code/playbooks/67-ai-code-quality-gates.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
