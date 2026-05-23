# AI 에이전트 기반 실시간 코드 품질 대시보드

> SonarQube, ESLint, TypeScript 컴파일러 결과를 AI 에이전트가 집계하여 팀 코드 품질 트렌드를 실시간으로 시각화하는 Next.js 대시보드 예제

## 이 예제에서 배울 수 있는 것

- SonarQube API와 ESLint JSON 리포트를 주기적으로 수집하는 패턴
- TypeScript 컴파일러 오류 수를 CI 파이프라인에서 추적하는 방법
- Claude API로 품질 지표를 분석하고 자연어 개선 제안을 생성하는 구조
- Next.js App Router + Recharts로 실시간 트렌드 차트를 구성하는 방법
- PR 단위 품질 변화를 Slack/Discord로 자동 알림하는 패턴

## 프로젝트 구조

```
ai-code-quality-dashboard/
├── app/
│   ├── api/
│   │   ├── collect/route.ts      # 지표 수집 API (cron 호출)
│   │   └── metrics/route.ts      # 대시보드 데이터 조회 API
│   ├── dashboard/
│   │   └── page.tsx              # 메인 대시보드 페이지
│   └── layout.tsx
├── components/
│   ├── QualityTrendChart.tsx     # 시계열 품질 트렌드 차트
│   ├── MetricCard.tsx            # 개별 지표 카드
│   └── AIInsights.tsx            # AI 분석 결과 패널
├── lib/
│   ├── sonarqube.ts              # SonarQube API 클라이언트
│   ├── eslint-collector.ts       # ESLint 리포트 파서
│   ├── typescript-checker.ts     # tsc 오류 수집기
│   └── ai-analyzer.ts            # Claude API 분석 모듈
├── scripts/
│   └── collect-metrics.ts        # 수동 실행 수집 스크립트
├── .github/
│   └── workflows/
│       └── quality-check.yml     # CI 품질 게이트 워크플로
└── README.md
```

## 시작하기

```bash
# 레포 클론
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-code-quality-dashboard

# 패키지 설치
pnpm install

# 환경 변수 설정
cp .env.example .env.local
# .env.local에 아래 값 입력:
# SONARQUBE_URL=http://localhost:9000
# SONARQUBE_TOKEN=your_token
# ANTHROPIC_API_KEY=your_key
# DATABASE_URL=postgresql://...

# 개발 서버 실행
pnpm dev
```

## 핵심 코드

### SonarQube 지표 수집 (`lib/sonarqube.ts`)

```typescript
const SONAR_METRICS = [
  "bugs",
  "vulnerabilities",
  "code_smells",
  "coverage",
  "duplicated_lines_density",
  "technical_debt",
  "reliability_rating",
  "security_rating",
];

export async function fetchSonarMetrics(projectKey: string) {
  const params = new URLSearchParams({
    component: projectKey,
    metricKeys: SONAR_METRICS.join(","),
  });

  const res = await fetch(
    `${process.env.SONARQUBE_URL}/api/measures/component?${params}`,
    {
      headers: {
        Authorization: `Bearer ${process.env.SONARQUBE_TOKEN}`,
      },
    }
  );

  if (!res.ok) {
    throw new Error(`SonarQube API error: ${res.status}`);
  }

  const data = await res.json();
  return Object.fromEntries(
    data.component.measures.map((m: { metric: string; value: string }) => [
      m.metric,
      parseFloat(m.value),
    ])
  );
}
```

**왜 이렇게 했나요?**

SonarQube `/api/measures/component` 엔드포인트는 여러 지표를 단일 요청으로 가져올 수 있어서 API 호출 횟수를 줄입니다. Bearer 토큰 방식은 SonarQube 9.x 이상에서 권장하는 인증 방식입니다.

### ESLint 리포트 파서 (`lib/eslint-collector.ts`)

```typescript
import { execSync } from "child_process";

export interface ESLintSummary {
  errorCount: number;
  warningCount: number;
  fixableErrorCount: number;
  topRules: { rule: string; count: number }[];
}

export function collectESLintMetrics(projectPath: string): ESLintSummary {
  let output: string;
  try {
    output = execSync(`npx eslint ${projectPath} --format json --quiet`, {
      encoding: "utf-8",
      cwd: projectPath,
    });
  } catch (err: unknown) {
    // ESLint가 오류를 발견하면 exit code 1을 반환하므로 stdout을 사용
    output = (err as { stdout: string }).stdout ?? "[]";
  }

  const results: { errorCount: number; warningCount: number; messages: { ruleId: string; severity: number }[] }[] = JSON.parse(output);
  const ruleCounts: Record<string, number> = {};

  let totalErrors = 0;
  let totalWarnings = 0;
  let fixableErrors = 0;

  for (const file of results) {
    totalErrors += file.errorCount;
    totalWarnings += file.warningCount;
    for (const msg of file.messages) {
      if (msg.ruleId) {
        ruleCounts[msg.ruleId] = (ruleCounts[msg.ruleId] ?? 0) + 1;
      }
    }
  }

  const topRules = Object.entries(ruleCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([rule, count]) => ({ rule, count }));

  return { errorCount: totalErrors, warningCount: totalWarnings, fixableErrorCount: fixableErrors, topRules };
}
```

