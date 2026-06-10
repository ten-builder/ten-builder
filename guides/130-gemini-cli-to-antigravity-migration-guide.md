# Gemini CLI 종료 완전 대응 가이드 2026 — Antigravity CLI 마이그레이션 6월 18일 전에 끝내기

> Gemini CLI는 2026년 6월 18일부터 요청을 처리하지 않습니다. 이 가이드는 영향받는 개발자가 Antigravity CLI로 무중단 전환하는 방법을 단계별로 다룹니다.

## 마이그레이션 대상 확인

이번 종료는 **모든 사용자에게 적용되지 않습니다.**

| 상태 | 영향 |
|------|------|
| Google AI Pro / Ultra | 6월 18일부터 Gemini CLI 사용 불가 |
| Gemini Code Assist (무료 개인) | 동일 |
| Code Assist Standard / Enterprise | 영향 없음 — 별도 일정 |
| 유료 Gemini API 키 직접 사용 | 영향 없음 |

## Antigravity CLI란

Google이 Gemini CLI를 대체하기 위해 출시한 차세대 터미널 에이전트입니다. 바이너리 이름은 `agy`이며, 내부적으로 Antigravity IDE와 같은 에이전트 엔진을 공유합니다. Gemini CLI와 비교했을 때 주요 차이점:

- `.gemini/` 설정 디렉토리 → `.agents/` (또는 `.agent/`)
- `GEMINI.md` 컨텍스트 파일 → `AGENTS.md`
- Skills 경로: `.gemini/skills/` → `.agents/skills/`
- MCP 설정: `~/.gemini/settings.json` → `mcp_config.json`

## Step 1: Antigravity CLI 설치

```bash
# macOS
brew install --cask antigravity

# 또는 직접 설치
curl -fsSL https://install.antigravity.dev | sh

# Windows
winget install Google.Antigravity

# 설치 확인
agy --version
```

## Step 2: 인증

```bash
# Google 계정으로 인증
agy auth login

# 인증 상태 확인
agy auth status
```

## Step 3: Gemini CLI 설정 이전

가장 빠른 방법은 플러그인 임포트 커맨드를 사용하는 것입니다.

```bash
# 자동 마이그레이션 (권장)
agy plugin import gemini

# 이 커맨드가 자동으로 처리하는 것:
# - .gemini/settings.json → mcp_config.json 변환
# - .gemini/skills/ → .agents/skills/ 이동
# - GEMINI.md → AGENTS.md 변환 (내용 유지)
```

자동 이전이 안 되는 경우 수동으로 처리합니다.

```bash
# Skills 디렉토리 이동
mkdir -p .agents/skills
cp -r .gemini/skills/* .agents/skills/ 2>/dev/null || true

# GEMINI.md → AGENTS.md 복사
cp GEMINI.md AGENTS.md 2>/dev/null || true

# 프로젝트별 설정이 있는 경우
cp .gemini/settings.json .agent/mcp_config.json 2>/dev/null || true
```

## Step 4: 설정 파일 필드명 변환

MCP 서버 설정에서 일부 필드명이 변경되었습니다.

| Gemini CLI | Antigravity CLI |
|------------|-----------------|
| `gemini.mcpServers` | `mcpServers` |
| `checkpointing.enabled` | `agent.checkpointing` |
| `sandbox.command` | `sandbox.exec` |
| `theme` | `ui.theme` |

**변환 예시:**

```json
// Gemini CLI settings.json (이전)
{
  "gemini": {
    "mcpServers": {
      "github": { "command": "npx", "args": ["@modelcontextprotocol/server-github"] }
    }
  },
  "checkpointing": { "enabled": true }
}

// Antigravity CLI mcp_config.json (이후)
{
  "mcpServers": {
    "github": { "command": "npx", "args": ["@modelcontextprotocol/server-github"] }
  },
  "agent": { "checkpointing": true }
}
```

## Step 5: 기존 스크립트 호환성 처리

쉘 스크립트나 자동화에서 `gemini` 명령어를 직접 호출하는 경우:

