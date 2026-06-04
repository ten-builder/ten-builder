# Warp 2026 실전 가이드 — 터미널에서 에이전트 팀을 운영하는 법

> Claude Code가 프로젝트를 이해하는 에이전트라면, Warp는 그 에이전트가 살아 숨쉬는 환경입니다. 2026년의 Warp는 단순 터미널을 넘어 에이전틱 개발 환경(Agentic Development Environment)으로 진화했습니다.

## 소요 시간

30-60분 (설치 + 기본 셋업)

## 사전 준비

- macOS 12+ 또는 Linux (Windows WSL2 지원)
- Warp 계정 (무료 플랜으로 시작 가능)
- 기본 터미널 사용 경험

---

## Warp 2.0이 기존 터미널과 다른 점

Warp는 2026년 4월 2.0 업데이트를 기점으로 "에이전틱 개발 환경"으로 재정의됐습니다.

| 항목 | 기존 터미널 | Warp 2.0 |
|------|------------|----------|
| 명령어 입력 | 타이핑 전용 | 자연어 → 명령어 변환 |
| 컨텍스트 인식 | 없음 | git 히스토리, 문서, 환경변수 분석 |
| 멀티 에이전트 | 불가 | 병렬 에이전트 관리 UI |
| 팀 협업 | 복붙/공유 없음 | Warp Drive로 커맨드 패키지 공유 |
| MCP 통합 | 없음 | MCP 서버 퍼스트 클래스 지원 |

---

## Step 1: 설치 및 초기 설정

### 1-1. Warp 설치

```bash
# macOS (Homebrew)
brew install --cask warp

# 또는 공식 사이트에서 다운로드
open https://www.warp.dev/download
```

### 1-2. 계정 연동

Warp를 실행하면 GitHub, Google 계정으로 바로 로그인할 수 있습니다.
무료 플랜은 AI 기능을 월 일정 크레딧 범위 내에서 무료로 사용합니다.

### 1-3. 동작 모드 이해

Warp는 세 가지 모드로 동작합니다:

| 모드 | 설명 | 전환 방법 |
|------|------|----------|
| 터미널 모드 | 표준 셸 명령어 실행 | 기본 상태 |
| 에이전트 모드 | 자연어로 복잡한 작업 지시 | `#` 또는 `@agent` 입력 |
| 자동 감지 모드 | Warp가 의도를 판단해 모드 전환 | 설정 > Behavior에서 활성화 |

---

## Step 2: 에이전트 모드 기본 사용법

### 2-1. 자연어로 명령 실행

```bash
# 프롬프트 앞에 # 붙이면 에이전트 모드 진입
# "현재 브랜치에서 병합되지 않은 커밋 목록 보여줘"
# Warp가 적절한 git 명령어를 제안하고 실행
```

에이전트가 제안한 명령어는 실행 전에 항상 미리보기를 제공합니다.
확인 없이 실행되지 않으므로 안전하게 탐색할 수 있습니다.

### 2-2. 프로젝트 컨텍스트 활용

```bash
# 레포 루트에서 Warp를 열면 자동으로 컨텍스트를 수집
# git log, README, 환경변수 등을 분석하여 더 정확한 제안 제공

# 예시: "테스트 실패 원인 분석해줘"
# Warp가 최근 커밋, CI 로그, 에러 메시지를 종합하여 분석
```

### 2-3. 허용 명령어 설정 (보안)

에이전트가 실행할 수 있는 명령어 범위를 제어할 수 있습니다:

```bash
# Settings > Agent > Command Deny List에서 위험한 명령어 차단
# 예: rm -rf, DROP TABLE, curl <unknown-host>

# 또는 자동 승인 허용 목록 설정
# git, npm, python, docker 등 신뢰하는 명령만 자동 실행
```

---

## Step 3: 병렬 에이전트 운영

Warp 2.0의 핵심 기능은 여러 에이전트를 동시에 실행하는 것입니다.

### 3-1. 멀티 에이전트 시작

```bash
# Warp 창에서 Cmd+T로 새 탭 → 각 탭에서 독립 에이전트 실행
# 또는 에이전트 관리 UI에서 "New Agent" 버튼 클릭
```

**실제 활용 예시:**

```
에이전트 1 (탭 1): 프론트엔드 컴포넌트 리팩토링
에이전트 2 (탭 2): API 엔드포인트 유닛 테스트 생성
에이전트 3 (탭 3): 의존성 보안 감사
```

### 3-2. 에이전트 상태 모니터링

