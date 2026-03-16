# AI 데이터베이스 마이그레이션 워크플로우

> AI 에이전트와 함께 데이터베이스 스키마 변경을 안전하게 수행하는 워크플로우 — 분석, 마이그레이션 생성, 검증, 롤백까지

## 개요

데이터베이스 스키마 변경은 잘못하면 서비스 전체가 멈추는 위험한 작업이에요. AI 코딩 도구를 사용하면 마이그레이션 스크립트 작성 속도는 빨라지지만, "빠르게 만든 마이그레이션"이 프로덕션에서 터지는 건 더 무서운 일이죠.

이 워크플로우는 AI가 마이그레이션을 생성하되, 사람이 반드시 검증하는 단계를 포함해요. 속도와 안전 사이의 균형을 잡는 게 핵심이에요.

## 사전 준비

- 마이그레이션 도구 설치 (Prisma / Knex / Flyway / Alembic 중 택 1)
- Claude Code 또는 Cursor Agent 설정
- 로컬에 테스트용 DB 인스턴스 (Docker 권장)
- Git 레포 + CI 파이프라인

## 전체 흐름

```
요구사항 분석 → 현재 스키마 파악 → 마이그레이션 생성 → 로컬 검증 → 스테이징 적용 → 프로덕션 배포
     ↑                                                              ↓
     └──────────────── 롤백 (문제 발생 시) ────────────────────────────┘
```

## Step 1: 현재 스키마 분석

AI에게 변경할 부분을 알려주기 전에, 현재 상태를 정확히 파악해요.

### 스키마 덤프

```bash
# PostgreSQL
pg_dump --schema-only --no-owner mydb > schema_current.sql

# MySQL
mysqldump --no-data --routines mydb > schema_current.sql

# SQLite
sqlite3 mydb.db .schema > schema_current.sql
```

### AI에게 분석 요청

```
현재 스키마를 분석해줘.
- 테이블 간 관계 (FK)
- 인덱스 현황
- 잠재적인 성능 병목 (N+1 가능 지점)

파일: schema_current.sql
```

AI가 ER 다이어그램 형태의 텍스트나 테이블 관계를 정리해주면, 변경 범위를 미리 가늠할 수 있어요.

## Step 2: 마이그레이션 스크립트 생성

### 변경 요구사항 프롬프트

```
users 테이블에 subscription_tier (enum: free, pro, enterprise) 컬럼을 추가하고,
기존 사용자는 모두 'free'로 설정해.
인덱스도 필요하면 추가하고, 롤백 스크립트도 함께 만들어줘.

사용 중인 마이그레이션 도구: Prisma
DB: PostgreSQL 15
```

### Prisma 예시 출력

```prisma
// schema.prisma 변경
model User {
  id               Int              @id @default(autoincrement())
  email            String           @unique
  name             String?
  subscriptionTier SubscriptionTier @default(FREE)
  createdAt        DateTime         @default(now())
  updatedAt        DateTime         @updatedAt

  @@index([subscriptionTier])
}

enum SubscriptionTier {
  FREE
  PRO
  ENTERPRISE
}
```

```bash
# 마이그레이션 생성
npx prisma migrate dev --name add-subscription-tier
```

### Knex 예시 출력

```javascript
// migrations/20260316_add_subscription_tier.js
exports.up = function(knex) {
  return knex.schema.alterTable('users', (table) => {
    table.enum('subscription_tier', ['free', 'pro', 'enterprise'])
      .defaultTo('free')
      .notNullable();
    table.index(['subscription_tier']);
  });
};

exports.down = function(knex) {
  return knex.schema.alterTable('users', (table) => {
    table.dropIndex(['subscription_tier']);
    table.dropColumn('subscription_tier');
  });
};
```

### Alembic (Python) 예시 출력

```python
# alembic/versions/20260316_add_subscription_tier.py
from alembic import op
import sqlalchemy as sa

def upgrade():
    subscription_tier = sa.Enum('free', 'pro', 'enterprise',
                                 name='subscriptiontier')
    subscription_tier.create(op.get_bind())

    op.add_column('users',
        sa.Column('subscription_tier', subscription_tier,
                  server_default='free', nullable=False))
    op.create_index('ix_users_subscription_tier',
                    'users', ['subscription_tier'])

def downgrade():
    op.drop_index('ix_users_subscription_tier', 'users')
    op.drop_column('users', 'subscription_tier')
    sa.Enum(name='subscriptiontier').drop(op.get_bind())
```

## Step 3: AI 생성 마이그레이션 검증 체크리스트

AI가 만든 마이그레이션은 반드시 아래 항목을 직접 확인해요.

| 검증 항목 | 확인 방법 | 위험도 |
|-----------|----------|--------|
| 롤백 스크립트 존재 | `down` 함수 확인 | 높음 |
| 데이터 손실 여부 | 컬럼 삭제/타입 변경 확인 | 높음 |
| 잠금(Lock) 시간 | 대형 테이블 ALTER 여부 | 높음 |
| 기본값 설정 | NOT NULL + DEFAULT 조합 | 중간 |
| 인덱스 영향 | 대형 테이블 인덱스 생성 | 중간 |
| FK 제약조건 | 순환 참조, 캐스케이드 | 중간 |
| 기존 데이터 호환 | 데이터 변환 필요 여부 | 중간 |

### AI에게 검증 요청

```
이 마이그레이션을 프로덕션에 적용할 때 위험한 부분을 분석해줘.
- users 테이블에 현재 500만 행이 있어
- 서비스 중단 없이 적용해야 해
- PostgreSQL 15 사용 중
```

