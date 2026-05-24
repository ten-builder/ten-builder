# 플레이북 72: AI 에이전트 마이크로프론트엔드 아키텍처 플레이북

> 하나의 거대한 프론트엔드를 독립적으로 배포 가능한 작은 앱으로 쪼개기 — Module Federation 기반 실전 설계와 AI 에이전트 구현 전략

## 소요 시간

60-90분

## 사전 준비

- Node.js 20+ 설치
- Webpack 5 또는 Vite + Module Federation 플러그인
- Claude Code 또는 AI 코딩 에이전트
- 기존 프론트엔드 코드베이스 (또는 새 프로젝트)

---

## 마이크로프론트엔드가 필요한 시점

단일 프론트엔드 앱이 다음 상황에 도달하면 분리를 검토할 때입니다.

| 신호 | 기준 |
|------|------|
| 빌드 시간 | 5분 이상 |
| 팀 규모 | 프론트엔드 개발자 5명 이상 |
| 배포 빈도 | 하루 여러 팀이 독립적으로 배포해야 하는 경우 |
| 코드베이스 크기 | 컴포넌트 500개 이상 |

---

## Step 1: 도메인 경계 분석

AI 에이전트로 기존 코드베이스에서 자연스러운 분리 경계를 찾습니다.

### 1-1. CLAUDE.md에 분석 컨텍스트 추가

```markdown
## 마이크로프론트엔드 분석 컨텍스트

**목표:** 기존 프론트엔드를 Module Federation 기반으로 분리
**현재 스택:** Next.js / React / TypeScript
**팀 구조:** 제품팀(Product), 결제팀(Checkout), 공통팀(Platform)
**기준:** 팀 경계 = 마이크로프론트엔드 경계
```

### 1-2. AI 에이전트로 경계 분석

```bash
# Claude Code에 코드베이스 분석 요청
claude code "src/ 디렉토리를 분석해서 다음을 파악해줘:
1. 팀 소유권이 명확하게 분리될 수 있는 도메인 영역
2. 공유 컴포넌트 vs 도메인 특화 컴포넌트 구분
3. 순환 의존성이 없는 경계 제안
결과를 mfe-boundary-analysis.md 파일로 저장해줘"
```

### 1-3. 경계 분류 기준

```
Shell App (Host)
  ├── navigation, layout, auth, routing
  └── 공유 상태 (사용자 정보, 세션)

MFE: Product
  ├── 상품 목록, 상세, 검색
  └── 장바구니 추가

MFE: Checkout
  ├── 결제 플로우, 주소 입력
  └── 결제 처리

MFE: Platform
  └── 공유 UI 컴포넌트 라이브러리
```

---

## Step 2: Module Federation 설정

### 2-1. Shell App (Host) 설정

```javascript
// apps/shell/webpack.config.js
const { ModuleFederationPlugin } = require("@module-federation/enhanced");

module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: "shell",
      remotes: {
        // 런타임에 원격 앱을 동적으로 로드
        product: "product@http://localhost:3001/remoteEntry.js",
        checkout: "checkout@http://localhost:3002/remoteEntry.js",
      },
      shared: {
        react: { singleton: true, requiredVersion: "^18.0.0" },
        "react-dom": { singleton: true, requiredVersion: "^18.0.0" },
        // 공유 상태 라이브러리는 singleton 필수
        zustand: { singleton: true },
      },
    }),
  ],
};
```

### 2-2. Remote App (Product MFE) 설정

```javascript
// apps/product/webpack.config.js
const { ModuleFederationPlugin } = require("@module-federation/enhanced");

module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: "product",
      filename: "remoteEntry.js",
      exposes: {
        // 외부에 노출할 컴포넌트만 명시적으로 선언
        "./ProductList": "./src/components/ProductList",
        "./ProductDetail": "./src/components/ProductDetail",
      },
      shared: {
        react: { singleton: true, requiredVersion: "^18.0.0" },
        "react-dom": { singleton: true, requiredVersion: "^18.0.0" },
      },
    }),
  ],
};
```

### 2-3. AI 에이전트로 설정 자동 생성

```bash
claude code "현재 package.json과 src/ 구조를 분석해서
apps/product/webpack.config.js에 Module Federation 설정을 생성해줘.
- exposes: src/components/ 아래 주요 컴포넌트
- shared: 현재 package.json의 의존성 기반으로 singleton 대상 추출
- 다른 팀의 코드는 건드리지 않는 독립 배포 구조"
```

---

## Step 3: 공유 상태 설계

마이크로프론트엔드 간 상태를 공유할 때 직접 import 대신 이벤트나 공유 저장소를 사용합니다.

### 3-1. 글로벌 이벤트 버스

