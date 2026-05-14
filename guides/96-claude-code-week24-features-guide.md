# Claude Code Week 24 실전 가이드 — Vim 비주얼 모드, 푸시 알림, Ultrareview CI 모드, 에이전트 개선

> 2026년 5월 11~15일 릴리스(v2.1.139~v2.1.145) 핵심 업데이트 — Vim 비주얼 모드 추가, 모바일 푸시 알림, `claude ultrareview [target]` CI 연동, 에이전트 툴 매칭 개선, 백그라운드 서비스 안정화 총정리

## 이번 주의 핵심 변화

Week 24는 사용자 경험(UX) 개선에 집중된 주다. Vim 사용자를 위한 비주얼 모드 지원, 원격 작업 중 완료 여부를 알려주는 모바일 푸시 알림, CI/CD 파이프라인에서 코드 리뷰를 자동화하는 `ultrareview` CLI 모드가 핵심이다. 에이전트 툴 매칭 방식도 유연해져 대소문자와 구분자에 관계없이 에이전트 역할을 지정할 수 있게 됐다.

---

## v2.1.145 — Vim 비주얼 모드 + 플러그인 경고 개선

### Vim 비주얼 모드 지원

Claude Code의 입력창에서 Vim 비주얼 모드(`v`, `V`)를 사용할 수 있게 됐다. 기존에는 Normal 모드와 Insert 모드만 지원해서 텍스트 블록 선택이 불편했는데, 이번 업데이트로 표준 Vim 워크플로우를 그대로 쓸 수 있다.

```
# Vim 비주얼 모드 사용법
v        — 문자 단위 비주얼 모드
V        — 줄 단위 비주얼 모드 (visual-line)

# 선택 후 조작 예시
vw       — 단어 하나 선택
V3j      — 현재 줄 포함 4줄 선택
d        — 선택 영역 삭제
y        — 선택 영역 복사
```

긴 프롬프트를 작성하다 특정 단락을 통째로 지우거나 복사할 때 유용하다. 비주얼 피드백도 추가돼 선택된 텍스트가 하이라이트 표시된다.

### 플러그인 기본 폴더 경고

`plugin.json`에서 `commands/` 같은 기본 컴포넌트 폴더를 명시적으로 지정하면, 충돌을 방지하기 위해 해당 폴더가 무시된다. 이제 무시될 때 명확한 경고 메시지를 출력한다.

```bash
# 경고 확인 방법
/doctor
claude plugin list
/plugin
```

---

## v2.1.143 — 모바일 푸시 알림 + 환경변수 추가

### 모바일 푸시 알림

Remote Control이 활성화된 상태에서 장시간 에이전트 작업을 돌려놓고 자리를 비웠을 때, 작업 완료나 승인 요청을 모바일로 바로 받을 수 있다.

**설정 방법:**

```json
// .claude/settings.json
{
  "remoteControl": {
    "pushNotifications": true,
    "notifyOnComplete": true,
    "notifyOnPermissionRequest": true
  }
}
```

**활용 시나리오:**

| 상황 | 알림 내용 |
|------|----------|
| 장시간 리팩토링 완료 | "에이전트 작업 완료 — 리뷰 대기 중" |
| 파일 삭제 권한 요청 | "승인 필요: 파일 삭제 요청" |
| 에러로 인한 중단 | "에이전트 중단 — 에러 발생" |

Remote Control 없이도 `terminalSequence` 훅 필드를 통해 데스크탑 알림, 타이틀 바 변경, 벨 소리를 설정할 수 있다.

```json
// .claude/settings.json hooks 예시
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "terminal-notifier -message '에이전트 완료'"
      }]
    }]
  }
}
```

### 새 환경변수 2가지

```bash
# GitHub 플러그인 소스를 SSH 대신 HTTPS로 클론
export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1

# 워크로드 아이덴티티 페더레이션 (기업 환경)
export ANTHROPIC_WORKSPACE_ID="your-workspace-id"
```

`ANTHROPIC_WORKSPACE_ID`는 기업 SSO와 연동된 Claude 계정을 사용하는 환경에서 특히 유용하다.

---

## v2.1.142 — 에이전트 툴 매칭 개선 + 배경 서비스 안정화

### 에이전트 `subagent_type` 유연한 매칭

에이전트에 역할을 지정할 때 대소문자나 구분자(하이픈, 공백, 언더스코어)가 달라도 이제 자동으로 인식한다.

```bash
# 아래 표현이 모두 동일하게 작동
claude --subagent-type "code-reviewer"
claude --subagent-type "Code Reviewer"
claude --subagent-type "code_reviewer"
claude --subagent-type "CodeReviewer"
```

