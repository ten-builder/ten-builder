# Discord 봇 + AI 실전 예제

> AI 코딩 에이전트로 Discord 봇을 처음부터 만드는 단계별 가이드 — 슬래시 커맨드, 이벤트 핸들링, AI 응답 통합

## 이 예제에서 배울 수 있는 것

- discord.js v14로 봇을 셋업하고 슬래시 커맨드를 등록하는 방법
- AI 코딩 에이전트에게 커맨드 핸들러를 요청하는 프롬프트 패턴
- LLM API를 연결해 봇이 자연어로 대화하게 만드는 구조
- 에러 핸들링, 레이트 리밋, 배포까지 한번에 잡는 워크플로우

## 프로젝트 구조

```
discord-bot-ai/
├── CLAUDE.md              # AI 에이전트 프로젝트 설정
├── src/
│   ├── index.ts           # 봇 엔트리포인트
│   ├── deploy-commands.ts # 슬래시 커맨드 등록 스크립트
│   ├── commands/
│   │   ├── ping.ts        # /ping 커맨드
│   │   ├── ask.ts         # /ask AI 질문 커맨드
│   │   └── summarize.ts   # /summarize 채널 요약
│   ├── events/
│   │   ├── ready.ts       # 봇 준비 이벤트
│   │   ├── interactionCreate.ts  # 인터랙션 핸들러
│   │   └── messageCreate.ts      # 메시지 이벤트
│   ├── services/
│   │   └── ai.ts          # AI API 래퍼
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
mkdir discord-bot-ai && cd discord-bot-ai
pnpm init
pnpm add discord.js dotenv
pnpm add -D typescript @types/node tsx vitest
npx tsc --init
```

### Step 2: CLAUDE.md 작성

프로젝트 루트에 `CLAUDE.md`를 만들어 AI 에이전트에게 컨텍스트를 전달해요.

```markdown
# CLAUDE.md

## Project
- Discord 봇 (discord.js v14)
- TypeScript strict mode
- Node.js 20+

## Architecture
- commands/ — 슬래시 커맨드 (각 파일이 하나의 커맨드)
- events/ — Discord 이벤트 핸들러
- services/ — 외부 API 래퍼 (AI, DB 등)
- utils/ — 공통 유틸리티

## Rules
- 모든 커맨드는 SlashCommandBuilder로 정의
- 비동기 처리는 deferReply() 후 editReply() 패턴
- 에러 시 사용자에게 친절한 메시지 반환
- 환경변수는 config.ts에서 한번에 검증
```

### Step 3: Discord Developer Portal 설정

```bash
# 1. https://discord.com/developers/applications 에서 봇 생성
# 2. Bot 탭 → Reset Token → .env에 저장
# 3. OAuth2 → URL Generator → bot + applications.commands 체크
# 4. 생성된 URL로 서버에 봇 초대
```

`.env` 파일:

```env
DISCORD_TOKEN=your_bot_token_here
DISCORD_CLIENT_ID=your_client_id_here
DISCORD_GUILD_ID=your_test_server_id
AI_API_KEY=your_ai_api_key
AI_MODEL=claude-sonnet-4-20250514
```

## 핵심 코드

### 봇 엔트리포인트 (src/index.ts)

```typescript
import { Client, Collection, GatewayIntentBits } from "discord.js";
import { config } from "./utils/config";
import { loadCommands } from "./commands";
import { loadEvents } from "./events";

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

// 커맨드 컬렉션
client.commands = new Collection();

async function main() {
  await loadCommands(client);
  await loadEvents(client);
  await client.login(config.DISCORD_TOKEN);
}

main().catch(console.error);
```

**왜 이렇게 했나요?**

커맨드와 이벤트를 별도 파일로 분리하면 AI 에이전트에게 "새 커맨드 추가해줘"라고 요청할 때 다른 코드에 영향 없이 파일 하나만 생성하면 돼요.

### 슬래시 커맨드 예시 (src/commands/ask.ts)

```typescript
import {
  SlashCommandBuilder,
  ChatInputCommandInteraction,
} from "discord.js";
import { askAI } from "../services/ai";

export const data = new SlashCommandBuilder()
  .setName("ask")
  .setDescription("AI에게 질문합니다")
  .addStringOption((option) =>
    option
      .setName("question")
      .setDescription("질문 내용")
      .setRequired(true)
  );

export async function execute(
  interaction: ChatInputCommandInteraction
) {
  const question = interaction.options.getString("question", true);

  // 응답 대기 표시 (3초 이상 걸리는 작업)
  await interaction.deferReply();

  try {
    const answer = await askAI(question);

    // 2000자 제한 처리
    if (answer.length > 2000) {
      const chunks = answer.match(/.{1,1990}/gs) || [];
      await interaction.editReply(chunks[0]);
      for (const chunk of chunks.slice(1)) {
        await interaction.followUp(chunk);
      }
    } else {
      await interaction.editReply(answer);
    }
  } catch (error) {
    await interaction.editReply(
      "답변을 생성하지 못했어요. 잠시 후 다시 시도해 주세요."
    );
  }
}
```

**왜 이렇게 했나요?**

`deferReply()`는 Discord의 3초 응답 제한을 우회해요. AI API 호출은 보통 3초 이상 걸리기 때문에 먼저 "생각 중" 상태를 보여주고 결과가 나오면 `editReply()`로 업데이트하는 패턴이 필수예요.

### AI 서비스 래퍼 (src/services/ai.ts)

