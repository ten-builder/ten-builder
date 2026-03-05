# Chrome Extension + AI 실전 예제

> Manifest V3 기반 Chrome Extension을 AI 코딩 도구로 처음부터 만드는 단계별 가이드

## 이 예제에서 배울 수 있는 것

- Manifest V3의 Service Worker, Side Panel 구조를 이해하고 셋업하는 방법
- AI 코딩 도구로 보일러플레이트를 빠르게 생성하고 반복 작업을 줄이는 패턴
- Content Script ↔ Background 메시지 통신을 구현하는 실전 워크플로우

## 프로젝트 구조

```
chrome-extension-ai/
├── manifest.json          # Manifest V3 설정
├── src/
│   ├── background.ts      # Service Worker (이벤트 핸들링)
│   ├── content.ts         # Content Script (페이지 DOM 접근)
│   ├── sidepanel/
│   │   ├── index.html     # Side Panel UI
│   │   ├── panel.ts       # Side Panel 로직
│   │   └── panel.css      # 스타일
│   └── utils/
│       ├── storage.ts     # Chrome Storage 래퍼
│       └── messaging.ts   # 메시지 통신 유틸
├── icons/
│   ├── icon-16.png
│   ├── icon-48.png
│   └── icon-128.png
├── tsconfig.json
├── webpack.config.js      # 번들링 설정
└── package.json
```

## 시작하기

### Step 1: 프로젝트 초기화

```bash
mkdir my-chrome-extension && cd my-chrome-extension
pnpm init
pnpm add -D typescript webpack webpack-cli ts-loader copy-webpack-plugin
```

AI에게 프로젝트 구조를 한 번에 요청하면 초기 셋업 시간을 크게 줄일 수 있어요.

```
프롬프트: "Manifest V3 Chrome Extension 프로젝트를 TypeScript + Webpack으로 셋업해줘.
Side Panel과 Content Script가 포함된 구조로 만들어줘."
```

### Step 2: Manifest 설정

```json
{
  "manifest_version": 3,
  "name": "My AI Helper",
  "version": "1.0.0",
  "description": "AI로 만든 생산성 Chrome Extension",
  "permissions": ["storage", "activeTab", "sidePanel"],
  "background": {
    "service_worker": "background.js",
    "type": "module"
  },
  "side_panel": {
    "default_path": "sidepanel/index.html"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"]
    }
  ],
  "action": {
    "default_icon": {
      "16": "icons/icon-16.png",
      "48": "icons/icon-48.png",
      "128": "icons/icon-128.png"
    }
  },
  "icons": {
    "16": "icons/icon-16.png",
    "48": "icons/icon-48.png",
    "128": "icons/icon-128.png"
  }
}
```

Manifest V3에서 `background`는 더 이상 페이지가 아니라 Service Worker예요. 유휴 상태가 되면 자동으로 종료되므로, 전역 변수 대신 `chrome.storage`를 써야 해요.

### Step 3: Service Worker 구현

```typescript
// src/background.ts
chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: true })
  .catch(console.error);

// Content Script에서 메시지 수신
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'PAGE_DATA') {
    // 페이지에서 수집한 데이터 저장
    chrome.storage.local.set({
      pageData: {
        url: sender.tab?.url,
        title: message.title,
        content: message.content,
        timestamp: Date.now(),
      },
    });
    sendResponse({ status: 'saved' });
  }
  return true; // 비동기 응답을 위해 true 반환
});

// 설치 시 초기화
chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.local.set({ settings: { enabled: true, theme: 'light' } });
  console.log('Extension installed');
});
```

### Step 4: Content Script 구현

```typescript
// src/content.ts

// 페이지 텍스트를 추출하는 함수
function extractPageContent(): string {
  const article = document.querySelector('article');
  if (article) return article.innerText.slice(0, 5000);

  const main = document.querySelector('main');
  if (main) return main.innerText.slice(0, 5000);

  return document.body.innerText.slice(0, 3000);
}

// Background로 페이지 데이터 전송
function sendPageData() {
  chrome.runtime.sendMessage({
    type: 'PAGE_DATA',
    title: document.title,
    content: extractPageContent(),
  });
}

// 페이지 로드 완료 후 실행
if (document.readyState === 'complete') {
  sendPageData();
} else {
  window.addEventListener('load', sendPageData);
}
```

### Step 5: Side Panel UI

```html
<!-- src/sidepanel/index.html -->
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <link rel="stylesheet" href="panel.css" />
</head>
<body>
  <div id="app">
    <header>
      <h1>📄 페이지 요약</h1>
    </header>
    <main>
      <div id="page-info">
        <p class="placeholder">페이지를 방문하면 자동으로 정보를 수집해요.</p>
      </div>
      <button id="refresh-btn">새로고침</button>
    </main>
  </div>
  <script src="panel.js"></script>
</body>
</html>
```

```typescript
// src/sidepanel/panel.ts
const pageInfoEl = document.getElementById('page-info')!;
const refreshBtn = document.getElementById('refresh-btn')!;

async function loadPageData() {
  const { pageData } = await chrome.storage.local.get('pageData');

  if (!pageData) {
    pageInfoEl.innerHTML = '<p class="placeholder">아직 수집된 데이터가 없어요.</p>';
    return;
  }

  const timeAgo = getTimeAgo(pageData.timestamp);

  pageInfoEl.innerHTML = `
    <div class="card">
      <h2>${escapeHtml(pageData.title)}</h2>
      <p class="url">${escapeHtml(pageData.url)}</p>
      <p class="time">${timeAgo}</p>
      <div class="content">${escapeHtml(pageData.content.slice(0, 500))}...</div>
    </div>
  `;
}

function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function getTimeAgo(timestamp: number): string {
  const seconds = Math.floor((Date.now() - timestamp) / 1000);
  if (seconds < 60) return '방금 전';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}분 전`;
  return `${Math.floor(seconds / 3600)}시간 전`;
}

