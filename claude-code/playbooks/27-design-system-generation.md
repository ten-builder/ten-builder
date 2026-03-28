# 플레이북 27: AI로 디자인 시스템 생성하기

> 디자인 토큰부터 컴포넌트 라이브러리까지 — AI 코딩 에이전트로 일관된 디자인 시스템을 빠르게 구축하는 방법

## 소요 시간

30-45분

## 사전 준비

- AI 코딩 도구 (Claude Code, Cursor 등) 설치 완료
- Node.js 18+ 환경
- 기존 프로젝트 또는 새 React/Vue 프로젝트
- (선택) Figma 디자인 파일 또는 브랜드 가이드

## Step 1: 디자인 토큰 정의

디자인 시스템의 기초는 **토큰(token)**이에요. 색상, 타이포그래피, 간격, 그림자 등 모든 스타일 값을 변수로 관리하면 AI가 생성하는 컴포넌트의 일관성이 올라가요.

```json
{
  "color": {
    "primary": { "50": "#eff6ff", "500": "#3b82f6", "900": "#1e3a5f" },
    "neutral": { "50": "#f9fafb", "500": "#6b7280", "900": "#111827" },
    "success": "#22c55e",
    "warning": "#f59e0b",
    "error": "#ef4444"
  },
  "spacing": {
    "xs": "0.25rem",
    "sm": "0.5rem",
    "md": "1rem",
    "lg": "1.5rem",
    "xl": "2rem"
  },
  "typography": {
    "fontFamily": {
      "sans": "Inter, system-ui, sans-serif",
      "mono": "JetBrains Mono, monospace"
    },
    "fontSize": {
      "xs": "0.75rem",
      "sm": "0.875rem",
      "base": "1rem",
      "lg": "1.125rem",
      "xl": "1.25rem",
      "2xl": "1.5rem"
    }
  },
  "borderRadius": {
    "sm": "0.25rem",
    "md": "0.375rem",
    "lg": "0.5rem",
    "full": "9999px"
  }
}
```

이 JSON을 CSS 변수로 변환하는 프롬프트:

```
이 디자인 토큰 JSON을 CSS custom properties로 변환해줘.
:root에 --color-primary-500 같은 형식으로 선언하고,
다크 모드용 [data-theme="dark"]도 포함해줘.
```

### CSS 변수 출력 예시

```css
:root {
  --color-primary-50: #eff6ff;
  --color-primary-500: #3b82f6;
  --color-primary-900: #1e3a5f;
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --font-sans: Inter, system-ui, sans-serif;
  --radius-md: 0.375rem;
}

[data-theme="dark"] {
  --color-primary-50: #1e3a5f;
  --color-primary-500: #60a5fa;
  --color-primary-900: #eff6ff;
  --color-neutral-50: #111827;
  --color-neutral-900: #f9fafb;
}
```

## Step 2: 기본 컴포넌트 스캐폴딩

토큰이 정해졌으면 핵심 컴포넌트를 AI로 생성해요. 한 번에 전부 만들려 하지 말고, 카테고리별로 나눠서 요청하는 게 품질이 좋아요.

| 카테고리 | 컴포넌트 예시 |
|----------|-------------|
| 기본 | Button, Input, Badge, Avatar |
| 피드백 | Alert, Toast, Skeleton, Spinner |
| 레이아웃 | Card, Stack, Grid, Divider |
| 네비게이션 | Tabs, Breadcrumb, Pagination |
| 데이터 | Table, Tag, Chip, Tooltip |

### 프롬프트 패턴: 컴포넌트 생성

```
Button 컴포넌트를 만들어줘.

요구사항:
- variant: primary, secondary, outline, ghost
- size: sm, md, lg
- 디자인 토큰(CSS 변수) 사용
- disabled, loading 상태 지원
- TypeScript props 타입 정의
- 접근성: aria-label, role 포함

파일 구조:
- components/Button/Button.tsx
- components/Button/Button.styles.ts
- components/Button/Button.types.ts
- components/Button/index.ts
```

### 컴포넌트 코드 예시

```tsx
// components/Button/Button.tsx
import { ButtonProps } from './Button.types';
import { buttonStyles } from './Button.styles';

export function Button({
  variant = 'primary',
  size = 'md',
  disabled = false,
  loading = false,
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      className={buttonStyles({ variant, size })}
      disabled={disabled || loading}
      aria-busy={loading}
      {...props}
    >
      {loading && <Spinner size="sm" />}
      {children}
    </button>
  );
}
```

## Step 3: 토큰-컴포넌트 연결 검증

생성된 컴포넌트가 실제로 디자인 토큰을 사용하는지 확인하는 단계에요. 하드코딩된 색상 값이 들어가면 시스템의 의미가 없어져요.

```bash
# 하드코딩된 색상값 탐지
grep -rn '#[0-9a-fA-F]\{3,8\}' src/components/ \
  --include='*.tsx' --include='*.ts' --include='*.css' \
  | grep -v 'node_modules' \
  | grep -v '*.test.*'
```

