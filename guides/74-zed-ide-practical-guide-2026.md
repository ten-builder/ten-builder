# Zed IDE 실전 가이드 2026 — ACP로 AI 에이전트 팀 구성하기

> Rust로 만든 초고속 에디터 Zed. 2026년엔 단순한 빠른 에디터가 아니라 AI 에이전트 플랫폼이 됐다.

## 왜 Zed인가

VS Code 대비 2배 빠른 시작 속도, 16배 낮은 메모리 사용량. 여기에 **Agent Client Protocol(ACP)** 로 외부 AI 에이전트를 에디터 안에 연결한다.

Cursor처럼 특정 모델에 묶이지 않는다. Claude Code, Gemini CLI, Codex CLI 중 원하는 걸 골라 붙이면 된다.

## 설치

```bash
# macOS
brew install --cask zed

# Linux
curl -f https://zed.dev/install.sh | sh
```

처음 실행하면 AI 에이전트 설정을 안내한다. 건너뛰고 직접 설정하는 걸 추천한다.

## ACP 기본 개념

ACP는 Zed가 주도한 오픈 표준이다. AI 에이전트가 에디터와 통신하는 방식을 표준화했다.

```
에디터 (Zed)
    ↕ ACP
AI 에이전트 (Claude Code / Gemini CLI / Codex CLI)
    ↕
파일 시스템 / 터미널 / MCP 서버
```

에이전트가 파일 읽기, 편집, 터미널 실행, 코드베이스 탐색을 에디터 UI에서 제어할 수 있다.

## Claude Code 연결하기

```bash
# Claude Code가 없으면 먼저 설치
npm install -g @anthropic-ai/claude-code

# Zed에서 ACP 에이전트 등록
# Command Palette → "zed: add agent"
```

`~/.config/zed/settings.json`:

```json
{
  "agent": {
    "default_model": {
      "provider": "anthropic",
      "model": "claude-sonnet-4-5"
    },
    "external_agents": [
      {
        "name": "Claude Code",
        "command": "claude",
        "args": ["--acp"]
      }
    ]
  }
}
```

## Gemini CLI 연결하기

```bash
npm install -g @google/gemini-cli
```

`settings.json`에 추가:

```json
{
  "agent": {
    "external_agents": [
      {
        "name": "Gemini CLI",
        "command": "gemini",
        "args": ["--acp"]
      }
    ]
  }
}
```

## 에이전트 전환 패턴

| 작업 유형 | 추천 에이전트 | 이유 |
|-----------|-------------|------|
| 대규모 리팩토링 | Claude Code | 컨텍스트 품질, 멀티파일 편집 |
| 1M 토큰 코드베이스 분석 | Gemini CLI | 2M 컨텍스트 윈도우 |
| 단순 수정 / 자동화 스크립트 | Codex CLI | 빠른 실행, 낮은 비용 |
| 보안 감사 | Claude Code | 추론 품질 |

```bash
# 에디터에서 에이전트 전환
# Ctrl+Shift+A → 에이전트 목록에서 선택
```

## MCP 서버 연결

Zed에서 MCP 서버를 직접 관리할 수 있다.

```json
{
  "context_servers": {
    "filesystem": {
      "command": {
        "path": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"]
      }
    },
    "postgres": {
      "command": {
        "path": "npx",
        "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"]
      }
    }
  }
}
```

에이전트가 자동으로 등록된 MCP 서버의 도구를 활용한다.

## 핵심 단축키

| 단축키 | 동작 |
|--------|------|
| `Ctrl+Shift+A` | AI 에이전트 패널 열기 |
| `Ctrl+Enter` | 에이전트에게 전송 |
| `Ctrl+Shift+E` | 에이전트 변경 내용 미리보기 |
| `Ctrl+Z` | 에이전트 변경 취소 |
| `Ctrl+Shift+M` | MCP 서버 목록 |

## 에이전트 권한 제어

에이전트가 실행할 수 있는 작업을 세밀하게 제어한다.

```json
{
  "agent": {
    "tool_permissions": {
      "bash": "ask",
      "file_write": "allow",
      "network": "deny"
    }
  }
}
```

| 권한 값 | 동작 |
|---------|------|
| `allow` | 자동 허용 |
| `ask` | 실행 전 확인 요청 |
| `deny` | 차단 |

## Zed AI vs 외부 에이전트

Zed에는 내장 AI(Zed AI)와 외부 에이전트(ACP) 두 가지 경로가 있다.

| | Zed AI (내장) | 외부 에이전트 (ACP) |
|-|--------------|-------------------|
| 설정 | 간단 | 에이전트 별도 설치 |
| 모델 선택 | 제한적 | 자유로움 |
| 기능 | 코드 완성, 채팅 | 전체 에이전트 기능 |
| 비용 | Zed 구독 포함 | 에이전트별 과금 |

단순 코드 완성은 Zed AI, 복잡한 태스크는 외부 에이전트를 쓰는 게 효율적이다.

## 실전 워크플로우 예시

### 신규 기능 구현

```
1. Gemini CLI로 전체 코드베이스 분석 (1M 토큰 활용)
   → "이 레포의 인증 패턴 분석해줘"

2. Claude Code로 구현
   → "JWT 기반 리프레시 토큰 흐름 추가해줘"

3. Zed AI로 코드 완성 보완
   → 인라인 제안 활용
```

### 레거시 코드 마이그레이션

```
1. Codex CLI로 빠른 패턴 스캔
   → "deprecated API 사용 위치 찾아줘"

2. Claude Code로 일괄 수정
   → "전부 새 API로 교체해줘"

3. Gemini CLI로 전체 검증
   → "변경 후 API 일관성 확인해줘"
```

## 흔한 설정 실수

| 실수 | 해결 |
|------|------|
| ACP 연결 안 됨 | 에이전트 CLI 버전 확인 (`claude --version` ≥ 1.2.0) |
| MCP 서버 인식 안 됨 | Zed 재시작 후 로그 확인 (`~/.local/share/zed/logs/`) |
| 에이전트 응답 느림 | `tool_permissions.bash: "allow"`로 변경 |
| 파일 편집 충돌 | 에이전트 작업 중 직접 편집 금지 |

## Cursor vs Zed 선택 기준

Cursor를 써야 하는 경우:
- VS Code 익스텐션 생태계가 필수인 팀
- AI 기능을 바로 쓰고 싶은 초보자
- Windows 메인 환경

Zed를 써야 하는 경우:
- 여러 AI 에이전트를 상황별로 바꿔 쓰고 싶은 경우
- 에디터 성능이 중요한 대용량 코드베이스
- MCP 서버를 직접 관리하고 싶은 경우
- macOS / Linux 메인 환경

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
