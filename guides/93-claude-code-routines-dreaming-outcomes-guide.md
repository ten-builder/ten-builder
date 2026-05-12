# Claude Code Routines + Dreaming + Outcomes 실전 가이드 2026

> 반복 업무를 코드 없이 자동화하고, 에이전트가 스스로 발전하게 만드는 세 가지 핵심 기능 완전 분석

## 이 가이드에서 다루는 것

- **Routines**: 스케줄/이벤트 기반으로 Claude Code 태스크를 클라우드에서 자동 실행
- **Dreaming**: 에이전트가 과거 세션을 복습하며 장기 메모리를 스스로 갱신하는 자기 개선 루프
- **Outcomes**: 태스크 성공 기준을 정의하면 별도 검증 에이전트가 품질을 자동 평가하는 QA 레이어

세 기능은 각각 독립적으로 쓸 수 있지만, 함께 조합하면 "정의 → 자동 실행 → 자기 검증 → 자기 개선" 흐름을 완성할 수 있어요.

---

## Part 1: Routines — 에이전트를 클라우드에서 자동 실행하기

### Routines란?

Routine은 프롬프트 + 실행 시점 + 출력 대상으로 구성된 자동화 단위입니다. 정의해두면 로컬 맥북이 꺼져 있어도 Anthropic 클라우드에서 계속 실행돼요.

| 구성 요소 | 설명 |
|----------|------|
| **프롬프트** | 무엇을 할지 자연어로 정의 |
| **스케줄 / 트리거** | 언제 실행할지 (시간/이벤트/API) |
| **출력 대상** | 결과를 어디로 보낼지 (대화, 슬랙, 이메일 등) |
| **컨텍스트** | 연결할 GitHub 레포, MCP 커넥터 목록 |

### 트리거 유형 3가지

#### 1. 스케줄 트리거 (Scheduled)

```bash
# CLI로 루틴 생성 예시
claude routines create \
  --name "daily-standup-summary" \
  --schedule "0 9 * * 1-5" \
  --prompt "GitHub에서 어제 머지된 PR과 열린 이슈를 요약해서 Slack #dev-daily에 보내줘"
```

| 패턴 | 용도 |
|------|------|
| 매일 오전 9시 | 일일 스탠드업 요약 |
| 매주 월요일 | 주간 기술 부채 체크 |
| 매 2시간 | 의존성 취약점 스캔 |
| 매월 1일 | 월간 코드 품질 리포트 |

#### 2. API 트리거 (On-demand)

각 루틴은 전용 HTTP 엔드포인트를 갖습니다.

```bash
curl -X POST https://api.claude.com/v1/routines/{routine-id}/run \
  -H "Authorization: Bearer $ROUTINE_TOKEN" \
  -d '{"context": "PR #234 리뷰 요청"}'
```

외부 시스템(Jira, Zapier, CI/CD)에서 Claude 태스크를 직접 호출할 때 유용해요.

#### 3. GitHub 웹훅 트리거 (Event-driven)

```yaml
# .claude/routines.yaml
routines:
  - name: pr-auto-review
    trigger:
      type: github_webhook
      event: pull_request.opened
    prompt: |
      새로 열린 PR을 리뷰하세요.
      보안 취약점, 테스트 누락, 타입 오류를 중심으로 확인하고
      인라인 코멘트를 남겨주세요.
    output:
      type: github_comment
```

### 실전 루틴 예시

#### 야간 이슈 트리아지

```
매일 자정, 열린 이슈를 분석해서:
1. 버그인지 기능 요청인지 분류
2. 심각도(critical/high/medium/low) 태그 추가
3. 담당자 추천 (커밋 히스토리 기반)
4. Slack #triage 채널에 요약 전송
```

#### 주간 문서 드리프트 탐지

```
매주 금요일 오후 5시, 지난 주 변경된 코드와 README/docs를 비교해서:
- 문서에 반영 안 된 API 변경 목록 추출
- 업데이트가 필요한 파일별로 PR 초안 생성
```

#### PR 머지 후 릴리스 노트 생성

```yaml
trigger:
  type: github_webhook
  event: pull_request.merged
  branch: main
prompt: |
  이번 변경사항을 CHANGELOG.md에 추가하고
  PR을 생성해주세요. conventional commits 형식 기준.
output:
  type: github_pr
```

---

## Part 2: Dreaming — 에이전트가 스스로 나아지는 방법

### Dreaming이란?

에이전트가 과거 세션들을 복습하면서 패턴과 실수를 추출하고 메모리를 업데이트하는 과정입니다. 사람으로 치면 "주간 회고"에 해당해요.

```
세션 A: 타입 오류로 3번 수정 반복
세션 B: 같은 패턴의 타입 오류 발생
세션 C: ──────────────────────────
                    ↓ Dreaming
[메모리 업데이트] TypeScript strict 모드에서 null 처리 시
                  optional chaining (?.) 우선 사용할 것
```

### 작동 방식

```
1. 비활성 시간에 자동 실행 (기본: 세션 없는 새벽)
2. 최근 N개 세션 로그 분석
3. 반복 패턴 / 자주 수정된 부분 추출
4. 메모리 업데이트 초안 생성
5. 개발자 검토 큐에 추가 (자동 적용 전)
```

