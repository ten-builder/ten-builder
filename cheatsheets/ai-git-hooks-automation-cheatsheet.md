# AI 에이전트 Git Hooks 자동화 치트시트

> pre-commit, pre-push, post-merge 훅을 AI 에이전트와 연동하여 코드 품질을 자동으로 강제하는 패턴 — 한 페이지 요약

## Git Hooks 종류와 활용 시점

| 훅 | 실행 시점 | 주요 용도 |
|----|-----------|-----------|
| `pre-commit` | `git commit` 직전 | 포맷팅, 린팅, 비밀값 검사 |
| `commit-msg` | 커밋 메시지 작성 후 | 메시지 포맷 강제, AI 자동 보완 |
| `pre-push` | `git push` 직전 | 테스트 실행, 빌드 확인 |
| `post-merge` | `git merge` 완료 후 | 의존성 재설치, 환경 동기화 |
| `post-checkout` | 브랜치 전환 후 | 브랜치별 환경 설정 |

## pre-commit: AI 코드 품질 게이트

### 기본 설정 (.pre-commit-config.yaml)

```yaml
repos:
  - repo: local
    hooks:
      - id: ai-format-check
        name: AI 코드 포맷 검사
        language: system
        entry: bash -c 'git diff --cached --name-only --diff-filter=ACM | grep -E "\.(ts|js|py)$" | xargs -I{} sh -c "claude --print \"코드 포맷 이슈 확인: {}\" < {}"'
        pass_filenames: false

      - id: secret-scan
        name: 비밀값 검사
        language: system
        entry: bash -c 'git diff --cached | grep -E "(api_key|secret|password|token)\s*=" && echo "⚠️ 비밀값 감지됨" && exit 1 || exit 0'
        pass_filenames: false
```

### 설치 및 활성화

```bash
# pre-commit 설치
pip install pre-commit

# 훅 설치 (.pre-commit-config.yaml 기준)
pre-commit install

# 전체 파일 대상 수동 실행
pre-commit run --all-files
```

## commit-msg: AI 커밋 메시지 보완

```bash
#!/bin/bash
# .git/hooks/commit-msg

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# 커밋 메시지가 너무 짧으면 AI로 보완
if [ ${#COMMIT_MSG} -lt 20 ]; then
  DIFF=$(git diff --cached --stat)
  IMPROVED=$(echo "$DIFF" | claude --print "아래 변경 요약을 보고 Conventional Commits 형식으로 한 줄 커밋 메시지를 작성해줘 (한국어):\n$DIFF")
  echo "$IMPROVED" > "$COMMIT_MSG_FILE"
  echo "✅ AI 커밋 메시지 생성됨: $IMPROVED"
fi
```

## pre-push: 테스트 + 빌드 자동화

```bash
#!/bin/bash
# .git/hooks/pre-push

CURRENT_BRANCH=$(git branch --show-current)

echo "🔍 pre-push 검사 중: $CURRENT_BRANCH"

# main/master 브랜치 push 시 전체 테스트 실행
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
  echo "⚠️  main 브랜치 push — 전체 테스트 실행"
  npm test 2>&1
  TEST_EXIT=$?
  
  if [ $TEST_EXIT -ne 0 ]; then
    echo "❌ 테스트 실패 — push 중단"
    exit 1
  fi
fi

# TypeScript 빌드 확인
if [ -f "tsconfig.json" ]; then
  npx tsc --noEmit 2>&1
  if [ $? -ne 0 ]; then
    echo "❌ TypeScript 빌드 실패 — push 중단"
    exit 1
  fi
fi

echo "✅ pre-push 검사 통과"
exit 0
```

## post-merge: 환경 자동 동기화

```bash
#!/bin/bash
# .git/hooks/post-merge

CHANGED_FILES=$(git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD)

# package.json 변경 감지 → 자동 재설치
if echo "$CHANGED_FILES" | grep -q "package.json"; then
  echo "📦 package.json 변경 감지 — npm install 실행"
  npm install
fi

# .env.example 변경 감지 → 알림
if echo "$CHANGED_FILES" | grep -q ".env.example"; then
  echo "⚠️  .env.example 변경됨 — .env 파일 직접 확인 필요"
fi

# DB 마이그레이션 파일 감지 → 자동 실행
if echo "$CHANGED_FILES" | grep -qE "migrations/.*\.sql$"; then
  echo "🗄️  마이그레이션 파일 감지 — 실행 여부 확인"
  read -p "마이그레이션을 실행할까요? (y/n): " CONFIRM
  if [ "$CONFIRM" = "y" ]; then
    npm run migrate
  fi
fi
```

## Claude Code Hooks 연동 (settings.json)

Claude Code 자체 훅 시스템으로 AI 에이전트 워크플로우에 Git 작업을 연결:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "git diff --stat HEAD"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'echo \"$CLAUDE_TOOL_INPUT\" | grep -qE \"git push.*main\" && echo \"{\\\"decision\\\": \\\"block\\\", \\\"reason\\\": \\\"main 직접 push 금지\\\"}\" || echo \"{\\\"decision\\\": \\\"approve\\\"}\"'"
          }
        ]
      }
    ]
  }
}
```

| 이벤트 | 설명 |
|--------|------|
| `PreToolUse` | 도구 실행 직전 — 위험 명령 차단에 사용 |
| `PostToolUse` | 도구 실행 후 — 포맷팅, 통계 출력에 사용 |
| `Stop` | 에이전트 세션 종료 시 — 요약, 알림에 사용 |

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 훅 실행 권한 없음 | `chmod +x .git/hooks/pre-commit` |
| 훅이 팀원에게 적용 안 됨 | `.pre-commit-config.yaml` + `pre-commit install` 문서화 |
| pre-commit이 너무 느림 | `--files` 옵션으로 변경 파일만 대상 지정 |
| AI 훅이 오탐 많음 | 신뢰도 임계값 설정 + `--no-verify` 탈출구 확보 |
| post-merge 훅이 rebase에서 미실행 | `post-rewrite` 훅도 함께 설정 |

## 팀 전체 적용 전략

```bash
# 1. 훅 스크립트를 레포에 포함
mkdir -p .githooks
cp .git/hooks/pre-commit .githooks/pre-commit
git add .githooks/

# 2. 팀원이 로컬에서 한 번만 실행하면 됨
git config core.hooksPath .githooks

# 3. package.json scripts로 자동화
```

```json
{
  "scripts": {
    "prepare": "git config core.hooksPath .githooks && chmod +x .githooks/*"
  }
}
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
