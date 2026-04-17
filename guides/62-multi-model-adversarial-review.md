# 가이드 62: 멀티 모델 교차 검증 워크플로우

> 한 AI가 작성하고, 다른 AI가 리뷰한다 — 결제, 인증, 데이터 파이프라인처럼 실수 비용이 높은 코드에 적용하는 교차 검증 패턴

## 왜 교차 검증이 필요한가

AI 에이전트는 혼자 작업할 때 반복적인 패턴의 오류를 만든다. 같은 모델로 검토하면 같은 사각지대가 생긴다. 서로 다른 모델은 서로 다른 학습 데이터와 추론 방식을 갖기 때문에, 한 모델이 놓친 오류를 다른 모델이 잡아낸다.

실제로 Claude Code로 작성한 코드를 Gemini CLI로 리뷰했을 때, SQL 인젝션 취약점 1건과 경쟁 조건(race condition) 2건을 추가로 발견한 사례가 있다.

## 언제 교차 검증을 써야 하는가

| 상황 | 교차 검증 필요 여부 |
|------|------------------|
| 인증/권한 코드 | ✅ 필수 |
| 결제 처리 로직 | ✅ 필수 |
| 데이터 파이프라인 변환 | ✅ 필수 |
| 일반 CRUD API | 선택 |
| UI 컴포넌트 | 선택 |
| 스크립트/유틸 | 불필요 |

## 소요 시간

15-30분 (코드 복잡도에 따라 다름)

## 사전 준비

- Claude Code 설치 (작성용)
- Gemini CLI 설치 (리뷰용)
- 검증 대상 코드 또는 작업 명세

## 기본 패턴: 작성 → 비판 → 수정

### Step 1: Claude Code로 초안 작성

```bash
# 명세를 먼저 전달하고, 코드 작성 전 계획을 확인
claude "payments/checkout.ts 파일의 결제 처리 로직을 구현해줘.
요구사항:
- Stripe API 연동
- 결제 실패 시 롤백
- 중복 결제 방지 (idempotency key)
코드 작성 전에 먼저 접근 방식을 설명해줘."
```

계획을 확인한 뒤:

```bash
claude "좋아, 그 방식으로 구현해줘. payments/checkout.ts에 작성해."
```

### Step 2: 작성된 코드를 Gemini CLI로 리뷰

```bash
# 리뷰 전용 프롬프트 — 구체적인 보안/안정성 관점을 지정
cat payments/checkout.ts | gemini "이 결제 처리 코드를 보안과 안정성 관점에서 비판적으로 리뷰해줘.

확인 항목:
1. 보안: 인젝션, 인증 우회, 민감 데이터 노출 가능성
2. 동시성: 경쟁 조건, 데드락 위험
3. 에러 처리: 실패 시나리오별 처리 누락 여부
4. 엣지 케이스: 네트워크 타임아웃, 부분 실패

발견한 문제를 '심각도 (높음/중간/낮음): 설명' 형식으로 나열해줘."
```

### Step 3: 리뷰 결과를 Claude Code에 반영

```bash
claude "Gemini 리뷰 결과야. 이 문제들을 수정해줘:

[Gemini 출력 붙여넣기]

각 문제를 수정하면서 어떤 변경을 했는지 설명도 추가해줘."
```

## 고급 패턴: 파일 기반 교차 검증

검토할 코드가 여러 파일에 걸쳐 있을 때:

```bash
# 리뷰 대상 파일 목록을 하나로 묶기
cat > /tmp/review-context.md << 'EOF'
# 리뷰 대상

## 파일 목록
- payments/checkout.ts (주 로직)
- payments/idempotency.ts (중복 방지)
- middleware/auth.ts (인증 레이어)

## 변경 사항
[git diff 또는 변경 설명]
EOF

# 컨텍스트와 함께 Gemini에 전달
cat /tmp/review-context.md payments/checkout.ts payments/idempotency.ts | \
  gemini "이 파일들을 함께 검토해줘. 파일 간 인터페이스 불일치나 보안 취약점을 중심으로."
```

## 역할 반전 패턴

