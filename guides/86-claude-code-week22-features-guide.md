# Claude Code Week 22 실전 가이드 — 세션 환경변수, 플러그인 URL 로딩, 터미널 UX 개선 총정리

> 2026년 5월 5~8일 릴리스(v2.1.129~v2.1.132) 핵심 업데이트 — `CLAUDE_CODE_SESSION_ID` 환경변수, `--plugin-url` 플래그, `CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE`, Ctrl+R 히스토리 전역 검색, 터미널 렌더링 개선, 주요 버그 수정 12건+

## 이번 주 요약

Week 22는 "안정성 + 개발자 경험" 집중 릴리스입니다. 눈에 띄는 새 기능 3개와 오랫동안 불편했던 버그들을 한꺼번에 정리했어요. 특히 세션 ID를 쉘 환경변수로 노출하는 변경은 Hooks 자동화를 쓰는 분들에게 바로 유용합니다.

## 새 기능

### 1. CLAUDE_CODE_SESSION_ID 환경변수

Bash 툴 서브프로세스에서 `$CLAUDE_CODE_SESSION_ID` 를 바로 쓸 수 있게 됐어요.

```bash
# Hooks나 Bash 툴에서 세션 ID 활용
echo "현재 세션: $CLAUDE_CODE_SESSION_ID"

# 세션별 로그 분리
LOG_FILE="~/.claude/logs/$CLAUDE_CODE_SESSION_ID.log"
echo "[$(date)] 작업 완료" >> "$LOG_FILE"
```

전에는 `session_id`를 Hook 페이로드에서 파싱해야 했는데, 이제 `$CLAUDE_CODE_SESSION_ID` 하나로 끝납니다.

**활용 패턴:**

| 상황 | 코드 |
|------|------|
| 세션별 임시 디렉토리 | `mkdir -p /tmp/cc-$CLAUDE_CODE_SESSION_ID` |
| 세션 추적 로그 | `echo "$CLAUDE_CODE_SESSION_ID" >> sessions.log` |
| 외부 시스템 연동 | `curl -d "session=$CLAUDE_CODE_SESSION_ID" $WEBHOOK` |

### 2. --plugin-url 플래그

플러그인 `.zip`을 URL에서 직접 로딩할 수 있게 됐어요. 플러그인 마켓플레이스나 사내 배포 서버에서 바로 가져올 수 있습니다.

```bash
# URL에서 플러그인 로딩 (현재 세션에만 적용)
claude --plugin-url https://example.com/my-plugin.zip

# 팀 내부 플러그인 서버 연동
claude --plugin-url https://plugins.team.internal/code-reviewer-v2.zip
```

`--plugin-dir`로 로컬 디렉토리를 지정하는 방식과 함께 쓸 수 있어요. 이번 릴리스에서 `/plugin` 컴포넌트 패널에서 `--plugin-dir`로 로드한 플러그인이 "Marketplace 'inline' not found"로 뜨던 버그도 함께 수정됐습니다.

### 3. 패키지 매니저 자동 업데이트

`CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE` 환경변수를 설정하면 Homebrew나 WinGet 설치본이 백그라운드에서 자동 업그레이드 후 재시작을 안내해요.

```bash
# ~/.zshrc 또는 ~/.bashrc에 추가
export CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1
```

수동으로 `brew upgrade claude-code` 하던 습관을 자동화할 수 있습니다.

### 4. Ctrl+R 히스토리 전역 검색 복원

2.1.124에서 실수로 현재 세션 범위로 좁혀졌던 Ctrl+R 히스토리 피커가 전체 프로젝트 범위로 복원됐어요.

```
Ctrl+R    → 모든 프로젝트의 전체 히스토리 검색 (기본값 복원)
Ctrl+S    → 현재 프로젝트/세션으로 범위 좁히기
```

## 주요 버그 수정

### 터미널 렌더링

```bash
# 노트북 덮개 열거나 Ctrl+Z/fg 후 빈 화면이 뜨던 문제 수정
# → 다음 키 입력 없이도 바로 정상 렌더링

# 대체 화면 렌더러 비활성화 (구형 터미널 호환)
export CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1
```

JetBrains IDE 2025.2 터미널에서 마우스 스크롤이 제멋대로 동작하던 버그도 수정됐습니다.

### 세션 복원

`--resume`에서 이모지가 잘려 `no low surrogate in string` 오류가 나던 버그 수정. 기존 손상된 세션도 로드 시 자동 복구됩니다.

```bash
# 이전에 실패하던 resume이 이제 정상 동작
claude --resume <session-id>
```

### MCP 서버

```bash
# tools/list 실패 시 기존: 0개 툴로 조용히 실패
# 수정 후: 1회 재시도 → "/mcp"에 "connected · tools fetch failed" 표시

# 비인가 MCP 커넥터 표시 개선
# 기존: "failed" → 수정 후: "needs auth"
```

stdio MCP 서버가 비-프로토콜 데이터를 stdout에 쓸 때 메모리가 10GB 이상 증가하던 버그도 수정됐어요.

### 권한/캐시

```bash
# 1시간 프롬프트 캐시 TTL이 5분으로 다운그레이드되던 버그 수정
# Bedrock/Vertex에서 ENABLE_PROMPT_CACHING_1H 설정 시 400 오류 수정

# plan-mode 세션 resume 시 --permission-mode 플래그가 무시되던 버그 수정
claude --resume <session-id> --permission-mode default
```

### /context 토큰 낭비 수정

`/context` 호출 시 ASCII 시각화 그리드가 대화에 덤프되어 매번 ~1,600 토큰을 낭비하던 버그가 수정됐습니다.

## skillOverrides 설정 동작 수정

`.claude/settings.json`의 `skillOverrides` 설정이 이제 제대로 동작해요.

```json
{
  "skillOverrides": {
    "my-skill": "off",              // 모델과 / 슬래시에서 숨김
    "another-skill": "user-invocable-only",  // 모델에서만 숨김
    "third-skill": "name-only"      // 설명 접기
  }
}
```

## EnterWorktree 브랜치 생성 수정

`EnterWorktree`가 이제 원격 `origin/<기본브랜치>`가 아닌 로컬 HEAD에서 새 브랜치를 만들어요. 아직 push 안 된 커밋이 사라지던 문제가 해결됐습니다.

```bash
# 수정 전: 미push 커밋이 있으면 새 worktree에서 커밋이 사라짐
# 수정 후: 로컬 HEAD 기준으로 브랜치 생성 → 미push 커밋 보존
```

## 업그레이드 체크리스트

- [ ] `CLAUDE_CODE_SESSION_ID` 를 기존 Hooks에서 활용하도록 업데이트
- [ ] `CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1` 설정으로 자동 업데이트 활성화
- [ ] `skillOverrides`를 쓰고 있다면 동작 방식 변경 확인
- [ ] `EnterWorktree` 기반 워크플로우에서 로컬 HEAD 기준 동작 확인

## 다음 단계

→ [컨텍스트 엔지니어링 가이드](./63-context-engineering-2026.md)
→ [Claude Code Agent Teams GA 실전 가이드](./71-claude-code-agent-teams-ga-guide.md)
→ [Claude Code Week 21 실전 가이드](./84-claude-code-week21-features-guide.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
