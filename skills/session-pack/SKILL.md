---
name: session-pack
description: 세션 종료 시 Memory, Handoff를 자동 정리. /pack
user_invocable: true
---

# Session Pack (Multi-Agent Orchestrator)

세션 중 대화한 내용을 3개 전문 에이전트가 병렬 분석하여 Memory와 Handoff에 자동 반영합니다.

## Trigger Keywords
- `/pack` — 전체 분석 + 반영

## Architecture

```
Phase 1: 데이터 수집 + 세션 요약 (메인 Claude)
                    │
                    ▼
Phase 2: 분석 (2 에이전트 병렬)
┌──────────────────────────────┬──────────────────────────────┐
│ memory-extractor             │ followup-planner             │
│ (Memory + Context + 학습)    │ (Handoff 판단)               │
└──────────────────────────────┴──────────────────────────────┘
                    │
                    ▼
Phase 3: 검증 (순차)
┌────────────────────────────────────────────────────────────┐
│ duplicate-checker — Phase 2 결과를 기존 문서와 대조         │
└────────────────────────────────────────────────────────────┘
                    │
                    ▼
Phase 4: 제안 표시 (메인 Claude)
Phase 5: 사용자 선택 후 적용 (메인 Claude)
Phase 6: 확인 리포트 (메인 Claude)
```

## Agents

| Agent | 파일 | 역할 |
|-------|------|------|
| `Session Wrap Memory Extractor` | `session-pack-memory-extractor` | Memory + Context + 학습 통합 추출 |
| `Session Wrap Followup Planner` | `session-pack-followup-planner` | Handoff 필요 여부 + 초안 |
| `Session Wrap Duplicate Checker` | `session-pack-duplicate-checker` | Phase 2 결과 중복/충돌 검증 |

---

## Phase 1: 데이터 수집 + 세션 요약

> **메인 Claude가 직접 수행.** 모든 Step을 **병렬로** 실행.

**Step 1: Git 변경 사항 수집**
```bash
git status && git diff --stat && git log --oneline -5
```
> git repo가 아니면 skip. 결과를 `[GIT_CHANGES]` 변수에 저장.

**Step 2: MEMORY.md 자동 감지**
```
Glob: ~/.claude/projects/*/memory/MEMORY.md
```
- 여러 개 발견되면 **가장 최근 수정된 파일** 사용
- 하나도 없으면 → "MEMORY.md 없음. 새로 생성할까요?" 질문
- 결과를 `[MEMORY_PATH]`와 `[CURRENT_MEMORY]` 변수에 저장

**Step 3: Context 파일 자동 감지**
```
Glob: ~/.claude/**/*-context.md
```
- `skills/`, `agents/`, `projects/` 하위 파일은 제외 (스킬 정의 파일이므로)
- 발견된 파일을 모두 읽어서 `[CONTEXT_FILES]` 변수에 저장
- 파일이 없으면 → context 업데이트 단계는 skip
- 어떤 파일이 발견되었는지 `[CONTEXT_PATHS]` 기록

**Step 4: 기존 Handoff 확인**
```
Glob: ~/.claude/handoff/HANDOFF-*.md
```
결과를 `[EXISTING_HANDOFFS]` 변수에 저장.

**Step 4b: Handoff 완료 여부 확인**

기존 Handoff 파일의 "진행 중" 섹션을 스캔하여 완료 후보를 식별:
```
각 HANDOFF 파일에서 "## 진행 중" 또는 "## 다음 할 일" 섹션의 [ ] 체크박스 상태 확인
→ 모두 [x]이거나, 관련 작업 완료 증거가 있으면 → [HANDOFF_ARCHIVE_CANDIDATES]에 추가
```
결과를 `[HANDOFF_ARCHIVE_CANDIDATES]` 변수에 저장.

**Step 5: 세션 요약 작성**

이 세션의 **전체 대화**를 분석하여 구조화된 요약을 작성합니다.
에이전트는 대화 컨텍스트를 직접 볼 수 없으므로, 이 요약이 에이전트의 유일한 입력입니다.

`[SESSION_SUMMARY]` 형식:

