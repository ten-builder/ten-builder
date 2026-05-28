# AI 에이전트 기반 기술 부채 자동 탐지 및 우선순위화 워크플로우

> 방치하면 스프린트 속도를 갉아먹는 기술 부채 — AI 에이전트로 감지하고, 비즈니스 임팩트 기준으로 정리하고, 스프린트에 반영하기까지 한번에

## 왜 기술 부채 관리가 어려운가

AI 코딩 도구가 빨라질수록 기술 부채도 빠르게 쌓입니다. Addy Osmani의 "80% 문제" 분석에 따르면, AI 에이전트가 빠르게 완성하는 80%의 코드가 나머지 20%의 기술 부채로 이어집니다. 변경 빈도가 높은 코드(핫스팟)에 부채가 집중되는 반면, 팀은 어디서부터 손대야 할지 감이 없습니다.

이 워크플로우는 **정적 분석 + AI 에이전트 조합으로 기술 부채를 수치화하고, 비즈니스 임팩트 기준으로 우선순위를 매기고, 스프린트 계획에 반영**하는 전 과정을 다룹니다.

---

## 사전 준비

- Node.js 22+ (또는 Python 3.13+)
- `ripgrep`, `cloc`, `jq` 설치
- Claude Code 또는 Gemini CLI
- GitHub CLI (`gh`) — PR 연동 시 필요
- SonarQube Cloud 계정 (선택) 또는 ESLint/TypeScript 컴파일러

---

## Step 1: 핫스팟 탐지

변경 빈도가 높고 복잡도가 높은 파일이 "핫스팟"입니다. 이런 파일이 리팩토링 우선순위 1순위입니다.

### 1-1. Git 변경 빈도 분석

```bash
# 최근 6개월 기준 자주 바뀐 파일 TOP 20
git log --since="6 months ago" --name-only --format="" | \
  sort | uniq -c | sort -rn | head -20
```

### 1-2. 복잡도 측정

```bash
# 파일별 라인 수 측정
cloc src/ --by-file --json > /tmp/cloc-report.json

# 중첩 깊이 추정 (들여쓰기 4단계 이상 라인 비율)
grep -rn "        " src/ | \
  awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -20
```

### 1-3. AI 에이전트로 핫스팟 합산

```
프롬프트:
"다음 두 데이터를 조합해서 핫스팟 순위를 매겨줘.
변경 빈도가 높을수록, 복잡도(라인 수)가 높을수록 점수가 높아야 해.
결과는 파일 경로 | 변경 횟수 | 라인 수 | 핫스팟 점수 형태로 정리해줘.

[cloc-report.json 내용]
[git log 출력 내용]"
```

| 파일 | 변경 횟수 | 라인 수 | 핫스팟 점수 |
|------|-----------|---------|-------------|
| `src/auth/token.ts` | 42 | 680 | 높음 |
| `src/api/orders.ts` | 38 | 520 | 높음 |
| `src/utils/format.ts` | 12 | 180 | 낮음 |

---

## Step 2: 기술 부채 유형 분류

핫스팟 파일을 AI 에이전트로 분석해 부채 유형을 분류합니다.

```bash
# 핫스팟 파일 내용을 AI 에이전트에 전달
cat src/auth/token.ts | claude "이 코드의 기술 부채를 다음 유형으로 분류해줘:
1. 중복 코드 (같은 로직 반복)
2. 긴 함수/클래스 (단일 책임 원칙 위반)
3. 의존성 문제 (강한 결합, 순환 의존)
4. 테스트 부재 (테스트 없는 비즈니스 로직)
5. 미사용 코드 (dead code)

각 항목에 대해: 위치(라인 번호), 심각도(낮음/중간/높음), 수정 예상 시간(시간 단위)을 포함해줘."
```

### 출력 예시

```
1. 중복 코드: lines 45-78, lines 234-267 (동일한 토큰 검증 로직)
   심각도: 높음 | 수정 시간: 2시간
2. 긴 함수: refreshToken() — 145줄, 6가지 역할 혼재
   심각도: 중간 | 수정 시간: 4시간
3. 테스트 부재: validatePermissions() 함수 — 커버리지 0%
   심각도: 높음 | 수정 시간: 3시간
```

---

## Step 3: 비즈니스 임팩트 기반 우선순위화

모든 기술 부채가 동일하게 중요하지 않습니다. **비즈니스 임팩트 × 수정 용이성** 매트릭스로 순위를 매깁니다.

### 3-1. 임팩트 점수 계산

```
프롬프트:
"다음 기술 부채 목록에 비즈니스 임팩트 점수(1-5)를 매겨줘.
기준: (1) 사용자 영향 (장애 가능성) (2) 변경 빈도 (자주 수정하는 코드) (3) 팀 생산성 저하 (이해하기 어려운 코드)

[기술 부채 목록]"
```

### 3-2. 우선순위 매트릭스 생성

AI 에이전트가 생성한 매트릭스를 바탕으로 분류합니다.

