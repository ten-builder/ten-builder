# AI 코딩 에이전트 샌드박싱 실전 가이드

> AI 코딩 에이전트를 안전하게 실행하는 격리 환경 구축 — Docker Sandbox, 네트워크 제한, 권한 관리

## 왜 샌드박싱이 필요한가

AI 코딩 에이전트는 파일 시스템 접근, 셸 명령 실행, 네트워크 요청까지 할 수 있어요. 편리하지만 한 가지 문제가 있어요 — 에이전트가 실행하는 코드를 매번 확인하기 어렵다는 점이에요.

실제로 발생하는 위험:

| 위험 유형 | 구체적 시나리오 | 심각도 |
|-----------|----------------|--------|
| 시크릿 유출 | `.env` 파일을 읽어 외부 서버로 전송 | 치명적 |
| 파일 시스템 손상 | 의도치 않은 `rm -rf` 또는 설정 파일 덮어쓰기 | 높음 |
| 의존성 오염 | 악성 패키지 설치 또는 공급망 공격 | 높음 |
| 리소스 남용 | 무한 루프, 메모리 폭주, 디스크 가득 참 | 중간 |
| 네트워크 악용 | 허가 없는 외부 API 호출, 데이터 전송 | 높음 |

샌드박싱은 에이전트의 실행 범위를 물리적으로 제한해서, 실수나 악의적 행동의 영향을 최소화하는 방법이에요.

## 주요 에이전트별 기본 격리 수준

각 AI 코딩 에이전트는 서로 다른 격리 전략을 가지고 있어요:

| 에이전트 | 기본 샌드박스 | 격리 방식 | 기본 활성화 |
|----------|-------------|-----------|------------|
| Claude Code | Seatbelt (macOS) / Bubblewrap (Linux) | OS 수준 정책 | 꺼짐 |
| Codex CLI | Landlock + seccomp | 커널 수준 제한 | 켜짐 |
| Gemini CLI | Docker / Podman 지원 | 컨테이너 격리 | 선택적 |
| Kiro | 내장 프로젝트 범위 제한 | IDE 수준 | 부분적 |

Codex CLI만 기본적으로 샌드박싱이 켜져 있다는 점이 주목할 만해요. 나머지 도구는 직접 설정해야 해요.

## 방법 1: Docker Sandbox (권장)

Docker Sandbox는 microVM 기반으로, 일반 컨테이너보다 한 단계 더 격리된 환경을 제공해요.

### Step 1: Docker Sandbox 설치

```bash
# Docker Desktop 최신 버전 필요 (4.38+)
# Sandbox 기능 활성화 확인
docker sandbox --help
```

### Step 2: 프로젝트 샌드박스 생성

```bash
# 현재 프로젝트를 샌드박스에서 실행
docker sandbox run claude ./my-project

# 특정 이름으로 생성
docker sandbox run --name my-agent-sandbox claude ./my-project
```

### Step 3: 네트워크 격리 설정

```yaml
# docker-sandbox.yaml
sandbox:
  network:
    mode: restricted
    allowlist:
      - "api.anthropic.com"
      - "api.openai.com"
      - "registry.npmjs.org"
      - "pypi.org"
```

### Step 4: 파일 시스템 마운트 제한

```bash
# 프로젝트 디렉토리만 읽기/쓰기 허용
docker sandbox run claude ./my-project \
  --mount type=bind,source=./src,target=/workspace/src \
  --mount type=bind,source=./tests,target=/workspace/tests,readonly
```

## 방법 2: Docker Compose로 커스텀 샌드박스

더 세밀한 제어가 필요하다면 직접 구성할 수 있어요:

```yaml
# docker-compose.sandbox.yaml
version: "3.9"
services:
  coding-agent:
    image: node:22-slim
    working_dir: /workspace
    volumes:
      - ./src:/workspace/src
      - ./tests:/workspace/tests
      - ./package.json:/workspace/package.json:ro
    networks:
      - restricted
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 4G
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:size=512M
      - /workspace/node_modules:size=2G

  proxy:
    image: squid:latest
    volumes:
      - ./squid.conf:/etc/squid/squid.conf:ro
    networks:
      - restricted
      - external

networks:
  restricted:
    internal: true
  external:
    driver: bridge
```

```bash
# Squid 프록시 도메인 허용 목록
# squid.conf (핵심 부분)
acl allowed_domains dstdomain .anthropic.com
acl allowed_domains dstdomain .openai.com
acl allowed_domains dstdomain .npmjs.org
acl allowed_domains dstdomain .github.com

http_access allow allowed_domains
http_access deny all
```

