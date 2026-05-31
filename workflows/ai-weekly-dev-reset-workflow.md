# AI 에이전트 기반 주간 개발 리셋 워크플로우 — 월요일 아침을 위한 자동화

> 일요일 밤 AI 에이전트에게 한 주의 마무리를 맡기고, 월요일 아침 집중 코딩 시간에 바로 진입하는 워크플로우

## 이 워크플로우가 해결하는 문제

월요일 오전의 첫 2시간은 보통 이렇게 낭비됩니다.

- 지난 주 머지되지 않은 PR 상태 확인
- 쌓인 코드 리뷰 코멘트 파악
- 기술 부채 티켓 정리
- 문서 업데이트 여부 확인
- 주간 계획 수립

AI 에이전트에게 이 일을 일요일 밤에 넘기면, 월요일 아침에는 정리된 작업 목록과 함께 바로 코딩을 시작할 수 있습니다.

## 사전 준비

- Claude Code 또는 Codex CLI 설치
- GitHub CLI (`gh`) 인증 완료
- 프로젝트 루트에 `CLAUDE.md` 또는 `AGENTS.md` 설정
- 선택: 주간 리포트를 받을 Slack Webhook 또는 Discord Webhook

## 워크플로우 설계

```
일요일 22:00 (자동 트리거 or 수동 실행)
    │
    ├─ Step 1: PR 상태 점검
    ├─ Step 2: 코드 리뷰 코멘트 요약
    ├─ Step 3: 기술 부채 탐지
    ├─ Step 4: 문서 동기화 체크
    └─ Step 5: 월요일 작업 목록 생성
    
월요일 09:00
    └─ 정리된 이슈 목록 확인 → 바로 코딩 시작
```

## Step 1: PR 상태 점검

```bash
#!/bin/bash
# weekly-reset.sh

# 열린 PR 목록과 상태 확인
gh pr list --state open --json number,title,reviewDecision,statusCheckRollup \
  --jq '.[] | "\(.number): \(.title) | review: \(.reviewDecision) | CI: \(.statusCheckRollup[0].state)"'
```

AI 에이전트에게 다음 프롬프트로 분석을 요청합니다.

```
위 PR 목록을 분석해서:
1. 머지 가능한 PR (승인 완료 + CI 통과)
2. 리뷰 필요한 PR
3. CI 실패 중인 PR (수정 필요)
세 그룹으로 분류하고, 각 그룹별 다음 액션을 추천해줘.
```

## Step 2: 코드 리뷰 코멘트 요약

```bash
# 지난 7일간 내 PR에 달린 리뷰 코멘트 조회
gh api graphql -f query='
{
  viewer {
    pullRequests(last: 10, states: OPEN) {
      nodes {
        number
        title
        reviews(last: 5) {
          nodes {
            comments(first: 5) {
              nodes {
                body
                path
                position
              }
            }
          }
        }
      }
    }
  }
}'
```

AI가 코멘트를 파악하면, 수정에 걸리는 예상 시간을 기준으로 우선순위화합니다.

| 우선순위 | 기준 | 예상 시간 |
|----------|------|-----------|
| 즉시 처리 | 오타, 변수명 변경 | 5분 이하 |
| 오전 중 처리 | 로직 개선, 테스트 추가 | 30분 이하 |
| 별도 티켓 | 아키텍처 변경, 리팩토링 | 1시간 이상 |

## Step 3: 기술 부채 탐지

```bash
# ESLint, TypeScript 컴파일러 에러 집계
npx eslint src --format json --output-file /tmp/eslint-report.json 2>/dev/null
npx tsc --noEmit 2>&1 | tail -20

# TODO/FIXME 주석 카운트
grep -r "TODO\|FIXME\|HACK\|XXX" src --include="*.ts" --include="*.tsx" | wc -l
```

```bash
# 테스트 커버리지 체크
npx jest --coverage --coverageReporters=json-summary 2>/dev/null
cat coverage/coverage-summary.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
total = d.get('total', {})
print(f'Lines: {total.get(\"lines\", {}).get(\"pct\", 0):.1f}%')
print(f'Functions: {total.get(\"functions\", {}).get(\"pct\", 0):.1f}%')
"
```

