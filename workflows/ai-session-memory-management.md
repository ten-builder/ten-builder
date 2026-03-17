# AI 세션 메모리 관리 워크플로우

> AI 코딩 에이전트 세션 간 컨텍스트를 유지하고 지식을 축적하는 메모리 관리 전략 — CLAUDE.md, 핸드오프 문서, 세션 설계

## 개요

Claude Code나 Cursor Agent로 작업하다 보면 매번 같은 설명을 반복하는 자신을 발견해요. "이 프로젝트는 모노레포고, 백엔드는 Go, 프론트는 Next.js이고..." — 세션이 바뀔 때마다 처음부터 다시. 토큰도 낭비되고, 집중력도 끊겨요.

이 워크플로우는 **세션 간 컨텍스트를 체계적으로 관리**해서, AI 에이전트가 매번 "초면"이 아니라 "이어서 작업"하는 환경을 만들어요.

## 사전 준비

- Claude Code 또는 Cursor 설치
- Git 레포 (로컬)
- 기본적인 Markdown 편집 능력

## 메모리 계층 구조

AI 에이전트의 메모리를 세 계층으로 나눠서 관리해요.

| 계층 | 파일 | 수명 | 용도 |
|------|------|------|------|
| L1: 프로젝트 메모리 | `CLAUDE.md` | 영구 | 프로젝트 규칙, 컨벤션, 아키텍처 |
| L2: 작업 메모리 | `HANDOFF.md` | 태스크 단위 | 현재 진행 상황, 다음 단계 |
| L3: 참조 메모리 | `.claude/docs/` | 필요시 | 상세 스펙, API 문서, 예제 |

## 설정

### Step 1: 프로젝트 메모리 (CLAUDE.md) 설계

프로젝트 루트에 `CLAUDE.md`를 만들어요. 핵심은 **매 세션 시작 시 자동 로드되는 정보**만 넣는 거예요.

```markdown
# CLAUDE.md

## 프로젝트 개요
- 모노레포: apps/ (프론트) + packages/ (공유) + services/ (백엔드)
- 프론트: Next.js 15 + TypeScript
- 백엔드: Go 1.22 + Echo
- DB: PostgreSQL 16 + Redis

## 코딩 컨벤션
- 커밋: conventional commits (feat/fix/chore)
- 테스트: 새 기능은 반드시 테스트 포함
- 타입: any 사용 금지, unknown 사용

## 자주 쓰는 명령어
- `pnpm dev` — 프론트 개발 서버
- `make run` — 백엔드 실행
- `pnpm test` — 전체 테스트
```

**주의할 점:**
- 전체 API 스펙을 넣지 마세요. 매 턴마다 토큰을 소비해요
- 활성화된 규칙만 유지하고, 완료된 항목은 아카이브해요
- 200줄 이내로 유지하는 게 좋아요

### Step 2: 작업 메모리 (HANDOFF.md) 활용

긴 작업을 여러 세션에 걸쳐 할 때, 세션 종료 전에 핸드오프 문서를 만들어요.

```markdown
# HANDOFF.md

## 현재 작업
인증 모듈 리팩토링 (3/5 단계 완료)

## 완료된 것
- [x] JWT 토큰 검증 로직 분리 (services/auth/jwt.go)
- [x] 미들웨어에서 직접 검증하던 코드 제거
- [x] 단위 테스트 추가 (coverage 82%)

## 다음 단계
- [ ] 리프레시 토큰 로테이션 구현
- [ ] 세션 관리 테이블 마이그레이션
  - 스키마: migrations/004_sessions.sql (초안 있음)

## 주의사항
- auth/middleware.go의 L45-60은 아직 이전 로직. 리프레시 구현 후 교체
- Redis 세션 스토어는 packages/cache를 사용할 것 (직접 연결 X)

## 관련 파일
- services/auth/jwt.go (신규)
- services/auth/jwt_test.go (신규)
- internal/middleware/auth.go (수정 중)
```

세션을 시작할 때 이렇게 지시해요:

```
HANDOFF.md를 읽고, 이전 세션에서 멈춘 지점부터 이어서 작업해줘.
```

### Step 3: 참조 메모리 디렉토리 구성

자주 참조하지만 매번 로드할 필요 없는 문서를 `.claude/docs/`에 정리해요.

```
.claude/
├── docs/
│   ├── api-spec.md          # API 엔드포인트 명세
│   ├── db-schema.md         # DB 스키마 문서
│   ├── deployment-guide.md  # 배포 절차
│   └── style-guide.md       # 코드 스타일 가이드
└── commands/
    ├── review.md            # 코드 리뷰 커맨드
    └── test.md              # 테스트 생성 커맨드
```

