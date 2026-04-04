# EP12: AI 코딩 에이전트 실시간 비용 대시보드 만들기

> AI 코딩 도구 사용량과 비용을 실시간으로 추적하는 대시보드를 직접 만들어보는 라이브 코딩 에피소드

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- Anthropic, OpenAI, Google 등 멀티 프로바이더 API 비용 수집 구조
- 터미널 기반 실시간 비용 모니터링 CLI 구현
- 일별/주별 사용량 트렌드 시각화
- 예산 초과 알림 시스템 구축

## 왜 비용 추적이 필요한가

AI 코딩 도구를 쓰다 보면 한 달 청구서에 놀라는 경우가 많아요. Claude Code로 대규모 리팩토링을 하루 하면 토큰이 수만 개씩 나가고, Cursor Agent 모드를 자주 쓰면 크레딧이 생각보다 빠르게 소진돼요.

문제는 **얼마나 쓰고 있는지 실시간으로 보기 어렵다**는 거예요. 대부분의 API 대시보드는 하루 뒤에 집계되고, 도구별로 흩어져 있어서 전체 그림을 파악하기 힘들어요.

이번 에피소드에서는 이 문제를 직접 해결하는 CLI 대시보드를 만들어볼게요. 핵심 목표는 세 가지예요:

1. **실시간 확인** — 터미널에서 바로 오늘 사용량과 비용 확인
2. **멀티 프로바이더 통합** — Anthropic + OpenAI + Google을 한 화면에
3. **예산 관리** — 일별/월별 한도 초과 시 즉시 알림

## 프로젝트 구조

```
ai-cost-dashboard/
├── src/
│   ├── index.ts          # CLI 엔트리포인트
│   ├── collector.ts      # API 비용 수집기
│   ├── dashboard.ts      # 터미널 UI 렌더링
│   ├── budget.ts         # 예산 관리 & 알림
│   └── providers/
│       ├── anthropic.ts  # Anthropic API 사용량 조회
│       ├── openai.ts     # OpenAI API 사용량 조회
│       └── google.ts     # Google AI API 사용량 조회
├── config.yaml           # 예산 설정 & API 키 경로
├── data/
│   └── usage.db          # SQLite 로컬 사용량 DB
├── package.json
└── tsconfig.json
```

## 시작하기

```bash
# 프로젝트 초기화
mkdir ai-cost-dashboard && cd ai-cost-dashboard
npm init -y
npm install blessed blessed-contrib better-sqlite3 yaml node-cron
npm install -D typescript @types/node @types/better-sqlite3

# tsconfig 설정
npx tsc --init --target ES2022 --module NodeNext \
  --moduleResolution NodeNext --outDir dist
```

## 핵심 코드

### 비용 수집기 (collector.ts)

