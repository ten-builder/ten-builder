# Claude Code Week 23 실전 가이드 — /powerup 대화형 레슨, 워크트리 설정, 레이트 리밋 2배 총정리

> 2026년 5월 9~11일 릴리스(v2.1.133~v2.1.138) 핵심 업데이트 — `/powerup` 대화형 튜토리얼, `worktree.baseRef` 설정, 플러그인 오프라인 캐시, 레이트 리밋 2배 확대, 주요 버그 수정 총정리

## 이번 주의 핵심 변화

Week 23은 학습 경험 개선, 에이전트 격리 설정 강화, 그리고 오래된 버그들을 한꺼번에 정리한 주다. 특히 `/powerup` 명령어는 Claude Code를 처음 접하는 팀원 온보딩에 유용하고, `worktree.baseRef` 설정은 병렬 에이전트 작업 시 브랜치 기준점을 정밀하게 제어할 수 있게 해준다.

---

## v2.1.138 — 워크트리 기준점 설정 + 샌드박스 경로 커스터마이징

### worktree.baseRef 설정

병렬 에이전트 실행 시 각 서브에이전트가 어느 커밋을 기준으로 워크트리를 생성할지 제어한다.

```json
// .claude/settings.json
{
  "worktree": {
    "baseRef": "head"
  }
}
```

| 값 | 동작 | 언제 쓰나 |
|---|---|---|
| `"fresh"` (기본값) | `origin/<default-branch>` 기준 체크아웃 | 항상 최신 원격 코드에서 시작하고 싶을 때 |
| `"head"` | 로컬 `HEAD` 기준 체크아웃 | 아직 push하지 않은 커밋을 서브에이전트에 포함시킬 때 |

**주의:** v2.1.128부터 `EnterWorktree`는 로컬 HEAD를 기준으로 동작했지만, v2.1.138에서 기본값이 `fresh`로 변경됐다. 기존 동작을 유지하려면 명시적으로 `"head"`를 설정해야 한다.

```bash
# 실제 사용 예시 — push 전 커밋을 서브에이전트에서 검증하고 싶을 때
# .claude/settings.json에 아래 추가
echo '{"worktree": {"baseRef": "head"}}' > .claude/settings.json

# 그다음 서브에이전트 실행
claude "현재 브랜치 코드를 테스트하고 결과 보고해줘"
```

### 샌드박스 경로 커스터마이징 (Linux/WSL)

Linux와 WSL 환경에서 bubblewrap과 socat 실행 파일 경로를 명시적으로 지정할 수 있다.

```json
// .claude/settings.json
{
  "sandbox": {
    "bwrapPath": "/usr/local/bin/bwrap",
    "socatPath": "/usr/local/bin/socat"
  }
}
```

기본 경로(`/usr/bin/bwrap`, `/usr/bin/socat`)가 아닌 위치에 설치된 경우 필요하다.

---

## v2.1.137 — /powerup 대화형 레슨 + 플러그인 오프라인 캐시

### /powerup 명령어

Claude Code의 주요 기능을 애니메이션 데모와 함께 단계별로 배울 수 있는 대화형 튜토리얼이다.

```bash
# 터미널에서 실행
claude
/powerup
```

팀에 새로운 개발자가 합류했을 때 `/team-onboarding` 명령어와 함께 사용하면 온보딩 시간을 크게 줄일 수 있다.

```bash
# 팀 온보딩 순서
/team-onboarding    # 팀 특화 가이드 생성
/powerup            # 기능별 인터랙티브 레슨
```

### 플러그인 오프라인 캐시

네트워크가 불안정하거나 오프라인 환경에서 작업할 때 기존 플러그인 마켓플레이스 캐시를 유지하는 환경변수다.

```bash
# .bashrc 또는 .zshrc에 추가
export CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1
```

`git pull`이 실패해도 이전에 받아둔 플러그인 목록을 그대로 사용한다. 사내 네트워크 제한이 있는 환경에서 유용하다.

### .husky 디렉토리 보호

