# Gemini CLI 실전 가이드 2026 — 터미널에서 Gemini 3 Pro 제대로 쓰기

> 설치 5분, 첫 프롬프트 즉시 — Gemini CLI로 대규모 코드베이스를 분석하고, 이미지·PDF를 컨텍스트로 넣고, MCP 서버까지 연결하는 실전 워크플로우

## 왜 Gemini CLI인가

Claude Code와 Gemini CLI는 2026년 현재 터미널 기반 AI 코딩 도구의 양대 산맥이다. 두 도구 모두 강력하지만 접근 방식이 다르다.

| 항목 | Gemini CLI | Claude Code |
|------|-----------|-------------|
| 기반 모델 | Gemini 3 Pro | Claude Sonnet/Opus |
| 컨텍스트 윈도우 | 2M 토큰 | 200K 토큰 |
| 멀티모달 입력 | 이미지·PDF·동영상 | 이미지 |
| 무료 티어 | 있음 (한도 제한) | 없음 |
| MCP 지원 | 있음 | 있음 |
| 비용 | $0.075/1K 토큰 | $0.003–0.015/1K |

둘 다 쓰는 개발자가 늘고 있다. Gemini CLI는 특히 **거대한 레포 전체 분석**, **이미지/PDF 컨텍스트 주입**, **저비용 탐색 작업**에 강점이 있다.

## 설치 및 초기 설정

### 설치

```bash
npm install -g @google/gemini-cli

# 또는 npx로 바로 실행
npx @google/gemini-cli
```

### 인증

```bash
# Google 계정으로 로그인
gemini auth login

# API 키 직접 설정 (CI/CD 환경)
export GEMINI_API_KEY="your-api-key"

# 현재 인증 상태 확인
gemini auth status
```

### 기본 설정 파일

`~/.gemini/config.yaml`:

```yaml
model: gemini-3-pro
temperature: 0.3
max_tokens: 8192
project: my-project-id
```

## 핵심 명령어 30초 요약

| 명령어 | 용도 |
|--------|------|
| `gemini` | 인터랙티브 세션 시작 |
| `gemini -i "질문"` | 단발성 질의 후 인터랙티브 계속 |
| `gemini -p "프롬프트"` | 단발성 질의 후 종료 |
| `gemini chat` | 대화 세션 |
| `gemini mcp list` | 연결된 MCP 서버 확인 |
| `gemini extensions` | 확장 관리 |
| `gemini config` | 설정 편집 |

## Step 1: 코드베이스 전체 분석

Gemini CLI의 가장 큰 강점은 **2M 토큰 컨텍스트 윈도우**다. 대형 레포 전체를 한 번에 넣을 수 있다.

```bash
# 현재 디렉토리 전체를 컨텍스트로 로드
cd ~/projects/my-app
gemini -i "이 프로젝트의 전체 구조를 설명해줘. 주요 모듈, 의존성, 개선이 필요한 부분을 중심으로."

# 특정 파일 그룹만 대상으로
gemini -i "src/**/*.ts 파일들을 분석해서 타입 안전성 문제를 찾아줘"

# 대규모 레포 마이그레이션 탐색
gemini -i "이 Next.js 12 프로젝트를 Next.js 15로 업그레이드할 때 변경해야 할 부분을 우선순위 순으로 나열해줘"
```

### @파일 참조 패턴

인터랙티브 세션 내에서 파일을 직접 참조할 수 있다:

```
> @src/api/users.ts 이 파일에서 보안 취약점 찾아줘
> @package.json 의존성 중 보안 패치가 필요한 것 알려줘
> @README.md 이 내용 기반으로 onboarding 가이드 초안 작성해줘
```

## Step 2: 멀티모달 입력 활용

Gemini CLI는 이미지, PDF, 동영상을 컨텍스트로 직접 넣을 수 있다.

```bash
# Figma 디자인 스크린샷으로 컴포넌트 생성
gemini -i "이 디자인 이미지를 React 컴포넌트로 구현해줘" --image ./design-mockup.png

# PDF 사양서 기반 API 구현
gemini -i "이 API 스펙 PDF를 기반으로 TypeScript 클라이언트 라이브러리를 만들어줘" --file ./api-spec.pdf

# 에러 스크린샷 디버깅
gemini -i "이 에러 화면을 보고 원인과 해결 방법을 알려줘" --image ./error-screenshot.png
```

### 실전 활용 시나리오

