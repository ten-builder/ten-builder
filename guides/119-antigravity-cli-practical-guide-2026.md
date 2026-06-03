# Antigravity CLI 실전 가이드 2026 — Gemini CLI를 대체하는 Google 터미널 에이전트

> Google I/O 2026에서 공개된 Antigravity CLI — Gemini CLI를 완전히 대체하고 동적 병렬 서브에이전트로 터미널 코딩을 새로 정의한다

## 이 가이드에서 다루는 것

- Antigravity CLI가 Gemini CLI와 다른 점 (그리고 왜 대체인가)
- 설치 및 초기 설정
- 동적 서브에이전트 & 병렬 실행 실전
- Hooks로 코딩 워크플로우 자동화
- Claude Code와의 역할 분담 전략

---

## Antigravity CLI란?

Google은 2026년 5월 I/O에서 Antigravity 2.0을 발표하며 터미널 개발자를 위한 전용 CLI도 함께 공개했습니다. Antigravity CLI는 **Gemini CLI의 공식 후속작**으로, 단순 LLM 터미널 인터페이스를 넘어 병렬 서브에이전트 오케스트레이션이 가능한 플랫폼으로 발전했습니다.

중요한 변경 사항이 있습니다. Gemini CLI는 2026년 6월 18일부로 개인 사용자(AI Pro, AI Ultra, 무료 플랜)에게 서비스를 종료합니다. 터미널에서 Gemini를 계속 쓰려면 Antigravity CLI로 전환이 필요합니다.

| 특성 | Gemini CLI | Antigravity CLI |
|------|-----------|-----------------|
| 기반 | 단독 CLI | Antigravity 에이전트 하네스 공유 |
| 서브에이전트 | 없음 | 동적 병렬 서브에이전트 지원 |
| Hooks | 없음 | 코딩 이벤트 자동화 가능 |
| 기본 모델 | Gemini 1.5 Pro | Gemini 3.5 Flash |
| 서비스 | 유지 (엔터프라이즈만) | 현재 무료 |

---

## 설치

### macOS

```bash
# npm 설치 (권장)
npm install -g @google/antigravity-cli

# 버전 확인
antigrav --version

# 로그인
antigrav auth login
```

### Linux

```bash
curl -fsSL https://antigravity.google.dev/install.sh | sh

# PATH 추가
echo 'export PATH="$HOME/.antigravity/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Windows (PowerShell)

```powershell
winget install Google.AntigravityCLI
```

### 초기 설정

```bash
# Google 계정 인증
antigrav auth login

# 프로젝트 연결 (선택)
cd ~/projects/my-app
antigrav init

# 설정 확인
antigrav config list
```

---

## 기본 사용법

### 일반 대화 및 코딩

```bash
# 단순 질문
antigrav "이 TypeScript 에러를 어떻게 고치나요?"

# 파일 기반 작업
antigrav "auth.ts의 JWT 토큰 검증 로직을 개선해줘"

# 인터랙티브 세션
antigrav chat
```

### 모델 선택

```bash
# 기본: Gemini 3.5 Flash (빠름, 무료)
antigrav chat

# 고성능 작업: Gemini 3.5 Pro
antigrav chat --model gemini-3.5-pro

# 설정으로 기본 모델 변경
antigrav config set model gemini-3.5-pro
```

---

## 핵심 기능: 동적 서브에이전트

Antigravity CLI의 가장 중요한 차별점은 **동적 서브에이전트**입니다. 복잡한 태스크를 여러 전문 에이전트가 병렬로 처리합니다.

### 서브에이전트 작동 방식

메인 에이전트가 태스크를 분석하고, 필요에 따라 전문화된 서브에이전트를 즉석에서 생성합니다. 서브에이전트는 부모의 도구 설정과 보안 권한을 그대로 상속받습니다.

```
메인 에이전트
├── 서브에이전트 1: 백엔드 API 리팩토링
├── 서브에이전트 2: 테스트 코드 작성
└── 서브에이전트 3: API 문서 업데이트
```

### 실전 예시: 병렬 기능 구현

```bash
antigrav "사용자 인증 시스템을 구현해줘. 
백엔드 JWT 로직, 프론트엔드 로그인 폼, 
통합 테스트를 동시에 만들어줘"
```

Antigravity CLI가 내부적으로 처리하는 방식:

1. 태스크 분석 → 3개 서브에이전트 생성 결정
2. 서브에이전트 A: `src/auth/` 백엔드 작업
3. 서브에이전트 B: `src/components/Login` 프론트 작업
4. 서브에이전트 C: `tests/auth.test.ts` 작성
5. 메인 에이전트: 결과 통합 및 충돌 해결

---

## Hooks: 코딩 이벤트 자동화

Hooks를 사용하면 파일 저장, 빌드 완료 등 특정 이벤트 발생 시 자동으로 에이전트 작업을 실행할 수 있습니다.

### ANTIGRAVITY.md 파일 설정

프로젝트 루트에 `ANTIGRAVITY.md`를 만들어 에이전트 행동을 정의합니다.

```markdown
# ANTIGRAVITY.md

