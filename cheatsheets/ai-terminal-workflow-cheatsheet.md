# AI 터미널 워크플로우 치트시트 — 터미널 하나로 AI 코딩 완전 정복

> 터미널 설정부터 AI 에이전트 동시 운영까지 — 한 페이지 요약

---

## 터미널 환경 선택

| 터미널 | 특징 | AI 코딩 적합도 |
|--------|------|--------------|
| **Ghostty** | 네이티브 성능, 빠른 렌더링 | ⭐⭐⭐⭐⭐ |
| **Warp** | AI 명령어 자동완성 내장 | ⭐⭐⭐⭐ |
| **iTerm2** | macOS 표준, tmux 통합 | ⭐⭐⭐ |
| **WezTerm** | Lua 커스터마이징 | ⭐⭐⭐ |

> **추천:** Ghostty + tmux 조합이 2026년 기준 AI 코딩에 가장 잘 맞아요.

---

## 필수 CLI 도구 스택

```bash
# 한 번에 설치
brew install starship zoxide atuin fzf bat eza fd ripgrep jq

# zsh 설정에 추가
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"
```

| 도구 | 용도 | 대체 |
|------|------|------|
| **Starship** | AI 컨텍스트 인식 프롬프트 | oh-my-zsh |
| **Zoxide** | `z proj` 로 디렉토리 점프 | cd |
| **Atuin** | 명령어 히스토리 검색/동기화 | `Ctrl+R` |
| **fzf** | 파일/히스토리 퍼지 검색 | grep |
| **bat** | 문법 강조 cat | cat |
| **eza** | 아이콘 포함 ls | ls |

---

## AI 도구별 터미널 alias

```bash
# ~/.zshrc에 추가

# Claude Code
alias c="claude"
alias cr="claude --resume"          # 이전 세션 재개
alias cm="claude --model opus"      # Opus 모델 지정

# Gemini CLI
alias g="gemini"
alias gf="gemini --flash"          # Flash 모델 (빠른 응답)

# Codex CLI
alias cx="codex"
alias cxa="codex --auto"           # 완전 자동 모드

# 자주 쓰는 패턴
alias cfix='claude "이 에러 고쳐줘: $(cat)"'
alias greview='git diff | gemini "이 diff 리뷰해줘"'
```

---

## Claude Code 핵심 단축키

| 단축키 | 동작 |
|--------|------|
| `Ctrl+G` | 외부 편집기($EDITOR)에서 프롬프트 작성 |
| `Ctrl+O` | verbose 모드 — 추론 과정 표시 |
| `Ctrl+R` | Atuin 히스토리 검색 (Claude Code 외부) |
| `Ctrl+C` | 현재 작업 취소 |
| `Ctrl+L` | 화면 지우기 |
| `/clear` | 대화 컨텍스트 초기화 |
| `/compact` | 컨텍스트 압축 (긴 세션에서) |

---

## tmux로 AI 에이전트 동시 운영

```bash
# ~/.tmux.conf 기본 설정
set -g prefix C-a
set -g mouse on
set -g status-position top

# 세션 생성 패턴
tmux new-session -s dev -n main

# 창 분할 예시
# [Claude Code | Gemini CLI]
# [    프로젝트 파일 트리    ]
```

### 권장 레이아웃

```
┌─────────────────┬──────────────────┐
│  claude (메인)   │  gemini (리뷰)   │
├─────────────────┴──────────────────┤
│         git log / 파일 탐색        │
└────────────────────────────────────┘
```

```bash
# 레이아웃 설정 스크립트
tmux split-window -h "gemini"
tmux split-window -v "eza --tree --level=2"
tmux select-pane -t 0
```

---

## 생산성 향상 패턴

### 패턴 1: 에러 즉시 분석

```bash
# 에러 발생 시
!! | claude "방금 에러가 났어. 원인이랑 해결 방법 알려줘"

# 빌드 에러
npm run build 2>&1 | tail -30 | claude "이 빌드 에러 고쳐줘"
```

### 패턴 2: Git diff 자동 리뷰

```bash
# 커밋 전 리뷰
git diff --staged | claude "코드 리뷰해줘. 버그, 개선점, 스타일 문제 알려줘"

# PR 준비
git diff main...HEAD | gemini "PR 설명 초안 작성해줘"
```

### 패턴 3: 히스토리 재활용

```bash
# Atuin으로 이전 AI 명령어 검색
# Ctrl+R 후 "claude" 입력 → 이전에 쓴 claude 명령어 검색

# fzf로 최근 명령어 재활용
alias fh="history | fzf --tac | cut -d' ' -f4-"
```

---

## 환경변수 설정

```bash
# ~/.zshrc 권장 설정

# AI 코딩 기본 모델
export ANTHROPIC_MODEL="claude-sonnet-4-5"
export MAX_THINKING_TOKENS=10000

# Claude Code 에디터 연동
export EDITOR="cursor --wait"       # Cursor 사용 시
# export EDITOR="code --wait"       # VS Code 사용 시

# 터미널 컬러
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
```

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 터미널 느려짐 | tmux 패널을 8개 이상 열지 않기 |
| 컨텍스트 초과 | `/compact` 또는 `/clear` 후 재시작 |
| 명령어 충돌 | `which c` 로 alias 확인 후 충돌 해결 |
| Starship 느림 | `STARSHIP_SHELL_TIMEOUT=500` 설정 |
| Claude Code 멈춤 | `Ctrl+C` → `/resume` 로 재개 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
