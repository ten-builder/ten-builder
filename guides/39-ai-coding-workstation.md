# 가이드 39: AI 코딩 워크스테이션 구축 가이드

> 터미널, IDE, CLI 에이전트를 하나의 워크플로우로 통합하는 개발 환경 최적화

## 왜 워크스테이션 레벨에서 설계해야 하나

AI 코딩 도구를 하나씩 설치하는 건 쉽습니다. 하지만 Claude Code, Cursor, Gemini CLI, Aider가 동시에 깔려있으면 어떤 상황에서 뭘 쓸지 혼란스럽죠. 도구를 많이 가진 것과 도구를 잘 쓰는 건 다른 문제예요.

이 가이드에서는 AI 코딩 도구를 **워크스테이션 레벨**에서 설계하는 방법을 다룹니다. 개별 도구가 아니라 전체 개발 환경이 하나의 시스템으로 동작하도록 구성하는 거예요.

## 기본 구조: 3계층 모델

AI 코딩 워크스테이션은 세 계층으로 나눠서 생각하면 정리가 됩니다.

| 계층 | 역할 | 도구 예시 |
|------|------|----------|
| **실행 계층** | 코드 생성, 편집, 테스트 | Claude Code, Cursor, Copilot |
| **오케스트레이션 계층** | 작업 분배, 세션 관리 | tmux, Background Agent, worktree |
| **컨텍스트 계층** | 프로젝트 지식, 규칙, 메모리 | CLAUDE.md, .cursorrules, MCP 서버 |

대부분의 개발자가 실행 계층에만 집중합니다. 하지만 생산성 차이는 오케스트레이션과 컨텍스트 계층에서 나옵니다.

## Step 1: 터미널 환경 설정

### 셸 프로필 최적화

```bash
# ~/.zshrc 또는 ~/.bashrc

# AI 도구 PATH 통합
export PATH="$HOME/.local/bin:$PATH"  # Claude Code, Codex CLI

# 모델 라우팅용 alias
alias cc="claude"                     # Claude Code (기본 에이전트)
alias ccb="claude --background"       # Background Agent
alias gcli="gemini"                   # Gemini CLI (빠른 Q&A)
alias aider="aider --model claude-3.5-sonnet"  # Aider (git 네이티브)

# 프로젝트별 자동 컨텍스트
function cd() {
  builtin cd "$@"
  if [ -f "CLAUDE.md" ]; then
    echo "📋 CLAUDE.md detected"
  fi
  if [ -f ".cursorrules" ]; then
    echo "📋 .cursorrules detected"
  fi
}
```

### tmux 워크스페이스 템플릿

```bash
#!/bin/bash
# ~/scripts/ai-workspace.sh

SESSION="ai-dev"
tmux new-session -d -s $SESSION

# 왼쪽: 메인 코딩 에이전트
tmux send-keys "cd ~/project && claude" C-m

# 오른쪽: 보조 작업
tmux split-window -h
tmux send-keys "cd ~/project" C-m

# 하단: 테스트/빌드 모니터
tmux split-window -v
tmux send-keys "cd ~/project && npm run dev" C-m

tmux attach-session -t $SESSION
```

## Step 2: 도구별 역할 분담

모든 AI 도구에 같은 작업을 시키면 비효율적입니다. 도구마다 잘하는 게 달라요.

| 작업 유형 | 1순위 도구 | 이유 |
|----------|-----------|------|
| 새 기능 구현 | Claude Code | 넓은 컨텍스트 윈도우, 파일 탐색 |
| 빠른 수정 (1-2줄) | Copilot 인라인 | IDE에서 바로 수정 |
| 리팩토링 | Cursor Agent | 멀티파일 편집 UI |
| 코드 리뷰 | Aider + `/review` | Git diff 기반 분석 |
| 디버깅 | Claude Code | 로그 분석, 스택 추적 |
| 문서 생성 | Gemini CLI | 빠른 응답, 무료 |
| 테스트 작성 | Claude Code | 프로젝트 구조 이해 |
| 1회성 질문 | Gemini CLI | 빠른 응답, 컨텍스트 불필요 |

## Step 3: 컨텍스트 파일 표준화

프로젝트마다 AI 도구가 읽는 컨텍스트 파일을 통일하세요.

