# 플레이북 26: AI 코딩 에이전트로 웹 접근성 검사하기

> 웹 접근성(a11y) 검사를 AI 에이전트와 함께 체계적으로 수행하는 방법 — WCAG 2.2 기준, axe-core 자동화, 수동 검증까지

## 소요 시간

30-45분

## 사전 준비

- Node.js 18+ 설치
- Claude Code 또는 AI 코딩 에이전트 설정 완료
- 검사 대상 웹 프로젝트 (React, Next.js, Vue 등)
- Playwright 또는 Cypress 테스트 환경

## 왜 AI + 접근성인가?

자동화 도구만으로는 WCAG 2.2 AA 기준의 약 30~40%만 검출할 수 있어요. 나머지는 맥락을 이해해야 판단 가능한 항목들이에요. AI 에이전트를 활용하면 자동 스캔 결과를 해석하고, 수정 코드까지 한 번에 생성할 수 있어요.

| 접근 방식 | 커버리지 | 시간 |
|----------|----------|------|
| 수동 검사만 | 90%+ | 수 일 |
| 자동화만 (axe-core) | 30-40% | 수 분 |
| 자동화 + AI 에이전트 | 60-70% | 30-45분 |

## Step 1: axe-core + Playwright 설정

프로젝트에 접근성 테스트 의존성을 추가해요.

```bash
npm install -D @axe-core/playwright playwright
```

테스트 파일을 생성해요:

```typescript
// tests/accessibility.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const pages = [
  { name: 'Home', path: '/' },
  { name: 'Login', path: '/login' },
  { name: 'Dashboard', path: '/dashboard' },
];

for (const page of pages) {
  test(`${page.name} 페이지 접근성 검사`, async ({ page: pw }) => {
    await pw.goto(page.path);
    
    const results = await new AxeBuilder({ page: pw })
      .withTags(['wcag2a', 'wcag2aa', 'wcag22aa'])
      .analyze();

    // 위반 사항을 상세 출력
    if (results.violations.length > 0) {
      console.log(`\n=== ${page.name} 위반 ${results.violations.length}건 ===`);
      for (const v of results.violations) {
        console.log(`[${v.impact}] ${v.id}: ${v.description}`);
        console.log(`  영향 노드: ${v.nodes.length}개`);
        console.log(`  수정 방법: ${v.help}`);
      }
    }

    expect(results.violations).toEqual([]);
  });
}
```

## Step 2: 첫 스캔 실행

```bash
npx playwright test tests/accessibility.spec.ts --reporter=json > a11y-report.json
```

결과 JSON에서 위반 사항을 빠르게 확인:

```bash
cat a11y-report.json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for suite in data.get('suites', []):
    for spec in suite.get('specs', []):
        print(f\"{spec['title']}: {'PASS' if spec['ok'] else 'FAIL'}\")
"
```

## Step 3: AI 에이전트에게 수정 요청

스캔 결과를 AI 에이전트의 컨텍스트로 전달해요.

**CLAUDE.md에 접근성 규칙 추가:**

```markdown
## 접근성 규칙

- 모든 img 태그에 의미 있는 alt 속성 필수
- 폼 입력에 label 연결 필수 (htmlFor 또는 aria-label)
- 색상 대비 최소 4.5:1 (일반 텍스트), 3:1 (큰 텍스트)
- 키보드만으로 모든 기능 사용 가능해야 함
- focus 표시가 시각적으로 명확해야 함
```

**AI 에이전트에게 수정 프롬프트:**

```
a11y-report.json을 분석해서 위반 사항을 수정해줘.
각 위반에 대해:
1. 영향받는 파일과 라인을 찾아서
2. WCAG 2.2 AA 기준에 맞게 수정하고
3. 수정 전/후를 주석으로 설명해줘
```

## Step 4: 주요 검사 항목 체크리스트

AI 에이전트가 자동 스캔으로 못 잡는 항목은 직접 확인해야 해요.

### 자동 검출 가능 (axe-core)

