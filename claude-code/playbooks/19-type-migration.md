# 플레이북 19: AI 타입 마이그레이션

> 레거시 JavaScript 코드에 타입을 점진적으로 추가해서 코드 품질과 AI 도구 호환성을 동시에 높이는 단계별 가이드

## 언제 쓰나요?

- JavaScript 프로젝트를 TypeScript로 전환하고 싶지만 한 번에 바꿀 엄두가 안 날 때
- Python 코드베이스에 타입 힌트를 추가하고 싶을 때
- AI 코딩 도구의 자동완성과 에러 감지 정확도를 높이고 싶을 때
- 팀이 타입을 도입하기로 했는데 기존 코드가 너무 많을 때

## 소요 시간

30-60분 (첫 모듈 기준)

## 사전 준비

- AI 코딩 도구 (Claude Code, Cursor 등)
- JavaScript 또는 untyped Python 프로젝트
- 기존 테스트 스위트 (있으면 좋음)
- Git 브랜치 전략 (rollback 대비)

## Step 1: 현재 상태 파악하기

타입 마이그레이션의 첫 단계는 코드베이스의 규모와 의존 관계를 정확히 파악하는 것입니다.

```bash
# JavaScript → TypeScript 마이그레이션 대상 파악
find src/ -name "*.js" -o -name "*.jsx" | wc -l
find src/ -name "*.ts" -o -name "*.tsx" | wc -l

# 파일별 라인 수 확인 (큰 파일부터 정렬)
find src/ -name "*.js" | xargs wc -l | sort -rn | head -20

# 의존 그래프 확인 (madge 사용)
npx madge --circular src/
npx madge --image dependency-graph.svg src/
```

AI에게 분석을 맡길 때는 구체적으로 요청하세요:

```
이 프로젝트의 src/ 디렉토리를 분석해서:
1. 파일 수와 총 라인 수
2. 순환 의존성이 있는 파일
3. 다른 파일에서 가장 많이 import되는 파일 (허브 모듈)
4. 외부 라이브러리 타입 지원 현황 (@types/* 패키지 존재 여부)
이 네 가지를 표로 정리해줘.
```

| 분석 항목 | 확인 이유 |
|----------|----------|
| 순환 의존성 | 타입 추가 시 순서 꼬임 방지 |
| 허브 모듈 | 먼저 타입 추가하면 효과 극대화 |
| 외부 라이브러리 | `@types/*` 없으면 직접 선언 필요 |
| 테스트 커버리지 | 타입 추가 후 검증 가능 여부 |

## Step 2: tsconfig 점진적 설정

한 번에 `strict: true`를 켜면 수백 개의 에러가 쏟아집니다. 단계별로 올리세요.

```json
// tsconfig.json — 1단계: 최소 설정
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowJs": true,
    "checkJs": false,
    "outDir": "./dist",
    "strict": false,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

```json
// tsconfig.json — 2단계: 점진적 강화
{
  "compilerOptions": {
    "strict": false,
    "noImplicitAny": true,
    "strictNullChecks": false
    // 나머지 동일
  }
}
```

```json
// tsconfig.json — 3단계: strict 모드
{
  "compilerOptions": {
    "strict": true
    // 나머지 동일
  }
}
```

AI에게 맡길 프롬프트:

```
현재 tsconfig.json을 확인하고,
allowJs: true + strict: false 상태에서 시작하는
점진적 마이그레이션용 tsconfig를 만들어줘.
기존 빌드가 깨지지 않게 해줘.
```

## Step 3: 리프 모듈부터 타입 추가

의존 관계에서 **리프 노드**(다른 파일에 의존하지 않는 파일)부터 변환합니다.

```
                  app.js        ← 마지막
                 /      \
           routes.js   middleware.js  ← 3번째
              |
          services.js     ← 2번째
          /         \
    utils.js     constants.js  ← 여기부터 시작
```

AI에게 변환을 맡기는 프롬프트:

```
src/utils/format.js 파일을 TypeScript로 변환해줘.
규칙:
1. 파일명을 .ts로 바꿔
2. 모든 함수 파라미터에 타입 추가
3. 리턴 타입 명시
4. any 사용 금지 — 정확한 타입을 추론해서 사용
5. 기존 export 방식 유지
6. JSDoc 주석이 있으면 타입으로 전환
```

### 변환 전/후 비교

```javascript
// 변환 전: utils/format.js
export function formatPrice(amount, currency) {
  const formatter = new Intl.NumberFormat('ko-KR', {
    style: 'currency',
    currency: currency || 'KRW'
  });
  return formatter.format(amount);
}

export function truncate(str, length) {
  if (!str) return '';
  return str.length > length
    ? str.slice(0, length) + '...'
    : str;
}
```

```typescript
// 변환 후: utils/format.ts
type CurrencyCode = 'KRW' | 'USD' | 'EUR' | 'JPY';

export function formatPrice(
  amount: number,
  currency: CurrencyCode = 'KRW'
): string {
  const formatter = new Intl.NumberFormat('ko-KR', {
    style: 'currency',
    currency,
  });
  return formatter.format(amount);
}

