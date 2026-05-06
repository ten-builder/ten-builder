# AI 코딩 도구 Shadow IT 리스크 관리 워크플로우

> 기업에서 무단 사용되는 AI 코딩 도구를 탐지하고, 보안 정책을 수립해 바이브 코딩의 위협을 체계적으로 통제하는 워크플로우

## 왜 지금 이 문제인가

2026년 4월, 국내 한 스타트업에서 개발팀이 승인되지 않은 AI 코딩 도구를 사용하다 프로덕션 DB 접근 자격증명이 외부 AI 서버로 전송되는 사고가 발생했다. 개발자는 단순히 "더 좋은 자동완성"을 원했을 뿐이다.

이것이 Shadow IT의 새로운 형태다. Claude Code, Cursor, Copilot 같은 AI 코딩 도구가 무단으로 도입되고, AI가 작성한 코드는 충분한 검토 없이 프로덕션에 배포된다.

## 사전 준비

- 현재 사용 중인 AI 도구 목록 파악 (승인 여부 무관)
- 보안팀과 개발팀 공동 리뷰 일정 수립
- CI/CD 파이프라인 접근 권한

## Phase 1: 현황 파악 — 무엇이 쓰이고 있는가

### Step 1: AI 도구 사용 현황 감사

```bash
# npm/pip에서 AI 관련 패키지 탐지
# 팀 전체 package.json / requirements.txt 수집
find ~/projects -name "package.json" -not -path "*/node_modules/*" | \
  xargs grep -l "openai\|anthropic\|@anthropic-ai\|langchain\|@google/generative-ai" 2>/dev/null

find ~/projects -name "requirements*.txt" | \
  xargs grep -il "openai\|anthropic\|langchain\|google-generativeai" 2>/dev/null
```

```bash
# Git 히스토리에서 AI 도구 관련 커밋 탐지
git log --all --oneline --grep="copilot\|cursor\|claude\|chatgpt" --since="6 months ago"

# .gitignore에 숨겨진 AI 설정 파일 탐지
find . -name ".cursorrules" -o -name "CLAUDE.md" -o -name ".copilotignore" | \
  grep -v ".git"
```

### Step 2: 네트워크 레벨 감사

| 확인 항목 | 방법 | 위험도 |
|-----------|------|--------|
| api.anthropic.com 트래픽 | 방화벽 로그 분석 | 높음 |
| api.openai.com 트래픽 | 프록시 로그 분석 | 높음 |
| cursor.sh, codeium.com | DNS 쿼리 로그 | 중간 |
| 미인가 MCP 서버 연결 | 포트 스캔 + 프로세스 확인 | 높음 |

```bash
# macOS/Linux에서 AI 도구 관련 프로세스 확인
ps aux | grep -i "cursor\|claude\|copilot\|codeium\|continue" | grep -v grep

# 열린 네트워크 연결 확인
lsof -i | grep -i "anthropic\|openai\|cursor"
```

## Phase 2: 리스크 분류 — 무엇이 위험한가

### 리스크 매트릭스

```
                    낮음           높음
              ┌────────────────────────────┐
위험도  높음  │ 승인 필요    │ 즉시 차단   │
              │ (30일 내)    │ (즉시)      │
              ├────────────────────────────┤
        낮음  │ 허용 (모니터│ 승인 필요   │
              │ 링 조건)     │ (14일 내)   │
              └────────────────────────────┘
                  코드 접근    시크릿 접근

```

### AI 도구별 위험도 분류

| 도구 유형 | 예시 | 주요 위험 | 기본 정책 |
|-----------|------|-----------|-----------|
| IDE 통합 AI | Cursor, Copilot | 코드 전송, 학습 데이터 | 승인 후 허용 |
| 터미널 에이전트 | Claude Code, Codex CLI | 환경변수 접근, 파일 시스템 | 정책 설정 후 허용 |
| MCP 서버 (외부) | 미인가 서버 | 자격증명 유출, 임의 실행 | 금지 (화이트리스트만) |
| 무단 API 키 | 개인 키 공유 | 비용 무단 발생, 감사 불가 | 중앙 관리 전환 |

## Phase 3: 정책 수립 — 허용 범위 정의

### APPROVED_TOOLS.md 작성

팀의 레포 루트에 `APPROVED_TOOLS.md` 파일을 생성해 허용된 AI 도구를 명확히 정의한다.

