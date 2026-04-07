# AI 에이전트 기반 모노레포 코드 오너십 대시보드

> 모노레포에서 AI 에이전트로 코드 오너십과 변경 빈도를 분석해서 시각화하는 CLI 대시보드

## 이 예제에서 배울 수 있는 것

- `git log` 히스토리를 파싱해서 파일별/팀별 오너십을 자동으로 산출하는 방법
- AI 에이전트로 CODEOWNERS 파일을 자동 생성하고 유지하는 패턴
- 변경 빈도(churn rate)와 오너십 집중도를 시각화하는 터미널 대시보드 구현
- 모노레포에서 "누가 이 코드를 가장 잘 아는가"를 데이터로 답하는 방법

## 프로젝트 구조

```
ai-monorepo-ownership-dashboard/
├── CLAUDE.md                      # AI 에이전트 프로젝트 규칙
├── src/
│   ├── cli.ts                     # CLI 엔트리포인트
│   ├── analyzer/
│   │   ├── git-log-parser.ts      # git log → 구조화 데이터
│   │   ├── ownership-calculator.ts # 파일별 오너십 점수 계산
│   │   ├── churn-detector.ts      # 변경 빈도 핫스팟 탐지
│   │   └── team-mapper.ts         # 커미터 → 팀 매핑
│   ├── generator/
│   │   ├── codeowners.ts          # CODEOWNERS 자동 생성
│   │   └── report.ts              # JSON/Markdown 리포트
│   └── dashboard/
│       ├── terminal-ui.ts         # blessed 기반 터미널 대시보드
│       ├── treemap.ts             # 디렉토리 트리맵 시각화
│       └── heatmap.ts             # 변경 빈도 히트맵
├── tests/
│   ├── git-log-parser.test.ts
│   ├── ownership-calculator.test.ts
│   └── fixtures/
│       └── sample-git-log.txt
├── package.json
├── tsconfig.json
└── README.md
```

## 왜 코드 오너십 분석이 필요한가

모노레포가 커지면 "이 모듈 수정하려면 누구한테 물어봐야 하지?"라는 질문에 답하기 어려워져요. CODEOWNERS 파일을 수동으로 관리하는 팀이 많지만, 실제 커밋 히스토리와 동기화가 안 되는 경우가 대부분이에요.

```
실제 상황:
CODEOWNERS에 적힌 담당자 → 6개월 전에 팀 이동
최근 3개월 실제 커미터 → CODEOWNERS에 없는 사람
PR 리뷰 요청 → 엉뚱한 사람한테 감
```

이 도구는 git 히스토리에서 실제 오너십을 자동으로 계산하고, CODEOWNERS를 최신 상태로 유지해줘요.

## 시작하기

### Step 1: 프로젝트 초기화

```bash
mkdir ai-monorepo-ownership-dashboard && cd $_
npm init -y
npm install blessed blessed-contrib chalk commander simple-git
npm install -D typescript @types/node tsx vitest
```

```json
{
  "scripts": {
    "dev": "tsx src/cli.ts",
    "build": "tsc",
    "test": "vitest",
    "analyze": "tsx src/cli.ts analyze --path .",
    "dashboard": "tsx src/cli.ts dashboard --path .",
    "codeowners": "tsx src/cli.ts generate-codeowners --path ."
  }
}
```

### Step 2: Git 로그 파서 구현

핵심은 `git log`의 `--numstat` 출력을 구조화된 데이터로 변환하는 거예요.

