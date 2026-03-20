# 가이드 26: 멀티 AI 코딩 도구 조합 워크플로우

> 하나의 도구로 모든 작업을 하지 마세요 — 상황에 맞는 도구를 골라 쓰는 게 2026년 AI 코딩의 핵심이에요.

## 이 가이드가 필요한 경우

- Claude Code, Cursor, Codex CLI 중 하나만 쓰고 있는데 한계를 느낄 때
- "어떤 도구가 최고야?"라는 질문에 답을 못 찾겠을 때
- 작업 종류에 따라 도구를 바꿔가며 쓰고 싶을 때
- 팀에서 도구 표준화를 고민 중일 때

## 핵심 원칙: 도구마다 잘하는 게 다르다

모든 AI 코딩 도구가 비슷해 보이지만, 실제로 쓰면 성격이 완전히 달라요.

| 작업 유형 | 추천 도구 | 이유 |
|-----------|-----------|------|
| 복잡한 아키텍처 설계 | Claude Code | 깊은 추론 + 멀티파일 동시 수정 |
| 일상적인 기능 개발 | Cursor | IDE 통합 + 빠른 자동완성 |
| 대량 반복 작업 | Codex CLI | 빠른 속도 + 병렬 실행 |
| 코드베이스 탐색 | Gemini CLI | 2M 토큰 컨텍스트 윈도우 |
| 빠른 프로토타이핑 | Cursor Composer | 실시간 미리보기 + 멀티파일 |
| 코드 리뷰 | Claude Code | 정밀한 추론 + 보안 분석 |
| CI/CD 디버깅 | Codex CLI | GitHub 딥 통합 |

## Step 1: 작업 단계별 도구 매핑

하루 개발 흐름에서 각 단계에 맞는 도구를 배치해 보세요.

### 오전: 설계 + 구조 잡기 → Claude Code

```bash
# 새 기능의 전체 구조를 Claude Code로 설계
claude "사용자 인증 모듈을 설계해줘. 
JWT + refresh token 패턴으로, 
middleware, service, controller 레이어 분리해서"
```

Claude Code는 여러 파일을 한 번에 생성하고 의존성 관계를 파악하는 데 뛰어나요. 초기 설계나 리팩토링처럼 "큰 그림"이 필요한 작업에 적합해요.

### 오후: 구현 + 코딩 → Cursor

설계가 끝나면 Cursor로 전환해서 실제 코드를 채워 넣어요.

| Cursor 기능 | 활용 시점 |
|-------------|-----------|
| Tab 자동완성 | 반복 패턴 코딩 |
| Composer | 여러 파일 동시 수정 |
| Agent 모드 | 기능 단위 구현 |
| `@file` 참조 | 특정 파일 맥락 지정 |

Cursor의 장점은 코드를 쓰는 흐름이 끊기지 않는다는 거예요. 터미널과 에디터를 오갈 필요 없이 IDE 안에서 모든 게 해결돼요.

### 저녁: 리뷰 + 테스트 → Claude Code

```bash
# 오늘 작업한 변경사항 전체 리뷰
claude "git diff main...HEAD를 보고 
코드 리뷰해줘. 보안 이슈, 
성능 문제, 누락된 에러 핸들링 위주로"
```

리뷰 단계에서는 다시 Claude Code가 효과적이에요. 변경사항 전체를 한 번에 분석하고, 보안 취약점이나 엣지 케이스를 찾아내는 정밀도가 높아요.

## Step 2: 프로젝트 규칙 파일 통일

여러 도구를 쓰면 프로젝트 규칙을 각 도구에 맞게 관리해야 해요.

### 규칙 파일 매핑

```
프로젝트 루트/
├── CLAUDE.md          # Claude Code 규칙
├── .cursor/rules/     # Cursor 규칙
├── AGENTS.md          # Codex CLI + 범용 규칙
├── .gemini/           # Gemini CLI 설정
└── .ai-rules.md       # 공통 규칙 (수동 동기화 원본)
```

### 공통 규칙 동기화 전략

핵심 규칙은 하나의 원본 파일(`.ai-rules.md`)에 작성하고, 각 도구 파일에서 참조하세요.

```markdown
<!-- CLAUDE.md -->
# 프로젝트 규칙
이 프로젝트의 공통 규칙은 .ai-rules.md를 참조하세요.

## Claude Code 전용 규칙
- /compact 사용 시 핵심 컨텍스트 유지
- 서브에이전트는 독립된 태스크에만 사용
```

```markdown
<!-- AGENTS.md -->
# Agent Guidelines
See .ai-rules.md for shared project conventions.

## Codex-specific
- Prefer parallel execution for independent tasks
- Use sandbox mode for destructive operations
```

