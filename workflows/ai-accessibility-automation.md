# AI 에이전트 기반 웹 접근성(Accessibility) 자동화 워크플로우

> WCAG 2.2 준수를 수개월에서 수주로 단축하는 실전 워크플로우 — axe-core 통합, 스크린리더 테스트, 키보드 탐색 검증, 색상 대비 체크, CI/CD 자동화

## 개요

접근성 준수는 대부분의 팀에서 마지막에 처리하는 기술 부채입니다. axe-core 위반이 수백 개 쌓인 코드베이스를 수동으로 수정하면 6~10개월이 걸리지만, AI 에이전트와 함께하면 몇 주로 줄일 수 있습니다.

이 워크플로우는 다음 세 단계로 접근성 자동화를 구현합니다:
1. **감지** — axe-core + Playwright로 WCAG 2.2 위반 자동 스캔
2. **수정** — AI 에이전트가 위반별 코드 패치 생성
3. **검증** — 스크린리더, 키보드 탐색, 색상 대비 자동 검증

## 사전 준비

- Node.js 18+, Playwright 설치
- Claude Code (또는 Gemini CLI, Codex CLI)
- CI/CD 파이프라인 (GitHub Actions 권장)

## Step 1: axe-core 기반 스캔 파이프라인 구축

### 1-1. 의존성 설치

```bash
npm install --save-dev axe-playwright @axe-core/playwright
npm install --save-dev playwright @playwright/test
```

### 1-2. 접근성 스캔 스크립트 작성

```typescript
// scripts/a11y-scan.ts
import { chromium } from "playwright";
import AxeBuilder from "@axe-core/playwright";
import fs from "fs";

const PAGES = ["/", "/about", "/contact", "/dashboard"];

async function scanAll() {
  const browser = await chromium.launch();
  const violations: Record<string, unknown[]> = {};

  for (const path of PAGES) {
    const page = await browser.newPage();
    await page.goto(`http://localhost:3000${path}`);

    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
      .analyze();

    violations[path] = results.violations;
    await page.close();
  }

  fs.writeFileSync("a11y-violations.json", JSON.stringify(violations, null, 2));
  console.log(`스캔 완료 — 총 ${Object.values(violations).flat().length}개 위반 감지`);
  await browser.close();
}

scanAll();
```

### 1-3. AI 에이전트에 위반 분석 위임

```bash
# CLAUDE.md에 접근성 컨텍스트 추가 후 실행
cat a11y-violations.json | claude "
다음 axe-core 위반 목록을 분석해줘.
우선순위 기준:
1. impact: critical > serious > moderate
2. 영향받는 페이지 수
3. 수정 난이도

각 위반에 대해:
- 파일 경로와 수정 방법
- 구체적인 코드 패치
를 제공해줘.
"
```

## Step 2: 유형별 자동 수정 패턴

### 2-1. 이미지 대체 텍스트 자동 추가

```bash
# 누락된 alt 속성 일괄 탐지
grep -rn '<img' src/ --include="*.tsx" --include="*.jsx" | grep -v 'alt='

# AI 에이전트에 컨텍스트 기반 alt 생성 위임
claude "
다음 이미지 파일들의 맥락을 분석해서 의미있는 alt 텍스트를 작성해줘.
장식용 이미지는 alt=\"\"로 처리.
파일: $(grep -rn '<img' src/ | grep -v 'alt=' | head -20)
"
```

### 2-2. 색상 대비 자동 수정

| WCAG 기준 | 일반 텍스트 | 큰 텍스트 (18pt+) |
|-----------|------------|------------------|
| AA (2.2) | 4.5:1 | 3:1 |
| AAA | 7:1 | 4.5:1 |

```typescript
// scripts/fix-contrast.ts
import { parse } from "css";
import { getContrastRatio, lightenDarken } from "./color-utils";

// AI 에이전트가 생성한 패치 적용
const violations = require("./contrast-violations.json");

for (const v of violations) {
  // AI가 제안한 대체 색상값을 CSS 변수에 반영
  console.log(`수정: ${v.selector} — ${v.foreground}/${v.background} → ${v.suggestion}`);
}
```

### 2-3. 키보드 탐색 검증 자동화

```typescript
// tests/keyboard-nav.spec.ts
import { test, expect } from "@playwright/test";

test("키보드만으로 전체 탐색 가능 — 메인 네비게이션", async ({ page }) => {
  await page.goto("/");

  // Tab 키로 순차 탐색
  await page.keyboard.press("Tab");
  const focused = await page.evaluate(() => document.activeElement?.tagName);
  expect(["A", "BUTTON", "INPUT"]).toContain(focused);

  // 포커스 가시성 확인
  const focusVisible = await page.evaluate(() => {
    const el = document.activeElement;
    if (!el) return false;
    const style = window.getComputedStyle(el);
    return style.outlineWidth !== "0px" || style.boxShadow !== "none";
  });
  expect(focusVisible).toBe(true);
});