| 항목 | WCAG 기준 | 검사 방법 |
|------|----------|----------|
| alt 텍스트 누락 | 1.1.1 | `image-alt` 규칙 |
| label 없는 폼 | 1.3.1 | `label` 규칙 |
| 색상 대비 부족 | 1.4.3 | `color-contrast` 규칙 |
| 중복 id | 4.1.1 | `duplicate-id` 규칙 |
| 빈 링크/버튼 | 4.1.2 | `link-name`, `button-name` |

### AI 에이전트 보조 필요

| 항목 | WCAG 기준 | AI 활용법 |
|------|----------|----------|
| alt 텍스트 품질 | 1.1.1 | "이 이미지의 alt가 맥락에 맞는지 검토해줘" |
| 논리적 탭 순서 | 2.4.3 | "tabindex 순서가 시각적 순서와 일치하는지 확인해줘" |
| 에러 메시지 명확성 | 3.3.1 | "폼 에러 메시지가 사용자에게 명확한지 검토해줘" |
| ARIA 패턴 적절성 | 4.1.2 | "이 커스텀 컴포넌트의 ARIA 역할이 올바른지 확인해줘" |
| 포커스 관리 | 2.4.7 | "모달 열릴 때 포커스 이동이 올바른지 확인해줘" |

## Step 5: CI/CD 파이프라인에 통합

접근성 검사를 자동화 파이프라인에 추가해요.

```yaml
# .github/workflows/a11y.yml
name: Accessibility Check

on: [pull_request]

jobs:
  a11y:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - run: npm ci
      - run: npm run build
      - run: npm start &
      - run: npx wait-on http://localhost:3000

      - run: npx playwright install chromium
      - run: npx playwright test tests/accessibility.spec.ts
        env:
          BASE_URL: http://localhost:3000
```

## Step 6: 점진적 개선 전략

한 번에 모든 위반을 수정하기보다 단계적으로 접근해요.

```bash
# 1단계: critical, serious만 먼저 수정
npx playwright test tests/accessibility.spec.ts 2>&1 | grep -E "\[(critical|serious)\]"

# 2단계: moderate 수정
npx playwright test tests/accessibility.spec.ts 2>&1 | grep "\[moderate\]"

# 3단계: minor 수정 + 수동 검증
```

**AI 에이전트 활용 팁:**

| 상황 | 프롬프트 |
|------|---------|
| 대량 수정 | "critical 위반부터 우선순위로 수정하고, 각 파일별로 PR 분리해줘" |
| 컴포넌트 패턴화 | "접근성 준수하는 Button, Input, Modal 컴포넌트를 만들어줘" |
| 스크린리더 테스트 | "VoiceOver로 이 페이지를 탐색할 때 읽히는 순서를 예측해줘" |
| 키보드 내비게이션 | "Tab 키로 이 폼을 순회할 때 순서와 포커스 트랩을 검증해줘" |

## 체크리스트

- [ ] axe-core + Playwright 테스트 설정 완료
- [ ] 주요 페이지 자동 스캔 실행
- [ ] critical/serious 위반 사항 수정
- [ ] CLAUDE.md에 접근성 규칙 추가
- [ ] CI/CD 파이프라인에 접근성 검사 통합
- [ ] 키보드 내비게이션 수동 검증
- [ ] 스크린리더 호환성 확인

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| 장식 이미지에 alt="" 안 넣기 | 장식용이면 `alt=""`로 명시, 의미 있으면 설명 작성 |
| `div`에 click 이벤트만 추가 | `button` 또는 `role="button"` + `tabindex="0"` + 키보드 핸들러 |
| 색상만으로 상태 구분 | 아이콘, 텍스트 레이블 등 추가 시각 단서 제공 |
| 모달에서 포커스 탈출 | 포커스 트랩 구현 (`focus-trap-react` 등 사용) |
| aria-label 남용 | 기본 HTML 시맨틱이 충분하면 ARIA 불필요 |

## 다음 단계

→ [플레이북 07: 성능 최적화](./07-performance.md)
→ [가이드 16: AI 코딩 보안](../../guides/16-ai-coding-security.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