## 프로젝트 컨텍스트
- TypeScript Next.js 프로젝트
- 테스트: Jest + Testing Library
- 린팅: ESLint + Prettier

## Hooks

### PostFileSave
저장 후 자동으로 해당 파일의 타입 에러 확인

### PostBuildFail
빌드 실패 시 에러 로그 분석 후 수정 제안

### PreCommit
커밋 전 코드 품질 검사
```

### antigrav.config.json으로 Hooks 설정

```json
{
  "hooks": {
    "postToolUse": {
      "Write": {
        "command": "npx tsc --noEmit",
        "onFail": "analyze_and_fix"
      }
    },
    "postBuild": {
      "onFail": {
        "action": "agent",
        "prompt": "빌드 에러를 분석하고 수정해줘: {{error}}"
      }
    }
  },
  "subagents": {
    "maxParallel": 5,
    "inheritPermissions": true
  }
}
```

---

## Antigravity CLI vs Claude Code: 언제 무엇을?

두 도구는 경쟁 관계가 아닙니다. 각자 잘하는 영역이 다릅니다.

| 상황 | Antigravity CLI | Claude Code |
|------|-----------------|-------------|
| 새 기능 병렬 구현 | 적합 (서브에이전트) | 적합 (Tasks) |
| 기존 대형 코드베이스 분석 | 제한적 | 적합 (긴 컨텍스트) |
| Google Cloud/Firebase 연동 | 강점 | 보통 |
| 복잡한 리팩토링 계획 | 보통 | 강점 |
| 비용 최소화 | 강점 (Gemini Flash 무료) | 비용 발생 |
| VS Code 플러그인 활용 | 제한 (Open VSX만) | 자유 |

### 조합 활용 패턴

```bash
# 1단계: Antigravity CLI로 기능 설계 및 병렬 초안 작성 (무료)
antigrav "결제 모듈의 설계를 잡고 초안을 작성해줘"

# 2단계: Claude Code로 세밀한 리뷰 및 리팩토링
claude "이 결제 코드의 에러 처리와 엣지 케이스를 강화해줘"
```

---

## 실전 워크플로우

### 1. 새 프로젝트 킥오프

```bash
mkdir my-saas && cd my-saas
antigrav init
antigrav "Next.js + Supabase SaaS 보일러플레이트를 설정해줘.
인증, 대시보드, API 라우트를 병렬로 구성해줘"
```

### 2. PR 전 자동 품질 검사

```bash
# antigrav.config.json에 preCommit hook 설정 후
git add .
git commit -m "feat: add user profile page"
# → 자동으로 에이전트가 코드 리뷰, 타입 체크, 테스트 실행
```

### 3. 인시던트 대응

```bash
antigrav "프로덕션 에러 로그를 분석하고 근본 원인을 찾아줘" \
  --context ./logs/error-2026-06-04.log
```

---

## Gemini CLI에서 마이그레이션하기

기존 `gemini` CLI 명령어와 Antigravity CLI 명령어는 대체로 호환됩니다.

| Gemini CLI | Antigravity CLI |
|-----------|-----------------|
| `gemini "질문"` | `antigrav "질문"` |
| `gemini chat` | `antigrav chat` |
| `gemini -m gemini-pro "..."` | `antigrav --model gemini-3.5-pro "..."` |
| `gemini -s system.md "..."` | `antigrav --context system.md "..."` |

### 마이그레이션 체크리스트

- [ ] `antigrav` 설치 및 로그인 완료
- [ ] 기존 스크립트의 `gemini` 명령어를 `antigrav`로 교체
- [ ] `GEMINI.md` 파일이 있다면 `ANTIGRAVITY.md`로 이름 변경
- [ ] Hooks 설정 추가 (선택, 하지만 권장)
- [ ] 팀에 마이그레이션 가이드 공유

---

## 자주 쓰는 명령어 정리

| 명령어 | 용도 |
|--------|------|
| `antigrav "질문"` | 단일 질문 |
| `antigrav chat` | 대화형 세션 시작 |
| `antigrav init` | 프로젝트 초기화 |
| `antigrav config list` | 설정 확인 |
| `antigrav config set model <model>` | 기본 모델 변경 |
| `antigrav auth login` | 재인증 |
| `antigrav --help` | 전체 명령어 확인 |

---

## 다음 단계

- [Google ADK 실전 가이드](./116-google-adk-practical-guide-2026.md) — Antigravity와 함께 멀티에이전트 시스템 구축
- [Antigravity IDE 실전 가이드](./85-google-antigravity-ide-practical-guide-2026.md) — GUI 버전 심화 활용

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **구독:** [@ten-builder](https://youtube.com/@ten-builder)