```typescript
import Database from "better-sqlite3";

interface UsageRecord {
  provider: string;
  model: string;
  input_tokens: number;
  output_tokens: number;
  cost_usd: number;
  timestamp: string;
}

// 프로바이더별 토큰 단가 (2026년 4월 기준)
const PRICING: Record<string, { input: number; output: number }> = {
  "claude-sonnet-4": { input: 3.0, output: 15.0 },     // per 1M tokens
  "claude-opus-4": { input: 15.0, output: 75.0 },
  "gpt-4.1": { input: 2.0, output: 8.0 },
  "gemini-2.5-pro": { input: 1.25, output: 10.0 },
};

export class CostCollector {
  private db: Database.Database;

  constructor(dbPath: string) {
    this.db = new Database(dbPath);
    this.initSchema();
  }

  private initSchema() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT NOT NULL,
        model TEXT NOT NULL,
        input_tokens INTEGER NOT NULL,
        output_tokens INTEGER NOT NULL,
        cost_usd REAL NOT NULL,
        timestamp TEXT NOT NULL DEFAULT (datetime('now'))
      );
      CREATE INDEX IF NOT EXISTS idx_usage_date
        ON usage(timestamp);
    `);
  }

  record(entry: UsageRecord) {
    this.db.prepare(`
      INSERT INTO usage (provider, model, input_tokens, output_tokens, cost_usd, timestamp)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(
      entry.provider,
      entry.model,
      entry.input_tokens,
      entry.output_tokens,
      entry.cost_usd,
      entry.timestamp
    );
  }

  // 오늘 총 비용
  todayTotal(): number {
    const row = this.db.prepare(`
      SELECT COALESCE(SUM(cost_usd), 0) as total
      FROM usage
      WHERE date(timestamp) = date('now')
    `).get() as { total: number };
    return row.total;
  }

  // 프로바이더별 일별 비용 (최근 7일)
  weeklyByProvider(): Array<{ date: string; provider: string; cost: number }> {
    return this.db.prepare(`
      SELECT date(timestamp) as date, provider, SUM(cost_usd) as cost
      FROM usage
      WHERE timestamp >= datetime('now', '-7 days')
      GROUP BY date(timestamp), provider
      ORDER BY date
    `).all() as Array<{ date: string; provider: string; cost: number }>;
  }

  // 모델별 토큰 사용량 (오늘)
  todayByModel(): Array<{ model: string; tokens: number; cost: number }> {
    return this.db.prepare(`
      SELECT model,
             SUM(input_tokens + output_tokens) as tokens,
             SUM(cost_usd) as cost
      FROM usage
      WHERE date(timestamp) = date('now')
      GROUP BY model
      ORDER BY cost DESC
    `).all() as Array<{ model: string; tokens: number; cost: number }>;
  }
}
```

**왜 SQLite인가요?**

서버 없이 로컬에서 바로 동작해야 하니까요. JSON 파일로도 되지만, 날짜별 집계 쿼리가 빈번해서 SQLite가 훨씬 편해요. `better-sqlite3`는 동기 API라 CLI에서 쓰기도 간단해요.

### Anthropic 사용량 조회 (providers/anthropic.ts)

```typescript
interface AnthropicUsageResponse {
  data: Array<{
    input_tokens: number;
    output_tokens: number;
    model: string;
    timestamp: string;
  }>;
}

export async function fetchAnthropicUsage(
  apiKey: string,
  startDate: string
): Promise<AnthropicUsageResponse> {
  const res = await fetch(
    `https://api.anthropic.com/v1/organizations/usage?start_date=${startDate}`,
    {
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2024-01-01",
      },
    }
  );

  if (!res.ok) {
    throw new Error(`Anthropic API error: ${res.status}`);
  }

  return res.json();
}

// 로컬 Claude Code 로그에서 토큰 추출 (API 키 없이도 가능)
export function parseClaudeCodeLogs(logDir: string): Array<{
  model: string;
  input_tokens: number;
  output_tokens: number;
  timestamp: string;
}> {
  // ~/.claude/projects/ 하위 JSONL 로그 파싱
  const entries: Array<{
    model: string;
    input_tokens: number;
    output_tokens: number;
    timestamp: string;
  }> = [];

  // 실제 구현에서는 fs.readdirSync + JSONL 파싱
  // Claude Code는 각 세션 로그를 JSONL로 저장
  return entries;
}
```

### 예산 관리 (budget.ts)

```typescript
import { CostCollector } from "./collector.js";

interface BudgetConfig {
  daily_limit_usd: number;
  monthly_limit_usd: number;
  alert_threshold: number; // 0.0 ~ 1.0 (80% = 0.8)
  webhook_url?: string;    // Slack/Discord 알림
}

export class BudgetManager {
  constructor(
    private collector: CostCollector,
    private config: BudgetConfig
  ) {}

  check(): { ok: boolean; warnings: string[] } {
    const warnings: string[] = [];
    const todayCost = this.collector.todayTotal();
    const threshold = this.config.daily_limit_usd * this.config.alert_threshold;

    if (todayCost >= this.config.daily_limit_usd) {
      warnings.push(
        `일일 한도 초과: $${todayCost.toFixed(2)} / $${this.config.daily_limit_usd}`
      );
    } else if (todayCost >= threshold) {
      warnings.push(
        `일일 한도 ${Math.round(this.config.alert_threshold * 100)}% 도달: ` +
        `$${todayCost.toFixed(2)} / $${this.config.daily_limit_usd}`
      );
    }

    return {
      ok: warnings.length === 0,
      warnings,
    };
  }

  async notify(message: string) {
    if (!this.config.webhook_url) return;

    await fetch(this.config.webhook_url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content: `⚠️ AI 비용 알림: ${message}` }),
    });
  }
}
```

### 터미널 대시보드 UI (dashboard.ts)

```typescript
import contrib from "blessed-contrib";
import blessed from "blessed";
import { CostCollector } from "./collector.js";
import { BudgetManager } from "./budget.js";