## Step 4: 대형 테이블 마이그레이션 전략

100만 행 이상 테이블은 일반 ALTER가 위험해요. AI에게 단계적 마이그레이션을 요청하세요.

### 패턴 1: Expand-Contract (권장)

```sql
-- Phase 1: Expand (컬럼 추가, 서비스 영향 없음)
ALTER TABLE users
  ADD COLUMN subscription_tier VARCHAR(20) DEFAULT 'free';

-- Phase 2: Migrate (배치로 기존 데이터 업데이트)
UPDATE users SET subscription_tier = 'free'
  WHERE subscription_tier IS NULL
  LIMIT 10000;  -- 배치 단위

-- Phase 3: Contract (제약조건 추가)
ALTER TABLE users
  ALTER COLUMN subscription_tier SET NOT NULL;
```

### 패턴 2: Shadow Table

```sql
-- 1. 새 구조의 테이블 생성
CREATE TABLE users_v2 (LIKE users INCLUDING ALL);
ALTER TABLE users_v2 ADD COLUMN subscription_tier VARCHAR(20);

-- 2. 트리거로 실시간 동기화
CREATE TRIGGER sync_users_v2
  AFTER INSERT OR UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION sync_to_users_v2();

-- 3. 기존 데이터 배치 복사
-- 4. 애플리케이션을 users_v2로 전환
-- 5. 원본 테이블 제거
```

### AI 프롬프트

```
users 테이블(500만 행)에 subscription_tier 컬럼을 추가해야 해.
다운타임 없이 적용하는 Expand-Contract 패턴의 마이그레이션 스크립트를 만들어줘.
배치 사이즈와 예상 소요 시간도 알려줘.
```

## Step 5: 로컬 테스트

### Docker로 테스트 DB 실행

```bash
# PostgreSQL 테스트 인스턴스
docker run -d --name test-db \
  -e POSTGRES_PASSWORD=test \
  -p 5433:5432 \
  postgres:15

# 현재 스키마 복원
psql -h localhost -p 5433 -U postgres -f schema_current.sql
```

### 마이그레이션 적용 + 롤백 테스트

```bash
# 마이그레이션 적용
DATABASE_URL="postgresql://postgres:test@localhost:5433/postgres" \
  npx prisma migrate deploy

# 롤백 테스트 (Knex 예시)
DATABASE_URL="postgresql://postgres:test@localhost:5433/postgres" \
  npx knex migrate:rollback

# 다시 적용해서 정상 동작 확인
DATABASE_URL="postgresql://postgres:test@localhost:5433/postgres" \
  npx knex migrate:latest
```

### AI에게 테스트 데이터 요청

```
subscription_tier 컬럼의 엣지 케이스를 테스트할 시드 데이터를 만들어줘.
- 각 tier별 사용자 10명씩
- NULL 값이 있는 레거시 데이터
- 특수 문자가 포함된 이메일
```

## Step 6: CI 파이프라인 통합

### GitHub Actions 마이그레이션 체크

```yaml
# .github/workflows/migration-check.yml
name: Migration Safety Check
on:
  pull_request:
    paths:
      - 'prisma/migrations/**'
      - 'migrations/**'
      - 'alembic/versions/**'

jobs:
  migration-check:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Apply migrations
        run: npx prisma migrate deploy
        env:
          DATABASE_URL: postgresql://postgres:test@localhost:5432/postgres

      - name: Rollback test
        run: npx prisma migrate reset --force
        env:
          DATABASE_URL: postgresql://postgres:test@localhost:5432/postgres

      - name: Check for dangerous operations
        run: |
          # DROP TABLE, DROP COLUMN 감지
          if grep -rn "DROP TABLE\|DROP COLUMN\|TRUNCATE" prisma/migrations/; then
            echo "::warning::위험한 작업이 감지되었습니다. 반드시 수동 검토하세요."
          fi
```

## 롤백 전략

| 상황 | 전략 | 명령어 예시 |
|------|------|------------|
| 마이그레이션 직후 발견 | 즉시 롤백 | `npx prisma migrate rollback` |
| 데이터 변환 후 발견 | 백업에서 복원 | `pg_restore -d mydb backup.dump` |
| 프로덕션 적용 후 발견 | Fix-forward 우선 | 새 마이그레이션으로 수정 |
| 전면 장애 | DB 스냅샷 복원 | 클라우드 콘솔에서 복원 |

### 롤백 판단 기준

```
다음 중 하나라도 해당되면 즉시 롤백:
- 에러율이 배포 전 대비 5배 이상 증가
- 평균 응답 시간이 2배 이상 증가
- 데이터 정합성 오류 발생
- 주요 기능이 동작하지 않음
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 배치 사이즈 | 10,000 | 대형 테이블 배치 업데이트 단위 |
| 잠금 타임아웃 | 5초 | `SET lock_timeout = '5s'` |
| 롤백 테스트 | 필수 | CI에서 자동 실행 |
| 백업 방식 | 스냅샷 | 마이그레이션 전 자동 백업 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 마이그레이션 충돌 | `prisma migrate resolve` 또는 수동 merge |
| 잠금 대기 초과 | 배치 사이즈 줄이고, 트래픽 낮은 시간에 실행 |
| 롤백 실패 | 백업 스냅샷에서 직접 복원 |
| 데이터 타입 불일치 | 중간 변환 단계 추가 (VARCHAR → INT는 직접 불가) |
| FK 제약조건 오류 | 참조 테이블 먼저 마이그레이션 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