// Storage 변경 감지 — 실시간 업데이트
chrome.storage.onChanged.addListener((changes) => {
  if (changes.pageData) loadPageData();
});

refreshBtn.addEventListener('click', loadPageData);
loadPageData();
```

### Step 6: Webpack 설정

```javascript
// webpack.config.js
const path = require('path');
const CopyPlugin = require('copy-webpack-plugin');

module.exports = {
  mode: 'production',
  entry: {
    background: './src/background.ts',
    content: './src/content.ts',
    panel: './src/sidepanel/panel.ts',
  },
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: '[name].js',
    clean: true,
  },
  module: {
    rules: [{ test: /\.ts$/, use: 'ts-loader', exclude: /node_modules/ }],
  },
  resolve: { extensions: ['.ts', '.js'] },
  plugins: [
    new CopyPlugin({
      patterns: [
        { from: 'manifest.json', to: '.' },
        { from: 'src/sidepanel/index.html', to: 'sidepanel/' },
        { from: 'src/sidepanel/panel.css', to: 'sidepanel/' },
        { from: 'icons', to: 'icons' },
      ],
    }),
  ],
};
```

```bash
# 빌드
pnpm webpack

# Chrome에서 로드: chrome://extensions → 개발자 모드 → 압축 해제된 확장 로드 → dist 폴더
```

## 핵심 코드

### Chrome Storage 래퍼

```typescript
// src/utils/storage.ts
type StorageKey = 'settings' | 'pageData';

export async function getStorage<T>(key: StorageKey): Promise<T | undefined> {
  const result = await chrome.storage.local.get(key);
  return result[key] as T | undefined;
}

export async function setStorage<T>(key: StorageKey, value: T): Promise<void> {
  await chrome.storage.local.set({ [key]: value });
}

// 여러 키를 한 번에 읽어야 할 때
export async function getMultiple<T extends Record<string, unknown>>(
  keys: StorageKey[]
): Promise<Partial<T>> {
  return chrome.storage.local.get(keys) as Promise<Partial<T>>;
}
```

**왜 래퍼를 만들었나요?**

`chrome.storage.local.get`은 타입 추론이 안 돼서 매번 타입 캐스팅을 해야 해요. 래퍼를 만들어두면 자동 완성도 되고, 키 이름 오타도 방지할 수 있어요. AI에게 "Storage 래퍼를 만들어줘"라고 요청하면 프로젝트 컨텍스트에 맞게 생성해줘요.

### 메시지 통신 유틸

```typescript
// src/utils/messaging.ts
interface MessageMap {
  PAGE_DATA: { title: string; content: string };
  GET_SETTINGS: undefined;
  UPDATE_SETTINGS: { enabled: boolean; theme: string };
}

type MessageType = keyof MessageMap;

export function sendMessage<T extends MessageType>(
  type: T,
  payload?: MessageMap[T]
): Promise<unknown> {
  return chrome.runtime.sendMessage({ type, ...payload });
}

export function onMessage<T extends MessageType>(
  type: T,
  handler: (payload: MessageMap[T], sender: chrome.runtime.MessageSender) => void
) {
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === type) {
      handler(message as MessageMap[T], sender);
      sendResponse({ ok: true });
    }
    return true;
  });
}
```

**왜 이렇게 했나요?**

Content Script ↔ Background 간 메시지가 늘어나면 `string` 타입만으로는 관리가 어려워요. `MessageMap`으로 타입을 한 곳에서 정의하면, 보내는 쪽과 받는 쪽 모두 타입 안전하게 통신할 수 있어요.

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 초기 셋업 | `Manifest V3 Chrome Extension 보일러플레이트를 TypeScript로 만들어줘` |
| Content Script | `현재 페이지의 메타데이터와 본문을 추출하는 Content Script 작성해줘` |
| Side Panel UI | `Chrome Extension Side Panel에 카드형 UI를 HTML + CSS로 만들어줘` |
| Storage 타입 | `chrome.storage를 타입 안전하게 사용할 수 있는 래퍼 함수를 만들어줘` |
| 디버깅 | `Service Worker가 예상대로 동작하지 않아. chrome.runtime.onMessage가 호출 안 돼` |
| 권한 최적화 | `이 Extension에서 정말 필요한 최소 권한만 남기고 정리해줘` |

## 자주 겪는 문제와 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| Service Worker가 반복 종료됨 | Manifest V3 정상 동작 (유휴 시 종료) | 상태를 `chrome.storage`에 저장, 전역 변수 사용 금지 |
| Content Script가 실행 안 됨 | `matches` 패턴 불일치 또는 페이지 새로고침 필요 | `matches` 확인 + Extension 리로드 |
| Side Panel이 안 열림 | `sidePanel` 권한 누락 | `manifest.json`에 `"permissions": ["sidePanel"]` 추가 |
| 메시지 응답이 `undefined` | `sendResponse`를 비동기로 호출했지만 `return true` 누락 | `onMessage` 리스너에서 `return true` 반환 |
| 빌드 후 타입 에러 | `chrome` 네임스페이스 미인식 | `pnpm add -D @types/chrome` 설치 |

## 확장 아이디어

이 기본 구조를 토대로 다양한 기능을 추가할 수 있어요:

- **페이지 요약**: 수집한 텍스트를 LLM API로 보내서 자동 요약
- **북마크 매니저**: 방문한 페이지를 태그와 함께 저장
- **읽기 모드**: Content Script로 불필요한 요소를 제거하고 깔끔한 레이아웃 적용
- **번역 도우미**: 선택한 텍스트를 Side Panel에서 바로 번역

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
