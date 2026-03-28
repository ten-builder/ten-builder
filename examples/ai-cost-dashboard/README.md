# AI API 비용 실시간 대시보드

> 여러 AI 프로바이더(Claude, OpenAI, Gemini)의 API 비용을 실시간으로 추적하고 시각화하는 웹 대시보드

## 이 예제에서 배울 수 있는 것

- 여러 AI API 프로바이더의 빌링 데이터를 통합 수집하는 패턴
- Next.js + Chart.js로 실시간 비용 추이 대시보드를 구축하는 방법
- 프로바이더별 토큰 단가 차이를 고려한 정확한 비용 계산 로직
- 예산 초과 시 Slack/Discord 알림을 자동 전송하는 웹훅 연동

## 프로젝트 구조

```
ai-cost-dashboard/
├── CLAUDE.md                  # 프로젝트 컨텍스트
├── package.json
├── tsconfig.json
├── .env.example               # API 키 템플릿
├── src/
│   ├── app/
│   │   ├── layout.tsx         # 루트 레이아웃
│   │   ├── page.tsx           # 메인 대시보드
│   │   └── api/
│   │       ├── usage/route.ts # 사용량 조회 API
│   │       └── alert/route.ts # 알림 웹훅
│   ├── lib/
│   │   ├── providers/
│   │   │   ├── anthropic.ts   # Anthropic API 사용량 수집
│   │   │   ├── openai.ts      # OpenAI API 사용량 수집
│   │   │   └── google.ts      # Google AI 사용량 수집
│   │   ├── pricing.ts         # 프로바이더별 토큰 단가 테이블
│   │   ├── db.ts              # SQLite 저장소
│   │   └── alert.ts           # 알림 로직
│   └── components/
│       ├── CostChart.tsx      # 비용 추이 차트
│       ├── ProviderCard.tsx   # 프로바이더별 요약 카드
│       ├── UsageTable.tsx     # 상세 사용 내역 테이블
│       └── BudgetGauge.tsx    # 예산 게이지 컴포넌트
├── prisma/
│   └── schema.prisma          # DB 스키마
└── tests/
    ├── providers.test.ts
    └── pricing.test.ts
```

## 시작하기

```bash
# 프로젝트 클론
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-cost-dashboard

# 의존성 설치
pnpm install

# 환경 변수 설정
cp .env.example .env
# .env 파일에 각 프로바이더 API 키 입력

# DB 초기화
pnpm db:push

# 개발 서버 실행
pnpm dev
```

## 핵심 코드

### 프로바이더별 사용량 수집기

각 AI 프로바이더의 빌링 API에서 사용량을 가져오는 수집기입니다.

```typescript
// src/lib/providers/anthropic.ts
interface UsageRecord {
  provider: 'anthropic' | 'openai' | 'google';
  model: string;
  inputTokens: number;
  outputTokens: number;
  cost: number;
  timestamp: Date;
}

export async function fetchAnthropicUsage(
  apiKey: string,
  startDate: Date,
  endDate: Date
): Promise<UsageRecord[]> {
  // Anthropic Admin API로 사용량 조회
  const response = await fetch(
    'https://api.anthropic.com/v1/organizations/usage',
    {
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2024-10-22',
      },
    }
  );

  const data = await response.json();

  return data.usage.map((entry: any) => ({
    provider: 'anthropic' as const,
    model: entry.model,
    inputTokens: entry.input_tokens,
    outputTokens: entry.output_tokens,
    cost: calculateAnthropicCost(
      entry.model,
      entry.input_tokens,
      entry.output_tokens
    ),
    timestamp: new Date(entry.timestamp),
  }));
}
```

**왜 프로바이더별 수집기를 분리했나요?**

각 프로바이더마다 빌링 API 형식, 인증 방식, 토큰 단가 구조가 다릅니다. 수집기를 분리하면 새 프로바이더 추가 시 기존 코드를 건드리지 않아도 됩니다.

### 토큰 단가 테이블

모델별 정확한 비용 계산을 위한 단가 테이블입니다.

```typescript
// src/lib/pricing.ts
type PricingEntry = {
  inputPer1M: number;   // 입력 토큰 100만개당 USD
  outputPer1M: number;  // 출력 토큰 100만개당 USD
  cached?: number;      // 캐시된 입력 토큰 단가 (선택)
};

const PRICING: Record<string, PricingEntry> = {
  // Anthropic
  'claude-opus-4': { inputPer1M: 15, outputPer1M: 75, cached: 1.5 },
  'claude-sonnet-4': { inputPer1M: 3, outputPer1M: 15, cached: 0.3 },
  'claude-haiku-3.5': { inputPer1M: 0.8, outputPer1M: 4, cached: 0.08 },

  // OpenAI
  'gpt-4.1': { inputPer1M: 2, outputPer1M: 8, cached: 0.5 },
  'gpt-4.1-mini': { inputPer1M: 0.4, outputPer1M: 1.6, cached: 0.1 },
  'o3': { inputPer1M: 10, outputPer1M: 40, cached: 2.5 },
  'o4-mini': { inputPer1M: 1.1, outputPer1M: 4.4, cached: 0.275 },

  // Google
  'gemini-2.5-pro': { inputPer1M: 1.25, outputPer1M: 10 },
  'gemini-2.5-flash': { inputPer1M: 0.15, outputPer1M: 0.6 },
};

export function calculateCost(
  model: string,
  inputTokens: number,
  outputTokens: number,
  cachedTokens = 0
): number {
  const pricing = PRICING[model];
  if (!pricing) return 0;

  const inputCost =
    ((inputTokens - cachedTokens) * pricing.inputPer1M) / 1_000_000;
  const cachedCost = pricing.cached
    ? (cachedTokens * pricing.cached) / 1_000_000
    : 0;
  const outputCost = (outputTokens * pricing.outputPer1M) / 1_000_000;

  return inputCost + cachedCost + outputCost;
}
```

