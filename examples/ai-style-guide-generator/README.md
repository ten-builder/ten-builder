# AI 에이전트 기반 코드 리뷰 스타일 가이드 생성기

> 레포의 기존 코드 패턴을 AI 에이전트로 분석해서 팀 스타일 가이드와 ESLint 룰을 자동으로 뽑아내는 예제 프로젝트

## 이 예제에서 배울 수 있는 것

- AI 에이전트로 기존 코드베이스를 분석하여 암묵적 컨벤션을 발굴하는 방법
- 분석 결과를 `guidelines.md`와 ESLint 설정 파일로 자동 변환하는 파이프라인
- 팀 코딩 스타일을 문서화하고 신규 개발자 온보딩에 활용하는 패턴

## 프로젝트 구조

```
ai-style-guide-generator/
├── .github/
│   └── workflows/
│       └── generate-style-guide.yml  # 수동 트리거 워크플로우
├── scripts/
│   ├── analyze.ts                    # 코드베이스 분석 메인
│   ├── file-sampler.ts               # 대표 파일 샘플링
│   ├── pattern-extractor.ts          # AI 패턴 추출
│   ├── rule-generator.ts             # ESLint 룰 생성
│   └── docs-writer.ts                # guidelines.md 작성
├── prompts/
│   ├── analyze-conventions.md        # 컨벤션 분석 프롬프트
│   └── generate-rules.md             # 룰 생성 프롬프트
├── output/
│   ├── guidelines.md                 # 생성된 스타일 가이드
│   └── .eslintrc-ai.json             # 생성된 ESLint 설정
├── package.json
├── tsconfig.json
└── README.md
```

## 시작하기

```bash
git clone https://github.com/your-org/your-repo.git target-repo
cd ai-style-guide-generator
npm install

# 분석 대상 레포 경로와 API 키 설정
export TARGET_REPO_PATH=../target-repo
export ANTHROPIC_API_KEY=your_key_here

# 분석 실행
npx tsx scripts/analyze.ts
```

## 핵심 코드

### 1. 대표 파일 샘플링 (`file-sampler.ts`)

모든 파일을 AI에 넘기면 컨텍스트 윈도우가 금방 차므로, 각 디렉토리에서 가장 최근 수정된 파일과 가장 많이 변경된 파일을 선별합니다.

```typescript
// file-sampler.ts
import { execSync } from 'child_process'
import * as fs from 'fs'
import * as path from 'path'

export interface SampledFile {
  path: string
  content: string
  commitCount: number
}

export function sampleFiles(repoPath: string, maxFiles = 30): SampledFile[] {
  // git log로 변경 빈도 높은 파일 추출
  const hotFiles = execSync(
    `cd ${repoPath} && git log --name-only --pretty=format: --diff-filter=M | sort | uniq -c | sort -rn | head -50`,
    { encoding: 'utf8' }
  )
    .trim()
    .split('\n')
    .map(line => {
      const match = line.trim().match(/^(\d+)\s+(.+)$/)
      return match ? { commitCount: parseInt(match[1]), filePath: match[2] } : null
    })
    .filter(Boolean)

  // 확장자 필터 (TS/JS/Python/Go 등)
  const targetExts = ['.ts', '.tsx', '.js', '.jsx', '.py', '.go', '.java']
  const filtered = hotFiles
    .filter(f => targetExts.some(ext => f!.filePath.endsWith(ext)))
    .slice(0, maxFiles)

  return filtered
    .map(f => {
      const fullPath = path.join(repoPath, f!.filePath)
      if (!fs.existsSync(fullPath)) return null
      const content = fs.readFileSync(fullPath, 'utf8')
      // 너무 긴 파일은 앞 100줄만
      const lines = content.split('\n').slice(0, 100).join('\n')
      return { path: f!.filePath, content: lines, commitCount: f!.commitCount }
    })
    .filter(Boolean) as SampledFile[]
}
```

**왜 이렇게 했나요?**

변경 빈도가 높은 파일일수록 팀이 실제로 자주 작업하는 파일입니다. 이런 파일에서 추출한 패턴이 팀의 진짜 컨벤션을 반영합니다. 잘 건드리지 않는 레거시 파일보다 훨씬 신뢰도가 높아요.

### 2. AI 패턴 추출 (`pattern-extractor.ts`)

