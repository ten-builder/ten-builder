# AI 멀티 툴 코딩 스택 치트시트

> 개발자 1인이 평균 2.3개 AI 도구를 쓰는 2026년 — Cursor, Claude Code, Codex CLI를 하나의 스택으로 연결하는 실전 참조 카드

## 도구별 역할 분담

| 도구 | 강점 | 주 사용 시점 |
|------|------|------------|
| **Cursor** | 빠른 인라인 편집, UI 탐색, 멀티모델 지원 | 빠른 수정, 컴포넌트 개발, 코드 탐색 |
| **Claude Code** | 깊은 컨텍스트, 에이전트 자율 실행, 대형 코드베이스 | 복잡한 기능 구현, 멀티 파일 리팩터링, 테스트 자동화 |
| **Codex CLI** | 샌드박스 격리, approval 기반 안전 실행 | 위험 명령어 검증, 인프라 변경, 외부 API 연동 |

---

## 레이어별 스택 구성

```
┌─────────────────────────────┐
│  탐색 / 빠른 편집 레이어       │  ← Cursor (IDE 내)
│  인라인 수정, 자동완성, Chat   │
├─────────────────────────────┤
│  에이전트 자율 실행 레이어      │  ← Claude Code (터미널)
│  복잡 태스크, 멀티 파일, Hooks │
├─────────────────────────────┤
│  안전 격리 실행 레이어          │  ← Codex CLI (샌드박스)
│  시스템 명령어, IaC, 검증      │
└─────────────────────────────┘
```

---

## 작업 유형별 도구 선택

| 작업 | 추천 도구 | 이유 |
|------|---------|------|
| 컴포넌트 1개 수정 | Cursor | 빠른 인라인 편집 |
| UI 버그 수정 | Cursor | 파일 탐색 + 즉시 편집 |
| 새 기능 전체 구현 | Claude Code | 에이전트 자율 실행 |
| 대규모 리팩터링 | Claude Code | 멀티 파일 일관성 유지 |
| 테스트 코드 생성 | Claude Code | 코드베이스 전체 맥락 활용 |
| 인프라 변경 (Terraform) | Codex CLI | 샌드박스 + approval 검증 |
| DB 마이그레이션 | Codex CLI | 되돌리기 어려운 변경 — 격리 필요 |
| 외부 API 키 다루는 스크립트 | Codex CLI | 시크릿 유출 위험 최소화 |

---

## 일반적인 하루 워크플로우

```
오전: Cursor로 이슈 파악 + 빠른 수정
       ↓
오후: Claude Code로 복잡한 기능 구현 (에이전트 자율 실행)
       ↓
PR 전: Codex CLI로 마이그레이션/IaC 변경 검증
       ↓
리뷰: Cursor에서 diff 확인 + 인라인 코멘트
```

---

## 도구 연결 패턴

### 패턴 1: Cursor에서 Claude Code로 위임

```bash
# Cursor에서 복잡한 태스크 감지 시
# → Claude Code로 컨텍스트 전달

# 1. 현재 파일 경로 복사
# 2. Claude Code 터미널에서 실행
claude --context "현재 작업 중인 파일: src/api/auth.ts" \
  "JWT 갱신 로직을 refresh token rotation 패턴으로 바꿔줘"
```

### 패턴 2: Claude Code + Codex CLI 교차 검증

```bash
# Claude Code가 생성한 마이그레이션 파일을 Codex CLI로 검증
codex "이 마이그레이션 파일을 dry-run으로 실행하고 영향 범위 알려줘" \
  --approval-mode suggest

# Codex가 안전하다고 확인하면 실제 실행
codex "이전 마이그레이션 실행해줘" --approval-mode auto
```

### 패턴 3: 비용 최적화 라우팅

```
간단한 수정 (< 5분) → Cursor (빠르고 저렴)
중간 복잡도 → Claude Code Sonnet
고복잡도 아키텍처 → Claude Code Opus (Max 플랜)
위험 실행 → Codex CLI (격리 환경)
```

---

## Cursor 핵심 단축키

| 단축키 | 기능 |
|--------|------|
| `Cmd+K` | 인라인 편집 |
| `Cmd+L` | 채팅 패널 열기 |
| `Cmd+Shift+J` | 에이전트 모드 실행 |
| `Cmd+I` | Composer 열기 (멀티 파일) |
| `@파일명` | 특정 파일 컨텍스트 주입 |

---

## Claude Code 핵심 명령어

```bash
# 기본 실행
claude "태스크 설명"

# 파일 컨텍스트 포함
claude --add-dir src/ "auth 모듈 전체 리팩터링"

# Plan 모드 (실행 전 계획 확인)
claude --plan "DB 스키마 변경"

# Hooks 트리거
claude --hooks-enabled "PR 생성 전 테스트 실행"

# 백그라운드 실행
claude --background "전체 테스트 스위트 실행"
```

---

## Codex CLI 핵심 명령어

```bash
# suggest 모드 (제안만, 실행 안 함)
codex --approval-mode suggest "nginx 설정 최적화"

# auto 모드 (자동 실행, 낮은 위험도만)
codex --approval-mode auto "npm 패키지 업데이트"

# full-auto 모드 (모든 승인 자동화, 주의)
codex --approval-mode full-auto "test 실행"

# 샌드박스 네트워크 차단
codex --no-network "로컬 스크립트만 실행"
```

---

## 비용 기준 (2026년 4월)

| 도구 | 플랜 | 월 비용 |
|------|------|--------|
| Cursor | Pro | $20 |
| Claude | Pro | $20 |
| Claude | Max | $100~$200 |
| Codex | API 사용량 | 변동 |
| GitHub Copilot | Pro | $10 |

**스타터 스택:** Cursor Pro + Claude Pro = $40/월
**파워 스택:** Cursor Pro + Claude Max ($100) = $120/월
**풀 스택:** Cursor + Claude Max + Copilot Pro = $130/월

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 모든 작업에 Claude Code 사용 → 비용 폭증 | 간단한 수정은 Cursor로 |
| Codex 없이 DB 변경 → 실수 복구 불가 | 되돌리기 어려운 작업은 Codex로 격리 |
| 3개 도구 동시 실행 → 컨텍스트 충돌 | 도구별 역할을 명확히 분리 |
| Cursor와 Claude Code 같은 파일 동시 편집 | 한 번에 한 도구만 파일 수정 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
