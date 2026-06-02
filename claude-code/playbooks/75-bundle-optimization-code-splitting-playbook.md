# 플레이북 75: AI 에이전트 번들 최적화 & 코드 스플리팅

> 프론트엔드 번들 크기를 AI 에이전트와 체계적으로 줄이는 실전 플레이북 — 코드 스플리팅, 트리 셰이킹, 레이지 로딩까지

## 소요 시간

30-60분 (프로젝트 규모에 따라 다름)

## 사전 준비

- Node.js 프로젝트 (React, Vue, Svelte 등)
- Vite, Webpack, Rollup 중 하나의 번들러
- Claude Code 설치 완료
- `npm run build` 명령이 작동하는 상태

---

## Step 1: 현재 번들 상태 진단

먼저 AI 에이전트에게 프로젝트의 번들 현황을 파악하게 합니다.

```
번들 분석 도구를 설치하고 현재 번들 크기와 구성을 분석해줘.
각 청크의 크기, 중복 패키지, 불필요하게 큰 의존성을 찾아서
우선순위별로 최적화 목록을 만들어줘.
```

AI 에이전트가 자동으로 실행하는 분석:

```bash
# Vite 프로젝트
npm install --save-dev rollup-plugin-visualizer

# Webpack 프로젝트
npm install --save-dev webpack-bundle-analyzer

# 번들 빌드 + 시각화
npm run build -- --report
```

**확인할 지표:**

| 지표 | 목표값 | 경고 기준 |
|------|--------|----------|
| 초기 번들 크기 | < 200KB (gzip) | > 500KB |
| 최대 청크 크기 | < 500KB | > 1MB |
| 미사용 코드 비율 | < 10% | > 30% |
| 중복 패키지 | 0개 | 3개 이상 |

---

## Step 2: 코드 스플리팅 적용

번들 분석 결과를 바탕으로 AI 에이전트가 코드 스플리팅 전략을 제안합니다.

```
분석 결과를 보여줄게. 라우트별 코드 스플리팅과 컴포넌트 레이지 로딩을
적용해줘. React/Vue 문법에 맞게 dynamic import를 사용하고,
로딩 중 fallback UI도 추가해줘.
```

**React 라우트 스플리팅:**

```tsx
// 수정 전 — 모든 페이지가 초기 번들에 포함
import Dashboard from './pages/Dashboard';
import Settings from './pages/Settings';
import Analytics from './pages/Analytics';

// 수정 후 — 라우트 접근 시에만 로드
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));
const Analytics = lazy(() => import('./pages/Analytics'));

function App() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/analytics" element={<Analytics />} />
      </Routes>
    </Suspense>
  );
}
```

**Vite 청크 분리 설정:**

```ts
// vite.config.ts
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          // UI 라이브러리 별도 청크
          'ui-vendor': ['@radix-ui/react-dialog', '@radix-ui/react-dropdown-menu'],
          // 차트 라이브러리 별도 청크 (무거운 의존성)
          'chart-vendor': ['recharts', 'd3'],
          // 유틸리티 공통 청크
          'utils': ['lodash-es', 'date-fns'],
        },
      },
    },
    // 청크 크기 경고 임계값
    chunkSizeWarningLimit: 500,
  },
});
```

---

## Step 3: 트리 셰이킹 최적화

AI 에이전트로 미사용 코드를 찾아 제거합니다.

```
프로젝트에서 트리 셰이킹이 제대로 작동하지 않는 곳을 찾아줘.
특히 lodash, date-fns, antd 같은 큰 라이브러리에서
전체 임포트를 사용하는 곳을 개별 임포트로 바꿔줘.
```

**흔한 트리 셰이킹 문제 패턴:**

```ts
// 나쁜 예 — 전체 라이브러리 임포트
import _ from 'lodash';
import * as dateFns from 'date-fns';
import { Button, Input, Modal, Form, Table } from 'antd';

// 좋은 예 — 필요한 것만 임포트
import debounce from 'lodash/debounce';
import { format, parseISO } from 'date-fns';
import { Button } from 'antd/es/button';
```

**package.json sideEffects 설정:**