```typescript
// pattern-extractor.ts
import Anthropic from '@anthropic-ai/sdk'
import { SampledFile } from './file-sampler'

const client = new Anthropic()

export interface ConventionReport {
  naming: string[]
  errorHandling: string[]
  imports: string[]
  codeStructure: string[]
  comments: string[]
  testing: string[]
}

export async function extractPatterns(
  files: SampledFile[]
): Promise<ConventionReport> {
  // 파일을 청크로 나눠서 처리 (컨텍스트 한계 대응)
  const chunks = chunkFiles(files, 10)
  const partialReports: ConventionReport[] = []

  for (const chunk of chunks) {
    const fileContent = chunk
      .map(f => `\`\`\`\n// FILE: ${f.path}\n${f.content}\n\`\`\``)
      .join('\n\n')

    const response = await client.messages.create({
      model: 'claude-opus-4-5',
      max_tokens: 2000,
      system: `당신은 코드 컨벤션 분석 전문가입니다. 주어진 코드 파일들에서 팀이 암묵적으로 따르는 코딩 패턴을 JSON 형식으로 추출하세요.
      
응답 형식:
{
  "naming": ["컨벤션 1", "컨벤션 2"],
  "errorHandling": ["패턴 1"],
  "imports": ["패턴 1"],
  "codeStructure": ["패턴 1"],
  "comments": ["패턴 1"],
  "testing": ["패턴 1"]
}

각 항목은 구체적이고 실행 가능한 규칙으로 작성하세요.`,
      messages: [
        {
          role: 'user',
          content: `다음 코드 파일들을 분석해서 팀 컨벤션을 추출해주세요:\n\n${fileContent}`,
        },
      ],
    })

    const text = response.content[0].type === 'text' ? response.content[0].text : ''
    try {
      const parsed = JSON.parse(text.match(/\{[\s\S]*\}/)?.[0] || '{}')
      partialReports.push(parsed)
    } catch {
      // 파싱 실패 시 스킵
    }
  }

  // 여러 청크 결과 병합
  return mergeReports(partialReports)
}

function chunkFiles<T>(arr: T[], size: number): T[][] {
  return Array.from({ length: Math.ceil(arr.length / size) }, (_, i) =>
    arr.slice(i * size, i * size + size)
  )
}

function mergeReports(reports: ConventionReport[]): ConventionReport {
  const merged: ConventionReport = {
    naming: [], errorHandling: [], imports: [],
    codeStructure: [], comments: [], testing: []
  }
  for (const report of reports) {
    for (const key of Object.keys(merged) as (keyof ConventionReport)[]) {
      if (Array.isArray(report[key])) {
        merged[key] = [...new Set([...merged[key], ...report[key]])]
      }
    }
  }
  return merged
}
```

### 3. guidelines.md 자동 생성 (`docs-writer.ts`)

```typescript
// docs-writer.ts
import Anthropic from '@anthropic-ai/sdk'
import * as fs from 'fs'
import { ConventionReport } from './pattern-extractor'

const client = new Anthropic()

export async function writeGuidelines(
  report: ConventionReport,
  repoName: string
): Promise<void> {
  const response = await client.messages.create({
    model: 'claude-opus-4-5',
    max_tokens: 4000,
    messages: [
      {
        role: 'user',
        content: `다음 컨벤션 분석 결과를 바탕으로 ${repoName} 프로젝트의 공식 코딩 스타일 가이드(guidelines.md)를 작성해주세요.
        
분석 결과:
${JSON.stringify(report, null, 2)}

요구사항:
- Claude Code나 Cursor에서 CLAUDE.md / .cursorrules로 바로 쓸 수 있는 형식
- 각 규칙에 간단한 이유 설명 포함
- 나쁜 예시 / 좋은 예시 코드 포함
- 신규 개발자가 읽고 바로 따라할 수 있는 수준`,
      },
    ],
  })

  const content = response.content[0].type === 'text' ? response.content[0].text : ''
  fs.writeFileSync('output/guidelines.md', content, 'utf8')
  console.log('guidelines.md 생성 완료')
}
```

## GitHub Actions 워크플로우

```yaml
# .github/workflows/generate-style-guide.yml
name: Generate Style Guide

on:
  workflow_dispatch:
    inputs:
      update_existing:
        description: '기존 guidelines.md 업데이트 여부'
        type: boolean
        default: true

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # 전체 커밋 히스토리 필요

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - run: npm ci

      - name: Analyze and Generate
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: npx tsx scripts/analyze.ts

      - name: Create PR with Generated Files
        uses: peter-evans/create-pull-request@v6
        with:
          title: 'docs: AI 분석 기반 스타일 가이드 업데이트'
          body: |
            AI 에이전트가 코드베이스를 분석해서 스타일 가이드를 갱신했습니다.
            
            변경 파일:
            - `output/guidelines.md`
            - `output/.eslintrc-ai.json`
          branch: style-guide/ai-generated
          commit-message: 'docs: update style guide from AI analysis'
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 컨벤션 분석 후 추가 정리 | `위 컨벤션 중 서로 충돌하는 규칙이 있으면 팀 코드 비율을 기준으로 하나로 통일해줘` |
| ESLint 룰 변환 | `이 컨벤션을 ESLint custom rule (AST 기반)로 구현해줘. 테스트 케이스도 포함해서` |
| 온보딩 문서화 | `신규 개발자가 처음 PR을 올리기 전 반드시 알아야 할 상위 5개 규칙만 추려줘` |
| 규칙 충돌 해소 | `Prettier 설정과 충돌하는 규칙이 있으면 알려줘` |

## 더 발전시키기

- **주기적 갱신:** 월 1회 CI에서 자동 실행해 코드베이스가 변할수록 가이드도 따라가도록 설정
- **점수 측정:** 현재 코드가 생성된 가이드를 얼마나 따르는지 준수율을 점수로 출력
- **Claude Code 연동:** 생성된 `guidelines.md`를 `CLAUDE.md`에 포함시켜 에이전트가 항상 참고하도록

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
