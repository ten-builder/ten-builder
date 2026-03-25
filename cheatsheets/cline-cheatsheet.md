# Cline AI 코딩 에이전트 치트시트

> 오픈소스 VS Code AI 코딩 에이전트 — BYOM(Bring Your Own Model), 명시적 승인 기반 자율 코딩

## 한눈에 보기

| 항목 | 내용 |
|------|------|
| 유형 | VS Code 확장 (오픈소스, Apache 2.0) |
| 모델 | BYOM — Anthropic, OpenAI, Google, Ollama 등 자유 선택 |
| 가격 | 무료 (API 비용만 본인 부담) |
| 핵심 철학 | "Approve Everything" — 모든 변경에 명시적 승인 |
| 설치 | VS Code Marketplace에서 `Cline` 검색 |

## 설치 & 초기 설정

```bash
# VS Code에서 설치
code --install-extension saoudrizwan.claude-dev

# 또는 Marketplace에서 "Cline" 검색 후 설치
```

### 모델 설정

| 제공자 | 설정 방법 | 추천 모델 |
|--------|----------|-----------|
| Anthropic | API Key 입력 | Claude Sonnet 4 |
| OpenAI | API Key 입력 | GPT-4.1 |
| Google | API Key 입력 | Gemini 2.5 Pro |
| Ollama | 로컬 URL 지정 | Llama 4, Qwen 3 |
| OpenRouter | API Key 입력 | 원하는 모델 라우팅 |

**설정 위치:** Cline 사이드바 → 설정 아이콘 → API Provider 선택

## 핵심 기능

### 1. 파일 편집 & 생성

Cline은 프로젝트 파일을 직접 읽고 수정해요. 모든 변경 전에 diff를 보여주고 승인을 요청합니다.

```
사용자: "auth 미들웨어를 Express에 추가해줘"
→ Cline이 파일 분석 → 변경 diff 표시 → 승인 클릭 → 적용
```

### 2. 터미널 명령어 실행

```
사용자: "테스트 실행하고 실패하는 거 고쳐줘"
→ Cline이 `npm test` 실행 요청 → 승인 → 결과 분석 → 수정 제안
```

### 3. 브라우저 자동화

Cline은 브라우저를 실행하고 스크린샷을 캡처해서 UI 테스트를 할 수 있어요.

```
사용자: "localhost:3000 열고 로그인 폼이 제대로 나오는지 확인해"
→ 브라우저 실행 → 스크린샷 캡처 → 결과 분석
```

### 4. MCP 도구 통합

```json
// .vscode/mcp.json 또는 Cline MCP 설정
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/project"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_TOKEN": "ghp_xxx" }
    }
  }
}
```

## 주요 단축키

| 단축키 | 기능 |
|--------|------|
| `Cmd+Shift+P` → "Cline" | 커맨드 팔레트에서 Cline 명령 |
| `Cmd+Alt+A` / `Ctrl+Alt+A` | Auto-approve 토글 |
| 사이드바 채팅창 | 자연어로 작업 지시 |

## 승인 시스템 — Cline의 핵심

Cline은 **기본적으로 모든 액션에 승인을 요구**해요. 이것이 다른 AI 코딩 도구와 가장 큰 차이점입니다.

| 승인 유형 | 설명 |
|-----------|------|
| 파일 읽기 | 프로젝트 파일 접근 시 승인 |
| 파일 쓰기 | 변경 diff + 승인 필요 |
| 터미널 실행 | 명령어 확인 후 승인 |
| 브라우저 접근 | URL 접근 승인 |

### Auto-approve 설정 (주의해서 사용)

```
Cline 설정 → Auto-approve 섹션:
- Read files: ✅ (비교적 안전)
- Write files: ⚠️ (신중하게)
- Terminal commands: ⚠️ (위험할 수 있음)
- Browser actions: ⚠️ (필요할 때만)
```

> **팁:** 익숙한 프로젝트에서 반복 작업 할 때만 auto-approve를 켜세요. 새 프로젝트나 중요한 코드에서는 기본 승인 모드를 유지하는 게 안전합니다.

## Cline vs 다른 AI 코딩 도구

| 기준 | Cline | Cursor | Claude Code |
|------|-------|--------|-------------|
| 유형 | VS Code 확장 | 독립 IDE | CLI |
| 가격 | 무료 (API 비용) | $20/월~ | $20/월~ |
| 모델 선택 | 완전 자유 | 제한적 | Claude만 |
| 승인 방식 | 액션별 명시적 승인 | 자동/수동 혼합 | yolo/승인 혼합 |
| 오픈소스 | Apache 2.0 | 비공개 | 비공개 |
| MCP 지원 | 네이티브 | 네이티브 | 네이티브 |
| 브라우저 자동화 | 내장 | 없음 | 외부 MCP |
| 강점 | 통제력 + 모델 자유 | 편의성 + 속도 | 터미널 파워 |

## 효과적인 사용 패턴

### 패턴 1: 점진적 신뢰 구축

```
1단계: 모든 승인 수동 (새 프로젝트)
2단계: Read auto-approve 켜기 (파악 완료 후)
3단계: 간단한 Write auto-approve (반복 작업 시)
```

### 패턴 2: MCP로 확장

```
기본: 파일 + 터미널
확장 1: GitHub MCP → PR/Issue 관리
확장 2: DB MCP → 스키마 조회/마이그레이션
확장 3: 커스텀 MCP → 프로젝트 특화 도구
```

### 패턴 3: 로컬 모델 조합

```
빠른 작업: Ollama + Llama 4 Scout (무료, 로컬)
복잡한 작업: Claude Sonnet 4 API
코드 리뷰: GPT-4.1 API
→ 작업별로 모델을 바꿔서 비용 최적화
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| Auto-approve 전체 켜놓고 실수 | 중요 프로젝트에선 기본 승인 모드 유지 |
| 비싼 모델만 계속 사용 | 간단한 작업엔 로컬 모델 활용 |
| MCP 서버 과다 등록 | 프로젝트에 필요한 것만 3~5개 이내 |
| 컨텍스트 윈도우 초과 | `.clineignore`로 불필요한 파일 제외 |
| 터미널 명령 무분별 승인 | 명령어 확인 습관 — 특히 `rm`, `git push` 주의 |

## .clineignore 설정

프로젝트 루트에 `.clineignore` 파일을 만들어 불필요한 파일을 컨텍스트에서 제외하세요:

```
# .clineignore
node_modules/
dist/
build/
.env
*.lock
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
