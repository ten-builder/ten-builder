# 플레이북 31: AI 코딩 에이전트로 CI 파이프라인 디버깅하기

> CI가 빨간불일 때 AI 에이전트에게 로그를 던져 원인을 분석하고 수정하는 6단계 워크플로우

## 소요 시간

10-20분 (수동 디버깅 대비 50-70% 단축)

## 사전 준비

- Claude Code 또는 터미널 AI 코딩 에이전트
- GitHub Actions (또는 GitLab CI, CircleCI 등) 설정된 프로젝트
- `gh` CLI 설치 및 인증 완료
- CI 로그 접근 권한

## 왜 CI 디버깅에 AI를 쓰나요?

CI 실패 로그는 대부분 긴 텍스트 속에 핵심 에러가 숨어 있어요. 수백 줄의 출력에서 진짜 원인을 찾는 건 시간 낭비인 경우가 많습니다. AI 에이전트는 로그 전체를 한 번에 읽고, 에러 패턴을 빠르게 잡아내고, 수정 코드까지 제안할 수 있어요.

## Step 1: CI 실패 로그 수집

CI가 실패하면 먼저 로그를 가져옵니다.

### GitHub Actions

```bash
# 최근 실패한 워크플로우 확인
gh run list --status failure --limit 5

# 특정 run의 로그 다운로드
gh run view <run-id> --log-failed

# 로그를 파일로 저장 (AI에게 넘기기 위해)
gh run view <run-id> --log-failed > /tmp/ci-failure.log
```

### GitLab CI

```bash
# glab CLI 사용
glab ci view --branch main
glab ci trace <job-id> > /tmp/ci-failure.log
```

### 범용 방법

```bash
# CI 웹 UI에서 로그를 복사해 파일로 저장
pbpaste > /tmp/ci-failure.log
```

## Step 2: AI 에이전트에게 분석 요청

로그를 AI 에이전트에게 넘기는 방법은 두 가지예요.

### 방법 A: 파일 경로 전달

```
이 CI 로그를 분석해줘. 실패 원인을 찾고 수정 방법을 알려줘.
파일: /tmp/ci-failure.log
```

### 방법 B: MCP 도구 연결

GitHub MCP 서버를 연결해두면 에이전트가 직접 CI 로그를 조회할 수 있어요.

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    }
  }
}
```

연결 후 프롬프트:

```
main 브랜치의 최근 CI 실패를 확인하고 원인을 분석해줘.
```

## Step 3: 에러 유형별 분석 패턴

AI 에이전트가 잘 처리하는 CI 에러 유형과 프롬프트 패턴이에요.

| 에러 유형 | 프롬프트 패턴 | 기대 결과 |
|-----------|-------------|-----------|
| 테스트 실패 | "실패한 테스트의 assertion을 분석하고 코드를 수정해줘" | 테스트 코드 또는 소스 코드 수정 |
| 타입 에러 | "TypeScript 빌드 에러를 모두 찾아서 수정해줘" | 타입 선언 수정 |
| 의존성 충돌 | "package-lock.json 충돌을 해결해줘" | lock 파일 재생성 |
| 린트 에러 | "ESLint/Prettier 에러를 자동 수정해줘" | 포맷팅 수정 |
| 빌드 실패 | "빌드 설정 문제를 분석하고 webpack/vite 설정을 수정해줘" | 빌드 설정 수정 |
| 환경 변수 누락 | "필요한 환경 변수를 CI 설정에서 확인해줘" | 환경 변수 목록 |
| 타임아웃 | "어떤 단계에서 시간이 오래 걸리는지 분석해줘" | 병목 지점 식별 |

## Step 4: 수정 사항 적용 및 검증

AI가 제안한 수정을 로컬에서 먼저 확인합니다.

```bash
# 1. 수정 사항 적용 후 로컬 테스트
npm test          # 또는 pytest, go test 등

# 2. 린트 체크
npm run lint

# 3. 빌드 테스트
npm run build

