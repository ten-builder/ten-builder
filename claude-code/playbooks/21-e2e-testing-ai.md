# 21. AI E2E 테스트 자동화 플레이북

> AI 코딩 에이전트로 Playwright/Cypress E2E 테스트를 작성하고 유지보수하는 6단계 워크플로우

## 왜 AI + E2E 테스트인가?

E2E 테스트는 작성 비용이 높고, UI 변경 시 깨지기 쉽다. AI 코딩 에이전트를 활용하면:

- **초기 테스트 생성 속도 5배 향상** — 페이지 구조를 읽고 테스트를 자동 생성
- **깨진 테스트 자동 수정** — selector 변경, 플로우 변경에 대한 자동 대응
- **테스트 커버리지 확장** — 놓치기 쉬운 엣지케이스와 접근성 테스트 자동 추가

```
┌─────────────────────────────────────────────────────────┐
│  AI E2E 테스트 자동화 6단계                                │
│                                                         │
│  1. 프레임워크 선택 & 셋업                                  │
│  2. 페이지 오브젝트 모델(POM) 생성                           │
│  3. 사용자 시나리오 → 테스트 코드 변환                        │
│  4. 데이터 팩토리 & 테스트 격리                              │
│  5. CI 통합 & 병렬 실행                                     │
│  6. 깨진 테스트 자동 진단 & 수정                             │
└─────────────────────────────────────────────────────────┘
```

## Step 1: 프레임워크 선택 & 셋업

### Playwright vs Cypress — AI 친화성 비교

| 항목 | Playwright | Cypress |
|------|-----------|---------|
| AI 코드 생성 정확도 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 타입 지원 | TypeScript 네이티브 | 별도 설정 필요 |
| 병렬 실행 | 내장 | Dashboard/별도 도구 |
| 크로스 브라우저 | Chromium, Firefox, WebKit | Chromium 중심 |
| AI Codegen 도구 | `playwright codegen` | 없음 |
| 비동기 처리 | `async/await` 네이티브 | 자체 체이닝 |

> 💡 **추천:** Playwright를 기본으로 사용하세요. TypeScript 네이티브 지원과 `async/await` 패턴이 AI 에이전트의 코드 생성 정확도를 높여줍니다.

### AI 에이전트에게 셋업 맡기기

```markdown
# 프롬프트 예시
Playwright E2E 테스트 환경을 셋업해줘.

요구사항:
- TypeScript + Playwright Test
- 3개 브라우저 프로필 (chromium, firefox, webkit)
- 기본 타임아웃 30초, 액션 타임아웃 10초
- 스크린샷: 실패 시만 캡처
- 비디오: 첫 리트라이에서만 녹화
- HTML 리포터 + JSON 리포터 동시 출력
- baseURL은 환경변수 BASE_URL에서 읽기
```

### 생성되는 `playwright.config.ts`

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? '50%' : undefined,
  timeout: 30_000,
  
  reporter: [
    ['html', { open: 'never' }],
    ['json', { outputFile: 'test-results/results.json' }],
  ],

  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    actionTimeout: 10_000,
    screenshot: 'only-on-failure',
    video: 'on-first-retry',
    trace: 'on-first-retry',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

## Step 2: 페이지 오브젝트 모델(POM) 생성

POM 패턴을 사용하면 AI가 생성한 테스트의 유지보수성이 크게 높아진다.

### AI에게 POM 생성 요청

```markdown
# 프롬프트 예시
로그인 페이지의 Page Object Model을 만들어줘.

페이지 URL: /login
주요 요소:
- 이메일 입력 필드
- 비밀번호 입력 필드
- 로그인 버튼
- 에러 메시지 영역
- "비밀번호 찾기" 링크
- "회원가입" 링크

규칙:
- getByRole, getByLabel 등 시맨틱 locator 사용 (CSS selector 금지)
- 각 액션 메서드는 결과 페이지 객체를 반환
- 검증 헬퍼 메서드 포함
```

### 생성 결과

