# Claude Code Remote Control + Dispatch 실전 가이드

> 2026년 1분기에 추가된 Remote Control, Dispatch, Channels 세 가지 기능을 활용해 여러 머신에서 AI 에이전트를 원격으로 조율하는 방법을 정리했어요.

## 왜 이 기능들이 중요한가

Claude Code는 2026년 1분기를 기점으로 성격이 바뀌었어요. 터미널에서 사람이 직접 지켜봐야 했던 도구가, API를 통해 원격에서 태스크를 발송하고 결과를 실시간으로 모니터링할 수 있는 프로그래밍 가능한 백엔드로 바뀌었어요.

| 기능 | 역할 |
|------|------|
| **Dispatch** | 터미널 세션 없이 API로 태스크 발송 |
| **Remote Control** | 실행 중인 세션을 원격 모니터링·개입 |
| **Channels** | 여러 에이전트 세션 간 메시지 라우팅 |

이 세 가지를 조합하면 CI/CD 파이프라인, 백그라운드 자동화, 분산 에이전트 팀을 만들 수 있어요.

## 사전 준비

- Claude Code CLI 최신 버전 (`claude --version` → 0.2.x 이상)
- Anthropic API 키 (`ANTHROPIC_API_KEY` 환경변수 설정)
- 대상 레포가 클론된 서버 또는 EC2/VPS (로컬 파일 접근 필요)

---

## Part 1: Dispatch — 헤드리스 태스크 실행

### 기본 동작 원리

Dispatch는 Claude Code를 큐 워커처럼 동작시켜요. HTTP 요청으로 태스크를 넘기면 Claude Code가 받아서 실행하고 결과를 반환해요.

```bash
# Claude Code 디스패치 모드 시작
claude dispatch --listen --port 8765

# 다른 터미널에서 태스크 전송
claude dispatch send \
  --host localhost:8765 \
  --task "src/utils.ts의 타입 에러를 모두 수정하고 결과를 알려줘" \
  --cwd /home/ec2-user/my-project
```

### GitHub Actions에서 Dispatch 사용하기

PR이 열리면 자동으로 코드 리뷰를 요청하는 예시예요.

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Claude Code 리뷰 요청
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          claude dispatch send \
            --task "변경된 파일을 리뷰하고 개선점을 PR 코멘트 형식으로 정리해줘. 
                    보안 취약점과 타입 안전성에 집중해서 봐줘." \
            --cwd ${{ github.workspace }} \
            --output review-result.md

          # 결과를 PR 코멘트로 남기기
          gh pr comment ${{ github.event.number }} \
            --body-file review-result.md
```

### 태스크 우선순위와 타임아웃 설정

```bash
# 우선순위와 타임아웃 지정
claude dispatch send \
  --task "인증 모듈 전체를 테스트 커버리지 80% 이상으로 올려줘" \
  --priority high \
  --timeout 1800 \
  --cwd /home/ec2-user/backend
```

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `--priority` | high / normal / low | normal |
| `--timeout` | 초 단위 제한 시간 | 600 |
| `--output` | 결과 저장 파일 경로 | stdout |
| `--model` | 사용할 Claude 모델 | claude-opus-4-5 |

---

## Part 2: Remote Control — 실행 중인 세션 원격 관리

### 세션 연결과 모니터링

Remote Control은 이미 실행 중인 Claude Code 세션을 원격에서 지켜보고 개입할 수 있게 해줘요.

```bash
# 서버에서: 원격 접속 허용 모드로 Claude Code 시작
claude --remote --session-id prod-refactor-01

# 로컬에서: 실행 중인 세션에 연결
claude remote attach prod-refactor-01 \
  --host your-server.example.com:8766