# 4. 통과하면 커밋 & 푸시
git add -A
git commit -m "fix: resolve CI failure in test suite"
git push
```

### 로컬 CI 재현이 어려울 때

```bash
# act로 GitHub Actions를 로컬에서 실행
act -j build

# Docker 기반 재현
docker run --rm -v $(pwd):/app -w /app node:20 npm test
```

## Step 5: 반복 실패 방지 패턴

같은 유형의 CI 실패가 반복되면, AI 에이전트에게 방지 장치를 요청합니다.

### Pre-commit 훅 추가

```
CI에서 자주 실패하는 린트 에러를 커밋 전에 잡는 pre-commit 훅을 만들어줘.
```

### CI 워크플로우 개선

```yaml
# .github/workflows/ci.yml 개선 예시
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint
      # 린트를 별도 job으로 분리하면 실패 원인을 빠르게 파악

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test -- --reporter=verbose
      # verbose 리포터로 실패 테스트 상세 출력

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
```

### CLAUDE.md에 CI 규칙 추가

```markdown
## CI/CD 규칙

- 커밋 전 반드시 `npm run lint && npm test` 실행
- CI 실패 시 로그를 먼저 확인하고 수정
- 새 의존성 추가 시 lock 파일 커밋 필수
- 환경 변수가 필요한 경우 CI secrets에도 등록
```

## Step 6: 자동 수정 파이프라인 구축

CI 실패를 감지하고 AI 에이전트가 자동으로 수정 PR을 만드는 워크플로우입니다.

```yaml
# .github/workflows/ai-fix.yml
name: AI Auto-Fix CI Failures

on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

jobs:
  ai-fix:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Get failure logs
        run: |
          gh run view ${{ github.event.workflow_run.id }} \
            --log-failed > /tmp/ci-log.txt
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: AI analysis & fix
        run: |
          # Claude Code 또는 다른 AI CLI로 분석
          claude -p "CI 로그를 분석하고 수정해줘: $(cat /tmp/ci-log.txt | tail -100)"

      - name: Create fix PR
        run: |
          git checkout -b fix/ci-auto-$(date +%s)
          git add -A
          git commit -m "fix: auto-resolve CI failure"
          git push origin HEAD
          gh pr create --title "fix: auto-resolve CI failure" \
            --body "CI 실패를 AI가 자동 분석하고 수정한 PR입니다."
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

> 이 워크플로우는 **린트, 포맷, 단순 테스트 실패**에 적합해요. 복잡한 로직 버그는 사람이 검토해야 합니다.

## 체크리스트

- [ ] CI 실패 로그 수집 방법 확인 (`gh run view --log-failed`)
- [ ] AI 에이전트에게 로그 전달 파이프라인 구축
- [ ] 에러 유형별 프롬프트 패턴 정리
- [ ] 로컬 CI 재현 환경 세팅 (`act` 또는 Docker)
- [ ] 반복 실패 방지 pre-commit 훅 설정
- [ ] CI 워크플로우 job 분리 (lint / test / build)
- [ ] CLAUDE.md에 CI 관련 규칙 추가
- [ ] (선택) 자동 수정 워크플로우 설정

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| CI 로그 전체를 AI에 넘기면 컨텍스트 초과 | `--log-failed`로 실패 부분만 추출하거나, `tail -200`으로 제한 |
| AI가 수정한 코드를 검증 없이 푸시 | 반드시 로컬 테스트 후 푸시. `npm test` 통과 확인 |
| 환경 변수 관련 실패를 코드에서 해결하려 함 | CI secrets 설정을 먼저 확인 |
| 캐시 관련 실패를 무시 | `actions/cache` 키를 lock 파일 해시로 설정 |
| flaky 테스트를 AI에게 수정 요청 | flaky 테스트는 격리 후 retry 로직 추가 |

## 다음 단계

→ [AI 에이전트 감독 워크플로우](../../workflows/ai-agent-supervision.md)
→ [GitHub Actions AI 코드 리뷰](../../workflows/github-actions-ai-review.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
