# Slack 봇 + AI 실전 예제

> AI 코딩 에이전트로 Slack 봇을 처음부터 만드는 단계별 가이드 — Bolt 프레임워크, 이벤트 구독, AI 응답 통합

## 이 예제에서 배울 수 있는 것

- Slack Bolt 프레임워크로 봇을 셋업하고 슬래시 커맨드를 등록하는 방법
- AI 코딩 에이전트에게 이벤트 핸들러를 요청하는 프롬프트 패턴
- LLM API를 연결해 봇이 자연어로 대화하게 만드는 구조
- Block Kit으로 풍부한 UI 메시지를 보내는 패턴
- 에러 핸들링, 레이트 리밋, 배포까지 한번에 잡는 워크플로우

## 프로젝트 구조

```
slack-bot-ai/
├── CLAUDE.md              # AI 에이전트 프로젝트 설정
├── src/
│   ├── app.ts             # Bolt 앱 엔트리포인트
│   ├── commands/
│   │   ├── ask.ts         # /ask AI 질문 커맨드
│   │   ├── summarize.ts   # /summarize 채널 요약
│   │   └── review.ts      # /review 코드 리뷰 요청
│   ├── events/
│   │   ├── app-mention.ts # @봇 멘션 핸들러
│   │   ├── message.ts     # DM 메시지 핸들러
│   │   └── app-home.ts    # 앱 홈탭 렌더링
│   ├── services/
│   │   ├── ai.ts          # AI API 래퍼
│   │   └── context.ts     # 대화 컨텍스트 관리
│   ├── blocks/
│   │   ├── home.ts        # 홈탭 Block Kit 레이아웃
│   │   └── response.ts    # AI 응답 포맷터
│   └── utils/
│       ├── config.ts      # 환경변수 관리
│       └── logger.ts      # 로깅 유틸
├── tests/
│   ├── commands.test.ts   # 커맨드 단위 테스트
│   └── ai-service.test.ts # AI 서비스 테스트
├── .env.example
├── package.json
├── tsconfig.json
└── Dockerfile
```

## 시작하기

### Step 1: 프로젝트 초기화

```bash
mkdir slack-bot-ai && cd slack-bot-ai
pnpm init
pnpm add @slack/bolt dotenv
pnpm add -D typescript @types/node tsx vitest
npx tsc --init
```

### Step 2: CLAUDE.md 작성

프로젝트 루트에 `CLAUDE.md`를 만들어 AI 에이전트에게 컨텍스트를 전달해요.

```markdown
# CLAUDE.md

## Project
- Slack 봇 (Bolt for JavaScript v4)
- TypeScript strict mode
- Node.js 20+

## Architecture
- commands/ — 슬래시 커맨드 (각 파일이 하나의 커맨드)
- events/ — Slack 이벤트 핸들러
- services/ — 외부 API 래퍼 (AI, DB 등)
- blocks/ — Block Kit 레이아웃 빌더
- utils/ — 공통 유틸리티

## Rules
- 모든 커맨드는 app.command()로 등록
- AI 응답은 반드시 say() 또는 respond()로 전송
- Block Kit 메시지는 blocks/ 디렉토리에서 빌드
- 에러 시 사용자에게 ephemeral 메시지로 안내
- 환경변수는 config.ts에서 한번에 검증
```

### Step 3: Slack App 설정