```typescript
// src/analyzer/git-log-parser.ts
import { simpleGit } from 'simple-git';

interface CommitStat {
  hash: string;
  author: string;
  email: string;
  date: Date;
  files: FileChange[];
}

interface FileChange {
  path: string;
  additions: number;
  deletions: number;
}

export async function parseGitLog(
  repoPath: string,
  since = '6 months ago'
): Promise<CommitStat[]> {
  const git = simpleGit(repoPath);

  const log = await git.raw([
    'log',
    `--since="${since}"`,
    '--numstat',
    '--format=COMMIT|%H|%an|%ae|%aI',
    '--no-merges',
  ]);

  const commits: CommitStat[] = [];
  let current: CommitStat | null = null;

  for (const line of log.split('\n')) {
    if (line.startsWith('COMMIT|')) {
      const [, hash, author, email, date] = line.split('|');
      current = { hash, author, email, date: new Date(date), files: [] };
      commits.push(current);
    } else if (current && line.match(/^\d+\t\d+\t/)) {
      const [additions, deletions, path] = line.split('\t');
      current.files.push({
        path,
        additions: parseInt(additions) || 0,
        deletions: parseInt(deletions) || 0,
      });
    }
  }

  return commits;
}
```

**왜 `--no-merges` 옵션을 넣었나요?**

머지 커밋은 실제 코드를 작성한 사람의 기여가 아니라 브랜치를 통합한 행위만 기록해요. 오너십 분석에서 이걸 포함하면 특정 사람(보통 팀 리드)의 기여도가 과대 측정돼요.

### Step 3: 오너십 점수 계산

단순히 "커밋 수"로 오너십을 매기면 정확하지 않아요. 최근 기여에 더 높은 가중치를 줘야 해요.

```typescript
// src/analyzer/ownership-calculator.ts
interface OwnershipScore {
  path: string;
  owners: { author: string; score: number; percentage: number }[];
  totalCommits: number;
  lastModified: Date;
}

export function calculateOwnership(
  commits: CommitStat[],
  options = { decayWeeks: 12, minCommits: 2 }
): Map<string, OwnershipScore> {
  const fileScores = new Map<string, Map<string, number>>();
  const fileMeta = new Map<string, { commits: number; lastModified: Date }>();
  const now = Date.now();

  for (const commit of commits) {
    // 시간 기반 감쇠: 최근 커밋일수록 가중치 높음
    const weeksAgo = (now - commit.date.getTime()) / (7 * 24 * 60 * 60 * 1000);
    const timeWeight = Math.exp(-weeksAgo / options.decayWeeks);

    for (const file of commit.files) {
      // 변경량 가중치: 큰 변경일수록 깊은 이해
      const changeWeight = Math.log2(file.additions + file.deletions + 1);
      const score = timeWeight * changeWeight;

      if (!fileScores.has(file.path)) {
        fileScores.set(file.path, new Map());
      }
      const authors = fileScores.get(file.path)!;
      authors.set(commit.author, (authors.get(commit.author) || 0) + score);

      const meta = fileMeta.get(file.path) || { commits: 0, lastModified: commit.date };
      meta.commits++;
      if (commit.date > meta.lastModified) meta.lastModified = commit.date;
      fileMeta.set(file.path, meta);
    }
  }

  // 디렉토리 단위 집계
  const results = new Map<string, OwnershipScore>();

  for (const [path, authors] of fileScores) {
    const totalScore = Array.from(authors.values()).reduce((a, b) => a + b, 0);
    const sorted = Array.from(authors.entries())
      .map(([author, score]) => ({
        author,
        score,
        percentage: Math.round((score / totalScore) * 100),
      }))
      .sort((a, b) => b.score - a.score);

    const meta = fileMeta.get(path)!;
    if (meta.commits >= options.minCommits) {
      results.set(path, {
        path,
        owners: sorted,
        totalCommits: meta.commits,
        lastModified: meta.lastModified,
      });
    }
  }

  return results;
}
```

**시간 감쇠(decay) 공식이 핵심이에요.** 6개월 전에 파일을 만든 사람보다 지난주에 버그를 고친 사람이 현재 더 잘 알 가능성이 높아요. `decayWeeks: 12`는 약 3개월 전 커밋의 가중치가 절반으로 줄어드는 설정이에요.

### Step 4: 변경 빈도 핫스팟 탐지

자주 바뀌는 파일은 버그가 숨어 있거나, 설계가 불안정하거나, 여러 팀이 동시에 건드리는 곳이에요. 이걸 빠르게 찾아야 해요.

