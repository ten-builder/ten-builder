# Claude Code Week 18 실전 가이드 — ultraplan 자동 클라우드, /resume, /model 영속화

> 2026년 4월 22~28일 릴리스(v2.1.118~v2.1.121) 주요 업데이트를 정리하고, 각 기능을 바로 활용하는 방법을 다룹니다.

## 이번 주 핵심 변경 사항

| 기능 | 버전 | 영향도 |
|------|------|--------|
| `/ultraplan` 자동 클라우드 환경 생성 | v2.1.118 | 상 |
| `/resume` 세션 요약 재개 | v2.1.118 | 상 |
| `/model` 설정 영속화 | v2.1.118 | 중 |
| `CLAUDE_CODE_FORK_SUBAGENT=1` | v2.1.118 | 중 |
| `SendMessage` 자동 에이전트 재개 | v2.1.120 | 중 |
| Agent tool `resume` 파라미터 제거 | v2.1.121 | 하 |

---

## 1. /ultraplan — 자동 클라우드 환경 생성

### 변경 내용

기존에는 `/ultraplan`으로 클라우드 플래닝을 시작하기 전에 claude.ai/code에서 직접 클라우드 환경을 만들어야 했습니다. 이제 `/ultraplan` 실행 시 기본 클라우드 환경이 없으면 자동으로 생성합니다.

### 사용 방법

```bash
# 터미널에서 실행 — 클라우드 환경 없어도 바로 작동
/ultraplan "인증 미들웨어를 JWT + Redis 세션으로 교체"
```

실행하면:
1. 기본 클라우드 환경 자동 생성 (없는 경우)
2. claude.ai/code에서 백그라운드 플래닝 시작
3. 터미널은 즉시 자유롭게 사용 가능
4. 플랜 완성 후 링크 공유 → 섹션별 코멘트 가능

### 주의 사항

```bash
# 환경 자동 생성을 원하지 않는 경우
# claude.ai/code에서 수동으로 환경 설정 후 사용
```

---

## 2. /resume — 오래된 세션 요약 재개

### 변경 내용

오래되거나 대화가 길어진 세션을 `/resume`으로 재개할 때, 전체 내용을 다시 읽는 대신 AI가 핵심 내용을 요약해 컨텍스트 소비를 줄입니다.

### 사용 시나리오

```bash
# 어제 작업하다 중단한 세션 재개
/resume

# Claude가 판단하여 요약 제안:
# "이 세션은 2,400 토큰 규모입니다.
#  요약본으로 재개할까요? (컨텍스트 84% 절약)"
# → Y 입력 시 핵심 맥락만 로드
```

### 팁

긴 세션은 저장하지 않고 그냥 닫아도 됩니다. 다음 날 `/resume`으로 돌아와도 AI가 이전 작업의 핵심을 파악해 이어서 진행합니다.

---

## 3. /model — 설정 영속화

### 변경 내용

이전에는 `/model`로 모델을 변경해도 재시작 시 프로젝트 설정(CLAUDE.md)의 기본값으로 돌아갔습니다. 이제 `/model` 선택이 `~/.claude/settings.json`에 저장되어 재시작 후에도 유지됩니다.

### 동작 방식

```bash
# 모델 변경
/model opus

# 재시작 후에도 opus 유지
# 시작 헤더에 모델 출처 표시:
# "claude-opus-4-7 [user settings]"  ← 사용자가 선택한 모델
# "claude-sonnet-4-6 [project pin]"  ← 프로젝트 기본값
```

### 우선순위

| 우선순위 | 설정 위치 | 적용 방식 |
|----------|-----------|-----------|
| 1순위 | `/model` 명령 (사용자 선택) | `~/.claude/settings.json` |
| 2순위 | 프로젝트 핀 (CLAUDE.md) | 프로젝트 설정 |
| 3순위 | 관리형 설정 | 조직 정책 |

---

## 4. CLAUDE_CODE_FORK_SUBAGENT=1 — 포크 서브에이전트

### 변경 내용

기존 서브에이전트는 새 대화로 시작해 부모 컨텍스트를 갖지 못했습니다. 포크 서브에이전트는 부모의 전체 대화 컨텍스트를 상속받아 작업 일관성이 높아집니다.

### 설정 방법

```bash
# .env 또는 셸 설정에 추가
export CLAUDE_CODE_FORK_SUBAGENT=1

# 또는 특정 실행에만 적용
CLAUDE_CODE_FORK_SUBAGENT=1 claude
```

### 언제 쓰는가

```bash
# 포크 서브에이전트가 유리한 경우
# - 큰 리팩터링에서 컴포넌트별 하위 작업 분배
# - 모듈 간 의존성이 높은 변경
# - 부모가 수집한 정보를 서브에이전트가 재사용해야 할 때

# 일반 서브에이전트가 유리한 경우
# - 완전히 독립된 작업 (독립 실행 가능한 스크립트 작성 등)
# - 컨텍스트 오염 방지가 우선일 때
```

---

## 5. SendMessage 자동 에이전트 재개

### 변경 내용

`SendMessage` 도구로 중단된 에이전트에 메시지를 보내면, 이전에는 에러가 반환됐습니다. 이제 자동으로 에이전트를 백그라운드에서 재개한 뒤 메시지를 전달합니다.

### SDK 활용 예시

```python
# Python SDK 예시
import anthropic

client = anthropic.Anthropic()

# 에이전트가 중단 상태여도 자동 재개
result = client.agents.send_message(
    agent_id="agent-abc123",
    message="이전 작업에서 타입 에러가 발생했어. 수정해줘."
)
# 에러 없이 자동 재개 후 처리
```

---

## 6. Agent tool 변경: resume 파라미터 제거

### 마이그레이션

```python
# 이전 방식 (v2.1.121 이전)
agent_tool.run(action="resume", agent_id="agent-xyz")

# 새로운 방식 (v2.1.121 이후)
send_message(to="agent-xyz", message="계속해줘")
```

기존 `resume` 파라미터를 사용하는 코드가 있다면 `SendMessage`로 교체해야 합니다.

---

## Week 18 마이그레이션 체크리스트

- [ ] `/ultraplan` 사용 시 클라우드 환경 수동 생성 단계 제거
- [ ] 오래된 세션 재개 시 `/resume` 활용 (컨텍스트 절약)
- [ ] `/model` 명령으로 모델 변경 후 재시작 테스트
- [ ] Agent tool `resume` 파라미터 사용 코드 → `SendMessage` 교체
- [ ] 포크 서브에이전트 활성화 여부 결정 (`CLAUDE_CODE_FORK_SUBAGENT=1`)

---

**최신 변경 사항:** [Claude Code Changelog](https://code.claude.com/docs/en/changelog)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
