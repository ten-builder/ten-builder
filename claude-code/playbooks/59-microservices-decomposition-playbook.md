# 플레이북 59: 모놀리스 → 마이크로서비스 분해 플레이북

> AI 에이전트와 함께 모놀리스를 마이크로서비스로 분해하는 단계별 플레이북 — 도메인 경계 분석, API 계약 설계, 데이터 분리, 서비스 메시 설정, 점진적 전환 전략

## 소요 시간

90-180분 (코드베이스 규모에 따라)

## 사전 준비

- 분해 대상 모놀리스 코드베이스 접근 권한
- Claude Code (또는 AI 코딩 에이전트) 설치
- Docker + docker-compose 환경
- 배포 대상 인프라 결정 (K8s, ECS, Cloud Run 등)

## Step 1: 코드베이스 분석 — 도메인 경계 찾기

먼저 AI 에이전트에게 전체 코드베이스를 분석시켜 도메인 경계를 찾게 합니다.

```
프롬프트: "이 코드베이스의 전체 디렉토리 구조와 주요 모듈을 분석해줘.
비즈니스 도메인 기준으로 자연스럽게 묶이는 그룹을 찾아서,
각 그룹의 책임 범위와 다른 그룹과의 의존 관계를 정리해줘.
DDD의 Bounded Context 관점에서 분리 기준을 제안해줘."
```

AI가 도출한 경계를 바탕으로 직접 검토합니다. 의존 관계 그래프를 확인하세요.

```bash
# 순환 의존성 확인 (Node.js 기준)
npx madge --circular src/

# Python 기준
pipdeptree --warn silence | grep -E "^\w"
```

| 확인 항목 | 판단 기준 |
|-----------|-----------|
| 순환 의존성 | 있으면 → 경계 재설정 필요 |
| 데이터베이스 테이블 공유 | 있으면 → 데이터 분리 전략 수립 필요 |
| 직접 함수 호출 빈도 | 높으면 → 이벤트 기반 통신으로 전환 검토 |

## Step 2: API 계약 설계

각 서비스 간 경계를 API 계약으로 명확히 정의합니다.

```
프롬프트: "Step 1에서 도출한 [서비스명] 경계를 기준으로
외부에 노출할 API 엔드포인트를 OpenAPI 3.0 스펙으로 작성해줘.
현재 모놀리스에서 이 도메인이 처리하는 기능만 포함하고,
다른 도메인과 통신이 필요한 부분은 이벤트 인터페이스로 표현해줘."
```

생성된 OpenAPI 스펙을 파일로 저장합니다.

```bash
mkdir -p contracts/
# AI가 생성한 스펙 저장
cat > contracts/user-service.yaml << 'EOF'
openapi: 3.0.0
info:
  title: User Service API
  version: 1.0.0
paths:
  /users/{id}:
    get:
      summary: 사용자 조회
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: 사용자 정보
EOF
```

계약 우선 개발(Contract-First)로 접근하면 나중에 서비스 간 불일치를 줄일 수 있어요.

## Step 3: Strangler Fig 패턴으로 점진적 분리

모놀리스를 한 번에 바꾸지 않고, 기능을 하나씩 분리합니다.

```
프롬프트: "현재 모놀리스의 [모듈명] 코드를 독립 서비스로 추출해줘.
1. 해당 모듈의 코드를 새 디렉토리 services/[서비스명]/ 에 복사
2. 독립 실행 가능한 main.ts (또는 main.py) 추가
3. 모놀리스의 기존 코드는 새 서비스를 HTTP로 호출하는 어댑터로 교체
4. 두 버전이 동시에 동작하도록 feature flag 추가"
```

```typescript
// 모놀리스 내부 어댑터 패턴 예시
// 기존 직접 호출 → HTTP 호출로 교체
export class UserServiceAdapter {
  private useRemote = process.env.USER_SERVICE_REMOTE === 'true';

  async getUser(id: string) {
    if (this.useRemote) {
      // 새 마이크로서비스 호출
      const res = await fetch(`${process.env.USER_SERVICE_URL}/users/${id}`);
      return res.json();
    }
    // 기존 모놀리스 내부 로직
    return this.legacyUserRepository.find(id);
  }
}
```

## Step 4: 데이터베이스 분리

서비스 간 데이터베이스 공유는 마이크로서비스의 가장 큰 걸림돌입니다.

