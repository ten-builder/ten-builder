# Claude Code Week 20 실전 가이드 — project purge, SSH OAuth, --channels 권한 중계

> 2026년 4월 27일~5월 1일 릴리스(v2.1.126~v2.1.128) 핵심 업데이트 — 프로젝트 상태 정리, SSH/WSL/컨테이너 OAuth, 모바일 권한 중계, 스크립트 모드

## 이번 주 릴리스 요약

| 버전 | 날짜 | 주제 | 핵심 변경 |
|------|------|------|-----------|
| v2.1.126 | 5월 1일 | 보안 강화 (33개 변경) | `claude project purge`, SSH OAuth, `--channels` 권한 중계, `--bare` 플래그 |
| v2.1.124 | 4월 30일 | 안정성 개선 | 모델 피커 게이트웨이 연동, 권한 규칙 버그 수정 |
| v2.1.123 | 4월 29일 | 긴급 수정 | OAuth 401 재시도 루프 수정 |

---

## 기능 1: `claude project purge` — 프로젝트 상태 3분 정리

프로젝트 관련 모든 Claude Code 상태(트랜스크립트, 태스크, 파일 히스토리, 설정 항목)를 한 번에 삭제하는 명령어가 추가됐다.

### 기본 사용법

```bash
# 드라이런으로 먼저 확인
claude project purge --dry-run

# 확인 없이 즉시 삭제
claude project purge -y

# 특정 프로젝트 경로 지정
claude project purge ~/projects/old-saas -y

# 인터랙티브 모드 (파일 하나씩 확인)
claude project purge -i

# 모든 프로젝트 한번에 정리
claude project purge --all
```

### 어떤 데이터가 삭제되나

`~/.claude/projects/` 경로 아래의 해당 프로젝트 데이터:

- 트랜스크립트 (대화 기록)
- Tasks 상태 파일
- 파일 편집 히스토리
- 프로젝트별 설정 항목

**참고:** v2.1.126 이전 버전에서 생성된 오래된 아티팩트는 정리되지 않을 수 있다. 레거시 경로에 있는 파일은 직접 `find` + `rm`으로 처리해야 한다.

### 실전 활용 시나리오

| 시나리오 | 추천 명령어 |
|----------|------------|
| 팀원 퇴사 후 머신 정리 | `claude project purge --all -y` |
| 민감한 프로젝트 종료 후 | `claude project purge ~/projects/secure-client -y` |
| 컨텍스트 오염 의심 시 | `claude project purge -i` (선택적 삭제) |
| CI/CD 파이프라인 후 | `claude project purge --dry-run` (확인 후 실행) |

> **보안 주의:** purge는 Claude Code 상태만 삭제한다. 퇴사자 처리 시 반드시 키 교체, 저장소 접근 제거, 자격증명 감사를 별도로 진행해야 한다.

---

## 기능 2: SSH/WSL/컨테이너에서 OAuth 로그인

원격 환경(SSH 세션, WSL, Docker 컨테이너)에서 Claude Code를 실행할 때 OAuth 인증이 안 됐던 문제가 해결됐다.

### 기존 방식 vs 새 방식

```bash
# 기존: SSH 환경에서는 API 키만 가능
export ANTHROPIC_API_KEY="sk-ant-..."
claude

# 신규: OAuth 브라우저 인증 지원
claude auth login
# → 로컬 브라우저에서 인증 URL 열어서 완료
#   or 원격 터미널에 URL 출력 → 수동 복사 후 완료
```

### WSL에서 설정하기

```bash
# WSL2에서 브라우저 연결 확인
wslview https://claude.ai  # 윈도우 브라우저로 열림

# Claude Code 인증
claude auth login
# → URL이 출력되면 Windows 브라우저에서 열기
```

### 동시 세션 재인증 문제 수정

여러 Claude Code 세션을 동시에 실행할 때 한 세션의 토큰 갱신이 다른 세션에 반복 재인증을 요구하던 버그도 함께 수정됐다. 팀에서 여러 에이전트를 병렬로 돌리는 경우에 특히 유용하다.

---

## 기능 3: `--channels` 권한 중계 — 모바일로 승인하기

