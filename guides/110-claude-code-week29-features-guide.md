# Claude Code Week 29 실전 가이드 — 핀 백그라운드 세션, continueOnBlock, /code-review 총정리

> 2026년 5월 26~29일 릴리스(v2.1.147~v2.1.153) 핵심 업데이트를 정리하고 실전에서 바로 쓸 수 있는 방법을 안내합니다.

## 소요 시간

15~20분

## 주요 업데이트 개요

Week 29에는 에이전트 운영 안정성과 코드 리뷰 자동화에 집중한 변경이 한꺼번에 도착했습니다. 핵심은 세 가지입니다.

1. **핀 백그라운드 세션** — 유휴 상태에서도 세션이 유지되고 업데이트 시 자동 재시작
2. **continueOnBlock 훅 옵션** — 훅 차단 시 에이전트가 멈추지 않고 진행 여부를 설정
3. **/code-review 명령어** — `/simplify`가 /code-review로 재편, 버그 탐지와 PR 인라인 코멘트 지원

---

## Step 1: 핀 백그라운드 세션 활용

### 변경 내용

`claude agents`에서 `Ctrl+T`로 고정한 백그라운드 세션이 이제 유휴 상태에서도 자동으로 종료되지 않습니다.

추가 동작:
- Claude Code 업데이트 발생 시 핀 세션을 자동 재시작하여 업데이트 적용
- 메모리 압박이 있을 때 비핀 세션부터 정리, 핀 세션은 마지막까지 유지
- 유휴 상태로 남은 빈 백그라운드 세션은 5분 후 자동 회수 (핀 제외)
- macOS에서 백그라운드 에이전트가 개인 정보 보호 설정에 "Claude Code"로 표시되고 업그레이드 후에도 권한 유지

### 실전 활용 패턴

```bash
# 백그라운드 에이전트 실행
claude agents

# Ctrl+T 로 세션 고정
# 장시간 작업 도중 Claude Code 업데이트가 발생해도 세션 유지됨
```

**언제 쓰는가:**
- 빌드/테스트 자동화처럼 1시간 이상 걸리는 작업
- 밤새 실행하는 크론 기반 에이전트
- 팀이 공유하는 CI 보조 에이전트

---

## Step 2: continueOnBlock 훅 옵션 설정

### 변경 내용

`PostToolUse` 훅이 차단(block) 응답을 반환했을 때 에이전트가 즉시 중단되지 않고 계속 진행하도록 설정할 수 있습니다.

### 설정 방법

`CLAUDE.md` 또는 훅 설정 파일에 `continueOnBlock: true` 옵션을 추가합니다.

```yaml
# hooks/post-tool-use.yaml
hooks:
  PostToolUse:
    - matcher: ".*"
      hooks:
        - type: command
          command: "./scripts/quality-check.sh"
          continueOnBlock: true   # 차단 시에도 에이전트 계속 진행
```

**기본값(false):** 훅이 차단 응답을 반환하면 에이전트가 그 자리에서 멈추고 사용자 확인 대기

**continueOnBlock: true:** 훅 차단 결과를 로그로 남기고 다음 단계로 넘어감

### 사용 시나리오

| 상황 | 권장 설정 |
|------|----------|
| 코드 품질 경고 (중단 불필요) | `continueOnBlock: true` |
| 보안 검사 실패 (반드시 중단) | `continueOnBlock: false` (기본값) |
| 알림 전송 실패 (비중요) | `continueOnBlock: true` |
| 배포 전 최종 검증 | `continueOnBlock: false` |

```bash
# 훅 스크립트 예시 — 경고는 로그만 남기고 계속 진행
#!/bin/bash
# scripts/quality-check.sh
RESULT=$(eslint --format json "$@" 2>/dev/null)
ERRORS=$(echo "$RESULT" | jq '[.[] | .errorCount] | add // 0')

if [ "$ERRORS" -gt 0 ]; then
  echo "ESLint 오류 $ERRORS 건 발견 — 로그 저장 후 진행" >&2
  echo "$RESULT" >> /tmp/eslint-log.json
  exit 2   # 차단 응답 (continueOnBlock: true 면 계속 진행)
fi
exit 0
```