| 규칙 유형 | 공통 파일에 | 도구별 파일에 |
|-----------|------------|--------------|
| 코딩 컨벤션 | ✅ | ❌ |
| 커밋 메시지 형식 | ✅ | ❌ |
| 컨텍스트 관리 | ❌ | ✅ |
| 도구 고유 기능 | ❌ | ✅ |
| 디렉토리 구조 | ✅ | ❌ |
| 테스트 패턴 | ✅ | ❌ |

## Step 3: 컨텍스트 이관 패턴

도구를 전환할 때 가장 큰 문제는 컨텍스트 유실이에요. 작업 내용을 다른 도구에 넘기는 패턴을 만들어 두세요.

### 패턴 1: Git 브랜치 기반 이관

```bash
# Claude Code에서 설계 완료 후
git add -A && git commit -m "feat(auth): initial architecture"

# Cursor에서 브랜치 열어서 구현 시작
# → git log와 diff로 설계 의도 파악 가능
```

### 패턴 2: 요약 파일 생성

```bash
# Claude Code 세션 종료 전
claude "지금까지 작업 내용을 .handoff.md에 정리해줘.
다른 AI 도구가 이어서 작업할 수 있도록
결정사항, 남은 작업, 주의사항을 포함해서"
```

`.handoff.md` 예시:

```markdown
## 결정사항
- JWT + refresh token 패턴 채택
- Redis에 refresh token 저장

## 완료된 작업
- auth.service.ts: 토큰 생성/검증 로직
- auth.middleware.ts: 인증 미들웨어

## 남은 작업
- [ ] auth.controller.ts: 로그인/로그아웃 엔드포인트
- [ ] 테스트 코드 작성

## 주의사항
- refresh token rotation 반드시 구현할 것
- rate limiting은 별도 미들웨어로 분리
```

### 패턴 3: 세션 기록 활용

```bash
# Claude Code 대화 내역 확인
claude "이번 세션에서 수정한 파일 목록과 
각 파일의 변경 이유를 요약해줘"
```

## Step 4: 상황별 도구 선택 의사결정 트리

```
새 작업 시작
├── 파일 1-2개 수정? → Cursor (빠른 편집)
├── 파일 5개 이상 동시 수정? → Claude Code (멀티파일 추론)
├── 반복 패턴 100개 적용? → Codex CLI (병렬 처리)
├── 대규모 코드베이스 이해? → Gemini CLI (넓은 컨텍스트)
├── 새 프로젝트 스캐폴딩? → Cursor Composer (실시간 미리보기)
└── 프로덕션 버그 긴급 수정? → Claude Code (정밀 분석)
```

## Step 5: 비용 최적화

여러 도구를 동시에 쓰면 비용이 걱정되죠. 현실적인 조합과 월 비용을 정리해 봤어요.

| 조합 | 월 예상 비용 | 적합한 사용자 |
|------|-------------|--------------|
| Cursor Pro만 | ~$16 | 일반 개발자, IDE 중심 |
| Claude Code + Cursor | ~$33-50 | 시니어 개발자, 아키텍처 작업 多 |
| Codex + Copilot | ~$20-30 | GitHub 중심 워크플로우 |
| Claude Code + Cursor + Gemini CLI | ~$33-50 | 풀스택, 다양한 작업 |

### 비용 절약 팁

```bash
# Claude Code: /compact로 토큰 사용량 줄이기
/compact

# Claude Code: 서브에이전트로 토큰 분산
claude "이 리팩토링은 서브에이전트에게 위임해줘"

# Gemini CLI: 무료 티어 먼저 활용
gemini "이 코드베이스 구조 설명해줘"
```

## 체크리스트

- [ ] 주 사용 도구 2개 선택 완료
- [ ] 프로젝트 규칙 파일 각 도구용으로 작성
- [ ] `.ai-rules.md` 공통 규칙 파일 생성
- [ ] 컨텍스트 이관 패턴 1개 이상 적용
- [ ] 팀원과 도구 조합 합의 (팀 프로젝트인 경우)

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| 모든 작업에 한 도구만 사용 | 작업 유형별 도구 매핑 |
| 도구 전환 시 컨텍스트 유실 | `.handoff.md` 패턴 적용 |
| 규칙 파일 중복 관리 | 공통 원본 + 도구별 참조 |
| 무작정 비싼 도구 구독 | 무료 티어 먼저 충분히 활용 |
| 도구 전환에 시간 낭비 | 작업 단위로 전환, 문장 중간에 바꾸지 않기 |

## 다음 단계

→ [AI CLI 도구 비교 치트시트](../cheatsheets/ai-cli-tools-comparison.md)
→ [컨텍스트 관리 플레이북](../claude-code/playbooks/12-context-management.md)
→ [CLAUDE.md 최적화 플레이북](../claude-code/playbooks/13-claudemd-optimization.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