```bash
# 임시 alias 추가 (~/.zshrc 또는 ~/.bashrc)
alias gemini='agy'

# 또는 심볼릭 링크
ln -sf $(which agy) /usr/local/bin/gemini
```

주요 커맨드 매핑:

| Gemini CLI | Antigravity CLI |
|------------|-----------------|
| `gemini` | `agy` |
| `gemini -m gemini-3-pro` | `agy --model gemini-3-pro` |
| `gemini --sandbox` | `agy --sandbox` |
| `gemini --yolo` | `agy --auto` |
| `gemini -p "..."` | `agy -p "..."` |

## Step 6: AGENTS.md 최적화

Antigravity CLI는 `AGENTS.md` 파일을 프로젝트 컨텍스트로 사용합니다. 기존 `GEMINI.md`를 그대로 사용할 수 있지만, 새 기능을 활용하려면 몇 가지를 추가하는 것이 좋습니다.

```markdown
# AGENTS.md

## 프로젝트 개요
{프로젝트 설명}

## 코딩 규칙
- TypeScript strict mode 사용
- 모든 함수에 JSDoc 작성

## Skills 활용
@skills/pr-reviewer  # PR 리뷰 자동화 스킬
@skills/test-writer  # 테스트 작성 스킬

## MCP 도구
이 프로젝트는 GitHub, Linear MCP가 연결되어 있습니다.
```

## Claude Code와의 역할 분담

Antigravity CLI와 Claude Code를 함께 사용할 때 효과적인 역할 분담:

| 역할 | 도구 | 이유 |
|------|------|------|
| 초기 설계 / 플래닝 | Antigravity CLI | Gemini 3 Pro의 긴 컨텍스트 강점 |
| 구현 / 코드 작성 | Claude Code | SWE-bench 성능 우위 |
| 코드 리뷰 | Antigravity CLI | 멀티모달 분석 + 대규모 diff |
| 병렬 서브에이전트 | Claude Code | Tasks + Agent View 기능 |

```bash
# 플래닝 단계
agy "이 레포의 인증 시스템을 분석하고 JWT 갱신 전략을 제안해줘"

# 구현 단계 (Claude Code로 전환)
claude "위 설계에 따라 JWT refresh token 로직을 구현해줘"
```

## 마이그레이션 체크리스트

- [ ] `agy --version`으로 설치 확인
- [ ] `agy auth status`로 인증 확인
- [ ] `agy plugin import gemini` 또는 수동 이전 완료
- [ ] `.agents/skills/` 파일 정상 동작 확인
- [ ] MCP 서버 연결 확인: `agy /mcp`
- [ ] 기존 스크립트에서 `gemini` 호출 부분 확인 및 수정
- [ ] CI/CD 파이프라인 업데이트
- [ ] 팀원 공지 및 공유

## 자주 묻는 질문

**Q: 6월 18일 이후에도 Gemini API 키로 직접 호출하면 되지 않나요?**

A: 유료 API 키를 직접 사용하는 경우 영향을 받지 않습니다. Google AI Pro/Ultra 구독이나 무료 Gemini Code Assist를 통해 인증하던 사용자만 Antigravity CLI로 전환이 필요합니다.

**Q: 기존 `.gemini/` 디렉토리를 삭제해야 하나요?**

A: 마이그레이션 후 동작을 확인하면 삭제해도 됩니다. 전환 기간 동안은 두 디렉토리를 모두 유지하는 것을 권장합니다.

**Q: Antigravity CLI에서 Gemini 3 Pro 모델을 그대로 쓸 수 있나요?**

A: 네, 동일한 모델을 사용합니다. 기본값이 Gemini 3 Pro이며, `--model` 플래그로 다른 모델을 지정할 수 있습니다.

## 더 알아보기

- [Antigravity CLI 공식 문서](https://antigravity.dev/cli)
- [구글 공식 마이그레이션 가이드](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli)
- [관련 가이드: Antigravity CLI 실전 가이드 2026](./119-antigravity-cli-practical-guide-2026.md)
- [관련 가이드: Google Antigravity IDE 실전 가이드 2026](./85-google-antigravity-ide-practical-guide-2026.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
