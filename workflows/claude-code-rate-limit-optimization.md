# Claude Code 레이트 리밋 최적화 워크플로우 — 2배 확대로 달라진 세션 전략

> 2026년 5월 레이트 리밋 2배 확대 이후, 집중 코딩 세션을 어떻게 설계하면 한계를 덜 만날 수 있는지 정리했습니다.

## 배경

Anthropic이 SpaceX Colossus 1 파트너십 이후 Claude Code의 5시간 레이트 리밋을 2배로 늘렸습니다. 피크 타임 스로틀링도 제거됐습니다. 좋은 소식이지만, 여전히 한계는 존재합니다. 특히 Opus 모델을 쓰거나 멀티 에이전트를 동시에 실행하면 빠르게 소진됩니다.

## 레이트 리밋 소진 주요 원인

| 원인 | 토큰 소비 규모 |
|------|--------------|
| Opus 모델 사용 | Sonnet 대비 ~5배 |
| ultrathink / xhigh effort | 추가 2~3배 |
| 서브에이전트 병렬 실행 | 팀원 수에 비례 |
| 대형 파일 반복 Read | 컨텍스트 중복 누적 |
| 결과 보고 루프 | 서브에이전트 수 × 컨텍스트 |

## Phase 1: 세션 시작 전 — 작업 분류

### 모델 선택 기준

```bash
# .claude/settings.json 예시 — 작업 유형별 기본 모델 지정
{
  "defaultModel": "claude-sonnet-4-7",
  "taskProfiles": {
    "refactor": "claude-sonnet-4-7",
    "architecture": "claude-opus-4-7",
    "debug": "claude-sonnet-4-7",
    "review": "claude-opus-4-7"
  }
}
```

간단한 수정, 리팩토링, 테스트 작성은 Sonnet으로 처리합니다. Opus는 아키텍처 설계나 복잡한 버그 분석에만 씁니다.

### 작업 배치 계획

하루 세션을 3구간으로 나누는 게 효과적입니다.

| 구간 | 시간대 | 작업 유형 | 모델 |
|------|--------|---------|------|
| 아침 집중 | 09:00–12:00 | 고난도 설계 | Opus |
| 오후 구현 | 13:00–17:00 | 기능 구현 | Sonnet |
| 저녁 정리 | 19:00–21:00 | 코드 리뷰, 문서 | Sonnet |

## Phase 2: 세션 중 — 컨텍스트 관리

### 핵심 규칙: 파일을 반복해서 읽지 않기

```markdown
# CLAUDE.md에 추가할 규칙 예시
- 한 세션에서 같은 파일을 두 번 Read하지 말 것
- 파일 내용이 필요하면 앞선 Read 결과를 재사용할 것
- 대형 파일(500줄 이상)은 필요한 섹션만 Read할 것
```

### 서브에이전트 수 제한

```bash
# Agent Teams 사용 시 — 적정 팀 규모
# 소규모 기능: 2명 (구현자 + 테스터)
# 중규모 기능: 3명 (플래너 + 구현자 + 테스터)
# 대규모 리팩토링: 4명 최대

# 팀 규모가 커질수록 토큰 소비는 선형으로 증가
# 5명 팀 = 1명 × 5배 소비
```

### /model 명령어로 동적 전환

```
# 세션 중간에 모델 전환
/model claude-sonnet-4-7

# 복잡한 부분만 Opus로
/model claude-opus-4-7
[복잡한 작업 처리]
/model claude-sonnet-4-7  ← 다시 Sonnet으로
```

## Phase 3: 레이트 리밋 예측

### 간단한 사용량 추정

```bash
# 현재 세션 토큰 사용 추이 확인 (OpenTelemetry가 있는 경우)
# skill_activated 이벤트 로그 분석
cat ~/.claude/logs/session-*.jsonl 2>/dev/null | \
  python3 -c "
import sys, json
total = 0
for line in sys.stdin:
    try:
        d = json.loads(line)
        if 'usage' in d:
            total += d['usage'].get('input_tokens', 0)
            total += d['usage'].get('output_tokens', 0)
    except:
        pass
print(f'추정 사용 토큰: {total:,}')
"
```

### 리밋 도달 전 체크포인트

긴 작업 시작 전에 체크포인트를 만들어두면 리밋 도달 후 재개가 쉽습니다.

```bash
# 작업 시작 시
git stash push -m "checkpoint-before-large-refactor-$(date +%H%M)"

# 단계마다
git add -A && git commit -m "checkpoint: [단계명] 완료"
```

## Phase 4: 병렬 작업 설계

### Git Worktree 기반 세션 분리

```bash
# 레이트 리밋을 분산시키는 방법 — 서로 다른 worktree에서 작업
git worktree add ../feature-auth feature/auth
git worktree add ../feature-api feature/api

# 각 worktree에서 별도 Claude Code 세션 실행
# 세션이 분리되어 있으면 토큰 소비도 독립적
```

### 백그라운드 에이전트 활용

```bash
# 리뷰나 문서화처럼 응답을 기다릴 필요 없는 작업은
# Tasks로 백그라운드 처리
/task "tests/ 디렉토리 전체 테스트를 실행하고 실패 목록만 파일로 저장해줘"
# → 다른 작업을 계속하면서 결과를 나중에 확인
```

## 플랜별 실용 기준

| 플랜 | 적합한 사용 패턴 | 레이트 리밋 도달 빈도 |
|------|----------------|------------------|
| Pro | 주 1~2일, Sonnet 위주 | 드물게 |
| Max 5x | 주 3~4일, Opus 혼용 | 가끔 |
| Max 20x | 매일, 멀티 에이전트 | 드물게 |
| API 직접 | 정밀 비용 관리 필요 | 없음 (청구 기반) |

Max 20x 플랜은 멀티 에이전트를 매일 사용하는 팀에서 가장 효율적입니다. 반면 단독 개발자가 주 2~3일만 쓴다면 API 직접 연결이 더 저렴한 경우가 많습니다.

## 체크리스트

- [ ] 세션 시작 전 작업 유형에 맞는 모델 설정
- [ ] CLAUDE.md에 파일 중복 Read 금지 규칙 추가
- [ ] 긴 작업 시작 전 git 체크포인트 생성
- [ ] 서브에이전트 팀 크기를 필요 최소한으로 유지
- [ ] 단순 작업은 Sonnet, 복잡한 설계는 Opus로 분리
- [ ] Git Worktree로 대규모 병렬 작업 격리

## 다음 단계

→ [Git Worktree 병렬 에이전트 가이드](../guides/91-git-worktree-parallel-agents-guide.md)
→ [Claude Code 비동기 백그라운드 에이전트 운영](../claude-code/playbooks/49-async-background-agent-operations.md)
→ [AI 에이전트 비용 최적화 실전 플레이북](../claude-code/playbooks/38-cost-optimization-playbook.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
