# AI 코딩 에이전트 팀 온보딩 체크리스트

> 개발팀에 AI 코딩 에이전트를 처음 도입할 때 꼭 챙겨야 할 설정, 규칙, 교육 항목을 한 페이지로 정리했어요.

---

## 1단계: 환경 설정

| 항목 | 내용 |
|------|------|
| `CLAUDE.md` 생성 | 레포 루트에 팀 공통 컨텍스트 파일 배치 |
| 권한 설정 | 에이전트가 접근 가능한 파일/디렉토리 명시 |
| `.gitignore` 업데이트 | 에이전트 세션 파일, 캐시 제외 설정 |
| API 키 관리 | 개인 키 vs 팀 공유 키 정책 결정 |

```bash
# CLAUDE.md 기본 구조
echo "# 프로젝트 컨텍스트

## 기술 스택
- Node.js 22 / TypeScript 5.5
- PostgreSQL 16, Redis 7

## 코딩 컨벤션
- ESLint + Prettier 사용 (설정: .eslintrc.json)
- 커밋: Conventional Commits 형식 필수

## 금지 사항
- main 브랜치 직접 push 금지
- 프로덕션 DB 직접 접근 금지
" > CLAUDE.md
```

---

## 2단계: 팀 규칙 수립

### 필수 결정 사항

| 결정 항목 | 권장 방향 |
|----------|----------|
| 에이전트 실행 범위 | 로컬 개발 환경만 허용 (프로덕션 접근 차단) |
| 코드 리뷰 정책 | AI 생성 코드도 반드시 PR 리뷰 필수 |
| 브랜치 전략 | feature 브랜치에서만 에이전트 실행 허용 |
| 커밋 메시지 | 팀 컨벤션 준수 (AI 생성 표시 여부 팀 결정) |

### `.claudeignore` 예시

```
# 에이전트 접근 차단 파일
.env
.env.production
secrets/
*.pem
*.key
terraform/state/
```

---

## 3단계: 공유 컨텍스트 구성

AI 에이전트가 팀 컨텍스트를 이해하려면 레포에 다음 파일들이 있어야 해요:

```
.
├── CLAUDE.md          # 에이전트 공통 컨텍스트
├── AGENTS.md          # 에이전트별 역할 정의
├── docs/
│   ├── architecture.md   # 시스템 구조 설명
│   ├── api-contracts.md  # API 계약 정의
│   └── coding-guide.md   # 팀 코딩 가이드
└── .github/
    └── pull_request_template.md
```

### 효과적인 CLAUDE.md 작성 패턴

```markdown
## 이 레포에서 자주 하는 작업
1. API 엔드포인트 추가: src/routes/ + src/controllers/
2. DB 스키마 변경: migrations/ + prisma/schema.prisma 동시 수정
3. 테스트: jest 사용, __tests__/ 디렉토리

## 절대 하지 않는 것
- 직접 DB 쿼리 실행 (Prisma ORM 사용)
- console.log 대신 logger.info() 사용
```

---

## 4단계: CI/CD 통합

```yaml
# .github/workflows/ai-code-check.yml
name: AI Code Quality Gate

on: [pull_request]

jobs:
  quality-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Type check
        run: npx tsc --noEmit
      - name: Lint
        run: npm run lint
      - name: Test
        run: npm test -- --coverage
      - name: Coverage threshold
        run: |
          # AI 생성 코드 포함 PR은 커버리지 80% 이상 유지
          npm test -- --coverage --coverageThreshold='{"global":{"lines":80}}'
```

---

## 5단계: 팀 교육

### 온보딩 순서

1. **1일차**: 에이전트 설치 + 개인 환경 설정 (30분)
2. **2일차**: CLAUDE.md 읽기 + 간단한 태스크 실습 (1시간)
3. **1주차**: 실제 이슈 1~2개를 에이전트와 함께 해결
4. **2주차**: 팀 회고 — 잘된 점, 주의할 점 공유

### 흔한 실수 vs 좋은 습관

| 흔한 실수 | 좋은 습관 |
|----------|----------|
| 에이전트 출력을 바로 커밋 | 반드시 실행 확인 후 커밋 |
| 막연한 프롬프트 ("리팩토링 해줘") | 구체적인 요청 ("UserService의 getById를 캐시 레이어 추가해줘") |
| 에이전트에게 보안 키 노출 | `.claudeignore`로 민감 파일 차단 |
| 에이전트가 생성한 테스트만 믿기 | 핵심 경로는 수동으로 검증 |

---

## 6단계: 도구별 팀 설정 요약

| 도구 | 팀 설정 핵심 |
|------|------------|
| **Claude Code** | CLAUDE.md, 프로젝트별 메모리 파일 |
| **Gemini CLI** | GEMINI.md, `--project` 플래그 공유 |
| **Codex CLI** | `.codex/config.yaml` 레포 내 공유 |
| **Cursor** | `.cursorrules` 파일 + 팀 공유 룰셋 |

---

## 빠른 체크리스트

**설정 완료 확인**
- [ ] 레포 루트에 `CLAUDE.md` 존재
- [ ] `.claudeignore`로 민감 파일 차단
- [ ] CI에 린트 + 테스트 게이트 설정
- [ ] 팀원 전원 로컬 설치 완료

**운영 규칙 확인**
- [ ] AI 생성 코드 PR 리뷰 필수 정책 문서화
- [ ] 에이전트 실행 금지 환경(프로덕션) 명시
- [ ] 온콜 시 에이전트 사용 기준 명확화
- [ ] 주간 회고에 AI 활용 사례 공유 항목 추가

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
