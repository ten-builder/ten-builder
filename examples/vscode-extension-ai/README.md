# VS Code Extension AI 자동 생성 예제

> AI 코딩 에이전트로 VS Code 확장을 프로토타이핑하고 배포까지 — 스캐폴딩부터 Webview, 테스트, 패키징 전 과정

## 이 예제에서 배울 수 있는 것

- AI 에이전트로 VS Code 확장 프로젝트를 빠르게 스캐폴딩하는 방법
- Extension API의 핵심 패턴 — Command, Webview, TreeView, StatusBar
- AI에게 확장 로직을 단계적으로 위임하는 프롬프트 전략
- 테스트 작성과 `vsce` 패키징까지 한 번에 처리하는 워크플로우

## 프로젝트 구조

```
vscode-extension-ai/
├── .vscode/
│   ├── launch.json          # Extension Host 디버그 설정
│   └── tasks.json           # 빌드 태스크
├── src/
│   ├── extension.ts         # 진입점 — activate/deactivate
│   ├── commands/
│   │   ├── analyzeCode.ts   # 코드 분석 커맨드
│   │   └── generateDocs.ts  # 문서 생성 커맨드
│   ├── providers/
│   │   ├── sidebarView.ts   # Webview 사이드바
│   │   └── hoverProvider.ts # 호버 정보 제공
│   └── utils/
│       ├── config.ts        # 설정 관리
│       └── telemetry.ts     # 사용 통계
├── webview/
│   ├── index.html           # Webview UI
│   └── main.js              # Webview 스크립트
├── test/
│   └── suite/
│       ├── extension.test.ts
│       └── commands.test.ts
├── package.json              # 확장 매니페스트 + contributes
├── tsconfig.json
└── .vscodeignore
```

## 시작하기

### Step 1: 스캐폴딩

Yeoman 제너레이터로 프로젝트를 생성해요.

```bash
npm install -g yo generator-code
yo code
```

선택 옵션:

| 항목 | 값 |
|------|-----|
| Type | New Extension (TypeScript) |
| Name | ai-code-assistant |
| Identifier | ai-code-assistant |
| Description | AI 기반 코드 분석 및 문서 생성 |
| Bundler | esbuild |

### Step 2: AI에게 핵심 기능 구현 위임

```
이 VS Code 확장에 두 가지 커맨드를 추가해줘:

1. "AI: Analyze Code" — 현재 열린 파일의 코드를 분석해서
   복잡도, 개선 포인트, 잠재 버그를 사이드바에 표시
2. "AI: Generate Docs" — 선택한 함수의 JSDoc/TSDoc을 자동 생성

package.json의 contributes에 커맨드를 등록하고,
src/commands/ 폴더에 각 커맨드 핸들러를 만들어줘.
```

## 핵심 코드

### extension.ts — 진입점

```typescript
import * as vscode from 'vscode';
import { analyzeCode } from './commands/analyzeCode';
import { generateDocs } from './commands/generateDocs';
import { SidebarViewProvider } from './providers/sidebarView';

export function activate(context: vscode.ExtensionContext) {
  // 커맨드 등록
  const analyzeDisposable = vscode.commands.registerCommand(
    'ai-assistant.analyzeCode',
    () => analyzeCode(context)
  );

  const docsDisposable = vscode.commands.registerCommand(
    'ai-assistant.generateDocs',
    () => generateDocs()
  );

  // 사이드바 Webview 등록
  const sidebarProvider = new SidebarViewProvider(context.extensionUri);
  const sidebarDisposable = vscode.window.registerWebviewViewProvider(
    'ai-assistant-sidebar',
    sidebarProvider
  );

  context.subscriptions.push(
    analyzeDisposable,
    docsDisposable,
    sidebarDisposable
  );
}

export function deactivate() {}
```

**왜 이렇게 했나요?**

`activate` 함수에서 모든 커맨드와 프로바이더를 등록하고 `subscriptions`에 추가하면, 확장이 비활성화될 때 자동으로 정리돼요. 메모리 누수를 방지하는 VS Code 확장의 기본 패턴이에요.

### commands/analyzeCode.ts — 코드 분석

