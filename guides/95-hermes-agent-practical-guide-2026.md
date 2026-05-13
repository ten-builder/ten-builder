# Hermes Agent 실전 가이드 2026 — 자기 개선 오픈소스 AI 에이전트 제대로 쓰기

> NousResearch가 만든 오픈소스 AI 에이전트 Hermes Agent — Docker 설치부터 Skills 시스템, Claude Code와의 차이점, 실전 코딩 워크플로우까지

## 왜 Hermes Agent인가

2026년 AI 에이전트 생태계에서 Hermes Agent는 독특한 위치를 차지해요. Claude Code, Codex CLI, Gemini CLI 등 기존 터미널 에이전트들이 코드 생성에 특화된 반면, Hermes는 **사용할수록 나아지는 자기 개선 구조**를 핵심으로 설계했습니다.

NousResearch가 2026년 2월 오픈소스로 공개한 이 에이전트는 출시 3개월 만에 140,000 GitHub 스타를 달성했고, Telegram/Discord/Slack 등 16개 메시징 플랫폼을 지원하면서 "어디서나 동작하는 에이전트"를 표방해요.

| 항목 | Hermes Agent | Claude Code |
|------|-------------|-------------|
| 라이선스 | MIT (오픈소스) | 상업용 |
| 자기 개선 | Skills 루프 + 영구 메모리 | 없음 |
| 설치 방식 | Docker / pip | npm |
| 코딩 특화 | 범용 에이전트 | 코딩 전용 에이전트 |
| 메시징 통합 | 16개 플랫폼 | VS Code/터미널 전용 |
| 모델 선택 | 자유 (OpenRouter BYOK) | Claude 전용 |

---

## 설치

### Docker (권장)

```bash
# 최신 이미지 풀
docker pull nousresearch/hermes-agent:latest

# 게이트웨이 실행
docker run -d \
  --name hermes \
  --restart unless-stopped \
  -v ~/.hermes:/opt/data \
  nousresearch/hermes-agent gateway run
```

### pip 설치

```bash
pip install hermes-agent
hermes setup          # 초기 설정 마법사
hermes gateway run    # 게이트웨이 시작
```

### 초기 설정

```bash
# 모델 설정 (OpenRouter 키 필요)
hermes model          # 사용 가능한 모델 목록

# Telegram 연결 (선택)
hermes connect telegram

# 상태 확인
hermes doctor
```

---

## TUI — 터미널 인터페이스

Hermes의 TUI는 단순한 CLI가 아닌 **풀 터미널 UI**예요. Claude Code의 인터랙티브 모드와 유사하지만, 세션 관리와 히스토리 검색이 더 강해요.

```bash
hermes tui            # TUI 실행
```

TUI 안에서 쓸 수 있는 주요 슬래시 커맨드:

| 커맨드 | 기능 |
|--------|------|
| `/skill list` | 설치된 스킬 목록 |
| `/skill run <name>` | 스킬 직접 실행 |
| `/memory` | 영구 메모리 확인 |
| `/history` | 대화 히스토리 검색 |
| `/model` | 모델 전환 |
| `/session new` | 새 세션 시작 |
| `/cron list` | 예약 작업 목록 |

---

## Skills 시스템 — Hermes의 핵심

Hermes의 가장 독특한 기능은 **자기 개선 Skills 시스템**이에요. 에이전트가 반복 작업을 수행하다 보면 스스로 Skill을 만들고, 다음 실행에서 그 Skill을 재사용해요.

