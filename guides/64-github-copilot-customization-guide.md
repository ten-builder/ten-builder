# GitHub Copilot 팀 맞춤 설정 가이드 2026

> 기본 자동완성을 넘어 팀 코딩 규칙, 프로젝트 컨텍스트, 보안 정책까지 반영하는 Copilot 환경을 만드는 실전 가이드

## 왜 커스텀 설정이 중요한가

GitHub Copilot은 기본 상태에서도 잘 동작하지만, 팀 특유의 코딩 규칙이나 프로젝트 도메인 지식 없이 제안을 생성합니다. `copilot-instructions.md`와 조직 수준 설정을 조합하면 Copilot이 팀 컨텍스트를 이해하고 일관된 제안을 만들어줍니다.

2026년 4월 기준으로 조직 수준 커스텀 지시사항(Organization Custom Instructions)이 정식 출시되어 전사 적용이 가능해졌습니다.

## 커스텀 설정 3가지 레이어

| 레이어 | 파일/위치 | 적용 범위 |
|--------|-----------|-----------|
| 조직 수준 | GitHub 조직 설정 → Copilot | 조직 전체 모든 레포 |
| 레포 수준 | `.github/copilot-instructions.md` | 해당 레포 |
| 워크스페이스 수준 | `.vscode/settings.json` | 로컬 팀 설정 |

---

## Step 1: 레포 수준 — copilot-instructions.md 작성

레포 루트의 `.github/copilot-instructions.md`에 저장하면 Copilot Chat과 코드 리뷰에 자동으로 적용됩니다.

```bash
mkdir -p .github
touch .github/copilot-instructions.md
```

### 좋은 copilot-instructions.md 예시

```markdown
# 프로젝트 개요
이 레포는 Node.js + TypeScript로 작성된 B2B SaaS 결제 API입니다.
PostgreSQL(Prisma ORM)을 사용하며, 모든 금융 데이터는 암호화 처리합니다.

# 코딩 규칙
- TypeScript strict 모드 사용. any 타입 금지
- 함수는 단일 책임 원칙 준수 (50줄 이하 권장)
- 에러 처리는 반드시 커스텀 AppError 클래스 사용
- 모든 API 엔드포인트는 Zod 스키마로 입력값 검증

# 테스트
- 유닛 테스트: Vitest, 커버리지 80% 이상 유지
- 통합 테스트: Supertest + 테스트 DB 사용
- 결제 관련 코드는 모킹 대신 Stripe test mode 사용

# 보안
- 환경 변수는 절대 코드에 하드코딩하지 않음
- 사용자 입력은 항상 sanitize 후 DB 저장
- PII 데이터는 로그에 절대 출력하지 않음

# 사용하지 않는 패턴
- var 키워드 사용 금지 (const/let만 사용)
- callback 패턴 금지 (Promise/async-await 사용)
- moment.js 사용 금지 (date-fns 사용)
```

### 작성 팁

| 항목 | 효과적인 방법 |
|------|--------------|
| 프로젝트 도메인 | 도메인 특화 용어 명시 (예: "주문 상태는 ORDER_STATUS enum 참조") |
| 금지 패턴 | "사용하지 않는 패턴" 섹션으로 명확히 구분 |
| 코드 스타일 | 팀 eslint 규칙과 연동하여 일관성 유지 |
| 분량 | 500자 이내로 간결하게 — 너무 길면 무시됨 |

---

## Step 2: 조직 수준 커스텀 지시사항 설정 (2026년 4월 GA)

모든 레포에 공통 적용할 조직 정책을 설정합니다.

```
GitHub → 프로필 사진 → Organizations → [조직 선택]
→ Settings → Copilot → Policies → Custom Instructions
```

조직 수준 지시사항은 개별 레포의 `copilot-instructions.md`보다 우선순위가 낮아 레포별 재정의가 가능합니다.

