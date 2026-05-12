# AI 에이전트 스킬 시스템 가이드 2026 — SKILL.md로 재사용 가능한 에이전트 구성하기

> 거대한 프롬프트 하나에 모든 것을 담는 시대는 끝났다 — 스킬(Skill)로 에이전트를 구조화하는 방법을 다룹니다.

## 왜 스킬인가

AI 코딩 에이전트를 한 달만 써보면 자연스럽게 비슷한 문제에 부딪힌다. 프로젝트마다 비슷한 프롬프트를 다시 입력하거나, 지난번에 잘 동작했던 패턴을 다시 설명하거나, 팀원에게 "이렇게 쓰면 돼"를 반복해서 알려주는 상황이다.

2026년에 바뀐 것은 단순하다. **재사용 가능한 구조화 절차를 `SKILL.md` 파일로 만들어 에이전트에게 가르칠 수 있다.**

프롬프트는 일회성 지시다. 스킬은 절차를 캡슐화한다. 차이는 규모가 커질수록 더 확실해진다.

| | 거대 프롬프트 | 스킬 시스템 |
|---|---|---|
| 복잡도 증가 시 | 프롬프트가 점점 길어짐 | 스킬 파일로 분리 |
| 재사용 | 매번 복사/붙여넣기 | 스킬 이름으로 호출 |
| 팀 공유 | 문서화 필요 | 스킬 파일 배포 |
| 자기 개선 | 수동 수정 | 세션 반영으로 자동 보정 |

## SKILL.md 구조

스킬 파일은 에이전트가 특정 작업을 수행할 때 참조하는 절차 문서다. Claude Code, Codex CLI, Gemini CLI 등 주요 터미널 에이전트들이 공통으로 지원한다.

```
project/
├── CLAUDE.md          # 프로젝트 전체 규칙
├── skills/
│   ├── pr-review/
│   │   └── SKILL.md   # PR 리뷰 절차
│   ├── deploy/
│   │   └── SKILL.md   # 배포 절차
│   └── debug/
│       └── SKILL.md   # 디버깅 절차
```

### SKILL.md 기본 형식

```markdown
# [스킬 이름]

> 한 줄 설명 — 언제, 무엇을, 어떻게

## 트리거 조건

이 스킬을 적용하는 상황:
- [조건 1]
- [조건 2]

## 절차

### Step 1: [단계명]
[구체적 지시]

```bash
[실행 명령어]
```

### Step 2: [단계명]
...

## 완료 기준

- [ ] [체크 항목 1]
- [ ] [체크 항목 2]

## 주의사항

- [금지 사항]
- [예외 처리]
```

## 컨트롤 스택 설계

스킬 시스템이 잘 동작하려면 세 레이어를 나눠 생각해야 한다.

### 레이어 1: 프로젝트 규칙 (CLAUDE.md)

프로젝트 전반에 적용되는 불변 규칙. 언어, 코드 스타일, 금지 명령어, 브랜치 정책 등.

```markdown
# CLAUDE.md

## 필수 규칙
- main 직접 push 금지 → feature 브랜치 → PR
- 커밋 메시지: Conventional Commits
- 테스트 없는 PR 금지

## 스킬 경로
- PR 생성: skills/pr-create/SKILL.md
- 배포: skills/deploy/SKILL.md
- 코드 리뷰: skills/review/SKILL.md
```

### 레이어 2: 재사용 스킬 (SKILL.md)

반복되는 작업 절차. 한 번 잘 만들어두면 팀 전체가 쓸 수 있다.

```markdown
# PR 생성 스킬

## 트리거
"PR 만들어줘", "pull request 생성" 요청 시

## 절차

### Step 1: 브랜치 상태 확인
```bash
git status
git log origin/main..HEAD --oneline
```

### Step 2: 커밋 정리
스쿼시 필요 여부 판단. 5개 이상이면 스쿼시 제안.

### Step 3: PR 생성
```bash
gh pr create --title "[type]: [description]" \
  --body "## Summary\n[변경 내용]\n\n## Test\n- [ ] 단위 테스트\n- [ ] 통합 테스트"
```

## 완료 기준
- [ ] PR URL 출력
- [ ] CI 상태 초록
```

### 레이어 3: 서브에이전트 경계

복잡한 작업을 스킬로 위임할 때 서브에이전트의 권한 범위를 명확히 제한한다.

```markdown
## 서브에이전트 허용 범위
- 읽기: 전체 레포
- 쓰기: feature 브랜치만
- 금지: main push, 환경변수 수정, 외부 API 호출
```

