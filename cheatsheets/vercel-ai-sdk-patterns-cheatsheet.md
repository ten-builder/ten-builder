# Vercel AI SDK 핵심 패턴 치트시트 2026

> Next.js App Router에서 AI 기능을 빠르게 구현하는 패턴 모음 — useChat, streamText, generateObject, Tool Use, 멀티모달까지 한 페이지로 정리

---

## 1. 레이어 구조

| 레이어 | 패키지 | 역할 |
|--------|--------|------|
| AI SDK Core | `ai` | 서버 사이드: `streamText`, `generateText`, `generateObject` |
| AI SDK UI | `ai/react` | 클라이언트: `useChat`, `useCompletion`, `useObject` |
| Provider | `@ai-sdk/anthropic` 등 | 모델 연결 (교체 시 import만 변경) |

```bash
npm install ai @ai-sdk/openai @ai-sdk/anthropic @ai-sdk/google zod
```

---

## 2. useChat — 채팅 UI 연동

### 기본 패턴

```tsx
// app/chat/page.tsx
'use client';
import { useChat } from 'ai/react';

export default function Chat() {
  const { messages, input, handleInputChange, handleSubmit, isLoading, error } = useChat({
    api: '/api/chat',
    onError: (err) => console.error('스트리밍 오류:', err),
    onFinish: (msg) => console.log('완료:', msg.usage),
  });

  return (
    <div>
      {messages.map((m) => (
        <div key={m.id}>{m.role}: {m.content}</div>
      ))}
      <form onSubmit={handleSubmit}>
        <input value={input} onChange={handleInputChange} disabled={isLoading} />
        <button type="submit">전송</button>
      </form>
      {error && <p>오류 발생 — 다시 시도해 주세요</p>}
    </div>
  );
}
```

### API Route

```ts
// app/api/chat/route.ts
import { streamText } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: anthropic('claude-sonnet-4-5'),
    system: '당신은 친절한 한국어 개발 도우미입니다.',
    messages,
    onFinish: ({ usage }) => {
      // 토큰 사용량 기록 — onFinish에서만 정확한 값 확인 가능
      console.log('tokens:', usage.totalTokens);
    },
  });

  return result.toDataStreamResponse();
}
```

---

## 3. streamText vs generateText 선택 기준

| 상황 | 함수 | 이유 |
|------|------|------|
| 채팅 UI, 실시간 타이핑 효과 | `streamText` | 첫 토큰부터 즉시 표시 |
| 짧은 요약, 분류 작업 | `generateText` | 단순하고 오버헤드 없음 |
| 구조화된 JSON 데이터 필요 | `generateObject` | Zod 스키마로 타입 안전 보장 |
| 폼 입력 완성, 단발 텍스트 | `useCompletion` | 메시지 기록 불필요 시 |

---

## 4. generateObject — 구조화 출력

```ts
// app/api/analyze/route.ts
import { generateObject } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';

const reviewSchema = z.object({
  sentiment: z.enum(['긍정', '부정', '중립']),
  score: z.number().min(1).max(10),
  keywords: z.array(z.string()).max(5),
  summary: z.string().max(100),
});

export async function POST(req: Request) {
  const { text } = await req.json();

  const { object } = await generateObject({
    model: openai('gpt-4o'),
    schema: reviewSchema,
    prompt: `다음 리뷰를 분석하세요: ${text}`,
  });

  return Response.json(object);
}
```

스트리밍이 필요하면 `streamObject` + 클라이언트에서 `useObject` 사용:

```tsx
import { useObject } from 'ai/react';

const { object, submit, isLoading } = useObject({
  api: '/api/analyze',
  schema: reviewSchema,
});
```

---

## 5. Tool Use — 함수 호출 패턴

```ts
import { streamText, tool } from 'ai';
import { z } from 'zod';

const result = streamText({
  model: anthropic('claude-sonnet-4-5'),
  tools: {
    getWeather: tool({
      description: '특정 도시의 현재 날씨 조회',
      parameters: z.object({
        city: z.string().describe('도시 이름 (한국어)'),
      }),
      execute: async ({ city }) => {
        // 실제 API 호출
        return { temp: 22, condition: '맑음', city };
      },
    }),
  },
  maxSteps: 5, // 툴 호출 루프 최대 횟수 — 반드시 설정
  messages,
});
```

