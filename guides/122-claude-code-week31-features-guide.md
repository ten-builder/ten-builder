# Claude Code Week 31 실전 가이드 — Opus 4.8 Dynamic Workflows, Fast Mode 실전 활용

> 2026년 6월 1~5일 업데이트(v2.1.160~v2.1.162)에서 챙겨야 할 핵심 변경 정리

## 소요 시간

15–20분

## 이번 주 핵심 요약

| 기능 | 변경 내용 | 영향 |
|------|-----------|------|
| `ultracode` 트리거 | Dynamic Workflow 트리거 이름 변경 | Routines/Workflow 설정 마이그레이션 필요 |
| `/effort` 기본값 저장 | 선택한 effort 레벨이 새 세션에도 유지 | 반복 설정 불필요 |
| `claude agents --json` | 대기 원인(`waitingFor`) 포함 | 모니터링 자동화 강화 |
| 백그라운드 세션 안정화 | 재연결·충돌 버그 다수 수정 | 장시간 실행 신뢰성 향상 |
| `/terminal-setup` GPU 가속 비활성화 | VS Code/Cursor/Windsurf 글자 깨짐 방지 | 통합 터미널 사용자 필수 |
| 병렬 툴 독립 결과 | Bash 실패 시 같은 배치 다른 툴 취소 안 됨 | 멀티 툴 워크플로 안정성 향상 |

---

## 1. Opus 4.8 Dynamic Workflows 실전 패턴

### 1-1. `ultracode` 트리거로 마이그레이션

v2.1.160부터 Dynamic Workflow 트리거 이름이 `dynamic-workflow` → `ultracode`로 변경됐어요.

기존 Routines나 워크플로 설정을 쓰고 있다면 즉시 변경이 필요합니다:

```yaml
# 이전 (v2.1.159 이하)
trigger: dynamic-workflow

# 이후 (v2.1.160+)
trigger: ultracode
```

Claude Code에서 직접 확인하는 방법:

```bash
/routines
# 열린 루틴 목록에서 trigger: dynamic-workflow 항목 선택 후 수정
```

### 1-2. Fast Mode와 Effort Control 조합

Opus 4.8은 **Fast Mode**와 **Effort Control**을 함께 쓸 때 가장 효율적입니다.

```bash
# 세션 시작 시 effort 레벨 설정 (v2.1.162부터 새 세션에 기본값으로 유지)
/effort low     # 빠른 반복 작업 (코드 포맷, 단순 수정)
/effort medium  # 일반 구현 (기본값)
/effort high    # 복잡한 설계, 보안 코드 리뷰
/effort max     # 아키텍처 결정, 심층 디버깅
```

**실전 전략:**

| 작업 유형 | 권장 설정 | 이유 |
|-----------|-----------|------|
| 빠른 프로토타이핑 | Fast Mode + `low` | 속도 우선, 토큰 절감 |
| 기능 구현 | 기본 모드 + `medium` | 균형 |
| PR 리뷰 | 기본 모드 + `high` | 품질 우선 |
| 보안 감사 | 기본 모드 + `max` | 정확도 최우선 |

v2.1.162에서 `/effort`를 한 번 설정하면 이후 새 세션에서도 유지돼요. 매번 입력할 필요가 없습니다.

---

## 2. 백그라운드 세션 안정화 업데이트

### 2-1. 주요 수정 사항

이번 주에 백그라운드 세션 관련 버그가 집중적으로 수정됐습니다:

```bash
# /resume로 백그라운드 세션 복구 (v2.1.162에서 안정화)
/resume

# claude agents 명령으로 대기 중인 세션 확인
claude agents --json | python3 -c "
import sys, json
agents = json.load(sys.stdin)
for a in agents:
    if a.get('waitingFor'):
        print(f\"[대기] {a['name']}: {a['waitingFor']}\")
"
```

**수정된 주요 버그:**

- 백그라운드 세션 재연결 후 대화 기록 소실 → 수정 완료
- `--bg` 실행 중 "socket missing" 오류 → 수정 완료
- `claude agents` 에서 완료된 서브에이전트가 실행 중으로 표시 → 수정 완료
- Workflow 에이전트가 자체 워크트리 안 파일 편집 불가 → 수정 완료

### 2-2. 안정적인 장시간 에이전트 실행 패턴

```bash
# 1. 백그라운드로 실행
claude --bg "코드베이스 전체 의존성 업그레이드 후 테스트"

# 2. 상태 모니터링 (새 기능: done/total 표시)
claude agents
# 출력 예시:
# [3/12] codebase-upgrade  (현재 작업 중인 서브태스크)

# 3. 특정 세션 상세 확인
claude agents --json | python3 -c "
import sys, json
for a in json.load(sys.stdin):
    print(a['name'], '|', a.get('status'), '|', a.get('waitingFor',''))
"

# 4. 대기 중인 세션 깨우기
claude agents attach <session-id>
```

---

## 3. 병렬 툴 독립 실행

### 3-1. 변경 내용

v2.1.161부터 **같은 배치의 Bash 명령이 하나 실패해도 다른 툴은 계속 실행**됩니다.

