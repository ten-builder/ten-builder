# AI 시맨틱 Diff 파이프라인

> 라인 기반 diff를 넘어서 — AST 분석과 의존성 추적으로 코드 변경의 진짜 의미를 파악하는 CI 파이프라인

## 개요

`git diff`가 보여주는 건 "어떤 줄이 바뀌었는지"예요. 하지만 개발자가 리뷰할 때 정말 알고 싶은 건 "이 변경이 어디에 영향을 미치는지"죠.

시맨틱 Diff 파이프라인은 코드의 구조(AST)를 분석해서 단순 포맷 변경과 로직 변경을 구분하고, 변경된 함수가 어디서 호출되는지 의존성 그래프로 추적해요. 여기에 AI를 더하면 변경 의도를 자연어로 요약하고, 적합한 리뷰어를 자동으로 할당할 수 있어요.

## 사전 준비

- Node.js 18+ 또는 Python 3.10+
- GitHub Actions (또는 다른 CI/CD)
- AI 코딩 에이전트 (Claude Code, Cursor 등)
- `tree-sitter` 또는 언어별 AST 파서

## 설정

### Step 1: AST 기반 Diff 분석기 구성

AST(Abstract Syntax Tree) 파서로 코드 변경을 구조적으로 분석해요.

```python
# semantic_diff.py
import ast
import sys
from dataclasses import dataclass

@dataclass
class SemanticChange:
    change_type: str      # "function_modified", "class_added", "import_changed"
    name: str             # 변경된 심볼 이름
    file_path: str
    impact_level: str     # "high", "medium", "low"
    description: str

def parse_function_signatures(source: str) -> dict:
    """파일에서 모든 함수/메서드의 시그니처를 추출"""
    tree = ast.parse(source)
    functions = {}
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            args = [a.arg for a in node.args.args]
            functions[node.name] = {
                "args": args,
                "lineno": node.lineno,
                "decorators": [d.id for d in node.decorator_list
                              if isinstance(d, ast.Name)],
                "body_hash": hash(ast.dump(node))
            }
    return functions

def compare_files(old_source: str, new_source: str, file_path: str) -> list:
    """두 버전의 파일을 AST 수준에서 비교"""
    old_funcs = parse_function_signatures(old_source)
    new_funcs = parse_function_signatures(new_source)
    changes = []

    # 추가된 함수
    for name in set(new_funcs) - set(old_funcs):
        changes.append(SemanticChange(
            change_type="function_added",
            name=name,
            file_path=file_path,
            impact_level="medium",
            description=f"새 함수 `{name}` 추가"
        ))

    # 삭제된 함수
    for name in set(old_funcs) - set(new_funcs):
        changes.append(SemanticChange(
            change_type="function_removed",
            name=name,
            file_path=file_path,
            impact_level="high",
            description=f"함수 `{name}` 삭제 — 호출부 확인 필요"
        ))

    # 시그니처 또는 본문 변경
    for name in set(old_funcs) & set(new_funcs):
        old, new = old_funcs[name], new_funcs[name]
        if old["args"] != new["args"]:
            changes.append(SemanticChange(
                change_type="signature_changed",
                name=name,
                file_path=file_path,
                impact_level="high",
                description=f"`{name}` 시그니처 변경: {old['args']} -> {new['args']}"
            ))
        elif old["body_hash"] != new["body_hash"]:
            changes.append(SemanticChange(
                change_type="logic_changed",
                name=name,
                file_path=file_path,
                impact_level="medium",
                description=f"`{name}` 내부 로직 변경"
            ))

    return changes
```

### Step 2: 의존성 그래프 추적

변경된 함수를 호출하는 다른 파일까지 영향 범위를 추적해요.

```python
# dependency_tracker.py
import os
import ast
import json
from collections import defaultdict

class DependencyGraph:
    """프로젝트 전체의 함수 호출 관계를 맵핑"""

    def __init__(self, project_root: str):
        self.project_root = project_root
        self.call_graph = defaultdict(set)  # caller -> set of callees
        self.reverse_graph = defaultdict(set)  # callee -> set of callers

    def build(self, extensions=(".py",)):
        """프로젝트 전체 파일을 스캔해 호출 관계 수집"""
        for root, _, files in os.walk(self.project_root):
            for f in files:
                if not any(f.endswith(ext) for ext in extensions):
                    continue
                filepath = os.path.join(root, f)
                self._analyze_file(filepath)

    def _analyze_file(self, filepath: str):
        try:
            with open(filepath) as fh:
                tree = ast.parse(fh.read())
        except (SyntaxError, UnicodeDecodeError):
            return

        rel_path = os.path.relpath(filepath, self.project_root)
        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                callee = self._get_call_name(node)
                if callee:
                    self.call_graph[rel_path].add(callee)
                    self.reverse_graph[callee].add(rel_path)

    def get_impacted_files(self, changed_symbol: str, depth: int = 3) -> set:
        """변경된 심볼에 영향받는 파일 목록 (BFS)"""
        visited = set()
        queue = [changed_symbol]
        for _ in range(depth):
            next_queue = []
            for symbol in queue:
                for caller in self.reverse_graph.get(symbol, set()):
                    if caller not in visited:
                        visited.add(caller)
                        next_queue.append(caller)
            queue = next_queue
        return visited

    @staticmethod
    def _get_call_name(node: ast.Call) -> str | None:
        if isinstance(node.func, ast.Name):
            return node.func.id
        if isinstance(node.func, ast.Attribute):
            return node.func.attr
        return None
```

### Step 3: GitHub Actions 워크플로우

