# Google Antigravity IDE 실전 가이드 2026

> Google이 만든 에이전트 퍼스트 IDE — Manager View로 여러 에이전트를 동시에 지휘하는 법

## 이 가이드에서 다루는 것

- Google Antigravity가 기존 AI 코딩 도구와 다른 점
- 설치 및 초기 설정
- Agent Manager(Manager View)와 Editor View 활용법
- 실전 멀티 에이전트 워크플로우 패턴
- Cursor, Claude Code와의 비교 및 조합 전략

---

## Antigravity란?

Google Antigravity는 VS Code 포크 기반의 에이전트 퍼스트 IDE입니다. 기존 도구가 에디터 사이드바에 AI를 붙인 방식이라면, Antigravity는 **에이전트가 독립적인 공간에서 작업하도록** 설계되었습니다.

Gemini 3 Pro를 기본 모델로 사용하고, SWE-bench Verified 76.2%, Terminal-Bench 2.0 54.2%를 기록하며 2026년 상반기 주목받는 도구입니다. 공개 프리뷰 기간에는 무료로 사용할 수 있습니다.

---

## 설치

### macOS

```bash
# Homebrew를 통한 설치
brew install --cask google-antigravity

# 또는 공식 사이트에서 .dmg 다운로드
# https://antigravity.google.dev
```

### Linux / Windows

```bash
# Linux (Debian/Ubuntu)
wget https://dl.antigravity.google.dev/latest/antigravity-linux-amd64.deb
sudo dpkg -i antigravity-linux-amd64.deb

# Windows (winget)
winget install Google.Antigravity
```

### 초기 설정

1. Gmail 계정으로 로그인 (공개 프리뷰 필수)
2. VS Code 또는 Cursor 설정 가져오기 선택
3. 기본 모델: Gemini 3 Pro 선택 (권장)
4. 브라우저 확장 프로그램 설치 → 에이전트 브라우저 테스트 활성화

---

## 두 가지 뷰: Manager View vs Editor View

### Manager View — 병렬 에이전트 지휘 센터

```
┌────────────────────────────────────────────┐
│ Manager View (Mission Control)              │
├──────────┬──────────────────────────────────┤
│ Inbox    │ 활성 태스크 목록                  │
│ Workspace│ 프로젝트 관리                    │
│ Playground│ 프롬프트 테스트                 │
│ Browser  │ 에이전트 자동화 테스트 뷰         │
└──────────┴──────────────────────────────────┘
```

여러 에이전트가 동시에 작업하는 상황을 한눈에 관리합니다. 한 에이전트가 백엔드 API를 리팩토링하는 동안 다른 에이전트가 React 컴포넌트를 분리하는 작업을 진행 상황과 함께 확인할 수 있습니다.

### Editor View — 일상적인 코딩 환경

VS Code와 동일한 인터페이스입니다.

| 구성 요소 | 역할 |
|-----------|------|
| 파일 탐색기 | 프로젝트 파일 관리 |
| 코드 에디터 | 직접 코드 편집 |
| Agent Panel | 맥락을 유지한 에이전트 대화 |
| 통합 터미널 | 명령어 실행 |

---

## 실전 워크플로우 패턴

### 패턴 1: 대규모 리팩토링 — Manager View 활용

새 기능 추가 없이 코드 구조를 개선할 때 에이전트 여러 개를 동시에 활용합니다.

```
Manager View → New Task 생성:

에이전트 A: "src/api/ 디렉토리의 에러 처리를 공통 미들웨어로 통합"
에이전트 B: "tests/ 의 중복 픽스처를 공유 factory로 리팩토링"
에이전트 C: "주석 없는 함수에 JSDoc 추가"
```

세 작업이 서로 영향을 주지 않으면 병렬 실행이 가능합니다.

### 패턴 2: 신규 기능 개발 — 역할 분리

```
Manager View → 태스크 분해:

1. 에이전트 A: "POST /api/comments 엔드포인트 구현 (Jest 테스트 포함)"
2. 에이전트 A 완료 후 → 에이전트 B: "CommentList 컴포넌트 구현 (API 스펙 참조)"
```

의존성이 있는 작업은 순서를 지정합니다. A 결과물을 B가 참조하도록 Inbox에서 연결할 수 있습니다.

### 패턴 3: 코드 감사 — 스페셜리스트 에이전트

```python
# Playground에서 역할 기반 프롬프트 테스트 후 Task로 전환

보안 감사 에이전트:
"이 코드베이스에서 SQL 인젝션, XSS, 인증 우회 패턴을 찾고
각 취약점에 대한 수정 코드를 제안하세요."

성능 에이전트:
"N+1 쿼리 패턴, 불필요한 re-render, 메모리 누수 가능성을
파일별로 정리하세요."
```

---

## Cursor, Claude Code와의 비교

| 기준 | Antigravity | Cursor | Claude Code |
|------|-------------|--------|-------------|
| 에이전트 모델 | Agent-First | IDE-First | Terminal-First |
| 멀티 에이전트 | Manager View (내장) | 제한적 | Git Worktree 수동 설정 |
| 비용 | 무료 (공개 프리뷰) | $16/월 | $17-200/월 |
| SWE-bench | 76.2% | - | 80.9% |
| MCP 지원 | 미지원 (2026-04 기준) | 지원 | 지원 |
| 이상적인 사용처 | 대규모 리팩토링, 병렬 구현 | 일상 코딩, 빠른 편집 | 복잡한 아키텍처, 터미널 자동화 |

### 추천 조합

```
신규 프로젝트 스캐폴딩     → Antigravity (Manager View로 병렬 구성)
일상 코드 편집              → Cursor (에디터 네이티브 경험)
복잡한 디버깅/아키텍처 리뷰 → Claude Code (터미널 자동화)
```

---

## 실전 팁

### Manager View 효율 높이기

```
1. Workspace를 프로젝트 단위로 분리 — 레포마다 별도 Workspace
2. Playground에서 프롬프트 검증 후 Task로 승격 — 실패 줄이기
3. 독립적인 작업만 병렬 실행 — 같은 파일 수정은 순차 처리
4. Browser View로 에이전트 자동화 테스트 결과 실시간 확인
```

### 에이전트 신뢰도 관리

```
에이전트 작업 완료 후 체크:
- diff 검토: 예상 범위 내 변경인지 확인
- 테스트 실행: 기존 테스트 통과 여부 확인
- 한 번에 한 에이전트 머지: 충돌 최소화
```

### MCP 미지원 대응

MCP를 활용해야 한다면 Claude Code나 Cursor와 병행 사용합니다.

```bash
# Claude Code로 MCP 도구 작업 처리
claude code --mcp-config ~/.config/mcp/servers.json

# 결과를 파일로 저장 후 Antigravity에서 후속 작업
```

---

## 체크리스트

- [ ] Gmail 계정으로 Antigravity 로그인 완료
- [ ] 브라우저 확장 프로그램 설치 완료
- [ ] 첫 Workspace 생성 및 프로젝트 연결
- [ ] Playground에서 프롬프트 테스트
- [ ] Manager View로 첫 병렬 태스크 실행
- [ ] 작업 완료 후 diff 검토 습관 정착

---

## 다음 단계

→ [멀티 에이전트 팀 구성 가이드](72-ai-coding-agent-team-composition-guide.md)  
→ [Cursor IDE 실전 가이드](73-cursor-ide-practical-guide-2026.md)  
→ [Zed IDE 실전 가이드](74-zed-ide-practical-guide-2026.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)  
**유튜브:** [@ten-builder](https://youtube.com/@ten-builder)
