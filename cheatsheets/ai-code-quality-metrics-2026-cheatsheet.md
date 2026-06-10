# AI 에이전트 코드 품질 지표 치트시트 2026 — DORA부터 AI 전용 메트릭까지

> AI 코딩 에이전트가 코드의 41%를 생성하는 지금, 팀 품질을 제대로 측정하려면 기존 DORA 4대 지표에 AI 특화 확장 메트릭을 더해야 합니다. 한 페이지로 정리했습니다.

## DORA 기본 4대 지표 — AI 시대의 해석 변화

| 지표 | 정의 | 엘리트 기준 | AI 시대 주의사항 |
|------|------|-------------|-----------------|
| **Deployment Frequency** | 프로덕션 배포 빈도 | 하루 여러 번 | AI로 인한 양 증가가 품질 하락 마스킹 가능 |
| **Lead Time for Changes** | 코드 커밋 → 프로덕션까지 시간 | 1시간 미만 | AI PR은 빠르지만 리뷰 부담 증가 |
| **Change Failure Rate** | 배포 후 롤백/핫픽스 필요 비율 | 5% 미만 | 2026 DORA 리포트: AI 팀에서 7.2% 상승 |
| **MTTR** | 인시던트 발생 → 복구 시간 | 1시간 미만 | AI 생성 코드의 버그는 진단이 더 어렵다 |

---

## AI 확장 메트릭 4가지

### 1. AI Code Share (%)

```
AI Code Share = AI 에이전트 생성 커밋 수 / 전체 커밋 수 × 100
```

| 수준 | 범위 | 의미 |
|------|------|------|
| 초기 도입 | 10-20% | 실험 단계, 생산성 임팩트 미미 |
| 적정 활용 | 40-60% | 2026년 선도 팀 평균 |
| 과도 의존 | 70%+ | 컨텍스트 품질 관리 강화 필요 |

### 2. Code Churn Rate (%)

```
Code Churn Rate = 14일 내 삭제/대폭 수정된 라인 / 추가된 전체 라인 × 100
```

| 수준 | 범위 | 의미 |
|------|------|------|
| 건강 | 15% 미만 | AI가 안정적인 코드 생성 |
| 주의 | 15-30% | CLAUDE.md 컨텍스트 보강 필요 |
| 위험 | 30%+ | AI 오용 또는 요구사항 불명확 — 2026년 평균 AI 팀은 비AI 팀의 2배 수준 |

### 3. AI-Assisted PR Cycle Time 격차

```
격차 = (Non-AI PR 사이클 타임 - AI-Assisted PR 사이클 타임) / Non-AI PR 사이클 타임 × 100
```

| 결과 | 해석 |
|------|------|
| 18-24% 단축 | 정상 범위 (2026년 엘리트 팀 기준) |
| 단축 없음 | AI PR이 리뷰 부담 가중 → 리뷰 온보딩 필요 |
| 오히려 증가 | 컨텍스트 품질 문제 또는 대형 PR |

### 4. AI-Generated Change Failure Rate

```
AI CFR = AI 생성 코드로 인한 핫픽스 수 / AI 배포 수 × 100
```

**판단 기준:**
- AI CFR ≤ Non-AI CFR × 1.2 → 정상 (허용 범위)
- AI CFR > Non-AI CFR × 1.5 → 코드 검증 게이트 강화 필요
- AI CFR > Non-AI CFR × 2.0 → AI 워크플로우 전면 재검토

---

## 빠른 측정 명령어

```bash
# Code Churn Rate (최근 30일)
git log --since="30 days ago" --format="" --numstat | \
  awk 'NF==3 {added+=$1; deleted+=$2} END {printf "Churn: %.1f%%\n", deleted/added*100}'

# AI Code Share (브랜치명 기반 추정)
TOTAL=$(git log --since="30 days ago" --oneline | wc -l)
AI=$(git log --since="30 days ago" --format="%D" | grep -cE "content/|ai/|claude/|agent/")
echo "AI Code Share: $(( AI * 100 / TOTAL ))%"

# PR Cycle Time (평균, 초 단위)
gh pr list --state closed --limit 100 \
  --json createdAt,mergedAt \
  --jq '[.[] | select(.mergedAt != null) |
    ((.mergedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) -
     (.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime)) / 3600
  ] | add/length | . * 10 | round / 10 | tostring + " hours avg"'
```

---

## 지표 해석 조합

| 패턴 | AI Code Share | Code Churn | Change Failure Rate | 대응 |
|------|---------------|------------|---------------------|------|
| 이상적 | 40-60% | <15% | ≤ Non-AI × 1.2 | 현상 유지 |
| 품질 저하 신호 | 60%+ | 30%+ | 상승 | CLAUDE.md 재점검, PostToolUse Hook 추가 |
| 속도만 증가 | 60%+ | 30%+ | 낮음 | 코드 내구성 모니터링 강화 |
| 도입 정체 | <20% | 낮음 | 낮음 | 팀 AI 온보딩 확대 |

---

## 측정 도구 추천

| 도구 | 측정 가능 지표 | 비용 |
|------|---------------|------|
| **Swarmia** | AI Code Share, Lead Time, 자율성 레벨 | 유료 |
| **LinearB** | DORA 전체 + AI 기여 | 유료 |
| **DX Data** | AI Code Share, Complexity-Adjusted Throughput | 유료 |
| **GitHub Insights** | Deployment Frequency, Lead Time (기본) | 무료 (Enterprise) |
| **직접 구현** | git log + gh CLI | 무료 |

---

## 자가 진단 체크리스트

- [ ] 팀의 AI Code Share 목표값을 설정했는가?
- [ ] Code Churn Rate를 주간 모니터링하고 있는가?
- [ ] AI PR과 일반 PR의 사이클 타임을 분리해서 추적하는가?
- [ ] AI 생성 코드로 인한 인시던트를 별도로 레이블링하는가?
- [ ] 지표 기준값(Baseline)을 AI 도입 전 시점으로 기록해뒀는가?

---

**관련 워크플로우:** [workflows/ai-dora-metrics-measurement-workflow.md](../workflows/ai-dora-metrics-measurement-workflow.md)

**에이전틱 테스팅으로 Change Failure Rate 개선:** [guides/104-agentic-testing-automation-guide-2026.md](../guides/104-agentic-testing-automation-guide-2026.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
