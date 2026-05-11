# Claude Code Week 23 신기능 설정 치트시트

> /powerup 대화형 레슨, worktree.baseRef 설정, 플러그인 오프라인 캐시 — 한 페이지 요약

## /powerup — 터미널 인터랙티브 레슨

2026년 4월 1일 출시된 `/powerup`은 터미널 안에서 Claude Code 기능을 직접 체험하는 10개 레슨 시스템입니다.

### 실행 방법

```bash
# 레슨 시작
/powerup

# 특정 레슨 직접 지정
/powerup lesson:3

# 팀 온보딩 워크플로우와 연계
/team-onboarding && /powerup
```

### 레슨 구성

| 레슨 번호 | 주제 |
|-----------|------|
| 1 | Claude Code 기본 사용법 |
| 2 | CLAUDE.md 작성 패턴 |
| 3 | 멀티 에이전트 설정 |
| 4 | Hooks 자동화 |
| 5 | MCP 서버 연결 |
| 6 | 워크트리 병렬 실행 |
| 7 | 비용 최적화 전략 |
| 8 | 팀 협업 워크플로우 |
| 9 | 보안 샌드박스 설정 |
| 10 | 고급 프롬프트 패턴 |

**신규 팀원 온보딩 권장 순서:** 레슨 1 → 2 → 8 → 나머지 순

---

## worktree.baseRef — 워크트리 분기 기준 설정

병렬 에이전트 작업 시 새 워크트리가 어디서 분기되는지 제어합니다.

### 설정값

| 값 | 동작 |
|----|------|
| `fresh` (기본값) | 원격 기본 브랜치 기준 분기 — 로컬 미푸시 커밋 제외 |
| `head` | 현재 로컬 HEAD 기준 분기 — 진행 중인 작업 포함 |

### 설정 방법

```bash
# 전역 설정 (모든 프로젝트)
claude config set worktree.baseRef fresh

# 프로젝트별 설정 (CLAUDE.md 내)
```

```yaml
# CLAUDE.md
worktree:
  baseRef: fresh   # 권장: 깨끗한 상태에서 분기
```

### 언제 어떤 값을 쓰나

```
fresh 사용 상황:
- 여러 독립적인 기능을 병렬로 개발할 때
- 에이전트에게 깨끗한 상태의 코드베이스를 제공하고 싶을 때
- 대형 모노레포에서 디스크 절약이 필요할 때

head 사용 상황:
- 진행 중인 리팩토링에 기반해 에이전트를 추가 투입할 때
- 로컬 변경사항이 전제가 되어야 하는 작업일 때
```

---

## 플러그인 오프라인 캐시

### 문제

`git pull`로 플러그인 업데이트 실패 시 기존 캐시가 삭제되어 오프라인 환경에서 동작 불가.

### 해결

```bash
# 환경변수 설정 — 실패해도 기존 캐시 유지
export CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=true

# .zshrc에 영구 추가
echo 'export CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=true' >> ~/.zshrc
```

**적용 대상:** CI/CD 파이프라인, 네트워크 불안정 환경, 오프라인 개발 머신

---

## 레이트 리밋 2배 확대 (v2.1.133~)

Week 23 업데이트에서 Pro/Max 플랜 레이트 리밋이 2배로 늘었습니다.

### 달라진 점

| 항목 | 이전 | 이후 |
|------|------|------|
| 시간당 요청 수 | 기준값 | 2배 |
| 병렬 에이전트 수 | 제한적 | 더 여유 |
| 장시간 태스크 | 중단 위험 | 안정적 |

### 세션 전략 업데이트

```bash
# 이전: 시간 분산 필요
# 이후: 집중 코딩 세션 가능

# 병렬 에이전트 한 번에 더 많이 실행 가능
claude --worktree  # 에이전트 1: 프론트엔드
claude --worktree  # 에이전트 2: 백엔드
claude --worktree  # 에이전트 3: 테스트 — 이전보다 안정적
```

---

## 기타 Week 23 설정 포인트

### Husky 보호 디렉토리

```bash
# .husky 폴더가 acceptEdits 모드에서 자동 보호됨
# 에이전트가 실수로 git hook을 수정하는 사고 방지

# 수동으로 추가 보호 디렉토리 설정 (CLAUDE.md)
```

```yaml
# CLAUDE.md
protectedPaths:
  - .husky
  - .github
  - scripts/deploy
```

### 레이트 리밋 무한 루프 버그 수정

이전 버전에서 레이트 리밋 도달 시 옵션 다이얼로그가 반복되는 문제가 수정됐습니다.
v2.1.133 이상으로 업데이트하면 자동 해결됩니다.

```bash
# 버전 확인
claude --version

# 업데이트
npm update -g @anthropic-ai/claude-code
```

---

## 팀 온보딩 체크리스트 (Week 23 기준)

```
신규 팀원 합류 시:
[ ] /team-onboarding 실행으로 프로젝트 컨텍스트 자동 설정
[ ] /powerup 레슨 1-3 완료 (기본 사용법, CLAUDE.md, 멀티 에이전트)
[ ] CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=true 환경변수 추가
[ ] worktree.baseRef: fresh 설정 확인
[ ] 팀 CLAUDE.md에서 보호 경로 확인
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