```
프롬프트: "현재 단일 DB에서 [서비스명]이 사용하는 테이블 목록을 추출해줘.
다른 서비스의 테이블을 직접 조인하는 쿼리가 있으면 찾아서,
각 케이스마다 다음 중 어떤 전략이 적합한지 판단해줘:
1. 데이터 복제 (이벤트 기반 동기화)
2. API 게이트웨이 집계
3. CQRS 패턴 적용"
```

```yaml
# docker-compose.yml — 서비스별 독립 DB 예시
services:
  user-db:
    image: postgres:16
    environment:
      POSTGRES_DB: user_service
    volumes:
      - user-data:/var/lib/postgresql/data

  order-db:
    image: postgres:16
    environment:
      POSTGRES_DB: order_service
    volumes:
      - order-data:/var/lib/postgresql/data

volumes:
  user-data:
  order-data:
```

| 데이터 분리 전략 | 적합한 상황 | 주의점 |
|-----------------|------------|--------|
| 이벤트 기반 복제 | 최종 일관성 허용 | 중복 데이터 관리 |
| API 집계 | 실시간 조회 필요 | 지연 시간 증가 |
| CQRS | 읽기/쓰기 분리 필요 | 복잡도 상승 |

## Step 5: 서비스 간 통신 설정

동기 통신(REST/gRPC)과 비동기 통신(메시지 큐) 중 적합한 방식을 선택합니다.

```
프롬프트: "서비스 간 통신 방식을 설계해줘.
현재 [서비스A] → [서비스B] 호출 목록을 보면:
- 사용자 인증 확인: 매 요청마다 필요
- 주문 완료 후 알림 발송: 실시간 응답 불필요

각 케이스에 맞는 통신 방식과 구현 코드를 작성해줘."
```

```typescript
// 동기 통신 — gRPC 예시 (지연 시간 중요할 때)
import { createClient } from '@connectrpc/connect';
import { UserService } from './gen/user_connect';

const client = createClient(UserService, transport);
const user = await client.getUser({ id: userId });

// 비동기 통신 — 메시지 큐 예시 (결합도 낮출 때)
await eventBus.publish('order.completed', {
  orderId,
  userId,
  amount,
});
```

## Step 6: 헬스체크 & 관찰가능성 추가

각 서비스에 표준 헬스체크와 모니터링 엔드포인트를 추가합니다.

```
프롬프트: "[서비스명]에 다음을 추가해줘:
1. GET /health — 기본 헬스체크 (DB 연결 포함)
2. GET /ready — 준비 상태 체크 (K8s readiness probe용)
3. Prometheus 메트릭 엔드포인트 /metrics
4. 구조화된 로그 (JSON 형식, correlation ID 포함)"
```

```bash
# 서비스 헬스체크 확인
curl -f http://localhost:3001/health
# {"status":"ok","db":"connected","uptime":1234}
```

## 체크리스트

- [ ] 도메인 경계를 팀과 함께 검토하고 합의했다
- [ ] 각 서비스의 OpenAPI 스펙을 contracts/ 디렉토리에 저장했다
- [ ] Strangler Fig 패턴으로 feature flag 기반 점진적 전환 구현했다
- [ ] 서비스별 독립 DB를 설정하고 데이터 분리 전략을 세웠다
- [ ] 서비스 간 통신 방식(동기/비동기)을 명확히 구분했다
- [ ] 각 서비스에 헬스체크 및 모니터링 엔드포인트를 추가했다
- [ ] CI/CD 파이프라인을 서비스별로 독립 배포 가능하게 설정했다
- [ ] 로컬 개발 환경에서 모든 서비스가 docker-compose로 실행된다

## 자주 하는 실수

| 실수 | 결과 | 해결 |
|------|------|------|
| 처음부터 완벽한 경계 설정 시도 | 수개월 소요, 팀 번아웃 | Strangler Fig로 단계적 전환 |
| 서비스 간 DB 공유 유지 | 배포 결합도 해소 안됨 | 데이터 복제 또는 API 집계 |
| 모든 통신을 동기 REST로 처리 | 장애 전파, 높은 결합도 | 이벤트 기반 비동기 통신 도입 |
| 너무 많은 서비스로 분해 | 운영 복잡도 폭발 | 서비스 수 최소화, 팀 크기 고려 |

## 다음 단계

→ [플레이북 51: 팀 AI 협업 워크플로우](./51-team-ai-collaboration-workflow.md)

→ [플레이북 60: AI 에이전트 마이크로서비스 운영 패턴](./60-microservices-operations-playbook.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