멀티 에이전트 팀을 스크립트로 자동 구성할 때 타이핑 실수로 인한 오류가 줄어든다.

### 백그라운드 서비스 안정화

`claude --bg`(백그라운드 서비스 모드) 사용 시 두 가지 버그가 수정됐다.

| 버그 | 수정 내용 |
|------|----------|
| idle-exit 직전 연결 끊김 | "connection dropped mid-request" 오류 해소 |
| 기업 보안 솔루션 충돌 | 엔드포인트 보안 소프트웨어가 설치된 환경에서 시작 실패 수정 |

원격 개발 환경이나 기업 맥북에서 `claude --bg`를 쓸 때 체감 안정성이 개선된다.

---

## v2.1.141 — `claude ultrareview [target]` CI 연동

### ultrareview 비대화형 실행

기존 `/ultrareview`는 Claude Code 터미널 안에서만 쓸 수 있었다. 이제 `claude ultrareview [target]` 서브커맨드로 CI/CD 파이프라인에서 비대화형으로 실행하고 결과를 stdout으로 받을 수 있다.

```bash
# PR 번호 지정
claude ultrareview pr/123

# 특정 브랜치 대상
claude ultrareview branch/feature/payment-refactor

# 현재 HEAD 기준
claude ultrareview head

# JSON 출력 (파싱용)
claude ultrareview pr/123 --format json
```

**GitHub Actions 연동 예시:**

```yaml
name: AI Code Review

on:
  pull_request:
    branches: [main]

jobs:
  ultrareview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Ultrareview
        run: claude ultrareview pr/${{ github.event.pull_request.number }}
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Post Review Comment
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Ultrareview에서 문제를 감지했습니다. 로그를 확인해 주세요.'
            })
```

**비용과 제한:**

| 항목 | 내용 |
|------|------|
| 요구 버전 | v2.1.86 이상 |
| 계정 | claude.ai Pro 또는 Max |
| 비용 | 변경 크기에 따라 $5~$20/회 |
| 실행 방식 | 클라우드 원격 샌드박스, 멀티 에이전트 병렬 리뷰 |

---

## v2.1.140 — 설정 핫리로드 수정 + 에이전트 색상

### 설정 핫리로드 버그 수정

심볼릭 링크로 연결된 settings 파일이 변경될 때 잘못된 `ConfigChange` 훅이 발동되던 문제가 수정됐다. 팀 공유 설정을 심볼릭 링크로 관리하는 경우 불필요한 훅 실행이 사라진다.

```bash
# 예시: 팀 공유 설정을 심볼릭 링크로 연결
ln -s ~/team-settings/.claude-settings.json .claude/settings.json

# 이제 이 파일이 변경돼도 잘못된 ConfigChange 훅이 발동되지 않음
```

### 에이전트 색상 팔레트 업데이트

멀티 에이전트 실행 시 각 에이전트를 구분하는 색상이 새롭게 정비됐다. 4개 이상 에이전트가 동시에 실행될 때 가독성이 높아진다.

---

## v2.1.139 — 에이전트 `/goal` 명령어 피드백 개선

### `/goal` 실행 시 명확한 피드백

`disableAllHooks` 또는 `allowManagedHooksOnly` 설정이 활성화된 상태에서 `/goal`을 실행하면 기존에는 아무 반응 없이 멈췄다. 이제 설정 충돌을 알려주는 명확한 메시지를 출력한다.

```bash
# 이전: 아무 메시지 없이 멈춤
/goal "PR이 모두 통과될 때까지 반복 수정"

# 이후: 명확한 안내 메시지
/goal "PR이 모두 통과될 때까지 반복 수정"
> /goal을 사용하려면 hooks를 활성화해야 합니다.
> settings.json에서 disableAllHooks를 false로 변경해 주세요.
```

---

## Week 24 빠른 적용 체크리스트

- [ ] Vim 모드 사용자 → 비주얼 모드(`v`, `V`) 사용 흐름 익히기
- [ ] Remote Control 사용자 → 모바일 푸시 알림 설정 활성화
- [ ] CI/CD 파이프라인 → `claude ultrareview pr/<번호>` 단계 추가 검토
- [ ] 팀 공유 설정 심볼릭 링크 → v2.1.140 이상으로 업데이트 (핫리로드 버그 해소)
- [ ] 멀티 에이전트 스크립트 → `subagent_type` 대소문자 자유롭게 사용 가능

---

**지난 주 가이드:** [Week 23 — /powerup, worktree.baseRef, 레이트 리밋 2배](./90-claude-code-week23-features-guide.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
