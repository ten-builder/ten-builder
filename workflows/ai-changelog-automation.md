# AI CHANGELOG 자동화 워크플로우

> 커밋 로그에서 CHANGELOG와 릴리스 노트를 자동 생성하는 실전 워크플로우

## 개요

릴리스마다 CHANGELOG를 수동으로 작성하면 빠지는 항목이 생기고, 팀원마다 톤이 달라져요. Conventional Commits 규칙과 AI 에이전트를 조합하면 커밋 히스토리에서 일관된 CHANGELOG를 자동으로 뽑아낼 수 있어요.

이 워크플로우가 해결하는 문제:
- 릴리스 노트 작성에 드는 반복 작업
- 커밋 메시지만으로는 부족한 "사용자 관점" 설명
- 시맨틱 버저닝과 CHANGELOG 동기화 누락

## 사전 준비

- Git 레포에 Conventional Commits 규칙 적용 (`feat:`, `fix:`, `chore:` 등)
- Node.js 18+ (semantic-release, standard-version 등 도구용)
- AI 코딩 에이전트 (Claude Code, Cursor 등)
- GitHub Actions 또는 CI/CD 파이프라인

## 설정

### Step 1: Conventional Commits 규칙 정의

프로젝트 루트에 `commitlint.config.js`를 추가해요:

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // 새 기능
        'fix',      // 버그 수정
        'docs',     // 문서 변경
        'style',    // 코드 포맷 (동작 변경 없음)
        'refactor', // 리팩토링
        'perf',     // 성능 개선
        'test',     // 테스트 추가/수정
        'chore',    // 빌드, 도구 설정 변경
        'ci',       // CI 설정 변경
      ],
    ],
    'subject-max-length': [2, 'always', 72],
  },
};
```

Husky로 커밋 시 자동 검증:

```bash
npm install -D @commitlint/cli @commitlint/config-conventional husky
npx husky init
echo 'npx --no -- commitlint --edit "$1"' > .husky/commit-msg
```

### Step 2: CHANGELOG 생성 도구 설치

```bash
# standard-version (독립형)
npm install -D standard-version

# 또는 semantic-release (CI 연동)
npm install -D semantic-release @semantic-release/changelog @semantic-release/git
```

`package.json`에 스크립트 추가:

```json
{
  "scripts": {
    "release": "standard-version",
    "release:minor": "standard-version --release-as minor",
    "release:major": "standard-version --release-as major"
  }
}
```

### Step 3: AI 에이전트 연동 — 릴리스 노트 보강

AI에게 넘길 프롬프트 템플릿을 `.github/release-note-prompt.md`로 저장해요:

```markdown
아래는 최근 릴리스의 커밋 로그야.
이 커밋들을 기반으로 사용자 관점의 릴리스 노트를 작성해줘.

규칙:
- 카테고리별 그룹핑 (New Features / Bug Fixes / Improvements)
- 각 항목은 사용자가 이해할 수 있는 한 줄 설명
- 내부 리팩토링, CI 변경 등은 "Internal Changes"로 분리
- 이전 버전과 비교해서 주목할 변화가 있으면 상단에 하이라이트

커밋 로그:
{COMMIT_LOG}
```

### Step 4: GitHub Actions 워크플로우

```yaml
# .github/workflows/release-notes.yml
name: Generate Release Notes

on:
  push:
    tags:
      - 'v*'

jobs:
  release-notes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get commits since last tag
        id: commits
        run: |
          PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
          if [ -z "$PREV_TAG" ]; then
            COMMITS=$(git log --pretty=format:"%h %s" HEAD)
          else
            COMMITS=$(git log --pretty=format:"%h %s" ${PREV_TAG}..HEAD)
          fi
          echo "commits<<EOF" >> $GITHUB_OUTPUT
          echo "$COMMITS" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Generate release notes with AI
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          PROMPT=$(cat .github/release-note-prompt.md)
          PROMPT="${PROMPT//\{COMMIT_LOG\}/${{ steps.commits.outputs.commits }}}"

          curl -s https://api.anthropic.com/v1/messages \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "{
              \"model\": \"claude-sonnet-4-20250514\",
              \"max_tokens\": 2048,
              \"messages\": [{
                \"role\": \"user\",
                \"content\": \"$PROMPT\"
              }]
            }" | jq -r '.content[0].text' > release-notes.md

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          body_path: release-notes.md
          generate_release_notes: false
