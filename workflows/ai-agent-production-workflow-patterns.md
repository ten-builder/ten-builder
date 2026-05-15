# AI 에이전트 프로덕션 워크플로 패턴 2026

> 팀 컨텍스트 품질을 높이고 PR 리뷰 사이클을 단축하는 실전 워크플로

## 개요

2026년 Packmind 데이터에 따르면 컨텍스트 품질을 높인 팀은:
- PR 리드타임 25% 단축
- Tech Lead 생산성 40% 향상 (주당 15시간 이상 절약)
- AI 생성 코드 재작업 60% 감소

이 워크플로는 그 핵심 패턴을 실무에 적용합니다.

## 사전 준비

- 팀 CLAUDE.md 또는 AGENTS.md 존재
- Git 훅 설정 (pre-commit 권장)
- PR 템플릿 (.github/pull_request_template.md)

## 패턴 1: 컨텍스트-퍼스트 PR 워크플로

### Step 1: PR 전 컨텍스트 준비

```bash
# AI에게 PR 컨텍스트를 명시적으로 제공
git diff main...HEAD > /tmp/pr-changes.diff

claude "다음 변경사항을 리뷰해줘.
컨텍스트:
- 프로젝트: [프로젝트명]
- 변경 목적: [이슈 번호/설명]
- 영향 범위: [변경된 모듈]
- 테스트 현황: [통과/실패]

변경 내용:
$(cat /tmp/pr-changes.diff)"
```

### Step 2: AI 사전 리뷰

AI 리뷰 요청 시 명시할 항목:

```markdown
## AI 리뷰 요청 체크리스트
- [ ] 보안 취약점 (SQL 인젝션, XSS, 인증 우회)
- [ ] 타입 안전성 (암묵적 any, null 처리)
- [ ] 에러 핸들링 (누락된 catch, 미처리 Promise)
- [ ] 성능 이슈 (N+1 쿼리, 불필요한 재렌더링)
- [ ] 코딩 컨벤션 위반
```

### Step 3: 리뷰 댓글 분류

| 댓글 유형 | AI 자동 처리 가능 | 사람 판단 필요 |
|----------|----------------|--------------|
| 포맷/스타일 | O | |
| 타입 에러 | O | |
| 로직 버그 | 일부 | O |
| 아키텍처 결정 | | O |
| 비즈니스 로직 | | O |

## 패턴 2: 팀 컨텍스트 품질 관리

### CLAUDE.md 버전 관리

```bash
# 팀 CLAUDE.md 업데이트 알림 훅
# .git/hooks/post-merge
if git diff HEAD@{1} HEAD -- CLAUDE.md | grep -q .; then
  echo "⚠️ CLAUDE.md 변경됨 — 팀 동기화 필요"
  echo "변경 내용: git diff HEAD@{1} HEAD -- CLAUDE.md"
fi
```

### 컨텍스트 드리프트 감지

주간 컨텍스트 감사 체크리스트:

- [ ] CLAUDE.md가 현재 코드베이스 구조와 일치하는가
- [ ] 더 이상 쓰지 않는 의존성이 기재되어 있지 않은가
- [ ] 팀 코딩 규칙이 최신 결정을 반영하는가
- [ ] 테스트/빌드 명령어가 정확한가

### 온보딩 컨텍스트 패킷

신규 팀원이 AI와 즉시 협업할 수 있는 문서 구성:

```
onboarding/
├── CLAUDE.md          # 프로젝트 규칙 (메인)
├── CONTEXT.md         # 도메인 지식 요약
├── ARCHITECTURE.md    # 시스템 구조
└── GOTCHAS.md         # 자주 발생하는 실수
```

## 패턴 3: AI 에이전트 게이트 CI/CD

### GitHub Actions 컨텍스트 게이트

```yaml
name: AI Context Gate
on: [pull_request]

jobs:
  context-quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: CLAUDE.md 존재 확인
        run: |
          if [ ! -f CLAUDE.md ]; then
            echo "CLAUDE.md 없음 — 컨텍스트 게이트 실패"
            exit 1
          fi
      
      - name: 컨텍스트 최신화 확인
        run: |
          # CLAUDE.md가 30일 이상 미수정이면 경고
          LAST_MODIFIED=$(git log -1 --format="%ct" -- CLAUDE.md)
          NOW=$(date +%s)
          DAYS_OLD=$(( (NOW - LAST_MODIFIED) / 86400 ))
          if [ $DAYS_OLD -gt 30 ]; then
            echo "::warning::CLAUDE.md가 ${DAYS_OLD}일 미수정"
          fi
```

## 패턴 4: 도메인별 컨텍스트 분리

대형 프로젝트에서 컨텍스트를 도메인별로 분리하는 방법:

```
프로젝트 루트/
├── CLAUDE.md              # 전체 프로젝트 공통 규칙
├── auth/
│   └── CLAUDE.md          # 인증 모듈 특화 컨텍스트
├── payments/
│   └── CLAUDE.md          # 결제 모듈 — PCI DSS 규정 포함
└── api/
    └── CLAUDE.md          # API 레이어 — 버전 관리 규칙
```

도메인별 CLAUDE.md 예시 (payments/CLAUDE.md):

```markdown
# 결제 모듈 AI 가이드라인

## 상위 컨텍스트
../CLAUDE.md 규칙을 모두 따른다.

## 결제 모듈 특화 규칙
- PCI DSS 범위 내 파일: payment-processor.ts, card-vault.ts
- 카드 번호/CVV를 절대 로그에 출력하지 않는다
- 모든 결제 API는 멱등성(idempotency) 보장 필수
- 금액 계산에 float 대신 정수(센트) 단위 사용

## 허용 자율 범위
- 읽기 전용 조회 로직
- 에러 메시지 개선

## 반드시 사람 승인
- 결제 플로우 변경
- 외부 결제 API 연동 추가/수정
```

## 성과 측정

컨텍스트 엔지니어링 도입 전후 비교:

| 지표 | 도입 전 | 도입 후 |
|------|---------|---------|
| PR 리뷰 댓글 수 | 12~20개 | 3~6개 |
| PR 머지까지 시간 | 2~3일 | 4~8시간 |
| AI 생성 코드 재작업 | 40% | 15% |
| 신규 팀원 온보딩 | 2주 | 3~5일 |

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| AI가 프로젝트 규칙 무시 | CLAUDE.md 내용 불명확 | 금지/허용 사항 명시적으로 분리 |
| 반복적 수정 요청 | 완료 기준 미정의 | 검증 가능한 완료 조건 추가 |
| 도메인 지식 오류 | 비즈니스 컨텍스트 부족 | CONTEXT.md 또는 GOTCHAS.md 보완 |
| 세션 후반 품질 저하 | 컨텍스트 오염 | /clear 후 CLAUDE.md 재주입 |

---

**더 자세한 가이드:** [가이드 63 — 컨텍스트 엔지니어링](../guides/63-context-engineering-2026.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
