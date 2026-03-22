# OpenCode 치트시트

> 120K+ GitHub 스타의 오픈소스 터미널 AI 코딩 에이전트 — 한 페이지 요약

## 설치

| 방법 | 명령어 |
|------|--------|
| macOS (Homebrew) | `brew install opencode` |
| Linux (curl) | `curl -fsSL https://opencode.ai/install.sh \| bash` |
| Windows (Scoop) | `scoop install opencode` |
| Go | `go install github.com/opencode-ai/opencode@latest` |

```bash
# 설치 확인
opencode --version

# 첫 실행 — 대화형 설정
opencode
```

## 핵심 특징

| 기능 | 설명 |
|------|------|
| 75+ 모델 지원 | OpenAI, Anthropic, Google, Ollama, LM Studio 등 |
| 로컬 모델 연동 | `ollama run` 모델을 직접 연결 가능 |
| LSP 통합 | 언어 서버 프로토콜로 코드 인텔리전스 제공 |
| 코드베이스 맵 | 프로젝트 전체 구조를 자동으로 파악 |
| 멀티 파일 편집 | 여러 파일을 한 번에 수정 |
| 내장 에이전트 | Build, Coder, Debug 등 목적별 에이전트 |
| TUI + 데스크톱 | 터미널 UI와 데스크톱 앱 모두 지원 |
| Git 통합 | 변경사항 자동 커밋, 브랜치 관리 |

## 모델 설정

```bash
# OpenAI 모델 사용
export OPENAI_API_KEY="sk-..."
opencode --model gpt-4o

# Anthropic 모델 사용
export ANTHROPIC_API_KEY="sk-ant-..."
opencode --model claude-sonnet-4

# 로컬 모델 (Ollama)
ollama serve  # 별도 터미널
opencode --model ollama/deepseek-coder-v2
```

### 설정 파일 (`~/.opencode/config.yaml`)

```yaml
model: claude-sonnet-4
provider: anthropic
agents:
  coder:
    model: claude-sonnet-4
  build:
    model: gpt-4o-mini   # 가벼운 작업은 저렴한 모델
temperature: 0.1
```

## 자주 쓰는 명령어

| 명령어 | 용도 |
|--------|------|
| `opencode` | 대화형 세션 시작 |
| `opencode "설명"` | 원샷 실행 (비대화형) |
| `opencode --model <name>` | 모델 지정 |
| `opencode --agent build` | Build 에이전트로 실행 |
| `opencode --agent coder` | Coder 에이전트로 실행 |
| `/help` | 세션 내 도움말 |
| `/clear` | 컨텍스트 초기화 |
| `/diff` | 현재 변경사항 확인 |
| `/undo` | 마지막 변경 되돌리기 |
| `/commit` | 변경사항 커밋 |

## 내장 에이전트 비교

| 에이전트 | 역할 | 적합한 작업 |
|----------|------|-------------|
| **Coder** | 범용 코딩 | 기능 구현, 리팩토링, 버그 수정 |
| **Build** | 프로젝트 생성 | 스캐폴딩, 초기 설정, 보일러플레이트 |
| **Debug** | 디버깅 | 에러 추적, 로그 분석, 재현 |
| **Review** | 코드 리뷰 | PR 분석, 개선 제안, 보안 체크 |

```bash
# Build 에이전트로 새 프로젝트 생성
opencode --agent build "Next.js + Tailwind 프로젝트 만들어줘"

# Debug 에이전트로 에러 분석
opencode --agent debug "TypeError: Cannot read property 에러 해결"
```

## Claude Code와의 주요 차이점

| 항목 | OpenCode | Claude Code |
|------|----------|-------------|
| 라이선스 | MIT (오픈소스) | 상용 (Anthropic) |
| 모델 | 75+ 프로바이더 | Claude 전용 |
| 로컬 모델 | Ollama/LM Studio 기본 지원 | 미지원 |
| 가격 | 무료 (API 비용만) | Max $100~200/월 또는 API |
| 에이전트 시스템 | 내장 4종 | 단일 에이전트 |
| 기업 지원 | Enterprise 옵션 | Teams/Enterprise |
| MCP | 지원 | 기본 지원 |
| 컨텍스트 관리 | LSP + 코드맵 | CLAUDE.md 기반 |

## 유용한 패턴

### 프라이빗 코드에 로컬 모델 사용

```bash
# 민감한 코드는 로컬 모델로 처리 (데이터 외부 전송 없음)
opencode --model ollama/codellama:34b "이 함수의 보안 취약점 점검해줘"
```

### 모델 라우팅 — 작업별 최적 모델 선택

```yaml
# config.yaml 에서 에이전트별 모델 분리
agents:
  coder:
    model: claude-sonnet-4     # 복잡한 코딩
  build:
    model: gpt-4o-mini         # 스캐폴딩 (비용 절감)
  review:
    model: claude-opus-4       # 정밀 리뷰
```

### Git 워크플로우 자동화

```bash
# 변경 → 리뷰 → 커밋 한 번에
opencode "이 PR의 변경사항 리뷰하고 커밋 메시지까지 작성해줘"
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 로컬 모델 연결 안 됨 | `ollama serve` 먼저 실행, 포트(11434) 확인 |
| API 키 인식 안 됨 | `~/.opencode/config.yaml`에 직접 설정 |
| 컨텍스트 부족 | `/add` 명령으로 관련 파일 수동 추가 |
| 모델 응답 느림 | 로컬 모델은 GPU 메모리에 따라 성능 차이 큼 |
| 멀티 파일 편집 충돌 | `/undo`로 롤백 후 파일 단위로 재시도 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
