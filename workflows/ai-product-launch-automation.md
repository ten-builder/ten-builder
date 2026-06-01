# AI 에이전트 기반 제품 출시 자동화 워크플로우

> 릴리스 노트 작성부터 마케팅 카피 생성, 문서 동기화, 사용자 피드백 수집까지 — 출시 전후 반복 작업을 AI 에이전트로 자동화합니다.

## 개요

제품 출시 당일, 개발팀은 코드 배포 외에도 해야 할 일이 쌓입니다. 릴리스 노트 작성, 마케팅 카피 다듬기, 문서 업데이트, 사용자 피드백 모니터링. 이 작업들은 비슷한 패턴이 반복되고, AI 에이전트가 처리하기 좋은 구조입니다.

이 워크플로우는 세 단계로 구성됩니다.

- **출시 전:** Git 커밋 이력 → 릴리스 노트 + 마케팅 카피 자동 생성
- **출시 시:** 문서 동기화 + llms.txt 업데이트
- **출시 후:** 사용자 피드백 수집 → 분류 → 다음 스프린트 인풋

## 사전 준비

- Claude Code 또는 AI 에이전트 실행 환경
- GitHub CLI (`gh`) 인증 완료
- 프로젝트의 `CHANGELOG.md` 또는 `releases/` 디렉토리 존재
- 선택: Slack/Discord webhook (피드백 알림용)

## Step 1: 릴리스 노트 자동 작성

Git 커밋 이력을 분석해 사용자 관점의 릴리스 노트를 생성합니다.

```bash
# 마지막 태그 이후 커밋 목록 추출
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~20")
git log "$LAST_TAG"..HEAD --oneline --no-merges > /tmp/commits.txt

# AI 에이전트에게 릴리스 노트 작성 위임
cat > /tmp/release-prompt.md << 'EOF'
아래 커밋 목록을 보고 사용자 관점의 릴리스 노트를 작성해 주세요.

규칙:
- 기술 용어보다 사용자가 체감하는 변화 중심으로 작성
- 새 기능 / 개선 / 수정 세 섹션으로 구분
- 각 항목은 한 줄로 간결하게
- 내부 리팩토링, 테스트 변경은 포함하지 않음

커밋 목록:
$(cat /tmp/commits.txt)
EOF
```

Claude Code에서 실행하는 방법:

```bash
claude --print "$(cat /tmp/release-prompt.md)" > releases/v$(date +%Y.%m.%d).md
```

## Step 2: 마케팅 카피 생성

릴리스 노트를 바탕으로 채널별 카피를 자동 생성합니다.

```bash
# 릴리스 노트에서 채널별 카피 생성
RELEASE_NOTES=$(cat releases/v$(date +%Y.%m.%d).md)

cat > /tmp/marketing-prompt.md << 'EOF'
아래 릴리스 노트를 보고 채널별 카피를 작성해 주세요.

1. **X/Twitter (280자 이내):** 핵심 기능 1~2개 강조
2. **LinkedIn (500자 이내):** 비즈니스 가치 중심, 전문적인 톤
3. **뉴스레터 소개 문단 (3~4문장):** 독자가 바로 써볼 수 있는 이점 강조

릴리스 노트:
$RELEASE_NOTES
EOF

claude --print "$(cat /tmp/marketing-prompt.md)" > marketing/v$(date +%Y.%m.%d)-copy.md
```

생성된 카피는 `marketing/` 디렉토리에 날짜별로 저장됩니다.

## Step 3: 문서 동기화

출시와 함께 README, API 레퍼런스, llms.txt를 최신 상태로 맞춥니다.

```bash
# llms.txt 자동 업데이트 (AI 도구가 API를 정확히 이해하도록)
# llms.txt는 API spec의 AI 최적화 요약본입니다.
cat > scripts/update-llms-txt.sh << 'EOF'
#!/bin/bash
set -e

OPENAPI_SPEC="openapi.yaml"
OUTPUT="llms.txt"

if [ ! -f "$OPENAPI_SPEC" ]; then
  echo "openapi.yaml not found, skipping llms.txt update"
  exit 0
fi

claude --print "
다음 OpenAPI spec을 바탕으로 llms.txt를 작성해 주세요.
llms.txt는 AI 도구가 이 API를 사용하는 코드를 작성할 때 참조하는 간결한 요약본입니다.

포함할 내용:
- API 기본 URL 및 인증 방식
- 주요 엔드포인트 목록 (메서드, 경로, 용도)
- 자주 쓰는 요청/응답 예시 3~5개
- 흔한 에러 코드와 대응 방법

$(cat $OPENAPI_SPEC)
" > "$OUTPUT"

echo "llms.txt updated"
EOF

chmod +x scripts/update-llms-txt.sh
```