> **주의:** `maxSteps`를 설정하지 않으면 툴 응답 후 텍스트 생성이 잘릴 수 있습니다.

---

## 6. 멀티모달 입력

```ts
// 이미지 + 텍스트 동시 전달
const result = await generateText({
  model: anthropic('claude-sonnet-4-5'),
  messages: [
    {
      role: 'user',
      content: [
        { type: 'text', text: '이 코드 스크린샷에서 버그를 찾아주세요.' },
        { type: 'image', image: new URL('https://example.com/code.png') },
        // 또는 파일: { type: 'image', image: fs.readFileSync('./code.png') }
      ],
    },
  ],
});
```

---

## 7. 프로바이더 교체 패턴

```ts
// 하나의 코드로 모든 프로바이더 지원
import { openai } from '@ai-sdk/openai';
import { anthropic } from '@ai-sdk/anthropic';
import { google } from '@ai-sdk/google';

const MODEL_MAP = {
  fast: openai('gpt-4o-mini'),
  balanced: anthropic('claude-sonnet-4-5'),
  powerful: google('gemini-3-pro'),
} as const;

// 태스크 유형에 따라 동적 선택
const model = MODEL_MAP[taskType] ?? MODEL_MAP.balanced;
```

OpenAI 호환 엔드포인트(Ollama, vLLM 등) 연결:

```ts
import { createOpenAICompatible } from '@ai-sdk/openai-compatible';

const ollama = createOpenAICompatible({
  name: 'ollama',
  baseURL: 'http://localhost:11434/v1',
});

const result = await streamText({ model: ollama('llama3.2') });
```

---

## 8. 에러 처리 & 프로덕션 패턴

```ts
// 프로바이더 fallback
async function streamWithFallback(messages: Message[]) {
  try {
    return streamText({ model: anthropic('claude-sonnet-4-5'), messages });
  } catch (e) {
    console.warn('기본 프로바이더 실패, fallback 실행');
    return streamText({ model: openai('gpt-4o'), messages }); // 자동 전환
  }
}
```

```tsx
// 클라이언트 재시도 버튼
const { reload, error } = useChat({ ... });

{error && (
  <button onClick={reload}>다시 시도</button>
)}
```

| 패턴 | 구현 방법 |
|------|----------|
| 스트림 중단 처리 | `onFinish`에서 `isAborted` 확인 + `consumeSseStream` 설정 |
| 토큰 비용 추적 | `onFinish({ usage })` — 스트림 청크 아닌 여기서 정확한 값 |
| 요청 취소 | `useChat`의 `stop()` 함수 또는 AbortController |
| 속도 제한 | API Route에서 IP 기반 rate limiting 미들웨어 추가 |

---

## 9. useCompletion — 단발 완성

```tsx
import { useCompletion } from 'ai/react';

const { completion, complete, isLoading } = useCompletion({
  api: '/api/complete',
});

// 폼 제출이나 버튼 클릭으로 트리거
<button onClick={() => complete(userInput)}>요약하기</button>
<p>{completion}</p>
```

useChat과의 차이: 대화 기록을 유지하지 않아 단일 요청에 적합합니다.

---

## 빠른 참조

| Hook/함수 | 위치 | 대표 사용 사례 |
|-----------|------|---------------|
| `useChat` | 클라이언트 | 채팅 인터페이스 |
| `useCompletion` | 클라이언트 | 텍스트 완성, 요약 버튼 |
| `useObject` | 클라이언트 | 스트리밍 구조화 데이터 |
| `streamText` | 서버 | 채팅 API Route |
| `generateText` | 서버 | 짧은 텍스트 생성 |
| `generateObject` | 서버 | JSON 구조화 응답 |
| `streamObject` | 서버 | 스트리밍 JSON |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