export function truncate(
  str: string | null | undefined,
  length: number
): string {
  if (!str) return '';
  return str.length > length
    ? str.slice(0, length) + '...'
    : str;
}
```

## Step 4: 인터페이스와 타입 중앙 관리

공유 타입은 `types/` 디렉토리에 모아서 관리합니다.

```typescript
// types/index.ts
export interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'user' | 'viewer';
  createdAt: Date;
}

export interface ApiResponse<T> {
  data: T;
  error: string | null;
  meta: {
    page: number;
    total: number;
  };
}

export type AsyncResult<T> = Promise<ApiResponse<T>>;
```

AI에게 타입 추출을 맡기는 프롬프트:

```
src/ 디렉토리의 모든 .ts 파일을 분석해서:
1. 2개 이상의 파일에서 사용되는 공통 타입을 찾아줘
2. types/index.ts 파일로 추출해줘
3. 기존 파일의 import를 types/index.ts로 변경해줘
4. 인라인 타입 리터럴은 named type으로 바꿔줘
```

## Step 5: Python 타입 힌트 추가

Python도 같은 점진적 접근이 가능합니다.

```python
# 변환 전
def process_order(order, discount=None):
    total = sum(item['price'] * item['qty'] for item in order['items'])
    if discount:
        total *= (1 - discount / 100)
    return {
        'order_id': order['id'],
        'total': round(total, 2),
        'status': 'completed'
    }
```

```python
# 변환 후
from dataclasses import dataclass
from typing import Optional

@dataclass
class OrderItem:
    price: float
    qty: int

@dataclass
class Order:
    id: str
    items: list[OrderItem]

@dataclass
class OrderResult:
    order_id: str
    total: float
    status: str

def process_order(
    order: Order,
    discount: Optional[float] = None
) -> OrderResult:
    total = sum(item.price * item.qty for item in order.items)
    if discount:
        total *= (1 - discount / 100)
    return OrderResult(
        order_id=order.id,
        total=round(total, 2),
        status='completed'
    )
```

AI에게 맡기는 프롬프트:

```
이 Python 파일에 타입 힌트를 추가해줘.
규칙:
1. dict 파라미터는 dataclass 또는 TypedDict로 변환
2. Optional은 명시적으로 표기
3. 리턴 타입 추가
4. mypy --strict 통과하도록
5. from __future__ import annotations 추가
```

## Step 6: CI에 타입 체크 통합

변환한 파일이 다시 untyped로 돌아가지 않도록 CI에서 검증합니다.

```yaml
# .github/workflows/typecheck.yml
name: Type Check

on: [push, pull_request]

jobs:
  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Install dependencies
        run: npm ci

      - name: TypeScript check
        run: npx tsc --noEmit

      # Python 프로젝트의 경우
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: mypy check
        run: |
          pip install mypy
          mypy src/ --ignore-missing-imports
```

### 점진적 CI 전략

처음부터 모든 파일에 타입 체크를 걸면 CI가 항상 실패합니다. 변환 완료된 파일만 체크하세요.

```json
// tsconfig.typecheck.json — 변환 완료된 파일만 포함
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "strict": true,
    "noEmit": true
  },
  "include": [
    "src/utils/**/*.ts",
    "src/types/**/*.ts",
    "src/models/**/*.ts"
  ]
}
```

```bash
# CI에서 변환 완료 파일만 strict 체크
npx tsc -p tsconfig.typecheck.json
```

## 체크리스트

- [ ] 코드베이스 규모와 의존 관계 분석 완료
- [ ] tsconfig.json 점진적 설정 (allowJs: true, strict: false)
- [ ] 리프 모듈부터 .ts 변환 시작
- [ ] 공통 타입을 types/ 디렉토리로 추출
- [ ] any 타입 사용 현황 추적 (0개 목표)
- [ ] CI에 타입 체크 추가 (변환 완료 파일만)
- [ ] 팀 가이드라인에 "새 파일은 반드시 .ts" 규칙 추가

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| 한 번에 전체를 변환하려 함 | 리프 모듈부터 하나씩, PR 단위로 진행 |
| `any`로 빠르게 에러만 없앰 | `unknown` + 타입 가드 패턴 사용 |
| @types/* 설치 누락 | `npx typesync`로 누락된 타입 패키지 자동 탐지 |
| 순환 의존성 파일부터 변환 | 먼저 순환 의존성 해소 후 변환 |
| JSDoc 주석을 그대로 유지 | TypeScript 타입으로 전환 후 중복 JSDoc 제거 |
| strict 모드 한 번에 활성화 | noImplicitAny → strictNullChecks → strict 순서 |

## 다음 단계

→ [플레이북 16: 대규모 리팩토링](16-large-scale-refactoring.md) — 타입 추가 후 구조 개선이 필요할 때

→ [플레이북 13: CLAUDE.md 최적화](13-claudemd-optimization.md) — "새 파일은 .ts 필수" 규칙을 CLAUDE.md에 추가

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
