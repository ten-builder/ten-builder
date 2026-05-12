# EP22: Claude Code로 팀 온보딩 30분 만에 끝내기

> /team-onboarding, /powerup, AGENTS.md를 조합해 신규 팀원 3명을 동시에 온보딩하는 실전 라이브 코딩

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

---

## 이 에피소드에서 다루는 것

- `/team-onboarding` 커맨드로 팀 맞춤 온보딩 가이드를 자동 생성하는 방법
- `/powerup` 대화형 레슨으로 신규 팀원이 Claude Code 핵심 기능을 20분 내 파악하는 흐름
- AGENTS.md + CLAUDE.md 조합으로 팀 규칙과 프로젝트 컨텍스트를 에이전트에게 한 번에 전달하는 패턴
- 신규 팀원 3명이 각자 독립 환경에서 첫 태스크를 동시에 완료하는 병렬 온보딩 워크플로우
- 온보딩 결과를 PR로 검토하고 팀 설정을 지속적으로 개선하는 피드백 루프

---

## 스택

| 항목 | 내용 |
|------|------|
| AI 도구 | Claude Code (v2.1.132+) |
| 핵심 커맨드 | `/team-onboarding`, `/powerup`, `/plan` |
| 설정 파일 | CLAUDE.md, AGENTS.md |
| Git 전략 | Git Worktree (팀원별 독립 브랜치) |
| 언어 | TypeScript + Node.js (예제 프로젝트) |

---

## 배경: 왜 AI 온보딩이 필요한가

신규 팀원이 합류하면 보통 이런 일이 생겨요.

| 문제 | 기존 방식 | AI 온보딩 이후 |
|------|----------|--------------|
| 코드베이스 파악 | 시니어가 직접 설명 (2~3시간) | Claude Code가 레포 분석 후 요약 (10분) |
| 개발 환경 구성 | README 보며 직접 설치 (1~2시간) | `/team-onboarding` 가이드 따라 자동 설정 |
| 팀 컨벤션 습득 | 코드 리뷰에서 지적받으며 학습 | CLAUDE.md로 사전 주입, 첫 커밋부터 일관성 유지 |
| 첫 태스크 완료 | 평균 3~5일 | 당일 PR 생성 가능 |

---

## /team-onboarding 커맨드 동작 방식

`/team-onboarding`을 실행하면 Claude Code는 현재 레포를 분석해 신규 팀원을 위한 가이드를 자동 생성해요.

```
> /team-onboarding
```

생성되는 내용:

```markdown
# 팀 온보딩 가이드 — [프로젝트명]

## 1. 개발 환경 설정
[패키지 설치, 환경변수 설정, DB 초기화 명령어]

## 2. 프로젝트 구조
[주요 디렉토리와 역할 설명]

## 3. 팀 컨벤션
[브랜치 네이밍, 커밋 메시지, 코드 스타일]

## 4. 첫 번째 태스크
[Good First Issue 목록과 접근 방법]
```

생성된 가이드는 `ONBOARDING.md`로 저장되거나, 출력에서 바로 복사해서 팀 위키에 붙여넣을 수 있어요.

---

## /powerup 대화형 레슨 활용법

`/powerup`은 Claude Code를 막 시작한 팀원이 핵심 기능을 빠르게 익히도록 설계된 대화형 레슨이에요.

```
> /powerup
```

레슨 흐름:

```
1단계: Hooks 설명 + 실습 (5분)
   → pre-save, post-tool-use 훅 직접 설정해보기

2단계: Skills 소개 (5분)
   → SKILL.md로 재사용 가능한 작업 단위 만들기

3단계: MCP 서버 연결 (5분)
   → 팀 내부 도구를 MCP로 연결해 에이전트와 연동하기

4단계: 플러그인 설치 (5분)
   → 팀 공용 플러그인 설치 및 사용법
```

팀장 입장에서 `/powerup`은 "신규 팀원에게 Claude Code 사용법을 일일이 가르치는 시간"을 없애주는 도구예요.

---

## 타임라인

### Part 1 (0-10분): 온보딩 환경 준비

```
0min  → 예제 레포 클론 + 팀 설정 파일 확인
3min  → CLAUDE.md에 팀 컨벤션 + 금지 사항 정의
6min  → AGENTS.md에 에이전트 역할 분담 구조 작성
10min → /team-onboarding 실행 → 가이드 생성 확인
```

### Part 2 (10-25분): 신규 팀원 3명 동시 온보딩

```
10min → 팀원 A: /powerup 레슨 시작 (Hooks + Skills)
12min → 팀원 B: CLAUDE.md 기반 환경 구성 시작
14min → 팀원 C: Good First Issue 선택 + /plan 실행
20min → 팀원 A: 첫 Hook 작성 완료
22min → 팀원 B: 개발 환경 구성 완료 + 에이전트 첫 실행
24min → 팀원 C: 첫 번째 PR 브랜치 생성
```

### Part 3 (25-40분): 첫 PR + 팀 피드백

```
25min → 팀원 C: 구현 완료 + PR 생성
28min → 팀장: PR 리뷰 + CLAUDE.md 보완 포인트 확인
32min → CLAUDE.md 업데이트 → 팀원 A, B에도 자동 반영
35min → 팀원 A, B: 업데이트된 컨텍스트로 첫 태스크 시작
40min → 온보딩 피드백 정리 + ONBOARDING.md 최종 업데이트
```

---

## CLAUDE.md 팀 온보딩 설정 예시

온보딩 때 새 팀원에게 전달할 CLAUDE.md의 핵심 섹션이에요.