### 비용 추이 차트 컴포넌트

일별/주별 비용 추이를 시각화하는 차트입니다.

```tsx
// src/components/CostChart.tsx
'use client';

import { Line } from 'react-chartjs-2';
import { useMemo } from 'react';

interface CostDataPoint {
  date: string;
  anthropic: number;
  openai: number;
  google: number;
}

export function CostChart({ data }: { data: CostDataPoint[] }) {
  const chartData = useMemo(
    () => ({
      labels: data.map((d) => d.date),
      datasets: [
        {
          label: 'Anthropic',
          data: data.map((d) => d.anthropic),
          borderColor: '#D97706',
          backgroundColor: 'rgba(217, 119, 6, 0.1)',
          fill: true,
        },
        {
          label: 'OpenAI',
          data: data.map((d) => d.openai),
          borderColor: '#10B981',
          backgroundColor: 'rgba(16, 185, 129, 0.1)',
          fill: true,
        },
        {
          label: 'Google',
          data: data.map((d) => d.google),
          borderColor: '#3B82F6',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          fill: true,
        },
      ],
    }),
    [data]
  );

  return (
    <div className="rounded-lg border p-4">
      <h3 className="mb-2 text-lg font-semibold">일별 비용 추이</h3>
      <Line
        data={chartData}
        options={{
          responsive: true,
          scales: {
            y: {
              beginAtZero: true,
              ticks: { callback: (v) => `$${v}` },
            },
          },
          plugins: {
            tooltip: {
              callbacks: {
                label: (ctx) =>
                  `${ctx.dataset.label}: $${ctx.parsed.y.toFixed(2)}`,
              },
            },
          },
        }}
      />
    </div>
  );
}
```

### 예산 알림 시스템

설정한 예산을 초과하면 자동으로 알림을 보내는 시스템입니다.

```typescript
// src/lib/alert.ts
interface BudgetConfig {
  dailyLimit: number;     // 일일 예산 (USD)
  monthlyLimit: number;   // 월간 예산 (USD)
  warningThreshold: 0.8;  // 80%에서 경고
  webhookUrl?: string;    // Slack/Discord 웹훅
}

export async function checkBudget(
  config: BudgetConfig,
  todayCost: number,
  monthCost: number
): Promise<void> {
  const alerts: string[] = [];

  // 일일 예산 체크
  if (todayCost >= config.dailyLimit) {
    alerts.push(
      `일일 예산 초과: $${todayCost.toFixed(2)} / $${config.dailyLimit}`
    );
  } else if (todayCost >= config.dailyLimit * config.warningThreshold) {
    alerts.push(
      `일일 예산 경고(80%): $${todayCost.toFixed(2)} / $${config.dailyLimit}`
    );
  }

  // 월간 예산 체크
  if (monthCost >= config.monthlyLimit) {
    alerts.push(
      `월간 예산 초과: $${monthCost.toFixed(2)} / $${config.monthlyLimit}`
    );
  }

  if (alerts.length > 0 && config.webhookUrl) {
    await sendWebhook(config.webhookUrl, alerts.join('\n'));
  }
}

async function sendWebhook(url: string, message: string) {
  // Discord와 Slack 웹훅 형식 자동 감지
  const isDiscord = url.includes('discord.com');
  const body = isDiscord
    ? { content: message }
    : { text: message };

  await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}
```

### DB 스키마

사용량 데이터를 저장하는 Prisma 스키마입니다.

```prisma
// prisma/schema.prisma
model UsageRecord {
  id          Int      @id @default(autoincrement())
  provider    String   // anthropic, openai, google
  model       String
  inputTokens Int
  outputTokens Int
  cachedTokens Int     @default(0)
  cost        Float
  timestamp   DateTime
  createdAt   DateTime @default(now())

  @@index([provider, timestamp])
  @@index([timestamp])
}

model BudgetConfig {
  id             Int    @id @default(autoincrement())
  dailyLimit     Float
  monthlyLimit   Float
  webhookUrl     String?
  updatedAt      DateTime @updatedAt
}
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 새 프로바이더 추가 | `Mistral API 수집기를 src/lib/providers/mistral.ts에 추가해줘. 기존 anthropic.ts 패턴을 따라서` |
| 차트 커스터마이징 | `월별 비용 비교 바 차트 컴포넌트를 추가해줘. 프로바이더별 색상은 기존 CostChart와 동일하게` |
| 알림 채널 추가 | `텔레그램 봇 알림을 alert.ts에 추가해줘. TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID 환경변수 사용` |
| 비용 최적화 분석 | `최근 7일 데이터에서 모델별 토큰당 비용 효율을 비교하는 API 엔드포인트를 만들어줘` |
| 캐싱 효율 추적 | `프로바이더별 캐시 히트율을 계산하고 대시보드에 표시하는 기능을 추가해줘` |

## 확장 아이디어

- **비용 예측**: 지난 7일 트렌드를 기반으로 월말 예상 비용을 계산
- **모델 라우팅 추천**: 태스크별 비용 효율이 높은 모델을 자동 추천
- **팀 대시보드**: 팀원별 API 키를 구분하여 개인 비용 추적
- **리포트 자동화**: 주간/월간 비용 리포트를 PDF로 생성하여 이메일 발송

## 주의사항

- API 키는 `.env` 파일에 저장하고, `.gitignore`에 포함되어 있는지 확인하세요
- 빌링 API는 프로바이더마다 호출 제한이 다릅니다. 수집 주기를 적절히 조절하세요
- 토큰 단가는 주기적으로 변경됩니다. `pricing.ts`를 최신 상태로 유지하세요

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