```markdown
## Session Summary

### 수행한 작업
1. {작업 1}: {결과}
2. {작업 2}: {결과}

### 변경된 파일
- {파일 경로}: {무엇을 변경했는지}

### 시행착오 / 디버깅
- 시도: {접근법 A} → 결과: {실패/성공 + 이유}
- 시도: {접근법 B} → 결과: {실패/성공 + 이유}

### 새로 발견한 것
- {도구/설정/패턴/API} 관련: {구체적 사실}

### 사용자가 명시적으로 기억 요청한 것
- {있으면 기록, 없으면 "없음"}

### 미완성 작업
- {있으면 기록, 없으면 "없음"}

### 결정된 사항
- {전략/방향/도구 선택 등}
```

> **중요**: 이 요약은 최대한 구체적으로 (경로, 명령어, 에러 메시지, 버전 번호 등 포함). 추상적 설명은 에이전트가 활용하기 어렵습니다.

---

## Phase 2: 에이전트 병렬 분석

Phase 1에서 수집한 데이터를 2개 에이전트에 전달하여 **동시에** 분석합니다.

> **반드시 2개 Agent tool call을 하나의 메시지에서 병렬로 호출하세요.**

### Agent 1: Memory Extractor

```
Agent tool:
  subagent_type: "Session Wrap Memory Extractor"
  model: "sonnet"
  prompt: |
    세션 요약과 현재 MEMORY.md를 분석하여 저장할 영구 지식을 추출하세요.

    [SESSION_SUMMARY]
    {Phase 1 Step 5의 세션 요약}

    [CURRENT_MEMORY]
    {Phase 1 Step 2의 MEMORY.md 내용}

    [MEMORY_PATH]
    {MEMORY.md 파일 경로}

    [CONTEXT_FILES]
    {Phase 1 Step 3의 context 파일 내용 — 있으면}

    [CONTEXT_PATHS]
    {발견된 context 파일 경로 목록}

    [GIT_CHANGES]
    {Phase 1 Step 1의 git 결과}

    에이전트 정의에 따라 분석하고 결과를 출력하세요.
```

### Agent 2: Followup Planner

```
Agent tool:
  subagent_type: "Session Wrap Followup Planner"
  model: "sonnet"
  prompt: |
    세션 요약과 git 변경을 분석하여 Handoff 필요 여부를 판단하세요.

    [SESSION_SUMMARY]
    {Phase 1 Step 5의 세션 요약}

    [GIT_CHANGES]
    {Phase 1 Step 1의 git 결과}

    [EXISTING_HANDOFFS]
    {Phase 1 Step 4의 기존 handoff 목록}

    [HANDOFF_ARCHIVE_CANDIDATES]
    {Phase 1 Step 4b의 완료 후보 handoff 목록}

    에이전트 정의에 따라 분석하고 결과를 출력하세요.
    완료된 Handoff가 있으면 Archive 제안도 포함하세요.
```

---

## Phase 3: 중복 검증 (순차)

Phase 2의 2개 에이전트 결과를 모아서 duplicate-checker에 전달합니다.

> **Phase 2가 모두 완료된 후** 순차적으로 실행.

```
Agent tool:
  subagent_type: "Session Wrap Duplicate Checker"
  model: "sonnet"
  prompt: |
    Phase 2 에이전트들의 제안을 기존 문서와 대조하여 중복/충돌을 검증하세요.

    [PHASE2_PROPOSALS]
    --- Memory Extractor ---
    {Agent 1 결과}

    --- Followup Planner ---
    {Agent 2 결과}

    [CURRENT_MEMORY]
    {MEMORY.md 내용}

    [MEMORY_PATH]
    {MEMORY.md 파일 경로}

    [FILE_PATHS]
    {검색 대상 파일 경로 목록: MEMORY.md + context 파일들 + handoff 파일들}

    에이전트 정의에 따라 각 제안을 Add/Merge/Skip/Conflict로 분류하세요.
```

---

## Phase 4: 제안 표시

Phase 3(duplicate-checker)의 **최종 분류 결과**를 기반으로 번호 매긴 제안 목록을 생성합니다.

> Skip 판정된 항목은 목록에서 제외. Conflict 항목은 별도 표시.

**출력 형식:**

