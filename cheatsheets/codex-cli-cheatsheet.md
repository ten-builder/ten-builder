# Codex CLI 실전 치트시트 — OpenAI 터미널 에이전트 완전 정복

> 터미널에서 GPT-5.4를 바로 쓰는 OpenAI 코딩 에이전트 — 핵심 명령어, Approval 모드, 샌드박스 설정, Claude Code와의 차이점을 한 페이지로 정리.

## 설치 및 시작

```bash
# npm으로 설치
npm install -g @openai/codex

# Homebrew로 설치 (macOS)
brew install --cask codex

# 인터랙티브 TUI 실행
codex

# 단발성 실행 (TUI 없이)
codex "users 테이블에 인덱스 추가하는 마이그레이션 작성해줘"
```

## 핵심 CLI 플래그

| 플래그 | 설명 |
|--------|------|
| `-m gpt-5.4` | 사용할 모델 지정 |
| `--full-auto` | 모든 작업 자동 실행 (승인 없음) |
| `--ask-for-approval on-request` | 파일 수정은 자동, 셸 명령만 승인 요청 |
| `--ask-for-approval untrusted` | 신뢰되지 않는 작업만 승인 요청 |
| `-C /path/to/dir` | 작업 디렉토리 지정 |
| `--add-dir /extra/path` | 추가 쓰기 권한 디렉토리 지정 |
| `-i image.png` | 이미지 첨부 |
| `--search` | 실시간 웹 검색 활성화 (기본값: 캐시 모드) |
| `-p profile-name` | `~/.codex/config.toml`의 프로파일 로드 |
| `--sandbox workspace-write` | 샌드박스 내 쓰기만 허용 |

## Approval 모드 — 언제 어떤 모드를 쓰나

| 모드 | 파일 수정 | 셸 명령 | 추천 상황 |
|------|-----------|---------|----------|
| `suggest` (기본) | 승인 필요 | 승인 필요 | 프로덕션 코드, 처음 사용 시 |
| `on-request` | 자동 | 승인 필요 | 일반 개발 작업 |
| `never` | 자동 | 자동 | CI/CD 파이프라인, 격리 환경 |
| `--full-auto` | 자동 | 자동 | 완전 자동화 (주의 필요) |

```bash
# CI/CD 파이프라인에서 사용
codex --ask-for-approval never "테스트 커버리지 80% 이상 맞춰줘"

# 파일 수정만 자동화, 명령은 확인
codex --ask-for-approval on-request "리팩토링 진행해줘"
```

## 인터랙티브 모드 슬래시 명령어

| 명령어 | 기능 |
|--------|------|
| `/model` | 모델 전환 (gpt-5.4, reasoning 등) |
| `/fast` | GPT-5.4 Fast 모드 토글 |
| `/review` | 현재 diff 코드 리뷰 실행 |
| `/diff` | Git diff 터미널에서 확인 |
| `/compact` | 대화 요약으로 컨텍스트 압축 |
| `/clear` | 화면 초기화, 새 대화 시작 |
| `/mention` | 파일을 컨텍스트로 첨부 (`@파일명`도 가능) |
| `/mcp` | 연결된 MCP 도구 목록 확인 |
| `/permissions` | 현재 권한 설정 확인 및 변경 |
| `/init` | `agents.md` 파일 생성 |
| `/copy` | 마지막 출력 클립보드에 복사 |
| `/status` | 현재 세션 정보 확인 |
| `/exit` | 세션 종료 |

## AGENTS.md 설정

Codex는 실행 시 여러 경로에서 `AGENTS.md`를 탐색해 레이어로 쌓는다.

```bash
# 글로벌 기본 설정
mkdir -p ~/.codex
cat > ~/.codex/AGENTS.md << 'EOF'
## 작업 규칙
- 변경 전 계획을 먼저 설명할 것
- 테스트 파일이 있으면 수정 후 반드시 실행
- 새 패키지 추가 전 확인 요청
- 커밋 메시지는 영어로 작성
EOF

# 프로젝트별 규칙 (레포 루트)
cat > AGENTS.md << 'EOF'
## 프로젝트 컨벤션
- pnpm 사용 (npm 금지)
- PR 전 lint 실행 필수
- 공개 유틸리티 변경 시 docs/ 업데이트
EOF
```

**탐색 우선순위:** `~/.codex/AGENTS.override.md` → `~/.codex/AGENTS.md` → 레포 루트 → 현재 디렉토리 순으로 레이어됨.

## 샌드박스 설정

```toml
# ~/.codex/config.toml

[sandbox]
# 파일시스템 접근 제한
allowed_read_paths = ["/home/user/project", "/tmp"]
allowed_write_paths = ["/home/user/project/output"]

# 네트워크 접근 제한
allowed_domains = ["api.openai.com", "github.com"]

# 기본 승인 정책
default_approval_mode = "on-request"
```

```bash
# macOS: Seatbelt 기반 OS 레벨 샌드박스 자동 적용
# Linux: Landlock / bubblewrap 기반
# --dangerously-bypass-approvals-and-sandbox 는 격리 환경에서만 사용
```

## 세션 관리

```bash
# 이전 세션 이어서 작업
codex resume

# 특정 세션 재개 (목록에서 선택)
codex resume --list

# 세션 로그 확인
cat ~/.codex/log/codex-tui.log
```

## Codex CLI vs Claude Code — 빠른 비교

| 항목 | Codex CLI | Claude Code |
|------|-----------|-------------|
| 제공사 | OpenAI | Anthropic |
| 기본 모델 | GPT-5.4 | Claude Opus/Sonnet 4.x |
| Approval 모드 | suggest / on-request / never | 샌드박스 기반 자동 허용 |
| 샌드박스 | OS 네이티브 (Seatbelt/Landlock) | 샌드박스 내 auto-allow |
| AGENTS.md | 글로벌 + 프로젝트 레이어 | CLAUDE.md |
| 설정 파일 | `~/.codex/config.toml` | `~/.claude/settings.json` |
| MCP 지원 | O | O |
| 오픈소스 | O (MIT) | X |
| IDE 확장 | VS Code, Cursor, Windsurf | VS Code, JetBrains |
| 세션 재개 | `codex resume` | 자체 세션 관리 |

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 샌드박스에서 외부 API 호출 안 됨 | `allowed_domains`에 대상 도메인 추가 |
| 파일 수정이 승인 없이 일어남 | `--ask-for-approval suggest`로 실행 |
| 컨텍스트가 너무 커서 느려짐 | `/compact`로 대화 요약 후 계속 |
| AGENTS.md 규칙이 안 먹힘 | `codex "현재 지시사항 요약해줘"`로 로드 확인 |
| CI 환경에서 승인 요청으로 중단 | `--ask-for-approval never` 또는 `--full-auto` 사용 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
