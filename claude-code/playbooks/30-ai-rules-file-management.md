# 플레이북 30: AI 코딩 에이전트 규칙 파일 통합 관리

> CLAUDE.md, .cursorrules, copilot-instructions.md를 하나의 소스로 관리하는 실전 워크플로우

## 소요 시간

20-30분

## 사전 준비

- AI 코딩 도구 1개 이상 사용 중 (Claude Code, Cursor, Copilot 등)
- 프로젝트 루트에 규칙 파일이 1개 이상 존재
- Git 기본 사용법 숙지

## 왜 통합 관리가 필요한가

AI 코딩 도구를 여러 개 쓰다 보면 규칙 파일이 흩어져요:

| 도구 | 규칙 파일 | 위치 |
|------|----------|------|
| Claude Code | `CLAUDE.md` | 프로젝트 루트 |
| Cursor | `.cursor/rules/*.mdc` | `.cursor/rules/` 디렉토리 |
| GitHub Copilot | `.github/copilot-instructions.md` | `.github/` 디렉토리 |
| Windsurf | `.windsurfrules` | 프로젝트 루트 |
| Cline | `.clinerules` | 프로젝트 루트 |

파일마다 같은 내용을 복사하면 어느 순간 버전이 달라지고, 한쪽만 업데이트하는 실수가 생겨요.

## Step 1: 마스터 규칙 파일 설계

모든 AI 도구가 참조할 **단일 소스(Single Source of Truth)**를 만들어요.

```bash
# 프로젝트 루트에 마스터 파일 생성
touch AGENTS.md
```

`AGENTS.md`에 도구에 무관한 공통 규칙을 작성해요:

```markdown
# 프로젝트 규칙

## 코드 스타일
- TypeScript strict mode 사용
- 함수형 패턴 우선 (class 최소화)
- 에러는 Result 타입으로 처리

## 아키텍처
- src/features/ 기반 모듈 구조
- 비즈니스 로직은 서비스 레이어에 집중
- DB 접근은 반드시 레포지토리 패턴

## 테스트
- 새 기능에는 단위 테스트 필수
- 통합 테스트는 API 엔드포인트 단위
- 테스트 파일은 __tests__/ 디렉토리

## 금지 사항
- any 타입 사용 금지
- console.log 커밋 금지
- 하드코딩된 시크릿 금지
```

## Step 2: 도구별 래퍼 파일 생성

각 도구의 규칙 파일에서 마스터 파일을 참조하도록 설정해요.

### Claude Code — CLAUDE.md

```markdown
# CLAUDE.md

이 프로젝트의 규칙은 AGENTS.md를 따릅니다.

## Claude Code 전용 설정
- /compact 사용 시 AGENTS.md 컨텍스트 유지
- 서브에이전트 사용 시 Task 파일에 AGENTS.md 경로 포함
- 커밋 메시지는 conventional commits 형식
```

Claude Code는 `AGENTS.md`를 자동으로 읽기 때문에 별도 import 구문 없이 동작해요.

### Cursor — .cursor/rules/

```markdown
---
description: 프로젝트 공통 규칙
globs: "**/*"
alwaysApply: true
---

@AGENTS.md 의 모든 규칙을 따르세요.

## Cursor 전용 설정
- Tab 자동완성 시 TypeScript 타입 추론 우선
- Composer에서 파일 생성 시 AGENTS.md 규칙 준수
```

### GitHub Copilot — copilot-instructions.md

```markdown
# Copilot Instructions

이 프로젝트는 AGENTS.md에 정의된 규칙을 따릅니다.
코드 제안 시 아래 규칙을 반드시 확인하세요.

- 코드 스타일: AGENTS.md > 코드 스타일 섹션
- 아키텍처: AGENTS.md > 아키텍처 섹션
- 테스트: AGENTS.md > 테스트 섹션
```

## Step 3: 자동 동기화 스크립트

마스터 파일이 변경되면 도구별 파일을 자동으로 갱신하는 스크립트를 만들어요.

```bash
#!/bin/bash
# scripts/sync-ai-rules.sh

MASTER="AGENTS.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

if [ ! -f "$MASTER" ]; then
  echo "AGENTS.md not found"
  exit 1
fi

# Claude Code — CLAUDE.md 업데이트
cat > CLAUDE.md << EOF
# CLAUDE.md
# 자동 생성 — 직접 수정하지 마세요
# 마스터: AGENTS.md | 동기화: $TIMESTAMP

$(cat "$MASTER")

## Claude Code 전용
- 커밋 메시지: conventional commits
- 서브에이전트: AGENTS.md 경로 포함
EOF

# Cursor rules 업데이트
mkdir -p .cursor/rules
cat > .cursor/rules/project.mdc << EOF
---
description: 프로젝트 공통 규칙 (AGENTS.md 동기화)
globs: "**/*"
alwaysApply: true
---
# 동기화: $TIMESTAMP

$(cat "$MASTER")
EOF

# Copilot instructions 업데이트
mkdir -p .github
cat > .github/copilot-instructions.md << EOF
# Copilot Instructions
# 동기화: $TIMESTAMP

$(cat "$MASTER")
EOF

echo "동기화 완료: $TIMESTAMP"
```