```typescript
// src/analyzer/churn-detector.ts
interface HotSpot {
  path: string;
  churnScore: number;
  uniqueAuthors: number;
  changeFrequency: number;  // 주당 변경 횟수
  riskLevel: 'low' | 'medium' | 'high' | 'critical';
}

export function detectHotSpots(
  commits: CommitStat[],
  weeks = 12
): HotSpot[] {
  const fileStats = new Map<string, {
    changes: number;
    authors: Set<string>;
    totalLines: number;
  }>();

  for (const commit of commits) {
    for (const file of commit.files) {
      const stats = fileStats.get(file.path) || {
        changes: 0,
        authors: new Set(),
        totalLines: 0,
      };
      stats.changes++;
      stats.authors.add(commit.author);
      stats.totalLines += file.additions + file.deletions;
      fileStats.set(file.path, stats);
    }
  }

  return Array.from(fileStats.entries())
    .map(([path, stats]) => {
      const changeFrequency = stats.changes / weeks;
      // 변경 빈도 x 작성자 수 = 충돌 위험도
      const churnScore = changeFrequency * stats.authors.size;

      return {
        path,
        churnScore,
        uniqueAuthors: stats.authors.size,
        changeFrequency,
        riskLevel: churnScore > 5 ? 'critical'
          : churnScore > 3 ? 'high'
          : churnScore > 1 ? 'medium'
          : 'low',
      };
    })
    .sort((a, b) => b.churnScore - a.score)
    .slice(0, 50);
}
```

### Step 5: CODEOWNERS 자동 생성

분석 결과를 바탕으로 GitHub CODEOWNERS 파일을 자동으로 만들어요.

```typescript
// src/generator/codeowners.ts
export function generateCodeowners(
  ownership: Map<string, OwnershipScore>,
  teamMap: Map<string, string>,  // author → @team/handle
  threshold = 30  // 최소 30% 이상 기여자만 포함
): string {
  const lines: string[] = [
    '# 이 파일은 git 히스토리 기반으로 자동 생성됩니다',
    `# 마지막 업데이트: ${new Date().toISOString().split('T')[0]}`,
    `# 기준: 최근 6개월 커밋, 최소 기여도 ${threshold}%`,
    '',
  ];

  // 디렉토리 단위로 집계
  const dirOwnership = aggregateByDirectory(ownership);

  for (const [dir, owners] of dirOwnership) {
    const qualified = owners
      .filter(o => o.percentage >= threshold)
      .map(o => teamMap.get(o.author) || `@${o.author}`)
      .slice(0, 3);  // 최대 3명

    if (qualified.length > 0) {
      lines.push(`${dir}/ ${qualified.join(' ')}`);
    }
  }

  return lines.join('\n');
}
```

### Step 6: 터미널 대시보드

`blessed-contrib`를 써서 터미널에서 바로 대시보드를 볼 수 있어요.

```typescript
// src/dashboard/terminal-ui.ts
import contrib from 'blessed-contrib';
import blessed from 'blessed';

export function renderDashboard(
  ownership: Map<string, OwnershipScore>,
  hotspots: HotSpot[]
) {
  const screen = blessed.screen({ smartCSR: true });
  const grid = new contrib.grid({ rows: 12, cols: 12, screen });

  // 좌상단: 디렉토리별 오너십 트리맵
  const treemap = grid.set(0, 0, 6, 6, contrib.tree, {
    label: ' Directory Ownership ',
    style: { border: { fg: 'cyan' } },
  });

  // 우상단: 핫스팟 테이블
  const table = grid.set(0, 6, 6, 6, contrib.table, {
    label: ' Change Hotspots ',
    columnWidth: [40, 10, 8, 10],
    keys: true,
    vi: true,
  });

  table.setData({
    headers: ['File', 'Churn', 'Authors', 'Risk'],
    data: hotspots.slice(0, 20).map(h => [
      h.path.length > 38 ? '...' + h.path.slice(-35) : h.path,
      h.churnScore.toFixed(1),
      String(h.uniqueAuthors),
      h.riskLevel.toUpperCase(),
    ]),
  });

  // 하단: 팀별 기여도 바 차트
  const bar = grid.set(6, 0, 6, 12, contrib.bar, {
    label: ' Team Contribution (last 3 months) ',
    barWidth: 12,
    maxHeight: 100,
  });

  screen.key(['escape', 'q', 'C-c'], () => process.exit(0));
  screen.render();
}
```

```bash
# 대시보드 실행
npx tsx src/cli.ts dashboard --path /path/to/monorepo

