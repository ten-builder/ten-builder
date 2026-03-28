# CLI 기반 AI 코딩 에이전트 비교 치트시트

> 터미널에서 코드를 짜는 시대 — 주요 CLI 코딩 에이전트 15종의 핵심 차이를 한 페이지로 정리

## 핵심 비교 테이블

| 도구 | 개발사 | 모델 | 오픈소스 | 가격 | 핵심 특징 |
|------|--------|------|---------|------|-----------|
| **Claude Code** | Anthropic | Claude 4 계열 | ❌ | Max $200/월 | 에이전틱 코딩, 서브에이전트, Background Agent |
| **Gemini CLI** | Google | Gemini 2.5 Pro | ✅ | 무료 (1M 토큰/일) | 넉넉한 무료 티어, 1M 컨텍스트 |
| **Codex CLI** | OpenAI | o4-mini, o3 | ✅ | API 종량제 | 샌드박스 격리 실행, multipass 검증 |
| **Aider** | Paul Gauthier | 다중 모델 | ✅ | 무료 (API 키 필요) | Git 네이티브, diff 기반 편집 |
| **OpenCode** | 커뮤니티 | 다중 모델 | ✅ | 무료 (API 키 필요) | TUI 인터페이스, LSP 연동 |
| **Goose** | Block | 다중 모델 | ✅ | 무료 (API 키 필요) | 확장형 도구 시스템, 자율 워크플로우 |
| **Amp** | Sourcegraph | Claude, GPT 등 | ❌ | Pro $29/월 | 에이전트 스레드, 코드 검색 통합 |
| **Cline** | 커뮤니티 | 다중 모델 | ✅ | 무료 (API 키 필요) | VS Code 확장, MCP 도구 지원 |
| **Continue** | Continue.dev | 다중 모델 | ✅ | 무료 (API 키 필요) | VS Code/JetBrains, 자동 완성 |
| **Pear (PearAI)** | PearAI | 다중 모델 | ✅ | 무료/Pro $15/월 | VS Code 포크, 통합 AI 환경 |
| **Void** | Void | 다중 모델 | ✅ | 무료 | 프라이버시 중심, 로컬 LLM 지원 |
| **Mentat** | AbanteAI | 다중 모델 | ✅ | 무료 (API 키 필요) | 컨텍스트 자동 수집, diff 적용 |
| **GPT Engineer** | Lovable | GPT-4 계열 | ✅ | 무료 (API 키 필요) | 프로젝트 생성 특화 |
| **Sweep** | Sweep AI | GPT-4 계열 | ✅ | 무료/Pro | GitHub 이슈 → PR 자동 생성 |
| **Amazon Q CLI** | AWS | 자체 모델 | ❌ | 무료/Pro $19/월 | AWS 서비스 통합, 쉘 자동완성 |

## 카테고리별 비교

### 에이전틱 자율 코딩 (가장 높은 자율성)

| 기능 | Claude Code | Codex CLI | Amp | Goose |
|------|------------|-----------|-----|-------|
| 파일 읽기/쓰기 | ✅ | ✅ (샌드박스) | ✅ | ✅ |
| 셸 명령 실행 | ✅ | ✅ (네트워크 차단) | ✅ | ✅ |
| 테스트 실행 후 자동 수정 | ✅ | ✅ | ✅ | ✅ |
| 멀티파일 동시 편집 | ✅ | ✅ | ✅ | ✅ |
| 서브에이전트 병렬 | ✅ | ❌ | ✅ | ❌ |
| 백그라운드 실행 | ✅ | ❌ | ❌ | ❌ |
| Git 자동 커밋 | ✅ | ✅ | ✅ | ❌ |

### Git 통합 수준

| 도구 | 자동 커밋 | 브랜치 관리 | PR 생성 | diff 미리보기 |
|------|----------|------------|---------|-------------|
| Aider | ✅ (기본) | ❌ | ❌ | ✅ (unified diff) |
| Claude Code | ✅ (수동) | ✅ | ✅ | ✅ |
| Codex CLI | ✅ (자동) | ❌ | ❌ | ✅ (패치 형태) |
| Sweep | ✅ | ✅ | ✅ (핵심 기능) | ✅ |

## 설치 한눈에 보기

```bash
# Claude Code
npm install -g @anthropic-ai/claude-code

# Gemini CLI
npm install -g @anthropic-ai/gemini-cli  # 아님
npm install -g @google/gemini-cli

# Codex CLI
npm install -g @openai/codex

# Aider
pip install aider-chat

# OpenCode
go install github.com/opencode-ai/opencode@latest

# Goose
brew install block/goose/goose

# Amp
npm install -g @anthropic-ai/amp  # 아님
# Sourcegraph에서 직접 다운로드
brew install sourcegraph/amp/amp

# Cline
# VS Code 마켓플레이스에서 설치

# Amazon Q CLI
brew install amazon-q
```

## 사용 시나리오별 추천

