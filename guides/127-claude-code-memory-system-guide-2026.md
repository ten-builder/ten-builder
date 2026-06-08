# Claude Code 메모리 시스템 실전 가이드 2026

> 세션이 끝나도 기억하는 에이전트 — Auto Memory, MEMORY.md, 팀 메모리까지

## 왜 메모리가 중요한가

Claude Code는 기본적으로 무상태(stateless)다. 세션이 끝나면 어떤 라이브러리를 선택했는지, 어떤 컨벤션을 정했는지 기억하지 못한다.

2026년 상반기 기준으로 세 가지 메모리 레이어가 자리잡았다:

| 레이어 | 파일 | 범위 | 업데이트 |
|--------|------|------|----------|
| 프로젝트 규칙 | `CLAUDE.md` | 레포 전체 | 사람이 직접 작성 |
| 세션 학습 | `MEMORY.md` (auto-memory) | 프로젝트별 | 에이전트 자동 기록 |
| 글로벌 선호 | `~/.claude/CLAUDE.md` | 모든 프로젝트 | 사람이 직접 작성 |

각 레이어를 언제 어떻게 쓰는지 모르면 에이전트가 같은 질문을 반복하고, 이미 결정한 사항을 뒤집는다.

---

## Auto Memory(자동 메모리) 이해하기

### 어떻게 동작하는가

Claude Code는 세션 중 다음 유형의 정보를 자동으로 포착한다:

- 사용자가 명시적으로 선호한 패턴 ("이 방식으로 해줘")
- 에이전트가 실수한 후 수정된 사항
- 프로젝트에서 자주 참조한 파일 구조와 컨벤션
- 반복적으로 주어진 컨텍스트 (팀 코딩 스타일, 금지 패키지 등)

이 내용은 `~/.claude/projects/<project-hash>/memory/MEMORY.md`에 누적된다.

### 파일 구조 확인

```bash
# 현재 프로젝트의 메모리 파일 확인
ls ~/.claude/projects/

# 특정 프로젝트 메모리 보기
cat ~/.claude/projects/$(echo $PWD | md5sum | cut -d' ' -f1)/memory/MEMORY.md
```

> 첫 주에는 아무것도 하지 않아도 된다. Claude Code를 평소처럼 쓰면 자동으로 MEMORY.md가 쌓인다.

---

## CLAUDE.md — 프로젝트 규칙의 핵심

Auto Memory가 에이전트가 "학습한" 내용이라면, CLAUDE.md는 사람이 명시적으로 정한 규칙이다. 에이전트는 두 파일을 모두 읽고 시작한다.

### 기본 구조

```markdown
# 프로젝트 컨텍스트

## 스택
- Node.js 22, TypeScript strict mode
- PostgreSQL 16 (Prisma ORM)
- React 19, Next.js 15 App Router

## 코딩 컨벤션
- 함수명: camelCase
- 파일명: kebab-case
- 테스트: Vitest, 커버리지 80% 이상 유지

## 금지 패턴
- `any` 타입 사용 금지 (Zod로 대체)
- `console.log` 커밋 금지
- 직접 DB 쿼리 금지 (Prisma 사용)

## 작업 흐름
1. 기능 추가 전 반드시 스펙 파일 작성
2. PR 전 `pnpm lint && pnpm test` 통과 확인
3. 마이그레이션 파일은 수동 검토 후 적용
```

### 글로벌 CLAUDE.md (모든 프로젝트에 적용)

```bash
# 글로벌 설정 파일 위치
~/.claude/CLAUDE.md
```

```markdown
# 글로벌 설정

## 언어
- 코드 주석: 영어
- 커밋 메시지: 영어 (Conventional Commits)
- PR 본문: 영어

## 공통 선호
- 함수형 패턴 우선 (클래스보다 함수)
- 명시적 타입 선언 선호
- 에러 처리는 Result 패턴 또는 throwing

## 절대 하지 않는 것
- 라이센스 파일 수정 금지
- .env 파일 커밋 금지
- node_modules 관련 파일 수정 금지
```

---

## 메모리 4단계 셋업

### Step 1: Auto Memory 활성화 확인

```bash
# Claude Code 설정에서 auto-memory 상태 확인
claude config get auto-memory

# 활성화 (기본값은 off인 경우 있음)
claude config set auto-memory true
```

### Step 2: 프로젝트 CLAUDE.md 초안 작성

