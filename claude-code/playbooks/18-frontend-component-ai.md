# 플레이북 18: AI 프론트엔드 컴포넌트 생성

> React/Vue 컴포넌트를 체계적으로 생성하고 스토리북으로 검증하는 6단계 워크플로우

## 언제 쓰나요?

- 디자인 시스템을 새로 구축하거나 확장할 때
- 컴포넌트를 빠르게 만들되, 일관된 품질을 유지하고 싶을 때
- 스토리북 문서화까지 한 번에 끝내고 싶을 때
- 기존 컴포넌트를 다른 프레임워크로 변환해야 할 때

## 소요 시간

15-30분 (컴포넌트 1개 기준)

## 사전 준비

- AI 코딩 에이전트 (Claude Code, Cursor 등)
- React 또는 Vue 프로젝트 (TypeScript 권장)
- Storybook 설치 (`npx storybook@latest init`)
- 디자인 토큰 또는 스타일 가이드 (있으면 좋음)

## Step 1: 컴포넌트 스펙 정의하기

코드를 바로 생성하기 전에 **컴포넌트 인터페이스를 먼저 설계**합니다. AI에게 "버튼 만들어줘"보다 "이 스펙에 맞는 버튼을 만들어줘"가 훨씬 좋은 결과를 줘요.

```typescript
// 컴포넌트 스펙 예시 — AI에게 전달할 인터페이스
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'ghost' | 'danger';
  size: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
  disabled?: boolean;
  loading?: boolean;
  icon?: React.ReactNode;
  onClick?: () => void;
}
```

| 정의 항목 | 작성 예시 | 이유 |
|----------|----------|------|
| Props 인터페이스 | 위 TypeScript 코드 | 타입이 명확하면 AI가 엣지케이스를 빠뜨리지 않음 |
| 상태 목록 | default, hover, focus, disabled, loading | 시각적 상태마다 스타일 필요 |
| 접근성 요구사항 | aria-label, 키보드 네비게이션 | 처음부터 반영해야 나중에 고치지 않음 |
| 반응형 동작 | 모바일에서 full-width | 미리 정의하면 미디어 쿼리 누락 방지 |

> **팁:** CLAUDE.md나 프로젝트 루트에 `component-spec.md`를 만들어두면 AI가 세션 내내 참조합니다.

## Step 2: 기존 디자인 토큰 수집하기

프로젝트에 이미 있는 색상, 간격, 폰트 정보를 AI에게 알려주세요. 없으면 Tailwind 기본값이나 shadcn/ui 토큰을 기반으로 시작하는 게 효율적이에요.

```bash
# 프로젝트의 기존 디자인 토큰 확인
cat src/styles/tokens.css     # CSS 변수
cat tailwind.config.ts        # Tailwind 커스텀 테마
cat src/theme/index.ts        # Theme 객체

# AI에게 컨텍스트 전달
claude "이 프로젝트의 디자인 토큰을 분석하고,
새 Button 컴포넌트에 적용할 색상/간격/폰트 매핑을 제안해줘"
```

| 토큰 유형 | 확인 위치 | 예시 |
|----------|----------|------|
| 색상 | `tokens.css`, `tailwind.config` | `--primary: #2563eb` |
| 간격 | `tailwind.config.theme.spacing` | `sm: 0.5rem, md: 1rem` |
| 폰트 | `globals.css`, `_app.tsx` | `Inter, system-ui` |
| 테두리 | `tokens.css` | `--radius: 0.375rem` |

> 디자인 토큰이 아예 없으면 → "shadcn/ui 스타일 기반으로 Button을 만들어줘"라고 하는 것도 좋은 출발점입니다.

## Step 3: 컴포넌트 코드 생성하기

스펙과 토큰을 AI에게 전달하고 컴포넌트를 생성합니다. 핵심은 **한 번에 완벽한 코드를 기대하지 않는 것**이에요. 1차 생성 → 리뷰 → 수정 사이클이 효과적입니다.

```bash
# 프롬프트 예시 (구체적일수록 좋음)
claude "src/components/ui/Button.tsx를 만들어줘.

요구사항:
1. ButtonProps 인터페이스 (variant, size, disabled, loading, icon)
2. Tailwind CSS로 스타일링
3. forwardRef 적용
4. loading 상태에서 Spinner 표시 + 클릭 비활성화
5. 키보드 접근성 (Enter/Space로 클릭)
6. className을 외부에서 확장할 수 있도록 cn() 유틸 사용"
```

**검수 체크리스트:**

- [ ] Props 타입이 스펙과 일치하는지
- [ ] 모든 variant/size 조합이 스타일링되어 있는지
- [ ] `forwardRef`가 올바르게 적용되었는지
- [ ] 불필요한 리렌더링을 유발하는 패턴이 없는지
- [ ] `aria-*` 속성이 적절히 적용되었는지

## Step 4: 스토리북 스토리 생성하기

컴포넌트를 만들었으면 스토리북 스토리를 바로 생성합니다. 스토리는 **시각적 테스트이자 문서**에요.

```bash
# 스토리 자동 생성
claude "Button.tsx의 Storybook 스토리를 만들어줘.

포함할 스토리:
1. Default — 기본 상태
2. Variants — primary, secondary, ghost, danger 모두 표시
3. Sizes — sm, md, lg 비교
4. WithIcon — 아이콘 포함 버전
5. Loading — 로딩 상태
6. Disabled — 비활성 상태
7. Playground — 모든 props를 Controls로 조작 가능

CSF3 포맷 사용, autodocs 태그 포함"
```

