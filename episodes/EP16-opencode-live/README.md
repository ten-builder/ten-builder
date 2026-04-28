# EP16: OpenCode 실전 — 오픈소스 AI 코딩 에이전트 직접 써보기

> GitHub Stars 12만을 넘긴 오픈소스 AI 코딩 에이전트 OpenCode. 설치부터 Claude Code와의 실전 비교, MCP 연동까지 직접 해봤습니다.

## 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- OpenCode 5분 설치 및 초기 설정
- Zen 라우터로 로컬 모델(Ollama) 연결하기
- Claude Code와의 실전 차이점 비교
- MCP 서버 연동 패턴
- 어떤 상황에서 OpenCode를 선택해야 하는가

---

## OpenCode란?

SST 팀이 Bun + TypeScript로 만든 오픈소스 터미널 AI 코딩 에이전트입니다. 특징은 **모델 독립성** — Claude, GPT, Gemini, 그리고 Ollama 로컬 모델까지 75개 이상의 제공자를 지원합니다.

```
GitHub Stars: 120,000+
설치 방법: npm install -g opencode
라이선스: MIT
```

---

## 설치 및 초기 설정

### 1단계: 설치

```bash
# npm으로 설치
npm install -g opencode

# 또는 bun 사용
bun install -g opencode

# 설치 확인
opencode --version
```

### 2단계: 첫 실행

```bash
# 프로젝트 디렉토리에서 실행
cd my-project
opencode
```

처음 실행하면 TUI(터미널 UI)가 열립니다. 상단에 모델 선택, 하단에 대화 입력창이 보입니다.

### 3단계: 기본 설정 파일

```json
// ~/.config/opencode/config.json
{
  "model": "anthropic/claude-sonnet-4-5",
  "theme": "dark",
  "keybindings": {
    "submit": "Enter",
    "newline": "Shift+Enter"
  }
}
```

---

## Zen 라우터로 모델 연결하기

Zen은 OpenCode가 직접 운영하는 모델 라우터입니다. OpenCode 팀이 코딩 에이전트 작업에 최적화된 모델을 벤치마킹해서 제공합니다.

```bash
# Zen을 통한 모델 설정
opencode model set zen/claude-sonnet

# Ollama 로컬 모델 연결 (비용 0원)
ollama pull qwen2.5-coder:7b
opencode model set ollama/qwen2.5-coder:7b
```

### 컨텍스트 크기 최적화 (Ollama)

```bash
# 16K 컨텍스트 변형 생성
ollama run qwen2.5-coder:7b
/set parameter num_ctx 16384
/save qwen2.5-coder:7b-16k
/bye

# OpenCode에서 사용
opencode model set ollama/qwen2.5-coder:7b-16k
```

---

## TUI 핵심 단축키

| 단축키 | 동작 |
|--------|------|
| `Ctrl+N` | 새 대화 시작 |
| `Ctrl+L` | 대화 목록 |
| `Ctrl+P` | 프로바이더/모델 전환 |
| `Ctrl+F` | 파일 첨부 |
| `Ctrl+C` | 현재 응답 중단 |
| `?` | 전체 단축키 보기 |

---

## Claude Code vs OpenCode: 실전 비교

| 항목 | Claude Code | OpenCode |
|------|-------------|----------|
| 모델 | Anthropic 전용 | 75개 이상 제공자 |
| UI | 텍스트 기반 | TUI (더 직관적) |
| MCP 통합 | 강력 | 지원 (설정 필요) |
| 비용 | Anthropic 요금제 | 모델별 상이 (로컬 무료) |
| 보안 정책 | 기본 보호 모드 | Glob 패턴 세밀 제어 |
| 컨텍스트 품질 | 높음 | 모델 의존 |
| 자율 실행 | Plan Mode | 기본 지원 |

**OpenCode가 유리한 상황:**
- 로컬 모델로 비용 절감이 필요할 때
- 특정 모델(GPT-o3, Gemini 3 Pro)이 필요할 때
- 다양한 프로바이더를 태스크별로 바꾸고 싶을 때
- 오픈소스 도구 철학을 선호할 때

**Claude Code가 유리한 상황:**
- 대형 코드베이스에서 복잡한 멀티 에이전트 작업
- Agent Teams, Hooks 같은 Anthropic 최신 기능 활용
- 프로덕션 수준의 컨텍스트 품질이 필요할 때

---

## MCP 서버 연동

```bash
# MCP 서버 추가 (파일 시스템)
opencode mcp add filesystem --command "npx @modelcontextprotocol/server-filesystem /path/to/dir"

# MCP 서버 추가 (GitHub)
opencode mcp add github --command "npx @modelcontextprotocol/server-github" \
  --env GITHUB_TOKEN=your_token

# 연결된 MCP 서버 확인
opencode mcp list
```

### config.json으로 MCP 관리

```json
{
  "mcp": {
    "servers": {
      "filesystem": {
        "command": "npx",
        "args": ["@modelcontextprotocol/server-filesystem", "/workspace"],
        "env": {}
      },
      "github": {
        "command": "npx",
        "args": ["@modelcontextprotocol/server-github"],
        "env": {
          "GITHUB_TOKEN": "${GITHUB_TOKEN}"
        }
      }
    }
  }
}
```

---

## 실전 워크플로우: 신규 기능 구현

### 1. 계획 수립 (저비용 모델)

```bash
# 계획 단계는 가벼운 모델로
opencode model set ollama/qwen2.5-coder:7b
opencode "이 프로젝트에 사용자 인증 기능을 추가하는 계획을 세워줘"
```

### 2. 구현 (고성능 모델로 전환)

```bash
# Ctrl+P로 모델 전환
# 구현 단계는 성능 좋은 모델로
opencode model set anthropic/claude-sonnet-4-5
opencode "계획대로 JWT 인증 미들웨어를 구현해줘"
```

### 3. 리뷰 (다른 모델로 교차 검증)

```bash
opencode model set openai/gpt-o3
opencode "방금 작성한 코드의 보안 취약점을 검토해줘"
```

---

## AGENTS.md와 함께 쓰기

OpenCode도 AGENTS.md를 읽습니다. 프로젝트 루트에 배치하면 자동으로 컨텍스트로 주입됩니다.

```markdown
# AGENTS.md

## 프로젝트 규칙
- TypeScript strict mode 사용
- 모든 함수에 JSDoc 주석 작성
- 테스트 없는 PR 금지

## 금지 사항
- console.log 프로덕션 코드 사용 금지
- any 타입 사용 금지
```

---

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| Anthropic 모델 접근 오류 | OpenCode는 Claude 직접 API 지원 종료 — Zen 라우터 또는 다른 모델 사용 |
| 로컬 모델 컨텍스트 부족 | num_ctx 파라미터로 컨텍스트 크기 늘리기 |
| MCP 서버 연결 실패 | `opencode mcp list`로 상태 확인, 환경변수 점검 |
| TUI가 깨져 보임 | 터미널 font를 Nerd Font로 변경 |

---

## 더 알아보기

- [OpenCode 공식 문서](https://opencode.ai)
- [Ollama + OpenCode 로컬 설정 가이드](../workflows/ollama-claude-hybrid-workflow.md)
- [MCP 서버 프로덕션 보안 운영](../cheatsheets/mcp-production-security-cheatsheet.md)
- [AI 코딩 에이전트 선택 가이드 2026](../cheatsheets/ai-coding-agent-selector-2026.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