새 프로젝트를 시작할 때 Claude Code에게 CLAUDE.md 초안을 맡긴다:

```
프로젝트 구조와 package.json을 읽고 CLAUDE.md 초안을 작성해줘.
스택, 코딩 컨벤션, 금지 패턴, 자주 쓰는 명령어 섹션을 포함해.
```

초안을 검토하고 팀 특성에 맞게 수정한 뒤 커밋한다.

### Step 3: 메모리 파일 주기적 검토

```bash
# 누적된 메모리 확인
cat ~/.claude/projects/*/memory/MEMORY.md

# 오래된 항목 정리 (에이전트에게 요청)
claude "MEMORY.md를 검토하고 더 이상 유효하지 않은 항목을 제거해줘"
```

### Step 4: 팀 메모리 공유

개인 메모리는 프로젝트별로 저장되지만, 팀이 공유해야 하는 컨텍스트는 CLAUDE.md에 포함시킨다:

```markdown
# 팀 결정 사항 (CLAUDE.md에 추가)

## 2026-05-15 결정
- 인증 라이브러리: better-auth (기존 next-auth 제거)
- 상태 관리: Zustand (Redux 사용 금지)
- API 스타일: tRPC (REST 신규 엔드포인트 금지)
```

---

## 실전 패턴 3가지

### 패턴 1: 세션 시작 루틴

세션 시작 시 에이전트가 메모리를 확실히 읽도록 유도:

```
이전 메모리와 CLAUDE.md를 읽고, 현재 프로젝트 상태를 요약해줘.
그다음 [오늘 할 작업]을 시작하자.
```

### 패턴 2: 결정 사항 즉시 기록

중요한 결정을 내린 직후 메모리에 기록:

```
방금 결정한 내용(Prisma를 Drizzle로 교체하기로 함)을 
CLAUDE.md의 '팀 결정 사항' 섹션에 날짜와 함께 추가해줘.
```

### 패턴 3: 에러 패턴 학습

반복되는 실수를 메모리에 등록:

```
이 에러(CORS 설정 누락)가 자꾸 발생해.
앞으로 API 라우트를 만들 때 CORS 설정을 자동으로 포함하도록 
MEMORY.md에 기록해줘.
```

---

## MEMORY.md vs CLAUDE.md 구분 기준

| 항목 | CLAUDE.md | MEMORY.md |
|------|-----------|-----------|
| 팀 전체 규칙 | ✅ | ❌ |
| 개인 작업 패턴 | ❌ | ✅ |
| 기술 스택 결정 | ✅ | ✅ |
| 일시적 작업 메모 | ❌ | ✅ |
| Git으로 관리 | ✅ (커밋) | ❌ (로컬) |
| 팀원과 공유 | ✅ | ❌ |

---

## 메모리 초기화 및 리셋

프로젝트가 크게 변경되거나 메모리 내용이 오래된 경우:

```bash
# 특정 프로젝트 메모리 초기화
rm ~/.claude/projects/<project-hash>/memory/MEMORY.md

# 에이전트에게 직접 요청
claude "MEMORY.md를 초기화하고 현재 CLAUDE.md 기반으로 새로 작성해줘"
```

---

## 문제 해결

| 증상 | 원인 | 해결 |
|------|------|------|
| 에이전트가 이전 결정을 무시함 | MEMORY.md가 너무 길거나 충돌 | MEMORY.md 정리, CLAUDE.md에 명시적 규칙 추가 |
| 매 세션마다 같은 질문 반복 | auto-memory 비활성화 | `claude config set auto-memory true` |
| 팀원 간 다른 컨텍스트 | CLAUDE.md가 최신 결정 미반영 | CLAUDE.md에 팀 결정 추가 후 커밋 |
| 프로젝트 컨텍스트 오염 | 글로벌 CLAUDE.md가 너무 많은 규칙 포함 | 글로벌 ↔ 프로젝트별 CLAUDE.md 역할 분리 |

---

## 체크리스트

- [ ] `claude config set auto-memory true` 확인
- [ ] 프로젝트 루트에 `CLAUDE.md` 생성
- [ ] `~/.claude/CLAUDE.md` 글로벌 설정 작성
- [ ] 주 1회 `MEMORY.md` 검토 및 정리
- [ ] 중요한 팀 결정 시 즉시 `CLAUDE.md` 업데이트

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