```typescript
// e2e/pages/login.page.ts
import { type Locator, type Page, expect } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly loginButton: Locator;
  readonly errorMessage: Locator;
  readonly forgotPasswordLink: Locator;
  readonly signupLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.getByLabel('이메일');
    this.passwordInput = page.getByLabel('비밀번호');
    this.loginButton = page.getByRole('button', { name: '로그인' });
    this.errorMessage = page.getByRole('alert');
    this.forgotPasswordLink = page.getByRole('link', { name: '비밀번호 찾기' });
    this.signupLink = page.getByRole('link', { name: '회원가입' });
  }

  async goto() {
    await this.page.goto('/login');
    return this;
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.loginButton.click();
  }

  async expectError(message: string) {
    await expect(this.errorMessage).toContainText(message);
  }

  async expectLoggedIn() {
    await expect(this.page).toHaveURL(/\/dashboard/);
  }
}
```

### POM 체크리스트

AI가 생성한 POM을 검수할 때 확인할 항목:

- [ ] **시맨틱 locator 사용** — `getByRole`, `getByLabel`, `getByText` 우선
- [ ] **CSS/XPath selector 없음** — UI 변경에 취약한 selector 배제
- [ ] **하드코딩된 대기 없음** — `page.waitForTimeout()` 대신 조건 기반 대기
- [ ] **반환 타입 명확** — 페이지 전환 시 다음 POM 객체 반환
- [ ] **독립적인 검증 메서드** — 상태 확인을 POM 안에 캡슐화

## Step 3: 사용자 시나리오 → 테스트 코드 변환

### 시나리오 기반 프롬프트

```markdown
# 프롬프트 예시
다음 사용자 스토리를 E2E 테스트로 변환해줘:

## 회원가입 → 로그인 → 프로필 수정 플로우

1. 회원가입 페이지에서 새 계정을 생성한다
2. 가입 완료 후 자동으로 대시보드로 이동한다
3. 프로필 설정 페이지에서 이름을 변경한다
4. 변경된 이름이 네비게이션 바에 반영된다

엣지케이스:
- 이미 등록된 이메일로 가입 시도
- 비밀번호 규칙 불일치
- 네트워크 지연 상황

Page Object: LoginPage, SignupPage, DashboardPage, ProfilePage 사용
```

### 생성 결과

```typescript
// e2e/flows/signup-to-profile.spec.ts
import { test, expect } from '@playwright/test';
import { SignupPage } from '../pages/signup.page';
import { DashboardPage } from '../pages/dashboard.page';
import { ProfilePage } from '../pages/profile.page';
import { createTestUser } from '../helpers/test-data';

test.describe('회원가입 → 로그인 → 프로필 수정 플로우', () => {
  let testUser: ReturnType<typeof createTestUser>;

  test.beforeEach(() => {
    testUser = createTestUser();
  });

  test('신규 사용자가 가입하고 프로필을 수정할 수 있다', async ({ page }) => {
    // Step 1: 회원가입
    const signupPage = new SignupPage(page);
    await signupPage.goto();
    await signupPage.signup(testUser);

    // Step 2: 대시보드 이동 확인
    const dashboardPage = new DashboardPage(page);
    await dashboardPage.expectWelcomeMessage(testUser.name);

    // Step 3: 프로필 수정
    const profilePage = new ProfilePage(page);
    await profilePage.goto();
    const newName = '수정된 이름';
    await profilePage.updateName(newName);
    await profilePage.expectSaveSuccess();

    // Step 4: 네비게이션 반영 확인
    await expect(page.getByTestId('nav-username')).toHaveText(newName);
  });

  test('이미 등록된 이메일로 가입하면 에러가 표시된다', async ({ page }) => {
    const signupPage = new SignupPage(page);
    await signupPage.goto();
    
    // 첫 번째 가입
    await signupPage.signup(testUser);
    
    // 로그아웃 후 같은 이메일로 재가입 시도
    await page.goto('/logout');
    await signupPage.goto();
    await signupPage.signup(testUser);
    
    await signupPage.expectError('이미 사용 중인 이메일');
  });

  test('비밀번호 규칙에 맞지 않으면 가입할 수 없다', async ({ page }) => {
    const signupPage = new SignupPage(page);
    await signupPage.goto();
    
    await signupPage.signup({
      ...testUser,
      password: '123', // 너무 짧음
    });
    
    await signupPage.expectError('비밀번호는 8자 이상');
  });
});
```

## Step 4: 데이터 팩토리 & 테스트 격리

### AI에게 테스트 데이터 팩토리 생성 요청

```markdown
# 프롬프트 예시
E2E 테스트용 데이터 팩토리를 만들어줘.

요구사항:
- faker.js로 랜덤 데이터 생성
- 각 테스트 실행마다 고유한 데이터
- API 시딩을 위한 헬퍼 함수
- 테스트 후 정리(cleanup) 메커니즘
```