test("모달 포커스 트랩 동작 확인", async ({ page }) => {
  await page.goto("/");
  await page.click('[data-testid="open-modal"]');

  // 모달 내부에서만 Tab 이동 확인
  for (let i = 0; i < 10; i++) {
    await page.keyboard.press("Tab");
    const inModal = await page.evaluate(() => {
      const modal = document.querySelector('[role="dialog"]');
      return modal?.contains(document.activeElement) ?? false;
    });
    expect(inModal).toBe(true);
  }
});
```

## Step 3: 스크린리더 호환성 검증

### 3-1. ARIA 레이블 자동 감사

```bash
# Playwright + AI로 ARIA 구조 분석
cat << 'EOF' > scripts/aria-audit.ts
import { chromium } from "playwright";

async function auditAria() {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto("http://localhost:3000");

  const ariaIssues = await page.evaluate(() => {
    const issues: string[] = [];

    // role="button"인데 키보드 접근 불가
    document.querySelectorAll('[role="button"]').forEach((el) => {
      const tabIndex = el.getAttribute("tabindex");
      if (!tabIndex || parseInt(tabIndex) < 0) {
        issues.push(`role=button without tabindex: ${el.outerHTML.slice(0, 100)}`);
      }
    });

    // aria-label 또는 aria-labelledby 없는 폼 필드
    document.querySelectorAll("input, select, textarea").forEach((el) => {
      const id = el.getAttribute("id");
      const hasLabel = id
        ? !!document.querySelector(`label[for="${id}"]`)
        : false;
      const hasAria =
        el.getAttribute("aria-label") || el.getAttribute("aria-labelledby");

      if (!hasLabel && !hasAria) {
        issues.push(`Unlabeled form field: ${el.outerHTML.slice(0, 100)}`);
      }
    });

    return issues;
  });

  console.log(`ARIA 문제 ${ariaIssues.length}개 발견:`);
  ariaIssues.forEach((issue) => console.log("  -", issue));
  await browser.close();
}

auditAria();
EOF

npx ts-node scripts/aria-audit.ts
```

### 3-2. 라이브 리전(Live Region) 동적 콘텐츠 처리

```typescript
// 상태 변경 알림 — 스크린리더 호환
// 나쁜 예
const [status, setStatus] = useState("");
return <div>{status}</div>;

// 좋은 예 — AI 에이전트가 수정하는 패턴
const [status, setStatus] = useState("");
return (
  <div aria-live="polite" aria-atomic="true">
    {status}
  </div>
);
```

## Step 4: CI/CD 파이프라인 통합

### 4-1. GitHub Actions 접근성 게이트

```yaml
# .github/workflows/a11y.yml
name: Accessibility Check

on:
  pull_request:
    branches: [main]

jobs:
  a11y:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: 의존성 설치
        run: npm ci

      - name: 앱 빌드 및 실행
        run: |
          npm run build
          npm run start &
          npx wait-on http://localhost:3000

      - name: axe-core 접근성 스캔
        run: npx ts-node scripts/a11y-scan.ts

      - name: 위반 수 임계값 확인
        run: |
          COUNT=$(node -e "
            const v = require('./a11y-violations.json');
            const critical = Object.values(v).flat()
              .filter(x => x.impact === 'critical').length;
            console.log(critical);
          ")
          echo "Critical 위반: $COUNT개"
          if [ "$COUNT" -gt 0 ]; then
            echo "Critical 접근성 위반이 있습니다. PR을 블록합니다."
            exit 1
          fi

      - name: 키보드 탐색 테스트
        run: npx playwright test tests/keyboard-nav.spec.ts
```

### 4-2. 위반 수 트렌드 추적

```bash
# 스프린트별 접근성 개선 현황 확인
cat a11y-violations.json | node -e "
const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
const byImpact = {};
Object.values(data).flat().forEach(v => {
  byImpact[v.impact] = (byImpact[v.impact] || 0) + 1;
});
console.table(byImpact);
"
```

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| axe-core가 SPA 콘텐츠를 못 잡음 | 동적 렌더링 타이밍 | `waitForSelector` 추가 후 재스캔 |
| 색상 대비 false positive | 반투명 오버레이 | 실제 렌더링된 색상으로 계산 |
| 키보드 포커스가 모달 밖으로 탈출 | 포커스 트랩 미구현 | `focus-trap-react` 라이브러리 사용 |
| ARIA role 경고 과다 | 잘못된 role 중첩 | WAI-ARIA 1.2 사양 확인 후 수정 |
| CI에서만 실패 | 폰트 로딩 타이밍 | `page.waitForLoadState('networkidle')` 사용 |

## 체크리스트

- [ ] axe-core 스캔 스크립트 설정 완료
- [ ] 주요 페이지 5개 이상 스캔 등록
- [ ] Critical impact 위반 0건 달성
- [ ] 키보드 탐색 테스트 전 페이지 통과
- [ ] 모든 이미지에 의미있는 alt 텍스트 적용
- [ ] 색상 대비 WCAG 2.2 AA 기준 충족
- [ ] 폼 필드 전체 label/aria-label 연결
- [ ] 모달/드롭다운 포커스 트랩 구현
- [ ] CI/CD 접근성 게이트 활성화
- [ ] 주간 접근성 위반 수 트렌드 추적

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
