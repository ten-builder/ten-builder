# 플레이북 53: Claude Code Max 플랜 200% 활용 가이드

> 월 $100~$200로 API 대비 93% 비용 절감 — Max 플랜을 제대로 쓰는 법

## 소요 시간

20-30분 (초기 설정 기준)

## 사전 준비

- Claude Pro 또는 Max 구독 계정
- Claude Code 설치 완료
- 현재 사용 패턴 파악 (일일 코딩 시간, 토큰 소비량)

---

## Max 플랜 2종 비교

| 플랜 | 가격 | 토큰 한도 (5시간) | 적합한 대상 |
|------|------|-------------------|-------------|
| Max 5x | $100/월 | ~88,000 토큰 | Pro 한도를 자주 초과하는 개발자 |
| Max 20x | $200/월 | ~220,000 토큰 | Claude Code를 주 개발 환경으로 쓰는 개발자 |

**API 비용 대비:** Max 20x 기준 개인 사용자 기준 최대 93% 절감 가능.

---

## Step 1: 플랜 선택 — 나는 어떤 유형인가?

**Pro로 충분한 경우:**

- 하루 1~2시간 가볍게 사용
- 주로 간단한 질문, 짧은 코드 수정
- 한도 초과 메시지를 거의 경험하지 않음

**Max 5x가 맞는 경우:**

- Pro 한도를 주 3회 이상 초과
- 멀티 파일 리팩토링, 테스트 작성이 주요 작업
- 중간 규모 코드베이스(~100K LOC) 작업

**Max 20x가 맞는 경우:**

```
- 하루 4시간 이상 Claude Code 사용
- Opus 모델로 복잡한 아키텍처 설계
- 여러 레포 동시 작업 또는 멀티 에이전트 운영
- 장시간 autonomous 세션 실행
```

> **핵심 판단 기준:** `/usage` 명령어로 최근 7일 평균 토큰 소비량 확인 후 결정.

---

## Step 2: CLAUDE.md 설정 — 토큰 낭비 방지

Max 플랜이라도 토큰을 효율적으로 쓰는 설정이 중요해요. 프로젝트 루트에 `CLAUDE.md`를 만드세요.

```markdown
# 프로젝트 컨텍스트

## 기술 스택
- Frontend: Next.js 15, TypeScript, Tailwind
- Backend: Node.js, Prisma, PostgreSQL
- 배포: Vercel + Supabase

## 코딩 규칙
- 함수는 단일 책임 원칙 준수
- 타입 추론 가능하면 명시적 타입 생략
- 테스트는 Vitest + Testing Library 사용

## 금지 사항
- any 타입 사용 금지
- console.log 프로덕션 코드에 포함 금지
- 무한 루프 가능성 있는 패턴 경고 요청

## 응답 형식
- 코드 변경 시 변경 이유 1줄 설명 후 코드 제시
- 불필요한 부연 설명 생략
```

**`.claudeignore` 설정:**

```
node_modules/
.next/
dist/
*.log
coverage/
.env*
```

이 두 파일만 잘 설정해도 토큰 사용량 30~40% 감소해요.

---

## Step 3: 컨텍스트 관리 — `/compact`와 `/clear` 언제 쓰나

Max 플랜 한도를 효율적으로 쓰려면 컨텍스트 관리가 필수예요.

| 명령어 | 언제 쓰나 | 효과 |
|--------|----------|------|
| `/compact` | 같은 작업 계속, 컨텍스트가 길어졌을 때 | 이전 대화 요약 유지, 노이즈 제거 |
| `/clear` | 전혀 다른 작업으로 전환할 때 | 완전 초기화 |
| 탭 분리 | 동시에 다른 파일 작업 시 | 컨텍스트 격리 |

**실전 패턴:**

```
[오전] 인증 모듈 작업 → /compact (점심 후 재개)
[오후] 결제 시스템으로 전환 → /clear (완전 분리)
[저녁] 배포 설정 작업 → 새 탭 열기
```

