# Claude Code Week 21 실전 가이드 — 스크롤 다이얼로그, Fork 서브에이전트, OpenTelemetry 스킬 이벤트

> 2026년 5월 4~8일 릴리스(v2.1.128~) 핵심 업데이트를 정리하고, 각 기능을 실무에 바로 적용하는 방법을 다룹니다.

## 이번 주 핵심 변경사항

| 버전 | 주요 변경 |
|------|----------|
| v2.1.128 | 터미널 다이얼로그 스크롤, URL 전체 열기 수정 |
| v2.1.128 | `CLAUDE_CODE_FORK_SUBAGENT=1` 비대화 세션 지원 |
| v2.1.128 | `--dangerously-skip-permissions` 스킬 디렉토리 쓰기 허용 |
| v2.1.128+ | `claude_code.skill_activated` OpenTelemetry 이벤트 |
| v2.1.128+ | Auto mode 권한 대기 시 스피너 적색 표시 |
| v2.1.128+ | RAM 사용량 감소 + 세션 로딩 최적화 |

## 1. 터미널 다이얼로그 스크롤 지원

Claude Code가 긴 권한 요청이나 도구 설명을 표시할 때 다이얼로그가 터미널 창 높이를 넘으면 내용이 잘리는 문제가 있었습니다.
v2.1.128부터 다이얼로그가 터미널을 넘는 경우 스크롤이 가능해졌습니다.

**지원하는 스크롤 방법:**

| 방법 | 동작 |
|------|------|
| 화살표 키 (`↑`/`↓`) | 한 줄씩 스크롤 |
| `PgUp` / `PgDn` | 페이지 단위 스크롤 |
| `Home` / `End` | 처음/끝으로 이동 |
| 마우스 휠 | 터치패드/마우스 스크롤 |

전체화면 모드와 일반 모드 모두 지원합니다. MCP 서버 목록, 긴 권한 설명, 스킬 설치 확인 다이얼로그에서 특히 유용합니다.

**긴 URL 자동 열기 수정:**

전체화면 모드에서 URL이 여러 줄에 걸쳐 표시되는 경우 첫 번째 줄만 클릭해도 전체 URL이 열립니다. 이전에는 URL이 잘려 브라우저에서 404가 발생하는 경우가 있었습니다.

## 2. Fork 서브에이전트 비대화 세션 지원

비대화(non-interactive) 세션에서도 포크 서브에이전트를 사용할 수 있게 되었습니다.

```bash
# CI/CD 파이프라인에서 포크 서브에이전트 활성화
CLAUDE_CODE_FORK_SUBAGENT=1 claude -p "레포 전체 테스트를 실행하고 실패 케이스를 수정해줘" --output-format json
```

**언제 쓰는가:**

| 상황 | 활용 |
|------|------|
| GitHub Actions CI | 테스트 실패 자동 수정 서브에이전트 포크 |
| 배치 코드 분석 | 여러 파일을 독립 서브에이전트로 병렬 분석 |
| 야간 자동화 스크립트 | 서버에서 무인 실행 중 서브에이전트 분기 |

이전에는 `-p` 플래그(print/비대화 모드)와 `FORK_SUBAGENT`가 충돌해 서브에이전트 생성이 실패했습니다. 이제 CI/CD 환경에서도 에이전트 팀을 활용할 수 있습니다.

## 3. 스킬 디렉토리 자동 쓰기 권한

`--dangerously-skip-permissions` 플래그를 사용하는 완전 자율 실행 모드에서 스킬·에이전트·커맨드 디렉토리 쓰기 시 더 이상 권한 프롬프트가 표시되지 않습니다.

```bash
# 이전: 스킬 설치 시 권한 프롬프트 발생
claude --dangerously-skip-permissions

# 이후: 아래 경로는 자동 허용
# .claude/skills/
# .claude/agents/
# .claude/commands/
```

**자동화 파이프라인 활용 예시:**

