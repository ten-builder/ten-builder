# Cursor IDE 실전 가이드 2026 — AI 코딩 에이전트로 10배 빠르게 개발하기

> Cursor는 단순한 AI 자동완성 플러그인이 아닙니다. VS Code를 기반으로 구축된 독립 IDE로, Background Agents, Notepads, .cursorrules, Composer까지 — 제대로 설정하면 개발 흐름이 완전히 바뀝니다.

## Cursor가 다른 AI 코딩 도구와 다른 점

Cursor는 에디터 자체가 AI를 중심으로 설계되어 있습니다. 단순히 플러그인을 추가하는 것과 달리, IDE의 모든 레이어에 AI가 통합되어 있어요.

| 기능 | Cursor | Claude Code | GitHub Copilot |
|------|--------|-------------|----------------|
| 에디터 통합 | 네이티브 IDE | 터미널 기반 | VS Code 플러그인 |
| 컨텍스트 인식 | 전체 코드베이스 | 전체 코드베이스 | 현재 파일 중심 |
| Background Agents | 지원 | 지원 | 미지원 |
| Notepads | 지원 | CLAUDE.md 유사 | 미지원 |
| YOLO 모드 | 지원 | 지원 | 미지원 |
| 모델 선택 | Claude, GPT, Gemini | Claude 계열 | GPT 계열 |

---

## 핵심 설정: .cursorrules

`.cursorrules`는 Cursor가 모든 대화에 자동으로 주입하는 프로젝트별 규칙입니다. 잘 작성된 `.cursorrules`는 개발팀의 코딩 표준과 AI 에이전트를 정렬시킵니다.

### 기본 구조

```
# 프로젝트 개요
이 프로젝트는 TypeScript + Next.js 14 App Router 기반의 SaaS입니다.

# 코딩 스타일
- 함수형 컴포넌트만 사용, 클래스 컴포넌트 금지
- async/await 패턴 사용, Promise 체인 금지
- 모든 공개 함수에 JSDoc 주석 필수

# AI 에이전트 규칙
- 변경 전 영향받는 파일 목록을 먼저 알릴 것
- 테스트 없는 비즈니스 로직 생성 금지
- 기존 패턴과 일관성 유지 (새 패턴 임의 도입 금지)

# 응답 형식
- 코드만 제안하고 장황한 설명 생략
- 변경 이유를 한 줄로만 설명
```

### 2026년 권장 Meta-Rules

Cursor 2.6+ 이후 에이전트가 자율적으로 동작하는 경우가 많아졌습니다. 규칙에 경계를 명확히 설정하세요.

```
# 자율 실행 경계
- 파일 삭제/이름 변경 전 반드시 확인
- 패키지 추가 시 이유와 대안 명시
- 환경변수 변경 시 알림 필수

# 자동 승인 허용 (YOLO 모드)
- 린트 에러 자동 수정
- 타입 에러 자동 수정
- 테스트 통과 확인 후 자동 커밋
```

---

## Notepads — 재사용 가능한 프롬프트 템플릿

Notepads는 반복적으로 사용하는 프롬프트, 아키텍처 결정, API 계약서 등을 저장하는 공간입니다. `@notepad/이름`으로 Chat이나 Composer에서 불러올 수 있어요.

### 유용한 Notepad 예시

**@notepad/api-patterns**
```
# API 엔드포인트 작성 패턴
- 모든 응답은 { data, error, meta } 형식
- 에러: { code, message, details }
- 페이지네이션: { page, limit, total, hasNext }
- 인증: Bearer JWT, 만료 시 401 반환
```

**@notepad/testing-strategy**
```
# 테스트 작성 기준
- 단위 테스트: 비즈니스 로직 함수 100% 커버리지
- 통합 테스트: API 엔드포인트 happy path + edge case
- E2E 테스트: 핵심 사용자 흐름 3가지 (회원가입, 결제, 주요 기능)
- 테스트 파일명: {기능명}.test.ts
```

`.cursorrules`는 모든 세션에 자동 주입되지만, Notepads는 필요할 때만 호출합니다. 세션 컨텍스트를 효율적으로 관리하는 핵심 패턴입니다.