`acceptEdits` 모드에서 `.husky` 디렉토리가 보호 목록에 추가됐다. AI가 Git 훅을 실수로 수정하는 일이 없어진다.

```bash
# 이제 이런 실수가 방지됨
# 기존: acceptEdits 모드에서 .husky/pre-commit이 수정될 수 있었음
# 변경: .husky/** 는 수정하려면 명시적 승인 필요
```

---

## v2.1.136 — UX 버그 수정 모음

### 주요 수정 사항

이번 릴리스는 사용성을 방해하던 버그들을 집중 수정했다.

| 문제 | 수정 내용 |
|------|-----------|
| 프롬프트 자동 제출 | Enter 입력 시 제안이 자동 제출되던 문제 — 이제 Tab 또는 방향키로만 선택 가능 |
| 키보드 단축키 힌트 | `keybindings.json`에서 리바인딩한 키가 UI에 반영되지 않던 문제 수정 |
| 언어 설정 초기화 | `/settings`에서 언어 변경 후 Escape 누르면 되돌아가던 문제 수정 |
| `/terminal-setup` 자동완성 | 정확한 이름 입력 없이도 부분 검색으로 나타나도록 개선 |
| AskUserQuestion 텍스트 삭제 | "Chat about this" 클릭 시 질문 텍스트가 지워지던 문제 수정 |
| MCP 툴 결과 표시 | 긴 MCP 도구 응답이 보이지 않던 문제 수정 |

---

## v2.1.133 — 레이트 리밋 무한 루프 수정 + 캐시 회귀 수정

### 레이트 리밋 다이얼로그 무한 루프 수정

레이트 리밋에 걸렸을 때 옵션 다이얼로그가 반복해서 열리며 세션이 충돌하던 심각한 버그가 수정됐다.

```
이전 동작: 레이트 리밋 → 다이얼로그 → 자동 닫힘 → 다시 열림 → 반복 → 세션 종료
수정 후:   레이트 리밋 → 다이얼로그 → 사용자 선택 대기 → 정상 처리
```

### --resume 캐시 미스 회귀 수정

`--resume`으로 세션을 재개할 때 캐시가 제대로 활용되지 않아 토큰 비용이 늘어나던 문제가 해결됐다.

```bash
# 이제 이렇게 해도 캐시가 정상 작동함
claude --resume <session-id>
```

---

## 이번 주 Claude Code 레이트 리밋 2배 확대

Week 23에서 가장 큰 변화는 사실 코드 변경이 아니다. **5월 6일부터 모든 유료 플랜의 5시간 레이트 리밋이 2배로 확대**됐다.

| 변경 사항 | 내용 |
|-----------|------|
| 5시간 레이트 리밋 | Pro, Max 5x, Max 20x, Team, Enterprise 전부 2배 |
| 피크타임 스로틀링 | Pro, Max 계정에서 완전 제거 |
| 적용 시점 | 2026년 5월 6일부로 즉시 적용 |
| 주간 한도 | 변경 없음 |

```bash
# 실제 체감 변화
# 이전: 집중 코딩 세션 30-40분 후 레이트 리밋
# 지금: 동일 속도로 60-80분 연속 작업 가능
# 피크타임(평일 낮)에도 동일한 한도 적용
```

이 변화는 장시간 실행 에이전트 작업에서 특히 의미있다. 대규모 리팩토링이나 멀티 파일 작업이 중간에 끊기는 빈도가 크게 줄어든다.

---

## 실전 활용 요약

### 이번 주 꼭 적용할 설정

```json
// .claude/settings.json — 병렬 에이전트 + 오프라인 환경 대비
{
  "worktree": {
    "baseRef": "head"
  }
}
```

```bash
# .zshrc — 플러그인 오프라인 캐시 (네트워크 불안정한 환경에서)
export CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1
```

### 팀 온보딩 플로우 업데이트

```bash
# 신규 팀원 온보딩 (Week 23 기준 권장 순서)
claude
/team-onboarding    # 1. 팀 환경 이해
/powerup            # 2. 기능별 실습 레슨
/skills             # 3. 사용 가능한 스킬 확인
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