```typescript
import Anthropic from "@anthropic-ai/sdk";
import { config } from "../utils/config";

const client = new Anthropic({ apiKey: config.AI_API_KEY });

export async function askAI(question: string): Promise<string> {
  const response = await client.messages.create({
    model: config.AI_MODEL,
    max_tokens: 1024,
    messages: [{ role: "user", content: question }],
    system:
      "당신은 Discord 서버의 도움 봇입니다. " +
      "간결하고 친절하게 답변하세요. " +
      "코드 블록은 Discord 마크다운 형식을 사용하세요.",
  });

  const block = response.content[0];
  if (block.type === "text") return block.text;
  return "응답을 처리할 수 없습니다.";
}

export async function summarizeMessages(
  messages: string[]
): Promise<string> {
  const joined = messages.join("\n");

  const response = await client.messages.create({
    model: config.AI_MODEL,
    max_tokens: 512,
    messages: [
      {
        role: "user",
        content: `다음 Discord 채팅 내역을 3~5줄로 요약해 주세요:\n\n${joined}`,
      },
    ],
  });

  const block = response.content[0];
  if (block.type === "text") return block.text;
  return "요약을 생성할 수 없습니다.";
}
```

### 인터랙션 핸들러 (src/events/interactionCreate.ts)

```typescript
import { Events, Interaction } from "discord.js";
import { logger } from "../utils/logger";

export const name = Events.InteractionCreate;

export async function execute(interaction: Interaction) {
  if (!interaction.isChatInputCommand()) return;

  const command = interaction.client.commands.get(
    interaction.commandName
  );
  if (!command) {
    logger.warn(
      `커맨드를 찾을 수 없음: ${interaction.commandName}`
    );
    return;
  }

  try {
    await command.execute(interaction);
  } catch (error) {
    logger.error(`커맨드 실행 실패: ${interaction.commandName}`, error);

    const reply = {
      content: "커맨드 실행 중 문제가 발생했어요.",
      ephemeral: true,
    };

    if (interaction.replied || interaction.deferred) {
      await interaction.followUp(reply);
    } else {
      await interaction.reply(reply);
    }
  }
}
```

### 환경변수 검증 (src/utils/config.ts)

```typescript
function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) throw new Error(`환경변수 누락: ${key}`);
  return value;
}

export const config = {
  DISCORD_TOKEN: requireEnv("DISCORD_TOKEN"),
  DISCORD_CLIENT_ID: requireEnv("DISCORD_CLIENT_ID"),
  DISCORD_GUILD_ID: process.env.DISCORD_GUILD_ID || "",
  AI_API_KEY: requireEnv("AI_API_KEY"),
  AI_MODEL: process.env.AI_MODEL || "claude-sonnet-4-20250514",
} as const;
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 새 커맨드 추가 | `"/poll 커맨드 만들어줘. 질문과 최대 5개 선택지를 받고 리액션으로 투표하는 방식"` |
| 에러 핸들링 개선 | `"모든 커맨드에 레이트 리밋 체크를 추가해줘. 유저당 분당 10회 제한"` |
| DB 연동 | `"SQLite로 유저별 질문 히스토리를 저장하는 기능 추가해줘"` |
| 테스트 작성 | `"ask 커맨드의 단위 테스트 작성해줘. AI 서비스는 모킹해서"` |
| 배포 준비 | `"Dockerfile 만들어줘. multi-stage build로 이미지 크기 줄여서"` |

## 레이트 리밋 패턴

Discord API와 AI API 모두 레이트 리밋이 있어요. 두 가지를 동시에 관리해야 해요.

```typescript
// 간단한 인메모리 레이트 리밋
const userCooldowns = new Map<string, number>();
const COOLDOWN_MS = 5000; // 5초

function checkRateLimit(userId: string): boolean {
  const lastUsed = userCooldowns.get(userId) || 0;
  const now = Date.now();

  if (now - lastUsed < COOLDOWN_MS) return false;

  userCooldowns.set(userId, now);
  return true;
}
```

## 테스트

```typescript
// tests/commands.test.ts
import { describe, it, expect, vi } from "vitest";
import { execute } from "../src/commands/ask";

describe("/ask 커맨드", () => {
  it("질문에 대한 AI 응답을 반환한다", async () => {
    const interaction = {
      options: {
        getString: vi.fn().mockReturnValue("TypeScript란?"),
      },
      deferReply: vi.fn(),
      editReply: vi.fn(),
    };

    // AI 서비스 모킹
    vi.mock("../src/services/ai", () => ({
      askAI: vi.fn().mockResolvedValue("TypeScript는 정적 타입 언어입니다."),
    }));

    await execute(interaction as any);

    expect(interaction.deferReply).toHaveBeenCalled();
    expect(interaction.editReply).toHaveBeenCalledWith(
      expect.stringContaining("TypeScript")
    );
  });
});
```

## 배포

### Docker

```dockerfile
FROM node:20-slim AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

FROM node:20-slim
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
CMD ["node", "dist/index.js"]
```

### 실행

```bash
# 개발
pnpm tsx src/index.ts

# 커맨드 등록 (최초 1회)
pnpm tsx src/deploy-commands.ts

# 프로덕션
pnpm build && node dist/index.js

# Docker
docker build -t discord-bot-ai .
docker run --env-file .env discord-bot-ai
```

## 확장 아이디어

- **대화 컨텍스트 유지**: 스레드별로 이전 메시지를 AI에 함께 전달
- **이미지 분석**: 첨부 이미지를 Vision API로 분석하는 `/analyze` 커맨드
- **스케줄링**: cron으로 매일 아침 채널에 뉴스 요약 전송
- **MCP 연동**: MCP 서버를 통해 봇이 외부 도구에 접근

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
