# AI 에이전트 기반 API 게이트웨이 설계 워크플로우

> 마이크로서비스 환경에서 API 게이트웨이를 설계하고 구현하는 일은 생각보다 복잡합니다. 라우팅 규칙, 인증/인가, 속도 제한, 로깅, 모니터링까지 — AI 에이전트와 함께 이 과정을 단계적으로 자동화하는 워크플로우를 정리합니다.

## 개요

API 게이트웨이는 클라이언트와 백엔드 마이크로서비스 사이에 위치하는 단일 진입점입니다. 요청 라우팅, 인증, 속도 제한, 응답 변환 등을 담당하며, 잘못 설계하면 시스템 전체의 병목이 됩니다.

AI 에이전트를 활용하면:
- 서비스 인터페이스 분석 후 라우팅 규칙 자동 생성
- OpenAPI 스펙 기반 인증/인가 정책 제안
- 트래픽 패턴에 맞는 속도 제한 설정 자동화
- 모니터링 대시보드 설정 코드 생성

이 워크플로우는 **Node.js + Express**로 직접 구현하거나, **Kong, APISIX, Traefik** 같은 오픈소스 게이트웨이 위에 설정을 입히는 두 가지 방향 모두에 적용할 수 있습니다.

## 사전 준비

- 백엔드 마이크로서비스 목록 (서비스명, 포트, 주요 엔드포인트)
- OpenAPI 스펙 파일 (있으면 좋음, 없어도 무관)
- 예상 일간 요청 수와 피크 트래픽 추정치
- 인증 방식 결정 (JWT, API Key, OAuth2 중 선택)

## Step 1: 서비스 맵 작성

먼저 AI 에이전트에게 현재 마이크로서비스 구조를 분석하게 합니다.

```bash
# CLAUDE.md에 서비스 목록을 정의
cat > CLAUDE.md << 'EOF'
# 프로젝트 컨텍스트

## 마이크로서비스 구조
- user-service: localhost:3001 (회원 관리)
- product-service: localhost:3002 (상품 관리)
- order-service: localhost:3003 (주문 처리)
- notification-service: localhost:3004 (알림 발송)

## 요구사항
- 인증: JWT 기반
- 속도 제한: 일반 사용자 100 req/min, 프리미엄 1000 req/min
- 로깅: 모든 요청/응답 기록 (개인정보 필드 마스킹)
EOF
```

```bash
# AI에게 라우팅 맵 초안 생성 요청
claude "위 CLAUDE.md를 읽고, 각 서비스의 주요 엔드포인트를 가정하여
API 게이트웨이 라우팅 규칙 초안을 routes.yaml 형식으로 작성해줘.
RESTful 관례를 따르고, 공개/인증 필요 엔드포인트를 구분해줘."
```

생성된 라우팅 초안 예시:

```yaml
# routes.yaml
routes:
  - path: /api/v1/auth/*
    service: user-service
    auth_required: false
    rate_limit: 20

  - path: /api/v1/users/*
    service: user-service
    auth_required: true
    rate_limit: 100

  - path: /api/v1/products/*
    service: product-service
    auth_required: false
    rate_limit: 200

  - path: /api/v1/orders/*
    service: order-service
    auth_required: true
    rate_limit: 50
```

## Step 2: 게이트웨이 코어 구현

라우팅 맵이 완성되면 AI 에이전트에게 게이트웨이 코어를 구현하게 합니다.

```bash
claude "routes.yaml를 읽고 다음 기능을 갖춘 Express 기반 API 게이트웨이를 구현해줘:
1. routes.yaml 동적 로딩
2. JWT 검증 미들웨어 (auth_required: true인 경우만)
3. http-proxy-middleware로 서비스별 프록시
4. 에러 응답 표준화"
```

구현 핵심 구조:

```javascript
// gateway.js
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const yaml = require('js-yaml');
const fs = require('fs');

const app = express();
const routes = yaml.load(fs.readFileSync('routes.yaml', 'utf8')).routes;

// 서비스 URL 맵
const SERVICE_MAP = {
  'user-service': process.env.USER_SERVICE_URL || 'http://localhost:3001',
  'product-service': process.env.PRODUCT_SERVICE_URL || 'http://localhost:3002',
  'order-service': process.env.ORDER_SERVICE_URL || 'http://localhost:3003',
};

// 라우트 동적 등록
routes.forEach(route => {
  const middlewares = [];

  if (route.auth_required) {
    middlewares.push(jwtMiddleware);
  }

  middlewares.push(
    createProxyMiddleware({
      target: SERVICE_MAP[route.service],
      changeOrigin: true,
      pathRewrite: { [`^${route.path.replace('*', '')}`]: '/' },
    })
  );

  app.use(route.path.replace('*', ''), ...middlewares);
});

app.listen(8080, () => console.log('Gateway running on :8080'));
```

