# AI 에이전트 기반 실시간 협업 코딩 도구

> WebSocket과 CRDT로 여러 개발자가 동시에 코드를 편집하는 협업 도구를 구현하는 예제

## 이 예제에서 배울 수 있는 것

- WebSocket으로 실시간 코드 변경사항을 전파하는 방법
- CRDT(Yjs)로 동시 편집 충돌을 자동 해결하는 방법
- Monaco Editor를 협업 환경에 통합하는 방법
- AI 에이전트로 이 정도 복잡도의 프로젝트를 구조화하는 방법

## 프로젝트 구조

```
ai-realtime-collab-editor/
├── server/
│   ├── index.ts          # WebSocket 서버 + Yjs 문서 관리
│   ├── room.ts           # 룸별 사용자 & 문서 상태 관리
│   └── awareness.ts      # 커서 위치, 사용자 정보 동기화
├── client/
│   ├── index.html        # Monaco Editor + 사용자 목록 UI
│   ├── editor.ts         # Monaco + Yjs 바인딩
│   └── collaboration.ts  # WebSocket 연결 + awareness 처리
├── shared/
│   └── types.ts          # 공유 타입 정의
├── package.json
└── tsconfig.json
```

## 시작하기

```bash
# 의존성 설치
npm install

# 개발 서버 실행 (서버 + 클라이언트 동시)
npm run dev

# 브라우저에서 여러 탭으로 접속
open http://localhost:3000
```

## 핵심 코드

### server/room.ts — 룸 기반 문서 관리

```typescript
import * as Y from "yjs";
import { WebSocket } from "ws";

interface User {
  id: string;
  name: string;
  color: string;
  cursor?: { line: number; column: number };
}

interface Room {
  doc: Y.Doc;
  users: Map<string, { ws: WebSocket; user: User }>;
}

const rooms = new Map<string, Room>();

export function getOrCreateRoom(roomId: string): Room {
  if (!rooms.has(roomId)) {
    rooms.set(roomId, {
      doc: new Y.Doc(),
      users: new Map(),
    });
  }
  return rooms.get(roomId)!;
}

export function joinRoom(
  roomId: string,
  userId: string,
  ws: WebSocket,
  user: User
): Room {
  const room = getOrCreateRoom(roomId);

  room.users.set(userId, { ws, user });

  // 새 사용자에게 현재 문서 상태 전송
  const state = Y.encodeStateAsUpdate(room.doc);
  ws.send(JSON.stringify({ type: "init", state: Buffer.from(state).toString("base64") }));

  // 다른 사용자들에게 입장 알림
  broadcastToRoom(room, userId, {
    type: "user-joined",
    user,
  });

  return room;
}

export function leaveRoom(roomId: string, userId: string) {
  const room = rooms.get(roomId);
  if (!room) return;

  room.users.delete(userId);

  broadcastToRoom(room, userId, {
    type: "user-left",
    userId,
  });

  // 빈 룸은 정리
  if (room.users.size === 0) {
    rooms.delete(roomId);
  }
}

export function applyUpdate(
  roomId: string,
  senderId: string,
  update: Uint8Array
) {
  const room = rooms.get(roomId);
  if (!room) return;

  // CRDT 업데이트 적용 — Yjs가 자동으로 충돌 해결
  Y.applyUpdate(room.doc, update);

  // 다른 사용자들에게 전파
  broadcastToRoom(room, senderId, {
    type: "update",
    update: Buffer.from(update).toString("base64"),
  });
}

function broadcastToRoom(
  room: Room,
  excludeId: string,
  message: object
) {
  const json = JSON.stringify(message);
  room.users.forEach(({ ws }, userId) => {
    if (userId !== excludeId && ws.readyState === WebSocket.OPEN) {
      ws.send(json);
    }
  });
}
```

**왜 이렇게 했나요?**

CRDT(Conflict-free Replicated Data Type)를 쓰면 서버가 문서 상태를 중재할 필요가 없습니다. 각 클라이언트가 자신의 변경사항을 독립적으로 적용하고, Yjs가 수학적으로 일관성을 보장합니다. 서버는 단순히 업데이트를 중계하는 역할만 합니다.

### server/index.ts — WebSocket 서버

```typescript
import { WebSocketServer } from "ws";
import { v4 as uuidv4 } from "uuid";
import {
  joinRoom,
  leaveRoom,
  applyUpdate,
} from "./room";

const PORT = 3001;
const wss = new WebSocketServer({ port: PORT });

wss.on("connection", (ws) => {
  const userId = uuidv4();
  let currentRoomId: string | null = null;

  ws.on("message", (raw) => {
    const msg = JSON.parse(raw.toString());

    switch (msg.type) {
      case "join": {
        currentRoomId = msg.roomId;
        joinRoom(currentRoomId, userId, ws, {
          id: userId,
          name: msg.name,
          color: randomColor(),
        });
        break;
      }

      case "update": {
        if (!currentRoomId) return;
        const update = Buffer.from(msg.update, "base64");
        applyUpdate(currentRoomId, userId, new Uint8Array(update));
        break;
      }

      case "awareness": {
        // 커서 위치, 선택 범위 등 동기화
        if (!currentRoomId) return;
        broadcastAwareness(currentRoomId, userId, msg.data);
        break;
      }
    }
  });

  ws.on("close", () => {
    if (currentRoomId) {
      leaveRoom(currentRoomId, userId);
    }
  });
});

function randomColor(): string {
  const colors = [
    "#3b82f6", "#ef4444", "#10b981", "#f59e0b",
    "#8b5cf6", "#ec4899", "#14b8a6", "#f97316",
  ];
  return colors[Math.floor(Math.random() * colors.length)];
}

console.log(`WebSocket 서버 실행 중: ws://localhost:${PORT}`);
```

### client/editor.ts — Monaco + Yjs 바인딩

```typescript
import * as monaco from "monaco-editor";
import * as Y from "yjs";
import { MonacoBinding } from "y-monaco";
import { WebsocketProvider } from "y-websocket";

