# 텐빌더 스킬

> Claude Code에서 `/study-vault`, `/study-quiz`, `/pack` 명령으로 사용할 수 있는 도구입니다.

## 무엇을 할 수 있나요?

| 스킬 | 명령어 | 설명 |
|------|--------|------|
| **study-vault** | `/study-vault` | PDF/문서를 Obsidian 학습 노트로 변환 |
| **study-quiz** | `/study-quiz` | 대화형 퀴즈로 숙달도 추적 |
| **session-pack** | `/pack` | 세션 종료 시 Memory/Handoff 자동 정리 |

## 설치

### 자동 설치 (추천)

```bash
curl -sSL https://raw.githubusercontent.com/ten-builder/ten-builder/main/skills/setup.sh | bash
```

### 수동 설치

파일을 `~/.claude/skills/`에 복사합니다:

```bash
git clone https://github.com/ten-builder/ten-builder.git
cp -r ten-builder/skills/study-vault ~/.claude/skills/
cp -r ten-builder/skills/study-quiz ~/.claude/skills/
cp -r ten-builder/skills/session-pack ~/.claude/skills/

# session-pack 에이전트는 별도 위치에 설치
cp ten-builder/skills/session-pack/agents/memory-extractor.md ~/.claude/agents/session-pack-memory-extractor.md
cp ten-builder/skills/session-pack/agents/followup-planner.md ~/.claude/agents/session-pack-followup-planner.md
cp ten-builder/skills/session-pack/agents/duplicate-checker.md ~/.claude/agents/session-pack-duplicate-checker.md

# Handoff 디렉토리 생성
mkdir -p ~/.claude/handoff
```

## 사용법

### 1. 학습 노트 만들기

```
/study-vault

# Claude Code가 질문합니다:
# - 학습 자료 경로 (PDF 또는 문서)
# - 출력 폴더
# - 과목명
```

**결과:** Obsidian에서 바로 열 수 있는 StudyVault가 생성됩니다.

```
AWS-SAA-StudyVault/
├── 00-Dashboard.md       ← 전체 학습 현황
├── 00-빠른참조.md         ← 핵심 정리 원페이저
├── 01-VPC/
│   ├── 개념노트.md
│   └── 연습문제.md
├── 02-IAM/
│   ├── 개념노트.md
│   └── 연습문제.md
└── ...
```

### 2. 퀴즈로 학습

```
/study-quiz

# 자동으로 약한 토픽을 선택해서 퀴즈를 출제합니다.
# 한 문제씩 풀고 즉시 피드백을 받습니다.
```

### 3. 세션 마무리

```
/pack

# 3개 에이전트가 세션 내용을 분석합니다:
# - Memory Extractor: 영구 지식 추출
# - Followup Planner: 미완성 작업 인계서
# - Duplicate Checker: 중복/충돌 검증
#
# 결과를 확인 후 선택 적용합니다.
```

**자동 감지 항목:**
- `MEMORY.md` — `~/.claude/projects/*/memory/MEMORY.md` 패턴으로 자동 탐색
- Context 파일 — `~/.claude/**/*-context.md` 패턴으로 자동 탐색
- Handoff — `~/.claude/handoff/HANDOFF-*.md`

### 4. 숙달도 추적

Dashboard에서 진행 상황을 확인할 수 있습니다:

| 배지 | 의미 | 기준 |
|------|------|------|
| 🔴 | 미학습 | 퀴즈 미실행 |
| 🟡 | 학습중 | 정답률 ~49% |
| 🟢 | 이해함 | 정답률 50~79% |
| 🔵 | 숙달 | 정답률 80%+ |
| ⭐ | 완벽 | 100% × 2회 연속 |

## 어떤 자료에 쓸 수 있나요?

- 자격증 교재 (AWS SAA, CKA 등)
- 기술 서적 PDF
- 강의 노트
- 오픈소스 프로젝트 코드베이스

## 파일 구조

```
skills/
├── README.md                          ← 지금 보고 있는 파일
├── setup.sh                           ← 자동 설치 스크립트
├── study-vault/
│   ├── SKILL.md                       ← 학습 노트 생성 스킬
│   └── references/
│       ├── vault-templates.md         ← Obsidian 노트 템플릿
│       ├── codebase-guide.md          ← 코드베이스 분석 가이드
│       └── quality-check.md           ← 품질 검증 체크리스트
├── study-quiz/
│   ├── SKILL.md                       ← 대화형 퀴즈 스킬
│   └── references/
│       └── quiz-policy.md             ← 퀴즈 출제 정책
└── session-pack/
    ├── SKILL.md                       ← 세션 마무리 오케스트레이터
    ├── agents/
    │   ├── memory-extractor.md        ← Memory + Context + 학습 추출
    │   ├── followup-planner.md        ← Handoff 판단 + 초안
    │   └── duplicate-checker.md       ← 중복/충돌 검증
    └── references/
        └── handoff-template.md        ← Handoff 문서 템플릿
```

> **참고:** session-pack의 에이전트 파일은 설치 시 `~/.claude/agents/` 디렉토리에
> `session-pack-{name}.md` 형태로 복사됩니다. Claude Code가 에이전트를 인식하려면
> 이 위치에 있어야 합니다.

---

📮 **매주 AI 코딩 인사이트:** [maily.so/tenbuilder](https://maily.so/tenbuilder)

🎬 **영상으로 보기:** [youtube.com/@ten-builder](https://youtube.com/@ten-builder)