| 구분 | 임팩트 높음 | 임팩트 낮음 |
|------|------------|------------|
| **수정 쉬움** | 🔴 즉시 처리 (이번 스프린트) | 🟡 시간 날 때 처리 |
| **수정 어려움** | 🟠 계획적 처리 (다음 분기) | 🟢 보류 (추적만) |

### 3-3. 자동화 스크립트로 티켓 생성

```bash
#!/bin/bash
# 우선순위 높은 기술 부채를 GitHub Issue로 자동 생성
export GH_TOKEN="..."

AI_SUMMARY=$(claude "다음 기술 부채 항목을 GitHub Issue 형식으로 정리해줘.
제목, 배경, 수정 방법, 예상 소요 시간을 포함해줘.
[부채 항목]")

gh issue create \
  --title "tech-debt: src/auth/token.ts 중복 검증 로직 통합" \
  --body "$AI_SUMMARY" \
  --label "tech-debt,priority-high" \
  --milestone "Q3-2026"
```

---

## Step 4: 스프린트 계획 연동

### 4-1. 스프린트당 기술 부채 비율 설정

```
권장 비율:
- 신규 기능 개발: 70%
- 기술 부채 처리: 20%
- 버그 수정: 10%
```

### 4-2. 자동 스프린트 제안

```
프롬프트:
"다음 기술 부채 백로그에서 이번 2주 스프린트에 처리할 항목을 골라줘.
팀 개발 용량: 120시간 (3명 × 2주 × 20시간)
기술 부채 예산: 24시간 (전체의 20%)

[기술 부채 백로그 목록]

선택 기준:
1. 우선순위 높음 먼저
2. 진행 중인 기능 개발과 파일 충돌 없는 것 우선
3. 24시간 내 완료 가능한 조합"
```

### 4-3. CI/CD 품질 게이트 설정

```yaml
# .github/workflows/tech-debt-check.yml
name: Tech Debt Check

on: [pull_request]

jobs:
  quality-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # 전체 git 이력 필요

      - name: Check hotspot complexity
        run: |
          # 변경된 파일 중 핫스팟 여부 확인
          CHANGED_FILES=$(git diff --name-only origin/main)
          for file in $CHANGED_FILES; do
            LINE_COUNT=$(wc -l < "$file" 2>/dev/null || echo 0)
            if [ "$LINE_COUNT" -gt 400 ]; then
              echo "⚠️ 경고: $file 는 ${LINE_COUNT}줄 (리팩토링 검토 필요)"
            fi
          done

      - name: ESLint complexity check
        run: npx eslint --rule '{"complexity": ["warn", 10]}' src/
```

---

## Step 5: 리팩토링 자동화

우선순위가 확정된 기술 부채는 AI 에이전트로 직접 리팩토링합니다.

### 5-1. 안전한 리팩토링 패턴

```bash
# 리팩토링 전: 테스트 커버리지 확인
npx jest --coverage --collectCoverageFrom="src/auth/token.ts"

# 테스트 커버리지 60% 미만이면 테스트 먼저 작성
claude "src/auth/token.ts의 refreshToken 함수에 대한 단위 테스트를 작성해줘.
엣지 케이스: 만료된 토큰, 잘못된 형식, 네트워크 오류 포함"

# 테스트 작성 후 리팩토링
claude "테스트가 모두 통과하는 상태에서 src/auth/token.ts의 중복 검증 로직을 
validateToken() 유틸 함수로 추출해줘. 기존 인터페이스는 유지할 것."
```

### 5-2. 리팩토링 검증 루프

```bash
# 리팩토링 전후 비교
git stash  # 리팩토링 임시 저장
npx jest   # 기존 테스트 실행 (기준선 확인)
git stash pop

npx jest   # 리팩토링 후 테스트 (모두 통과해야 함)

# 복잡도 변화 측정
BEFORE=$(git show HEAD:src/auth/token.ts | wc -l)
AFTER=$(wc -l < src/auth/token.ts)
echo "라인 수 변화: $BEFORE → $AFTER"
```

---

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| AI가 부채를 과대 탐지 | 컨텍스트 부족 | `CLAUDE.md`에 팀 코딩 컨벤션 명시 |
| 리팩토링 후 테스트 실패 | 의존성 미파악 | 리팩토링 전 의존성 그래프 먼저 분석 |
| 스프린트 과부하 | 부채 예산 초과 | 20% 규칙 엄수 — 초과 항목은 다음 스프린트로 |
| 팀 저항 | 기술 부채 수치화 부족 | CodeScene 또는 SonarQube로 비용 가시화 |

---

## 체크리스트

- [ ] 핫스팟 분석 스크립트 실행 (격주 1회)
- [ ] 비즈니스 임팩트 매트릭스 업데이트
- [ ] 스프린트 기술 부채 예산 20% 유지
- [ ] CI/CD 복잡도 게이트 설정
- [ ] 리팩토링 전 테스트 커버리지 60% 이상 확보
- [ ] 리팩토링 후 테스트 전량 통과 확인

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
