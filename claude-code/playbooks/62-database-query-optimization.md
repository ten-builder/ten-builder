# 플레이북 62: AI 에이전트 데이터베이스 쿼리 최적화

> 느린 쿼리를 AI 에이전트와 함께 체계적으로 진단하고 수정하는 실전 가이드

## 소요 시간

30–60분

## 사전 준비

- PostgreSQL 또는 MySQL 접근 권한
- EXPLAIN ANALYZE 실행 권한
- Claude Code 또는 Gemini CLI 설치

---

## Step 1: 느린 쿼리 탐지

AI 에이전트에 현황 파악을 맡기기 전, 먼저 슬로우 쿼리 로그를 활성화합니다.

```sql
-- PostgreSQL: 100ms 이상 걸리는 쿼리 기록
ALTER SYSTEM SET log_min_duration_statement = 100;
SELECT pg_reload_conf();

-- 최근 슬로우 쿼리 조회 (pg_stat_statements 필요)
SELECT query, calls, total_exec_time / calls AS avg_ms,
       rows / calls AS avg_rows
FROM pg_stat_statements
WHERE total_exec_time / calls > 100
ORDER BY avg_ms DESC
LIMIT 10;
```

Claude Code에 슬로우 쿼리 목록을 붙여넣고 다음처럼 요청하세요:

```
위 쿼리들의 성능 문제 원인을 분석하고,
각 쿼리에 EXPLAIN ANALYZE를 실행할 수 있는 명령어를 생성해줘.
테이블 구조도 함께 확인해야 하면 알려줘.
```

---

## Step 2: EXPLAIN ANALYZE 분석

AI 에이전트가 실행 계획을 읽고 병목 지점을 파악합니다.

```sql
-- 분석 대상 쿼리 예시
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT o.id, u.name, SUM(oi.quantity * oi.price) AS total
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON oi.order_id = o.id
WHERE o.created_at > NOW() - INTERVAL '7 days'
GROUP BY o.id, u.name
ORDER BY total DESC
LIMIT 50;
```

EXPLAIN 결과를 AI에 전달하면 아래 항목을 분석해 줍니다:

| 패턴 | 의미 | 해결 방법 |
|------|------|----------|
| `Seq Scan on large table` | 인덱스 미사용 | 컬럼에 인덱스 추가 |
| `rows=10000 actual rows=1` | 통계 오차 | `ANALYZE` 실행 |
| `Sort: external merge` | 메모리 부족 | `work_mem` 증가 |
| `Hash Join` on millions of rows | 메모리 해시 | 인덱스 기반 NL Join 고려 |
| `Buffers: hit=0 read=9000` | 캐시 미스 | 자주 쓰는 데이터 캐시 유도 |

---

## Step 3: 인덱스 설계

분석 결과를 바탕으로 AI에게 인덱스 전략을 요청합니다.

```
다음 EXPLAIN 결과를 보고 인덱스 추가 계획을 짜줘.
테이블 크기는 orders 5000만 건, users 200만 건, order_items 2억 건이야.
읽기 쿼리가 80%, 쓰기가 20%야.
```

AI가 제안하는 일반적인 인덱스 패턴:

```sql
-- 복합 인덱스 (필터 + 정렬 컬럼 순서 중요)
CREATE INDEX CONCURRENTLY idx_orders_created_user
ON orders (created_at DESC, user_id)
WHERE created_at > '2025-01-01';  -- 파셜 인덱스로 크기 최소화

-- 커버링 인덱스 (SELECT 컬럼까지 포함)
CREATE INDEX CONCURRENTLY idx_order_items_covering
ON order_items (order_id) INCLUDE (quantity, price);

-- 인덱스 효과 즉시 확인
EXPLAIN (ANALYZE, BUFFERS)
SELECT ... -- 기존 슬로우 쿼리
```

인덱스 추가 전후 실행 시간을 AI에게 비교 분석시키세요.

---

## Step 4: 쿼리 리팩토링

인덱스만으로 해결 안 되는 경우 쿼리 자체를 개선합니다.

```sql
-- 비효율 패턴: IN 서브쿼리
SELECT * FROM orders
WHERE user_id IN (
    SELECT id FROM users WHERE signup_date > '2025-01-01'
);

-- 개선 패턴: EXISTS 또는 JOIN
SELECT o.* FROM orders o
JOIN users u ON o.user_id = u.id
WHERE u.signup_date > '2025-01-01';
```

AI에게 이렇게 요청하세요:

```
위 쿼리를 리팩토링해줘.
PostgreSQL 16 기준으로 실행 계획이 최적화되는 방향으로.
가독성도 유지해야 해.
```

---

## Step 5: 커넥션 풀 최적화

쿼리 자체가 빨라도 커넥션 병목이 생기면 응답 시간이 늘어납니다.

```bash
# PgBouncer 설정 검토 (AI에게 분석 요청)
cat /etc/pgbouncer/pgbouncer.ini
```

```ini
# pgbouncer.ini 핵심 설정
[pgbouncer]
pool_mode = transaction      # 트랜잭션 단위 풀링 (권장)
max_client_conn = 1000       # 최대 클라이언트 연결
default_pool_size = 20       # DB당 커넥션 수
min_pool_size = 5
reserve_pool_size = 10
server_idle_timeout = 600
```

현재 커넥션 현황을 AI에 넘기면 최적값을 제안합니다:

```sql
-- 현재 커넥션 상태 확인
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
SELECT wait_event_type, wait_event, count(*)
FROM pg_stat_activity
WHERE wait_event IS NOT NULL
GROUP BY wait_event_type, wait_event
ORDER BY count(*) DESC;
```

---

## 체크리스트

- [ ] `pg_stat_statements`로 슬로우 쿼리 목록 추출
- [ ] 상위 5개 쿼리에 EXPLAIN ANALYZE 실행
- [ ] AI 분석으로 Seq Scan 발생 쿼리 파악
- [ ] `CONCURRENTLY` 옵션으로 무중단 인덱스 추가
- [ ] 인덱스 추가 전후 실행 시간 비교 (최소 3회 평균)
- [ ] `ANALYZE` 실행으로 통계 갱신
- [ ] 커넥션 풀 설정 검토
- [ ] `pg_stat_user_indexes`로 미사용 인덱스 확인 및 정리

---

## 흔한 실수 피하기

| 실수 | 결과 | 해결 |
|------|------|------|
| 모든 컬럼에 인덱스 추가 | 쓰기 성능 저하 | 자주 필터링하는 컬럼에만 |
| `ANALYZE` 없이 인덱스만 추가 | 통계 오차로 잘못된 플랜 | 인덱스 후 `ANALYZE` 실행 |
| `CONCURRENTLY` 미사용 | 테이블 잠금 → 서비스 중단 | 프로덕션에서 항상 사용 |
| work_mem 과도하게 증가 | 다른 쿼리 메모리 부족 | 세션별 설정 (`SET work_mem`) |

---

## 다음 단계

→ [플레이북 57: AI 에이전트 컨텍스트 오염 방지](57-context-contamination-prevention.md)

→ [워크플로우: AI 에이전트 기반 SDLC 전 단계 자동화](../../workflows/ai-full-sdlc-automation.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