README의 변경 로그 섹션도 자동으로 갱신합니다:

```bash
# README changelog 섹션 업데이트
cat > scripts/update-readme-changelog.sh << 'EOF'
#!/bin/bash
RELEASE_FILE="releases/v$(date +%Y.%m.%d).md"
README="README.md"

if [ ! -f "$RELEASE_FILE" ]; then
  echo "Release notes not found"
  exit 1
fi

# ## Changelog 섹션 이후에 새 버전 추가
VERSION="v$(date +%Y.%m.%d)"
MARKER="## Changelog"

NEW_ENTRY="### $VERSION\n$(cat $RELEASE_FILE | head -20)\n"

# 기존 Changelog 섹션 앞에 새 항목 삽입
sed -i "s/$MARKER/$MARKER\n$NEW_ENTRY/" "$README"
EOF

chmod +x scripts/update-readme-changelog.sh
```

## Step 4: 사용자 피드백 수집 및 분류

출시 후 사용자 반응을 수집하고 다음 스프린트 인풋으로 정리합니다.

```bash
# GitHub Issues에서 출시 이후 신규 이슈 수집
RELEASE_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

gh issue list \
  --label "feedback" \
  --state open \
  --json number,title,body,createdAt \
  --jq ".[] | select(.createdAt >= \"$RELEASE_DATE\")" \
  > /tmp/feedback-raw.json

# AI 에이전트로 피드백 분류
claude --print "
아래 GitHub 이슈 목록을 분류해 주세요.

분류 기준:
- 버그 리포트: 실제 오동작 보고
- 기능 요청: 새 기능 제안
- UX 피드백: 사용성 불편 사항
- 문서 요청: 설명 부족한 부분

각 카테고리별로 이슈 번호와 한 줄 요약을 나열하고,
가장 많이 언급된 불편 사항 Top 3를 마지막에 추가해 주세요.

이슈 데이터:
$(cat /tmp/feedback-raw.json)
" > reports/feedback-$(date +%Y.%m.%d).md

echo "Feedback report generated: reports/feedback-$(date +%Y.%m.%d).md"
```

피드백 리포트를 Slack/Discord로 알림 전송:

```bash
# 피드백 요약 알림 (선택)
WEBHOOK_URL="${SLACK_WEBHOOK_URL}"
SUMMARY=$(head -30 reports/feedback-$(date +%Y.%m.%d).md)

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": \"출시 후 피드백 요약 ($(date +%Y-%m-%d))\n\`\`\`\n${SUMMARY}\n\`\`\`\"
  }"
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 릴리스 노트 대상 기간 | 마지막 태그 이후 | `LAST_TAG` 변수로 조정 |
| 피드백 수집 레이블 | `feedback` | `--label` 값 변경 |
| 문서 동기화 범위 | README + llms.txt | 필요에 따라 스크립트 확장 |
| 알림 채널 | Slack/Discord (선택) | Webhook URL 환경변수로 설정 |
| 마케팅 카피 채널 | X, LinkedIn, 뉴스레터 | 프롬프트에 채널 추가/제거 |

## CI/CD 파이프라인 통합

출시 태그 push 시 자동으로 실행되는 GitHub Actions 예시입니다.

```yaml
# .github/workflows/product-launch.yml
name: Product Launch Automation

on:
  push:
    tags:
      - 'v*'

jobs:
  launch-automation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate Release Notes
        run: |
          bash scripts/generate-release-notes.sh
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Sync Documentation
        run: |
          bash scripts/update-llms-txt.sh
          bash scripts/update-readme-changelog.sh

      - name: Commit Updated Docs
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add releases/ llms.txt README.md
          git diff --staged --quiet || git commit -m "docs: release $(git describe --tags --abbrev=0) 문서 자동 업데이트"
          git push
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| 커밋 이력이 너무 많아 노트가 길어짐 | `--max-count=50` 옵션으로 제한 |
| llms.txt가 openapi.yaml 없이 실패 | spec 파일 경로를 환경변수로 분리 |
| 피드백 이슈 없음 | `feedback` 레이블 외에 `question`, `bug` 레이블도 포함 |
| 마케팅 카피 톤이 맞지 않음 | 프롬프트에 기존 카피 예시 2~3개 추가 |
| GitHub Actions 권한 오류 | `GITHUB_TOKEN`에 `contents: write` 권한 부여 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
