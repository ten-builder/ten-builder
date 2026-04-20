# AI 에이전트 기반 데이터 파이프라인 개발 워크플로우

> 설계부터 배포까지 — AI 에이전트로 ETL/ELT 파이프라인 전 과정을 자동화하는 실전 워크플로우

## 개요

데이터 파이프라인 개발에서 반복적인 작업이 많다. 스키마 정의, 변환 로직 작성, 테스트 케이스 생성, 배포 스크립트 관리 — 이 모든 것이 AI 에이전트가 잘 다루는 영역이다.

이 워크플로우는 Claude Code를 중심으로 Airflow, dbt, Kafka 등 현대 데이터 스택과 통합하여 파이프라인 개발 주기를 단축하는 방법을 다룬다.

## 사전 준비

- Claude Code (또는 터미널 AI 에이전트) 설치
- 데이터 스택: Airflow / dbt / Kafka 중 1개 이상
- Python 3.10+
- 소스 DB 또는 API 접근 권한

## Step 1: 요구사항 분석 — AI에게 구조 설명하기

파이프라인 구현 전, CLAUDE.md에 데이터 소스 정보를 정리해 AI 에이전트가 컨텍스트를 파악하도록 한다.

```markdown
# 데이터 파이프라인 컨텍스트

## 소스
- PostgreSQL (orders, users 테이블) → S3 → BigQuery
- 업데이트 주기: 매시간 증분 적재

## 스키마
- orders: order_id, user_id, amount, created_at, status
- users: user_id, email, created_at, country

## 목표
- 주문 집계 대시보드용 데이터 웨어하우스 구성
- SLA: 1시간 이내 데이터 반영
```

AI 에이전트에게 구조 설계를 요청한다:

```
현재 CLAUDE.md에 정의된 소스 기준으로 ETL 파이프라인 구조를 설계해줘.
Airflow DAG 구성, dbt 모델 레이어, 데이터 품질 검증 지점을 포함해서.
```

## Step 2: 스키마 정의 + 변환 로직 자동 생성

AI 에이전트로 dbt 모델을 생성한다:

```
orders 테이블의 증분 적재용 dbt 모델을 만들어줘.
- staging 레이어: 원본 그대로
- intermediate 레이어: NULL 제거, 타입 변환
- marts 레이어: 일별/국가별 주문 집계
unique_key는 order_id, 증분 기준은 created_at 사용
```

생성 결과 예시:

```sql
-- models/staging/stg_orders.sql
{{ config(materialized='incremental', unique_key='order_id') }}

SELECT
    order_id,
    user_id,
    amount::DECIMAL(10,2) AS amount,
    created_at,
    status,
    CURRENT_TIMESTAMP AS _loaded_at
FROM {{ source('postgres', 'orders') }}

{% if is_incremental() %}
WHERE created_at > (SELECT MAX(created_at) FROM {{ this }})
{% endif %}
```

## Step 3: 데이터 품질 검증 자동 생성

AI 에이전트가 스키마를 읽고 검증 규칙을 자동 생성한다:

```
stg_orders.sql을 보고 Great Expectations 또는 dbt test 기반
데이터 품질 검증 파일을 만들어줘.
NULL 체크, 범위 검증, 참조 무결성 포함.
```

```yaml
# models/staging/stg_orders.yml
models:
  - name: stg_orders
    columns:
      - name: order_id
        tests:
          - not_null
          - unique
      - name: amount
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 0"
      - name: status
        tests:
          - accepted_values:
              values: ['pending', 'completed', 'cancelled', 'refunded']
```

## Step 4: Airflow DAG 생성

```
위에서 만든 dbt 모델을 실행하는 Airflow DAG를 만들어줘.
- 매시간 실행
- staging → intermediate → marts 순서로 의존성 구성
- 실패 시 Slack 알림
- 재시도 2회
```

