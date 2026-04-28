# Claude Code Opus 4.7 신기능 치트시트

> 2026년 4월 출시된 Opus 4.7과 함께 추가된 Claude Code 핵심 기능 — `/ultrareview`, `xhigh` effort, Dispatch, Auto Mode 확대까지 한 페이지로 정리

## Opus 4.7 핵심 수치

| 항목 | Opus 4.6 | Opus 4.7 | 변화 |
|------|---------|---------|------|
| SWE-Bench Verified | 80.8% | 87.6% | +6.8p |
| SWE-Bench Pro | 53.4% | 64.3% | +10.9p |
| 멀티홉 추론 (Graphwalks) | 38.7% | 58.6% | +19.9p |
| 컴퓨터 사용 (OSWorld) | 72.7% | 78.0% | +5.3p |
| 가격 | $5/$25 per M | $5/$25 per M | 동일 |

---

## /ultrareview — 세니어 리뷰어 시뮬레이션

```bash
# 세션 끝에 실행
/ultrareview

# 특정 파일만 리뷰
/ultrareview src/payment.ts

# PR 단위 리뷰
/ultrareview --diff HEAD~3
```

**/ultrareview가 잡아내는 것:**

| 기존 /review | /ultrareview 추가 탐지 |
|-------------|---------------------|
| 문법 오류, 타입 에러 | 미묘한 설계 결함 |
| 린트 위반 | 동시성 버그 패턴 |
| 누락된 에러 핸들링 | 성능 병목 예측 |
| 기본 보안 취약점 | 경쟁 조건(race condition) |

> `/ultrareview`는 단순 코드 검사가 아니라, "시니어가 PR 올리기 전에 확인할 것들"을 시뮬레이션합니다.

**실전 사용 패턴:**

```bash
# 기능 완성 후 → 커밋 전에 실행
git add .
/ultrareview
# 지적사항 수정 후 커밋
git commit -m "feat: add payment processor"
```

---

## Effort 슬라이더 — xhigh 기본값

Opus 4.7부터 Claude Code 기본 effort가 `high`에서 `xhigh`로 상향됩니다.

### 5단계 Effort 비교

| 레벨 | 토큰 | 응답 속도 | 적합한 상황 |
|------|------|---------|-----------|
| `low` | 최소 | 빠름 | 간단한 변수명 변경, 주석 추가 |
| `medium` | 적음 | 보통 | 함수 작성, 단순 리팩토링 |
| `high` | 중간 | 보통 | 기존 기본값, 일반 기능 개발 |
| `xhigh` | 많음 | 느림 | **신규 기본값**, 복잡한 기능 설계 |
| `max` | 최대 | 가장 느림 | 치명적 버그 분석, 보안 감사 |

```bash
# 인터랙티브 슬라이더
/effort

# 직접 지정
/effort xhigh

# 빠른 작업은 낮춰서
/effort medium
"변수명 payAmt를 paymentAmount로 바꿔줘"
```

**팁:** `max`는 함정입니다. 속도가 너무 느려져 생산성이 떨어져요. `xhigh`로 대부분의 작업을 처리하고, 아키텍처 설계나 보안 감사에만 `max`를 쓰세요.

---

## Dispatch — 프로그래밍 방식으로 태스크 실행

Dispatch는 사람 없이 Claude Code를 트리거할 수 있는 기능입니다. CI/CD 파이프라인, 스케줄러, 이벤트 훅과 연결할 수 있어요.

### 기본 사용법

```bash
# CLI로 태스크 전송
claude dispatch "모든 deprecated API를 v2로 마이그레이션하고 테스트 실행"

# 결과 파일로 저장
claude dispatch --output task-result.md \
  "CHANGELOG.md에 오늘 커밋 내역 요약 추가"
```

### GitHub Actions 통합

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Claude Code Dispatch
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          claude dispatch --effort high \
            "PR 변경사항을 검토하고 개선점을 REVIEW.md에 작성해줘"
```

### 주간 자동화 예시

```bash
#!/bin/bash
# cron: 0 9 * * 1 (매주 월요일 9시)
claude dispatch \
  "지난 주 커밋을 분석해서 기술 부채 리포트를 reports/tech-debt-$(date +%Y%m%d).md로 저장해줘"
```

---

## Auto Mode 확대 — Max 플랜도 사용 가능

기존에는 Teams, Enterprise, API에서만 사용 가능했던 Auto Mode가 **Max 플랜**으로 확대됩니다.

```bash
# Auto Mode 활성화 (사람 확인 없이 자율 실행)
/auto on

# 권한 수준 설정
/permissions set write:all read:all execute:tests
```

**Auto Mode 권장 가드레일:**

```markdown
# CLAUDE.md에 추가
## Auto Mode 제한사항
- 프로덕션 DB 직접 수정 금지
- 환경변수 파일(.env) 수정 금지
- 외부 API 실제 호출 금지 (테스트 환경만)
- 삭제 작업 전 반드시 백업 생성
```

---

## 달라진 동작 방식 (주의!)

### 지시사항 따르기 — 더 문자 그대로

```bash
# Opus 4.6: "auth 모듈 타입 개선"
# → auth + 관련 모듈들 전체 수정

# Opus 4.7: 같은 프롬프트
# → auth 모듈만 수정 (명시한 것만)

# 더 많은 범위가 필요하면 명시:
"auth 모듈과 연관된 user, session 모듈의 타입도 함께 개선해줘"
```

### 툴 호출 — 더 적게, 추론 더 많이

```bash
# Opus 4.7은 파일을 덜 열고 추론으로 처리
# 더 많은 툴 호출이 필요한 경우:
/effort xhigh  # 또는 max
```

### 응답 길이 — 작업 복잡도에 맞게

```bash
# 간단한 작업 → 짧게 답변
"README 오탈자 수정"  # 한두 줄로 답

# 복잡한 작업 → 자동으로 상세하게
"결제 시스템 아키텍처 설계해줘"  # 전체 설계 문서
```

---

## 업그레이드 체크리스트

- [ ] CLAUDE.md에 Auto Mode 제한사항 추가
- [ ] `/ultrareview`를 커밋 전 루틴에 추가
- [ ] 기존 `high` effort 워크플로우를 `xhigh`로 조정
- [ ] 반복 태스크는 Dispatch로 자동화 검토
- [ ] 지시사항을 더 명시적으로 작성 (Opus 4.7 리터럴 해석 대응)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
