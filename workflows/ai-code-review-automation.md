# AI 코드 리뷰 자동화 워크플로우

> PR이 올라오면 AI가 먼저 리뷰하고, 사람은 핵심만 확인하는 코드 리뷰 파이프라인 구축 가이드

## 개요

코드 리뷰는 품질을 지키는 가장 확실한 방법이지만, 시간이 오래 걸려요. 특히 팀원이 바쁠 때 PR이 며칠씩 방치되는 건 흔한 일이에요.

AI 코드 리뷰 자동화는 이 병목을 해결해요. PR이 올라오면 AI가 **보안 취약점, 패턴 위반, 테스트 누락**을 먼저 검사하고, 사람은 비즈니스 로직과 설계 판단에 집중하는 구조예요.

이 워크플로우에서 다루는 것:

1. **GitHub Actions로 PR 자동 리뷰** — PR 이벤트에 반응하는 CI 파이프라인
2. **리뷰 관점별 프롬프트 설계** — 보안, 성능, 스타일, 테스트를 분리
3. **리뷰 결과 정리** — 인라인 코멘트 + 요약 코멘트 자동 생성
4. **수정 제안 자동화** — AI가 제안한 수정을 Suggestion 블록으로 변환
5. **사람 리뷰와의 역할 분담** — AI가 놓치는 부분을 보완하는 가이드라인

## 사전 준비

- GitHub 레포 (GitHub Actions 활성화)
- AI API 키 (Anthropic, OpenAI, 또는 Google)
- Node.js 18+ 또는 Python 3.11+
- 레포에 린팅/테스트 파이프라인이 이미 설정되어 있으면 좋음

## 설정

### Step 1: GitHub Actions 워크플로우 파일 생성

`.github/workflows/ai-review.yml`을 만들어요:

```yaml
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize, ready_for_review]

permissions:
  contents: read
  pull-requests: write

jobs:
  ai-review:
    if: github.event.pull_request.draft == false
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get PR diff
        id: diff
        run: |
          git diff origin/${{ github.base_ref }}...HEAD \
            --diff-filter=ACMR \
            --unified=5 \
            -- '*.ts' '*.tsx' '*.py' '*.go' '*.rs' \
            > /tmp/pr_diff.txt
          echo "lines=$(wc -l < /tmp/pr_diff.txt)" >> $GITHUB_OUTPUT

      - name: AI Review
        if: steps.diff.outputs.lines > 0
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          node scripts/ai-review.mjs \
            --diff /tmp/pr_diff.txt \
            --pr ${{ github.event.pull_request.number }}
```

### Step 2: 리뷰 스크립트 작성

`scripts/ai-review.mjs`가 실제 AI 호출과 코멘트 생성을 담당해요:

```javascript
import { readFileSync } from 'fs';
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic();
const diff = readFileSync(process.argv[3], 'utf-8');
const prNumber = process.argv[5];

// diff가 너무 길면 파일별로 분할
const MAX_DIFF_CHARS = 30000;
const chunks = diff.length > MAX_DIFF_CHARS
  ? splitByFile(diff)
  : [diff];

const reviews = [];

for (const chunk of chunks) {
  const response = await client.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 4096,
    messages: [{
      role: 'user',
      content: buildReviewPrompt(chunk)
    }]
  });
  reviews.push(parseReview(response.content[0].text));
}

// GitHub API로 코멘트 생성
await postReviewComments(prNumber, reviews.flat());
```

### Step 3: 리뷰 프롬프트 설계

프롬프트를 관점별로 나누면 각 영역에서 더 정확한 피드백을 받을 수 있어요:

```javascript
function buildReviewPrompt(diff) {
  return `당신은 시니어 소프트웨어 엔지니어이고, 코드 리뷰를 진행합니다.

아래 PR diff를 검토하고, 다음 관점에서 이슈를 찾아주세요:

## 검토 관점
1. **보안**: SQL 인젝션, XSS, 하드코딩된 시크릿, 인증 우회
2. **버그 가능성**: null 참조, 경계 조건, 레이스 컨디션
3. **성능**: N+1 쿼리, 불필요한 루프, 메모리 누수 패턴
4. **가독성**: 함수 길이 50줄 초과, 매직 넘버, 불명확한 변수명

## 출력 형식 (JSON)
[
  {
    "file": "파일 경로",
    "line": 시작 줄 번호,
    "severity": "critical | warning | suggestion",
    "category": "security | bug | performance | readability",
    "message": "이슈 설명 (한국어, 2-3문장)",
    "suggestion": "수정 코드 (있으면)"
  }
]

사소한 스타일 이슈는 무시하세요. 실제 문제만 리포트해주세요.

## PR Diff
${diff}`;
}
```

## 사용 방법

### 기본 흐름

```
PR 생성 → GitHub Actions 트리거 → diff 추출 → AI 리뷰
→ 인라인 코멘트 게시 → 요약 코멘트 추가 → 사람 리뷰어 할당
```