```json
{
  "name": "my-app",
  "sideEffects": [
    "*.css",
    "*.scss",
    "./src/polyfills.ts"
  ]
}
```

| 라이브러리 | 전체 임포트 크기 | 개별 임포트 크기 | 절감율 |
|-----------|----------------|----------------|--------|
| lodash | ~71KB | ~2-5KB | ~93% |
| date-fns | ~78KB | ~1-3KB | ~96% |
| antd | ~2.8MB | ~20-50KB | ~98% |
| Material UI | ~1.2MB | ~10-30KB | ~97% |

---

## Step 4: 레이지 로딩 패턴 적용

무거운 컴포넌트와 이미지에 레이지 로딩을 적용합니다.

```
에디터, 차트, 모달 같은 무거운 컴포넌트들에 레이지 로딩을 적용하고,
이미지는 Intersection Observer로 뷰포트에 들어올 때만 로드하게 해줘.
```

**무거운 컴포넌트 레이지 로딩:**

```tsx
// 코드 에디터 — 필요할 때만 로드
const CodeEditor = lazy(() =>
  import('@monaco-editor/react').then(mod => ({ default: mod.Editor }))
);

// PDF 뷰어 — 문서 탭 클릭 시에만 로드
const PdfViewer = lazy(() => import('./components/PdfViewer'));

// 차트 — 대시보드 진입 시 로드
const AnalyticsChart = lazy(() =>
  import('recharts').then(mod => ({
    default: ({ data }: { data: any[] }) => (
      <mod.AreaChart data={data}>
        <mod.Area dataKey="value" />
      </mod.AreaChart>
    ),
  }))
);
```

**이미지 레이지 로딩 (Intersection Observer):**

```ts
// hooks/useLazyImage.ts
export function useLazyImage(src: string) {
  const [loaded, setLoaded] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    if (!imgRef.current) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setLoaded(true);
          observer.disconnect();
        }
      },
      { rootMargin: '200px' }  // 200px 전에 미리 로드 시작
    );

    observer.observe(imgRef.current);
    return () => observer.disconnect();
  }, []);

  return { ref: imgRef, src: loaded ? src : undefined };
}
```

---

## Step 5: 최적화 결과 검증

AI 에이전트와 함께 개선 전후를 측정합니다.

```
최적화 전후 빌드를 비교해줘. 번들 크기, Lighthouse 점수,
Core Web Vitals 지표를 측정하고 개선 결과를 표로 정리해줘.
```

```bash
# 빌드 후 크기 분석
npm run build && du -sh dist/assets/*.js | sort -h

# Lighthouse CI 실행
npx lhci autorun --upload.target=temporary-public-storage

# 번들 상세 분석
npx source-map-explorer dist/assets/*.js
```

**검증 체크리스트:**

- [ ] 초기 번들 크기 200KB 이하 (gzip)
- [ ] 라우트별 청크 분리 확인 (개발자 도구 Network 탭)
- [ ] 레이지 로딩 컴포넌트 동적 로드 확인
- [ ] LCP(Largest Contentful Paint) 2.5초 이하
- [ ] FCP(First Contentful Paint) 1.8초 이하
- [ ] 트리 셰이킹 후 미사용 코드 0% 목표

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| Suspense 없이 lazy 사용 | 반드시 `<Suspense fallback={...}>` 감싸기 |
| CommonJS 모듈 트리 셰이킹 실패 | ESM으로 마이그레이션 또는 `sideEffects: false` 설정 |
| 너무 많은 청크 분리 | HTTP/2 환경에서는 100개 이하 청크 유지 |
| SSR에서 dynamic import 오류 | `ssr: false` 옵션 또는 클라이언트 전용 처리 |
| 프리로드 없는 레이지 로딩 | 중요 경로는 `<link rel="preload">` 추가 |

---

## 다음 단계

- [플레이북 65: 프론트엔드 성능 최적화](./65-frontend-performance-optimization.md) — Core Web Vitals 종합 전략
- [플레이북 62: 데이터베이스 쿼리 최적화](./62-database-query-optimization.md) — 백엔드 성능 최적화
- [플레이북 34: AI 코드 생성 검증 루프](./34-ai-code-generation-validation.md) — 최적화 결과 자동 검증

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