## Step 3: 속도 제한 + 인증 레이어

```bash
claude "기존 gateway.js에 다음을 추가해줘:
1. express-rate-limit으로 라우트별 속도 제한
2. JWT 디코딩 후 user.tier(일반/프리미엄)에 따라 다른 limit 적용
3. Redis 기반 분산 rate limiting (redis-rate-limit 사용)
4. 429 Too Many Requests 응답에 Retry-After 헤더 포함"
```

속도 제한 미들웨어 패턴:

```javascript
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');

function createRateLimiter(baseLimit) {
  return rateLimit({
    windowMs: 60 * 1000, // 1분
    max: (req) => {
      // JWT에서 추출한 사용자 등급에 따라 limit 조정
      if (req.user?.tier === 'premium') return baseLimit * 10;
      return baseLimit;
    },
    store: new RedisStore({
      client: redisClient,
      prefix: 'rl:',
    }),
    handler: (req, res) => {
      res.status(429).json({
        error: 'Too Many Requests',
        retryAfter: Math.ceil(req.rateLimit.resetTime / 1000),
      });
    },
    standardHeaders: true,
  });
}
```

## Step 4: 로깅 + 모니터링 설정

```bash
claude "gateway.js에 요청/응답 로깅을 추가해줘:
- 요청: method, path, user_id, ip, timestamp
- 응답: status_code, latency_ms, upstream_service
- 개인정보(email, phone, password) 필드 자동 마스킹
- Prometheus 메트릭 엔드포인트 /metrics 추가
- prom-client로 요청 수, 레이턴시 히스토그램, 에러율 수집"
```

Prometheus 메트릭 예시:

```javascript
const promClient = require('prom-client');

const httpRequestDuration = new promClient.Histogram({
  name: 'gateway_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code', 'service'],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
});

const httpRequestTotal = new promClient.Counter({
  name: 'gateway_http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code', 'service'],
});

// /metrics 엔드포인트
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

## Step 5: 회로 차단기(Circuit Breaker) 패턴

다운스트림 서비스 장애 시 게이트웨이가 함께 다운되는 걸 막는 패턴입니다.

```bash
claude "opossum 라이브러리로 서비스별 Circuit Breaker를 구현해줘.
실패율 50% 초과 시 5초간 요청 차단, Half-Open 상태에서 1회 테스트 요청.
Circuit Open 시 503 응답과 함께 Fallback 메시지 반환."
```

```javascript
const CircuitBreaker = require('opossum');

function createBreaker(serviceName, proxyFn) {
  const breaker = new CircuitBreaker(proxyFn, {
    timeout: 3000,           // 3초 내 응답 없으면 실패
    errorThresholdPercentage: 50,  // 50% 실패율에서 Open
    resetTimeout: 5000,      // 5초 후 Half-Open
  });

  breaker.fallback(() => ({
    error: `${serviceName} is temporarily unavailable`,
    retryAfter: 5,
  }));

  breaker.on('open', () => {
    console.log(`Circuit OPEN: ${serviceName}`);
  });

  return breaker;
}
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `rate_limit.window` | 60초 | 속도 제한 측정 시간 윈도우 |
| `circuit.timeout` | 3000ms | 다운스트림 응답 대기 시간 |
| `circuit.errorThreshold` | 50% | Circuit Open 임계값 |
| `jwt.expiry` | 1h | JWT 토큰 유효 시간 |
| `log.maskFields` | email, phone, password | 마스킹 대상 필드 |

환경 변수로 서비스 URL을 분리하면 로컬/스테이징/프로덕션 전환이 쉬워집니다.

```bash
# .env.production
USER_SERVICE_URL=http://user-service.internal:3001
PRODUCT_SERVICE_URL=http://product-service.internal:3002
ORDER_SERVICE_URL=http://order-service.internal:3003
REDIS_URL=redis://redis-cluster:6379
JWT_SECRET=your-production-secret
```

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| 응답 지연 증가 | Redis rate limit 연결 지연 | Redis 로컬 캐시 레이어 추가 |
| 502 Bad Gateway | 다운스트림 서비스 응답 없음 | Circuit Breaker 임계값 확인 |
| JWT 검증 실패 | 시간 차이(clock skew) | `clockTolerance: 30` 옵션 추가 |
| 메모리 누수 | 프록시 연결 미정리 | `keepAlive` 설정 + 연결 타임아웃 |
| CORS 오류 | 게이트웨이 CORS 미설정 | cors 미들웨어 추가 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