```typescript
// packages/platform/src/eventBus.ts
type EventMap = {
  "cart:updated": { itemCount: number };
  "user:authenticated": { userId: string; role: string };
  "checkout:completed": { orderId: string };
};

class EventBus {
  private listeners = new Map<string, Set<Function>>();

  emit<K extends keyof EventMap>(event: K, data: EventMap[K]) {
    this.listeners.get(event)?.forEach((fn) => fn(data));
  }

  on<K extends keyof EventMap>(event: K, handler: (data: EventMap[K]) => void) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(handler);
    return () => this.listeners.get(event)?.delete(handler);
  }
}

export const eventBus = new EventBus();
```

### 3-2. 공유 상태 패턴 비교

| 방법 | 적합한 상황 | 주의 사항 |
|------|-------------|-----------|
| 이벤트 버스 | MFE 간 느슨한 통신 | 이벤트 타입 중앙 관리 필수 |
| URL/QueryString | 페이지 이동 시 데이터 전달 | 민감한 데이터 제외 |
| 공유 Zustand Store | 동일 Shell 내 긴밀한 상태 | singleton 설정 필수 |
| 백엔드 API | 중요한 상태, 지속성 필요 | 지연 시간 고려 |

---

## Step 4: 독립 배포 파이프라인

### 4-1. 각 MFE별 CI/CD 설정

```yaml
# .github/workflows/product-mfe.yml
name: Deploy Product MFE

on:
  push:
    paths:
      - "apps/product/**"
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: cd apps/product && npm ci
      - name: Build
        run: cd apps/product && npm run build
      - name: Deploy to CDN
        run: |
          # remoteEntry.js를 CDN에 배포
          aws s3 sync apps/product/dist s3://mfe-product-bucket
          aws cloudfront create-invalidation --paths "/remoteEntry.js"
```

### 4-2. AI 에이전트로 파이프라인 생성

```bash
claude code "apps/product/의 빌드 설정을 분석해서
.github/workflows/product-deploy.yml 파일을 생성해줘.
- main 브랜치에 apps/product/** 변경 시 자동 배포
- npm ci → build → CDN 업로드 → CloudFront invalidation
- 배포 실패 시 Slack 알림 (#frontend-deploys 채널)"
```

---

## Step 5: 런타임 원격 URL 동적 관리

하드코딩된 URL 대신 런타임에 원격 주소를 주입합니다.

```typescript
// apps/shell/src/remoteConfig.ts
interface RemoteConfig {
  product: string;
  checkout: string;
}

async function loadRemoteConfig(): Promise<RemoteConfig> {
  // 환경별 설정 서버에서 원격 URL을 동적으로 로드
  const response = await fetch("/api/mfe-config");
  return response.json();
}

// Module Federation 동적 원격 로드
export async function loadRemoteModule(scope: string, module: string) {
  const config = await loadRemoteConfig();
  const url = config[scope as keyof RemoteConfig];

  // @ts-ignore
  await __webpack_init_sharing__("default");
  const container = await new Promise<any>((resolve) => {
    const script = document.createElement("script");
    script.src = url;
    script.onload = () => resolve((window as any)[scope]);
    document.head.appendChild(script);
  });

  await container.init(__webpack_share_scopes__.default);
  const factory = await container.get(module);
  return factory();
}
```

---

## Step 6: 타입 안전성 확보

```typescript
// packages/types/src/mfe-contracts.ts
// 각 MFE가 외부에 공개하는 컴포넌트의 타입 계약

export interface ProductListProps {
  categoryId?: string;
  onAddToCart: (productId: string, quantity: number) => void;
}

export interface CheckoutFormProps {
  cartItems: CartItem[];
  onComplete: (orderId: string) => void;
}

// Shell에서 타입 안전하게 사용
import type { ProductListProps } from "@mfe-platform/types";
const ProductList = React.lazy<React.FC<ProductListProps>>(
  () => import("product/ProductList")
);
```

---

## 체크리스트

- [ ] 도메인 경계 문서화 (`mfe-boundary.md`)
- [ ] 각 MFE별 독립 `package.json` + 빌드 스크립트
- [ ] `remoteEntry.js` CDN 배포 자동화
- [ ] 공유 의존성 `singleton: true` 설정
- [ ] 이벤트 버스 타입 중앙 관리
- [ ] MFE 타입 계약 패키지 (`@platform/types`)
- [ ] 각 MFE 독립 배포 파이프라인 검증
- [ ] 로컬 개발 환경에서 전체 통합 테스트

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| React 두 번 로드됨 | `singleton: true` + `requiredVersion` 필수 |
| MFE 간 직접 import | 이벤트 버스 또는 URL 파라미터 사용 |
| 모든 MFE 동시 배포 | 각 MFE 독립 CI/CD 파이프라인 분리 |
| 공유 상태 과도한 사용 | 필요한 최소한만 공유, 나머지는 로컬 상태 |

## 다음 단계

→ [플레이북 59: 마이크로서비스 설계](./59-microservices-decomposition-playbook.md)
→ [워크플로우: E2E 테스트 자동 생성](../../../workflows/ai-e2e-test-generation.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
