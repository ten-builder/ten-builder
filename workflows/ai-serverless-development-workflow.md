# AI 에이전트 기반 서버리스 앱 개발 워크플로우

> 설계부터 배포까지 — Cold Start 최소화, 비용 예측, 로컬 개발 환경 구성까지 한번에 정리

## 왜 서버리스인가

서버리스는 "서버 없음"이 아니라 "서버 관리 없음"입니다. 2026년 기준으로 AWS Lambda의 SnapStart와 Vercel의 Fluid Compute 덕분에 Cold Start 문제가 사실상 해결됐고, AI 에이전트를 붙이면 인프라 설정 시간도 크게 줄일 수 있습니다.

이 워크플로우는 **신규 서버리스 프로젝트를 AI 에이전트와 함께 처음부터 구성하는 전 과정**을 다룹니다.

---

## 사전 준비

- Node.js 22+ 또는 Python 3.13+
- AWS CLI + SAM CLI (Lambda 경로) 또는 Vercel CLI (Vercel 경로)
- Claude Code 또는 Gemini CLI
- 프로젝트 루트에 `CLAUDE.md` 초안

---

## Step 1: 플랫폼 선택 기준 정의

AI 에이전트에게 요구사항을 설명하고 플랫폼 추천을 받습니다.

```
프롬프트:
"다음 요구사항에 맞는 서버리스 플랫폼을 추천해줘:
- 예상 월 호출 수: 50만 건
- 최대 실행 시간: 30초
- 주 언어: TypeScript
- 팀 규모: 3명
- 프론트엔드: Next.js 기반"
```

| 조건 | Vercel Functions | AWS Lambda |
|------|-----------------|------------|
| Next.js 통합 | 최적 (Fluid Compute) | 별도 설정 필요 |
| 실행 시간 제한 | 최대 5분 (Pro) | 최대 15분 |
| Cold Start | ~50ms (Fluid) | 200ms → SnapStart 시 50ms |
| 로컬 개발 | `vercel dev` | SAM CLI / LocalStack |
| AI 에이전트 통합 | Vercel AI SDK 기본 지원 | Bedrock SDK 별도 설정 |

---

## Step 2: 프로젝트 스캐폴딩

### Vercel Functions 경로

```bash
# AI 에이전트로 초기 구조 생성
npx create-next-app@latest my-serverless-app --typescript --app
cd my-serverless-app

# 함수 디렉토리 구조 설정
mkdir -p app/api/{users,products,webhooks}
```

AI 에이전트에게 `CLAUDE.md` 작성을 위임합니다.

```
프롬프트:
"이 프로젝트의 CLAUDE.md를 작성해줘.
서버리스 함수 파일 위치: app/api/**
타임아웃 기준: 10초 이상이면 경고
콜드 스타트 최소화 원칙: 의존성은 함수 외부에서 초기화"
```

### AWS Lambda 경로

```bash
sam init --runtime nodejs22.x --name my-lambda-app
cd my-lambda-app

# template.yaml에 SnapStart 활성화
```

```yaml
# template.yaml 핵심 설정
Globals:
  Function:
    Timeout: 30
    MemorySize: 512
    SnapStart:
      ApplyOn: PublishedVersions  # Cold Start ~200ms → ~50ms

Resources:
  UserFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/users.handler
      Runtime: nodejs22.x
      SnapStart:
        ApplyOn: PublishedVersions
      Environment:
        Variables:
          NODE_OPTIONS: "--enable-source-maps"
```

---

## Step 3: Cold Start 최소화 패턴

서버리스 함수에서 Cold Start를 줄이는 핵심 패턴입니다.

### 의존성 초기화 분리

```typescript
// 잘못된 패턴 - 매 요청마다 초기화
export const handler = async (event: APIGatewayEvent) => {
  const db = new PrismaClient(); // Cold Start 시 연결 지연
  const result = await db.user.findMany();
  return { statusCode: 200, body: JSON.stringify(result) };
};

// 올바른 패턴 - 함수 외부에서 한 번 초기화
const db = new PrismaClient(); // 컨테이너 재사용 시 재초기화 없음

export const handler = async (event: APIGatewayEvent) => {
  const result = await db.user.findMany();
  return { statusCode: 200, body: JSON.stringify(result) };
};
```

### 번들 크기 최적화

AI 에이전트에게 번들 분석을 요청합니다.

```bash
# Lambda 번들 크기 분석
npx esbuild src/handlers/users.ts --bundle --analyze

# 목표: 핵심 함수 10MB 이하
```

| 전략 | 절감 효과 |
|------|----------|
| Tree-shaking (esbuild) | 40~60% 감소 |
| AWS SDK v3 모듈화 | 추가 30% 감소 |
| 레이어로 공통 의존성 분리 | 배포 속도 향상 |