# 결과 예시 (터미널):
# ┌─ Directory Ownership ─────┐┌─ Change Hotspots ──────────┐
# │ src/api/   @kim (62%)     ││ src/api/auth.ts    5.2  H  │
# │ src/web/   @park (45%)    ││ src/shared/utils.ts 4.1 H  │
# │ packages/  @lee (38%)     ││ config/webpack.ts  3.8  M  │
# └───────────────────────────┘└────────────────────────────┘
# ┌─ Team Contribution ────────────────────────────────────┐
# │ ████████████ api-team: 34%                              │
# │ █████████    web-team: 28%                              │
# │ ██████       platform: 22%                              │
# └────────────────────────────────────────────────────────┘
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 분석 로직 구현 | `git log 파서를 TypeScript로 만들어줘. --numstat 출력에서 파일별 커밋자와 변경량을 추출해야 해` |
| 시각화 개선 | `blessed-contrib 트리맵에 디렉토리별 오너십 비율을 색상으로 표시해줘` |
| 테스트 작성 | `ownership-calculator.ts에 대한 단위 테스트를 만들어줘. 시간 감쇠가 제대로 적용되는지 검증해야 해` |
| CODEOWNERS 생성 | `우리 레포의 git 히스토리를 분석해서 CODEOWNERS 파일을 자동 생성해줘. 기여도 30% 이상인 사람만 포함` |
| 핫스팟 분석 | `최근 3개월간 가장 많이 변경된 파일 20개를 찾고, 각 파일의 주요 커미터를 알려줘` |
| 팀 매핑 설정 | `이 JSON으로 커미터→팀 매핑 파일을 만들고, CODEOWNERS에 @team 핸들로 변환해줘` |

## CLAUDE.md 예시

이 프로젝트에 AI 에이전트를 투입할 때 사용할 CLAUDE.md 템플릿이에요.

```markdown
# ai-monorepo-ownership-dashboard

## 프로젝트 개요
git 히스토리 기반 코드 오너십 분석 CLI 도구.
모노레포에서 파일/디렉토리별 실제 오너와 변경 핫스팟을 시각화.

## 기술 스택
- TypeScript + tsx (런타임)
- simple-git (git 인터페이스)
- blessed-contrib (터미널 UI)
- vitest (테스트)

## 규칙
- git log 파싱 로직은 --numstat 형식에 의존. 포맷 변경 시 파서 수정 필요
- 오너십 점수는 시간 감쇠 + 변경량 가중치 복합. 단순 커밋 카운트 사용 금지
- CODEOWNERS 생성 시 기여도 30% 미만은 자동 제외
- 터미널 UI는 blessed 기반. 최소 80x24 터미널 크기 필요

## 테스트
vitest 실행: npm test
fixtures/sample-git-log.txt로 파서 테스트
```

## 확장 아이디어

- **GitHub Actions 연동**: PR에서 변경된 파일의 실제 오너에게 자동 리뷰 요청
- **Slack 알림**: "이 디렉토리의 오너가 3개월째 커밋이 없습니다" 경고
- **웹 대시보드**: Next.js + D3.js로 브라우저 기반 인터랙티브 트리맵
- **PR 코멘트 봇**: "이 파일의 주요 기여자 @kim, @park에게 리뷰를 추천합니다"

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
