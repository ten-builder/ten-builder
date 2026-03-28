# 플레이북 28: AI 페어 리뷰

> 사람과 AI가 함께 코드를 리뷰하는 실전 플레이북 — 역할 분담, 체크리스트, 피드백 루프

## 언제 쓰나요?

- 혼자 개발하는데 코드 리뷰 상대가 없을 때
- PR 리뷰에 AI를 보조 리뷰어로 붙이고 싶을 때
- AI 에이전트가 생성한 코드를 체계적으로 검수하고 싶을 때
- 리뷰 품질을 일정 수준 이상으로 유지하면서 속도도 챙기고 싶을 때

## 소요 시간

15-30분 (워크플로우 세팅), 이후 PR당 5-15분

## 사전 준비

- AI 코딩 도구 (Claude Code, Cursor 등)
- Git + PR 기반 워크플로우
- 프로젝트 규칙 파일 (CLAUDE.md, .cursorrules 등)

## Step 1: 역할을 명확하게 나누기

페어 리뷰에서 가장 중요한 건 "AI가 잘하는 것"과 "사람이 잘하는 것"을 구분하는 거예요.

| 관점 | AI가 담당 | 사람이 담당 |
|------|----------|-----------|
| 버그 탐지 | 타입 오류, null 체크 누락, 경계값 | 비즈니스 로직 오류, 도메인 규칙 위반 |
| 보안 | SQL 인젝션, XSS, 시크릿 노출 | 인증/인가 설계, 권한 모델 적절성 |
| 성능 | N+1 쿼리, 불필요한 루프, 메모리 누수 | 아키텍처 수준 병목, 캐싱 전략 |
| 스타일 | 네이밍, 포맷, 컨벤션 일관성 | 코드 가독성, 추상화 수준 |
| 테스트 | 커버리지 갭, 엣지케이스 누락 | 테스트 시나리오 적절성, 의미 있는 검증 |
| 설계 | 패턴 불일치, 중복 코드 | 아키텍처 방향성, 확장성, 트레이드오프 |

```markdown
# .claude/review-role.md — 프로젝트에 넣어두면 AI가 매번 참조

## AI 리뷰어 역할
1. 코드 정확성: 타입, null safety, 에러 핸들링
2. 보안: 인젝션, XSS, 시크릿 노출
3. 성능: 쿼리 최적화, 불필요한 연산
4. 컨벤션: 네이밍 규칙, 코드 스타일 일관성
5. 테스트: 빠진 엣지케이스 제안

## 사람 리뷰어 역할
1. 비즈니스 로직 정합성
2. 아키텍처 적합성
3. 사용자 경험 영향도
4. 팀 컨텍스트와 일치 여부
```

## Step 2: AI 1차 리뷰 실행하기

PR이 올라오면 AI에게 먼저 리뷰를 맡겨요. 핵심은 **구체적인 관점을 지정**하는 거예요.

```bash
# Claude Code에서 PR diff 리뷰 요청
git diff main...feature/my-feature | claude "이 diff를 리뷰해줘.
다음 관점으로 문제를 찾아줘:
1. 버그: 타입 오류, null 체크 누락, 경계값
2. 보안: 인젝션, 시크릿 노출
3. 성능: N+1, 불필요한 루프
4. 테스트: 빠진 엣지케이스

각 이슈를 [심각도: 높음/중간/낮음] + 파일:라인 형식으로 정리해줘."
```

**Cursor에서는:**

```
@Codebase PR diff를 리뷰해줘.
변경된 파일: src/api/users.ts, src/middleware/auth.ts
관점: 보안 + 성능 + 에러 핸들링
```

**리뷰 결과 구조화 예시:**

```markdown
## AI 리뷰 결과

### [높음] src/api/users.ts:42
- 문제: `req.params.id`를 parseInt 없이 직접 DB 쿼리에 사용
- 제안: `const id = parseInt(req.params.id, 10)` + NaN 체크 추가

### [중간] src/middleware/auth.ts:15
- 문제: JWT 검증 실패 시 에러 메시지에 토큰 일부가 노출됨
- 제안: 에러 응답에서 토큰 정보 제거, 로그에만 기록

### [낮음] src/api/users.ts:78
- 문제: `users.filter().map()` 체이닝 — 배열을 2번 순회
- 제안: `reduce`로 1회 순회 또는 현재 규모면 무시 가능
```

## Step 3: 사람이 2차 리뷰하기

AI 리뷰 결과를 그대로 받아들이지 마세요. 사람의 2차 리뷰는 AI가 놓치는 영역을 커버해요.

**사람이 집중할 3가지 질문:**

```markdown
## 2차 리뷰 체크리스트

### 1. 이 변경이 맞는 방향인가?
- [ ] 요구사항을 정확히 구현했는가
- [ ] 더 나은 접근법이 있지 않은가
- [ ] 기존 아키텍처와 일관성이 있는가

### 2. AI 리뷰 결과를 검증했는가?
- [ ] AI가 지적한 이슈가 실제로 문제인가 (false positive 체크)
- [ ] AI가 놓친 비즈니스 로직 이슈가 없는가
- [ ] AI 제안 수정사항이 다른 부분을 망가뜨리지 않는가

### 3. 이 코드를 6개월 뒤에도 이해할 수 있는가?
- [ ] 복잡한 로직에 "왜"를 설명하는 주석이 있는가
- [ ] 함수/변수 이름만으로 의도가 전달되는가
- [ ] 테스트가 명세서 역할을 하는가
```

**AI 리뷰에 대한 판정:**