## 방법 3: 도구별 내장 격리 활용

### Claude Code — 권한 모드 설정

```json
// .claude/settings.json
{
  "permissions": {
    "allow": [
      "Read",
      "Edit",
      "Write"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(curl*)",
      "Bash(wget*)"
    ]
  }
}
```

### Codex CLI — 네트워크 정책

```bash
# 기본 모드: 네트워크 차단 + 디렉토리 격리
codex exec "테스트 코드 작성해줘" --full-auto

# 네트워크 필요한 작업
codex exec "npm 패키지 설치 후 테스트" --full-auto --net
```

## 실전 구성: 프로젝트별 보안 레벨

프로젝트 민감도에 따라 샌드박싱 수준을 다르게 설정하면 좋아요:

| 보안 레벨 | 적용 대상 | 격리 방식 | 네트워크 |
|-----------|-----------|-----------|----------|
| Level 1 (낮음) | 개인 사이드 프로젝트 | 도구 내장 권한만 | 허용 |
| Level 2 (중간) | 오픈소스 프로젝트 | Docker 컨테이너 | 패키지 레지스트리만 |
| Level 3 (높음) | 회사 프로덕션 코드 | Docker Sandbox (microVM) | 프록시 허용 목록 |
| Level 4 (최고) | 금융/의료 시스템 | 에어갭 VM + 로컬 LLM | 완전 차단 |

### Level 3 설정 예시 (회사 프로젝트)

```bash
#!/bin/bash
# sandbox-start.sh — 회사 프로젝트용 샌드박스 시작

PROJECT_DIR=$(pwd)
SANDBOX_NAME="corp-$(basename $PROJECT_DIR)"

# 1. 시크릿 파일 제외 확인
if [ -f ".env" ]; then
  echo "WARNING: .env 파일 감지. 샌드박스에 마운트하지 않습니다."
fi

# 2. 샌드박스 생성 (시크릿 제외)
docker sandbox run --name "$SANDBOX_NAME" claude "$PROJECT_DIR" \
  --exclude ".env" \
  --exclude ".env.local" \
  --exclude "*.pem" \
  --exclude "*.key"

# 3. 네트워크 제한 적용
echo "Sandbox '$SANDBOX_NAME' started with restricted network"
```

## 모니터링과 감사

샌드박스를 띄워놓고 끝이 아니에요. 에이전트가 무엇을 했는지 추적해야 해요:

```bash
# Docker 컨테이너 리소스 모니터링
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# 에이전트 실행 로그 수집
docker logs coding-agent --since 1h 2>&1 | grep -E "(EXEC|WRITE|DELETE)"

# 파일 시스템 변경 추적
docker diff coding-agent
```

### 감사 체크리스트

- [ ] `.env`, 시크릿 파일이 마운트되지 않았는가
- [ ] 네트워크 허용 목록이 최소 범위로 설정되었는가
- [ ] CPU/메모리 제한이 설정되었는가
- [ ] 에이전트 로그를 주기적으로 확인하고 있는가
- [ ] 샌드박스 종료 후 임시 파일이 정리되는가

## 흔한 실수와 해결

| 실수 | 왜 문제인가 | 해결 |
|------|------------|------|
| `.env`를 통째로 마운트 | API 키가 에이전트에 노출 | 필요한 환경변수만 개별 주입 |
| `--privileged` 플래그 사용 | 컨테이너 격리 무력화 | 필요한 capability만 추가 |
| 네트워크 제한 없이 실행 | 데이터 유출 경로 열림 | 프록시 + 허용 목록 적용 |
| 작업 완료 후 샌드박스 방치 | 리소스 낭비, 보안 노출 | 자동 정리 스크립트 사용 |
| 모든 프로젝트에 동일 설정 | 과하거나 부족한 격리 | 프로젝트별 보안 레벨 분류 |

## 다음 단계

이 가이드에서 다룬 샌드박싱은 에이전트 보안의 첫 단계예요. 더 깊이 알아보려면:

- [AI 코딩 보안 실전 가이드](./16-ai-coding-security.md) — 코드 수준 보안 패턴
- [Docker + AI 개발 환경](../workflows/docker-ai-dev-environment.md) — 개발 환경 구축 상세
- [AI 에이전트 감독 워크플로우](../workflows/ai-agent-supervision.md) — 사람이 감독하는 패턴

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