```markdown
# Session Pack Proposals

## Memory Updates (N items)

### [1] New: {섹션 제목}
> 판정: Add | 대상: MEMORY.md
+ 추가될 내용 미리보기

### [2] Update: {기존 섹션 제목}
> 판정: Merge | 대상: MEMORY.md — {기존 섹션}에 병합
- 기존 내용 (유지)
+ 새로 추가될 bullet

## Context Updates (N items)

### [3] Update: {변경 설명}
> 판정: Add | 대상: {파일명} — {섹션명}
- 기존 값
+ 새 값

## Handoff

### [4] Create: HANDOFF-{topic}-{YYYYMMDD}.md
> 미완성 작업 인계
- 완료: A, B
- 미완성: C (70%)
- 다음: D, E

## Learnings (N items)

### [5] TIL: {인사이트 제목}
> 판정: Add | 대상: MEMORY.md
+ 인사이트 내용

## Conflicts (확인 필요)

### [!1] {항목}: 기존값 vs 새값
> 어느 값이 맞는지 선택해주세요
- A: 기존값 "{...}"
- B: 새값 "{...}"

## Skipped (참고)
- {Skip된 항목}: 이미 {위치}에 존재
```

**제안 후 AskUserQuestion:**

```
question: "적용할 항목을 선택하세요"
options:
  - "All" — 전체 적용
  - "None" — 아무것도 적용하지 않음
  - "Pick" — 번호로 선택 (예: 1,3,4)
```

> "Pick" 선택 시 추가 번호 입력 요청.
> Conflict 항목은 별도 질문으로 A/B 선택 요청.

---

## Phase 5: 적용

사용자가 선택한 항목만 적용합니다.

### Memory New (새 섹션 추가)

MEMORY.md 끝에 새 섹션을 append:

```markdown
## {섹션 제목} ({YYYY-MM-DD})
- bullet 1
- bullet 2
```

- Edit tool 사용 (파일 끝부분의 기존 텍스트를 anchor로 잡아 append)
- `# currentDate` 섹션이 있으면 그 **위에** 추가

### Memory Merge (기존 섹션 업데이트)

기존 `##` 섹션을 찾아 Edit으로 bullet 추가:
- 기존 bullet 유지 + 새 bullet append
- 날짜 태그가 있으면 업데이트

### Context Update

대상 context 파일의 해당 섹션을 Edit으로 수정:
- frontmatter `updated:` 오늘 날짜로 갱신
- 변경 이력/체크리스트 항목 추가

### Handoff Create

`~/.claude/handoff/HANDOFF-{topic}-{YYYYMMDD}.md` 생성:

> references/handoff-template.md의 템플릿을 사용

### Handoff Update (기존 handoff 갱신)

기존 HANDOFF 파일을 Edit으로 수정:
- 완료 항목 체크
- 진행 중 상태 업데이트
- frontmatter `updated:` 갱신

### Handoff Archive

완료된 Handoff를 archived/로 이동:
```bash
mv ~/.claude/handoff/HANDOFF-{name}.md ~/.claude/handoff/archived/
```

---

## Phase 6: 확인 리포트

```markdown
## Session Pack Complete

| Action | File | Status |
|--------|------|--------|
| Memory: N added, M merged | MEMORY.md | Done |
| Context: N updated | {파일명} | Done |
| Handoff | HANDOFF-{name}.md | Created / Updated / — |
| Learnings: N captured | MEMORY.md | Done |
| Skipped | N items | — |
| Conflicts resolved | N items | Done |

> 다음 세션에서 /pack 결과가 잘 반영되었는지 확인하세요.
```

> "None" 선택 시: "No changes applied. Session pack cancelled." 만 출력.

---

## Edge Cases

| 상황 | 동작 |
|------|------|
| 대화가 짧고 변경 사항 없음 | "이 세션에서 저장할 내용이 없습니다." — Phase 2 skip |
| MEMORY.md 400줄 초과 우려 | 별도 topic 파일 생성 제안 (예: `memory/debugging.md`) |
| Context 파일 없음 | Context 업데이트 단계 skip |
| Context 파일 대상 섹션 못 찾음 | 가장 적절한 위치를 제안하고 확인 요청 |
| 모순 발견 (Conflict) | Phase 4에서 별도 표시 + 사용자 선택 |
| git repo 아님 | Phase 1 Step 1 skip, [GIT_CHANGES]를 "N/A"로 전달 |
| 에이전트 실패 | 해당 카테고리만 skip, 나머지 정상 진행 |
| Handoff 디렉토리 없음 | 자동 생성: `mkdir -p ~/.claude/handoff` |
