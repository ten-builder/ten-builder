# Claude Code Hooks 치트시트

> Claude Code 훅 시스템 핵심 이벤트와 설정 패턴 — 한 페이지 요약

## 훅이란?

Claude Code 훅은 세션 라이프사이클의 특정 시점에 자동으로 실행되는 스크립트예요. `.claude/settings.json`에 정의하고, 프로젝트에 커밋하면 팀 전체가 동일한 자동화를 공유할 수 있어요.

## 12가지 라이프사이클 이벤트

| 이벤트 | 실행 시점 | 대표 용도 |
|--------|----------|----------|
| `SessionStart` | 세션 시작/재개 시 | 환경 변수 검증, 초기 설정 |
| `UserPromptSubmit` | 프롬프트 제출 직후, 처리 전 | 입력 필터링, 컨텍스트 주입 |
| `PreToolUse` | 도구 실행 직전 | 위험 명령 차단, 파일 경로 검증 |
| `PermissionRequest` | 권한 확인 다이얼로그 표시 시 | 자동 승인/거부 규칙 |
| `PostToolUse` | 도구 실행 직후 | 린팅, 포매팅, 감사 로그 |
| `PostToolUseFailure` | 도구 실행 실패 시 | 에러 로깅, 자동 복구 시도 |
| `SubagentStart` | 서브에이전트 시작 시 | 서브에이전트 컨텍스트 설정 |
| `SubagentStop` | 서브에이전트 종료 시 | 결과 수집, 정리 |
| `Stop` | 세션 종료 시 | 데스크톱 알림, 요약 저장 |
| `Notification` | Claude가 알림 발생 시 | Slack/Discord 알림 전송 |
| `PreCompact` | 컨텍스트 압축 직전 | 중요 정보 보존 처리 |
| `Setup` | 최초 프로젝트 설정 시 | 의존성 설치, 환경 구성 |

## 핸들러 타입 3가지

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "matcher": "Write",
        "command": "prettier --write $FILEPATH"
      }
    ]
  }
}
```

| 타입 | 설명 | 사용 시나리오 |
|------|------|-------------|
| `command` | 셸 명령어 실행, stdin으로 JSON 수신 | 린팅, 포매팅, 스크립트 실행 |
| `prompt` | Claude 모델에 단일 프롬프트 전송 | 코드 리뷰, 품질 체크 |
| `agent` | 별도 Claude 에이전트 실행 | 복잡한 검증, 멀티스텝 작업 |

## 실전 설정 예제

### 1. 파일 저장 시 자동 포매팅

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "matcher": "Write",
        "command": "npx prettier --write \"$FILEPATH\""
      }
    ]
  }
}
```

**핵심:** `matcher`에 `Write`를 지정하면 파일 쓰기 도구 실행 후에만 동작해요.

### 2. 위험 명령 차단 (PreToolUse)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "matcher": "Bash",
        "command": "echo '$ARGUMENTS' | python3 -c \"import sys,json; args=json.load(sys.stdin); cmd=args.get('command',''); exit(1 if any(w in cmd for w in ['rm -rf /','DROP TABLE','force push']) else 0)\""
      }
    ]
  }
}
```

**핵심:** PreToolUse에서 exit code 1을 반환하면 해당 도구 실행이 차단돼요.

### 3. 세션 종료 시 데스크톱 알림

```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "osascript -e 'display notification \"Claude 작업 완료\" with title \"Claude Code\"'"
      }
    ]
  }
}
```

### 4. ESLint 자동 검사

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "matcher": "Write",
        "command": "npx eslint --fix \"$FILEPATH\" 2>/dev/null || true"
      }
    ]
  }
}
```

### 5. 커밋 메시지 검증

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "prompt",
        "matcher": "Bash",
        "prompt": "이 git commit 메시지가 Conventional Commits 규칙을 따르는지 검증해주세요: $ARGUMENTS"
      }
    ]
  }
}
```

## 설정 파일 위치

| 파일 | 범위 | 공유 |
|------|------|------|
| `.claude/settings.json` | 프로젝트 | ✅ Git 커밋 가능 |
| `~/.claude/settings.json` | 전역 (모든 프로젝트) | ❌ 개인 설정 |

## matcher 패턴

| matcher 값 | 매칭 대상 |
|------------|----------|
| `Write` | 파일 쓰기 |
| `Bash` | 셸 명령어 실행 |
| `Read` | 파일 읽기 |
| `Edit` | 파일 수정 |
| `Glob` | 파일 검색 |
| `Grep` | 텍스트 검색 |
| (생략) | 모든 도구에 적용 |

## 환경 변수

훅 실행 시 자동으로 제공되는 변수들:

| 변수 | 설명 |
|------|------|
| `$FILEPATH` | 대상 파일 경로 (Write/Edit 시) |
| `$ARGUMENTS` | 도구에 전달된 인자 JSON |
| `$TOOL_NAME` | 실행된 도구 이름 |
| `$SESSION_ID` | 현재 세션 ID |

## 추천 시작 조합

처음 훅을 도입한다면 이 3가지부터 시작하세요:

1. **PostToolUse + Write** → 자동 포매팅 (prettier/black)
2. **PreToolUse + Bash** → 위험 명령 차단
3. **Stop** → 데스크톱 알림

이 세 가지만으로도 대부분의 작업 품질과 안전성을 확보할 수 있어요.

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 훅이 실행 안 됨 | `settings.json` 경로 확인 — `.claude/settings.json`이 맞는지 체크 |
| matcher 오타 | 도구 이름은 PascalCase (`Write`, `Bash`, `Edit`) |
| command가 무한 루프 | PostToolUse에서 파일을 다시 쓰면 훅이 재실행됨 — 조건 분기 필요 |
| JSON 파싱 에러 | `$ARGUMENTS`는 JSON 문자열 — 파이프로 `jq`나 `python3` 사용 |
| 훅 타임아웃 | 기본 60초 제한 — 오래 걸리는 작업은 백그라운드로 실행 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