```yaml
# .github/workflows/semantic-diff.yml
name: Semantic Diff Analysis

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  semantic-analysis:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Get changed files
        id: changed
        run: |
          FILES=$(git diff --name-only origin/${{ github.base_ref }}...HEAD -- '*.py' '*.ts' '*.js')
          echo "files<<EOF" >> $GITHUB_OUTPUT
          echo "$FILES" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Run semantic diff
        run: |
          python scripts/semantic_diff_runner.py \
            --base origin/${{ github.base_ref }} \
            --head HEAD \
            --output report.json

      - name: Assign reviewers
        if: success()
        run: |
          python scripts/auto_assign_reviewer.py \
            --report report.json \
            --codeowners .github/CODEOWNERS

      - name: Post analysis comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = JSON.parse(fs.readFileSync('report.json', 'utf8'));
            const body = formatReport(report);
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });

            function formatReport(r) {
              let md = `## Semantic Diff Analysis\n\n`;
              md += `| 변경 유형 | 심볼 | 영향도 | 설명 |\n`;
              md += `|----------|------|--------|------|\n`;
              for (const c of r.changes) {
                const badge = c.impact_level === 'high' ? '🔴'
                            : c.impact_level === 'medium' ? '🟡' : '🟢';
                md += `| ${c.change_type} | \`${c.name}\` | ${badge} | ${c.description} |\n`;
              }
              if (r.impacted_files.length > 0) {
                md += `\n### 영향받는 파일 (${r.impacted_files.length}개)\n`;
                for (const f of r.impacted_files) {
                  md += `- \`${f}\`\n`;
                }
              }
              return md;
            }
```

## 사용 방법

### 시나리오 1: 함수 시그니처 변경 감지

인자 이름을 바꾸거나 새 파라미터를 추가하면, 일반 diff에선 한 줄 변경으로 보여요. 시맨틱 diff는 이걸 "시그니처 변경 — 호출부 12곳 확인 필요"로 알려줘요.

### 시나리오 2: 포맷 변경 vs 로직 변경 구분

`black`이나 `prettier` 포매터를 돌리면 수십 줄이 바뀌지만 로직은 동일해요. AST 비교는 이런 노이즈를 자동으로 필터링하고, 실제 로직 변경만 하이라이트해요.

### 시나리오 3: 자동 리뷰어 할당

변경된 함수의 최근 커미터, CODEOWNERS 파일, 의존성 그래프를 조합해서 가장 적합한 리뷰어를 자동 할당해요.

```python
# auto_assign_reviewer.py
import json
import subprocess

def get_recent_authors(file_path: str, limit: int = 5) -> list:
    """파일의 최근 커밋 작성자 목록"""
    result = subprocess.run(
        ["git", "log", f"-{limit}", "--format=%ae", "--", file_path],
        capture_output=True, text=True
    )
    return list(dict.fromkeys(result.stdout.strip().split("\n")))

def suggest_reviewers(report: dict, codeowners: dict) -> list:
    """시맨틱 분석 결과 기반 리뷰어 추천"""
    candidates = {}

    for change in report["changes"]:
        # 영향도가 높은 변경의 관련 작성자에게 가중치 부여
        weight = {"high": 3, "medium": 2, "low": 1}[change["impact_level"]]
        authors = get_recent_authors(change["file_path"])
        for author in authors:
            candidates[author] = candidates.get(author, 0) + weight

    # CODEOWNERS 매칭
    for change in report["changes"]:
        owner = codeowners.get(change["file_path"])
        if owner:
            candidates[owner] = candidates.get(owner, 0) + 5

    # 점수 순 정렬, 상위 2명 추천
    sorted_candidates = sorted(candidates.items(), key=lambda x: -x[1])
    return [c[0] for c in sorted_candidates[:2]]
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `AST_PARSER` | `ast` (Python) | 언어별 파서 (`tree-sitter`로 교체 가능) |
| `DEPTH_LIMIT` | `3` | 의존성 추적 깊이 |
| `IMPACT_THRESHOLD` | `medium` | 이 수준 이상만 리포트에 포함 |
| `AUTO_ASSIGN` | `true` | 리뷰어 자동 할당 여부 |
| `EXCLUDE_PATTERNS` | `["test_*", "*_test.py"]` | 분석 제외 파일 패턴 |

## TypeScript 프로젝트에서 사용하기

TypeScript/JavaScript 프로젝트에선 `tree-sitter`나 `ts-morph`를 쓰면 같은 패턴을 적용할 수 있어요.

```typescript
// semantic-diff.ts
import { Project, SyntaxKind } from "ts-morph";

function analyzeChanges(oldPath: string, newPath: string) {
  const oldProject = new Project();
  const newProject = new Project();

  const oldFile = oldProject.addSourceFileAtPath(oldPath);
  const newFile = newProject.addSourceFileAtPath(newPath);

  const oldFunctions = oldFile.getFunctions().map(f => ({
    name: f.getName(),
    params: f.getParameters().map(p => p.getName()),
    bodyText: f.getBodyText(),
  }));

  const newFunctions = newFile.getFunctions().map(f => ({
    name: f.getName(),
    params: f.getParameters().map(p => p.getName()),
    bodyText: f.getBodyText(),
  }));

  // 시그니처 비교, 본문 비교 등 Python 버전과 동일한 로직
  return compareFunctionSets(oldFunctions, newFunctions);
}
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| AST 파싱 실패 | 문법 오류가 있는 파일은 건너뛰고 라인 diff로 폴백 |
| 대규모 레포에서 느림 | `--changed-only` 플래그로 변경 파일만 분석 |
| 동적 호출 미추적 | `getattr`, 리플렉션 패턴은 정적 분석 한계 — 주석으로 표시 |
| 언어 혼합 프로젝트 | `tree-sitter` 멀티 파서로 언어별 분석기 등록 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
