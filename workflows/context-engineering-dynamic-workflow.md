# 컨텍스트 엔지니어링 실전 워크플로우 — CLAUDE.md에서 다이나믹 컨텍스트까지

> 정적 CLAUDE.md를 넘어 태스크별로 컨텍스트를 동적으로 구성하는 실전 워크플로우 — 컨텍스트 레이어 설계, 도메인별 파일 분리, 세션 간 컨텍스트 지속성, 팀 공유 전략

## 왜 컨텍스트 엔지니어링인가?

AI 코딩 에이전트 결과물이 세션마다 들쭉날쭉한 이유는 모델의 문제가 아닌 경우가 많아요. 컨텍스트가 문제입니다.

Arize AI의 실험에서 CLAUDE.md 시스템 프롬프트 최적화만으로 SWE-Bench 점수가 10% 향상됐고, Chroma Research 연구에서는 113k 토큰 전체 대화 히스토리를 주는 것보다 300토큰의 집중된 컨텍스트가 정확도 30% 높은 결과를 냈어요.

2026년 현재, 프롬프트를 잘 쓰는 것보다 **에이전트가 작동하는 정보 환경 전체를 설계**하는 것이 핵심 스킬이에요.

## 컨텍스트 4레이어 구조

Claude Code는 다음 4개 레이어로 컨텍스트를 처리해요:

| 레이어 | 파일 | 범위 | 우선순위 |
|--------|------|------|----------|
| 1. 엔터프라이즈 정책 | `~/.claude/CLAUDE.md` | 전체 머신 | 최상위 |
| 2. 프로젝트 규칙 | `{repo}/CLAUDE.md` | 레포 전체 | 높음 |
| 3. 디렉토리 규칙 | `{dir}/CLAUDE.md` | 서브 디렉토리 | 중간 |
| 4. 세션 컨텍스트 | `MEMORY.md`, 동적 주입 | 현재 태스크 | 실시간 |

정적 CLAUDE.md는 레이어 2까지예요. 다이나믹 컨텍스트는 레이어 3-4를 활용하는 패턴이에요.

## Step 1: 도메인별 CLAUDE.md 분리

레포 루트에 모든 규칙을 몰아넣으면 컨텍스트가 오염돼요. 디렉토리별로 분리하세요.

```
project/
  CLAUDE.md              # 공통: 기술스택, 코딩 컨벤션, 팀 규칙
  frontend/
    CLAUDE.md            # 프론트 전용: React 패턴, 스타일 가이드
  backend/
    CLAUDE.md            # 백엔드 전용: DB 스키마, API 규칙
  infra/
    CLAUDE.md            # 인프라 전용: IaC 패턴, 환경 변수 규칙
  MEMORY.md              # 세션 간 학습 내용 (자동 생성)
```

루트 CLAUDE.md 예시:

```markdown
# 프로젝트 컨텍스트

## 기술 스택
- Frontend: Next.js 14 App Router, TypeScript strict, Tailwind CSS
- Backend: Node.js 20, Prisma ORM, PostgreSQL 15
- 배포: Vercel (프론트), Fly.io (백엔드)

## 공통 규칙
- 함수명: camelCase, 컴포넌트: PascalCase
- 테스트: Vitest, 최소 커버리지 80%
- 커밋 메시지: Conventional Commits

## 금지 사항
- 직접 DB 쿼리 금지 (Prisma 사용)
- any 타입 금지
- console.log 프로덕션 코드 금지
```

## Step 2: 태스크별 동적 컨텍스트 주입

태스크 시작 전 관련 파일을 컨텍스트에 직접 주입하는 패턴이에요.

### 방법 1: @ 파일 첨부

```bash
# 관련 파일을 직접 참조
claude "이 API 엔드포인트를 수정해줘 @backend/routes/user.ts @backend/CLAUDE.md"

# 스키마와 함께
claude "새 테이블 마이그레이션 작성해줘 @backend/prisma/schema.prisma @docs/db-conventions.md"
```

### 방법 2: 태스크 전용 컨텍스트 파일

```markdown
# task-context.md (태스크별 임시 파일)

## 현재 태스크
결제 시스템 리팩토링 — Stripe → Toss Payments 전환

## 관련 파일
- `backend/services/payment.ts` — 현재 Stripe 구현
- `backend/types/payment.ts` — 결제 타입 정의
- `docs/toss-payments-api.md` — Toss API 스펙

## 제약 조건
- 기존 결제 데이터 마이그레이션 없음
- 신규 결제만 Toss로 처리
- Stripe 코드 즉시 삭제 금지 (6개월 유지)

## 완료 기준
- [ ] Toss 결제 생성 구현
- [ ] 웹훅 처리 구현
- [ ] 기존 테스트 통과
```

```bash
claude @task-context.md "위 계획대로 진행해줘"
```

## Step 3: 세션 간 컨텍스트 지속성

에이전트는 세션이 끝나면 기억을 잃어요. MEMORY.md로 지속성을 만드세요.

### MEMORY.md 구조

