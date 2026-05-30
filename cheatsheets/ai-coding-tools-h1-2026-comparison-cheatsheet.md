# AI 코딩 도구 2026 상반기 총정리

> 2026년 상반기 기준 — Claude Code, Cursor, Gemini CLI, Codex CLI, GitHub Copilot, Cline 6개 도구 한 페이지 비교

## 도구별 한 줄 포지션

| 도구 | 타입 | 핵심 강점 |
|------|------|-----------|
| **Claude Code** | 터미널 에이전트 | 대형 코드베이스 자율 리팩토링 |
| **Cursor** | AI 네이티브 IDE | 인라인 편집 경험 |
| **GitHub Copilot** | IDE 확장 | 기업 도입, 멀티 IDE |
| **Gemini CLI** | 터미널 에이전트 | 멀티모달, 1M 컨텍스트 무료 |
| **Codex CLI** | 터미널 에이전트 | GPT-5.5 연동, /goal 자율 루프 |
| **Cline** | VS Code 확장 | 오픈소스, BYOK 멀티 LLM |

---

## SWE-bench Verified 점수 비교

| 도구 | 점수 | 기준 모델 |
|------|------|-----------|
| Claude Code | **87.6%** | Opus 4.7 Adaptive |
| Cursor Pro | ~80% | Claude Sonnet 4 기반 |
| GitHub Copilot | **72.5%** | GPT-5.4 |
| Gemini CLI | ~71% | Gemini 3.1 Pro |
| Codex CLI | ~70% | GPT-5.5 |
| Cline | 모델 종속 | BYOK 선택 모델 |

> **참고:** 점수는 동일 모델이라도 도구 구현 방식에 따라 최대 17점 차이. 벤치마크 = 필요조건, 충분조건 아님.

---

## 가격 비교 (월간, 2026년 5월 기준)

| 도구 | 가격 | 플랜 구조 |
|------|------|-----------|
| **GitHub Copilot** | $10~$39 | Individual / Business / Enterprise |
| **Cursor** | $0~$40 | Free / Pro($20) / Business($40) |
| **Claude Code** | $20~$200 | Pro($20) / Max($100/$200) |
| **Gemini CLI** | **무료** | Gemini API free tier 포함 |
| **Codex CLI** | ChatGPT Plus 포함 | ChatGPT Plus $20 |
| **Cline** | **무료** | API 비용 별도 (BYOK) |

---

## 작업 유형별 추천 도구

| 상황 | 추천 | 이유 |
|------|------|------|
| 대규모 리팩토링 (50+ 파일) | Claude Code | 긴 컨텍스트 + 자율 실행 |
| 신규 기능 인라인 편집 | Cursor | Tab 자동완성 + Composer |
| 팀 기업 도입 | GitHub Copilot | SSO, 정책, 감사 로그 |
| 무료로 빠르게 시작 | Gemini CLI | 무료 + 1M 토큰 컨텍스트 |
| AWS/클라우드 인프라 | Amazon Q Developer | IaC 특화, AWS 네이티브 |
| 오픈소스 + BYOK | Cline | VS Code 확장, 모델 자유 선택 |
| 장시간 자율 태스크 | Codex CLI | /goal 루프, Budget Awareness |

---

## 주요 기능 지원 비교

| 기능 | Claude Code | Cursor | Copilot | Gemini CLI | Codex | Cline |
|------|:-----------:|:------:|:-------:|:----------:|:-----:|:-----:|
| 멀티파일 자율 수정 | ✅ | ✅ | 제한적 | ✅ | ✅ | ✅ |
| 터미널 실행 | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| 인라인 자동완성 | ❌ | ✅ | ✅ | 제한적 | ❌ | 제한적 |
| MCP 연동 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 멀티에이전트 | ✅ | 제한적 | ❌ | ❌ | ❌ | ❌ |
| 멀티모달(이미지) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| BYOK | ❌ | 제한적 | ❌ | ❌ | ❌ | ✅ |
| 오프라인 실행 | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (로컬 모델) |

---

## 2026 상반기 주요 업데이트 하이라이트

### Claude Code
- Opus 4.7 Adaptive 출시 → SWE-bench 87.6%
- Agent Teams GA (역할 기반 멀티에이전트)
- /powerup 대화형 온보딩 레슨
- 레이트 리밋 2배 확대
- Agent View + 백그라운드 세션
- /autofix-pr CI 자동 수정

### Cursor
- Background Agents (클라우드 에이전트)
- Notepads 팀 공유 컨텍스트
- BugBot (PR 자동 감지)

### GitHub Copilot
- Agent Mode 정식 출시 (멀티 파일 수정)
- Extensions 에코시스템 확장
- Copilot Workspace 일반 공개

### Gemini CLI
- Gemini 3.1 Pro 통합
- MCP 서버 alwaysLoad 지원
- 멀티모달 입력 강화

---

## 어떤 도구를 선택할까?

```
혼자 쓰는 개인 개발자?
├── 돈 아끼고 싶다 → Gemini CLI (무료)
├── 터미널 익숙 + 복잡한 작업 → Claude Code Pro
└── IDE에서 편하게 → Cursor Free → Pro 업그레이드

팀/기업?
├── 보안 정책 중요 → GitHub Copilot Business/Enterprise
├── AI 네이티브 팀 → Claude Code Max + Cursor
└── 오픈소스 유연성 → Cline (BYOK)

특수 목적?
├── AWS 인프라 → Amazon Q Developer CLI
├── 자율 장기 태스크 → Codex CLI /goal 모드
└── 보안 코딩 특화 → Checkmarx One Assist
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/) | [guides](../guides/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