```
project/
├── CLAUDE.md          # Claude Code 전용 지시사항
├── .cursorrules       # Cursor 전용 규칙
├── .github/
│   └── copilot-instructions.md  # Copilot 커스텀 지시
├── .aider/
│   └── conventions.md # Aider 코딩 컨벤션
└── docs/
    └── ARCHITECTURE.md  # 모든 도구가 참조하는 공유 문서
```

### 핵심 원칙: DRY 컨텍스트

여러 도구에 같은 규칙을 반복하지 마세요. 공유 문서를 만들고 각 도구 설정에서 참조합니다.

```markdown
# CLAUDE.md 예시
## 프로젝트 규칙
- 아키텍처: docs/ARCHITECTURE.md 참조
- 코딩 컨벤션: TypeScript strict, ESLint flat config
- 테스트: Vitest, 커버리지 80% 이상
```

## Step 4: 병렬 작업 패턴

### git worktree + 멀티 에이전트

```bash
# 메인 브랜치에서 worktree 생성
git worktree add ../project-feat-auth feature/auth
git worktree add ../project-fix-perf fix/performance

# 각 worktree에서 독립적으로 AI 에이전트 실행
# 터미널 1
cd ../project-feat-auth && claude "인증 모듈 구현해줘"

# 터미널 2
cd ../project-fix-perf && claude "N+1 쿼리 문제 해결해줘"
```

### Background Agent 활용

```bash
# 백그라운드에서 테스트 작성 실행
claude --background "src/utils/ 디렉토리의 모든 함수에 단위 테스트 추가"

# 결과 확인
claude --resume  # 완료된 세션 이어받기
```

## Step 5: 비용 관리 전략

도구를 많이 쓸수록 비용이 쌓입니다. 간단한 규칙으로 비용을 통제하세요.

| 가격 구간 | 용도 | 도구 |
|-----------|------|------|
| 무료 | 간단한 질문, 문서 생성 | Gemini CLI (free tier) |
| $20/월 | 일상 코딩 | Claude Pro + Code |
| $100-200/월 | 팀 프로젝트, 대규모 작업 | Claude Max + Cursor Pro |

### 비용 절약 팁

1. **모델 라우팅**: 간단한 작업은 Haiku/Flash, 복잡한 작업만 Opus/Pro
2. **캐싱 활용**: CLAUDE.md에 자주 쓰는 지시를 넣으면 프롬프트 캐싱으로 비용 절감
3. **세션 관리**: `/clear`로 불필요한 컨텍스트 정리, 새 작업은 새 세션

## Step 6: 일일 워크플로우 체크리스트

```markdown
## 아침 루틴
- [ ] `git pull` 후 CLAUDE.md 최신 상태 확인
- [ ] 오늘 할 작업 목록 정리
- [ ] AI 도구별 역할 배정

## 코딩 세션
- [ ] 복잡한 기능 → Claude Code (Plan 모드 먼저)
- [ ] 빠른 수정 → IDE 인라인 (Copilot/Cursor)
- [ ] 병렬 가능한 작업 → worktree + Background Agent

## 마무리
- [ ] AI 생성 코드 리뷰 (diff 확인)
- [ ] 테스트 통과 확인
- [ ] 커밋 메시지 직접 작성 (AI 의존 줄이기)
```

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| 모든 작업에 같은 도구 사용 | 작업 유형별 도구 분담표 만들기 |
| CLAUDE.md 없이 매번 같은 지시 반복 | 프로젝트 루트에 컨텍스트 파일 생성 |
| 컨텍스트 윈도우 초과 | 작업 단위를 작게 나누고 새 세션 시작 |
| AI가 만든 코드 그대로 커밋 | 반드시 diff 확인 후 수동 리뷰 |
| 비용 추적 없이 사용 | 월간 사용량 대시보드 설정 |

## 정리

AI 코딩 워크스테이션은 결국 **도구의 조합이 아니라 워크플로우의 설계**입니다.

1. 3계층(실행/오케스트레이션/컨텍스트)으로 구조화하세요
2. 각 도구에 명확한 역할을 부여하세요
3. 컨텍스트 파일을 표준화해서 반복을 줄이세요
4. 병렬 작업 패턴으로 처리량을 높이세요
5. 비용을 추적하고 모델 라우팅으로 최적화하세요

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