### 메모리 레이어 구조

| 레이어 | 범위 | 업데이트 주체 |
|--------|------|--------------|
| **프로젝트 메모리** | 특정 레포 | Dreaming + 수동 |
| **팀 메모리** | 조직 전체 | 관리자 승인 필요 |
| **개인 메모리** | 개인 세션 | Dreaming 자동 |

### 개발자가 할 일

```bash
# 보류 중인 메모리 업데이트 확인
claude memory review

# 출력 예시:
# [PENDING] 프로젝트: ten-builder-api
# 패턴: Prisma 쿼리 시 select 없이 findMany 사용 → N+1 위험
# 제안: findMany 사용 시 반드시 select 또는 include 명시 추가
# [승인] y  [수정] e  [거절] n
```

메모리 업데이트를 수동으로 추가할 수도 있어요.

```bash
# 수동 메모리 추가
claude memory add "API 응답은 항상 camelCase로 반환, DB 필드는 snake_case"

# 프로젝트 메모리 조회
claude memory list --project ./
```

### Dreaming 활용 팁

- **코드 리뷰 피드백을 메모리에 반영**: PR 코멘트를 Dreaming이 학습하도록 연결하면, 같은 실수가 반복되지 않아요
- **팀 컨벤션 자동 학습**: 팀원들의 수정 패턴이 쌓이면 Dreaming이 팀 스타일을 파악해요
- **민감 정보 주의**: 메모리에 API 키나 개인정보가 들어가지 않도록 `memory.deny_patterns` 설정을 활용하세요

---

## Part 3: Outcomes — 성공 기준을 정의하면 에이전트가 자기검증

### Outcomes란?

태스크의 성공 기준(rubric)을 정의하면 별도 검증 에이전트(grader)가 독립적으로 결과를 평가하는 QA 레이어입니다.

```
개발자: "React 컴포넌트 리팩토링해줘"
        + Outcome 정의: 타입 오류 0건, 테스트 커버리지 80% 이상

구현 에이전트 → 코드 생성
검증 에이전트 → rubric 기준으로 독립 평가
    ↓ 기준 미달
구현 에이전트 → 재시도 (최대 N회)
```

### Outcome 설정 방법

#### 간단한 방식 (인라인)

```bash
claude "이 함수에 유닛 테스트 추가해줘" \
  --outcome "테스트 커버리지 90% 이상, 엣지 케이스 3개 이상 포함"
```

#### 파일로 정의

```yaml
# .claude/outcomes/test-quality.yaml
name: test-quality-check
rubric:
  - criterion: "커버리지 90% 이상"
    weight: high
    check: "nyc report shows >= 90%"
  - criterion: "엣지 케이스 포함"
    weight: medium
    check: "describe('edge cases') 블록 존재"
  - criterion: "비동기 테스트 처리"
    weight: medium
    check: "async/await 또는 done 콜백 사용"
max_retries: 3
on_failure: escalate_to_human
```

```bash
claude "API 엔드포인트 테스트 추가" --outcome-file .claude/outcomes/test-quality.yaml
```

### Outcomes가 효과적인 상황

| 상황 | rubric 예시 |
|------|------------|
| **코드 리뷰 자동화** | "보안 취약점 0건, 타입 오류 0건" |
| **문서 생성** | "예제 코드 포함, 500자 이상, 헤딩 3개 이상" |
| **버그 수정** | "기존 테스트 모두 통과, 회귀 테스트 추가" |
| **API 구현** | "OpenAPI 스펙과 일치, 응답 시간 200ms 이하" |

### Outcomes + Routines 조합

루틴에 Outcome을 붙이면 자동 실행 + 품질 보증이 함께 됩니다.

```yaml
routines:
  - name: weekly-doc-refresh
    schedule: "0 18 * * 5"
    prompt: "변경된 코드에 맞게 README와 API 문서를 업데이트하고 PR 생성"
    outcome:
      rubric:
        - "변경된 모든 함수에 JSDoc 추가"
        - "README 예제 코드가 실제 동작하는 코드"
        - "기존 링크 유효성 확인"
      max_retries: 2
```

---

## 세 기능 조합 — "자율 개선 개발 루프"

```
Routine (매주 월요일 09:00)
   ↓
에이전트: 지난주 코드 리뷰 + 기술 부채 정리
   ↓
Outcomes: 리뷰 커버리지 100%, PR 크기 300줄 이하
   ↓
(실패 시 재시도 → 품질 달성)
   ↓
Dreaming (세션 종료 후)
에이전트: 이번 세션에서 반복된 패턴 학습
   ↓
다음 주 같은 실수 방지
```

이 흐름이 완성되면 개발자는 주요 결정과 검토에만 집중하면 되고, 반복 업무와 품질 관리는 에이전트 시스템이 담당해요.

---

## 시작 체크리스트

- [ ] Claude Code CLI 최신 버전 확인 (`claude --version`)
- [ ] 첫 루틴 생성: 매일 오전 PR 요약 알림
- [ ] `claude memory list`로 현재 프로젝트 메모리 확인
- [ ] 핵심 태스크에 Outcome rubric 1개 정의
- [ ] Dreaming 메모리 검토 알림 설정 (`claude memory review --notify`)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