## Step 4: 문서 동기화 체크

```bash
# 최근 7일간 변경된 파일 목록
git log --since="7 days ago" --name-only --pretty=format: | sort -u | grep -v "^$"

# README, CHANGELOG가 마지막으로 수정된 날짜
git log -1 --format="%ai" -- README.md
git log -1 --format="%ai" -- CHANGELOG.md
```

AI 에이전트에게 코드 변경 사항과 문서를 비교해서 업데이트가 필요한 섹션을 찾아달라고 요청합니다.

```
지난 주 변경된 파일 목록과 현재 README.md를 비교해서,
문서에 반영되지 않은 변경사항이 있으면 추가할 초안을 작성해줘.
최대 3개 항목만, 간략하게.
```

## Step 5: 월요일 작업 목록 생성

모든 점검이 끝나면 AI가 작업 목록을 생성합니다.

```markdown
# 월요일 작업 목록 — 2026-06-01

## 즉시 처리 (30분)
- [ ] PR #42: 오타 수정 2건 (리뷰어 요청)
- [ ] PR #44: CI 실패 → 테스트 데이터 수정
- [ ] PR #39: 승인 완료 → 머지

## 오전 집중 (2시간)
- [ ] PR #41: 비동기 처리 로직 개선 (리뷰 코멘트 반영)
- [ ] 테스트 커버리지 62% → 70% 목표 (누락된 유틸 함수 3개)

## 이번 주 중
- [ ] TODO 주석 12개 중 우선순위 높은 5개 처리
- [ ] README API 섹션 최신화 (v2.3 변경사항 미반영)

## 다음 스프린트 후보
- [ ] UserService 리팩토링 (기술 부채 티켓 #88)
```

## 자동화 설정

### cron 기반 자동 실행

```bash
# crontab -e 에 추가
# 일요일 22:00 자동 실행
0 22 * * 0 /path/to/weekly-reset.sh >> ~/logs/weekly-reset.log 2>&1
```

### CLAUDE.md에 주간 리셋 규칙 추가

```markdown
## Weekly Reset

매주 일요일 22시, 다음 순서로 주간 리셋을 실행한다:

1. `gh pr list --state open` 으로 PR 상태 확인
2. 머지 가능한 PR 즉시 머지
3. 리뷰 코멘트 우선순위화 (즉시/오전/별도 티켓 3분류)
4. 기술 부채 탐지 후 상위 5개 선별
5. 월요일 작업 목록을 `MONDAY.md`에 저장

출력물은 `MONDAY.md` 파일로 저장한다.
```

### 결과를 알림으로 전송

```bash
# Slack 또는 Discord Webhook으로 요약 전송
SUMMARY=$(cat ~/MONDAY.md | head -20)
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"주간 리셋 완료\n\`\`\`\n${SUMMARY}\n\`\`\`\"}"
```

## 커스터마이징

| 설정 | 기본값 | 변경 기준 |
|------|--------|-----------|
| 실행 시간 | 일요일 22:00 | 팀 관행에 맞게 조정 |
| PR 조회 기간 | 최근 10개 | 활발한 레포는 20개 |
| 기술 부채 상위 N개 | 5개 | 스프린트 여유에 따라 조정 |
| 문서 비교 깊이 | README + CHANGELOG | API 문서 포함 가능 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| `gh` 인증 만료 | `gh auth refresh` 실행 |
| ESLint 설정 없음 | 기술 부채 탐지 스텝 스킵 |
| 대형 레포에서 느림 | `--limit` 플래그로 조회 범위 제한 |
| 알림 미전송 | Webhook URL 환경변수 확인 |

## 더 알아보기

- [AI 에이전트 기술 부채 탐지 워크플로우](./ai-tech-debt-detection-prioritization.md)
- [AI 에이전트 코드 문서화 자동화](./ai-code-documentation-automation.md)
- [claude-code/playbooks](../claude-code/playbooks/)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