```markdown
# 프로젝트: [프로젝트명]

## 핵심 원칙
- 커밋 메시지: `feat:`, `fix:`, `chore:` 접두어 필수
- PR 단위: 기능 하나당 PR 하나 (500줄 이하 권장)
- 테스트: 새 기능은 반드시 단위 테스트 추가

## 디렉토리 구조
- `src/features/` — 기능별 모듈 (도메인 중심 설계)
- `src/shared/` — 공통 유틸, 타입, 상수
- `src/api/` — 외부 API 클라이언트

## 에이전트 금지 사항
- `prisma/migrations/` 폴더 직접 수정 금지
- 환경변수는 `.env.example`에만 추가 (`.env` 수정 금지)
- `main` 브랜치 직접 push 금지

## 이 레포의 AI 활용 패턴
- 새 기능 구현 전: `/plan`으로 접근 방식 협의
- 코드 리뷰 전: 에이전트가 스스로 리뷰 후 수정
- 테스트 작성: 에이전트에게 위임 가능 (단, 시나리오는 사람이 정의)
```

---

## AGENTS.md 팀 역할 분담 설정

```markdown
# AGENTS.md — [프로젝트명] 에이전트 운영 규칙

## 세션 시작 루틴
1. `CLAUDE.md` 읽기 (프로젝트 컨텍스트)
2. `memory/YYYY-MM-DD.md` 읽기 (오늘 작업 맥락)
3. 현재 브랜치 확인: `git branch --show-current`

## 역할별 에이전트 구성

### 구현 에이전트
- 담당: 기능 코드 작성, 리팩토링
- 금지: 직접 배포, DB 마이그레이션

### 리뷰 에이전트
- 담당: 코드 품질 검토, 보안 체크
- 실행 시점: PR 생성 직전

### 테스트 에이전트
- 담당: 단위/통합 테스트 작성 및 실행
- 목표 커버리지: 80% 이상

## 메모리 관리
- `memory/` 폴더에 일별 작업 로그 유지
- 중요한 설계 결정은 `DECISIONS.md`에 기록
```

---

## 팀원별 첫 태스크 접근법

신규 팀원이 Claude Code와 함께 첫 태스크를 처리하는 권장 순서예요.

```
Step 1: 레포 전체 파악
> 이 레포의 전체 구조를 분석하고 핵심 모듈 5개를 설명해줘.
  아키텍처 다이어그램도 텍스트로 그려줘.

Step 2: 태스크 계획
> [이슈 내용 붙여넣기]
> 이 이슈를 해결하려면 어떤 파일을 어떤 순서로 수정해야 해?
> 변경 영향 범위도 알려줘.

Step 3: 구현 + 검증
> 계획대로 구현해줘. 각 단계마다 테스트를 실행해서 확인해.
> 완료되면 변경 요약과 테스트 결과를 알려줘.

Step 4: PR 준비
> 변경사항을 요약해서 PR 제목과 본문 초안을 작성해줘.
> CLAUDE.md의 PR 규칙을 지켜서 작성해.
```

---

## 온보딩 품질 체크리스트

팀장이 신규 팀원 온보딩 완료를 확인하는 기준이에요.

```
개발 환경
- [ ] 로컬 서버 실행 확인 (`npm run dev`)
- [ ] 전체 테스트 통과 확인 (`npm test`)
- [ ] Claude Code 설치 + CLAUDE.md 로드 확인

팀 컨벤션 이해
- [ ] /powerup 레슨 완료 (Hooks + Skills + MCP)
- [ ] 첫 커밋 메시지가 팀 컨벤션을 따름
- [ ] PR 생성 후 리뷰 프로세스 경험

에이전트 활용
- [ ] /plan으로 태스크 계획 수립 경험
- [ ] 에이전트가 생성한 코드 검토 후 수정 경험
- [ ] memory/ 폴더에 첫 번째 일별 로그 작성
```

---

## 온보딩 피드백 → CLAUDE.md 개선 루프

온보딩 과정에서 신규 팀원이 막히는 지점은 CLAUDE.md가 불명확한 곳이에요.

```
온보딩 세션 종료 후:

1. 팀원에게 물어볼 것
   - "에이전트가 예상과 다르게 행동한 순간이 있었나요?"
   - "CLAUDE.md에서 이해가 안 됐던 부분이 있었나요?"

2. CLAUDE.md 업데이트
   - 불명확했던 규칙 → 예시 추가
   - 에이전트가 실수한 패턴 → 금지 사항으로 명시

3. 다음 온보딩에 적용
   - 업데이트된 CLAUDE.md를 레포에 커밋
   - 온보딩 가이드에도 변경사항 반영
```

이 루프를 3~4회 반복하면 CLAUDE.md가 팀의 암묵지를 담은 살아있는 문서가 돼요.

---

## 이 에피소드에서 얻어가는 것

- **온보딩 시간 단축**: 기존 3~5일 → 당일 첫 PR 생성 가능
- **일관성 확보**: CLAUDE.md 하나로 모든 팀원의 에이전트가 동일한 규칙 준수
- **팀장 부담 감소**: 반복적인 설명 없이 에이전트가 컨텍스트 전달
- **지속적 개선**: 온보딩마다 CLAUDE.md가 더 정교해지는 피드백 루프

---

## 더 알아보기

- [Claude Code Week 23 가이드](../../guides/90-claude-code-week23-features-guide.md) — /powerup, worktree.baseRef 설명
- [AI 에이전트 온보딩 자동화 플레이북](../../claude-code/playbooks/43-team-onboarding-automation.md)
- [AI 에이전트 팀 구성 가이드](../../guides/72-ai-coding-agent-team-composition-guide.md)
- [AGENTS.md 컨텍스트 파일 설계 치트시트](../../cheatsheets/agents-md-context-engineering-cheatsheet.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