---

## Composer — 멀티 파일 에이전트 모드

Composer는 여러 파일을 동시에 수정하는 Cursor의 핵심 기능입니다. Chat이 단일 파일 대화라면, Composer는 기능 단위 에이전트 실행입니다.

### Composer 효과적으로 쓰는 법

1. **태스크를 구체적으로 지정합니다**

```
나쁨: "결제 기능 만들어줘"

좋음: "Stripe Checkout Session을 생성하는 POST /api/payment/checkout
엔드포인트를 구현해줘. 성공 시 session_id 반환, 실패 시 로깅 포함.
관련 파일: src/app/api/payment/, src/lib/stripe.ts"
```

2. **체크포인트를 활용합니다** — Composer가 변경을 시작하기 전 "계획을 먼저 보여줘"라고 요청하세요. 의도치 않은 대규모 변경을 사전에 막습니다.

3. **@codebase 컨텍스트** — `@codebase`를 붙이면 전체 레포지토리를 참조합니다. 기존 패턴을 따라야 할 때 유용합니다.

---

## Background Agents — 비동기 태스크 실행

Cursor 2026의 Background Agents는 코딩하는 동안 다른 작업을 자동으로 처리합니다.

### 설정 방법

```
Settings > Agents > Background Agents 활성화
```

### 실전 활용 패턴

| 트리거 | 자동 실행 작업 |
|--------|---------------|
| 파일 저장 | 린트 검사 + 자동 수정 |
| PR 생성 | 테스트 스위트 실행 |
| 의존성 추가 | 보안 취약점 스캔 |
| 커밋 전 | 타입 체크 |

```bash
# .cursor/hooks/pre-commit.sh
#!/bin/bash
# Cursor Background Agent Hook
npx tsc --noEmit && npx eslint src/ --fix
```

---

## YOLO 모드 — 승인 없는 자동 실행

YOLO(You Only Live Once) 모드는 에이전트가 터미널 명령어를 자동으로 실행합니다. 보안과 속도의 균형이 중요합니다.

**허용 권장:**

```
✅ npx tsc, eslint, prettier
✅ npm test, vitest
✅ git add, git commit
✅ npm install (lock 파일 생성)
```

**절대 허용 금지:**

```
❌ rm -rf
❌ git push (검토 전)
❌ production 환경 변수 변경
❌ DB 마이그레이션 실행
```

---

## Claude Code vs Cursor — 언제 무엇을 쓸까

텐빌더 채널 구독자들이 자주 묻는 질문입니다.

| 상황 | 추천 |
|------|------|
| GUI 에디터 선호, VS Code 익숙 | Cursor |
| 터미널 중심 워크플로우 | Claude Code |
| 팀원이 VS Code 사용 중 | Cursor |
| 대규모 에이전트 오케스트레이션 | Claude Code |
| 멀티 모델 전환이 자주 필요 | Cursor |
| 헤드리스/CI 환경에서 실행 | Claude Code |

두 도구를 조합하는 패턴도 많습니다. Cursor로 코딩하고, Claude Code로 대규모 리팩토링을 맡기는 식으로요.

---

## 팀 협업 설정

`.cursorrules`를 Git에 커밋하면 팀 전체가 동일한 AI 에이전트 설정을 공유합니다.

```bash
# 팀 공유 설정
git add .cursorrules
git commit -m "chore: add Cursor AI team rules"
git push
```

Notepads는 현재 로컬 전용입니다. 공유가 필요하다면 `docs/ai-prompts/` 폴더에 마크다운으로 보관하고 팀원이 직접 Notepads에 복사하는 방식을 씁니다.

---

## 체크리스트 — Cursor 세팅 완료 확인

- [ ] `.cursorrules` 파일 작성 후 Git 커밋 완료
- [ ] 자주 쓰는 Notepads 3개 이상 등록
- [ ] Background Agents 활성화 및 Hook 설정
- [ ] YOLO 모드 허용/금지 명령어 목록 확인
- [ ] 팀 모델 선택 기준 정립 (Claude vs GPT vs Gemini)
- [ ] Privacy Mode 확인 (코드가 학습 데이터로 사용되지 않도록)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
