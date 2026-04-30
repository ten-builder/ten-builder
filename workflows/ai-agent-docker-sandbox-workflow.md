# AI 에이전트 Docker 샌드박스 실행 워크플로우

> AI 에이전트가 생성한 코드를 안전하게 실행하는 격리 환경 구성 — Docker 기반 샌드박스 설계부터 보안 강화, 프로덕션 적용까지

## 개요

AI 에이전트가 생성하는 코드를 그대로 호스트 머신에서 실행하는 것은 위험합니다. 2026년 기준, 표준 컨테이너만으로는 충분한 격리가 되지 않는다는 것이 보안 커뮤니티의 공통된 견해입니다.

이 워크플로우는 AI 에이전트 코드 실행 환경을 단계별로 격리하고, 실제 서비스에 안전하게 적용하는 방법을 다룹니다.

## 사전 준비

- Docker Engine 26.0+
- Docker Compose v2
- Claude Code 또는 Codex CLI
- Linux 호스트 권장 (macOS도 동작하지만 gVisor 미지원)

## 위협 모델 이해

### AI 에이전트 코드 실행의 위험

| 위협 | 설명 | 실제 사례 |
|------|------|-----------|
| 컨테이너 탈출 | 커널 취약점 노출 | CVE-2024-21626 (runc 취약점) |
| 호스트 파일시스템 접근 | 잘못된 볼륨 마운트 | `/` 마운트 후 자격증명 노출 |
| 네트워크 측면 이동 | 내부 서비스 접근 | 데이터베이스 직접 연결 |
| 리소스 고갈 | CPU/메모리 무제한 사용 | 서비스 장애 |

### 격리 레벨 선택

```
레벨 1: 표준 컨테이너 (신뢰된 코드, 단일 테넌트)
레벨 2: 강화 컨테이너 (검증된 외부 코드, 제한적)
레벨 3: gVisor/microVM (미검증 코드, 다중 테넌트)
```

## Step 1: 기본 샌드박스 컨테이너 설정

### Dockerfile 작성

```dockerfile
# sandbox.Dockerfile
FROM ubuntu:24.04

# 최소 권한 사용자 생성
RUN groupadd -r sandbox && useradd -r -g sandbox -m sandbox

# 필요한 런타임만 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3-pip nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# 작업 디렉토리 설정 (호스트 접근 불가)
WORKDIR /sandbox
RUN chown sandbox:sandbox /sandbox

USER sandbox

# 실행 제한 설정
ENV PYTHONDONTWRITEBYTECODE=1
ENV NODE_OPTIONS="--max-old-space-size=512"
```

### docker-compose.yml 보안 설정

```yaml
# docker-compose.sandbox.yml
version: '3.9'

services:
  sandbox:
    build:
      context: .
      dockerfile: sandbox.Dockerfile
    # 보안 설정
    security_opt:
      - no-new-privileges:true
      - seccomp:seccomp-profile.json
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # 필요한 경우만
    read_only: true
    tmpfs:
      - /tmp:size=100m,mode=1777
      - /sandbox/output:size=500m
    # 리소스 제한
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.1'
          memory: 128M
    # 네트워크 격리
    network_mode: none  # 완전 네트워크 차단
    # 볼륨: 출력 디렉토리만 선택적 마운트
    volumes:
      - type: tmpfs
        target: /sandbox/workspace
        tmpfs:
          size: 500000000
```

## Step 2: AI 에이전트 코드 실행 파이프라인

### 실행 스크립트 작성

```bash
#!/bin/bash
# run-in-sandbox.sh

set -euo pipefail

CODE_FILE="${1:?코드 파일 경로를 인자로 전달하세요}"
TIMEOUT="${2:-30}"  # 기본 30초 타임아웃

# 1. 코드 사전 검사 (정적 분석)
echo "[SANDBOX] 사전 검사 중..."
if grep -qE "(os\.system|subprocess\.call|eval\(|exec\()" "$CODE_FILE"; then
    echo "[WARN] 위험 패턴 감지. 수동 검토 필요."
    exit 1
fi

# 2. 임시 격리 디렉토리 생성
SANDBOX_DIR=$(mktemp -d /tmp/sandbox-XXXXXXXX)
cp "$CODE_FILE" "$SANDBOX_DIR/code.py"

# 3. Docker 컨테이너에서 실행
echo "[SANDBOX] 격리 환경에서 실행 중..."
timeout "$TIMEOUT" docker run \
    --rm \
    --network none \
    --memory 512m \
    --cpus 0.5 \
    --security-opt no-new-privileges \
    --cap-drop ALL \
    --read-only \
    --tmpfs /tmp:size=50m \
    --volume "$SANDBOX_DIR:/code:ro" \
    sandbox-runner:latest \
    python3 /code/code.py 2>&1

EXIT_CODE=$?
rm -rf "$SANDBOX_DIR"

if [ $EXIT_CODE -eq 124 ]; then
    echo "[ERROR] 타임아웃 초과 (${TIMEOUT}초)"
    exit 1
fi

exit $EXIT_CODE
```