| AI 지적 | 사람 판정 | 액션 |
|---------|----------|------|
| 타입 오류 발견 | 동의 | 즉시 수정 |
| 성능 개선 제안 | 현재 규모에선 과도 | 무시 + TODO 코멘트 |
| 보안 취약점 발견 | 동의 + 추가 이슈 발견 | 수정 + 추가 패치 |
| 네이밍 변경 제안 | 프로젝트 컨벤션과 불일치 | 거절 |

## Step 4: 피드백 루프 만들기

리뷰 결과를 축적하면 AI 리뷰 정확도가 올라가요.

```markdown
# .claude/review-learnings.md — 프로젝트 루트에 유지

## 자주 나오는 false positive
- `Array.filter().map()` 체이닝: 배열 100개 이하면 무시
- `any` 타입 경고: 외부 라이브러리 타입 정의 없을 때는 허용
- 에러 메시지 노출 경고: 개발 모드에서는 의도적

## 프로젝트 특수 규칙
- `/api/internal/*` 경로: 내부 전용이라 인증 체크 불필요
- DB 쿼리: ORM 사용 중이라 SQL 인젝션 경고 대부분 무시 가능
- 환경 변수: `.env.example`에 있는 키는 시크릿 아님

## 지난 리뷰에서 놓친 것
- 2026-03: 파일 업로드 크기 제한 없어서 OOM 발생
- 2026-02: 동시성 이슈 — 낙관적 잠금 없이 업데이트
```

**리뷰 세션 후 업데이트 루틴:**

```bash
# 리뷰 끝난 후 학습 파일 업데이트
claude "이번 PR 리뷰에서 발견한 새로운 패턴이나 규칙을
.claude/review-learnings.md에 추가해줘.
- false positive 였던 것
- 실제 중요했던 이슈
- 프로젝트 특수 규칙"
```

## Step 5: 워크플로우 자동화

매번 수동으로 AI 리뷰를 요청하지 말고 자동화해요.

### GitHub Actions 연동

```yaml
# .github/workflows/ai-review.yml
name: AI Pair Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get diff
        run: |
          git diff origin/main...HEAD > /tmp/pr-diff.txt

      - name: AI Review
        run: |
          # diff를 AI에 보내고 결과를 PR 코멘트로 작성
          cat /tmp/pr-diff.txt | \
            claude --output-format json \
            "코드 리뷰해줘. JSON으로 반환:
            {issues: [{severity, file, line, message, suggestion}]}" \
            > /tmp/review.json

      - name: Post Review Comment
        uses: actions/github-script@v7
        with:
          script: |
            const review = require('/tmp/review.json');
            const body = review.issues
              .map(i => `**[${i.severity}]** \`${i.file}:${i.line}\`\n${i.message}\n> ${i.suggestion}`)
              .join('\n\n');
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `## AI Review\n\n${body}`
            });
```

### Pre-push 훅으로 로컬 리뷰

```bash
#!/bin/bash
# .git/hooks/pre-push

echo "Running AI pair review..."

DIFF=$(git diff origin/main...HEAD)
if [ -n "$DIFF" ]; then
  echo "$DIFF" | claude "빠르게 리뷰해줘.
  심각한 문제(보안, 크래시)만 알려줘.
  문제 없으면 'LGTM'만 출력." 2>/dev/null

  read -p "push 진행? (y/n) " confirm
  [ "$confirm" != "y" ] && exit 1
fi
```

## Step 6: 리뷰 품질 측정하기

페어 리뷰가 실제로 효과가 있는지 추적해요.

| 메트릭 | 측정 방법 | 목표 |
|--------|---------|------|
| AI 이슈 정확도 | 실제 수정한 이슈 / AI가 지적한 이슈 | 70% 이상 |
| 발견 속도 | AI 리뷰 완료까지 소요 시간 | 3분 이내 |
| 사후 버그 | 리뷰 통과 후 발견된 버그 수 | 월 2건 이하 |
| 리뷰 커버리지 | AI+사람 리뷰를 거친 PR 비율 | 90% 이상 |

```bash
# 월간 리뷰 효과 분석 프롬프트
claude "지난 한 달간 PR 리뷰 기록을 분석해줘.
- AI가 지적해서 실제로 수정한 건 몇 건?
- AI가 놓쳤는데 사람이 잡은 건 몇 건?
- 리뷰 통과 후 프로덕션에서 발견된 버그는?
데이터: .claude/review-learnings.md"
```

## 체크리스트

- [ ] 역할 분담 문서 작성 (.claude/review-role.md)
- [ ] AI 1차 리뷰 프롬프트 템플릿 준비
- [ ] 사람 2차 리뷰 체크리스트 준비
- [ ] 학습 파일 생성 (.claude/review-learnings.md)
- [ ] CI/CD 또는 pre-push 훅 자동화 설정
- [ ] 월간 리뷰 효과 측정 루틴 수립

## 실전 팁

**1인 개발자일 때:** AI를 "시니어 리뷰어"로 설정하고 모든 PR에 AI 리뷰를 필수로 걸어두세요. 혼자서도 리뷰 문화를 유지할 수 있어요.

**팀에서 쓸 때:** AI 리뷰를 "1차 필터"로 사용하고, 사람 리뷰어는 AI가 통과시킨 코드에서 아키텍처와 비즈니스 로직에 집중하세요. 리뷰 시간이 절반 이상 줄어요.

**AI 리뷰를 맹신하지 마세요:** AI는 패턴 매칭에 능하지만, "이 변경이 왜 필요한가?"나 "6개월 뒤 유지보수성"은 여전히 사람의 영역이에요.

## 다음 단계

→ [AI 코드 리뷰 플레이북](./10-code-review.md)
→ [AI 출력물 검증 가이드](../../guides/18-ai-output-verification.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
