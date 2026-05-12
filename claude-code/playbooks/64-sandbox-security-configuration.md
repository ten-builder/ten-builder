# 플레이북 64: Claude Code 샌드박스 보안 설정 플레이북

> Claude Code를 안전하게 실행하는 샌드박스 설정 완전 가이드 — bubblewrap 기반 파일시스템 격리, 네트워크 통제, 권한 최소화, CVE 대응까지

## 소요 시간

15-30분 (초기 설정), 이후 자동 적용

## 사전 준비

- Claude Code 최신 버전 (v2.1.128+)
- Linux 또는 WSL2 환경 (macOS는 Docker 샌드박스 사용)
- 터미널 sudo 권한

---

## 왜 샌드박스가 필요한가

Claude Code는 파일 시스템 읽기/쓰기, 셸 명령 실행, 네트워크 요청을 자율적으로 처리한다. 2026년 현재 팀들이 맞닥뜨리는 실제 리스크:

| 상황 | 위험 |
|------|------|
| `rm -rf` 등 실수 명령 실행 | 레포 파일 전체 삭제 |
| 의도치 않은 외부 요청 | API 키 유출, 데이터 전송 |
| 사용자 홈 디렉토리 전체 접근 | 무관한 파일 열람/수정 |
| CVE-2026-25725 유형 취약점 | 샌드박스 탈출, 원격 코드 실행 |

샌드박스는 에이전트에게 "작업 공간"을 주고, 그 바깥을 차단하는 것이다.

---

## Step 1: 샌드박스 의존성 설치

### Linux / WSL2

```bash
# Ubuntu/Debian
sudo apt-get install bubblewrap socat

# Fedora/RHEL
sudo dnf install bubblewrap socat

# 설치 확인
bwrap --version
# 예상 출력: bubblewrap 0.8.x
```

### macOS

macOS는 bubblewrap을 지원하지 않는다. 대신 Docker 마이크로VM 기반 샌드박스를 사용한다.

```bash
# Docker Desktop 설치 (https://docker.com)
docker --version

# Claude Code는 macOS에서 Docker를 자동 감지하여 마이크로VM 샌드박스를 활성화한다
```

> **WSL1 주의:** WSL1은 지원하지 않는다. 반드시 WSL2를 사용해야 한다.
> `wsl --set-version <distro> 2` 명령으로 WSL2로 전환할 수 있다.

---

## Step 2: 샌드박스 활성화

Claude Code 세션 내에서 `/sandbox` 커맨드를 실행한다.

```
/sandbox
```

의존성이 올바르게 설치되어 있으면 샌드박스가 활성화된다. 이후 모든 셸 명령은 bubblewrap으로 격리된 환경에서 실행된다.

### 샌드박스 상태 확인

```bash
# Claude Code 세션 외부에서 샌드박스 여부 확인
# .claude/settings.json에서 sandbox 항목 조회
cat .claude/settings.json | grep -A5 sandbox
```

---

## Step 3: settings.json 핵심 보안 설정