### Claude Code CLAUDE.md 통합

```markdown
# CLAUDE.md - 샌드박스 실행 규칙

## 코드 실행 정책

생성된 코드를 실행할 때는 반드시 샌드박스를 사용합니다:

```bash
# 직접 실행 금지
# python3 generated_code.py  ❌

# 샌드박스 실행
./run-in-sandbox.sh generated_code.py 60  ✅
```

## 허용 작업

- 파일 읽기/쓰기 (샌드박스 내부)
- 데이터 처리 및 변환
- API 호출 (명시적으로 허용된 경우)

## 금지 작업

- 호스트 파일시스템 직접 접근
- 환경변수 외부 노출
- 네트워크 연결 (기본값: 차단)
```

## Step 3: Seccomp 프로파일 강화

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "read", "write", "open", "close", "stat", "fstat",
        "mmap", "mprotect", "munmap", "brk", "exit_group",
        "futex", "clock_gettime", "gettimeofday",
        "openat", "newfstatat", "pread64", "pwrite64"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

```bash
# Seccomp 프로파일 저장 후 적용
docker run \
    --security-opt seccomp=seccomp-profile.json \
    sandbox-runner:latest python3 /code/script.py
```

## Step 4: 실행 결과 검증 파이프라인

### 출력 스캐닝

```python
# output-scanner.py
import re
import json

SENSITIVE_PATTERNS = [
    r'[A-Za-z0-9+/]{40,}={0,2}',  # Base64 인코딩 가능 토큰
    r'(password|secret|token|api_key)\s*[:=]\s*\S+',  # 자격증명
    r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',  # IP 주소
    r'sk-[a-zA-Z0-9]{48}',  # OpenAI 스타일 키
]

def scan_output(output: str) -> dict:
    findings = []
    for pattern in SENSITIVE_PATTERNS:
        matches = re.findall(pattern, output, re.IGNORECASE)
        if matches:
            findings.append({
                "pattern": pattern,
                "count": len(matches)
            })
    return {
        "safe": len(findings) == 0,
        "findings": findings
    }

if __name__ == "__main__":
    import sys
    output = sys.stdin.read()
    result = scan_output(output)
    print(json.dumps(result, indent=2))
    if not result["safe"]:
        sys.exit(1)
```

### Claude Code 워크플로우 통합

```bash
# 전체 파이프라인: 생성 → 샌드박스 실행 → 출력 검증
claude "데이터 파싱 코드를 생성해줘" \
    --output-file generated.py

# 샌드박스 실행
./run-in-sandbox.sh generated.py 30 | \
    python3 output-scanner.py

echo "검증 완료"
```

## Step 5: gVisor 심화 격리 (선택)

```bash
# gVisor 설치 (Linux)
curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
sudo apt-get install -y runsc

# Docker 런타임으로 등록
sudo runsc install

# gVisor로 실행 (커널 레벨 격리)
docker run \
    --runtime runsc \
    --network none \
    --memory 512m \
    sandbox-runner:latest python3 /code/script.py
```

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| 컨테이너 실행 실패 | Seccomp 너무 제한적 | `--security-opt seccomp=unconfined`로 임시 테스트 후 허용 syscall 추가 |
| 메모리 부족 | 제한이 낮음 | `--memory 1g`로 상향 |
| 타임아웃 빈번 | 코드 무한루프 | AI에게 타임아웃 처리 코드 추가 요청 |
| 파일 쓰기 불가 | read-only 설정 | `--tmpfs /sandbox/output`으로 쓰기 허용 영역 추가 |
| 네트워크 필요 | 외부 API 호출 | 허용 도메인만 명시한 네트워크 프록시 추가 |

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `TIMEOUT` | 30초 | AI 코드 최대 실행 시간 |
| `--memory` | 512m | 컨테이너 메모리 한도 |
| `--cpus` | 0.5 | CPU 코어 제한 |
| `--network` | none | 네트워크 정책 (none/bridge) |
| Seccomp | 최소 허용 | 시스템콜 허용 목록 |

---

**관련 가이드:** [AI 에이전트 보안 위협 대응](../cheatsheets/ai-agent-security-threat-response.md) | [AI 에이전트 자율 실행 설계](../claude-code/playbooks/22-autonomous-execution.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
