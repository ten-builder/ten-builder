# AI 기술 부채 해소 워크플로우

> AI 코딩 에이전트로 기술 부채를 체계적으로 식별하고, 우선순위를 정하고, 점진적으로 개선하는 워크플로우

## 개요

"나중에 고치자"가 쌓여서 프로젝트가 느려지는 경험, 개발자라면 누구나 있어요. 기술 부채는 코드의 복잡도, 오래된 의존성, 테스트 부족, 비일관적인 패턴 등 다양한 형태로 나타나요. 문제는 이걸 **언제, 어떤 순서로 해소할지** 판단하기 어렵다는 거예요.

이 워크플로우는 AI 코딩 에이전트를 사용해서 기술 부채를 자동으로 탐지하고, 우선순위를 매기고, 실제 수정까지 진행하는 체계를 만들어요. 사람은 전략적 판단과 머지 검수에 집중하면 돼요.

## 사전 준비

- Claude Code, Codex CLI, 또는 Cursor Agent 중 하나
- Git 레포 (로컬 클론)
- Node.js / Python 등 프로젝트 런타임
- ESLint, Pylint 등 기존 린터 (있으면 활용)

## Step 1: 기술 부채 탐색 프롬프트 설계

AI 에이전트에게 레포 전체를 스캔하게 해서 부채 목록을 추출해요.

### 탐색 프롬프트 예시

```
이 프로젝트의 기술 부채를 분석해줘.
다음 카테고리별로 분류하고, 각 항목에 심각도(high/medium/low)를 매겨줘:

1. 코드 복잡도: 순환 복잡도가 높은 함수, 긴 함수(100줄+), 깊은 중첩
2. 의존성: 메이저 버전이 2개 이상 뒤처진 패키지, deprecated API 사용
3. 테스트 부족: 테스트가 없는 핵심 모듈, 커버리지 사각지대
4. 패턴 비일관: 같은 문제를 다른 방식으로 해결한 곳, 사용되지 않는 코드
5. 문서 부재: 공개 API에 주석이 없는 곳, 오래된 README

파일 경로와 함께 구체적으로 알려줘.
```

### 출력 형식 지정

```
결과를 다음 YAML 형식으로 정리해줘:

tech_debt:
  - id: TD-001
    category: complexity
    severity: high
    file: src/utils/parser.ts
    line_range: "45-180"
    description: "parseConfig 함수가 135줄, 순환 복잡도 23"
    suggested_fix: "전략 패턴으로 분리"
    effort: medium
```

## Step 2: 우선순위 매트릭스 만들기

탐지된 부채를 **영향도 × 수정 난이도** 매트릭스로 분류해요.

| | 수정 쉬움 | 수정 보통 | 수정 어려움 |
|---|---|---|---|
| **영향 큼** | 즉시 수정 | 이번 스프린트 | 계획 수립 |
| **영향 보통** | 틈새 시간 | 백로그 | 모니터링 |
| **영향 작음** | 자동화 | 보류 | 무시 |

### AI에게 분류 요청

```
위 기술 부채 목록을 영향도(impact)와 수정 난이도(effort)로 분류해줘.

영향도 기준:
- high: 버그 발생 가능성, 성능 저하, 온보딩 방해
- medium: 유지보수 비용 증가, 개발 속도 저하
- low: 미관상 문제, 사소한 비일관성

수정 난이도 기준:
- easy: 패턴 변경 없이 수정 가능, 30분 이내
- medium: 일부 리팩토링 필요, 테스트 수정 포함
- hard: 아키텍처 변경 필요, 여러 파일 동시 수정
```

## Step 3: 자동 수정 실행 전략

부채 유형별로 AI 에이전트 활용 방식이 달라요.

### 3-1. 자동화 가능한 부채 (L1: 자율 실행)

사람 검수 없이 에이전트가 처리하고 PR만 만들면 되는 항목:

```bash
# 사용하지 않는 import 제거
claude -p "이 프로젝트에서 사용하지 않는 import를 모두 찾아서 제거해줘.
각 파일별로 변경사항을 커밋해줘."

# 타입 안전성 강화
claude -p "any 타입이 사용된 곳을 찾아서 적절한 타입으로 교체해줘.
확실하지 않은 건 TODO 주석으로 남겨줘."

# deprecated API 교체
claude -p "deprecated된 API 호출을 찾아서 새 API로 교체해줘.
변경 전후를 커밋 메시지에 명시해줘."
```

