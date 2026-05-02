# Claude Code Week 19 실전 가이드 — alwaysLoad MCP, PostToolUse Hooks, 동적 비주얼

> 2026년 4월 29일~5월 2일 릴리스(v2.1.122~v2.1.125) 핵심 업데이트를 정리하고 바로 활용하는 방법을 다룹니다.

---

## 이번 주 핵심 변경 3가지

1. **MCP `alwaysLoad` 옵션** — 툴 검색 지연 없이 항상 로드
2. **`PostToolUse` Hooks 전체 툴 지원** — 모든 툴 출력 가로채기 및 교체
3. **Hooks에서 MCP 툴 직접 호출** — 훅 체인 구성이 가능해짐

---

## 1. MCP alwaysLoad — 지연 없이 툴 즉시 사용

기존에는 MCP 서버의 툴이 "필요할 때" 지연 로드됐습니다. `alwaysLoad: true`를 설정하면 세션 시작 시 모든 툴이 즉시 로드됩니다.

**설정 방법:**

```json
// .claude/claude.json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["my-mcp-server"],
      "alwaysLoad": true
    }
  }
}
```

**언제 쓰나요?**

| 상황 | 권장 설정 |
|------|-----------|
| 매 세션 항상 쓰는 서버 (GitHub, DB) | `alwaysLoad: true` |
| 가끔만 쓰는 서버 | 기본값 (지연 로드) |
| 대규모 툴셋 서버 | 기본값 (컨텍스트 절약) |

자주 쓰는 GitHub MCP, Supabase MCP는 `alwaysLoad: true`로 설정하면 첫 질문부터 바로 사용할 수 있습니다.

---

## 2. PostToolUse Hooks — 모든 툴 출력 가로채기

기존 `PostToolUse` Hooks는 일부 툴만 지원했습니다. 이번 업데이트로 **모든 툴**의 출력을 가로채고 교체할 수 있게 됐습니다.

**설정 예시 — 파일 읽기 후 자동 포맷 검사:**

```json
// .claude/hooks.json
{
  "PostToolUse": [
    {
      "matcher": { "tool_name": "Read" },
      "hooks": [
        {
          "type": "command",
          "command": "echo '파일 읽기 완료: $CLAUDE_TOOL_RESULT_PATH'"
        }
      ]
    },
    {
      "matcher": { "tool_name": "Bash" },
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/scripts/log-bash-output.sh"
        }
      ]
    }
  ]
}
```

**Hooks에서 MCP 툴 직접 호출:**

이제 훅 스크립트 안에서 MCP 툴을 직접 호출할 수 있습니다.

```bash
#!/bin/bash
# PostToolUse 훅에서 Slack MCP로 알림 전송
claude mcp call slack send_message \
  --channel "#ai-coding-log" \
  --text "파일 변경: $CLAUDE_TOOL_RESULT_PATH"
```

**활용 패턴:**

| 훅 시나리오 | 설명 |
|------------|------|
| 파일 수정 후 자동 린트 | Edit 툴 → ESLint 실행 |
| Bash 실행 후 로그 저장 | Bash 툴 → 실행 이력 DB 저장 |
| 코드 생성 후 테스트 트리거 | Write 툴 → 관련 테스트 자동 실행 |
| MCP 툴 호출 후 Slack 알림 | 모든 툴 → 팀 채널 공유 |

---

## 3. 플러그인 정리 — plugin prune

자동 설치된 플러그인 의존성 중 사용하지 않는 것을 정리하는 명령어가 추가됐습니다.

```bash
# 고아 플러그인 정리
claude plugin prune

# 플러그인 제거 + 의존성 함께 정리
claude plugin uninstall my-plugin --prune
```

레포별로 플러그인이 자동 설치되다 보면 더 이상 안 쓰는 의존성이 쌓입니다. 주 1회 `plugin prune`을 실행하는 습관을 들이면 Claude Code 시작 속도가 빨라집니다.

---

## 4. /skills 검색 박스

스킬이 많아질수록 `/skills` 목록에서 원하는 것을 찾기 어려웠습니다. 이번 업데이트로 타입-투-필터 검색 박스가 추가됐습니다.

```bash
# 스킬 목록 열기
/skills

# 검색창에 "github" 입력 → GitHub 관련 스킬만 필터링
```

스킬이 10개 이상이면 검색이 훨씬 편해집니다.

---

## 5. 동적 비주얼 렌더링 (v2.1.125)

코드 복잡도 지표나 데이터 분석 결과를 텍스트 대신 인라인 차트/다이어그램으로 표시할 수 있게 됐습니다.

```bash
# 코드 복잡도 시각화 요청
"이 파일들의 순환 복잡도를 차트로 보여줘"

# 데이터 분석 시각화
"이 CSV 데이터의 분포를 히스토그램으로 보여줘"
```

데이터 사이언스 작업이나 코드 품질 분석 시 유용하게 쓸 수 있습니다.

---

## 실전 세팅 — Week 19 기능 총활용

```json
// .claude/claude.json — 추천 설정
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}" },
      "alwaysLoad": true
    },
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase"],
      "alwaysLoad": false
    }
  }
}
```

```json
// .claude/hooks.json — PostToolUse 자동화
{
  "PostToolUse": [
    {
      "matcher": { "tool_name": "Write" },
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/scripts/run-lint-on-write.sh"
        }
      ]
    }
  ]
}
```

---

## Week 19 핵심 요약

| 기능 | 변경 전 | 변경 후 |
|------|---------|---------|
| MCP 툴 로드 | 지연 로드 (필요 시) | `alwaysLoad: true`로 즉시 로드 |
| PostToolUse Hooks | 일부 툴만 지원 | 모든 툴 지원 |
| Hooks → MCP 호출 | 불가 | 직접 호출 가능 |
| 플러그인 관리 | 수동 정리 | `plugin prune` 자동화 |
| /skills | 전체 스크롤 | 타입-투-필터 검색 |
| 결과 렌더링 | 텍스트/표 | 동적 차트/다이어그램 |

---

**이전 가이드:** [Claude Code Week 18 실전 가이드](./79-claude-code-week18-features-guide.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