export function renderDashboard(
  collector: CostCollector,
  budget: BudgetManager
) {
  const screen = blessed.screen({ smartCSR: true });
  const grid = new contrib.grid({ rows: 3, cols: 3, screen });

  // 오늘 비용 게이지
  const gauge = grid.set(0, 0, 1, 1, contrib.gauge, {
    label: " 오늘 비용 ",
    stroke: "green",
    fill: "white",
  });

  // 프로바이더별 도넛 차트
  const donut = grid.set(0, 1, 1, 1, contrib.donut, {
    label: " 프로바이더별 비용 ",
    radius: 10,
  });

  // 주간 트렌드 라인 차트
  const line = grid.set(0, 2, 1, 1, contrib.line, {
    label: " 주간 트렌드 ",
    showLegend: true,
  });

  // 모델별 사용량 테이블
  const table = grid.set(1, 0, 1, 3, contrib.table, {
    label: " 모델별 사용량 (오늘) ",
    columnWidth: [25, 15, 12],
    keys: true,
    fg: "white",
    selectedFg: "black",
    selectedBg: "green",
  });

  // 로그 패널
  const log = grid.set(2, 0, 1, 3, contrib.log, {
    label: " 최근 활동 ",
    fg: "green",
  });

  function refresh() {
    const today = collector.todayTotal();
    const budgetCheck = budget.check();

    // 게이지 업데이트 (일일 한도 대비 %)
    const pct = Math.min(100, Math.round((today / 10) * 100)); // $10 기준
    gauge.setPercent(pct);

    // 모델별 테이블
    const models = collector.todayByModel();
    table.setData({
      headers: ["모델", "토큰", "비용(USD)"],
      data: models.map((m) => [
        m.model,
        m.tokens.toLocaleString(),
        `$${m.cost.toFixed(4)}`,
      ]),
    });

    // 경고 표시
    budgetCheck.warnings.forEach((w) => log.log(`⚠️ ${w}`));

    screen.render();
  }

  // 30초마다 갱신
  setInterval(refresh, 30_000);
  refresh();

  screen.key(["q", "C-c"], () => process.exit(0));
}
```

### 설정 파일 (config.yaml)

```yaml
# AI 비용 대시보드 설정
providers:
  anthropic:
    api_key_env: ANTHROPIC_API_KEY
    enabled: true
  openai:
    api_key_env: OPENAI_API_KEY
    enabled: true
  google:
    api_key_env: GOOGLE_AI_API_KEY
    enabled: false

budget:
  daily_limit_usd: 10.00
  monthly_limit_usd: 200.00
  alert_threshold: 0.8

alerts:
  discord_webhook: ""  # 선택: Discord 웹훅 URL
  slack_webhook: ""    # 선택: Slack 웹훅 URL

# Claude Code 로컬 로그 수집 (API 키 없이 사용량 추적)
local_sources:
  claude_code:
    enabled: true
    log_dir: "~/.claude/projects"
  cursor:
    enabled: false
    log_dir: "~/.cursor-tutor"
```

### CLI 엔트리포인트 (index.ts)

```typescript
#!/usr/bin/env node
import { readFileSync } from "fs";
import { parse } from "yaml";
import { CostCollector } from "./collector.js";
import { BudgetManager } from "./budget.js";
import { renderDashboard } from "./dashboard.js";

const args = process.argv.slice(2);
const command = args[0] || "dashboard";

// 설정 로드
const config = parse(readFileSync("config.yaml", "utf-8"));
const collector = new CostCollector("data/usage.db");
const budget = new BudgetManager(collector, config.budget);