# 세션 목록 조회
claude remote list --host your-server.example.com:8766
```

연결하면 서버에서 실행 중인 Claude Code의 출력이 로컬 터미널에 실시간으로 스트리밍돼요. 개입이 필요할 때는 명령을 입력하면 돼요.

### 모바일에서 모니터링하기

Remote Control은 claude.ai 웹 인터페이스와도 연동돼요. 서버에서 실행 중인 에이전트의 진행 상황을 스마트폰에서 확인하고, 필요하면 중단하거나 방향을 바꿀 수 있어요.

```bash
# 웹 연동용 토큰 발급
claude remote token --session-id prod-refactor-01
# → 출력된 토큰을 claude.ai/remote 에서 입력
```

---

## Part 3: Channels — 에이전트 간 메시지 라우팅

### Channels가 해결하는 문제

여러 Claude Code 세션이 동시에 돌아갈 때, 서로 결과를 주고받으려면 파일 시스템이나 외부 큐 없이 Channels를 사용할 수 있어요.

```bash
# 세션 A: 분석 에이전트 시작 (채널 publish)
claude --session-name analyzer --channel codebase-analysis

# 세션 B: 수정 에이전트 시작 (채널 subscribe)
claude --session-name fixer --channel codebase-analysis --mode subscriber
```

분석 에이전트가 "utils.ts에 타입 에러 3건 발견"이라고 채널에 발송하면, 수정 에이전트가 이를 받아서 수정 작업을 시작해요.

### 실전 패턴: 분석 → 수정 → 검증 파이프라인

```bash
#!/bin/bash
# three-stage-pipeline.sh

# Stage 1: 분석 에이전트
claude dispatch send \
  --task "코드베이스를 분석해서 수정이 필요한 파일 목록을 
          JSON 형식으로 codebase-analysis 채널에 발송해줘" \
  --channel codebase-analysis \
  --session-name stage1-analyzer &

# Stage 2: 수정 에이전트 (stage1 완료 후 자동 시작)
claude dispatch send \
  --task "codebase-analysis 채널에서 파일 목록을 받아서 
          각 파일의 에러를 수정해줘" \
  --channel codebase-analysis \
  --subscribe \
  --session-name stage2-fixer &

# Stage 3: 검증 에이전트
claude dispatch send \
  --task "수정된 파일에 대해 테스트를 실행하고 
          결과를 슬랙 웹훅으로 전송해줘" \
  --channel fix-complete \
  --subscribe \
  --session-name stage3-validator &

wait
echo "파이프라인 완료"
```

---

## 네트워크 격리와 보안 설정

프로덕션에서 Remote Control을 쓸 때는 직접 포트를 열지 않는 게 좋아요.

```bash
# 권장: SSH 터널을 통해 연결
ssh -L 8766:localhost:8766 your-server.example.com

# 서버에서는 localhost만 바인딩
claude --remote --bind 127.0.0.1:8766
```

| 보안 항목 | 권장 설정 |
|-----------|----------|
| 포트 바인딩 | `127.0.0.1`만 (외부 노출 금지) |
| 접근 제어 | SSH 터널 또는 VPN 경유 |
| API 키 | 환경변수로 주입 (`--env-file .env`) |
| 세션 ID | 무작위 UUID 사용 (`--session-id $(uuidgen)`) |
| 타임아웃 | 장시간 세션은 `--timeout` 명시 |

---

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| `connection refused` | 서버에서 --remote 플래그 없이 시작 | 서버 재시작 시 `--remote` 추가 |
| 세션이 중간에 끊김 | 네트워크 타임아웃 | `--keepalive 30` 옵션 추가 |
| Dispatch 태스크 응답 없음 | 타임아웃 초과 | `--timeout` 값 늘리기 |
| 채널 메시지 누락 | 구독 시점 이전 메시지 | `--from-beginning` 플래그 사용 |

---

## 다음 단계

→ [멀티 에이전트 오케스트레이션](./40-multi-agent-orchestration.md)  
→ [백그라운드 에이전트 워크플로](./46-background-coding-agents.md)  
→ [AI 에이전트 관찰 가능성](./29-ai-agent-observability.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)  
**YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
