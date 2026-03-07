# 플레이북 10: AI 코드 리뷰

> AI 에이전트로 코드 리뷰를 체계화하는 가이드 — PR 자동 분석, 보안 취약점, 성능 제안

## 언제 쓰나요?

- PR이 쌓여서 리뷰 병목이 생겼을 때
- 보안 취약점을 사람이 놓칠까 걱정될 때
- 코드 스타일과 패턴 일관성을 유지하고 싶을 때
- 주니어 개발자의 코드를 효율적으로 피드백하고 싶을 때

## 소요 시간

20-40분 (초기 설정)

## 사전 준비

- GitHub 레포 접근 권한
- Claude Code 또는 AI 코딩 도구 설치
- 팀 코딩 컨벤션 문서 (있으면 좋음)

## Step 1: 리뷰 체크리스트 정의

좋은 코드 리뷰는 명확한 기준에서 시작해요. AI에게 체크리스트를 먼저 알려주면 일관된 리뷰가 가능합니다.

```markdown
# .claude/review-checklist.md

## 필수 체크 항목
- [ ] 에러 핸들링: try-catch 누락, 에러 메시지 노출
- [ ] 입력 검증: 사용자 입력 sanitization
- [ ] SQL 인젝션, XSS 등 보안 취약점
- [ ] N+1 쿼리, 불필요한 루프
- [ ] 하드코딩된 시크릿, API 키
- [ ] 테스트 커버리지 (새 기능에 테스트 포함 여부)

## 권장 체크 항목
- [ ] 함수/변수 네이밍 일관성
- [ ] 불필요한 의존성 추가
- [ ] 타입 안정성 (TypeScript strict 모드 기준)
```

## Step 2: PR diff 분석 요청

PR의 변경 사항을 AI에게 넘겨서 1차 리뷰를 받아보세요.

```bash
# 특정 PR의 diff를 Claude에게 전달
gh pr diff 42 | claude "이 PR을 리뷰해줘.
다음 관점에서 분석해줘:
1. 버그 가능성
2. 보안 취약점
3. 성능 이슈
4. 개선 제안

심각도를 🔴 높음 / 🟡 중간 / 🟢 낮음으로 표시해줘."
```

```bash
# 특정 파일만 집중 리뷰
gh pr diff 42 --name-only | grep '\.ts$' | while read f; do
  echo "=== $f ==="
  gh pr diff 42 -- "$f" | claude "이 TypeScript 파일 변경을 리뷰해줘. 타입 안정성 위주로."
done
```

## Step 3: 보안 중심 리뷰

보안 취약점은 사람이 놓치기 쉬운 부분이에요. AI에게 보안 관점만 따로 요청하면 효과적입니다.

```bash
claude "다음 코드에서 보안 취약점을 찾아줘.
OWASP Top 10 기준으로 분석하고, 각 취약점의
- 위험도 (Critical/High/Medium/Low)
- 공격 시나리오
- 수정 방법
을 알려줘.

$(gh pr diff 42)"
```

| 흔한 보안 이슈 | AI가 잡아주는 패턴 |
|---------------|-------------------|
| SQL 인젝션 | 문자열 결합으로 쿼리 생성 |
| XSS | `innerHTML`, `dangerouslySetInnerHTML` 사용 |
| 시크릿 노출 | `.env` 밖에서 키 하드코딩 |
| 인증 우회 | 미들웨어 누락, 권한 체크 빠짐 |
| SSRF | 사용자 입력 URL로 서버 요청 |

## Step 4: 성능 리뷰

변경된 코드가 성능에 미치는 영향을 미리 파악하세요.

```bash
claude "이 PR의 성능 영향을 분석해줘.
특히 다음을 확인해줘:
- 데이터베이스 쿼리 수 변화
- 메모리 할당 패턴
- 시간 복잡도가 O(n²) 이상인 로직
- 캐싱 가능한 부분

$(gh pr diff 42)"
```

| 성능 패턴 | 확인 포인트 |
|----------|------------|
| N+1 쿼리 | 루프 안에서 DB 호출 |
| 메모리 누수 | 이벤트 리스너 해제 누락 |
| 불필요한 리렌더링 | React 컴포넌트 deps 배열 |
| 대용량 처리 | 스트림 대신 전체 로드 |

## Step 5: GitHub Actions 자동화

매 PR마다 수동으로 AI 리뷰를 요청하는 건 번거로워요. GitHub Actions로 자동화하면 편합니다.

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get PR diff
        run: |
          git diff origin/main...HEAD > diff.txt

      - name: AI Review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          claude "이 diff를 리뷰하고 GitHub PR 코멘트 형식으로 정리해줘" < diff.txt > review.md

      - name: Post Review Comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const review = fs.readFileSync('review.md', 'utf8');
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: review
            });
```

## Step 6: 리뷰 결과 정리

AI 리뷰 결과를 팀에 공유할 때는 구조화된 포맷이 좋아요.

```bash
claude "리뷰 결과를 다음 형식으로 정리해줘:

## 리뷰 요약
- 전체 평가: (통과/수정 필요/재작성 권장)
- 변경 파일: N개
- 발견된 이슈: N개

## 이슈 목록
| # | 심각도 | 파일 | 라인 | 설명 |
|---|--------|------|------|------|

## 칭찬할 점
(잘 작성된 부분도 언급)

## 제안 사항
(필수가 아닌 개선 아이디어)"
```

## 체크리스트

- [ ] 리뷰 체크리스트 파일 생성
- [ ] PR diff → AI 리뷰 워크플로우 테스트
- [ ] 보안 리뷰 프롬프트 저장
- [ ] GitHub Actions 자동화 설정
- [ ] 팀원에게 리뷰 프로세스 공유

## 실전 팁

| 상황 | 프롬프트 예시 |
|------|-------------|
| 전체 리뷰 | `이 PR을 리뷰해줘. 버그, 보안, 성능 순서로.` |
| 특정 파일 집중 | `이 파일의 에러 핸들링만 확인해줘.` |
| 아키텍처 리뷰 | `이 변경이 기존 아키텍처와 일관성이 있는지 확인해줘.` |
| 테스트 리뷰 | `테스트 커버리지가 충분한지, 엣지 케이스가 빠졌는지 확인해줘.` |

## 다음 단계

→ [GitHub Actions + AI 코드 리뷰](../../workflows/github-actions-ai-review.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
