# Codex CLI /goal 모드 실전 가이드 2026 — 자율 에이전트로 장시간 작업 완전 자동화하기

> `/goal` 하나로 Codex가 18시간 동안 혼자 기능 14개를 구현한 사례 — 목표 기반 자율 실행의 모든 것

## 소요 시간

30분 (설정 + 첫 목표 실행)

## 사전 준비

- Codex CLI v0.128.0 이상 설치
- ChatGPT Pro, Team, Enterprise, Plus 구독 (Goal 모드 필수 조건)
- 작업 대상 Git 레포지토리

---

## /goal 모드란?

Codex CLI v0.128.0(2026년 5월 출시)에 추가된 `/goal` 명령어는 단순한 태스크 실행을 넘어 **장기 목표 기반 자율 에이전트**로 Codex를 전환합니다.

기존 방식과의 차이:

| 방식 | 특징 |
|------|------|
| 기존 프롬프트 | 한 번 지시 → 결과 확인 → 다음 지시 (사람 개입 필수) |
| /goal 모드 | 목표 설정 → Plan→Act→Test→Review 루프 자동 반복 → 완료 시 종료 |

핵심은 **검증 가능한 종료 조건**입니다. "모든 테스트 통과"처럼 객관적으로 측정 가능한 목표를 주면 Codex가 스스로 달성 여부를 판단하며 작업합니다.

---

## Step 1: Codex CLI 설치 및 버전 확인

```bash
# 최신 버전 설치
npm install -g @openai/codex

# 버전 확인 (0.128.0 이상)
codex --version
```

ChatGPT 구독 계정으로 인증:

```bash
codex auth
# 브라우저 OAuth 흐름으로 자동 로그인
```

---

## Step 2: 첫 /goal 설정하기

프로젝트 디렉토리에서 Codex를 실행하세요.

```bash
cd ~/projects/my-project
codex
```

TUI가 열리면 `/goal` 명령어로 목표를 설정합니다.

```
/goal Pydantic v1에서 v2로 전체 마이그레이션하고 모든 테스트가 통과되도록 수정한다. src/ 디렉토리만 수정하고 tests/는 건드리지 않는다.
```

### 좋은 목표 작성 원칙

| 원칙 | 나쁜 예 | 좋은 예 |
|------|---------|---------|
| 검증 가능한 조건 | "코드를 깔끔하게 만들어" | "모든 lint 오류를 제거하고 테스트 커버리지 80% 이상 달성" |
| 명확한 범위 | "프로젝트 개선" | "src/api/ 내 함수만 수정, 외부 인터페이스 유지" |
| 실패 조건 포함 | (없음) | "동일 단계에서 3번 이상 실패하면 중단" |

---

## Step 3: 자율 실행 중 상태 확인

Codex는 목표를 `brief.md`, `goals.json`, `ledger.jsonl` 파일로 레포에 저장합니다.

```bash
# 현재 목표 상태 확인
/goal

# 출력 예시:
# Goal: Pydantic v2 migration
# Status: in_progress
# Steps: 12/18 완료
# Budget: 34,200 / 50,000 토큰 사용
```

터미널을 닫아도 작업이 계속되며, 나중에 다시 열면 자동으로 재개됩니다.

---

## Step 4: Budget Awareness — 예산 관리

토큰 한도 도달 시 Codex는 급하게 종료하는 대신 **Soft Stop**을 실행합니다.

```
Budget limited: 현재까지 진행 상황을 저장하고 다음 실행에서 재개할 준비 완료.
완료된 단계: 11/18
남은 단계: goals.json에 저장됨
```

다음에 Codex를 켜면:

```bash
codex
# Codex: 이전 목표를 감지했습니다. 재개하려면 /goal resume
/goal resume
```

---

## Step 5: 실전 활용 사례

### 대규모 리팩토링

```
/goal 전체 코드베이스에서 콜백 패턴을 async/await로 변환. 변환 후 각 파일의 기존 테스트가 모두 통과해야 한다.
```

### 테스트 커버리지 향상

```
/goal src/ 내 모든 함수에 대해 단위 테스트를 추가하여 커버리지를 현재 45%에서 80% 이상으로 올린다.
```

### 의존성 마이그레이션

```
/goal Express.js 4에서 Fastify 5로 전환. API 응답 구조와 에러 포맷은 기존과 동일하게 유지.
```

### 문서 자동화

```
/goal 모든 public 함수에 JSDoc 주석 추가. TypeScript 타입과 일치하는 @param, @returns 필수.
```

---

## Step 6: MCP 서버 연동으로 확장

Codex /goal 모드는 MCP 서버와 함께 사용하면 더 강력해집니다.

```bash
# .codex/config.json
{
  "mcpServers": {
    "database": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRESQL_CONNECTION_STRING": "..."
      }
    }
  }
}
```

이렇게 설정하면 `/goal`이 데이터베이스 스키마를 직접 조회하며 마이그레이션 코드를 생성할 수 있습니다.

---

## Step 7: Skills 파일로 반복 목표 자동화

자주 사용하는 목표 패턴은 `SKILL.md`로 저장할 수 있습니다.

```markdown
# SKILL.md — 코드 품질 검사

## 트리거
코드 리뷰, PR 준비, 품질 검사

## 실행
1. ESLint + Prettier 오류 전부 수정
2. 테스트 커버리지 현재 대비 유지 또는 향상
3. 타입 오류 제거
4. 완료 조건: 모든 CI 검사 통과
```

저장 후 Codex가 관련 태스크를 감지하면 자동으로 이 스킬을 로드합니다.

---

## 문제 해결

| 문제 | 해결 |
|------|------|
| "Goal requires subscription" | ChatGPT Pro/Team/Enterprise/Plus 로그인 필요, API 키만으로는 불가 |
| 목표가 루프에 빠짐 | `/goal clear` → 더 구체적인 실패 조건 포함해 재설정 |
| 예상과 다른 파일 수정 | 목표에 "수정 범위: src/만, tests/는 읽기 전용" 명시 |
| 재개 후 컨텍스트 누락 | `goals.json`을 직접 열어 이전 단계 결과 확인 후 `/goal resume` |

---

## /goal vs Claude Code Tasks 비교

| 항목 | Codex /goal | Claude Code Tasks |
|------|-------------|-------------------|
| 영속성 | 파일 기반 (레포에 저장) | 세션 기반 (로컬 상태) |
| 모델 | GPT-5.5 기본 | Claude Sonnet/Opus 선택 |
| 인증 | ChatGPT 구독 필수 | Anthropic API 또는 구독 |
| 재개 방식 | 자동 감지 + /goal resume | /resume 커맨드 |
| MCP 지원 | 지원 | 지원 |
| 비용 투명성 | 토큰 예산 실시간 표시 | /usage 명령어 |

---

## 체크리스트

- [ ] Codex CLI v0.128.0 이상 설치
- [ ] ChatGPT Pro/Team/Enterprise 계정으로 인증
- [ ] 검증 가능한 종료 조건이 포함된 목표 작성
- [ ] 수정 범위(디렉토리/파일) 명시
- [ ] 실패 조건 및 예산 제한 설정
- [ ] 실행 중 `/goal` 명령어로 주기적 상태 확인
- [ ] 필요 시 MCP 서버 연동으로 컨텍스트 확장

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
