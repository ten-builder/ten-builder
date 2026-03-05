# EP05: 에이전트 팀즈 with tmux — 5개 AI가 동시에 코딩하는 법

> tmux로 Claude Code 에이전트 5명을 동시에 돌려서 SaaS 대시보드를 15분 만에 완성하는 실전 워크플로우

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- tmux 세션으로 에이전트 팀을 구성하는 방법
- 역할별 프롬프트 분리 전략 (파일 충돌 방지)
- 5개 에이전트 동시 실행 → 하나의 프로젝트 완성
- 실전 프롬프트 전문 + 실행 스크립트

## 왜 에이전트 팀즈인가?

혼자서 순차적으로 코딩하면 각 파트를 하나씩 작업해야 해요. 하지만 tmux + Claude Code 조합을 쓰면 **5개 터미널 세션에서 동시에** 작업이 진행돼요.

핵심은 **파일 경계를 명확하게 나누는 것**이에요. 각 에이전트가 담당하는 파일을 겹치지 않게 지정하면, 동시 실행해도 충돌이 없어요.

## 팀 구성

| 에이전트 | 역할 | 담당 파일 |
|----------|------|-----------|
| Agent 1 | Frontend Architect | `layout.tsx`, `page.tsx`, `Sidebar.tsx`, `TopBar.tsx` |
| Agent 2 | Component Engineer | `KPICard.tsx`, `AreaChart.tsx`, `BarChart.tsx`, `DataTable.tsx` |
| Agent 3 | Page Builder | `AnalyticsPage.tsx`, `SettingsPage.tsx`, `HelpPage.tsx` |
| Agent 4 | Data Engineer | `mock-data.ts` |
| Agent 5 | UX Designer | `globals.css` |

## 시작하기

### 1. 프로젝트 초기화

```bash
npx create-next-app@latest saas-dashboard --typescript --tailwind --app
cd saas-dashboard
npm install recharts
```

### 2. tmux 세션 생성

```bash
# 세션 생성 + 5개 패널로 분할
tmux new-session -d -s agents

# 패널 4개 추가 (총 5개)
tmux split-window -h -t agents
tmux split-window -v -t agents:0.0
tmux split-window -v -t agents:0.1
tmux select-layout -t agents tiled
tmux split-window -v -t agents

# 타일 레이아웃으로 정렬
tmux select-layout -t agents tiled
tmux attach -t agents
```

### 3. 각 패널에서 에이전트 실행

```bash
# 패널 1: Frontend Architect
cat prompts/1-layout.md | claude --print

# 패널 2: Component Engineer
cat prompts/2-components.md | claude --print

# 패널 3: Page Builder
cat prompts/3-pages.md | claude --print

# 패널 4: Data Engineer
cat prompts/4-data.md | claude --print

# 패널 5: UX Designer
cat prompts/5-styles.md | claude --print
```

> 💡 `--print`는 대화 모드 없이 바로 실행하는 옵션이에요.

### 4. 원커맨드 실행 스크립트

매번 수동으로 5개를 실행하기 번거로우면 스크립트로 자동화할 수 있어요:

```bash
#!/bin/bash
# run-agents.sh

SESSION="agents"
PROMPTS_DIR="./prompts"

tmux new-session -d -s $SESSION

for i in 1 2 3 4; do
  tmux split-window -t $SESSION
done

tmux select-layout -t $SESSION tiled

for i in 1 2 3 4 5; do
  tmux send-keys -t $SESSION:0.$((i-1)) \
    "cat $PROMPTS_DIR/$i-*.md | claude --print" Enter
done

tmux attach -t $SESSION
```

```bash
chmod +x run-agents.sh
./run-agents.sh
```

## 프롬프트 설계 핵심

### 파일 경계 명시

프롬프트 첫 부분에 **"이 파일만 만들어라"**를 명확히 선언하는 게 중요해요:

```markdown
## Your files (create ONLY these — do not touch any other files):

### src/components/KPICard.tsx
### src/components/AreaChart.tsx
```

이렇게 하면 다른 에이전트의 파일을 건드리지 않아요.

### 역할 부여

각 프롬프트 첫 줄에 역할을 지정해요:

```markdown
You are a Frontend Architect.
You are a Component Engineer.
You are a Data Engineer.
```

역할을 주면 해당 분야에 집중한 결과물이 나와요.

### 공통 규칙 통일

모든 프롬프트에 동일한 기술 스택을 명시해요:

```markdown
## Tech stack: Next.js 15 + React 19 + Tailwind CSS 4
```

## 프롬프트 전문

5개 프롬프트는 [`prompts/`](../ep5-agent-teams-with-tmux/prompts/) 폴더에서 확인하세요:

| 파일 | 역할 |
|------|------|
| [`1-layout.md`](../ep5-agent-teams-with-tmux/prompts/1-layout.md) | 루트 레이아웃 + 네비게이션 |
| [`2-components.md`](../ep5-agent-teams-with-tmux/prompts/2-components.md) | 재사용 UI 컴포넌트 |
| [`3-pages.md`](../ep5-agent-teams-with-tmux/prompts/3-pages.md) | 서브 페이지 |
| [`4-data.md`](../ep5-agent-teams-with-tmux/prompts/4-data.md) | 데이터 레이어 |
| [`5-styles.md`](../ep5-agent-teams-with-tmux/prompts/5-styles.md) | 디자인 시스템 CSS |

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| 에이전트끼리 같은 파일 수정 | 프롬프트에 `ONLY these` 명시 |
| import 경로 불일치 | 공통 디렉토리 구조를 모든 프롬프트에 포함 |
| 스타일 충돌 | CSS는 한 에이전트만 담당 |
| 타입 에러 | 공유 타입은 별도 `types.ts`로 분리 |
| tmux 패널 구분 어려움 | `tmux select-pane -T "Agent1"` 으로 이름 지정 |

## 결과물

5개 에이전트가 동시에 작업하면 약 2~3분 만에 전체 SaaS 대시보드 코드가 생성돼요:

```
src/
├── app/
│   ├── layout.tsx          ← Agent 1
│   ├── page.tsx            ← Agent 1
│   └── globals.css         ← Agent 5
├── components/
│   ├── Sidebar.tsx         ← Agent 1
│   ├── TopBar.tsx          ← Agent 1
│   ├── KPICard.tsx         ← Agent 2
│   ├── AreaChart.tsx       ← Agent 2
│   ├── BarChart.tsx        ← Agent 2
│   ├── DataTable.tsx       ← Agent 2
│   └── pages/
│       ├── AnalyticsPage.tsx  ← Agent 3
│       ├── SettingsPage.tsx   ← Agent 3
│       └── HelpPage.tsx       ← Agent 3
└── lib/
    └── mock-data.ts        ← Agent 4
```

## 더 알아보기

- [Claude Code Agent Teams 공식 문서](https://code.claude.com/docs/en/agent-teams)
- [에이전트 팀 프롬프트 템플릿](../../templates/agent-team-example/)
- [EP02: 에이전트 팀즈 기초](../EP02-agent-teams/README.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