### 생성 결과

```typescript
// e2e/helpers/test-data.ts
import { faker } from '@faker-js/faker';

export interface TestUser {
  name: string;
  email: string;
  password: string;
}

export function createTestUser(overrides?: Partial<TestUser>): TestUser {
  const timestamp = Date.now();
  return {
    name: faker.person.fullName(),
    email: `e2e-${timestamp}-${faker.string.alphanumeric(4)}@test.local`,
    password: `Test${faker.string.alphanumeric(12)}!`,
    ...overrides,
  };
}

// API를 통한 데이터 시딩 (UI를 거치지 않고 빠르게 상태 구성)
export async function seedUser(
  request: import('@playwright/test').APIRequestContext,
  user: TestUser,
) {
  const response = await request.post('/api/test/users', {
    data: user,
  });
  return response.json();
}

export async function cleanupUser(
  request: import('@playwright/test').APIRequestContext,
  email: string,
) {
  await request.delete(`/api/test/users/${encodeURIComponent(email)}`);
}
```

### 테스트 격리 패턴

```typescript
// e2e/fixtures/auth.fixture.ts
import { test as base } from '@playwright/test';
import { createTestUser, seedUser, cleanupUser } from '../helpers/test-data';

type AuthFixtures = {
  authenticatedPage: import('@playwright/test').Page;
  testUser: import('../helpers/test-data').TestUser;
};

export const test = base.extend<AuthFixtures>({
  testUser: async ({}, use) => {
    const user = createTestUser();
    await use(user);
  },

  authenticatedPage: async ({ page, request, testUser }, use) => {
    // Setup: API로 사용자 생성 & 로그인
    await seedUser(request, testUser);
    await page.goto('/login');
    await page.getByLabel('이메일').fill(testUser.email);
    await page.getByLabel('비밀번호').fill(testUser.password);
    await page.getByRole('button', { name: '로그인' }).click();
    await page.waitForURL(/\/dashboard/);

    await use(page);

    // Teardown: 테스트 데이터 정리
    await cleanupUser(request, testUser.email);
  },
});
```

## Step 5: CI 통합 & 병렬 실행

### GitHub Actions 설정

```markdown
# 프롬프트 예시
Playwright E2E 테스트를 GitHub Actions에 통합해줘.

요구사항:
- PR마다 E2E 테스트 실행
- 3개 브라우저 병렬 (matrix)
- 테스트 결과를 PR 코멘트로
- 실패 시 스크린샷/비디오를 artifact로 업로드
- sharding으로 대규모 테스트 분산
```

### 생성되는 워크플로우

```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on:
  pull_request:
    branches: [main]

jobs:
  e2e:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        shard: [1/4, 2/4, 3/4, 4/4]

    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: 'npm'
      
      - run: npm ci
      
      - name: Install Playwright Browsers
        run: npx playwright install --with-deps
      
      - name: Run E2E Tests
        run: npx playwright test --shard=${{ matrix.shard }}
        env:
          BASE_URL: http://localhost:3000
      
      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.shard }}
          path: |
            test-results/
            playwright-report/
          retention-days: 7
```

## Step 6: 깨진 테스트 자동 진단 & 수정

E2E 테스트가 깨졌을 때 AI 에이전트를 활용한 자동 수정 패턴:

### 진단 프롬프트

```markdown
# 프롬프트 예시
E2E 테스트가 CI에서 실패했어. 원인을 분석하고 수정해줘.

실패한 테스트: e2e/flows/checkout.spec.ts
에러 메시지: "Timeout waiting for selector [data-testid='submit-order']"

참고 파일:
- 최근 변경된 컴포넌트: src/components/checkout/OrderButton.tsx
- Playwright trace: test-results/checkout-trace.zip

가능한 원인을 순서대로 확인해줘:
1. selector가 변경되었나?
2. 렌더링 조건이 바뀌었나?
3. API 응답이 달라졌나?
```

### 자동 수정 워크플로우