export function initEditor(
  container: HTMLElement,
  roomId: string,
  userName: string
) {
  // Yjs 문서 초기화
  const ydoc = new Y.Doc();
  const yText = ydoc.getText("code");

  // WebSocket으로 다른 클라이언트와 연결
  const provider = new WebsocketProvider(
    "ws://localhost:3001",
    roomId,
    ydoc
  );

  // 내 커서 색상 설정
  provider.awareness.setLocalStateField("user", {
    name: userName,
    color: "#" + Math.floor(Math.random() * 0xffffff).toString(16),
  });

  // Monaco 에디터 생성
  const editor = monaco.editor.create(container, {
    value: "",
    language: "typescript",
    theme: "vs-dark",
    fontSize: 14,
    minimap: { enabled: false },
  });

  // Monaco와 Yjs 문서 바인딩 — 여기서 실시간 동기화 연결
  const binding = new MonacoBinding(
    yText,
    editor.getModel()!,
    new Set([editor]),
    provider.awareness
  );

  // 연결 상태 표시
  provider.on("status", ({ status }: { status: string }) => {
    document.getElementById("status")!.textContent =
      status === "connected" ? "연결됨" : "연결 중...";
  });

  return { editor, provider, ydoc };
}
```

**왜 이렇게 했나요?**

`y-monaco` 바인딩이 Monaco 에디터의 모든 변경사항을 자동으로 Yjs 문서와 동기화합니다. 개발자가 직접 delta 계산이나 충돌 해결 로직을 작성할 필요가 없습니다. `y-websocket`의 awareness 기능으로 다른 사용자의 커서 위치도 자동으로 표시됩니다.

### client/index.html — 사용자 인터페이스

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <title>실시간 협업 코딩</title>
  <style>
    body { margin: 0; background: #1e1e1e; color: #d4d4d4; font-family: sans-serif; }
    #toolbar {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 8px 16px;
      background: #252526;
      border-bottom: 1px solid #3c3c3c;
    }
    #status { font-size: 12px; color: #10b981; }
    #users { display: flex; gap: 6px; margin-left: auto; }
    .user-badge {
      width: 24px; height: 24px;
      border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      font-size: 11px; font-weight: bold; color: white;
    }
    #editor-container { height: calc(100vh - 42px); }
  </style>
</head>
<body>
  <div id="toolbar">
    <span>🤝 협업 코딩</span>
    <span id="status">연결 중...</span>
    <div id="users"></div>
  </div>
  <div id="editor-container"></div>
  <script type="module" src="./editor.ts"></script>
</body>
</html>
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 실시간 충돌 해결 로직 설계 | `CRDT와 OT의 트레이드오프를 분석하고, 이 프로젝트에 Yjs를 쓰는 이유를 코드와 함께 설명해줘` |
| WebSocket 연결 안정성 개선 | `WebSocket 연결 끊김 시 자동 재연결 + exponential backoff 패턴을 구현해줘` |
| 코드 실행 샌드박스 추가 | `Docker 기반 격리 환경에서 TypeScript 코드를 실행하고 결과를 WebSocket으로 전송하는 기능 추가해줘` |
| 성능 최적화 | `1000명이 동시에 접속할 때 Yjs 업데이트 브로드캐스트 성능을 분석하고 최적화 방안을 제안해줘` |
| 테스트 작성 | `WebSocket 연결, CRDT 동기화, awareness 전파에 대한 통합 테스트를 Vitest로 작성해줘` |

## 확장 아이디어

```
이 예제를 기반으로 추가할 수 있는 것들:

1. 언어별 LSP(Language Server Protocol) 통합
   → TypeScript, Python, Go 등 자동완성 & 타입 체크

2. 코드 실행 샌드박스
   → Docker 컨테이너에서 격리된 코드 실행 + 결과 공유

3. 세션 저장 & 재개
   → PostgreSQL + Yjs 스냅샷으로 편집 히스토리 영구 저장

4. AI 코딩 에이전트 참여자
   → Claude API를 WebSocket 클라이언트로 연결 → AI가 팀원처럼 코드 기여
```

## 의존성

```json
{
  "dependencies": {
    "yjs": "^13.6.0",
    "y-websocket": "^1.5.0",
    "y-monaco": "^0.1.5",
    "monaco-editor": "^0.46.0",
    "ws": "^8.17.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "vite": "^5.2.0",
    "@types/ws": "^8.5.0"
  }
}
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