```typescript
import * as vscode from 'vscode';

interface AnalysisResult {
  complexity: string;
  suggestions: string[];
  potentialBugs: string[];
}

export async function analyzeCode(
  context: vscode.ExtensionContext
): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    vscode.window.showWarningMessage('열린 파일이 없어요.');
    return;
  }

  const document = editor.document;
  const code = document.getText();
  const language = document.languageId;

  // 분석 진행 표시
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: '코드 분석 중...',
      cancellable: false,
    },
    async () => {
      const result = await performAnalysis(code, language);
      showAnalysisResult(result);
    }
  );
}

async function performAnalysis(
  code: string,
  language: string
): Promise<AnalysisResult> {
  // 여기에 실제 분석 로직 또는 외부 API 호출
  const lines = code.split('\n');
  const functionCount = lines.filter(
    (l) => l.includes('function ') || l.includes('=>')
  ).length;

  return {
    complexity: functionCount > 20 ? '높음' : functionCount > 10 ? '중간' : '낮음',
    suggestions: [
      `함수 ${functionCount}개 감지 — 10개 이상이면 모듈 분리를 고려하세요`,
      lines.length > 300
        ? '파일이 300줄을 넘어요. 책임 분리를 검토하세요'
        : '파일 길이 적절해요',
    ],
    potentialBugs: lines.some((l) => l.includes('any'))
      ? ['TypeScript `any` 타입 사용 감지 — 구체적 타입으로 교체를 권장해요']
      : [],
  };
}

function showAnalysisResult(result: AnalysisResult): void {
  const panel = vscode.window.createWebviewPanel(
    'analysisResult',
    '코드 분석 결과',
    vscode.ViewColumn.Beside,
    {}
  );

  panel.webview.html = `
    <!DOCTYPE html>
    <html>
    <body>
      <h2>분석 결과</h2>
      <p><strong>복잡도:</strong> ${result.complexity}</p>
      <h3>개선 제안</h3>
      <ul>${result.suggestions.map((s) => `<li>${s}</li>`).join('')}</ul>
      <h3>잠재 이슈</h3>
      <ul>${result.potentialBugs.map((b) => `<li>${b}</li>`).join('')}</ul>
    </body>
    </html>
  `;
}
```

**왜 이렇게 했나요?**

`withProgress`로 사용자에게 분석 진행 상태를 보여주고, 결과를 Webview 패널에 표시해요. VS Code의 네이티브 UI 패턴을 따르면 사용자 경험이 일관돼요.

### providers/sidebarView.ts — Webview 사이드바

```typescript
import * as vscode from 'vscode';

export class SidebarViewProvider implements vscode.WebviewViewProvider {
  constructor(private readonly extensionUri: vscode.Uri) {}

  resolveWebviewView(
    webviewView: vscode.WebviewView,
    _context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken
  ): void {
    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this.extensionUri],
    };

    webviewView.webview.html = this.getHtml(webviewView.webview);

    // Webview → Extension 메시지 수신
    webviewView.webview.onDidReceiveMessage((message) => {
      switch (message.command) {
        case 'analyze':
          vscode.commands.executeCommand('ai-assistant.analyzeCode');
          break;
        case 'generateDocs':
          vscode.commands.executeCommand('ai-assistant.generateDocs');
          break;
      }
    });
  }

  private getHtml(webview: vscode.Webview): string {
    return `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { padding: 10px; font-family: var(--vscode-font-family); }
          button {
            width: 100%;
            padding: 8px;
            margin: 4px 0;
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
            border: none;
            cursor: pointer;
            border-radius: 4px;
          }
          button:hover {
            background: var(--vscode-button-hoverBackground);
          }
          .section { margin-bottom: 16px; }
          h3 { margin: 0 0 8px 0; }
        </style>
      </head>
      <body>
        <div class="section">
          <h3>AI 코드 어시스턴트</h3>
          <button onclick="send('analyze')">코드 분석</button>
          <button onclick="send('generateDocs')">문서 생성</button>
        </div>
        <div class="section" id="result"></div>
        <script>
          const vscode = acquireVsCodeApi();
          function send(command) {
            vscode.postMessage({ command });
          }
        </script>
      </body>
      </html>
    `;
  }
}
```

**왜 이렇게 했나요?**

Webview 사이드바는 `registerWebviewViewProvider`로 등록해요. CSS 변수(`--vscode-*`)를 사용하면 VS Code 테마와 자연스럽게 어울려요. `acquireVsCodeApi()`로 확장과 양방향 통신이 가능해요.

### package.json — contributes 설정