```markdown
# AI 도구 승인 목록 — {팀명}

> 마지막 업데이트: {날짜}
> 책임자: {보안팀 담당자}

## 승인된 도구

| 도구 | 버전/플랜 | 허용 범위 | 조건 |
|------|-----------|-----------|------|
| GitHub Copilot | Enterprise | IDE 자동완성 | 코드 학습 OFF 설정 필수 |
| Claude Code | Pro/Max | 터미널 에이전트 | 내부 프로젝트 전용 |
| Cursor | Business | IDE | .cursorrules 필수 |

## 금지된 도구

- 개인 계정 API 키 사용
- 미승인 MCP 서버 연결
- 비공개 코드를 무료 플랜으로 전송

## 시크릿 보호 규칙

AI 에이전트에게 절대 노출 금지:
- AWS/GCP/Azure 자격증명
- DB 연결 문자열
- API 키, OAuth 시크릿
- 고객 데이터
```

### CLAUDE.md에 보안 가드레일 추가

```markdown
## 보안 규칙 (필수)

### 절대 하지 않을 것
- 환경변수에서 시크릿 직접 출력
- .env 파일 내용을 코드에 하드코딩
- 외부 서비스로 자격증명 전송

### 항상 할 것
- 시크릿은 환경변수로만 참조: `process.env.SECRET_KEY`
- 새 의존성 추가 시 라이선스 확인
- 외부 API 호출 전 팀 승인 확인
```

## Phase 4: 자동화 게이트 — CI/CD에 보안 통합

### Pre-commit Hook 설정

```bash
#!/bin/sh
# .git/hooks/pre-commit (또는 pre-commit 프레임워크 사용)

echo "AI 코드 보안 검사 실행 중..."

# 시크릿 하드코딩 탐지
if grep -r "sk-\|AKIA\|ghp_\|xoxb-" --include="*.ts" --include="*.js" --include="*.py" .; then
  echo "ERROR: 하드코딩된 시크릿이 감지되었습니다. 커밋을 중단합니다."
  exit 1
fi

# AI 생성 TODO 미완성 체크
if grep -rn "TODO: \[AI\]\|FIXME: \[AI\]" --include="*.ts" --include="*.js" .; then
  echo "WARNING: AI가 남긴 미완성 TODO가 있습니다. 확인 후 커밋하세요."
fi

echo "보안 검사 완료."
```

### GitHub Actions — AI 코드 품질 게이트

```yaml
# .github/workflows/ai-code-security.yml
name: AI Code Security Gate

on:
  pull_request:
    branches: [main, develop]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: 시크릿 스캔
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}

      - name: AI 생성 코드 마커 검사
        run: |
          # 미검토 AI 생성 블록 탐지
          if grep -r "AI_GENERATED_UNREVIEWED" --include="*.ts" --include="*.js" .; then
            echo "::error::검토되지 않은 AI 생성 코드 블록이 있습니다"
            exit 1
          fi

      - name: 의존성 취약점 검사
        run: |
          npm audit --audit-level=high || true
          # 실패해도 파이프라인은 계속 (경고만)
```

## Phase 5: 팀 교육 — 안전한 AI 코딩 문화

### 개발자 체크리스트 (코드 리뷰 전)

```markdown
## AI 코드 제출 전 자가 점검

- [ ] AI가 작성한 코드를 한 줄씩 읽고 이해했는가?
- [ ] 외부 의존성이 추가됐다면 라이선스를 확인했는가?
- [ ] 환경변수/시크릿이 하드코딩되지 않았는가?
- [ ] 에러 메시지에 시스템 경로/DB 이름이 노출되지 않는가?
- [ ] AI가 제안한 SQL 쿼리에 인젝션 취약점은 없는가?
- [ ] 승인된 AI 도구만 사용했는가?
```

### 팀 리더를 위한 리뷰 포인트

| 리뷰 항목 | 감지 방법 | 조치 |
|-----------|-----------|------|
| 과도한 복잡성 | 불필요한 추상화 레이어 | 단순화 요청 |
| 미사용 임포트 | 린터 결과 | 정리 요청 |
| 테스트 없는 비즈니스 로직 | 커버리지 리포트 | 테스트 추가 요청 |
| 승인되지 않은 API 호출 | 외부 URL 목록 검토 | 보안팀 검토 |

## 실행 규칙 요약

| 단계 | 주기 | 담당 |
|------|------|------|
| 현황 감사 | 분기 1회 | 보안팀 |
| APPROVED_TOOLS.md 업데이트 | 도구 변경 시 | 팀 리드 |
| Pre-commit Hook 적용 | 즉시 | 개발자 전체 |
| CI 보안 게이트 점검 | 월 1회 | DevOps |
| 팀 교육 | 반기 1회 | 팀 리드 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
