# Hermes Agent 치트시트 — CLI, TUI, Skills, Docker 핵심 명령어 정리

> Hermes Agent(NousResearch)의 설치부터 스킬 관리, Docker 운영, 크론 자동화까지 한 페이지로 정리

---

## 설치 & 기본 실행

| 명령어 | 설명 |
|--------|------|
| `curl -fsSL https://get.hermes-agent.nousresearch.com \| bash` | 원라인 설치 (Linux/macOS/WSL2) |
| `hermes` | 기본 CLI 실행 |
| `hermes --tui` | TUI(터미널 UI) 모드 실행 (권장) |
| `hermes --tui -c` | 마지막 세션 재개 (TUI) |
| `hermes --tui --continue <session-id>` | 특정 세션 재개 |
| `hermes dump` | 현재 설정/상태 덤프 출력 |
| `hermes update` | 최신 버전으로 업그레이드 |

---

## CLI 주요 플래그

| 플래그 | 설명 |
|--------|------|
| `--model <model>` | 사용할 모델 지정 (예: `anthropic/claude-opus-4.6`) |
| `--profile <name>` | 다른 프로파일로 실행 (예: `hermes -p coder`) |
| `-c`, `--continue` | 마지막 세션 이어서 실행 |
| `--force` | 기존 설정 덮어쓰기 확인 생략 |
| `--no-gateway` | 게이트웨이 없이 단독 실행 |
| `hermes -p <name> --tui` | 특정 프로파일로 TUI 실행 |

---

## TUI 키보드 단축키

| 단축키 | 기능 |
|--------|------|
| `Ctrl+C` | 현재 실행 중인 에이전트 중지 |
| `Ctrl+G` / `Ctrl+X Ctrl+E` | 입력 버퍼를 외부 에디터에서 편집 (`$EDITOR`) |
| `Esc` | 편집 취소 및 큐 강조 해제 |
| `위/아래 방향키` | 히스토리 탐색 |

---

## TUI 슬래시 커맨드

### 기본 제어

| 커맨드 | 설명 |
|--------|------|
| `/help` | 사용 가능한 슬래시 커맨드 목록 표시 |
| `/stop` | 현재 실행 중단 |
| `/restart` | 에이전트 재시작 |
| `/debug` | 디버그 모드 전환 |
| `/update` | Hermes 업데이트 |
| `/yolo` | 모든 확인 요청 자동 승인 (주의해서 사용) |

### 세션 & 이력

| 커맨드 | 설명 |
|--------|------|
| `/sessions` | 세션 목록 표시 |
| `/goal` | 현재 목표 설정/확인 |
| `/goal clear` | 현재 목표 초기화 |
| `/usage` | 토큰 사용량 및 비용 패널 |

### 에이전트 & 태스크

| 커맨드 | 설명 |
|--------|------|
| `/agents` (또는 `/tasks`) | 서브에이전트 트리 및 비용/토큰 현황 표시 |
| `/kanban list --mine` | 내 칸반 태스크 목록 |
| `/kanban unblock t_abc` | 특정 태스크 차단 해제 |
| `/kanban comment t_abc "..."` | 태스크에 코멘트 추가 |
| `/kanban boards switch <slug>` | 칸반 보드 전환 |

### 스킬 & 모델

| 커맨드 | 설명 |
|--------|------|
| `/skills` | 설치된 스킬 목록 표시 |
| `/skills browse` | 스킬 마켓플레이스 탐색 |
| `/skills search <query>` | 스킬 검색 |
| `/skills install <source/skill>` | 스킬 설치 |
| `/skills reset <name>` | 특정 스킬 초기화 |
| `/model` | 현재 모델 확인 및 변경 |
| `/reload-mcp` | MCP 서버 재로드 |

### 승인 & 보안

| 커맨드 | 설명 |
|--------|------|
| `/approve session` | 현재 세션에서 위험 명령어 일괄 승인 |
| `/approve always` | 항상 자동 승인 (영구) |
| `/deny` | 보류 중인 위험 명령어 거절 |

---

## 스킬 시스템 (CLI)

```bash
# 스킬 검색
hermes skills search <query> --source skills-sh

# 스킬 설치
hermes skills install <source/skill-name>

# 설치된 스킬 목록
hermes skills list

# 특정 스킬 실행
hermes /<skill-name> [인자]

# 스킬 초기화 (프로파일별 독립)
hermes -p coder skills reset <name>
```

---

## 프로파일 관리

```bash
# 프로파일 생성
hermes profile create <name>

# 프로파일 목록 조회
hermes profile list

# 프로파일 내보내기
hermes profile export ./backup-$(date +%Y%m%d).tar.gz

# 프로파일 가져오기
hermes profile import ./work-20260423.tar.gz --name work
```

---

## 크론 자동화

| 형식 | 예시 | 설명 |
|------|------|------|
| 분 단위 | `30m` | 30분 후 한 번 실행 |
| cron 표현식 | `0 9 * * *` | 매일 오전 9시 |
| 주중 실행 | `0 9 * * 1-5` | 평일 오전 9시 |
| ISO 타임스탬프 | `2026-06-01T09:00:00` | 특정 날짜/시간 한 번 실행 |

```bash
# 크론 태스크 등록 예시 (TUI /goal 또는 SKILL.md 정의)
# ~/.hermes/cron.yaml 또는 /skills cron 명령으로 관리
```

---

## Docker 운영

```bash
# Docker 컨테이너로 실행 (데이터는 호스트 /opt/data에 마운트)
docker run -it \
  -v /opt/data:/opt/data \
  nousresearch/hermes-agent:latest

# 컨테이너 업그레이드 (데이터 유지)
docker pull nousresearch/hermes-agent:latest
docker stop hermes && docker rm hermes
docker run -d --name hermes \
  -v /opt/data:/opt/data \
  nousresearch/hermes-agent:latest

# Podman 사용 시
HERMES_DOCKER_BINARY=podman hermes ...
```

> Docker 컨테이너는 무상태(stateless)로 설계되어, 이미지 업그레이드 시 `/opt/data` 마운트 데이터는 그대로 유지됩니다.

---

## 설정 파일 주요 항목

```yaml
# ~/.hermes/config.yaml
display:
  tool_preview_length: 80   # 툴 미리보기 길이 (0 = 제한 없음)

model: anthropic/claude-opus-4.6
provider: openrouter         # openrouter | openai | anthropic | nous

# 환경변수로도 설정 가능
HERMES_DOCKER_BINARY=podman  # Docker 대신 Podman 사용
```

---

## 흔한 실수 & 해결

| 문제 | 해결 |
|------|------|
| Windows 네이티브에서 실행 안 됨 | WSL2 환경에서 실행 |
| Android에서 설치 안 됨 | Termux 전용 가이드 참조 |
| 게이트웨이 충돌 | `--no-gateway` 플래그 또는 `hermes import` 전 게이트웨이 종료 |
| 스킬이 프로파일 간 섞임 | `-p <profile>` 플래그로 프로파일 명시 |
| 토큰 비용 과다 | `/usage`로 실시간 확인, `/model`로 저비용 모델 전환 |

---

**더 자세한 가이드:** [guides/95-hermes-agent-practical-guide-2026.md](../guides/95-hermes-agent-practical-guide-2026.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