```python
# dags/orders_pipeline.py
from airflow.decorators import dag, task
from airflow.providers.dbt.cloud.operators.dbt import DbtCloudRunJobOperator
from datetime import datetime, timedelta

@dag(
    schedule_interval='@hourly',
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args={
        'retries': 2,
        'retry_delay': timedelta(minutes=5),
    }
)
def orders_pipeline():
    staging = DbtCloudRunJobOperator(
        task_id='run_staging',
        job_id=101,  # staging 레이어
    )
    intermediate = DbtCloudRunJobOperator(
        task_id='run_intermediate',
        job_id=102,
    )
    marts = DbtCloudRunJobOperator(
        task_id='run_marts',
        job_id=103,
    )

    staging >> intermediate >> marts

orders_pipeline()
```

## Step 5: 스키마 드리프트 감지 자동화

소스 스키마가 바뀌면 파이프라인이 조용히 깨진다. AI 에이전트로 드리프트 감지 스크립트를 만든다:

```
소스 PostgreSQL과 타겟 BigQuery 스키마를 비교해서
차이가 생기면 Slack으로 알리는 Python 스크립트를 만들어줘.
새로운 컬럼, 삭제된 컬럼, 타입 변경을 각각 감지해야 해.
```

```python
# scripts/schema_drift_detector.py
import psycopg2
from google.cloud import bigquery
import json

def get_pg_schema(conn_str: str, table: str) -> dict:
    """PostgreSQL 스키마 조회"""
    conn = psycopg2.connect(conn_str)
    cur = conn.cursor()
    cur.execute("""
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = %s
    """, (table,))
    return {row[0]: row[1] for row in cur.fetchall()}

def detect_drift(source_schema: dict, target_schema: dict) -> dict:
    """스키마 차이 감지"""
    new_cols = set(source_schema) - set(target_schema)
    removed_cols = set(target_schema) - set(source_schema)
    type_changes = {
        col: (source_schema[col], target_schema[col])
        for col in source_schema & set(target_schema)
        if source_schema[col] != target_schema[col]
    }
    return {
        'new': list(new_cols),
        'removed': list(removed_cols),
        'type_changes': type_changes
    }
```

## Step 6: 이상 탐지 + 모니터링

```
일별 주문 수와 금액이 과거 30일 평균 대비 ±30% 벗어나면
경고를 발생시키는 모니터링 쿼리를 dbt test로 만들어줘.
```

```sql
-- tests/generic/anomaly_detection.sql
{% test order_volume_anomaly(model, column_name) %}
WITH daily_stats AS (
    SELECT
        DATE(created_at) AS day,
        COUNT(*) AS daily_count,
        AVG(COUNT(*)) OVER (
            ORDER BY DATE(created_at)
            ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING
        ) AS rolling_avg
    FROM {{ model }}
    GROUP BY 1
)
SELECT day
FROM daily_stats
WHERE ABS(daily_count - rolling_avg) / NULLIF(rolling_avg, 0) > 0.3
  AND day = CURRENT_DATE - 1
{% endtest %}
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 증분 기준 컬럼 | `created_at` | 업데이트 감지 기준 |
| 재시도 횟수 | 2회 | Airflow 태스크 재시도 |
| 드리프트 감지 임계값 | ±30% | 이상 탐지 민감도 |
| 스케줄 주기 | `@hourly` | Airflow DAG 실행 주기 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 증분 적재 누락 | `created_at` 인덱스 확인, 타임존 통일 |
| dbt 테스트 실패 | `dbt test --select stg_orders` 로 개별 디버깅 |
| 스키마 드리프트 무시됨 | `_loaded_at` 메타 컬럼 추가로 적재 시점 추적 |
| Airflow DAG 실패 | `airflow tasks test` 명령으로 단위 테스트 |

## AI 활용 포인트 요약

| 단계 | AI 에이전트 활용 |
|------|----------------|
| 설계 | 소스 스키마 분석 → 레이어 구조 제안 |
| 구현 | dbt 모델, Airflow DAG 코드 자동 생성 |
| 검증 | 데이터 품질 테스트 케이스 자동 작성 |
| 모니터링 | 이상 탐지 쿼리 + 알림 스크립트 생성 |
| 유지보수 | 스키마 드리프트 감지 + PR 자동 생성 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