CLAUDE.md에서 이 파일들을 참조만 해두면, 필요할 때 에이전트가 알아서 읽어요:

```markdown
## 참조 문서
- API 명세: `.claude/docs/api-spec.md`
- DB 스키마: `.claude/docs/db-schema.md`
```

## 사용 방법

### 일반 작업 세션 흐름

```
1. 세션 시작
   └─ CLAUDE.md 자동 로드 (프로젝트 컨텍스트)
   └─ HANDOFF.md 확인 (이전 작업 이어받기)

2. 작업 진행
   └─ 필요시 .claude/docs/ 참조
   └─ 코드 변경 + 테스트

3. 세션 종료 전
   └─ HANDOFF.md 업데이트
   └─ CLAUDE.md에 새 컨벤션 추가 (발견한 게 있으면)
```

### 세션 핸드오프 자동화

매번 수동으로 HANDOFF.md를 쓰기 귀찮다면, Claude Code 커맨드로 자동화할 수 있어요.

`.claude/commands/handoff.md`:

```markdown
현재 세션에서 작업한 내용을 분석해서 HANDOFF.md를 업데이트해줘.

포함할 내용:
1. 이번 세션에서 완료한 작업 (변경된 파일 기준)
2. 아직 완료되지 않은 작업
3. 다음 세션에서 주의할 점
4. 관련 파일 목록

기존 HANDOFF.md가 있으면 업데이트하고, 없으면 새로 만들어.
```

이제 세션 끝날 때 `/project:handoff`만 실행하면 돼요.

### 장기 프로젝트 지식 축적

프로젝트가 커지면서 쌓이는 패턴을 CLAUDE.md에 점진적으로 추가해요.

```markdown
## 학습된 패턴

### 2026-03-15: Redis 연결 풀 이슈
- 문제: 동시 접속 100 이상에서 커넥션 풀 고갈
- 해결: MaxIdleConns=50, MaxActiveConns=200 설정
- 파일: config/redis.go

### 2026-03-10: Next.js 빌드 캐시
- 문제: turbopack 캐시가 간헐적으로 깨짐
- 해결: .next/cache 삭제 후 재빌드
- 명령어: pnpm clean && pnpm build
```

이렇게 쌓인 패턴은 **같은 실수를 반복하지 않게** 해줘요.

## 메모리 관리 모범 사례

| 상황 | 권장 방식 |
|------|----------|
| 새 프로젝트 시작 | CLAUDE.md부터 작성 — 아키텍처, 컨벤션, 명령어 |
| 1시간 이상 작업 | 30분마다 HANDOFF.md에 진행 상황 기록 |
| 복잡한 디버깅 | 해결 후 "학습된 패턴"에 추가 |
| 팀원에게 넘기기 | HANDOFF.md + 구두 설명 대신 문서 공유 |
| 컨텍스트 창 부족 | CLAUDE.md에서 비활성 항목 .claude/docs/로 이동 |
| 주기적 정리 | 주 1회 CLAUDE.md 리뷰 — 오래된 항목 아카이브 |

## 컨텍스트 예산 관리

AI 에이전트의 컨텍스트 창은 유한해요. 어디에 토큰을 쓸지 의식적으로 결정하세요.

```
컨텍스트 예산 배분 (예시: 200K 토큰)
├── CLAUDE.md (자동 로드)     ~2K (1%)
├── 현재 작업 파일            ~30K (15%)
├── 대화 히스토리             ~100K (50%)
├── 도구 실행 결과            ~50K (25%)
└── 여유분                    ~18K (9%)
```

**절약 팁:**
- `CLAUDE.md`에 전체 스펙을 넣지 마세요. "이 파일을 읽어"라는 포인터만 넣으세요
- 긴 에러 로그는 관련 부분만 붙여넣으세요
- 이전 대화가 길어지면 `/compact`로 압축하세요
- 한 세션에서 너무 많은 작업을 하지 마세요. 2~3개 태스크가 적당해요

## 문제 해결

| 문제 | 해결 |
|------|------|
| 에이전트가 CLAUDE.md 규칙을 무시 | 규칙을 상단으로 이동, "반드시" "항상" 키워드 추가 |
| HANDOFF.md가 너무 길어짐 | 완료된 항목은 별도 로그로 이동, 현재 상태만 유지 |
| 매번 같은 질문을 함 | FAQ 형태로 CLAUDE.md에 추가 |
| 컨텍스트 창 초과 | 참조 문서를 .claude/docs/로 분리, CLAUDE.md 경량화 |
| 세션 간 충돌 | 두 세션이 같은 파일을 수정하지 않도록 HANDOFF.md에 "작업 영역" 명시 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
