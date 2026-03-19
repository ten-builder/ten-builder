# Gemini CLI 치트시트

> Google의 오픈소스 터미널 AI 코딩 에이전트 — 한 페이지 요약

## 설치 & 설정

| 단계 | 명령어 |
|------|--------|
| **설치** | `npm install -g @google/gemini-cli` |
| **실행** | `gemini` |
| **인증** | Google 계정 로그인 (브라우저 팝업) |
| **API 키 설정** | `export GEMINI_API_KEY=your-key` |
| **버전 확인** | `gemini --version` |

> Node.js 18+ 필요. Google Cloud Shell에서는 사전 설치되어 있어요.

## 핵심 슬래시 커맨드

| 커맨드 | 용도 |
|--------|------|
| `/memory` | 세션 메모리에 지시사항 저장 |
| `/stats` | 현재 세션의 토큰 사용량 확인 |
| `/mcp` | MCP 서버 연결 상태 확인 |
| `/tools` | 사용 가능한 도구 목록 |
| `/chat` | 코드 실행 없이 대화만 |
| `/quit` | 세션 종료 |

## 실전 사용 패턴

### 대규모 코드베이스 탐색

```bash
# 프로젝트 디렉토리에서 시작
cd my-project
gemini

# 대화형으로 코드 구조 파악
> 이 프로젝트의 전체 아키텍처를 설명해줘
> src/api 폴더의 엔드포인트를 정리해줘
```

2M 토큰 컨텍스트 윈도우 덕분에 대규모 프로젝트도 한 세션에서 분석할 수 있어요.

### 파일 생성 & 수정

```bash
# 인터랙티브 모드에서 파일 작업
> auth 미들웨어를 만들어줘. JWT 검증 + 리프레시 토큰 로직 포함
> 이 함수에 에러 핸들링을 추가해줘
```

파일 수정 전 diff를 보여주고 승인을 요청해요. `--yolo` 모드에서는 자동 승인.

### 자동화 & 파이프라인

```bash
# 비대화형 모드 (CI/CD에 적합)
echo "이 코드의 보안 취약점을 찾아줘" | gemini

# 특정 파일을 대상으로 분석
gemini -f src/auth.ts "이 파일의 타입 에러를 수정해줘"
```

## Conductor (컨텍스트 기반 개발)

Gemini CLI의 고급 기능으로, 프로젝트 컨텍스트를 구조화해서 관리해요.

```yaml
# .gemini/config.yaml
context:
  include:
    - src/**/*.ts
    - docs/*.md
  exclude:
    - node_modules
    - dist
  instructions: |
    이 프로젝트는 TypeScript + Express 백엔드입니다.
    모든 코드는 ESLint 규칙을 따릅니다.
```

| 설정 | 설명 |
|------|------|
| `include` | 컨텍스트에 포함할 파일 패턴 |
| `exclude` | 제외할 파일/폴더 |
| `instructions` | 프로젝트별 기본 지시사항 |

## MCP 서버 연동

```json
// .gemini/settings.json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://localhost/mydb"
      }
    }
  }
}
```

## Claude Code와 주요 차이점

| 항목 | Gemini CLI | Claude Code |
|------|-----------|-------------|
| **가격** | 무료 티어 (Gemini 3 Pro) | API 종량제 / Max 구독 |
| **컨텍스트** | 2M 토큰 | 1M 토큰 (베타) |
| **에이전트 팀** | 단일 에이전트 | subagent 패턴 지원 |
| **Rules 파일** | `.gemini/` 디렉토리 | `CLAUDE.md` |
| **Git 통합** | 기본 수준 | 내장 (커밋, PR, diff) |
| **오픈소스** | ✅ Apache 2.0 | ❌ |
| **모델 선택** | Gemini 모델만 | Claude 모델만 |

## 유용한 설정 팁

### 메모리 활용

```bash
# 세션 메모리에 규칙 저장 (CLAUDE.md와 비슷한 역할)
/memory 모든 함수에 JSDoc 주석을 작성해줘
/memory 에러 처리는 커스텀 AppError 클래스를 사용해
/memory 테스트 파일은 __tests__ 폴더에 생성해
```

### 모델 설정

```bash
# 환경변수로 모델 지정
export GEMINI_MODEL=gemini-3-pro

# 설정 파일로 기본 모델 지정
# .gemini/settings.json
{
  "model": "gemini-3-pro",
  "temperature": 0.2
}
```

## 이럴 때 Gemini CLI를 선택하세요

| 상황 | 이유 |
|------|------|
| 비용을 최소화하고 싶을 때 | 무료 티어로 충분히 사용 가능 |
| 대규모 코드베이스 분석 | 2M 토큰으로 전체 프로젝트 로딩 |
| 오픈소스 도구를 선호할 때 | Apache 2.0, 커스터마이징 자유 |
| Google Cloud 환경일 때 | Cloud Shell 사전 설치, GCP 통합 |
| 탐색/분석 위주 작업 | 코드 읽기와 설명에 강점 |

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| Node.js 버전 오류 | `nvm use 18` 이상으로 전환 |
| 인증 만료 | `gemini --reauth`로 재인증 |
| MCP 서버 연결 실패 | `.gemini/settings.json` 경로 확인 |
| 컨텍스트 초과 | `.gemini/config.yaml`에서 exclude 패턴 추가 |
| 파일 수정 권한 오류 | `--yolo` 플래그 또는 수동 승인 |

---

**다른 CLI 도구가 궁금하다면:** [AI CLI 도구 비교](ai-cli-tools-comparison.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
