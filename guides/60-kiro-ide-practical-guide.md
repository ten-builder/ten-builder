# 가이드 60: Kiro IDE 실전 가이드 — Amazon 스펙 주도 AI 코딩 에이전트

> Amazon이 만든 AI 코딩 에이전트 Kiro — 코드를 짜기 전에 **스펙부터 잡는** 새로운 접근법을 실전 기준으로 정리합니다.

## Kiro란?

Kiro는 Amazon이 2026년 출시한 스펙 주도 AI 코딩 에이전트입니다. VS Code를 기반으로 하고, Amazon Bedrock에서 Claude 모델을 사용합니다.

Claude Code나 Cursor처럼 "일단 코드부터 만들어줘"가 아니라, **요구사항 → 설계 → 태스크 → 구현** 순서를 강제합니다. 8,000줄짜리 PR을 혼자 완성하는 에이전트가 필요하다면 Kiro가 맞습니다.

## 핵심 개념 3가지

### 1. Specs (스펙 문서)

기능을 구현하기 전에 3개의 파일을 자동 생성합니다:

| 파일 | 내용 |
|------|------|
| `requirements.md` | EARS 형식 요구사항 (When/The system shall...) |
| `design.md` | 데이터 모델, 컴포넌트 구조, API 설계 |
| `tasks.md` | 체크박스형 구현 태스크 목록 |

```
# 스펙 생성 예시
/spec create --feature "사용자 로그인 기능"
```

스펙 파일이 완성되면 Kiro가 각 태스크를 순서대로 실행합니다. 중간에 멈춰도 어디서 재개할지 명확합니다.

### 2. Agent Hooks (에이전트 훅)

IDE 이벤트에 반응해 AI 에이전트를 자동 실행하는 규칙입니다.

```yaml
# .kiro/hooks/test-sync.yaml
name: Test Sync Hook
trigger:
  type: file_change
  pattern: "**/*.py"
action:
  type: agent
  prompt: "변경된 파이썬 파일에 맞게 테스트 파일을 업데이트해줘"
```

**실용적인 훅 패턴:**

| 트리거 | 자동 실행 |
|--------|-----------|
| `.py` 파일 저장 | 대응 테스트 파일 업데이트 |
| 파일 생성 | 문서 뼈대 자동 추가 |
| 에이전트 턴 완료 | CHANGELOG 자동 갱신 |
| PR 생성 | 코드 리뷰 체크리스트 실행 |

> **주의:** 훅은 강력하지만 무분별하게 설정하면 저장할 때마다 에이전트가 실행되어 오히려 느려집니다. 처음에는 테스트 동기화 하나만 설정하는 걸 추천합니다.

### 3. Steering Files (스티어링 파일)

프로젝트 전반에 걸쳐 에이전트가 따라야 할 규칙을 파일로 관리합니다. Claude Code의 `CLAUDE.md`와 비슷하지만, 목적별로 파일을 분리합니다.

```
.kiro/steering/
  product-overview.md     # 프로젝트 배경 및 목적
  tech-stack.md           # 사용 기술 스택
  security-policies.md    # 보안 규칙
  coding-standards.md     # 코드 스타일 가이드
  deployment-workflow.md  # 배포 절차
```

```markdown
# coding-standards.md 예시
- TypeScript strict 모드 필수
- 함수 하나당 단일 책임 원칙
- 비동기 처리는 async/await만 사용
- 에러는 반드시 typed error로 처리
```

## 실전 워크플로우

### Step 1: 프로젝트 초기화

```bash
# Kiro 설치 (VS Code 확장)
# Marketplace에서 "Amazon Kiro" 검색

# 스티어링 파일 초기화
mkdir -p .kiro/steering
```

먼저 `product-overview.md`와 `tech-stack.md`에 프로젝트 기본 정보를 작성합니다. Kiro에게 "이런 프로젝트야"를 먼저 알려주는 과정입니다.

### Step 2: 스펙으로 기능 정의

```
# Kiro 채팅창에서
/spec create
> 어떤 기능인가요?
# "이메일 인증이 포함된 회원가입 기능"

# requirements.md, design.md, tasks.md 자동 생성
```

생성된 스펙을 검토하고, 틀린 부분이 있으면 파일을 직접 수정합니다. Kiro는 스펙 파일을 기준으로 구현하기 때문에, 여기서 제대로 잡아야 합니다.

### Step 3: 에이전트 실행

스펙이 준비되면 에이전트를 실행합니다:

```
/agent start --spec features/user-signup/
```

태스크 목록을 위에서부터 순서대로 실행합니다. 각 태스크 완료 시 `tasks.md`의 체크박스가 업데이트됩니다.

### Step 4: 훅으로 자동화

개발 중에는 테스트 동기화 훅을 켜두면 코드를 저장할 때마다 테스트가 자동으로 맞춰집니다:

```yaml
# .kiro/hooks/auto-test.yaml
name: Auto Test Update
trigger:
  type: file_save
  pattern: "src/**/*.ts"
action:
  type: agent
  prompt: "변경 사항에 맞게 __tests__ 폴더의 테스트를 최신화해줘"
  autoApprove: false  # 변경 전 미리보기 필수
```

## Kiro vs Claude Code — 실전 비교

| 항목 | Kiro | Claude Code |
|------|------|-------------|
| 인터페이스 | VS Code GUI | 터미널 CLI |
| 코딩 방식 | 스펙 → 구현 순서 고정 | 자유로운 대화형 |
| 대형 기능 | 강점 (스펙 추적) | 직접 관리 필요 |
| 빠른 수정 | 오버헤드 있음 | 빠름 |
| 컨텍스트 유지 | 스펙 파일로 자동 관리 | CLAUDE.md 수동 관리 |
| 훅 자동화 | 기본 제공 | 외부 스크립트 필요 |
| 모델 | Claude via Bedrock | Claude 직접 |

**Kiro가 적합한 상황:**
- 처음부터 새로운 기능을 설계하며 구현할 때
- 팀원이 여럿이고 구현 맥락을 공유해야 할 때
- 대형 PR(수천 줄)을 에이전트에게 완전히 위임할 때

**Claude Code가 적합한 상황:**
- 기존 코드베이스의 빠른 수정과 리팩토링
- 터미널 친화적인 워크플로우
- 세밀한 프롬프트 제어가 필요한 복잡한 작업

## 체크리스트

- [ ] `.kiro/steering/` 파일 4개 이상 작성
- [ ] 첫 스펙 생성 후 `requirements.md` 직접 검토/수정
- [ ] 훅은 `autoApprove: false`로 시작 후 신뢰가 생기면 켜기
- [ ] 스펙 파일은 Git에 커밋 (팀원과 맥락 공유)
- [ ] 큰 기능은 서브 스펙으로 분리 (하나의 스펙 = 하루치 작업)

## 다음 단계

→ [스펙 주도 개발 치트시트](../cheatsheets/spec-driven-development-cheatsheet.md)
→ [오케스트레이터-워커 패턴 심화 가이드](58-ai-agent-orchestrator-patterns.md)
→ [AI 코딩 에이전트 비교 가이드](51-terminal-ai-agents-comparison-2026.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