```

## 사용 방법

### 일상 커밋 → 자동 CHANGELOG

```bash
# 기능 추가 커밋
git commit -m "feat(auth): add OAuth2 Google login"

# 버그 수정 커밋
git commit -m "fix(api): handle null response in user endpoint"

# 릴리스 생성 (CHANGELOG.md 자동 업데이트)
npm run release
# → CHANGELOG.md에 새 섹션 추가
# → package.json 버전 범프
# → 태그 생성 (v1.2.0)

git push --follow-tags
# → GitHub Actions가 AI 릴리스 노트 생성
```

### AI 에이전트에게 직접 요청하는 패턴

로컬에서 Claude Code나 Cursor를 쓰고 있다면 더 간단해요:

```bash
# 최근 커밋 로그 추출
git log --pretty=format:"%h %s (%an)" v1.1.0..HEAD > /tmp/commits.txt

# AI에게 릴리스 노트 요청
# "이 커밋 로그를 보고 v1.2.0 릴리스 노트를 작성해줘"
```

| 상황 | 프롬프트 예시 |
|------|-------------|
| 전체 릴리스 노트 | `v1.1.0 이후 커밋을 분석해서 릴리스 노트 작성해줘` |
| 특정 기능 하이라이트 | `이번 릴리스에서 auth 관련 변경사항만 정리해줘` |
| 사용자 공지용 | `비개발자도 이해할 수 있는 업데이트 공지로 바꿔줘` |
| 마이그레이션 가이드 | `breaking change가 있으면 마이그레이션 가이드 포함해줘` |

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `commitlint` 타입 | conventional | 팀 규칙에 맞게 `type-enum` 수정 |
| CHANGELOG 포맷 | keepachangelog | `standard-version` 설정에서 변경 가능 |
| AI 모델 | claude-sonnet | 비용 절감 시 haiku, 복잡한 프로젝트는 opus |
| 릴리스 주기 | 수동 | `schedule` 트리거로 주간/월간 자동 가능 |
| 언어 | 영어 | 프롬프트에서 한국어 지정 가능 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 커밋 메시지 규칙 안 지킴 | `commitlint` + Husky로 강제. 기존 커밋은 `--no-verify`로 우회 |
| CHANGELOG가 너무 장황함 | `standard-version`의 `hidden: true` 옵션으로 chore, ci 등 숨김 |
| AI가 커밋 의도를 잘못 해석 | 커밋 body에 상세 설명 추가, 또는 PR 번호 참조 |
| Breaking change 누락 | 커밋 footer에 `BREAKING CHANGE:` 명시. commitlint로 검증 |
| 태그 충돌 | `git tag -l` 확인 후 `--release-as` 옵션으로 수동 버전 지정 |

## 실전 CHANGELOG 예시

```markdown
# Changelog

## [1.2.0] - 2026-03-18

### New Features
- **auth:** Google OAuth2 로그인 지원 (#142)
- **dashboard:** 실시간 알림 위젯 추가 (#145)

### Bug Fixes
- **api:** 사용자 엔드포인트 null 응답 처리 (#143)
- **ui:** 모바일 사이드바 레이아웃 깨짐 수정 (#144)

### Improvements
- **perf:** 메인 페이지 로딩 속도 40% 개선
- **docs:** API 문서 v1.2 업데이트

### Internal Changes
- CI 파이프라인 Node 22로 업그레이드
- 테스트 커버리지 78% → 85%
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