`.claude/settings.json`에서 샌드박스 동작을 세부 조정할 수 있다.

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false,
    "excludedCommands": [
      "git",
      "npm",
      "node"
    ],
    "allowUnixSockets": ["/var/run/docker.sock"],
    "network": "restricted"
  }
}
```

| 설정 항목 | 기본값 | 권장값 | 설명 |
|-----------|--------|--------|------|
| `enabled` | `false` | `true` | 샌드박스 활성화 여부 |
| `failIfUnavailable` | `false` | `true` | 샌드박스 불가 시 실행 중단 |
| `allowUnsandboxedCommands` | `true` | `false` | 샌드박스 실패 시 비샌드박스 재시도 허용 |
| `excludedCommands` | `[]` | 필요한 것만 | 샌드박스 예외 명령 목록 |

> **핵심:** `allowUnsandboxedCommands: false`는 에이전트가 샌드박스를 우회하는 "탈출 해치"를 막는다.

---

## Step 4: 파일시스템 권한 최소화

bubblewrap은 기본적으로 프로젝트 디렉토리 바인드 마운트를 사용한다. 직접 설정이 필요한 경우 `.claude/sandbox-config.json`으로 커스터마이징한다.

```json
{
  "bindMounts": {
    "readOnly": [
      "/usr",
      "/lib",
      "/etc/ssl/certs"
    ],
    "readWrite": [
      "${PWD}",
      "${HOME}/.npm",
      "${HOME}/.claude"
    ]
  },
  "tmpfs": ["/tmp", "/var/tmp"],
  "proc": true,
  "dev": true
}
```

### 허용 목록 설계 원칙

- **읽기 전용으로 최소화**: 시스템 라이브러리, SSL 인증서
- **읽기/쓰기 최소화**: 프로젝트 디렉토리, 패키지 캐시
- **홈 디렉토리 전체 바인드 금지**: 최소한 필요한 서브디렉토리만

---

## Step 5: 네트워크 격리 설정

Claude Code 샌드박스는 네트워크 접근을 통제할 수 있다.

```json
{
  "sandbox": {
    "network": "restricted",
    "allowedHosts": [
      "api.anthropic.com",
      "registry.npmjs.org",
      "github.com"
    ]
  }
}
```

| 네트워크 모드 | 설명 |
|---------------|------|
| `unrestricted` | 모든 외부 접근 허용 (기본값) |
| `restricted` | `allowedHosts`만 허용 |
| `none` | 네트워크 완전 차단 |

> **실전 팁:** CI/CD 환경에서는 `none`으로 설정하고 필요한 패키지만 사전 설치하는 방식이 가장 안전하다.

---

## Step 6: CVE-2026-25725 대응

2026년 초 발견된 CVE-2026-25725는 `settings.json`이 존재하지 않을 때 bubblewrap이 설정 파일을 보호하지 못하는 취약점이다.

### 즉시 조치

```bash
# 1. Claude Code 최신 버전으로 업데이트
npm update -g @anthropic-ai/claude-code

# 2. 프로젝트 루트에 settings.json 미리 생성
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false
  }
}
EOF

# 3. 파일 권한 설정
chmod 644 .claude/settings.json
```

### 팀 레포 적용

```bash
# git에 settings.json 추가 (민감 정보 없는 경우)
git add .claude/settings.json
git commit -m "chore: add Claude Code sandbox security defaults"
```

---

## Step 7: CI/CD 통합

GitHub Actions 등 CI 환경에서 에이전트를 안전하게 실행하는 설정이다.

```yaml
# .github/workflows/ai-agent.yml
name: AI Agent Task
on:
  workflow_dispatch:

jobs:
  agent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install sandbox dependencies
        run: sudo apt-get install -y bubblewrap socat

      - name: Configure sandbox
        run: |
          mkdir -p .claude
          cat > .claude/settings.json << 'EOF'
          {
            "sandbox": {
              "enabled": true,
              "failIfUnavailable": true,
              "allowUnsandboxedCommands": false,
              "network": "restricted",
              "allowedHosts": ["api.anthropic.com"]
            }
          }
          EOF

      - name: Run Claude Code agent
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          claude --dangerously-skip-permissions \
            --sandbox \
            "지정된 태스크를 실행해줘"
```

---

## 체크리스트

- [ ] bubblewrap, socat 설치 완료 (Linux/WSL2) 또는 Docker Desktop 설치 (macOS)
- [ ] WSL2 환경 확인 (WSL1 미사용)
- [ ] `/sandbox` 명령으로 샌드박스 활성화
- [ ] `settings.json`에 `allowUnsandboxedCommands: false` 설정
- [ ] `failIfUnavailable: true`로 샌드박스 우회 방지
- [ ] 파일시스템 바인드 마운트를 필요한 경로만으로 제한
- [ ] 네트워크 모드 `restricted` 또는 `none` 설정
- [ ] Claude Code 최신 버전으로 업데이트 (CVE-2026-25725 패치 적용)
- [ ] CI/CD 파이프라인에 샌드박스 설정 통합

---

## 문제 해결

| 문제 | 해결 |
|------|------|
| `bwrap: not found` | `sudo apt-get install bubblewrap` 재실행 |
| `sandbox not available` | WSL1 → WSL2 전환 또는 Docker 설치 |
| `command failed in sandbox` | `excludedCommands`에 해당 명령 추가 |
| `network request blocked` | `allowedHosts`에 필요한 도메인 추가 |
| 샌드박스 활성화 후 속도 저하 | Docker 마이크로VM 대신 bubblewrap 사용 검토 |

---

## 다음 단계

→ [AI 에이전트 보안 취약점 자동 패치 플레이북](./48-security-vulnerability-auto-patch.md)

→ [AI 에이전트 컨텍스트 오염 방지 플레이북](./57-context-contamination-prevention.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