때로는 Gemini CLI로 먼저 작성하고 Claude Code로 리뷰하는 것이 더 효과적이다.

```bash
# Gemini CLI: 속도가 빠르고 컨텍스트 윈도우가 커서 대형 파일 분석에 유리
gemini "이 레거시 코드베이스를 분석하고 리팩토링 계획을 세워줘" < legacy/core.ts

# Claude Code: 다단계 수정 작업과 파일 편집에 강점
claude "Gemini가 제안한 리팩토링을 단계별로 실행해줘:
[Gemini 출력 붙여넣기]"
```

## CI/CD에 교차 검증 통합

PR 단계에서 자동으로 교차 검증을 실행하는 GitHub Actions 예시:

```yaml
# .github/workflows/ai-cross-review.yml
name: AI Cross Review

on:
  pull_request:
    paths:
      - 'payments/**'
      - 'auth/**'
      - 'data-pipeline/**'

jobs:
  gemini-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Get changed files
        id: changed
        run: |
          git diff --name-only origin/main HEAD > /tmp/changed-files.txt
          cat /tmp/changed-files.txt

      - name: Gemini Security Review
        env:
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
        run: |
          # 변경된 파일 내용 수집
          while read file; do
            echo "=== $file ===" >> /tmp/review-target.txt
            cat "$file" >> /tmp/review-target.txt
          done < /tmp/changed-files.txt
          
          # Gemini CLI로 보안 리뷰
          cat /tmp/review-target.txt | gemini \
            "이 PR 변경 사항에서 보안 취약점과 버그를 찾아줘. 
            심각도 높음 문제만 보고해줘. 없으면 'LGTM'이라고만 답해줘." \
            > /tmp/review-result.txt
          
          cat /tmp/review-result.txt

      - name: Post Review Comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const review = fs.readFileSync('/tmp/review-result.txt', 'utf8');
            if (!review.includes('LGTM')) {
              github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: `## AI 교차 검증 결과\n\n${review}`
              });
            }
```

## 실용 팁

### 리뷰 프롬프트 설계

막연한 "리뷰해줘"보다 검증 항목을 구체적으로 지정하면 더 유용한 결과를 얻는다.

| 상황 | 추천 프롬프트 패턴 |
|------|-----------------|
| 보안 코드 | "OWASP Top 10 기준으로 취약점을 찾아줘" |
| 동시성 코드 | "경쟁 조건과 데드락 가능성을 찾아줘" |
| 데이터 처리 | "입력값 검증 누락과 타입 불일치를 찾아줘" |
| API 설계 | "RFC 7807 오류 응답 규격과 비교해줘" |

### 모델별 강점 활용

| 모델 | 강점 | 적합한 역할 |
|------|------|-----------|
| Claude Code | 다단계 편집, 코드베이스 이해 | 작성, 수정 |
| Gemini CLI | 대용량 컨텍스트, 빠른 처리 | 리뷰, 분석 |
| Codex CLI | 간결한 함수 생성 | 유틸리티 구현 |

### 피드백 루프 제한

교차 검증은 최대 2-3 라운드로 제한한다. 무한 루프 방지:

```
Round 1: Claude 작성 → Gemini 리뷰
Round 2: Claude 수정 → Gemini 최종 확인
Round 3 이상: 사람이 직접 결정
```

## 체크리스트

- [ ] 고위험 코드(인증/결제/데이터 파이프라인)를 교차 검증 대상으로 지정
- [ ] 리뷰 프롬프트에 구체적인 검증 항목 포함
- [ ] 리뷰 결과에서 심각도 높음 항목 우선 처리
- [ ] 변경 사항을 수정 후 최종 확인 리뷰 실행
- [ ] CI/CD에 핵심 경로(payments, auth) 자동 리뷰 통합

## 다음 단계

→ [가이드 40: 멀티 에이전트 오케스트레이션](./40-multi-agent-orchestration.md)

→ [가이드 16: AI 코딩 보안](./16-ai-coding-security.md)

→ [플레이북: 커스텀 MCP 서버 빌드 & 배포](../claude-code/playbooks/45-custom-mcp-server-build-deploy.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