**왜 이렇게 했나요?**

ESLint는 오류를 발견하면 프로세스를 비정상 종료하므로 try/catch로 stdout을 직접 파싱합니다. `--format json` 옵션을 사용하면 규칙별 위반 수를 정확하게 집계할 수 있습니다.

### AI 분석 모듈 (`lib/ai-analyzer.ts`)

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

export async function analyzeQualityTrend(
  current: Record<string, number>,
  previous: Record<string, number>
): Promise<string> {
  const delta = Object.entries(current).map(([key, val]) => ({
    metric: key,
    current: val,
    change: val - (previous[key] ?? val),
  }));

  const prompt = `다음은 코드 품질 지표의 변화입니다:
${JSON.stringify(delta, null, 2)}

개발팀을 위해 한국어로 간단히 분석해주세요:
1. 가장 중요한 변화 2가지
2. 즉시 조치가 필요한 항목
3. 잘 개선된 점 1가지

각 항목은 2문장 이내로 작성하고, 기술적이고 실용적인 조언을 제시하세요.`;

  const message = await client.messages.create({
    model: "claude-opus-4-7",
    max_tokens: 512,
    messages: [{ role: "user", content: prompt }],
  });

  return (message.content[0] as { text: string }).text;
}
```

**왜 이렇게 했나요?**

지표의 절댓값보다 변화량(delta)을 AI에 전달하면 더 맥락 있는 분석이 나옵니다. 토큰 절약을 위해 max_tokens를 512로 제한하고, 프롬프트에서 응답 형식을 구체적으로 지정합니다.

### 대시보드 페이지 (`app/dashboard/page.tsx`)

```typescript
import { fetchSonarMetrics } from "@/lib/sonarqube";
import { collectESLintMetrics } from "@/lib/eslint-collector";
import QualityTrendChart from "@/components/QualityTrendChart";
import AIInsights from "@/components/AIInsights";
import MetricCard from "@/components/MetricCard";

export const revalidate = 300; // 5분마다 갱신

export default async function DashboardPage() {
  const [sonar, eslint] = await Promise.all([
    fetchSonarMetrics(process.env.SONAR_PROJECT_KEY!),
    collectESLintMetrics(process.env.PROJECT_PATH!),
  ]);

  const metrics = [
    { label: "버그", value: sonar.bugs, unit: "건", alert: sonar.bugs > 0 },
    { label: "취약점", value: sonar.vulnerabilities, unit: "건", alert: sonar.vulnerabilities > 0 },
    { label: "코드 커버리지", value: sonar.coverage, unit: "%", alert: sonar.coverage < 80 },
    { label: "ESLint 오류", value: eslint.errorCount, unit: "건", alert: eslint.errorCount > 0 },
    { label: "중복 코드", value: sonar.duplicated_lines_density, unit: "%", alert: sonar.duplicated_lines_density > 5 },
    { label: "기술 부채", value: Math.round(sonar.technical_debt / 60), unit: "시간" },
  ];

  return (
    <main className="p-8">
      <h1 className="text-2xl font-bold mb-6">코드 품질 대시보드</h1>
      <div className="grid grid-cols-3 gap-4 mb-8">
        {metrics.map((m) => (
          <MetricCard key={m.label} {...m} />
        ))}
      </div>
      <div className="grid grid-cols-2 gap-6">
        <QualityTrendChart />
        <AIInsights sonar={sonar} eslint={eslint} />
      </div>
    </main>
  );
}
```

### GitHub Actions 품질 게이트 (`.github/workflows/quality-check.yml`)

```yaml
name: Code Quality Gate

on:
  pull_request:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run ESLint
        run: npx eslint . --format json --output-file eslint-report.json || true

      - name: TypeScript Check
        run: npx tsc --noEmit 2>&1 | tee tsc-output.txt

      - name: Post Quality Summary
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: npx ts-node scripts/collect-metrics.ts --pr ${{ github.event.number }}
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 품질 저하 원인 파악 | `"지난 주 대비 버그가 12건 증가했습니다. 가장 가능성 있는 원인 3가지를 코드 패턴 관점에서 설명해주세요."` |
| 개선 우선순위 결정 | `"기술 부채 40시간, 커버리지 65%, 중복 코드 8% 중 이번 스프린트에서 먼저 해결해야 할 항목과 이유를 알려주세요."` |
| 팀 리포트 자동 생성 | `"이번 달 품질 지표 변화를 3문장으로 요약하고, 다음 달 목표를 제안해주세요."` |
| 규칙별 위반 분석 | `"ESLint @typescript-eslint/no-explicit-any 규칙이 34건 위반됩니다. 팀 전체에 영향을 주는 수정 전략을 제안해주세요."` |

## 확장 아이디어

- **PR별 품질 배지:** README에 실시간 품질 점수 배지 추가
- **Slack/Discord 알림:** 품질 지표가 임계치를 넘으면 자동 알림
- **팀별 뷰:** 모노레포에서 팀/서비스별 품질 트렌드 분리 추적
- **예측 분석:** 과거 트렌드로 다음 스프린트 예상 기술 부채 계산

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