```markdown
# MEMORY.md — 프로젝트 학습 기록

마지막 업데이트: 2026-06-11

## 결정된 사항

### 아키텍처
- 2026-05-15: Redis 캐시 레이어 제거 결정 (복잡도 대비 효용 부족)
- 2026-05-28: 인증 방식을 JWT → session-based로 전환 (GDPR 대응)

### 기술 선택
- ORM: Prisma (TypeORM에서 마이그레이션 완료)
- 테스트 러너: Vitest (Jest에서 전환, 속도 3배 향상)

## 알려진 주의사항

- `user.service.ts`의 `deleteUser` 함수는 소프트 딜리트만 허용 (하드코딩된 비즈니스 규칙)
- 로컬 환경에서 결제 웹훅 테스트 시 ngrok 필요 (README 참조)
- M1 Mac에서 docker-compose 실행 시 `--platform linux/amd64` 플래그 필요

## 현재 진행 중인 태스크
- [ ] 결제 시스템 Toss Payments 전환 (이슈 #234)
- [ ] 검색 기능 Elasticsearch 7 → 8 업그레이드 (이슈 #241)
```

### MEMORY.md 자동 업데이트 패턴

```bash
# 세션 종료 시 에이전트에게 요청
claude "오늘 작업 내용을 MEMORY.md에 반영해줘. 
결정된 사항, 변경된 패턴, 주의해야 할 점을 추가해줘"
```

## Step 4: 팀 컨텍스트 공유 전략

CLAUDE.md를 Git에 커밋하면 팀 전체가 동일한 컨텍스트를 공유해요.

### 팀 컨텍스트 레이어 설계

```
# 팀 공유 (Git 관리)
CLAUDE.md            ← 모든 팀원 공통
MEMORY.md            ← 프로젝트 히스토리 공유
frontend/CLAUDE.md   ← 프론트 팀 공통
backend/CLAUDE.md    ← 백엔드 팀 공통

# 개인 설정 (.gitignore에 추가)
.claude/personal.md  ← 개인 선호 설정 (에디터, 언어 등)
```

### .gitignore 설정

```gitignore
# 개인 AI 설정
.claude/personal.md
task-context.md      # 임시 태스크 파일
```

### CI/CD에서 컨텍스트 검증

```yaml
# .github/workflows/context-check.yml
name: Context Quality Check

on:
  pull_request:
    paths:
      - 'CLAUDE.md'
      - '**/CLAUDE.md'
      - 'MEMORY.md'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check CLAUDE.md has required sections
        run: |
          required_sections=("기술 스택" "공통 규칙" "금지 사항")
          for section in "${required_sections[@]}"; do
            if ! grep -q "$section" CLAUDE.md; then
              echo "ERROR: CLAUDE.md에 '$section' 섹션이 없습니다"
              exit 1
            fi
          done
          echo "컨텍스트 검증 통과"
```

## Step 5: 다이나믹 컨텍스트 자동화

반복되는 컨텍스트 구성을 스크립트로 자동화해요.

### 컨텍스트 생성 스크립트

```bash
#!/bin/bash
# scripts/build-context.sh
# 현재 작업 디렉토리와 관련 파일을 기반으로 태스크 컨텍스트 자동 생성

TASK_DESC="${1:-현재 태스크}"
CONTEXT_FILE="task-context.md"

cat > "$CONTEXT_FILE" << EOF
# 태스크 컨텍스트 — $(date +%Y-%m-%d)

## 태스크
$TASK_DESC

## 최근 변경 파일 (48시간)
$(git diff --name-only HEAD~20 --diff-filter=M 2>/dev/null | head -10 | sed 's/^/- /')

## 관련 이슈
$(gh issue list --state open --limit 5 --json number,title --jq '.[] | "- #\(.number): \(.title)"' 2>/dev/null)

## 현재 브랜치
$(git branch --show-current)
EOF

echo "컨텍스트 파일 생성: $CONTEXT_FILE"
cat "$CONTEXT_FILE"
```

사용법:

```bash
chmod +x scripts/build-context.sh
./scripts/build-context.sh "결제 시스템 Toss 전환"
claude @task-context.md "진행해줘"
```

## 실전 패턴 요약

| 상황 | 권장 패턴 |
|------|-----------|
| 새 기능 개발 | task-context.md 생성 + @ 첨부 |
| 버그 수정 | 관련 파일 @ 첨부 + 에러 로그 첨부 |
| 레거시 파악 | MEMORY.md 업데이트 후 참조 |
| 팀 온보딩 | Git CLAUDE.md 최신화 + /powerup |
| 장기 리팩토링 | MEMORY.md에 결정 사항 지속 기록 |
| 도메인 경계 작업 | 해당 디렉토리 CLAUDE.md 우선 참조 |

## 흔한 실수

| 실수 | 올바른 접근 |
|------|------------|
| CLAUDE.md에 모든 규칙 몰아넣기 | 디렉토리별로 분리하기 |
| 오래된 규칙 방치 | 분기별 컨텍스트 리뷰 일정 잡기 |
| 전체 히스토리 주입 | 집중된 300토큰 컨텍스트 선호 |
| 개인 설정 Git에 커밋 | .gitignore로 분리하기 |
| MEMORY.md 업데이트 생략 | 세션 종료마다 업데이트 습관 들이기 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
