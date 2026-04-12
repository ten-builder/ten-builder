# 플레이북 46: AI 에이전트 스키마 마이그레이션 자동화

> 데이터베이스 스키마 변경의 가장 위험한 순간을 AI로 안전하게 넘기는 법 — 마이그레이션 파일 생성부터 검증, 롤백 계획까지 자동화합니다.

## 소요 시간

30-60분 (초기 설정) / 이후 매 마이그레이션 5-10분

## 사전 준비

- AI 코딩 에이전트 (Claude Code, Cursor 등)
- ORM 도구: Prisma / Alembic / Django Migrations / Flyway 중 하나
- Git 브랜치 전략 (feature branch)
- CI/CD 파이프라인 (GitHub Actions 권장)

---

## Step 1: 스키마 변경 의도를 AI에게 명확히 전달하기

마이그레이션 자동화의 핵심은 **AI가 맥락을 이해하도록 구조화된 프롬프트**를 작성하는 것입니다.

### 프롬프트 템플릿

```
현재 스키마:
[현재 테이블 DDL 붙여넣기]

변경 목표:
- users 테이블에 `email_verified_at` 컬럼 추가 (nullable TIMESTAMP)
- 기존 데이터: email_verified = true인 레코드는 현재 시각으로 backfill

제약:
- 프로덕션 테이블, 다운타임 0
- 롤백 가능해야 함
- PostgreSQL 15 기준

Prisma migration 파일과 data backfill 스크립트를 생성해줘.
```

### AI가 생성하는 산출물

| 산출물 | 설명 |
|--------|------|
| `YYYYMMDDHHMMSS_add_email_verified_at.sql` | Up 마이그레이션 |
| `YYYYMMDDHHMMSS_add_email_verified_at.down.sql` | Down 마이그레이션 (롤백) |
| `backfill_email_verified_at.ts` | 데이터 backfill 스크립트 |
| `migration_checklist.md` | 사전/사후 검증 체크리스트 |

---

## Step 2: 제로 다운타임 패턴 적용

AI에게 **Expand-Contract 패턴** 적용을 명시적으로 요청합니다.

```bash
# 위험한 방법 (테이블 락 발생)
ALTER TABLE users RENAME COLUMN name TO full_name;

# AI가 생성하는 안전한 4단계 패턴
```

AI가 생성하는 Expand-Contract 마이그레이션:

```sql
-- Phase 1: Expand (새 컬럼 추가, 앱 코드는 두 컬럼 동시 쓰기)
ALTER TABLE users ADD COLUMN full_name TEXT;

-- Phase 2: Backfill (기존 데이터 채우기)
UPDATE users SET full_name = name WHERE full_name IS NULL;

-- Phase 3: 앱 코드 전환 (읽기를 full_name으로 전환 후 배포)

-- Phase 4: Contract (구 컬럼 제거)
ALTER TABLE users DROP COLUMN name;
```

```python
# Alembic 예시 — AI가 생성하는 upgrade/downgrade 쌍
def upgrade():
    op.add_column('users', sa.Column('full_name', sa.Text(), nullable=True))
    op.execute("UPDATE users SET full_name = name WHERE full_name IS NULL")

def downgrade():
    # 롤백 시 데이터 손실 없이 되돌리기
    op.execute("UPDATE users SET name = full_name WHERE name IS NULL")
    op.drop_column('users', 'full_name')
```

---

## Step 3: AI 자동 검증 게이트 설정

마이그레이션을 CI에 통합하여 AI가 위험한 패턴을 자동 탐지하게 합니다.

```yaml
# .github/workflows/migration-check.yml
name: Migration Safety Check

on:
  pull_request:
    paths:
      - 'prisma/migrations/**'
      - 'alembic/versions/**'
      - 'db/migrate/**'

jobs:
  ai-migration-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Detect changed migrations
        id: migrations
        run: |
          git diff --name-only origin/main | grep -E 'migrations?/' > changed_migrations.txt
          cat changed_migrations.txt

      - name: AI Safety Review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # 변경된 마이그레이션 파일을 AI에게 분석 요청
          python3 scripts/ai-migration-review.py changed_migrations.txt
```

