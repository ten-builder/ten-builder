# AI 코딩 에이전트 원격 제어 워크플로우

> 채팅 앱이나 모바일에서 AI 코딩 에이전트를 원격으로 제어하는 실전 워크플로우

## 개요

외출 중에 버그를 발견했는데 노트북이 없을 때, 출퇴근길에 코드 리뷰를 처리하고 싶을 때 — AI 코딩 에이전트를 모바일에서 원격으로 돌릴 수 있으면 빈 시간을 생산적으로 쓸 수 있어요.

이 워크플로우가 해결하는 문제:
- 개발 머신 앞에 없을 때 긴급 대응이 필요한 상황
- 빌드/테스트/배포 같은 반복 작업을 이동 중에 실행
- 코딩 에이전트의 자율 작업 결과를 실시간으로 모니터링

## 사전 준비

- 항상 켜져 있는 개발 머신 (데스크톱, 서버, 또는 VPS)
- SSH 접근 가능한 네트워크 환경 (Tailscale, WireGuard 등)
- 텔레그램 또는 디스코드 봇 (선택)
- Claude Code 또는 다른 터미널 AI 코딩 에이전트

## 방법 1: SSH + tmux 기반 원격 제어

가장 범용적이고 안정적인 방법이에요. 어떤 AI 코딩 도구든 터미널에서 동작하면 원격으로 쓸 수 있어요.

### Step 1: 원격 머신에 tmux 세션 준비

```bash
# 개발 머신에서 tmux 세션 생성
tmux new-session -d -s coding

# AI 코딩 에이전트 실행
tmux send-keys -t coding "cd ~/projects/my-app && claude" Enter
```

### Step 2: 모바일에서 SSH 접속

```bash
# iOS: Blink Shell, Termius 등
# Android: Termux, JuiceSSH 등

ssh dev-machine

# 기존 tmux 세션에 붙기
tmux attach -t coding
```

### Step 3: Tailscale로 어디서든 접속

VPN이나 포트 포워딩 없이 Tailscale 하나로 해결해요:

```bash
# 개발 머신에 Tailscale 설치
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# 모바일에서 Tailscale 앱 설치 + 같은 네트워크 접속
ssh user@dev-machine  # Tailscale IP 또는 MagicDNS
```

| 장점 | 단점 |
|------|------|
| 어떤 도구든 동작 | 터미널 UI가 모바일에서 불편 |
| 설정이 간단 | 키보드 입력이 느림 |
| 비용 없음 | 실시간 알림이 없음 |

## 방법 2: Claude Code Channels (텔레그램/디스코드)

Claude Code의 Channels 기능을 쓰면 채팅 앱에서 직접 코딩 에이전트와 대화할 수 있어요.

### Step 1: 텔레그램 봇 생성

```bash
# 1. @BotFather에서 새 봇 생성
# /newbot → 이름/유저네임 설정 → API 토큰 획득

# 2. Claude Code에서 채널 연결
claude channels add telegram --bot-token "YOUR_BOT_TOKEN"

# 3. 연결 확인
claude channels list
```

### Step 2: 디스코드 봇 연결

```bash
# 1. Discord Developer Portal에서 봇 생성
# Applications → New Application → Bot 토큰 발급

# 2. Claude Code 채널 추가
claude channels add discord --bot-token "YOUR_BOT_TOKEN"

# 3. 특정 채널에서만 응답하도록 설정
claude channels config discord --channel-id "CHANNEL_ID"
```

### Step 3: 모바일에서 원격 코딩

텔레그램이나 디스코드 앱에서 봇에게 메시지를 보내면 됩니다:

```
사용자: src/api/users.ts에서 에러 핸들링 추가해줘
봇: users.ts를 확인하고 있어요...
    [변경 사항 요약]
    파일 3개 수정 완료. 테스트도 통과했어요.

사용자: 커밋하고 PR 올려줘
봇: PR #42 생성 완료 — "feat: add error handling to users API"
```

| 장점 | 단점 |
|------|------|
| 채팅 UI로 자연스러운 사용 | 현재 Research Preview 단계 |
| 푸시 알림으로 결과 수신 | 지원 채널이 제한적 |
| 여러 채널에서 동시 접근 | 복잡한 작업에는 아직 불안정 |

## 방법 3: 자동화 봇 + 알림 파이프라인

AI 에이전트가 정해진 일정에 자율적으로 일하고, 결과만 알림으로 받는 방식이에요.

### Step 1: 크론 기반 자동 실행

```bash
# crontab 또는 systemd timer
# 매 시간마다 코드 품질 체크
0 * * * * cd ~/projects/my-app && claude --print "린트 에러 확인하고 수정해줘" > /tmp/lint-report.txt

# 결과를 텔레그램으로 전송
0 * * * * /usr/local/bin/notify-telegram.sh /tmp/lint-report.txt
```

### Step 2: 텔레그램 알림 스크립트

```bash
#!/bin/bash
# notify-telegram.sh
BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"
MESSAGE=$(cat "$1" | head -c 4000)  # 텔레그램 메시지 길이 제한

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=${MESSAGE}" \
  -d "parse_mode=Markdown"
```

### Step 3: GitHub Actions + 모바일 알림

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: AI Review
        run: |
          npx claude --print "이 PR의 변경사항을 리뷰해줘" > review.md
      - name: Post Comment
        uses: actions/github-script@v7
        with:
          script: |
            const review = require('fs').readFileSync('review.md', 'utf8');
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: review
            });
```

| 장점 | 단점 |
|------|------|
| 완전 자동화 | 실시간 대화 불가 |
| 일정 기반 예측 가능 | 예외 상황 대응이 느림 |
| 여러 알림 채널 지원 | 초기 설정에 시간 소요 |

## 방법별 추천 시나리오

| 시나리오 | 추천 방법 | 이유 |
|----------|----------|------|
| 긴급 버그 수정 | SSH + tmux | 전체 터미널 제어 가능 |
| 이동 중 코드 리뷰 | Channels | 채팅으로 자연스럽게 요청 |
| 야간 배치 작업 | 자동화 봇 | 사람이 안 봐도 동작 |
| PR 모니터링 | GitHub Actions | 이벤트 기반 자동 실행 |
| 팀 공유 | 디스코드 Channels | 채널 멤버 모두 접근 가능 |

## 보안 고려사항

원격으로 코딩 에이전트를 제어할 때 꼭 확인해야 할 보안 항목이에요:

| 항목 | 권장 설정 |
|------|----------|
| SSH 인증 | 키 기반 인증, 비밀번호 로그인 비활성화 |
| 네트워크 접근 | Tailscale/WireGuard VPN 사용 |
| 봇 토큰 관리 | 환경변수로 관리, 코드에 하드코딩 금지 |
| 에이전트 권한 | 파일 시스템 접근 범위 제한 |
| 실행 로그 | 모든 원격 명령 로그 기록 |
| 2FA | SSH와 봇 계정 모두 2단계 인증 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| SSH 연결이 자주 끊김 | `ServerAliveInterval 60` 설정 + tmux로 세션 유지 |
| tmux 세션이 사라짐 | systemd 서비스로 자동 재시작 설정 |
| 봇이 응답하지 않음 | 봇 프로세스 상태 확인 + 로그 점검 |
| Tailscale 연결 불안정 | `tailscale ping` 으로 상태 확인, 릴레이 서버 변경 |
| 모바일 키보드로 코딩이 불편 | 음성 입력 + 프롬프트 템플릿 사전 저장 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
