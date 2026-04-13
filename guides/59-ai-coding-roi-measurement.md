# AI 코딩 도구 ROI 측정 가이드 — 속도만 보면 절반은 틀린다

> 84%가 쓰고, 29%만 신뢰하는 AI 코딩 도구. 팀이나 조직에 실제로 얼마나 도움이 되는지 어떻게 알 수 있을까요? 이 가이드는 라인 수나 커밋 수 같은 허수 지표가 아니라, 실제 생산성 변화를 측정하는 방법을 다룹니다.

## 왜 지금 ROI 측정이 중요한가

AI 코딩 도구 도입 비용은 더 이상 무시할 수 없는 수준입니다. 개발자 1인당 월 $20~100의 구독료, 사용량 기반 API 비용, 팀 교육 비용까지 합산하면 10인 팀 기준 연간 수천만 원에 달합니다.

문제는 대부분의 팀이 "빠르게 코드 짠 것 같다"는 주관적 느낌으로 투자를 정당화한다는 점입니다. 반면 ROI를 체계적으로 추적하는 팀은 **건강한 ROI 2.5~3.5배, 상위 팀은 4~6배**를 달성하고 있습니다.

## 절대 쓰면 안 되는 지표

| 허수 지표 | 왜 틀리나 |
|----------|----------|
| 라인 수(LOC) | AI는 불필요한 코드도 쉽게 생성 — 오히려 늘어나면 위험 |
| 커밋 횟수 | 작은 커밋이 많아진 것일 뿐, 실제 기여와 무관 |
| PR 생성 속도 | 리뷰를 통과 못 하면 의미 없음 |
| 완료된 티켓 수 | 복잡도 가중치 없이는 허수 |

속도 지표만 추적하면 AI가 기술 부채를 쌓는 방향으로 최적화될 수 있습니다.

## 측정해야 하는 진짜 지표

### 1. 변경 리드타임 (Lead Time for Changes)

```
리드타임 = 코드 커밋 시간 - PR 머지 시간
```

AI 도입 전후를 비교합니다. 이상적인 개선은 30~50% 단축입니다.

```bash
# GitHub CLI로 최근 30일 리드타임 측정
gh pr list --state closed --limit 50 --json createdAt,mergedAt \
  --jq '[.[] | select(.mergedAt != null) | 
    {lead_days: (((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 86400)}
  ] | map(.lead_days) | add / length | . * 10 | round / 10 | "\(.) days average"'
```

### 2. 배포 빈도 (Deployment Frequency)

AI 코딩 도구를 제대로 쓰는 팀은 릴리즈 사이클이 짧아집니다. 주 1회 → 일 1회로 개선되면 팀 수준의 변화입니다.

### 3. 결함율 (Post-Release Defect Rate)

```bash
# 배포 후 N일 이내 생성된 버그 티켓 비율
# AI 도입 전 3개월 vs 후 3개월 비교
```

AI 도입 후 결함율이 올라간다면 리뷰 프로세스에 문제가 있는 것입니다.

### 4. PR 크기 & 리뷰 시간

```bash
# 평균 PR diff 크기 (줄 수)
gh pr list --state closed --limit 50 --json additions,deletions \
  --jq 'map(.additions + .deletions) | add / length | "Average PR size: \(round) lines"'
```

AI를 쓸수록 PR이 커지는 경향이 있습니다. 큰 PR은 리뷰 품질을 떨어뜨리므로 **PR 하나당 200줄 이하**를 목표로 합니다.

### 5. 변경 실패율 (Change Failure Rate)

핫픽스, 롤백, 긴급 패치 빈도를 추적합니다. AI 생성 코드의 신뢰도를 판단하는 핵심 지표입니다.

## 측정 대시보드 설계

### 월간 AI ROI 대시보드 구성

```markdown
## AI 코딩 도구 월간 리포트 (YYYY-MM)

### 속도 지표
- 평균 리드타임: X일 (전월 대비 ▲/▼)
- 배포 횟수: N회 (전월 대비 ▲/▼)

### 품질 지표
- 결함율: N% (전월 대비 ▲/▼)
- 변경 실패율: N% (전월 대비 ▲/▼)

### 비용 지표
- AI 도구 비용: $N/인
- 추정 절감 시간: N시간/인

### 종합 ROI
- 비용: $N
- 추정 절감 가치: $N (시간 × 시급)
- ROI 배수: N.Nx
```

### 간단한 트래킹 스크립트

```bash
#!/bin/bash
# ai-roi-check.sh — 주간 지표 수집
REPO="your-org/your-repo"

echo "=== 최근 30일 지표 ==="

# 리드타임 평균
echo "리드타임:"
gh pr list --repo "$REPO" --state closed --limit 30 \
  --json createdAt,mergedAt \
  --jq '[.[] | select(.mergedAt != null) | 
    (((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 3600)
  ] | add / length | "  평균 \(round)시간"'

# PR 크기 평균
echo "PR 크기:"
gh pr list --repo "$REPO" --state closed --limit 30 \
  --json additions,deletions \
  --jq 'map(.additions + .deletions) | add / length | "  평균 \(round)줄"'
```

## 팀 규모별 적용 가이드

| 팀 규모 | 측정 주기 | 핵심 지표 | 도구 |
|---------|---------|---------|-----|
| 1~3인 | 월간 | 리드타임, 결함율 | GitHub 통계 |
| 4~10인 | 격주 | 5가지 DORA 지표 | LinearB, Axify |
| 10인+ | 주간 | 전체 + 비용 분석 | Jellyfish, DX |

## ROI 계산 예시

```
팀 규모: 5명
AI 도구 비용: $100/인/월 = $500/월
개발자 평균 시급: $50/시간
AI로 절약된 시간: 2시간/인/일 = 10시간/일 = 200시간/월
절약 가치: 200시간 × $50 = $10,000/월

ROI = ($10,000 - $500) / $500 = 19배
→ 과장된 추정. 실제는 리뷰, 수정, 재검토 시간 포함 시 2~4배가 현실적.
```

**교훈:** 절약 시간에서 AI 코드 리뷰 + 수정 시간을 반드시 빼야 합니다.

## 체크리스트

- [ ] 허수 지표(LOC, 커밋 수)를 기준에서 제거했나
- [ ] AI 도입 전 3개월치 베이스라인 데이터 확보했나
- [ ] 리드타임, 결함율, 변경 실패율 3가지를 추적하고 있나
- [ ] PR 크기 제한 가이드라인이 팀에 공유되었나
- [ ] 월간 ROI 리포트를 팀이 함께 검토하고 있나

## 다음 단계

→ [가이드 27: AI 생성 코드 신뢰성 검증](../claude-code/playbooks/42-ai-code-trust-verification.md)  
→ [AI 코딩 에이전트 비용 최적화 플레이북](../claude-code/playbooks/38-cost-optimization-playbook.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)  
**유튜브:** [@ten-builder](https://youtube.com/@ten-builder)