---

## Step 3: /code-review 명령어 활용

### 변경 내용

기존 `/simplify` 명령어가 `/code-review`로 이름을 바꾸고 기능도 확장됐습니다.

**주요 기능:**
- 지정한 effort 수준으로 버그·정확성 문제 보고
- `--comment` 플래그로 GitHub PR에 인라인 코멘트 직접 게시
- `/feedback` 명령어가 컨텍스트 압축 이전 대화까지 포함하여 리포트 생성 개선

### 기본 사용법

```bash
# 현재 변경사항 리뷰 (기본 effort)
/code-review

# 높은 effort로 심층 버그 탐지
/code-review high

# PR 인라인 코멘트로 바로 게시
/code-review --comment

# effort 지정 + 인라인 코멘트
/code-review high --comment
```

### effort 수준별 차이

| effort | 탐지 범위 | 소요 시간 | 권장 상황 |
|--------|----------|----------|----------|
| `low` | 명백한 버그, 타입 오류 | 빠름 | 빠른 확인 |
| `medium` (기본) | 로직 오류, 엣지 케이스 | 보통 | 일반 PR 리뷰 |
| `high` | 보안 취약점, 성능 문제 포함 | 느림 | 배포 전 최종 검토 |

### PR 워크플로우에 통합하기

```bash
# 1. 기능 구현 후 변경사항 확인
git diff HEAD

# 2. 코드 리뷰 실행 (PR 생성 전)
/code-review high

# 3. 지적 사항 수정 후 PR 생성
gh pr create --title "feat: 새 기능 추가" --body "..."

# 4. PR에 인라인 코멘트로 리뷰 결과 공유
/code-review --comment
```

---

## Step 4: 기타 주목할 변경 사항

### v2.1.151~v2.1.153 버그 수정

**안정성 개선:**

| 항목 | 내용 |
|------|------|
| `--bare` 모드 회귀 수정 | 인터랙티브 세션에서 MCP 툴 누락 버그 수정 |
| 플러그인 스크립트 권한 | macOS/Linux에서 공식 마켓플레이스 플러그인 "Permission denied" 수정 |
| 멀티 인스턴스 상태바 | 여러 Claude Code를 실행할 때 `/model` 변경이 다른 세션 상태바에 잘못 표시되던 문제 수정 |
| `claude update` 채널 | 릴리스 채널 설정을 무시하고 최신 버전을 설치하던 버그 수정 |
| MCP 재연결 루프 | 선택적 GET SSE 스트림이 없는 상태 저장 MCP 서버가 `tools/list`에서 루프되던 회귀 수정 |
| 시작 레이턴시 | claude.ai MCP 연결이 많을 때 이벤트 루프 스톨 감소 |

### 유휴 세션 자동 정리

```
# 빈 유휴 백그라운드 세션은 5분 후 자동 회수 (핀 제외)
# 메모리 관리가 자동화되어 오래된 세션 누적 문제 해결
```

### /feedback 개선

```bash
# 이제 컨텍스트 압축 이전 대화까지 포함
/feedback "에이전트가 긴 세션 초반의 지시를 무시했습니다"
```

---

## 실전 체크리스트

```
Week 29 업데이트 적용 확인

[ ] claude update 실행하여 최신 버전 업데이트
[ ] 장기 실행 에이전트에 Ctrl+T 핀 설정
[ ] 기존 훅 설정에 continueOnBlock 옵션 검토
[ ] /simplify 대신 /code-review 사용으로 전환
[ ] PR 리뷰 워크플로우에 /code-review --comment 통합
```

```bash
# 버전 확인
claude --version

# 업데이트
claude update
```

---

## 다음 단계

→ [Git Worktree 기반 병렬 에이전트 실전 가이드](../guides/91-git-worktree-parallel-agents-guide.md)

→ [Claude Code Agent View 실전 가이드](../guides/99-claude-code-agent-view-guide.md)

→ [AI 에이전트 비상 정지 및 복구 치트시트](../cheatsheets/ai-agent-emergency-stop-cheatsheet.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)

**구독:** [@ten-builder](https://youtube.com/@ten-builder)
