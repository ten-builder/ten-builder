# 플레이북 65: AI 에이전트 프론트엔드 성능 최적화

> Next.js/TypeScript 프로젝트에서 Core Web Vitals를 목표치 이내로 맞추는 자동화 플레이북 — AI 에이전트가 측정부터 수정까지 담당합니다.

## 소요 시간

30–60분 (초기 분석 + 자동 수정 루프)

## 사전 준비

- Next.js 15+ 프로젝트 (App Router 권장)
- `@next/bundle-analyzer`, `lighthouse-ci` 설치
- `web-vitals` 라이브러리 통합 또는 Vercel Analytics

## 2026 Core Web Vitals 기준

| 지표 | 목표 | 개선 필요 | 나쁨 |
|------|------|-----------|------|
| LCP (Largest Contentful Paint) | ≤ 2.5s | 2.5–4.0s | > 4.0s |
| INP (Interaction to Next Paint) | ≤ 200ms | 200–500ms | > 500ms |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | 0.1–0.25 | > 0.25 |
| TTFB (Time to First Byte) | ≤ 200ms | 200–600ms | > 600ms |

> 2024년부터 FID 대신 INP가 공식 지표로 사용됩니다. 경쟁 사이트는 INP 150ms 이하를 목표로 합니다.

---

## Step 1: Lighthouse 기준선 측정 자동화

AI 에이전트에게 프로젝트 루트에서 아래 설정을 만들어달라고 요청합니다.

### lighthouserc.js 설정

```javascript
// lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: ['http://localhost:3000', 'http://localhost:3000/dashboard'],
      numberOfRuns: 3,
    },
    assert: {
      assertions: {
        'categories:performance': ['warn', { minScore: 0.8 }],
        'first-contentful-paint': ['error', { maxNumericValue: 2000 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'total-blocking-time': ['warn', { maxNumericValue: 300 }],
        interactive: ['warn', { maxNumericValue: 3800 }],
      },
    },
    upload: {
      target: 'temporary-public-storage',
    },
  },
};
```

### GitHub Actions CI 통합

```yaml
# .github/workflows/performance.yml
name: Performance Budget
on:
  pull_request:
    branches: [main]

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm ci && npm run build
      - run: npm start &
      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v12
        with:
          configPath: ./lighthouserc.js
          uploadArtifacts: true
```

**AI 에이전트 프롬프트:**
> "현재 Next.js 프로젝트에 lighthouserc.js와 GitHub Actions 워크플로우를 추가해줘. 목표: LCP 2.5s, INP 200ms, CLS 0.1 이하."

---

## Step 2: 번들 크기 분석 및 자동 최적화

### 번들 분석기 설정

```javascript
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});

module.exports = withBundleAnalyzer({
  experimental: {
    optimizePackageImports: [
      'lucide-react',
      '@radix-ui/react-icons',
      'date-fns',
    ],
  },
  compress: true,
});
```

```bash
# 번들 분석 실행
ANALYZE=true npm run build
```

### AI 에이전트 번들 최적화 루프

```bash
# CLAUDE.md에 추가할 번들 최적화 규칙
cat >> CLAUDE.md << 'EOF'

## 번들 최적화 규칙
- 새 패키지 추가 시 번들 크기 영향 확인 필수
- `import * as` 사용 금지 — named import만 사용
- 300KB 초과 컴포넌트 발견 시 dynamic import로 전환
- 이미지는 반드시 next/image 사용
EOF
```

**동적 임포트 적용 패턴:**

```typescript
// Before: 번들에 항상 포함
import { Chart } from '@/components/chart';

// After: 필요할 때만 로드
import dynamic from 'next/dynamic';

const Chart = dynamic(() => import('@/components/chart'), {
  loading: () => <div className="h-64 animate-pulse bg-gray-100 rounded" />,
  ssr: false, // 서버 렌더링 불필요한 경우
});
```

**AI 에이전트 프롬프트:**
> "번들 분석 결과를 보고 300KB 이상인 컴포넌트를 찾아서 dynamic import로 전환해줘. loading 상태는 skeleton UI로 처리해."

---

## Step 3: LCP 최적화 — 이미지와 폰트

### 이미지 최적화 자동화

```typescript
// components/hero-image.tsx
import Image from 'next/image';

// AI 에이전트가 자동으로 적용하는 패턴
export function HeroImage() {
  return (
    <Image
      src="/hero.webp"
      alt="히어로 이미지"
      width={1200}
      height={600}
      priority // LCP 이미지에 필수
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
      quality={85}
    />
  );
}
```

### 폰트 최적화

```typescript
// app/layout.tsx
import { Geist } from 'next/font/google';

const geist = Geist({
  subsets: ['latin'],
  display: 'swap',        // FOUT 허용, CLS 방지
  preload: true,          // 폰트 사전 로드
  variable: '--font-geist',
});
```

