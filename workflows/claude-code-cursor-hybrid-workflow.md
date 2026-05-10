# Claude Code + Cursor 하이브리드 워크플로우

> 두 도구의 강점을 조합해 개발 속도와 코드 품질을 함께 높이는 실전 가이드

## 개요

2026년 기준 개발자들은 평균 2.3개의 AI 코딩 도구를 동시에 사용합니다. 그중 Claude Code와 Cursor의 조합이 실무에서 가장 많이 쓰이는 스택입니다.

두 도구는 경쟁 관계가 아닙니다. 각자 잘하는 영역이 다릅니다.

| 도구 | 강점 | 적합한 작업 |
|------|------|------------|
| **Claude Code** | 전체 코드베이스 파악, 멀티 파일 수정, 자율 실행 | 리팩토링, 마이그레이션, 아키텍처 변경 |
| **Cursor** | 인라인 제안, 빠른 편집, 시각적 피드백 | 기능 구현, 컴포넌트 작성, 즉각적인 수정 |

이 워크플로우는 두 도구를 태스크 유형에 따라 전환하면서 사용하는 방법을 다룹니다.

## 사전 준비

- Claude Code 설치 (`npm install -g @anthropic-ai/claude-code`)
- Cursor 설치 + Claude Code 익스텐션 활성화
- 프로젝트 루트에 `CLAUDE.md` 작성 (컨텍스트 공유)
- `.cursorrules` 또는 `.cursor/rules` 설정

## 설정

### Step 1: 공유 컨텍스트 파일 구성

두 도구가 동일한 맥락을 가지도록 `CLAUDE.md`를 작성합니다.

```markdown
# Project Context

## 기술 스택
- Backend: Node.js + TypeScript + Fastify
- Frontend: Next.js 15 + Tailwind CSS
- DB: PostgreSQL + Prisma

## 코딩 규칙
- 함수형 컴포넌트만 사용 (클래스 컴포넌트 금지)
- 에러 처리는 Result 타입 패턴 사용
- 커밋은 Conventional Commits 형식

## 금지 패턴
- any 타입 사용 금지
- console.log 프로덕션 코드에 포함 금지
```

### Step 2: Cursor에 Claude Code 익스텐션 연동

Cursor 설정에서 Claude Code를 외부 터미널 에이전트로 연결합니다.

```json
// .cursor/settings.json
{
  "terminal.integrated.env.osx": {
    "ANTHROPIC_API_KEY": "${env:ANTHROPIC_API_KEY}"
  },
  "claude-code.integration": {
    "enabled": true,
    "syncClaude_md": true
  }
}
```

### Step 3: 작업 유형별 라우팅 규칙 정의

```markdown
# .cursor/rules/routing.md

## Claude Code로 처리할 작업
- 파일 3개 이상 동시 수정
- 데이터베이스 스키마 변경 + 마이그레이션
- 의존성 업그레이드
- 전체 모듈 리팩토링

## Cursor에서 처리할 작업
- 단일 함수/컴포넌트 구현
- 버그 수정 (1~2개 파일)
- 스타일 변경
- 빠른 프로토타이핑
```

## 사용 방법

### 패턴 1: 계획은 Claude Code, 구현은 Cursor

복잡한 기능을 시작할 때 효과적인 방식입니다.

```bash
# 1. Claude Code로 태스크 분석 및 파일 목록 파악
claude "결제 모듈을 리팩토링해야 해. 현재 구조를 분석하고
어떤 파일을 어떤 순서로 수정해야 할지 계획을 세워줘.
코드는 작성하지 말고 계획만."

# 2. Claude Code가 분석한 파일들을 Cursor에서 열기
# 3. Cursor 인라인 에이전트로 각 파일 구현
```

### 패턴 2: 구현 후 Claude Code로 검토

Cursor로 빠르게 구현하고 Claude Code로 전체 일관성을 검토합니다.

```bash
# Cursor에서 구현 완료 후
claude "방금 구현한 결제 컴포넌트를 검토해줘.
기존 코드베이스 패턴과 일관성이 있는지,
보안 이슈는 없는지 확인해줘."
```

### 패턴 3: 파일 경계를 넘는 변경은 Claude Code

API 변경, 타입 수정, 인터페이스 변경처럼 여러 파일에 영향을 주는 작업입니다.

```bash
# API 응답 구조 변경
claude "UserResponse 타입을 변경해야 해.
firstName/lastName을 fullName으로 합치는 변경인데
관련된 모든 파일을 찾아서 일관성 있게 수정해줘."
```

## 일반적인 하루 워크플로우

```
오전: Cursor
- 전날 PR 리뷰, 이슈 파악
- 새 기능 단위 구현 (컴포넌트, 함수)

오후 전반: 필요 시 Claude Code 전환
- 크로스 파일 리팩토링
- 마이그레이션, 의존성 업데이트

오후 후반: Cursor 복귀
- 디버깅, 스타일 수정
- 테스트 코드 작성
```

## 컨텍스트 동기화 유지

두 도구가 다른 맥락을 가지면 일관성 없는 코드가 생성됩니다. 중요한 결정은 `CLAUDE.md`에 기록해두세요.

```bash
# 중요한 아키텍처 결정 후
claude "방금 결정한 내용을 CLAUDE.md에 추가해줘:
레거시 API는 2026년 Q3까지 유지하고
새 엔드포인트는 v2/ 프리픽스 사용"
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `CLAUDE.md` 위치 | 프로젝트 루트 | Cursor와 Claude Code 모두 자동 인식 |
| 컨텍스트 전달 방식 | 파일 | `--add-context` 플래그로 추가 파일 지정 가능 |
| 도구 전환 기준 | 파일 수 3개 | 팀 규칙에 따라 조정 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| Claude Code가 Cursor 편집 내용을 모름 | `git add` 후 Claude Code 실행 |
| 두 도구가 다른 스타일로 코드 생성 | `.cursorrules`와 `CLAUDE.md` 규칙 통일 |
| Claude Code가 Cursor 파일을 덮어씀 | 작업 전 `git stash` 또는 브랜치 분리 |
| 컨텍스트가 너무 길어짐 | `CLAUDE.md`를 핵심만 남기고 정리 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