우측 상단의 에이전트 관리 UI에서:
- 각 에이전트의 진행 상태 확인
- 작업 완료 알림 수신 (시스템 노티피케이션)
- 중간에 멈춰야 할 에이전트 즉시 중단

---

## Step 4: MCP 서버 연동

Warp는 MCP(Model Context Protocol) 서버를 터미널 내에서 직접 연결할 수 있습니다.

### 4-1. MCP 서버 설정

```bash
# Settings > Integrations > MCP Servers
# 또는 ~/.warp/mcp-config.json 직접 편집
```

```json
{
  "servers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"]
    }
  }
}
```

### 4-2. MCP 서버 활용 예시

```bash
# GitHub MCP 연결 후
# "지난 주 머지된 PR 중 리뷰 댓글이 3개 이상인 것 목록 뽑아줘"
# Warp 에이전트가 GitHub API를 통해 직접 데이터 조회

# Filesystem MCP 연결 후
# "src/ 폴더에서 TODO 주석이 가장 많은 파일 5개 알려줘"
```

---

## Step 5: Warp Drive로 팀 커맨드 공유

### 5-1. 커맨드 패키지 생성

```bash
# 자주 쓰는 복잡한 명령어를 팀과 공유
# Warp Drive > New Workflow에서 생성

# 예시: 배포 전 체크리스트 워크플로우
echo "=== 배포 전 체크 ==="
npm run test && npm run build && npm run lint
echo "=== Docker 이미지 빌드 ==="
docker build -t myapp:$(git rev-parse --short HEAD) .
echo "=== 빌드 완료 ==="
```

### 5-2. 파라미터화된 워크플로우

```bash
# 팀원이 변수만 바꿔서 실행할 수 있는 템플릿
# {ENVIRONMENT}, {VERSION} 같은 변수를 Warp Drive에서 정의
docker push registry.company.com/{SERVICE_NAME}:{VERSION}
kubectl set image deployment/{SERVICE_NAME} {SERVICE_NAME}=registry.company.com/{SERVICE_NAME}:{VERSION} -n {ENVIRONMENT}
```

---

## Step 6: Claude Code와 Warp 조합 활용

Warp와 Claude Code는 함께 쓸 때 시너지가 극대화됩니다.

### 6-1. 역할 분리

| 도구 | 역할 |
|------|------|
| Claude Code | 코드 작성, 파일 수정, 프로젝트 구조 이해 |
| Warp 에이전트 | 빌드/테스트/배포 명령 실행, 시스템 탐색 |

### 6-2. 실전 워크플로우

```bash
# 1. Claude Code에서 기능 구현 지시
claude "사용자 인증 미들웨어 추가해줘"

# 2. Warp로 전환 후 에이전트에게
# "방금 추가된 미들웨어가 기존 테스트에 영향을 주는지 확인해줘"
# Warp가 변경 파일을 감지하고 관련 테스트 자동 실행

# 3. 테스트 통과 확인 후
# "변경사항을 feature/auth-middleware 브랜치에 커밋하고 PR 초안 생성해줘"
```

---

## 자주 쓰는 Warp 단축키

| 단축키 | 기능 |
|--------|------|
| `Cmd+T` | 새 탭 (새 에이전트 시작) |
| `Cmd+D` | 화면 분할 |
| `Cmd+K` | AI 명령어 검색 |
| `#` (입력 시작) | 에이전트 모드 진입 |
| `Cmd+G` | Warp Drive 열기 |
| `Ctrl+C` | 에이전트 즉시 중단 |
| `Cmd+R` | 이전 명령어 AI 검색 |

---

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 에이전트가 의도와 다른 명령 실행 | 항상 미리보기에서 확인 후 실행; 자동 승인 범위 좁히기 |
| MCP 서버 연결 안 됨 | `~/.warp/logs/` 확인; 환경변수 누락 여부 점검 |
| 여러 에이전트가 같은 파일 수정 | 에이전트별 작업 범위를 명확히 분리 |
| 크레딧 소진 | 반복 작업은 일반 터미널 모드로; 에이전트는 복잡한 분석에만 사용 |

---

## 다음 단계

→ [Claude Code와 Warp 하이브리드 워크플로우](../workflows/claude-code-cursor-hybrid-workflow.md)  
→ [멀티 에이전트 병렬 코딩 플레이북](../claude-code/playbooks/71-multi-agent-parallel-coding-playbook.md)  
→ [AI 터미널 워크플로우 치트시트](../cheatsheets/ai-terminal-workflow-cheatsheet.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) — AI 코딩 실전 팁을 매주 받아보세요.
