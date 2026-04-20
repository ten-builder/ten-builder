# AGENTS.md 컨텍스트 파일 설계 치트시트

> AI 에이전트가 레포를 처음 보는 것처럼 행동하지 않도록 — 올바른 AGENTS.md / CLAUDE.md 설계로 에이전트 성능을 끌어올리는 패턴 정리

---

## 핵심 개념

| 파일 | 역할 | 적용 에이전트 |
|------|------|-------------|
| `AGENTS.md` | 레포 전체용 컨텍스트 (OpenAI Codex, 범용) | Codex CLI, OpenAI Agents |
| `CLAUDE.md` | Claude Code 전용 프로젝트 컨텍스트 | Claude Code |
| `.cursorrules` | Cursor IDE 전용 규칙 | Cursor |

> **팁:** 두 에이전트를 함께 쓴다면 `CLAUDE.md`에 내용을 작성하고, `AGENTS.md`에서 include 참조하세요.

---

## 필수 섹션 (최소 구성)

```markdown
## 프로젝트 개요
- 무엇을 하는 서비스인지 1~2줄로 설명
- 핵심 사용자와 주요 기능

## 기술 스택
- 언어: TypeScript 5.4, Python 3.12
- 프레임워크: Next.js 15, FastAPI
- DB: PostgreSQL 16, Redis 7
- 테스트: Vitest, pytest

## 자주 쓰는 명령어
```bash
pnpm dev        # 개발 서버
pnpm test       # 테스트 전체 실행
pnpm build      # 프로덕션 빌드
```

## 코딩 규칙
- 함수형 컴포넌트만 사용 (클래스 컴포넌트 금지)
- 상태 관리: Zustand (Redux 사용 금지)
- API 응답 타입은 반드시 zod로 검증
```

---

## 섹션별 작성 패턴

### 1. 아키텍처 맵

```markdown
## 핵심 파일 구조
- `src/stores/` — Zustand 스토어 (상태 관리 진입점)
- `src/api/` — API 클라이언트 (직접 fetch 금지, 여기서만)
- `prisma/schema.prisma` — DB 스키마 진실의 원천
- `src/types/` — 공유 타입 정의 (중복 정의 금지)
```

### 2. 금지 사항 명시

```markdown
## 하지 말아야 할 것
- `console.log` 직접 사용 금지 → `logger.info()` 사용
- `any` 타입 사용 금지 → `unknown` + 타입 가드 사용
- 직접 DB 쿼리 금지 → 반드시 Repository 패턴 거쳐서
- `.env` 파일 수정 금지 → `.env.example`만 수정 후 안내
```

### 3. 테스트 규칙

```markdown
## 테스트 작성 기준
- 새 컴포넌트: 동일 디렉토리에 `.test.tsx` 파일 필수
- API 엔드포인트: 통합 테스트 1개 이상 필수
- 커버리지 기준: 70% 이상 유지
- Mock 도구: `msw` (axios-mock-adapter 사용 금지)
```

### 4. 커밋 / PR 규칙

```markdown
## Git 규칙
- 커밋 형식: `feat:`, `fix:`, `docs:`, `refactor:`
- PR 단위: 기능 1개 = PR 1개 원칙
- main 직접 push 금지
- PR 제목에 이모지 금지
```

---

## 크기 최적화 기법

| 전략 | 설명 |
|------|------|
| **핵심만** | 471줄 → 61줄로 압축 가능. 에이전트가 읽는 건 토큰 |
| **예시 우선** | 설명보다 코드 예시 1개가 3배 효과적 |
| **부정 금지 → 대안 제시** | "X 금지" 대신 "X 대신 Y 사용" |
| **섹션 분리** | 도메인 복잡도가 높으면 `docs/claude/` 폴더에 분리 |

**파일 크기 권장값:**

```
초소형 프로젝트:  30~60줄 (1인 사이드 프로젝트)
중형 프로젝트:   80~150줄 (팀 5명 이하)
대형 모노레포:   200줄 이하 + 서브 파일 참조
```

---

## 계층적 구성 패턴

```
project-root/
├── CLAUDE.md          ← 전체 규칙 (최상위)
├── src/
│   ├── frontend/
│   │   └── CLAUDE.md  ← 프론트엔드 특화 규칙
│   └── backend/
│       └── CLAUDE.md  ← 백엔드 특화 규칙
└── infra/
    └── CLAUDE.md      ← Terraform/k8s 규칙
```

> Claude Code는 현재 디렉토리와 부모 디렉토리의 CLAUDE.md를 모두 읽습니다.

---

## 효과 측정 기준

| 지표 | 나쁜 상태 | 좋은 상태 |
|------|----------|----------|
| 같은 실수 반복 | 3회 이상 | 0~1회 |
| 첫 시도 성공률 | 40% 미만 | 70% 이상 |
| 불필요한 패키지 제안 | 자주 발생 | 거의 없음 |
| 금지 패턴 사용 | 종종 발생 | 없음 |

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 너무 많은 내용 포함 | 일반 지식은 제외, 프로젝트 고유 정보만 |
| 오래된 정보 방치 | 월 1회 리뷰 루틴 추가 |
| 추상적 규칙만 나열 | 코드 예시로 구체화 |
| 팀원 공유 안 함 | PR 체크리스트에 CLAUDE.md 업데이트 항목 추가 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