---

## Step 4: 에이전트 팀 구성 — 병렬 작업으로 속도 2~3배

Max 플랜 사용자의 최대 강점은 멀티 에이전트 운영이에요.

**팀 구조 예시 (API 피처 개발):**

```
리드 에이전트 (오케스트레이터)
├── 에이전트 A: API 엔드포인트 구현
├── 에이전트 B: 테스트 작성
└── 에이전트 C: 문서화
```

**실제 설정 방법:**

```bash
# Git Worktree로 격리된 작업 환경 생성
git worktree add ../feature-auth auth/user-management
git worktree add ../feature-test test/auth-tests

# 각 디렉토리에서 별도 Claude Code 세션 실행
cd ../feature-auth && claude  # 에이전트 A
cd ../feature-test && claude  # 에이전트 B
```

**에이전트 간 공유 파일:**

```markdown
# tasks.md (공유 작업 목록)

## 에이전트 A 담당
- [x] POST /api/auth/login
- [ ] POST /api/auth/refresh
- [ ] DELETE /api/auth/logout

## 에이전트 B 담당
- [ ] login 엔드포인트 단위 테스트
- [ ] refresh 토큰 만료 시나리오 테스트

## 완료 시 에이전트 A에게 알림 필요
```

---

## Step 5: Hooks 설정 — 반복 작업 자동화

Max 플랜 사용자라면 Hooks 설정으로 시간을 더 절약할 수 있어요.

**`.claude/settings.json` 기본 설정:**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|Create",
        "hooks": [
          {
            "type": "command",
            "command": "npm run lint --fix --silent 2>/dev/null || true"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "npm test --silent 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

**효과:** 코드 수정할 때마다 자동 린트, 세션 종료 시 자동 테스트 실행.

---

## Step 6: Plan Mode로 시작 — 효율 최대화

복잡한 작업을 시작할 때 Shift+Tab으로 Plan Mode를 활성화하세요.

```
Plan Mode 활성화 → Claude가 전체 계획 수립 → 승인 후 실행
```

**언제 유용한가:**

- 새 기능 추가 (파일 여러 개 수정 예상)
- 리팩토링 범위 파악
- 버그 원인 분석 전

**Plan Mode 없이 바로 시작하면 좋은 경우:**

- 파일 1~2개의 간단한 수정
- 명확한 단일 함수 구현
- 빠른 질문이나 설명 요청

---

## Step 7: `/usage` 모니터링 — 한도 전 알림 설정

```bash
# 현재 사용량 확인
/usage

# 출력 예시
# 현재 세션: 45,200 토큰 (한도의 51%)
# 5시간 윈도우 리셋: 2시간 15분 후
```

**한도 관리 전략:**

| 사용량 | 조치 |
|--------|------|
| 0~60% | 정상 작업 |
| 60~80% | `/compact`으로 정리 |
| 80%+ | 새 탭 열어서 작업 분산 |
| 90%+ | 리셋까지 가벼운 작업만 |

---

## 체크리스트

- [ ] `/usage`로 현재 소비 패턴 파악, 플랜 선택 완료
- [ ] `CLAUDE.md` 프로젝트별 설정 완료
- [ ] `.claudeignore`로 불필요한 파일 제외
- [ ] `.claude/settings.json` Hooks 설정
- [ ] Git Worktree 병렬 작업 환경 테스트
- [ ] `/compact` 습관화 — 장시간 세션 시 정기 실행

---

## 다음 단계

→ [플레이북 49: Claude Code 비동기 백그라운드 에이전트 운영](./49-async-background-agent-operations.md)

→ [플레이북 41: 멀티 파일 동시 편집](./41-multi-file-coherent-editing.md)

→ [치트시트: AI 코딩 에이전트 비용 최적화](../../cheatsheets/ai-coding-cost-optimization-cheatsheet.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