### "무료로 시작하고 싶다"

```
1순위: Gemini CLI (일 1M 토큰 무료)
2순위: Aider + 로컬 LLM (Ollama)
3순위: OpenCode + 로컬 LLM
```

### "복잡한 리팩토링을 맡기고 싶다"

```
1순위: Claude Code (서브에이전트 병렬 처리)
2순위: Amp (에이전트 스레드 + 코드 검색)
3순위: Codex CLI (샌드박스 안전 실행)
```

### "기존 Git 워크플로우에 자연스럽게 끼워넣고 싶다"

```
1순위: Aider (Git 네이티브 — 변경마다 자동 커밋)
2순위: Claude Code (git 명령 직접 실행 가능)
3순위: Sweep (이슈 → PR 자동)
```

### "프라이빗 코드, 외부 전송 불가"

```
1순위: Void (로컬 LLM 전용 설계)
2순위: OpenCode + Ollama (로컬 모델)
3순위: Aider + Ollama (오프라인 모드)
```

### "AWS 환경이 주력이다"

```
Amazon Q CLI → AWS 서비스 자동완성, IAM 정책 생성, CloudWatch 연동
```

## 주요 명령어 비교

### 작업 시작

```bash
# Claude Code — 프로젝트 폴더에서 실행
cd my-project && claude

# Gemini CLI — 바로 질문
cd my-project && gemini

# Codex CLI — 태스크 지정
codex "이 프로젝트에 로깅 미들웨어 추가해줘"

# Aider — 대상 파일 지정
aider src/app.py src/utils.py

# OpenCode — TUI 모드
opencode
```

### 파일 편집 방식 차이

| 도구 | 편집 방식 | 장점 |
|------|----------|------|
| Claude Code | 전체 파일 또는 diff | 큰 변경에 유리 |
| Codex CLI | 패치(diff) 적용 | 토큰 절약 |
| Aider | unified diff + 전체 | Git과 자연스러운 통합 |
| Gemini CLI | 전체 파일 | 큰 컨텍스트로 정확도 높음 |

## 모델 유연성

| 도구 | 기본 모델 | 모델 교체 | 로컬 LLM |
|------|----------|----------|---------|
| Claude Code | Claude 4 Sonnet | Claude 계열만 | ❌ |
| Gemini CLI | Gemini 2.5 Pro | Gemini 계열만 | ❌ |
| Codex CLI | o4-mini | OpenAI 계열만 | ❌ |
| Aider | 다중 지원 | ✅ (50+ 모델) | ✅ (Ollama) |
| OpenCode | 다중 지원 | ✅ | ✅ (Ollama) |
| Goose | 다중 지원 | ✅ | ✅ |
| Cline | 다중 지원 | ✅ | ✅ |

## 비용 비교 (2026년 기준)

| 도구 | 무료 티어 | 유료 | 예상 월 비용 (일 2시간 사용) |
|------|----------|------|---------------------------|
| Claude Code | ❌ | Max $200/월 | $100~200 |
| Gemini CLI | ✅ (1M 토큰/일) | API 초과 시 종량제 | $0~30 |
| Codex CLI | ❌ | API 종량제 | $20~80 |
| Aider | ✅ (도구 무료) | API 비용만 | $10~50 |
| OpenCode | ✅ | API 비용만 | $10~50 |
| Amp | ❌ | Pro $29/월 | $29 |
| Amazon Q | ✅ (기본) | Pro $19/월 | $0~19 |

## 선택 플로차트

```
터미널 AI 코딩 도구가 필요하다
│
├─ 예산이 없다
│  ├─ 큰 컨텍스트 필요 → Gemini CLI
│  ├─ Git 중심 워크플로우 → Aider + 무료 API
│  └─ TUI가 좋다 → OpenCode
│
├─ 생산성이 최우선이다
│  ├─ 복잡한 멀티파일 → Claude Code
│  ├─ 안전한 실행 필요 → Codex CLI
│  └─ 코드 검색 통합 → Amp
│
├─ 보안/프라이버시 필수
│  ├─ 완전 오프라인 → Void + Ollama
│  └─ 부분 오프라인 → Aider + 로컬 모델
│
└─ AWS 중심 → Amazon Q CLI
```

## 자주 하는 질문

| 질문 | 답변 |
|------|------|
| 가장 코드 품질이 높은 건? | Claude Code (Claude 4 Opus 사용 시) |
| 가장 빠른 건? | Gemini CLI (2.5 Flash 모드) |
| 가장 안전한 건? | Codex CLI (네트워크 차단 샌드박스) |
| 가장 유연한 건? | Aider (50+ 모델 지원) |
| 가장 가성비 좋은 건? | Gemini CLI (무료) 또는 Aider + DeepSeek |
| 여러 개 조합할 수 있나? | 가능 — 큰 작업은 Claude Code, 빠른 수정은 Gemini CLI 패턴 추천 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