```json
{
  "name": "ai-code-assistant",
  "displayName": "AI Code Assistant",
  "version": "0.1.0",
  "engines": { "vscode": "^1.85.0" },
  "categories": ["Other"],
  "activationEvents": [],
  "main": "./dist/extension.js",
  "contributes": {
    "commands": [
      {
        "command": "ai-assistant.analyzeCode",
        "title": "AI: Analyze Code",
        "category": "AI Assistant"
      },
      {
        "command": "ai-assistant.generateDocs",
        "title": "AI: Generate Docs",
        "category": "AI Assistant"
      }
    ],
    "viewsContainers": {
      "activitybar": [
        {
          "id": "ai-assistant",
          "title": "AI Assistant",
          "icon": "resources/icon.svg"
        }
      ]
    },
    "views": {
      "ai-assistant": [
        {
          "type": "webview",
          "id": "ai-assistant-sidebar",
          "name": "AI Assistant"
        }
      ]
    },
    "configuration": {
      "title": "AI Code Assistant",
      "properties": {
        "ai-assistant.analysisDepth": {
          "type": "string",
          "default": "standard",
          "enum": ["quick", "standard", "deep"],
          "description": "코드 분석 깊이를 설정해요"
        }
      }
    }
  }
}
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 스캐폴딩 | `VS Code 확장 프로젝트를 TypeScript + esbuild로 초기화해줘. 사이드바 Webview 포함.` |
| 커맨드 추가 | `package.json contributes에 "Format Selection" 커맨드를 등록하고 핸들러를 만들어줘` |
| Webview UI | `React로 사이드바 UI를 만들어줘. VS Code 테마 CSS 변수를 사용해서.` |
| TreeView | `파일 시스템을 트리로 보여주는 TreeDataProvider를 구현해줘` |
| 테스트 | `commands/analyzeCode.ts에 대한 유닛 테스트를 작성해줘. vscode 모듈은 mock 처리` |
| 패키징 | `vsce로 패키징하기 전에 필요한 설정을 점검하고 .vscodeignore를 최적화해줘` |

## 테스트 작성

### test/suite/extension.test.ts

```typescript
import * as assert from 'assert';
import * as vscode from 'vscode';

suite('Extension Test Suite', () => {
  test('확장이 활성화되어야 한다', async () => {
    const extension = vscode.extensions.getExtension(
      'undefined_publisher.ai-code-assistant'
    );
    assert.ok(extension);
    await extension!.activate();
    assert.strictEqual(extension!.isActive, true);
  });

  test('analyzeCode 커맨드가 등록되어야 한다', async () => {
    const commands = await vscode.commands.getCommands(true);
    assert.ok(commands.includes('ai-assistant.analyzeCode'));
  });

  test('generateDocs 커맨드가 등록되어야 한다', async () => {
    const commands = await vscode.commands.getCommands(true);
    assert.ok(commands.includes('ai-assistant.generateDocs'));
  });
});
```

### AI에게 테스트 보강 요청

```
analyzeCode 함수의 유닛 테스트를 추가해줘:
1. 에디터가 열리지 않은 경우 경고 메시지 표시
2. TypeScript 파일 분석 시 'any' 타입 감지
3. 300줄 이상 파일에서 경고 생성
vscode 모듈은 sinon으로 stub 처리해줘.
```

## 패키징과 배포

### Step 1: 패키징 전 점검

```bash
# vsce 설치
npm install -g @vscode/vsce

# 패키징 전 검증
vsce ls
```

### Step 2: VSIX 파일 생성

```bash
vsce package
# ai-code-assistant-0.1.0.vsix 생성
```

### Step 3: 로컬 설치 테스트

```bash
code --install-extension ai-code-assistant-0.1.0.vsix
```

| 배포 옵션 | 설명 |
|-----------|------|
| Marketplace | `vsce publish`로 공개 배포 |
| Private | VSIX 파일을 팀 내부 공유 |
| Open VSX | VS Code 대안 마켓에 등록 |

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| Webview가 빈 화면 | `enableScripts: true` 확인, CSP 헤더 점검 |
| 커맨드가 팔레트에 안 보임 | `contributes.commands`에 등록했는지 확인 |
| 디버그가 안 됨 | `launch.json`에 Extension Host 설정 확인 |
| `vsce package` 실패 | `publisher` 필드 누락, README.md 없음 체크 |
| Webview 스타일 깨짐 | `--vscode-*` CSS 변수 사용, 테마별 테스트 |

## 확장 아이디어

이 예제를 기반으로 만들어볼 수 있는 확장들이에요:

- **코드 스니펫 매니저** — 자주 쓰는 패턴을 AI가 추천
- **Git 커밋 메시지 생성기** — diff 분석 후 커밋 메시지 제안
- **API 클라이언트** — Webview에서 REST API 테스트
- **프로젝트 대시보드** — 코드 통계, TODO, 의존성 현황 시각화

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
