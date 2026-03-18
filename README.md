# 텐빌더

> AI로 10배 빠르게 빌드하는 방법을 알려드려요

[![Newsletter](https://img.shields.io/badge/뉴스레터-구독-blue)](https://maily.so/tenbuilder)
[![YouTube](https://img.shields.io/badge/YouTube-텐빌더-red)](https://youtube.com/@ten-builder)

---

실무에서 바로 쓸 수 있는 AI 활용법을 다루고 있어요.

글로벌 IT 회사에서 6년간 2억+ 유저 서비스를 담당했던 엔지니어가,
Claude Code, Gemini 등 AI를 실무에서 직접 써보고 검증한 내용을 공유합니다.

- **직접 써보고 검증한 AI 리뷰**
- **AI를 10배 더 활용할 수 있는 실전 노하우**
- **2억명+ 서비스를 다뤄본 경험의 실전 노하우**

---

## 목차

- [무엇이 있나요?](#무엇이-있나요)
- [Quick Start](#quick-start)
- [에이전트 팀](#에이전트-팀)
- [가이드 목차](#가이드-목차)
- [에피소드별 코드](#에피소드별-코드)
- [치트시트](#치트시트)
- [실전 예제](#실전-예제)
- [워크플로](#워크플로)
- [플레이북](#플레이북)
- [템플릿](#템플릿)
- [스킬](#스킬)

---

## 무엇이 있나요?

| 폴더 | 내용 | 난이도 |
|------|------|--------|
| [`/guides`](./guides) | 1~22 단계별 실전 가이드 | ⭐⭐⭐ |
| [`/episodes`](./episodes) | 영상별 코드 & 스크립트 | ⭐⭐ |
| [`/cheatsheets`](./cheatsheets) | 원페이저 치트시트 | ⭐ |
| [`/examples`](./examples) | 프로젝트별 실전 예제 | ⭐⭐ |
| [`/workflows`](./workflows) | CI/CD, Docker, MCP 워크플로 | ⭐⭐⭐ |
| [`/claude-code`](./claude-code) | 플레이북 & 심화 패턴 | ⭐⭐⭐ |
| [`/templates`](./templates) | 복사해서 바로 쓰는 설정 파일 | ⭐ |
| [`/skills`](./skills) | Claude Code 학습 스킬 (퀴즈 + 노트) | ⭐⭐ |

## Quick Start

**1분 안에 Claude Code 프로젝트 설정:**

```bash
# CLAUDE.md 템플릿 복사
curl -O https://raw.githubusercontent.com/ten-builder/ten-builder/main/templates/CLAUDE.md.template

# 프로젝트 루트에 배치
mv CLAUDE.md.template CLAUDE.md

# 프로젝트에 맞게 수정 후 사용
```

**AI 코딩 환경 한 번에 세팅:**

```bash
# macOS 원클릭 설정
curl -sSL https://raw.githubusercontent.com/ten-builder/ten-builder/main/templates/macos-setup.sh | bash
```

## 에이전트 팀

> AI 에이전트 5명이 동시에 코딩합니다. tmux로 병렬 실행.

```bash
# 1. 레포 클론
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/episodes/ep5-agent-teams-with-tmux

# 2. 미리보기
./run-agent-team.sh prompts --dry

# 3. 실행 (tmux + Claude Code 필요)
./run-agent-team.sh prompts
```

**자세한 가이드:** [에이전트 팀 가이드](./guides/11-agent-teams.md)

📮 **영상에서 사용한 실제 프롬프트 5개는 뉴스레터에서:** [maily.so/tenbuilder](https://maily.so/tenbuilder)

## 가이드 목차

| # | 가이드 | 설명 |
|---|--------|------|
| 1 | [환경 세팅](./guides/1-environment-setup.md) | AI 코딩 도구 설치 & 설정 |
| 2 | [프로젝트 초기 설정](./guides/2-project-setup.md) | CLAUDE.md부터 첫 커밋까지 |
| 3 | [일일 코딩 루틴](./guides/3-daily-workflow.md) | 매일 AI와 코딩하는 워크플로 |
| 4 | [코드 리뷰](./guides/4-code-review.md) | AI 코드 리뷰 & PR 워크플로 |
| 5 | [디버깅](./guides/5-debugging.md) | AI와 체계적으로 버그 잡기 |
| 6 | [리팩토링](./guides/6-refactoring.md) | AI와 안전하게 코드 개선 |
| 7 | [TDD](./guides/7-tdd.md) | AI와 테스트 주도 개발 |
| 8 | [MCP 도구](./guides/8-mcp-tools.md) | 외부 도구 연결 (DB, GitHub 등) |
| 9 | [보안](./guides/9-security.md) | AI 코딩 도구 보안 설정 |
| 10 | [Hooks](./guides/10-hooks.md) | 자동 검사/포맷/알림 설정 |
| 11 | [에이전트 팀](./guides/11-agent-teams.md) | AI 에이전트 5명으로 동시 빌딩 |
| 12 | [배포](./guides/12-deployment.md) | AI와 배포 파이프라인 구축 |
| 13 | [하네스 엔지니어링](./guides/13-harness-engineering.md) | AI 에이전트 실행 환경 설계 |
| 14 | [비용 최적화](./guides/14-cost-optimization.md) | AI 코딩 도구 비용 관리 전략 |
| 15 | [서브에이전트 오케스트레이션](./guides/15-subagent-orchestration.md) | 서브에이전트 분할 & 병렬 실행 전략 |
| 16 | [AI 코딩 보안](./guides/16-ai-coding-security.md) | AI 코딩 보안 위험 & 방어 전략 |
| 19 | [태스크 분해](./guides/19-task-decomposition.md) | AI 에이전트 태스크 분해 기법 |
| 21 | [팀 AI 도입](./guides/21-team-ai-adoption.md) | 팀 단위 AI 도구 도입 전략 |
| 22 | [스펙 기반 AI 개발](./guides/22-spec-driven-ai-development.md) | 스펙 먼저 정의하고 AI에게 맡기기 |

## 에피소드별 코드

| EP | 제목 | 코드 |
|----|------|------|
| EP01 | 바이브 코딩의 함정 | [`/episodes/EP01-vibe-coding`](./episodes/EP01-vibe-coding) |
| EP02 | 에이전트 팀 | [`/episodes/EP02-agent-teams`](./episodes/EP02-agent-teams) |
| EP03 | AI 에이전트 A to Z | [`/episodes/EP03-ai-agent-az`](./episodes/EP03-ai-agent-az) |
| EP04 | Claude Desktop MCP | [`/episodes/EP04-claude-desktop-mcp`](./episodes/EP04-claude-desktop-mcp) |
| EP05 | 에이전트 팀즈 with tmux | [`/episodes/EP05-agent-teams-tmux`](./episodes/EP05-agent-teams-tmux) |
| EP06 | Claude Code Hooks | [`/episodes/EP06-claude-code-hooks`](./episodes/EP06-claude-code-hooks) |
| EP07 | AI 자동화 봇 | [`/episodes/EP07-ai-automation-bot`](./episodes/EP07-ai-automation-bot) |

## 치트시트

| 치트시트 | 설명 |
|----------|------|
| [AI 코딩 기본](./cheatsheets/ai-coding-cheatsheet.md) | AI 코딩 핵심 명령어 모음 |
| [에이전틱 코딩](./cheatsheets/agentic-coding-cheatsheet.md) | 에이전트 기반 코딩 패턴 |
| [프롬프트 엔지니어링](./cheatsheets/prompt-engineering-cheatsheet.md) | 효과적인 프롬프트 작성법 |
| [Claude Code Hooks](./cheatsheets/claude-code-hooks-cheatsheet.md) | Hooks 설정 & 패턴 |
| [MCP 레퍼런스](./cheatsheets/mcp-quick-reference.md) | MCP 서버 빠른 참조 |
| [토큰 최적화](./cheatsheets/token-optimization-cheatsheet.md) | 토큰 사용량 절약 팁 |
| [Windsurf](./cheatsheets/windsurf-cheatsheet.md) | Windsurf AI IDE 가이드 |
| [하네스 엔지니어링](./cheatsheets/harness-engineering-cheatsheet.md) | Model/Harness/Surfaces 구조 요약 |
| [AI CLI 도구 비교](./cheatsheets/ai-cli-tools-comparison.md) | Claude Code vs Codex CLI vs Gemini CLI |
| [서브에이전트 오케스트레이션](./cheatsheets/subagent-orchestration-cheatsheet.md) | 서브에이전트 분할 & 위임 패턴 |
| [Git + AI 워크플로우](./cheatsheets/git-ai-workflow-cheatsheet.md) | Git + AI 브랜치/커밋 패턴 |
| [에이전트 모드 비교](./cheatsheets/agent-mode-comparison-cheatsheet.md) | AI 에이전트 모드 기능 비교 |
| [Claude Code 커맨드](./cheatsheets/claude-code-commands-cheatsheet.md) | 커스텀 슬래시 커맨드 가이드 |
| [에이전틱 IDE 비교](./cheatsheets/agentic-ide-comparison-cheatsheet.md) | Kiro vs Cursor vs Claude Code 비교 |

## 실전 예제

| 예제 | 설명 |
|------|------|
| [Next.js + Claude Code](./examples/nextjs-claude-code) | Next.js 프로젝트 AI 세팅 |
| [Supabase + Next.js AI](./examples/supabase-nextjs-ai) | 풀스택 AI 개발 환경 |
| [FastAPI + AI 테스팅](./examples/fastapi-ai-testing) | FastAPI 프로젝트 AI 테스트 |
| [Python CLI + AI](./examples/python-cli-ai) | CLI 도구 AI 개발 |
| [Chrome Extension + AI](./examples/chrome-extension-ai) | 크롬 확장 AI 개발 |
| [Express.js + AI API](./examples/express-api-ai) | Express.js REST API AI 개발 |
| [Django API](./examples/django-api.md) | Django REST API 예제 |
| [Go Microservice](./examples/go-microservice.md) | Go 마이크로서비스 예제 |
| [Rust API](./examples/rust-api.md) | Rust API 예제 |
| [Next.js SaaS](./examples/nextjs-saas.md) | SaaS 보일러플레이트 |
| [Terraform + AI IaC](./examples/terraform-ai-iac) | Terraform AI 인프라 자동화 |
| [Go Microservice + AI](./examples/go-microservice-ai) | Go 마이크로서비스 AI 개발 |
| [GraphQL + AI API](./examples/graphql-ai-api) | GraphQL API AI 개발 |
| [CLAUDE.md 작성법](./examples/user-claudemd.md) | 사용자 CLAUDE.md 가이드 |

## 워크플로

| 워크플로 | 설명 |
|----------|------|
| [Docker AI 개발환경](./workflows/docker-ai-dev-environment.md) | Docker 기반 AI 개발 환경 구축 |
| [커스텀 MCP 서버](./workflows/custom-mcp-server.md) | MCP 서버 직접 만들기 |
| [Pre-commit AI 훅](./workflows/pre-commit-ai-hooks.md) | 커밋 전 AI 자동 검사 |
| [GitHub Actions AI 리뷰](./workflows/github-actions-ai-review.md) | PR 자동 리뷰 워크플로 |
| [모노레포 AI 워크플로](./workflows/monorepo-ai-workflow.md) | 모노레포 AI 개발 패턴 |
| [AI 에이전트 감독](./workflows/ai-agent-supervision.md) | AI 에이전트 태스크 위임 & 검수 |
| [AI 테스트 강화](./workflows/ai-test-augmentation.md) | AI로 테스트 스위트 강화 & CI 통합 |
| [AI 세션 메모리 관리](./workflows/ai-session-memory-management.md) | AI 세션 간 컨텍스트 & 지식 관리 |
| [AI 에이전트 파이프라인](./workflows/ai-agent-pipeline.md) | 멀티 에이전트 코드→테스트→배포 파이프라인 |

## 플레이북

> 심화 주제별 단계 가이드 — [`/claude-code/playbooks`](./claude-code/playbooks)

| 플레이북 | 설명 |
|----------|------|
| [성능 최적화](./claude-code/playbooks/07-performance.md) | AI로 성능 병목 찾기 & 최적화 |
| [배포 자동화](./claude-code/playbooks/08-deployment.md) | AI와 배포 파이프라인 구축 |
| [문서화](./claude-code/playbooks/09-documentation.md) | AI로 문서 자동 생성 & 관리 |
| [코드 리뷰 심화](./claude-code/playbooks/10-code-review.md) | AI 코드 리뷰 고급 패턴 |
| [보안 감사](./claude-code/playbooks/11-security-audit.md) | AI로 보안 취약점 점검 |
| [컨텍스트 관리](./claude-code/playbooks/12-context-management.md) | AI 컨텍스트 윈도우 최적화 |
| [CLAUDE.md 최적화](./claude-code/playbooks/13-claudemd-optimization.md) | CLAUDE.md 프로젝트 설정 최적화 |
| [API 설계](./claude-code/playbooks/14-api-design.md) | AI와 REST API 설계 & 구현 |
| [코드베이스 온보딩](./claude-code/playbooks/15-codebase-onboarding.md) | AI와 레포 구조 파악 & 온보딩 |
| [대규모 리팩토링](./claude-code/playbooks/16-large-scale-refactoring.md) | AI로 대규모 리팩토링 안전하게 수행 |
| [프로토타이핑](./claude-code/playbooks/17-rapid-prototyping.md) | AI로 아이디어를 빠르게 프로토타입으로 |

## 템플릿

> 복사해서 바로 쓰는 설정 파일 — [`/templates`](./templates)

| 템플릿 | 설명 |
|--------|------|
| [CLAUDE.md](./templates/CLAUDE.md.template) | 프로젝트 기본 설정 템플릿 |
| [AGENTS.md](./templates/agents.md.template) | 에이전트 역할 정의 템플릿 |
| [.cursorrules](./templates/cursorrules.template) | Cursor AI IDE 설정 |
| [.zshrc.ai](./templates/.zshrc.ai) | AI 코딩 쉘 설정 |
| [macOS 셋업](./templates/macos-setup.sh) | AI 코딩 환경 원클릭 설치 |
| [에이전트 팀 실행](./templates/run-agent-team.sh) | tmux 에이전트 팀 실행 스크립트 |
| [에이전트 팀 프롬프트](./templates/agent-team-example) | 5인 에이전트 팀 프롬프트 예시 |

## 스킬

> Claude Code에서 슬래시 명령으로 바로 사용 — 자세한 설치법은 [`/skills/README.md`](./skills/README.md)

| 스킬 | 명령어 | 설명 |
|------|--------|------|
| **study-vault** | `/study-vault` | PDF/문서를 Obsidian 학습 노트로 변환 |
| **study-quiz** | `/study-quiz` | 대화형 퀴즈로 숙달도 추적 |
| **session-pack** | `/pack` | 세션 종료 시 Memory/Handoff 자동 정리 |

```bash
# 자동 설치 (추천)
curl -sSL https://raw.githubusercontent.com/ten-builder/ten-builder/main/skills/setup.sh | bash
```

---

## 이 레포는 어떻게 업데이트 되나요?

- **상시** — 새로운 가이드와 치트시트, 패턴 등 추가
- **Release** — ⭐ Star 누르면 새 콘텐츠 추가 시 알림

## 더 알아보기

이 레포가 도움이 됐다면, 매주 보내는 AI 코딩 인사이트도 좋아할 거예요:

- 에이전트 팀 실전 프롬프트 + 촬영 팁
- 직접 써보고 검증한 AI 도구 리뷰
- 실패 사례와 트레이드오프

**뉴스레터 구독:** [maily.so/tenbuilder](https://maily.so/tenbuilder)

## License

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

이 레포의 콘텐츠는 [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) 라이선스로 제공됩니다.

- **학습/참고 목적 사용** — 자유롭게 가능
- **수정/재배포** — 출처 표기 + 동일 라이선스 적용 시 가능
- **상업적 사용** — 불가