### 3-2. 감독이 필요한 부채 (L2: 승인 게이트)

```bash
# 복잡한 함수 분리
claude -p "src/utils/parser.ts의 parseConfig 함수를 분석해줘.
리팩토링 계획을 먼저 보여주고, 승인하면 실행해줘.
기존 테스트가 통과하는지 확인해줘."

# 의존성 메이저 업데이트
claude -p "package.json에서 메이저 버전이 2개 이상 뒤처진
패키지 목록을 보여줘. 각 업데이트의 breaking change를 요약해줘.
한 번에 하나씩 업데이트하고 테스트 돌려줘."
```

### 3-3. 사람이 주도해야 하는 부채 (L3: 페어 모드)

```bash
# 아키텍처 수준 리팩토링
claude -p "현재 모놀리식 서비스 레이어를 도메인별로 분리하는
마이그레이션 계획을 세워줘. 단계별로 논의하면서 진행하자."
```

## Step 4: 점진적 개선 파이프라인

한 번에 다 고치려 하면 실패해요. 매주 조금씩 줄여가는 파이프라인을 만들어요.

### 주간 기술 부채 루틴

```yaml
# .github/workflows/tech-debt-weekly.yml (개념 예시)
schedule:
  - cron: "0 9 * * 1"  # 매주 월요일 오전 9시

steps:
  - name: 부채 스캔
    run: |
      # 린터 실행 → 결과 수집
      eslint . --format json > lint-report.json
      # 복잡도 분석
      npx complexity-report src/ > complexity-report.json

  - name: 리포트 생성
    run: |
      # 지난주 대비 변화량 계산
      # 새로 추가된 부채 / 해소된 부채 비교
```

### 부채 트래킹 파일

프로젝트 루트에 `.tech-debt.yaml`을 유지하면서 변화를 추적해요:

```yaml
# .tech-debt.yaml
last_scan: "2026-03-17"
summary:
  total: 42
  high: 5
  medium: 18
  low: 19
  resolved_this_month: 8
  added_this_month: 3

trends:
  - date: "2026-03-01"
    total: 47
  - date: "2026-03-08"
    total: 44
  - date: "2026-03-15"
    total: 42
```

## Step 5: 부채 방지 자동화

새 부채가 생기지 않도록 가드레일을 설정해요.

### Pre-commit 부채 체크

```bash
#!/bin/bash
# .husky/pre-commit

# 새 코드의 복잡도 체크
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|js|py)$')

for file in $CHANGED_FILES; do
  # 함수 길이 체크 (100줄 초과 경고)
  long_funcs=$(grep -c "function\|const.*=.*=>" "$file" 2>/dev/null)
  lines=$(wc -l < "$file")

  if [ "$lines" -gt 300 ]; then
    echo "경고: $file이 300줄을 초과했어요 ($lines줄)"
  fi
done
```

### PR 자동 리뷰에 부채 체크 추가

```yaml
# .claude/review-checklist.md에 추가
- [ ] 새 기술 부채를 만들지 않았는가?
- [ ] 기존 부채를 악화시키지 않았는가?
- [ ] 수정한 파일 주변의 사소한 부채를 함께 해소했는가?
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 스캔 주기 | 주 1회 | 프로젝트 규모에 따라 조절 |
| 자동 수정 범위 | L1만 | 팀 신뢰도에 따라 L2까지 확대 가능 |
| 심각도 임계값 | high | medium까지 포함하면 더 적극적 |
| 최대 동시 PR | 3개 | 리뷰 부담 고려 |
| 부채 증가 알림 | 주 5개+ | Slack/Discord 알림 트리거 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 부채 목록이 너무 많아서 압도됨 | 상위 5개만 집중, 나머지는 백로그로 |
| AI가 리팩토링 중 테스트를 깨뜨림 | 수정 전 테스트 스냅샷 저장, 실패 시 롤백 |
| 팀원이 부채 해소 PR을 리뷰 안 함 | 소규모 PR로 쪼개기 (파일 3개 이하) |
| 의존성 업데이트 후 빌드 실패 | 한 번에 하나만 업데이트, lockfile 커밋 |
| "이건 부채가 아니라 설계 결정이다" | 팀 합의로 `.tech-debt-ignore`에 등록 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