switch (command) {
  case "dashboard":
    // 터미널 UI 실행
    renderDashboard(collector, budget);
    break;

  case "today":
    // 오늘 비용 요약 (한 줄)
    const total = collector.todayTotal();
    const models = collector.todayByModel();
    console.log(`오늘 총 비용: $${total.toFixed(4)}`);
    models.forEach((m) => {
      console.log(`  ${m.model}: ${m.tokens.toLocaleString()} tokens ($${m.cost.toFixed(4)})`);
    });
    break;

  case "check":
    // 예산 체크
    const result = budget.check();
    if (result.ok) {
      console.log("✅ 예산 범위 내");
    } else {
      result.warnings.forEach((w) => console.log(`⚠️ ${w}`));
      process.exit(1);
    }
    break;

  case "collect":
    // 수동 수집 트리거
    console.log("🔄 비용 데이터 수집 중...");
    // 프로바이더별 수집 로직 실행
    break;

  default:
    console.log(`
AI 비용 대시보드 CLI

사용법:
  ai-cost dashboard    터미널 대시보드 실행
  ai-cost today        오늘 비용 요약
  ai-cost check        예산 체크
  ai-cost collect      비용 데이터 수동 수집
    `);
}
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| SQLite 스키마 설계 | `"API 비용 추적용 SQLite 스키마 만들어줘. 프로바이더별, 모델별 집계가 필요해"` |
| blessed-contrib 차트 | `"blessed-contrib로 라인 차트 + 도넛 차트 + 테이블 조합 레이아웃 만들어줘"` |
| API 응답 파싱 | `"Anthropic usage API 응답을 파싱해서 모델별 토큰 비용 계산하는 함수 작성해줘"` |
| cron 스케줄링 | `"node-cron으로 5분마다 비용 수집하고 일일 한도 초과 시 Discord 알림 보내는 코드"` |
| 로그 파싱 | `"~/.claude/projects 디렉토리의 JSONL 로그를 파싱해서 세션별 토큰 사용량 집계해줘"` |

## 실전 팁

### 1. Claude Code 로컬 로그 활용

API 키 없이도 로컬 로그에서 토큰 사용량을 추적할 수 있어요. Claude Code는 `~/.claude/projects/` 아래에 세션 로그를 JSONL 형식으로 저장해요.

```bash
# 오늘 Claude Code 사용량 확인 (간단 버전)
find ~/.claude/projects -name "*.jsonl" -newer /tmp/today_marker \
  | xargs grep '"usage"' \
  | python3 -c "
import sys, json
total_in = total_out = 0
for line in sys.stdin:
    try:
        data = json.loads(line.split(':', 1)[1] if ':' in line else line)
        if 'usage' in data:
            total_in += data['usage'].get('input_tokens', 0)
            total_out += data['usage'].get('output_tokens', 0)
    except: pass
print(f'Input: {total_in:,} tokens')
print(f'Output: {total_out:,} tokens')
"
```

### 2. ccusage 활용

이미 커뮤니티에서 만든 도구도 있어요. [ccusage](https://ccusage.com/)는 Claude Code 사용량을 웹 대시보드로 보여주는 도구예요. 이 에피소드의 CLI 대시보드와 병행해서 쓰면 좋아요.

### 3. 예산 관리 자동화

```bash
# .zshrc에 추가 — 터미널 열 때마다 오늘 비용 확인
ai-cost check 2>/dev/null || echo "⚠️ AI 비용 한도 주의!"
```

## 따라하기

### Step 1: 프로젝트 세팅

```bash
mkdir ai-cost-dashboard && cd ai-cost-dashboard
npm init -y
npm install blessed blessed-contrib better-sqlite3 yaml
npm install -D typescript @types/node
npx tsc --init
```

### Step 2: 수집기 구현

위의 `collector.ts` 코드를 `src/` 아래에 작성하고, SQLite DB 초기화를 확인해요.

### Step 3: 프로바이더 연동

각 AI 프로바이더의 usage API를 연동해요. Anthropic은 `/v1/organizations/usage`, OpenAI는 `/v1/usage`를 사용해요.

### Step 4: 대시보드 UI

`blessed-contrib`로 터미널 UI를 구성해요. 게이지, 도넛 차트, 라인 차트, 테이블 4개 위젯이 핵심이에요.

### Step 5: 예산 알림

`config.yaml`에서 일별/월별 한도를 설정하고, Discord나 Slack 웹훅으로 알림을 보내는 기능을 추가해요.

## 더 알아보기

- [AI 비용 최적화 플레이북](../claude-code/playbooks/38-cost-optimization-playbook.md)
- [AI 비용 모니터링 예제](../examples/ai-cost-monitor)
- [AI 에이전트 옵저버빌리티](../workflows/ai-agent-observability-pipeline.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