```bash
#!/bin/bash
# CI에서 스킬 자동 설치 후 실행
claude --dangerously-skip-permissions <<'EOF'
/skills install ai-code-reviewer
/skills install test-generator
테스트 커버리지가 80% 미만인 파일을 찾아서 테스트를 만들어줘
EOF
```

이 변경으로 스킬 기반 자동화 워크플로우에서 불필요한 사람 개입이 줄어듭니다.

## 4. OpenTelemetry 스킬 이벤트 추적

`claude_code.skill_activated` OpenTelemetry 이벤트가 사용자 슬래시 커맨드에도 발행되기 시작했습니다.

**이벤트 속성:**

```json
{
  "event": "claude_code.skill_activated",
  "skill_name": "ai-code-reviewer",
  "invocation_trigger": "user-slash"
}
```

`invocation_trigger` 값 종류:

| 값 | 설명 |
|----|------|
| `"user-slash"` | 사용자가 직접 `/skill-name` 입력 |
| `"claude-proactive"` | Claude가 문맥 파악 후 자동 호출 |
| `"nested-skill"` | 다른 스킬 내부에서 호출 |

**실무 활용 — 팀 대시보드 연동:**

```yaml
# OpenTelemetry Collector 설정
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"

processors:
  filter/skill_events:
    traces:
      span:
        - 'attributes["event"] == "claude_code.skill_activated"'

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
```

어떤 스킬이 얼마나 자주, 어떤 방식으로 호출되는지 추적하면 팀의 AI 활용 패턴을 파악하고 자주 쓰는 스킬을 최적화할 수 있습니다.

## 5. Auto Mode 권한 대기 시각화 개선

Auto mode(`shift+tab`으로 활성화)에서 Claude가 권한 확인 대기 중일 때 기존에는 스피너가 계속 돌아가 "뭔가 실행 중"처럼 보였습니다. 이제 스피너가 **빨간색**으로 바뀌어 즉시 구분할 수 있습니다.

```
# 정상 실행 중
⠸ 파일 분석 중...   ← 기본 색상 스피너

# 권한 대기 중
⠸ 권한 확인 대기    ← 빨간색 스피너
```

긴 자율 실행 세션에서 Claude가 멈춘 게 아니라 승인을 기다리고 있다는 사실을 빠르게 파악할 수 있습니다.

## 6. 성능 개선 — RAM 감소 + 세션 로딩

v2.1.128+에서 전반적인 메모리 사용량이 감소했고, 세션 로딩(`/resume`) 속도가 빨라졌습니다.

**체감할 수 있는 상황:**

| 상황 | 개선 효과 |
|------|----------|
| 동시에 여러 Claude Code 세션 실행 | RAM 사용 감소 |
| 대형 레포 세션 재개(`/resume`) | 로딩 시간 단축 |
| 장시간 실행 후 세션 메모리 | 점진적 증가 완화 |

8GB RAM 맥북에서 2-3개 세션을 동시에 돌리거나, 1M 토큰급 긴 컨텍스트를 사용하는 경우 차이가 느껴집니다.

## 이번 주 업데이트 활용 체크리스트

```
[ ] 긴 MCP 서버 목록 확인 시 스크롤 키 활용
[ ] CI 파이프라인에 CLAUDE_CODE_FORK_SUBAGENT=1 추가 검토
[ ] 스킬 자동화 스크립트에서 권한 프롬프트 제거 확인
[ ] OpenTelemetry Collector 있다면 skill_activated 이벤트 수집 설정
[ ] Auto mode 사용 시 빨간 스피너 = 승인 대기 기억
```

## 다음 단계

스킬 자동화를 처음 시도한다면 → [커스텀 MCP 서버 빌드 플레이북](../claude-code/playbooks/45-custom-mcp-server-build-deploy.md)

CI/CD에서 Claude 활용이 궁금하다면 → [CI/CD 파이프라인 자동 최적화 워크플로우](../workflows/ai-cicd-pipeline-optimization.md)

이전 주 릴리스가 궁금하다면 → [Week 20 가이드](./83-claude-code-week20-features-guide.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