이전에는 병렬 툴 중 하나라도 실패하면 전체 배치가 중단됐어요. 지금은 각 툴이 독립적으로 결과를 반환합니다.

```bash
# 이제 이런 병렬 작업에서 mkdir 실패가 npm install을 막지 않음
# (에이전트가 내부적으로 병렬 실행할 때 적용)
mkdir -p /some/path   # 실패해도
npm install           # 독립적으로 실행됨
```

### 3-2. 실전 적용

멀티 툴 워크플로 설계 시 이 특성을 활용할 수 있어요:

```bash
# CLAUDE.md에 병렬 처리 힌트 추가
echo "## 병렬 실행 가능 작업
- 의존성 설치와 환경 설정은 독립적으로 실행 가능
- 여러 파일 읽기는 동시에 처리
- 테스트 스위트별 독립 실행" >> CLAUDE.md
```

---

## 4. UX 개선 사항

### 4-1. `/terminal-setup` 으로 글자 깨짐 해결

VS Code, Cursor, Windsurf의 통합 터미널에서 글자가 깨진다면:

```bash
/terminal-setup
# GPU 가속 자동 비활성화 → 재시작 후 정상 렌더링
```

### 4-2. 슬래시 커맨드 자동완성 UX 변경

v2.1.162부터 자동완성 메뉴에서 슬래시 커맨드를 클릭하면 **바로 실행이 아니라 입력창에 채워집니다**. Enter를 눌러야 실행돼요.

실수로 실행되는 상황을 방지하기 위한 변경이에요. 처음에 낯설 수 있지만 금방 적응됩니다.

### 4-3. Remote Control 상시 표시

Remote Control이 이제 시작 메시지 대신 **하단 고정 pill**로 항상 표시됩니다. 세션 링크를 바로 확인할 수 있어요:

```bash
# 하단에 항상 보임
[Remote Control: https://claude.ai/code/sessions/...]
```

### 4-4. Windsurf → Devin Desktop 이름 변경

Windsurf IDE가 Devin Desktop으로 리브랜딩됨에 따라 `/ide`, `/terminal-setup`, `/scroll-speed` 메뉴에서도 이름이 변경됐습니다.

---

## 5. 보안 강화

### 5-1. 빌드 도구 설정 파일 쓰기 전 확인

`acceptEdits` 모드에서 이제 코드 실행 권한을 가진 빌드 도구 설정 파일을 쓰기 전에 확인을 요청합니다:

```
# 확인 대상 파일들
.npmrc
.yarnrc*
bunfig.toml
.bazelrc
.pre-commit-config.yaml
.devcontainer/
```

실수로 악의적인 설정이 주입되는 것을 방지하는 가드레일이에요.

### 5-2. WebFetch 권한 규칙 수정

명시적인 `WebFetch(domain:...)` deny/ask/allow 규칙이 이제 사전 승인된 도메인보다 우선합니다:

```json
// settings.json
{
  "permissions": {
    "deny": ["WebFetch(domain:suspicious-site.com)"],
    "allow": ["WebFetch(domain:api.trusted.com)"]
  }
}
```

---

## 6. MCP 관련 개선

### 6-1. 연결 안 된 커넥터 숨기기

```bash
/mcp
# 로그인하지 않은 claude.ai 커넥터가 "미사용 커넥터 표시" 뒤에 숨겨짐
# 실제로 쓰는 MCP 서버만 빠르게 확인 가능
```

### 6-2. `claude mcp` 시크릿 노출 수정

`claude mcp list/get/add` 명령에서 `${VAR}` 환경변수가 더 이상 실제 값으로 확장되지 않아요. 크레덴셜 헤더와 URL 시크릿도 마스킹됩니다.

### 6-3. MCP 서브-1000ms timeout 처리

1000ms 미만으로 설정한 `timeout` 값이 이전에는 모든 툴 호출을 1초 후 강제 종료했어요. 이제는 해당 값을 무시하고 `MCP_TOOL_TIMEOUT`이나 기본값을 사용합니다.

```json
// 이 설정은 이제 안전하게 무시됨 (기존엔 모든 호출 실패)
{
  "mcpServers": {
    "my-server": {
      "timeout": 500
    }
  }
}
```

---

## 체크리스트

- [ ] Dynamic Workflow 트리거를 `ultracode`로 변경
- [ ] `/effort` 기본값 설정 (medium이 아닌 다른 레벨 쓴다면)
- [ ] 통합 터미널 글자 깨짐 있으면 `/terminal-setup` 실행
- [ ] `claude mcp` 명령어 실행 시 시크릿 노출 여부 확인
- [ ] `.npmrc`, `.bazelrc` 등 빌드 설정 파일 관련 워크플로 확인

---

## 다음 단계

→ [Claude Code Routines + Dreaming + Outcomes 실전 가이드](93-claude-code-routines-dreaming-outcomes-guide.md)

→ [AI 에이전트 비상 정지 및 복구 치트시트](../cheatsheets/ai-agent-emergency-stop-cheatsheet.md)

→ [멀티에이전트 세션 병렬 관리](../claude-code/playbooks/66-multitasking-agents-session-management.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