```typescript
// 생성되는 스토리 구조 예시
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';

const meta: Meta<typeof Button> = {
  title: 'UI/Button',
  component: Button,
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary', 'ghost', 'danger'],
    },
    size: {
      control: 'select',
      options: ['sm', 'md', 'lg'],
    },
  },
};

export default meta;
type Story = StoryObj<typeof Button>;

export const Default: Story = {
  args: { children: 'Button', variant: 'primary', size: 'md' },
};

export const AllVariants: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: '1rem' }}>
      <Button variant="primary">Primary</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="ghost">Ghost</Button>
      <Button variant="danger">Danger</Button>
    </div>
  ),
};
```

## Step 5: 시각 테스트 + 접근성 검증

스토리북을 실행해서 눈으로 확인하고, 자동화 테스트도 추가합니다.

```bash
# 스토리북 실행
npm run storybook

# 접근성 검사 (a11y 애드온)
# storybook.js.org/addons/@storybook/addon-a11y
npx storybook@latest add @storybook/addon-a11y
```

**시각 테스트 확인 항목:**

| 항목 | 체크 방법 |
|------|----------|
| 다크 모드 대응 | Storybook 테마 토글로 전환 |
| 반응형 레이아웃 | Viewport 애드온으로 모바일/태블릿 확인 |
| 상태 전환 | Controls에서 disabled, loading 토글 |
| 접근성 위반 | A11y 패널에서 Violations 0개 확인 |

```bash
# AI에게 테스트 코드도 함께 생성
claude "Button 컴포넌트의 테스트를 작성해줘.

테스트 항목:
1. 각 variant가 올바른 className을 갖는지
2. disabled일 때 onClick이 호출되지 않는지
3. loading일 때 spinner가 렌더링되는지
4. forwardRef가 DOM 요소를 올바르게 참조하는지
5. 키보드 이벤트(Enter, Space)가 onClick을 트리거하는지

React Testing Library + Vitest 사용"
```

## Step 6: 컴포넌트 추출 패턴 — 복제가 아닌 구성

한 컴포넌트가 잘 동작하면, 이 패턴을 확장해서 관련 컴포넌트를 빠르게 만들 수 있어요.

```bash
# 패턴 기반 확장
claude "Button과 같은 디자인 토큰과 variant 시스템을 사용해서
IconButton, ButtonGroup, ToggleButton 컴포넌트를 만들어줘.

규칙:
- Button의 variant/size 시스템 재사용
- 공통 스타일은 buttonVariants로 추출
- 각 컴포넌트마다 Storybook 스토리 포함"
```

**컴포넌트 확장 전략:**

| 패턴 | 설명 | 예시 |
|------|------|------|
| Composition | 기존 컴포넌트를 조합 | `ButtonGroup` = `Button` × N |
| Variation | 같은 베이스에 변형 추가 | `IconButton` = `Button` + icon only |
| Specialization | 특정 용도에 맞게 래핑 | `SubmitButton` = `Button` + form submit |

## 실전 워크플로우 요약

```
스펙 정의 → 토큰 수집 → 컴포넌트 생성 → 스토리 작성 → 테스트 → 확장
   (5분)      (3분)        (7분)         (5분)      (5분)    (5분)
```

## 체크리스트

- [ ] 컴포넌트 인터페이스(Props)를 먼저 정의했는가
- [ ] 기존 디자인 토큰을 반영했는가
- [ ] TypeScript 타입이 정확한가
- [ ] 스토리북 스토리가 모든 상태를 커버하는가
- [ ] 접근성(a11y) 위반 사항이 없는가
- [ ] 테스트가 핵심 동작을 검증하는가
- [ ] `forwardRef`와 `className` 확장이 가능한가

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| Props를 정의하지 않고 바로 생성 요청 | 인터페이스를 먼저 작성 → AI가 엣지케이스를 놓치지 않음 |
| 디자인 토큰 없이 하드코딩된 색상 사용 | 프로젝트의 토큰 파일을 AI에게 먼저 공유 |
| 스토리에 happy path만 작성 | 에러, 로딩, 빈 상태, 긴 텍스트 등 엣지 스토리 추가 |
| 접근성을 나중에 추가 | 1차 생성 프롬프트에 aria, 키보드 내비게이션 포함 |
| 컴포넌트마다 스타일 시스템이 다름 | `cva()`나 공통 variant 함수로 통일 |

## Storybook MCP 연동 (선택)

Storybook MCP 서버를 설정하면 AI가 기존 컴포넌트 라이브러리를 직접 탐색하고, 일관된 패턴으로 새 컴포넌트를 생성할 수 있어요.

```json
{
  "mcpServers": {
    "storybook": {
      "command": "npx",
      "args": ["@anthropic-ai/storybook-mcp@latest"],
      "env": {
        "STORYBOOK_URL": "http://localhost:6006"
      }
    }
  }
}
```

| MCP 기능 | 용도 |
|---------|------|
| 컴포넌트 목록 조회 | 기존 디자인 시스템 파악 |
| 스토리 탐색 | 기존 패턴/variant 확인 |
| 스크린샷 비교 | 생성 결과 시각 검증 |

## 다음 단계

→ [플레이북 17: AI 프로토타이핑](./17-rapid-prototyping.md)
→ [플레이북 13: CLAUDE.md 최적화](./13-claudemd-optimization.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