## 실전 스킬 예제 3가지

### 스킬 1: 코드 리뷰 체크리스트

```markdown
# 코드 리뷰 스킬

## 트리거
PR 리뷰 요청 시

## 검토 항목

### 보안
- [ ] SQL injection 취약점
- [ ] 환경변수 하드코딩
- [ ] 인증 로직 누락

### 성능
- [ ] N+1 쿼리
- [ ] 불필요한 반복 연산
- [ ] 캐싱 누락

### 코드 품질
- [ ] 함수 단일 책임
- [ ] 에러 처리 누락
- [ ] 타입 안전성

## 출력 형식
각 항목에 대해 파일명:줄번호와 개선 제안을 명시한다.
```

### 스킬 2: 버그 재현 → 수정 → 테스트

```markdown
# 버그 수정 스킬

## 트리거
"버그 고쳐줘", "에러 발생했어" + 스택트레이스 첨부 시

## 절차

### Step 1: 재현 환경 구성
```bash
git stash
git checkout main
```
에러가 재현되는 최소 케이스를 먼저 만든다.

### Step 2: 원인 분석
- 에러 메시지 역추적
- 관련 파일 3개 이내로 범위 제한
- 가설 수립 (최대 2개)

### Step 3: 수정
가설 1부터 시도. 수정 후 재현 케이스로 검증.

### Step 4: 테스트 추가
수정 내용을 커버하는 테스트를 반드시 추가.

## 완료 기준
- [ ] 재현 케이스 실패 → 성공
- [ ] 기존 테스트 통과
- [ ] 신규 테스트 추가
```

### 스킬 3: 문서 자동 동기화

```markdown
# 문서 동기화 스킬

## 트리거
코드 변경 후 "문서 업데이트해줘" 요청 시

## 절차

### Step 1: 변경 파일 파악
```bash
git diff --name-only origin/main
```

### Step 2: 관련 문서 탐색
변경된 함수/클래스와 연결된 README, API 문서, 주석 파악.

### Step 3: 문서 업데이트
- 함수 시그니처 변경 → JSDoc/docstring 수정
- API 변경 → README 예제 코드 수정
- 설정 변경 → 환경변수 목록 업데이트

## 주의
- 문서가 없는 곳에 함부로 문서를 추가하지 않는다
- 변경된 코드와 직접 관련 있는 부분만 수정
```

## 스킬 배포와 팀 공유

개인 스킬을 팀 전체로 확장하는 방법은 세 가지다.

**1. 레포 내 `skills/` 폴더 공유**

레포에 커밋하면 팀 전체가 동일한 스킬을 쓴다. 가장 단순하고 버전 관리도 된다.

**2. 글로벌 스킬 디렉토리**

```bash
~/.claude/skills/          # 모든 프로젝트에서 사용
  ├── git-workflow/
  │   └── SKILL.md
  └── security-review/
      └── SKILL.md
```

Claude Code는 `~/.claude/skills/`를 자동으로 탐지하고 모든 프로젝트에서 활성화한다.

**3. 스킬 레지스트리 (ClawHub, npm 패키지)**

공개된 스킬을 설치해 쓰는 방식이 2026년부터 정착되고 있다.

```bash
clawhub install pr-review-standard
clawhub install security-scan-owasp
```

## 스킬 자기 개선 패턴

2026년 Claude Code의 PostToolUse Hooks를 활용하면 스킬이 세션 경험에서 스스로 개선된다.

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "python3 ~/.claude/skills/update-from-session.py"
      }]
    }]
  }
}
```

`update-from-session.py`는 세션 중 수정된 패턴을 감지해 SKILL.md에 반영 제안을 만든다. 에이전트가 실수를 반복하지 않도록 절차를 보강하는 것이다.

## 체크리스트

스킬 시스템 도입 시 확인할 항목:

- [ ] 자주 반복되는 작업 3가지 식별
- [ ] 각 작업의 성공 기준 정의
- [ ] SKILL.md에 절차 문서화
- [ ] CLAUDE.md에 스킬 경로 등록
- [ ] 팀 공유 방식 결정 (레포 내 vs 글로벌)
- [ ] 2주 후 스킬 품질 리뷰 일정 잡기

## 다음 단계

→ [컨텍스트 엔지니어링 가이드](63-context-engineering-2026.md)
→ [Claude Code Agent Teams GA 실전 가이드](71-claude-code-agent-teams-ga-guide.md)
→ [Claude Code Week 21 실전 가이드](84-claude-code-week21-features-guide.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