채널 서버가 권한 승인 요청을 모바일 기기로 전달할 수 있게 됐다.

### 작동 원리

```
AI 에이전트 실행 중 권한 요청
        ↓
    채널 서버
        ↓
    모바일 앱/웹 UI
        ↓
  개발자가 스마트폰으로 승인/거절
```

### 설정 방법

```bash
# 채널 서버 권한 중계 활성화
claude --channels https://my-channel-server.example.com \
  --dangerously-skip-permissions

# 서버 측 설정 (channel server가 필요)
# 채널 서버가 "permission" capability를 선언해야 함
```

이 기능은 서버가 `permission` capability를 선언한 경우에만 동작한다. 현재는 직접 채널 서버를 구성하거나, Anthropic 파트너 서비스를 통해 이용 가능하다.

---

## 기능 4: `--bare` 플래그 — 스크립트 자동화용 경량 모드

CI/CD 파이프라인이나 스크립트에서 Claude Code를 실행할 때 불필요한 초기화를 건너뛰는 플래그다.

### `--bare` 모드에서 비활성화되는 것

- Hooks (pre/post-tool)
- LSP (언어 서버 프로토콜)
- 플러그인 동기화
- 스킬 디렉토리 탐색
- 자동 메모리

```bash
# CI/CD 파이프라인에서 사용 예
claude -p "이 PR의 코드 리뷰를 해줘" \
  --bare \
  --settings ./ci-settings.json
```

**필수 요건:** `--bare` 모드는 `ANTHROPIC_API_KEY` 환경변수 또는 `--settings`를 통한 `apiKeyHelper`가 필요하다. OAuth와 키체인 인증은 비활성화된다.

### CI/CD 파이프라인 통합 예시

```yaml
# .github/workflows/ai-review.yml
- name: AI 코드 리뷰
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    claude -p "$(cat review-prompt.txt)" \
      --bare \
      --output-format json > review-result.json
```

---

## 기능 5: `--dangerously-skip-permissions` 확장

이전에는 이 플래그를 써도 `.claude/`, `.git/`, `.vscode/`, 쉘 설정 파일 등은 여전히 권한 확인을 요구했다. v2.1.126부터 이런 경로들도 프롬프트 없이 수정 가능해졌다.

### 안전하게 쓰는 법

```bash
# 반드시 컨테이너 환경에서 실행
docker run -it \
  -v $(pwd):/workspace \
  -w /workspace \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  ghcr.io/anthropics/claude-code \
  claude --dangerously-skip-permissions

# Git 커밋 상태 확인 후 실행
git status && git stash
claude --dangerously-skip-permissions
git stash pop  # 문제 발생 시
```

> **경고:** `rm -rf` 등 치명적인 명령은 여전히 확인 프롬프트를 띄운다. 그래도 반드시 컨테이너 + Git 커밋 상태에서만 실행할 것.

---

## 기타 주목할 수정

| 항목 | 내용 |
|------|------|
| Mac 슬립 복구 | 슬립 후 재개 시 세션 연결 끊김 문제 수정 |
| `/model` 피커 | 게이트웨이 `/v1/models` 엔드포인트 연동 — 사용 가능한 모델 목록 자동 동기화 |
| Vertex `count_tokens` | AI 사용량 집계 오류 수정 |
| `/branch` 명령 | 브랜치 생성 관련 버그 수정 |
| 권한 규칙 | JavaScript 프로토타입 속성명(예: `toString`)이 규칙 이름인 경우 `settings.json` 무시되던 버그 수정 |

---

## 정리

이번 Week 20 업데이트는 **팀 보안 운영**과 **원격 환경 지원**에 집중됐다. `project purge`로 민감한 프로젝트 정리가 쉬워졌고, SSH/WSL 환경에서 OAuth 인증이 가능해져 원격 작업 환경이 개선됐다.

다음 단계로는 Week 21 업데이트를 기다리면서 `--bare` 플래그를 활용한 CI/CD 파이프라인 최적화를 해보자.

→ [Week 19 가이드](81-claude-code-week19-features-guide.md) | [Week 18 가이드](79-claude-code-week18-features-guide.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