| 입력 | 프롬프트 예시 |
|------|--------------|
| 시스템 아키텍처 다이어그램 | `이 다이어그램에서 단일 장애점(SPOF)을 찾아줘` |
| 데이터베이스 ERD | `이 ERD 기반으로 Prisma 스키마 생성해줘` |
| UI 목업 | `이 디자인을 Tailwind CSS로 구현해줘` |
| 로그 파일 | `이 로그에서 패턴 분석하고 이상 탐지해줘` |

## Step 3: MCP 서버 연결

Gemini CLI는 MCP(Model Context Protocol) 서버와 연결해 도구를 확장할 수 있다.

```bash
# MCP 서버 설정 파일 위치
# ~/.gemini/mcp_servers.json

# Filesystem MCP 연결 예시
gemini mcp add filesystem --command "npx @modelcontextprotocol/server-filesystem /workspace"

# GitHub MCP 연결
gemini mcp add github --command "npx @modelcontextprotocol/server-github" \
  --env "GITHUB_TOKEN=ghp_xxx"

# 연결된 MCP 서버 확인
gemini mcp list

# MCP 도구 사용
gemini -i "GitHub에서 오픈 이슈 목록 가져와서 우선순위 분류해줘"
```

### `~/.gemini/mcp_servers.json` 예시

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem", "/Users/me/projects"]
    },
    "github": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"
      }
    }
  }
}
```

## Step 4: 코딩 워크플로우 통합

### CI/CD 파이프라인에서 활용

```bash
# PR 코드 리뷰 자동화
git diff main...feature-branch | gemini -p "이 diff를 리뷰해줘. 버그, 성능 이슈, 보안 문제 중심으로."

# 테스트 커버리지 분석
gemini -p "$(cat coverage/lcov.info)" "커버리지가 낮은 파일과 추가 테스트가 필요한 함수를 찾아줘"

# 릴리즈 노트 자동 생성
git log v1.0..v2.0 --pretty=format:"%s" | gemini -p "이 커밋 목록으로 사용자 친화적인 릴리즈 노트 작성해줘"
```

### Shell 스크립트와 조합

```bash
#!/bin/bash
# ai-review.sh — 수정된 파일들에 대해 Gemini CLI로 자동 리뷰

CHANGED_FILES=$(git diff --name-only HEAD~1)

for file in $CHANGED_FILES; do
  if [[ "$file" == *.ts || "$file" == *.py ]]; then
    echo "=== Reviewing $file ==="
    gemini -p "다음 파일을 코드 리뷰해줘. 한국어로 간결하게:
$(cat $file)"
  fi
done
```

## Step 5: 비용 최적화

Gemini CLI를 효율적으로 쓰려면 토큰 사용량을 관리해야 한다.

| 전략 | 방법 |
|------|------|
| 탐색은 무료 티어 | 초기 분석·탐색은 무료 한도 내에서 |
| 파일 범위 지정 | 전체 레포 대신 관련 파일만 포함 |
| 배치 처리 | 여러 작은 질의를 하나로 묶기 |
| 캐싱 활용 | 동일 컨텍스트 재사용 시 `--session` 플래그 |

```bash
# 세션 저장으로 컨텍스트 재사용
gemini --session my-project -i "프로젝트 구조 파악해줘"
# 나중에 같은 컨텍스트로 재연결
gemini --session my-project -i "인증 모듈 리팩터링 계획 세워줘"
```

## Claude Code vs Gemini CLI — 언제 어떤 도구를?

| 상황 | 추천 도구 | 이유 |
|------|-----------|------|
| 대규모 레포 전체 분석 | Gemini CLI | 2M 토큰 컨텍스트 |
| 이미지·PDF 컨텍스트 | Gemini CLI | 멀티모달 강점 |
| 파일 직접 편집·커밋 | Claude Code | 에이전트 자율 실행 |
| 비용 민감 탐색 작업 | Gemini CLI | 무료 티어 활용 |
| 복잡한 멀티 파일 변경 | Claude Code | agentic 능력 |
| 두 도구 병행 | 상황에 따라 | 작업 특성에 맞게 선택 |

## 체크리스트

- [ ] `npm install -g @google/gemini-cli` 설치
- [ ] `gemini auth login`으로 인증
- [ ] `~/.gemini/config.yaml` 기본 설정
- [ ] `gemini mcp add`로 필요한 MCP 서버 연결
- [ ] 자주 쓰는 프롬프트를 shell alias로 등록
- [ ] 비용 모니터링을 위해 사용량 대시보드 설정

## 다음 단계

→ [Claude Code와 함께 쓰는 멀티 에이전트 워크플로우](../workflows/ai-multi-model-routing.md)

→ [MCP 서버 직접 만들기](../claude-code/playbooks/45-custom-mcp-server-build-deploy.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