```python
# scripts/ai-migration-review.py
# AI가 탐지하는 위험 패턴 목록

DANGEROUS_PATTERNS = [
    ("ADD COLUMN.*NOT NULL.*DEFAULT", "기본값 없는 NOT NULL 컬럼 추가 → 테이블 락"),
    ("DROP COLUMN", "컬럼 삭제 → 앱 코드 먼저 제거했는지 확인"),
    ("RENAME.*COLUMN", "컬럼 이름 변경 → Expand-Contract 패턴 사용 필요"),
    ("CREATE INDEX(?!.*CONCURRENTLY)", "CONCURRENTLY 없는 인덱스 생성 → 테이블 락"),
    ("ALTER COLUMN.*TYPE", "컬럼 타입 변경 → 전체 테이블 재작성 위험"),
]
```

---

## Step 4: 롤백 계획 자동 생성

AI에게 모든 마이그레이션마다 롤백 계획을 함께 생성하도록 지시합니다.

### CLAUDE.md 설정 예시

```markdown
## 데이터베이스 마이그레이션 규칙

마이그레이션 파일 생성 시 항상:

1. **up.sql + down.sql 쌍으로 생성** — 단독 up 마이그레이션 금지
2. **위험도 분류 포함:**
   - 🟢 LOW: nullable 컬럼 추가, 인덱스 CONCURRENTLY
   - 🟡 MEDIUM: 데이터 backfill, 컬럼 타입 변경
   - 🔴 HIGH: 컬럼/테이블 삭제, NOT NULL 추가
3. **롤백 예상 시간 명시** — 테이블 크기 × 연산 복잡도
4. **백업 명령어 포함** — `pg_dump`, `mysqldump` 등
```

### AI가 생성하는 롤백 플레이카드

```markdown
## 마이그레이션 롤백 플레이카드
생성일: 2026-04-13
마이그레이션: add_email_verified_at
위험도: 🟡 MEDIUM

### 롤백 조건
- 배포 후 에러율 > 1% 지속 시
- users 테이블 쿼리 latency 2배 이상 증가 시

### 롤백 명령
```bash
# 1. 앱 코드 이전 버전으로 롤백
git revert HEAD && git push origin main

# 2. 마이그레이션 롤백
npx prisma migrate resolve --rolled-back 20260413120000_add_email_verified_at
psql $DATABASE_URL < migrations/20260413120000_add_email_verified_at.down.sql

# 3. 검증
psql $DATABASE_URL -c "SELECT column_name FROM information_schema.columns WHERE table_name='users';"
```

예상 롤백 시간: ~2분 (데이터 손실 없음)
```

---

## Step 5: CI/CD 파이프라인 통합

```yaml
# 마이그레이션 자동 실행 파이프라인
deploy:
  steps:
    - name: Pre-migration backup
      run: |
        pg_dump $DATABASE_URL | gzip > backup_$(date +%Y%m%d%H%M%S).sql.gz
        aws s3 cp backup_*.sql.gz s3://backups/migrations/

    - name: Run migrations (dry-run)
      run: npx prisma migrate deploy --preview-feature

    - name: AI validation
      run: python3 scripts/post-migration-validate.py

    - name: Run migrations (actual)
      run: npx prisma migrate deploy

    - name: Smoke test
      run: npm run test:smoke
```

---

## 체크리스트

### 마이그레이션 전

- [ ] AI가 생성한 up/down 쌍 모두 존재 확인
- [ ] 위험도 분류 확인 (🔴 HIGH면 별도 검토)
- [ ] staging 환경에서 실제 실행 완료
- [ ] 롤백 플레이카드 준비
- [ ] 데이터베이스 백업 완료

### 마이그레이션 후

- [ ] 쿼리 latency 정상 범위 확인
- [ ] 에러 로그 이상 없음
- [ ] 영향받은 테이블 row count 일치
- [ ] 롤백 플레이카드 보관 (30일)

---

## 커스터마이징

| 항목 | 기본값 | 설명 |
|------|--------|------|
| 위험도 임계값 | 🟡 이상 → PR 리뷰 필수 | 팀 정책에 맞게 조정 |
| 백업 보관 기간 | 30일 | 규정 요건에 따라 변경 |
| dry-run 환경 | staging | 프로덕션과 동일한 데이터 볼륨 권장 |
| AI 리뷰 모델 | Claude Sonnet | 복잡한 마이그레이션은 Opus 사용 |

---

## 다음 단계

→ [플레이북 45: 커스텀 MCP 서버 빌드 및 배포](./45-custom-mcp-server-build-deploy.md)
→ [워크플로우: AI 에이전트 CI/CD 파이프라인 자동 최적화](../../workflows/ai-cicd-pipeline-optimization.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