```markdown
# 조직 보안 정책
- 모든 시크릿은 GitHub Secrets 또는 Vault 사용
- AWS 자격증명을 코드에 직접 포함하지 않음
- 의존성 추가 시 라이선스 확인 필수 (GPL 계열 주의)

# 코드 리뷰 기준
- PR 설명에 변경 이유와 영향 범위 명시
- breaking change는 MAJOR 버전 업 필요
- 테스트 없는 로직 변경은 리뷰 반려
```

---

## Step 3: VS Code 워크스페이스 설정 동기화

`.vscode/settings.json`을 레포에 포함하면 팀 전체가 동일한 Copilot 설정을 씁니다.

```json
{
  "github.copilot.enable": {
    "*": true,
    "plaintext": false,
    "markdown": true,
    "scminput": false
  },
  "github.copilot.editor.enableAutoCompletions": true,
  "github.copilot.chat.localeOverride": "ko",
  "github.copilot.advanced": {
    "length": 500,
    "inlineSuggestCount": 3
  },
  "chat.editor.fontFamily": "JetBrains Mono, monospace"
}
```

| 설정 키 | 설명 |
|---------|------|
| `copilot.enable` | 파일 타입별 Copilot 활성화 제어 |
| `chat.localeOverride` | Copilot Chat 응답 언어 고정 (ko = 한국어) |
| `advanced.length` | 제안 최대 토큰 수 |
| `inlineSuggestCount` | 인라인 제안 개수 |

---

## Step 4: Prompt 파일로 반복 작업 자동화

VS Code에서 `.prompt.md` 파일을 만들면 재사용 가능한 구조화된 프롬프트를 팀이 공유할 수 있습니다.

```bash
# VS Code Command Palette
# Chat: Create Prompt → 이름 입력
# .github/prompts/ 폴더에 저장
```

```markdown
<!-- .github/prompts/write-unit-test.prompt.md -->
# 유닛 테스트 작성

선택한 함수에 대한 Vitest 테스트를 작성해줘.

요구사항:
- 정상 케이스 최소 2개
- 경계값 케이스 포함
- 에러 케이스 포함 (잘못된 입력, 네트워크 실패 등)
- 각 테스트는 독립적으로 실행 가능해야 함
- mock은 vi.mock() 사용

파일은 [파일명].test.ts 형식으로 생성.
```

자주 쓰는 프롬프트 파일 예시:

| 파일명 | 용도 |
|--------|------|
| `write-unit-test.prompt.md` | 유닛 테스트 자동 생성 |
| `review-security.prompt.md` | 보안 관점 코드 리뷰 |
| `generate-api-docs.prompt.md` | API 문서 자동화 |
| `refactor-to-clean.prompt.md` | 클린 코드 리팩토링 |

---

## Step 5: 팀 도입 체크리스트

```bash
# 설정 파일 구조
.github/
  copilot-instructions.md   # 레포 수준 지시사항
  prompts/                  # 공유 프롬프트 파일
    write-unit-test.prompt.md
    review-security.prompt.md
.vscode/
  settings.json             # Copilot + 에디터 설정
  extensions.json           # 권장 확장 목록
```

- [ ] `.github/copilot-instructions.md` 작성 및 팀 리뷰
- [ ] `.vscode/settings.json` 공통 Copilot 설정 확인
- [ ] 조직 설정에서 Custom Instructions 활성화
- [ ] 공유 프롬프트 파일 2~3개 초기 세트 준비
- [ ] 팀원 대상 설정 설명 세션 (30분)

---

## 흔한 설정 실수

| 실수 | 해결 |
|------|------|
| instructions.md가 너무 길다 | 500자 이내로 압축, 세부 규칙은 별도 문서로 |
| 프로젝트 맥락 없이 규칙만 나열 | 레포가 무엇을 하는지 첫 줄에 명시 |
| `.vscode/settings.json` 미공유 | `.gitignore`에서 제외하고 레포에 포함 |
| 지시사항을 초기 설정 후 방치 | 분기마다 팀이 함께 검토/업데이트 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