AI에게 검증을 맡기는 프롬프트:

```
src/components/ 폴더의 모든 컴포넌트를 확인해서
디자인 토큰(CSS 변수) 대신 하드코딩된 색상, 간격, 폰트 값이 있는지 찾아줘.
발견하면 해당 디자인 토큰으로 교체해줘.
```

| 검증 항목 | 확인 방법 |
|----------|----------|
| 색상 하드코딩 | `#hex`, `rgb()` 직접 사용 여부 |
| 간격 하드코딩 | `px`, `rem` 고정값 직접 사용 여부 |
| 폰트 하드코딩 | font-family 직접 선언 여부 |
| 다크 모드 | CSS 변수 기반이면 자동 대응 |

## Step 4: Storybook 문서화

컴포넌트를 만들었으면 Storybook으로 카탈로그를 구성해요. AI가 스토리 파일을 자동으로 생성하게 할 수 있어요.

```bash
# Storybook 설치
npx storybook@latest init
```

### 스토리 생성 프롬프트

```
Button 컴포넌트의 Storybook 스토리를 만들어줘.

포함할 스토리:
- Default: 기본 상태
- Variants: primary, secondary, outline, ghost
- Sizes: sm, md, lg
- States: disabled, loading
- WithIcon: 아이콘 포함

Controls 패널에서 모든 props를 조절할 수 있게 해줘.
```

```tsx
// components/Button/Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';

const meta: Meta<typeof Button> = {
  title: 'Components/Button',
  component: Button,
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary', 'outline', 'ghost'],
    },
    size: {
      control: 'select',
      options: ['sm', 'md', 'lg'],
    },
  },
};

export default meta;
type Story = StoryObj<typeof Button>;

export const Primary: Story = {
  args: { variant: 'primary', children: 'Button' },
};

export const AllVariants: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: '1rem' }}>
      <Button variant="primary">Primary</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="outline">Outline</Button>
      <Button variant="ghost">Ghost</Button>
    </div>
  ),
};
```

## Step 5: 테마 확장과 다크 모드

디자인 토큰 기반이면 테마 전환은 CSS 변수만 교체하면 돼요.

```tsx
// hooks/useTheme.ts
export function useTheme() {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');

  const toggle = () => {
    const next = theme === 'light' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', next);
    setTheme(next);
  };

  return { theme, toggle };
}
```

### 새 테마 추가 프롬프트

```
기존 디자인 토큰을 기반으로 "brand-blue" 테마를 추가해줘.
primary 색상 계열을 파란색에서 남색(indigo)으로 교체하고,
[data-theme="brand-blue"] 선택자로 CSS 변수를 오버라이드해줘.
```

| 테마 | primary-500 | 용도 |
|------|------------|------|
| light | `#3b82f6` | 기본 |
| dark | `#60a5fa` | 다크 모드 |
| brand-blue | `#6366f1` | 브랜드 변형 |

## Step 6: CI에 디자인 시스템 검증 통합

디자인 시스템이 깨지지 않도록 CI 파이프라인에 검증을 추가해요.

```yaml
# .github/workflows/design-system.yml
name: Design System Check
on: [pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: npm ci

      - name: Token consistency check
        run: |
          # 하드코딩된 색상값 탐지
          HARDCODED=$(grep -rn '#[0-9a-fA-F]\{6\}' src/components/ --include='*.tsx' | wc -l)
          if [ "$HARDCODED" -gt 0 ]; then
            echo "Found $HARDCODED hardcoded color values"
            exit 1
          fi

      - name: Storybook build
        run: npx storybook build

      - name: Visual regression test
        run: npx chromatic --project-token=${{ secrets.CHROMATIC_TOKEN }}
```

## 체크리스트

- [ ] 디자인 토큰 JSON 정의 완료
- [ ] CSS 변수 생성 및 다크 모드 포함
- [ ] 핵심 컴포넌트 5개 이상 생성
- [ ] 하드코딩된 스타일 값 없음 확인
- [ ] Storybook 스토리 작성 완료
- [ ] 테마 전환 동작 확인
- [ ] CI 파이프라인에 검증 추가

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| 토큰 없이 컴포넌트부터 생성 | 토큰을 먼저 정의하고 컨텍스트에 포함 |
| 한 번에 모든 컴포넌트 생성 요청 | 카테고리별로 나눠서 3-4개씩 |
| Figma 스크린샷만 던지고 "이거 만들어줘" | 토큰 + 구조 설명을 함께 제공 |
| 다크 모드 나중에 추가 | 처음부터 CSS 변수 기반으로 설계 |
| 컴포넌트 스타일 직접 수정 | 토큰 값을 변경하면 전체 반영 |

## 다음 단계

→ [AI 프론트엔드 컴포넌트 생성 플레이북](18-frontend-component-ai.md)
→ [AI E2E 테스트 자동화 플레이북](21-e2e-testing-ai.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
