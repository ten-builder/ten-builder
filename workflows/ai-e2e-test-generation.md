# AI 에이전트 기반 E2E 테스트 자동 생성 워크플로우

> Playwright + AI 에이전트로 신규 기능 구현 후 E2E 테스트를 자동 생성하고 CI/CD 파이프라인에 통합하는 워크플로우

## 개요

새 기능을 구현할 때마다 E2E 테스트 작성이 뒤처지는 건 흔한 문제입니다. "나중에 쓰지"가 결국 "영원히 안 쓰기"가 되는 패턴이죠.

이 워크플로우는 AI 에이전트가 새 기능 구현 직후 자동으로 Playwright E2E 테스트를 생성하고, GitHub Actions에 연결해서 PR마다 검증하는 전체 흐름을 다룹니다.

**이런 팀에 적합합니다:**

- Playwright를 쓰고 있지만 E2E 테스트 커버리지가 낮은 팀
- AI 에이전트로 구현 속도를 올렸지만 테스트가 따라오지 못하는 팀
- E2E 테스트 작성에 시간이 너무 많이 걸려서 건너뛰는 팀

## 사전 준비

- Node.js 18+ 및 Playwright 설치
- Claude Code 또는 터미널 AI 에이전트
- GitHub Actions 접근 권한

```bash
# Playwright 설치
npm init playwright@latest

# 필요한 브라우저 설치
npx playwright install chromium
```

## 워크플로우 구조

```
기능 구현 완료
    ↓
AI 에이전트 호출 (사용자 플로우 분석)
    ↓
E2E 테스트 초안 자동 생성
    ↓
로컬 실행 검증
    ↓
PR 생성 + GitHub Actions 연동
    ↓
CI에서 자동 실행
```

## Step 1: CLAUDE.md에 E2E 테스트 생성 규칙 추가

AI 에이전트가 일관된 방식으로 테스트를 생성하도록 프로젝트 컨텍스트를 설정합니다.

```markdown
# E2E 테스트 생성 규칙

## 테스트 파일 위치
- 모든 E2E 테스트: `tests/e2e/` 폴더
- 파일명: `[기능명].spec.ts`

## 테스트 구조 원칙
- 각 테스트는 독립적으로 실행 가능해야 함
- test.beforeEach로 공통 설정 처리
- data-testid 속성 우선 사용 (CSS 선택자 최소화)
- 네트워크 요청은 page.waitForResponse로 대기

## 필수 포함 시나리오
1. 정상 플로우 (Happy Path)
2. 유효성 검사 오류 처리
3. 빈 상태(Empty State) 렌더링
4. 로딩 상태 처리
```

## Step 2: AI 에이전트 호출 프롬프트 패턴

기능 구현 후 아래 프롬프트로 AI 에이전트에게 테스트 생성을 요청합니다.

```
방금 구현한 [기능명] 기능에 대한 Playwright E2E 테스트를 작성해줘.

구현 파일: [파일 경로]
사용자 플로우:
1. [첫 번째 단계]
2. [두 번째 단계]
3. [예상 결과]

다음을 포함해줘:
- Happy Path 시나리오
- 유효성 오류 케이스
- 로딩/빈 상태 처리

파일 위치: tests/e2e/[기능명].spec.ts
```

## Step 3: 생성된 테스트 구조 예시

AI 에이전트가 생성하는 전형적인 테스트 구조입니다.

```typescript
import { test, expect } from '@playwright/test';

test.describe('사용자 로그인', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
  });

  test('정상 로그인 플로우', async ({ page }) => {
    // 입력
    await page.getByTestId('email-input').fill('user@example.com');
    await page.getByTestId('password-input').fill('password123');

    // 제출 및 응답 대기
    const responsePromise = page.waitForResponse('/api/auth/login');
    await page.getByTestId('login-button').click();
    await responsePromise;

    // 결과 검증
    await expect(page).toHaveURL('/dashboard');
    await expect(page.getByTestId('user-menu')).toBeVisible();
  });

  test('잘못된 비밀번호 오류 처리', async ({ page }) => {
    await page.getByTestId('email-input').fill('user@example.com');
    await page.getByTestId('password-input').fill('wrong');
    await page.getByTestId('login-button').click();

    await expect(page.getByTestId('error-message')).toContainText(
      '이메일 또는 비밀번호가 올바르지 않습니다'
    );
  });

  test('빈 폼 유효성 검사', async ({ page }) => {
    await page.getByTestId('login-button').click();

    await expect(page.getByTestId('email-error')).toBeVisible();
    await expect(page.getByTestId('password-error')).toBeVisible();
  });
});
```

## Step 4: playwright.config.ts 설정

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',

  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

## Step 5: GitHub Actions 연동

```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on:
  pull_request:
    branches: [main, develop]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: 의존성 설치
        run: npm ci

      - name: Playwright 브라우저 설치
        run: npx playwright install --with-deps chromium

      - name: E2E 테스트 실행
        run: npx playwright test
        env:
          BASE_URL: ${{ secrets.STAGING_URL }}

      - name: 결과 업로드
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 7
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `retries` | CI: 2, 로컬: 0 | 실패 시 재시도 횟수 |
| `workers` | CI: 1, 로컬: 자동 | 병렬 실행 수 |
| `trace` | on-first-retry | 트레이스 수집 조건 |
| `screenshot` | only-on-failure | 스크린샷 수집 조건 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 선택자를 찾을 수 없음 | `data-testid` 속성을 구현 코드에 추가 |
| 테스트가 간헐적으로 실패 | `waitForResponse` 또는 `waitForSelector` 추가 |
| CI에서만 실패 | `BASE_URL` 환경변수와 타임아웃 확인 |
| 테스트가 너무 느림 | `fullyParallel: true` 설정 확인 |

## 적용 후 기대 효과

실제로 이 워크플로우를 적용한 팀들의 경험을 보면:

- **테스트 작성 시간 60-70% 단축** — AI가 초안을 만들면 개발자는 검토와 수정에만 집중
- **커버리지 자연스럽게 향상** — 구현과 동시에 테스트가 생성되니 나중으로 미루지 않음
- **E2E 테스트에 대한 심리적 부담 감소** — "어떻게 쓰지"의 빈 화면 공포가 없어짐

핵심은 AI를 "테스트를 대신 써주는 도구"가 아니라 "초안을 빠르게 만들어주는 페어"로 쓰는 것입니다. 생성된 테스트를 그대로 사용하지 말고, 도메인 지식을 더해서 실제로 의미 있는 검증이 이뤄지도록 다듬으세요.

---

**더 자세한 가이드:** [claude-code/playbooks/21-e2e-testing-ai.md](../claude-code/playbooks/21-e2e-testing-ai.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
