# Docker + AI 개발 환경 구축

> 컨테이너 안에서 AI 코딩 도구를 사용하는 재현 가능한 개발 환경을 만들어요.

## 개요

"내 컴퓨터에서는 되는데…" 문제를 해결하면서, AI 코딩 도구의 보안 리스크까지 줄이는 방법이에요. Docker 컨테이너 안에서 Claude Code, Cursor 같은 도구를 실행하면 호스트 시스템을 보호하면서도 팀 전체가 동일한 환경에서 작업할 수 있어요.

## 사전 준비

- Docker Desktop 또는 Docker Engine 설치
- VS Code + Dev Containers 확장 (ms-vscode-remote.remote-containers)
- Claude Code CLI 또는 Cursor 라이선스

## 설정

### Step 1: devcontainer.json 만들기

프로젝트 루트에 `.devcontainer/devcontainer.json`을 생성해요:

```json
{
  "name": "AI Dev Environment",
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".."
  },
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "lts"
    },
    "ghcr.io/devcontainers/features/python:1": {
      "version": "3.12"
    },
    "ghcr.io/devcontainers/features/git:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "github.copilot",
        "github.copilot-chat",
        "esbenp.prettier-vscode",
        "dbaeumer.vscode-eslint"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "zsh"
      }
    }
  },
  "mounts": [
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly",
    "source=${localEnv:HOME}/.gitconfig,target=/home/vscode/.gitconfig,type=bind,readonly"
  ],
  "postCreateCommand": "npm install -g @anthropic-ai/claude-code && echo 'setup done'",
  "remoteUser": "vscode"
}
```

### Step 2: Dockerfile 작성

`.devcontainer/Dockerfile`을 만들어요:

```dockerfile
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# 시스템 패키지
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    ripgrep \
    fd-find \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Oh My Zsh (선택)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# 작업 디렉토리
WORKDIR /workspace
```

### Step 3: 환경 변수 분리

API 키는 `.devcontainer/.env`에서 관리하고, `.gitignore`에 추가해요:

```bash
# .devcontainer/.env
ANTHROPIC_API_KEY=sk-ant-xxx
OPENAI_API_KEY=sk-xxx
```

`devcontainer.json`에 env 파일 연결:

```json
{
  "runArgs": ["--env-file", ".devcontainer/.env"]
}
```

```bash
# .gitignore에 추가
.devcontainer/.env
```

## 사용 방법

### VS Code에서 열기

```bash
# 방법 1: 명령 팔레트
# Cmd+Shift+P → "Dev Containers: Reopen in Container"

# 방법 2: CLI
devcontainer open .
```

### Claude Code 실행

컨테이너 안에서 바로 사용할 수 있어요:

```bash
# 컨테이너 터미널에서
claude

# 특정 작업 지시
claude "이 프로젝트의 테스트를 작성해줘"
```

### 팀 공유

레포에 `.devcontainer/` 디렉토리를 커밋하면 팀원 모두 동일한 환경을 사용해요:

```bash
git add .devcontainer/devcontainer.json .devcontainer/Dockerfile
git commit -m "chore: add devcontainer config"
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `features` | Node + Python | 필요한 런타임 추가/제거 |
| `mounts` | SSH + gitconfig | 호스트 인증 정보 공유 |
| `postCreateCommand` | claude-code 설치 | 초기 설정 스크립트 |
| `runArgs` | env 파일 | 추가 Docker 옵션 |

### 프로젝트 유형별 확장

```json
// React/Next.js 프로젝트
{
  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "20" }
  },
  "forwardPorts": [3000, 5173]
}
```

```json
// Python ML 프로젝트
{
  "features": {
    "ghcr.io/devcontainers/features/python:1": { "version": "3.12" },
    "ghcr.io/devcontainers/features/nvidia-cuda:1": {}
  }
}
```

```json
// Go 프로젝트
{
  "features": {
    "ghcr.io/devcontainers/features/go:1": { "version": "1.22" }
  }
}
```

## 보안 이점

AI 코딩 도구를 컨테이너에서 실행하면 세 가지 이점이 있어요:

| 항목 | 호스트 직접 설치 | 컨테이너 실행 |
|------|-----------------|-------------|
| 파일 접근 범위 | 전체 디스크 | 마운트된 디렉토리만 |
| 네트워크 | 무제한 | 제한 가능 |
| 시스템 변경 | 가능 | 컨테이너 삭제 시 초기화 |

네트워크를 더 제한하고 싶다면:

```json
{
  "runArgs": [
    "--env-file", ".devcontainer/.env",
    "--network=ai-dev-net"
  ]
}
```

```bash
# 특정 도메인만 허용하는 네트워크 생성
docker network create ai-dev-net
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| SSH 키 인식 안 됨 | `mounts`에 `.ssh` 경로 확인, 권한 `chmod 600` |
| Claude Code 설치 실패 | Node.js 버전 18+ 확인, `postCreateCommand` 로그 체크 |
| Git push 안 됨 | SSH agent forwarding 확인: `"mounts"` 대신 `"features"` git 사용 |
| 컨테이너 느림 | Docker Desktop 리소스 할당 늘리기 (CPU 4+, RAM 8GB+) |
| 확장 프로그램 누락 | `customizations.vscode.extensions`에 ID 정확히 입력 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