[Slack API 사이트](https://api.slack.com/apps)에서 새 앱을 만들어요.

**필요한 Bot Token Scopes:**

| Scope | 용도 |
|-------|------|
| `app_mentions:read` | @봇 멘션 감지 |
| `chat:write` | 메시지 전송 |
| `commands` | 슬래시 커맨드 |
| `im:history` | DM 대화 읽기 |
| `im:write` | DM 전송 |
| `channels:history` | 채널 히스토리 (요약용) |

**Event Subscriptions:**
- `app_mention` — 봇이 멘션되었을 때
- `message.im` — DM 수신
- `app_home_opened` — 홈 탭 열기

### Step 4: 환경변수

```bash
# .env.example
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_SIGNING_SECRET=your-signing-secret
SLACK_APP_TOKEN=xapp-your-app-token  # Socket Mode용
AI_API_KEY=your-ai-api-key
AI_MODEL=claude-sonnet-4-20250514
PORT=3000
```

## 핵심 코드

### 앱 엔트리포인트 (src/app.ts)

```typescript
import { App, LogLevel } from '@slack/bolt';
import { config } from './utils/config';
import { registerCommands } from './commands';
import { registerEvents } from './events';

const app = new App({
  token: config.SLACK_BOT_TOKEN,
  signingSecret: config.SLACK_SIGNING_SECRET,
  socketMode: true,
  appToken: config.SLACK_APP_TOKEN,
  logLevel: LogLevel.INFO,
});

// 커맨드와 이벤트 등록
registerCommands(app);
registerEvents(app);

(async () => {
  await app.start(config.PORT);
  console.log(`Slack bot running on port ${config.PORT}`);
})();
```

**왜 Socket Mode를 쓰나요?**

개발 환경에서 ngrok 없이 바로 테스트할 수 있어요. 프로덕션에서도 Socket Mode는 방화벽 뒤에서 동작해서 인프라 설정이 간단해요.

### /ask 커맨드 (src/commands/ask.ts)

```typescript
import type { App } from '@slack/bolt';
import { aiService } from '../services/ai';
import { buildResponseBlocks } from '../blocks/response';

export function registerAskCommand(app: App) {
  app.command('/ask', async ({ command, ack, respond }) => {
    await ack();

    if (!command.text.trim()) {
      await respond({
        response_type: 'ephemeral',
        text: '질문을 입력해주세요. 예: `/ask TypeScript에서 제네릭 쓰는 법`',
      });
      return;
    }

    // 사용자에게 처리 중 알림
    await respond({
      response_type: 'ephemeral',
      text: ':hourglass_flowing_sand: 답변을 준비하고 있어요...',
    });

    try {
      const answer = await aiService.ask(command.text, {
        userId: command.user_id,
        channelId: command.channel_id,
      });

      await respond({
        response_type: 'in_channel',
        blocks: buildResponseBlocks(command.text, answer),
      });
    } catch (error) {
      await respond({
        response_type: 'ephemeral',
        text: ':warning: 답변 생성 중 문제가 발생했어요. 잠시 후 다시 시도해주세요.',
      });
    }
  });
}
```

### AI 서비스 (src/services/ai.ts)

```typescript
import Anthropic from '@anthropic-ai/sdk';
import { config } from '../utils/config';

const client = new Anthropic({ apiKey: config.AI_API_KEY });

interface AskContext {
  userId: string;
  channelId: string;
}

const SYSTEM_PROMPT = `당신은 Slack 워크스페이스의 개발팀 AI 어시스턴트입니다.
- 기술 질문에 정확하고 실용적인 답변을 제공하세요
- 코드 예제를 포함할 때는 언어를 명시하세요
- 답변은 Slack markdown 형식으로 작성하세요
- 간결하지만 핵심을 놓치지 않게 답변하세요`;

export const aiService = {
  async ask(question: string, context: AskContext): Promise<string> {
    const message = await client.messages.create({
      model: config.AI_MODEL,
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: [{ role: 'user', content: question }],
    });

    const textBlock = message.content.find((b) => b.type === 'text');
    return textBlock?.text ?? '답변을 생성하지 못했어요.';
  },

  async summarize(messages: string[]): Promise<string> {
    const combined = messages.join('\n---\n');

    const message = await client.messages.create({
      model: config.AI_MODEL,
      max_tokens: 512,
      system: '채널 대화를 요약해주세요. 핵심 논의 사항, 결정된 사항, 후속 조치를 구분해서 정리하세요.',
      messages: [{ role: 'user', content: combined }],
    });

    const textBlock = message.content.find((b) => b.type === 'text');
    return textBlock?.text ?? '요약을 생성하지 못했어요.';
  },
};
```

### 대화 컨텍스트 관리 (src/services/context.ts)

```typescript
interface ConversationEntry {
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
}

// 메모리 기반 대화 컨텍스트 (프로덕션에선 Redis 추천)
const conversations = new Map<string, ConversationEntry[]>();

const MAX_HISTORY = 10;
const TTL_MS = 30 * 60 * 1000; // 30분

export const contextService = {
  add(threadId: string, entry: ConversationEntry) {
    const history = conversations.get(threadId) ?? [];
    history.push(entry);

    // 오래된 항목 정리
    const cutoff = Date.now() - TTL_MS;
    const filtered = history.filter((e) => e.timestamp > cutoff).slice(-MAX_HISTORY);

    conversations.set(threadId, filtered);
  },

  get(threadId: string): ConversationEntry[] {
    return conversations.get(threadId) ?? [];
  },

  clear(threadId: string) {
    conversations.delete(threadId);
  },
};
```

### @봇 멘션 핸들러 (src/events/app-mention.ts)

```typescript
import type { App } from '@slack/bolt';
import { aiService } from '../services/ai';
import { contextService } from '../services/context';

export function registerAppMention(app: App) {
  app.event('app_mention', async ({ event, say, client }) => {
    // 봇 멘션 태그 제거
    const question = event.text.replace(/<@[A-Z0-9]+>/g, '').trim();

    if (!question) {
      await say({
        text: '무엇을 도와드릴까요? 질문을 멘션과 함께 보내주세요.',
        thread_ts: event.thread_ts ?? event.ts,
      });
      return;
    }

    // 스레드 컨텍스트 로드
    const threadId = event.thread_ts ?? event.ts;
    const history = contextService.get(threadId);

    try {
      const answer = await aiService.ask(question, {
        userId: event.user,
        channelId: event.channel,
      });

      // 컨텍스트 저장
      contextService.add(threadId, {
        role: 'user',
        content: question,
        timestamp: Date.now(),
      });
      contextService.add(threadId, {
        role: 'assistant',
        content: answer,
        timestamp: Date.now(),
      });

      await say({
        text: answer,
        thread_ts: threadId,
      });
    } catch (error) {
      await say({
        text: ':warning: 답변 생성 중 문제가 발생했어요.',
        thread_ts: threadId,
      });
    }
  });
}
```

### Block Kit 응답 포맷터 (src/blocks/response.ts)

```typescript
import type { KnownBlock } from '@slack/bolt';

export function buildResponseBlocks(
  question: string,
  answer: string
): KnownBlock[] {
  return [
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `:speech_balloon: *질문:* ${question}`,
      },
    },
    { type: 'divider' },
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: answer,
      },
    },
    {
      type: 'context',
      elements: [
        {
          type: 'mrkdwn',
          text: ':robot_face: AI가 생성한 답변이에요. 정확하지 않을 수 있으니 참고용으로 사용해주세요.',
        },
      ],
    },
    {
      type: 'actions',
      elements: [
        {
          type: 'button',
          text: { type: 'plain_text', text: ':thumbsup: 유용해요' },
          action_id: 'feedback_positive',
          value: 'positive',
        },
        {
          type: 'button',
          text: { type: 'plain_text', text: ':thumbsdown: 아쉬워요' },
          action_id: 'feedback_negative',
          value: 'negative',
        },
      ],
    },
  ];
}
```

### 홈 탭 (src/events/app-home.ts)

```typescript
import type { App } from '@slack/bolt';

export function registerAppHome(app: App) {
  app.event('app_home_opened', async ({ event, client }) => {
    await client.views.publish({
      user_id: event.user,
      view: {
        type: 'home',
        blocks: [
          {
            type: 'header',
            text: { type: 'plain_text', text: ':wave: AI 어시스턴트' },
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: '채널에서 저를 멘션하거나, 슬래시 커맨드를 사용해보세요.',
            },
          },
          { type: 'divider' },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                '*사용 가능한 커맨드:*',
                '• `/ask [질문]` — AI에게 질문하기',
                '• `/summarize` — 최근 채널 대화 요약',
                '• `/review [PR URL]` — 코드 리뷰 요청',
              ].join('\n'),
            },
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: '*멘션 사용:*\n`@AI봇 TypeScript 제네릭 설명해줘` 처럼 자유롭게 질문하세요.',
            },
          },
        ],
      },
    });
  });
}
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 슬래시 커맨드 추가 | `새 슬래시 커맨드 /deploy 추가해줘. GitHub Actions 워크플로우를 트리거하는 기능이야` |
| Block Kit 메시지 디자인 | `이 응답을 Block Kit으로 바꿔줘. 코드 블록이랑 버튼 액션 포함해서` |
| 이벤트 핸들러 작성 | `reaction_added 이벤트 핸들러 만들어줘. 특정 이모지 달리면 채널에 알림 보내는 기능` |
| 미들웨어 추가 | `모든 커맨드에 레이트 리밋 미들웨어 추가해줘. 유저당 분당 10회 제한` |
| 테스트 작성 | `ask 커맨드 테스트 작성해줘. AI 서비스는 mock으로 처리` |
| 에러 핸들링 | `글로벌 에러 핸들러 추가해줘. 에러 타입별로 다른 사용자 메시지 보내게` |

## Slack 봇 vs Discord 봇 차이

| 항목 | Slack (Bolt) | Discord (discord.js) |
|------|-------------|---------------------|
| 커맨드 등록 | `app.command()` | `SlashCommandBuilder` |
| 이벤트 구독 | `app.event()` | `client.on()` |
| 메시지 전송 | `say()` / `respond()` | `interaction.reply()` |
| 리치 메시지 | Block Kit | Embed |
| 인증 | Bot Token + Signing Secret | Bot Token |
| 소켓 연결 | Socket Mode (옵션) | WebSocket (기본) |
| 실시간 연결 | Socket Mode / Events API | Gateway |

## 프로덕션 체크리스트

- [ ] `SLACK_BOT_TOKEN`, `SLACK_SIGNING_SECRET`, `SLACK_APP_TOKEN` 환경변수 설정
- [ ] Event Subscriptions URL 또는 Socket Mode 활성화
- [ ] 슬래시 커맨드 URL 등록 (HTTP 모드 시)
- [ ] 에러 알림 채널 설정 (봇 에러 → 운영 채널 전송)
- [ ] AI API 레이트 리밋 설정 (유저당 분당 N회)
- [ ] 대화 컨텍스트 TTL 설정 (메모리 누수 방지)
- [ ] Dockerfile 작성 및 컨테이너 배포
- [ ] 로깅 → CloudWatch / Datadog 연동
- [ ] 피드백 버튼 액션 핸들러 구현
- [ ] Slack App Directory 등록 (팀 외부 배포 시)

## 확장 아이디어

1. **코드 리뷰 봇** — PR URL 입력 시 diff 분석 후 리뷰 코멘트 생성
2. **스탠드업 봇** — 매일 아침 팀원에게 DM으로 스탠드업 질문, 답변 모아서 채널에 게시
3. **온콜 어시스턴트** — 장애 알림 수신 시 관련 로그/메트릭 자동 수집 후 요약
4. **문서 검색** — 사내 Notion/Confluence 연동, 질문에 맞는 문서 검색 후 답변

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