```bash
# 실행 권한 부여
chmod +x scripts/sync-ai-rules.sh

# 실행
./scripts/sync-ai-rules.sh
```

## Step 4: Git Hook으로 자동 검증

`AGENTS.md`가 변경되었는데 다른 파일이 동기화되지 않으면 커밋을 막아요.

```bash
#!/bin/bash
# .husky/pre-commit 또는 .git/hooks/pre-commit

# AGENTS.md가 변경되었는지 확인
if git diff --cached --name-only | grep -q "AGENTS.md"; then
  echo "AGENTS.md 변경 감지 — 동기화 검사 중..."

  # 동기화 스크립트 실행
  ./scripts/sync-ai-rules.sh

  # 동기화된 파일도 스테이징
  git add CLAUDE.md .cursor/rules/project.mdc .github/copilot-instructions.md

  echo "규칙 파일 동기화 완료"
fi
```

## Step 5: 팀 공유 패턴

### 5-1. 계층적 규칙 구조

대규모 프로젝트에서는 규칙을 계층으로 나눠요:

```
AGENTS.md              # 전체 프로젝트 공통
├── docs/AGENTS.md     # 문서 관련 규칙
├── frontend/AGENTS.md # 프론트엔드 규칙
└── backend/AGENTS.md  # 백엔드 규칙
```

### 5-2. 모노레포 패턴

```yaml
# 루트 AGENTS.md
## 공통 규칙
- pnpm workspace 사용
- 패키지 간 의존성은 workspace:* 프로토콜

## 패키지별 규칙
- packages/web → React 19 + Next.js 15
- packages/api → Hono + Drizzle ORM
- packages/shared → 순수 TypeScript (프레임워크 의존 금지)
```

### 5-3. .gitignore 전략

```gitignore
# AI 규칙 파일 — 커밋 대상
!AGENTS.md
!CLAUDE.md
!.github/copilot-instructions.md
!.cursor/rules/project.mdc

# AI 도구 캐시 — 커밋 제외
.claude/
.cursor/cache/
```

## Step 6: 규칙 품질 검증

작성한 규칙이 실제로 잘 동작하는지 검증하는 방법이에요.

| 검증 항목 | 방법 | 기준 |
|-----------|------|------|
| 규칙 인식 여부 | AI에게 "현재 프로젝트 규칙을 요약해줘" 요청 | 마스터 규칙 80% 이상 반영 |
| 코드 생성 품질 | 규칙 위반 코드가 생성되는지 확인 | 위반율 10% 이하 |
| 도구 간 일관성 | 같은 프롬프트로 각 도구에서 코드 생성 | 스타일/패턴 일치 |
| 규칙 충돌 | 도구별 고유 규칙이 마스터와 충돌하는지 확인 | 충돌 0건 |

```bash
# 규칙 인식 테스트 (Claude Code)
claude "AGENTS.md에 정의된 코드 스타일 규칙을 3줄로 요약해줘"

# 규칙 준수 테스트
claude "src/features/user/에 새 API 엔드포인트를 만들어줘" 
# → 레포지토리 패턴, Result 타입 등이 적용되었는지 확인
```

## 체크리스트

- [ ] `AGENTS.md` 마스터 파일 생성
- [ ] 공통 규칙 (코드 스타일, 아키텍처, 테스트, 금지 사항) 작성
- [ ] 도구별 래퍼 파일 설정 (CLAUDE.md, .cursor/rules, copilot-instructions)
- [ ] 동기화 스크립트 작성 및 테스트
- [ ] Git Hook으로 자동 검증 설정
- [ ] 팀원에게 AGENTS.md 수정 워크플로우 공유
- [ ] 규칙 인식/준수 테스트 실행

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| 도구별 파일을 각각 수정 | AGENTS.md만 수정하고 동기화 스크립트 실행 |
| 규칙이 너무 길어서 컨텍스트 초과 | 핵심 규칙 30줄 이내, 상세 규칙은 별도 파일로 분리 |
| 규칙 파일을 .gitignore에 추가 | AI 규칙 파일은 반드시 커밋 대상에 포함 |
| 도구별 고유 설정을 마스터에 섞음 | 공통 규칙만 AGENTS.md, 도구 고유 설정은 래퍼 파일에 |
| 규칙 업데이트 후 테스트 안 함 | 변경 시마다 규칙 인식 테스트 실행 |

## 다음 단계

→ [CLAUDE.md 최적화 플레이북](./13-claudemd-optimization.md)
→ [컨텍스트 관리 플레이북](./12-context-management.md)
→ [AI 에이전트 설정 최적화 워크플로우](../../workflows/ai-agent-config-optimization.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