스킬은 `~/.hermes/skills/` 폴더에 Markdown 파일로 저장돼요. [agentskills.io](https://agentskills.io)와 호환되어 외부 스킬을 가져오거나 직접 만든 스킬을 공유할 수 있어요.

### 스킬 구조 예시

```markdown
# Git PR 자동 리뷰

**트리거:** PR 번호를 주면 diff를 가져와 코드 품질, 보안, 테스트를 리뷰

## 실행 절차
1. `gh pr diff {번호}` 로 diff 수집
2. 변경 파일 분류 (로직/설정/테스트)
3. 카테고리별 리뷰 포인트 도출
4. 요약 리포트 생성
```

### 코딩 관련 유용한 스킬 예시

```bash
# 스킬 설치 (agentskills.io)
hermes skill install pr-reviewer
hermes skill install code-review
hermes skill install test-generator

# 직접 스킬 실행
hermes skill run pr-reviewer
```

---

## 메모리 레이어 구조

Hermes는 4개 레이어로 컨텍스트를 관리해요:

| 레이어 | 내용 | 저장소 |
|--------|------|--------|
| Persistent Notes | 에이전트가 직접 큐레이션하는 장기 지식 | SQLite + 파일 |
| Session History | 전체 대화 히스토리 (FTS 검색 지원) | SQLite FTS5 |
| User Model | 사용자 선호도와 작업 패턴 학습 | Honcho |
| Procedural Memory | 재사용 가능한 스킬(방법론) | Markdown 파일 |

이 구조 덕분에 Hermes는 새 세션을 시작해도 이전 컨텍스트를 잃지 않아요. Claude Code나 Codex CLI가 세션이 끊기면 처음부터 다시 시작해야 하는 것과 대비돼요.

---

## 코딩 워크플로우에 Hermes 쓰기

Hermes는 코드 생성보다 **오케스트레이션과 자동화**에 강해요. Claude Code와 조합하면 좋은 결과를 얻을 수 있어요.

### 패턴 1: 일상 자동화 + 코드 생성 분리

```
Hermes → 반복 작업 자동화 (PR 체크, 일정 리마인더, 리포트)
Claude Code → 코드 작성, 리팩토링, 디버깅
```

### 패턴 2: Hermes로 Claude Code 조율

```bash
# Hermes TUI에서
> claude-code 실행해서 src/api/ 리팩토링해줘, 완료되면 알려줘
```

Hermes가 Claude Code를 서브프로세스로 실행하고, 결과를 Telegram으로 보내줘요.

### 패턴 3: 코드 리뷰 자동화

```bash
# cron으로 매일 아침 8시 PR 상태 리포트
hermes cron add "0 8 * * *" "열린 PR 목록을 요약해서 Telegram으로 보내줘"
```

---

## Claude Code와 함께 쓰기 — 실전 조합

두 도구는 경쟁 관계가 아니라 **역할이 다른 조합**이에요:

```bash
# Hermes: 상태 관리와 알림
hermes tui
> 오늘 커밋할 내용이 있는지 확인하고 남은 이슈 요약해줘

# Claude Code: 실제 코드 작업
claude
> 오늘 작업할 feature 브랜치 만들고 구현 시작해줘
```

| 작업 | 추천 도구 |
|------|----------|
| 코드 작성 / 리팩토링 | Claude Code |
| 반복 작업 자동화 | Hermes (cron + skills) |
| 다중 서비스 알림 | Hermes (메시징 통합) |
| 장기 컨텍스트 유지 | Hermes (영구 메모리) |
| 테스트 작성 / CI 수정 | Claude Code |
| 프로젝트 상태 트래킹 | Hermes |

---

## 설치 체크리스트

- [ ] Docker 또는 pip으로 Hermes Agent 설치
- [ ] `hermes setup` 으로 초기 설정 완료
- [ ] 모델 선택 (OpenRouter API 키 설정)
- [ ] `hermes doctor` 로 상태 정상 확인
- [ ] TUI 실행해서 슬래시 커맨드 테스트
- [ ] Telegram 또는 Discord 연결 (선택)
- [ ] 첫 번째 cron 작업 등록
- [ ] `~/.hermes/skills/` 폴더에 커스텀 스킬 추가

## 문제 해결

| 증상 | 해결 |
|------|------|
| `hermes doctor` 오류 | `docker logs hermes` 로 로그 확인 |
| 봇 토큰 무효 | Telegram BotFather에서 토큰 재발급 |
| 세션 응답 없음 | `hermes gateway restart` |
| 스킬 실행 실패 | `hermes skill validate <name>` |
| 처음부터 다시 시작 | `rm -rf ~/.hermes && hermes setup` |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