```
실패 감지
  │
  ├─ 1. 에러 메시지 분석
  │     └─ Timeout? → selector 변경 확인
  │     └─ Assertion? → 기대값 변경 확인
  │     └─ Network? → API 응답 확인
  │
  ├─ 2. 소스 코드 diff 확인
  │     └─ 최근 커밋에서 관련 컴포넌트 변경 추적
  │
  ├─ 3. 수정 적용
  │     └─ POM의 locator 업데이트
  │     └─ 테스트 시나리오 조정
  │     └─ 새로운 대기 조건 추가
  │
  └─ 4. 로컬 실행으로 검증
        └─ npx playwright test --grep "실패한 테스트"
```

### 안정적인 E2E 테스트를 위한 AI 프롬프트 규칙

CLAUDE.md에 다음 규칙을 추가하면 AI가 더 안정적인 테스트를 생성합니다:

```markdown
## E2E 테스트 규칙

- `page.waitForTimeout()` 사용 금지 — `waitForSelector`, `waitForResponse` 등 조건 기반 대기만 사용
- CSS selector 대신 `getByRole`, `getByLabel`, `getByText` 등 시맨틱 locator 사용
- `data-testid`는 시맨틱 locator가 불가능할 때만 사용
- 각 테스트는 독립적 — 다른 테스트의 결과에 의존하지 않음
- API 시딩으로 사전 조건 구성 — UI를 통한 셋업은 테스트 대상 플로우에서만
- 하드코딩된 값 대신 팩토리 함수로 테스트 데이터 생성
- 네트워크 요청 완료를 기다린 후 assertion 수행
```

## AI 활용 프롬프트 모음

| 상황 | 프롬프트 예시 |
|------|-------------|
| POM 생성 | `이 페이지의 Page Object Model 만들어줘. 시맨틱 locator만 사용해` |
| 시나리오 → 테스트 | `이 사용자 스토리를 Playwright 테스트로 변환해줘` |
| 깨진 테스트 수정 | `이 에러 메시지 보고 테스트 수정해줘. trace 파일도 참고해` |
| 접근성 테스트 | `각 페이지에 axe-core 접근성 테스트 추가해줘` |
| 모바일 테스트 | `이 테스트를 모바일 뷰포트(iPhone 14)에서도 실행되게 해줘` |
| 시각적 회귀 | `이 컴포넌트에 Playwright 스냅샷 테스트 추가해줘` |
| API 모킹 | `외부 결제 API를 route.fulfill()로 모킹해줘` |
| 성능 측정 | `페이지 로드 시간을 측정하는 테스트 추가해줘 (Web Vitals)` |

## 핵심 포인트 정리

| 패턴 | 설명 |
|------|------|
| POM 우선 | 테스트 전에 Page Object를 먼저 생성 → 재사용성 ↑ |
| 시맨틱 Locator | CSS selector 대신 역할/라벨 기반 → 안정성 ↑ |
| API 시딩 | UI가 아닌 API로 사전 데이터 구성 → 속도 ↑ |
| 팩토리 패턴 | 랜덤 테스트 데이터로 테스트 격리 → 신뢰성 ↑ |
| Fixture 활용 | 공통 셋업/티어다운을 fixture로 캡슐화 → 중복 ↓ |
| CI Sharding | 테스트를 여러 머신에 분산 → CI 시간 ↓ |
| 자동 진단 | 실패 원인을 AI가 trace/diff 기반으로 분석 → 수정 속도 ↑ |

## 안티패턴 — AI가 자주 만드는 실수

| ❌ 안티패턴 | ✅ 올바른 패턴 |
|------------|--------------|
| `await page.waitForTimeout(3000)` | `await page.waitForSelector('.loaded')` |
| `page.locator('.btn-primary')` | `page.getByRole('button', { name: '제출' })` |
| 테스트 간 데이터 공유 | 각 테스트에서 독립적으로 데이터 생성 |
| UI로 로그인 반복 | `storageState`로 인증 상태 재사용 |
| 전체 페이지 스크린샷 비교 | 특정 컴포넌트 단위 스냅샷 |
| `expect(text).toBe('정확한 문자열')` | `expect(text).toContain('핵심 키워드')` |

## 확장하기

이 플레이북을 기반으로 다음을 추가해 보세요:

- **Visual Regression Testing** — Playwright의 `toHaveScreenshot()`으로 UI 변경 감지
- **접근성 자동 테스트** — axe-core 통합으로 WCAG 위반 자동 발견
- **성능 예산 테스트** — Web Vitals 임계값을 E2E 테스트에 통합
- **API 계약 테스트** — Playwright의 `request` fixture로 API 스펙 검증

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