### 결과 코멘트 형식

AI가 남기는 코멘트는 이렇게 구성돼요:

```markdown
## AI Code Review Summary

### 발견된 이슈: 3건

| 심각도 | 카테고리 | 파일 | 설명 |
|--------|---------|------|------|
| critical | security | `src/auth.ts:42` | API 키가 응답에 포함됨 |
| warning | bug | `src/utils.ts:88` | null 체크 누락 |
| suggestion | performance | `src/db.ts:15` | N+1 쿼리 패턴 |

> 이 리뷰는 자동화된 초벌 검사입니다. 최종 판단은 사람 리뷰어가 진행합니다.
```

### 인라인 Suggestion 블록

```javascript
async function postReviewComments(prNumber, issues) {
  const criticals = issues.filter(i => i.severity === 'critical');
  const others = issues.filter(i => i.severity !== 'critical');

  // critical 이슈는 "Request changes"로
  // 나머지는 "Comment"로 리뷰 생성
  const event = criticals.length > 0
    ? 'REQUEST_CHANGES'
    : 'COMMENT';

  const comments = issues
    .filter(i => i.suggestion)
    .map(i => ({
      path: i.file,
      line: i.line,
      body: `**${i.category}** (${i.severity})\n\n${i.message}\n\n\`\`\`suggestion\n${i.suggestion}\n\`\`\``
    }));

  await octokit.pulls.createReview({
    owner, repo, pull_number: prNumber,
    event,
    body: buildSummaryComment(issues),
    comments
  });
}
```

### CLI에서 로컬 리뷰 실행

CI 전에 로컬에서 먼저 확인할 수도 있어요:

```bash
# 현재 브랜치의 변경사항을 AI 리뷰
git diff main...HEAD -- '*.ts' | \
  node scripts/ai-review.mjs --stdin --format terminal

# 특정 파일만 리뷰
node scripts/ai-review.mjs --files src/auth.ts src/db.ts
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `AI_REVIEW_MODEL` | `claude-sonnet-4-20250514` | 리뷰에 사용할 모델 |
| `MAX_DIFF_LINES` | `2000` | 이 이상이면 파일별 분할 리뷰 |
| `REVIEW_LANGUAGE` | `ko` | 코멘트 언어 (ko, en) |
| `SEVERITY_THRESHOLD` | `warning` | 이 이상만 코멘트 |
| `AUTO_REQUEST_CHANGES` | `true` | critical 시 자동 변경 요청 |
| `IGNORE_PATTERNS` | `*.test.ts,*.spec.ts` | 리뷰 제외 패턴 |

### 프로젝트별 규칙 추가

`.github/ai-review-rules.md`에 팀 규칙을 정의하면 프롬프트에 자동으로 포함돼요:

```markdown
# AI 리뷰 추가 규칙

- React 컴포넌트는 반드시 `React.memo` 또는 `useMemo` 사용 여부 확인
- API 엔드포인트는 rate limiting 미들웨어 필수
- DB 쿼리는 인덱스 사용 여부 확인
- 환경 변수는 `zod` 스키마로 검증
```

```javascript
// 스크립트에서 규칙 파일 로딩
const rulesPath = '.github/ai-review-rules.md';
const customRules = existsSync(rulesPath)
  ? readFileSync(rulesPath, 'utf-8')
  : '';

// 프롬프트에 주입
const prompt = buildReviewPrompt(diff) +
  (customRules ? `\n\n## 추가 규칙\n${customRules}` : '');
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| diff가 너무 커서 토큰 초과 | `MAX_DIFF_LINES` 줄이거나 파일 필터 추가 |
| 리뷰 코멘트가 잘못된 줄에 달림 | diff 파싱 로직에서 hunk 헤더 정확히 추적 |
| API rate limit 초과 | 파일별 리뷰 사이에 `sleep(1000)` 추가 |
| 거짓 양성이 많음 | severity threshold를 높이고 커스텀 규칙 정제 |
| PR 코멘트 권한 오류 | `permissions: pull-requests: write` 확인 |

## AI와 사람 리뷰어의 역할 분담

| 검토 항목 | AI | 사람 |
|-----------|-----|------|
| 보안 취약점 | ✅ 패턴 기반 탐지 | ✅ 비즈니스 로직 보안 |
| 코딩 컨벤션 | ✅ 자동 체크 | - |
| 테스트 커버리지 | ✅ 누락 감지 | ✅ 시나리오 적절성 |
| 아키텍처 적합성 | ⚠️ 제한적 | ✅ 핵심 판단 |
| 비즈니스 요구사항 | ❌ 불가 | ✅ 필수 |
| 성능 병목 | ✅ 패턴 감지 | ✅ 실측 기반 판단 |

핵심 원칙: **AI는 반복적이고 패턴 기반인 검사를 담당하고, 사람은 맥락과 의도를 판단하는 데 집중해요.**

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