**AI 에이전트 프롬프트:**
> "프로젝트 내 모든 `<img>` 태그를 next/image로 교체하고, LCP 이미지(뷰포트 내 가장 큰 이미지)에 priority 속성을 추가해줘."

---

## Step 4: INP 최적화 — 인터랙션 응답성

### useTransition으로 무거운 상태 업데이트 처리

```typescript
'use client';
import { useTransition, useState } from 'react';

export function SearchComponent() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<string[]>([]);
  const [isPending, startTransition] = useTransition();

  const handleSearch = (value: string) => {
    setQuery(value); // 즉시 업데이트 (INP에 영향)

    startTransition(() => {
      // 무거운 필터링 작업 — 저우선순위로 처리
      const filtered = expensiveFilter(value);
      setResults(filtered);
    });
  };

  return (
    <div>
      <input
        value={query}
        onChange={(e) => handleSearch(e.target.value)}
        placeholder="검색..."
      />
      {isPending ? (
        <div className="animate-pulse">검색 중...</div>
      ) : (
        <ResultList items={results} />
      )}
    </div>
  );
}
```

### 긴 태스크 분산 처리

```typescript
// utils/scheduler.ts
export async function yieldToMain(): Promise<void> {
  if ('scheduler' in window && 'yield' in (window as any).scheduler) {
    return (window as any).scheduler.yield();
  }
  return new Promise((resolve) => setTimeout(resolve, 0));
}

// 무거운 루프에서 INP 개선
export async function processLargeArray<T>(
  items: T[],
  processFn: (item: T) => void
) {
  for (let i = 0; i < items.length; i++) {
    processFn(items[i]);
    // 50개마다 메인 스레드에 양보
    if (i % 50 === 0) await yieldToMain();
  }
}
```

**AI 에이전트 프롬프트:**
> "클릭/입력 이벤트 핸들러에서 200ms 이상 걸리는 작업을 찾아서 useTransition 또는 scheduler.yield()로 분리해줘."

---

## Step 5: CLS 방지 — 레이아웃 안정성

| 원인 | 해결 |
|------|------|
| 이미지 크기 미지정 | `width`/`height` 속성 또는 `aspect-ratio` CSS 필수 |
| 폰트 교체 FOUT | `font-display: swap` + `size-adjust` 속성 |
| 동적 콘텐츠 삽입 | 광고/배너 공간을 미리 확보 (`min-height`) |
| 지연 로드 컴포넌트 | 스켈레톤 UI로 공간 유지 |

```css
/* globals.css — CLS 방지 기본 설정 */
img, video {
  max-width: 100%;
  height: auto;
}

/* 배너/광고 공간 사전 확보 */
.ad-container {
  min-height: 90px;
  container-type: inline-size;
}
```

---

## Step 6: CI/CD 성능 게이트 통합

```yaml
# .github/workflows/performance.yml 에 추가
- name: Bundle Size Check
  run: |
    SIZE=$(du -sk .next/static | cut -f1)
    echo "Bundle size: ${SIZE}KB"
    if [ "$SIZE" -gt 5000 ]; then
      echo "::error::번들 크기 초과: ${SIZE}KB (한계: 5000KB)"
      exit 1
    fi

- name: Performance Budget Summary
  run: |
    echo "## 성능 예산 결과" >> $GITHUB_STEP_SUMMARY
    echo "| 지표 | 현재값 | 목표 | 통과 |" >> $GITHUB_STEP_SUMMARY
    echo "|------|--------|------|------|" >> $GITHUB_STEP_SUMMARY
```

---

## 체크리스트

- [ ] lighthouserc.js 설정 및 CI 통합 완료
- [ ] 번들 분석 실행 — 300KB 초과 컴포넌트 없음
- [ ] LCP 이미지에 `priority` 속성 추가
- [ ] 폰트 `next/font/google`으로 최적화
- [ ] 무거운 인터랙션에 `useTransition` 적용
- [ ] 이미지/동적 콘텐츠에 크기 명시 (CLS 방지)
- [ ] PR마다 Lighthouse 점수 자동 체크 활성화

## AI 에이전트 통합 워크플로우 요약

```bash
# 1. 기준선 측정
npx lhci autorun

# 2. 문제 파악 → AI에게 리포트
# "Lighthouse 결과: LCP 3.8s, INP 350ms. 이 프로젝트에서 원인을 찾고 수정해줘."

# 3. 자동 수정 후 재측정
npm run build && npx lhci autorun

# 4. PR 게이트에서 자동 검증
git push origin feature/perf-optimize
```

## 다음 단계

→ [플레이북 60: 풀스택 타입 안전성 확보](./60-fullstack-type-safety-playbook.md)
→ [플레이북 61: 프로덕션 버그 30분 내 해결](./61-production-debug-timeline.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
