# Claude Code 라이브 앱 프리뷰 & 데브 서버 연동 치트시트

> 개발 서버를 자동으로 실행하고 콘솔·로그를 실시간으로 보며 반복하는 Live App Preview 활용 패턴 — 설정, 오류 디버깅, 멀티 서비스 연동 한 페이지 정리

---

## 핵심 개념

| 개념 | 설명 |
|------|------|
| Live App Preview | Claude Code 데스크탑 앱이 dev server를 직접 실행·감시하는 기능 |
| `launch.json` | `.claude/launch.json`에 저장되는 서버 실행 설정 파일 |
| 자동 감지 | Next.js, Vite, React CRA 등 주요 프레임워크는 설정 없이 자동 인식 |
| 콘솔 연동 | 브라우저 콘솔 로그·에러를 Claude가 직접 읽고 수정 제안 |

---

## launch.json 기본 구조

```json
{
  "version": "1.0",
  "servers": [
    {
      "name": "frontend",
      "command": "npm run dev",
      "port": 3000,
      "env": {
        "NODE_ENV": "development"
      }
    }
  ]
}
```

**파일 위치:** 세션 시작 시 선택한 폴더 루트의 `.claude/launch.json`

---

## 자동 감지되는 프레임워크

| 프레임워크 | 감지 기준 | 기본 포트 |
|-----------|----------|----------|
| Next.js | `next.config.js` 존재 | 3000 |
| Vite | `vite.config.ts` 존재 | 5173 |
| Create React App | `react-scripts` 의존성 | 3000 |
| Astro | `astro.config.mjs` 존재 | 4321 |
| SvelteKit | `svelte.config.js` 존재 | 5173 |

자동 감지가 안 되면 Preview 드롭다운에서 **Edit configuration** 클릭

---

## 멀티 서비스 설정

```json
{
  "version": "1.0",
  "servers": [
    {
      "name": "frontend",
      "command": "npm run dev",
      "port": 3000,
      "cwd": "./frontend"
    },
    {
      "name": "backend",
      "command": "npm run start:dev",
      "port": 4000,
      "cwd": "./backend",
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"
      }
    }
  ],
  "primary": "frontend"
}
```

**`primary`**: Preview 패널에 기본 표시될 서버

---

## 실시간 반복 워크플로우

```
1. Claude Code 데스크탑에서 폴더 열기
2. Preview 패널에서 dev server 시작
3. 변경 요청 → 코드 수정 → 자동 새로고침 확인
4. 콘솔 에러 발생 → Claude가 자동으로 오류 인식
5. "이 에러 고쳐줘" → 코드 수정 → 재확인
```

콘솔 로그를 직접 붙여넣지 않아도 됨 — Preview 패널이 연결된 상태에서는 Claude가 콘솔 출력을 직접 읽음

---

## 오류 디버깅 패턴

### 빌드 오류 즉시 수정

```
문제: TypeScript 컴파일 오류
패턴: 빌드 실패 → 에러 메시지 자동 수집 → 수정 제안
```

```
# 프롬프트 예시
"Preview 패널에서 TypeScript 에러가 보이면 바로 수정해줘"
```

### 런타임 오류 추적

```
문제: 콘솔에 Uncaught TypeError 반복 발생
패턴: 에러 스택 → 관련 파일 탐색 → 원인 분석 → 수정
```

```
# 프롬프트 예시
"콘솔에 계속 나오는 TypeError를 추적해서 원인 파일과 줄을 찾아줘"
```

### 스타일 반복 수정

```
# 프롬프트 예시 (Preview 보면서)
"버튼이 모바일에서 잘려 보여. 직접 확인하면서 고쳐줘"
```

---

## 흔한 문제 & 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| 서버가 자동 시작 안 됨 | 서브폴더 구조 문제 | 해당 서브폴더를 루트로 세션 열기 |
| 포트 충돌 | 기존 프로세스가 포트 점유 | `launch.json`에서 포트 변경 또는 기존 프로세스 종료 |
| 콘솔 로그 안 보임 | Preview 패널 연결 안 됨 | Preview 드롭다운에서 서버 선택 확인 |
| auto-verify 실패 | 서버 시작 시간 초과 | `launch.json`에 `"startTimeout": 30000` 추가 |
| 환경 변수 미적용 | `.env` 파일 경로 문제 | `launch.json`의 `env` 필드에 직접 지정 |

---

## 고급 설정 옵션

```json
{
  "version": "1.0",
  "servers": [
    {
      "name": "app",
      "command": "pnpm dev",
      "port": 3000,
      "startTimeout": 30000,
      "readyPattern": "ready on",
      "autoVerify": false,
      "env": {
        "NEXT_PUBLIC_API_URL": "http://localhost:4000"
      }
    }
  ]
}
```

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `startTimeout` | 서버 준비 대기 시간(ms) | `10000` |
| `readyPattern` | 서버 준비 감지 문자열 | 자동 감지 |
| `autoVerify` | 서버 상태 자동 확인 | `true` |

---

## 모바일 & 원격 프리뷰

Claude Code 데스크탑의 Preview는 `claude.ai/code`와 연결됨:

- **원격 확인**: 다른 기기 브라우저에서 `claude.ai/code`에 접속하면 동일한 프리뷰 확인 가능
- **모바일 테스트**: iOS/Android 브라우저에서 반응형 UI 직접 확인
- **공유 URL**: 팀원과 프리뷰 링크 공유 가능 (로그인 필요)

---

## Claude Code vs 기존 개발 방식 비교

| 항목 | 기존 방식 | Claude Code Live Preview |
|------|----------|--------------------------|
| 콘솔 에러 공유 | 스크린샷 또는 복사·붙여넣기 | 자동 연결, 직접 읽음 |
| 수정 → 확인 | 탭 전환·새로고침 반복 | 수정 즉시 자동 새로고침 |
| 멀티 서비스 | 터미널 여러 개 | `launch.json` 하나로 관리 |
| 모바일 확인 | ngrok 등 별도 터널링 | `claude.ai/code`로 즉시 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