---

## Step 4: 로컬 개발 환경 구성

### Vercel 로컬 개발

```bash
# 환경 변수 설정
vercel env pull .env.local

# 로컬 서버 실행 (실제 Vercel 런타임과 동일)
vercel dev

# AI 에이전트와 함께 API 테스트
curl http://localhost:3000/api/users
```

### AWS 로컬 개발

```bash
# LocalStack으로 AWS 서비스 로컬 에뮬레이션
docker run -d -p 4566:4566 localstack/localstack

# SAM 로컬 실행
sam local start-api --env-vars env.json

# 함수 단독 테스트
sam local invoke UserFunction --event events/user-get.json
```

---

## Step 5: AI 에이전트 통합

서버리스 함수 내에서 AI 에이전트를 호출하는 패턴입니다.

### Vercel AI SDK 스트리밍

```typescript
// app/api/chat/route.ts
import { streamText } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';

export const runtime = 'nodejs'; // Edge가 아닌 Node.js 런타임 사용
export const maxDuration = 60;   // 스트리밍을 위해 타임아웃 확장

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: anthropic('claude-sonnet-4-5'),
    messages,
    maxTokens: 2048,
  });

  return result.toDataStreamResponse();
}
```

### Lambda + Bedrock

```typescript
// src/handlers/ai-process.ts
import { BedrockRuntimeClient, InvokeModelCommand } from '@aws-sdk/client-bedrock-runtime';

// 클라이언트는 함수 외부에서 초기화
const bedrock = new BedrockRuntimeClient({ region: 'us-east-1' });

export const handler = async (event: SQSEvent) => {
  for (const record of event.Records) {
    const payload = JSON.parse(record.body);

    const command = new InvokeModelCommand({
      modelId: 'anthropic.claude-sonnet-4-5-v1:0',
      body: JSON.stringify({
        messages: [{ role: 'user', content: payload.prompt }],
        max_tokens: 1024,
      }),
    });

    const response = await bedrock.send(command);
    // 결과 처리...
  }
};
```

---

## Step 6: 비용 예측 및 모니터링

AI 에이전트에게 비용 추정을 요청합니다.

```
프롬프트:
"다음 Lambda 함수의 월별 예상 비용을 계산해줘:
- 월 호출 수: 100만 건
- 평균 실행 시간: 800ms
- 메모리: 512MB
- 리전: ap-northeast-2 (서울)"
```

### 비용 최적화 체크리스트

| 항목 | Vercel | AWS Lambda |
|------|--------|-----------|
| 유휴 비용 | 없음 (Fluid) | 없음 |
| 콜드 스타트 비용 | Fluid 기준 활성 CPU만 | SnapStart 사용 시 절감 |
| 메모리 설정 | 1GB 기본, 조정 불가 | 128MB~10GB 자유 조정 |
| 예산 알림 | Dashboard | CloudWatch + SNS |

```bash
# CloudWatch 비용 알림 설정 (AI 에이전트 생성)
aws cloudwatch put-metric-alarm \
  --alarm-name "LambdaCostAlert" \
  --metric-name "EstimatedCharges" \
  --namespace "AWS/Billing" \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions "arn:aws:sns:ap-northeast-2:ACCOUNT_ID:billing-alert"
```

---

## Step 7: 배포 파이프라인 자동화

```yaml
# .github/workflows/deploy.yml (AI 에이전트 생성)
name: Deploy Serverless

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Deploy to Vercel
        run: vercel deploy --prod --token=${{ secrets.VERCEL_TOKEN }}
        # AWS Lambda의 경우: sam deploy --no-confirm-changeset
```

---

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| 타임아웃 오류 | 실행 시간 초과 | `maxDuration` 늘리거나 비동기 큐 처리로 전환 |
| Cold Start 느림 | 번들 크기 큼 | esbuild tree-shaking, 레이어 분리 |
| 메모리 초과 | 대용량 데이터 처리 | 스트리밍 처리, 청크 분할 |
| DB 연결 고갈 | 함수마다 새 연결 | PgBouncer, RDS Proxy 사용 |
| 비용 급증 | 무한 루프 또는 높은 호출 수 | CloudWatch 알림, 동시 실행 제한 |

---

## 체크리스트

- [ ] `CLAUDE.md`에 서버리스 규칙 정의 (타임아웃, 의존성 초기화 위치)
- [ ] Cold Start 최소화 — 함수 외부 의존성 초기화
- [ ] 번들 크기 10MB 이하 확인
- [ ] 로컬 개발 환경 (`vercel dev` 또는 SAM local) 검증
- [ ] 비용 알림 설정 ($50 기준)
- [ ] CI/CD 파이프라인 자동 배포 구성

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
