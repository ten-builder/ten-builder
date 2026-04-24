# 가이드 70: AI 에이전트 품질 저하 감지법 — Claude Code 사후 분석으로 배우는 신뢰성 설계

> 2026년 4월, Claude Code에서 6주에 걸친 품질 저하가 발생했습니다. 세 가지 독립적인 변경이 겹쳐 개발자들은 이상하게 느리고, 건망증 있고, 출력이 짧아진 에이전트를 경험했습니다. 무슨 일이 있었는지, 그리고 비슷한 상황에서 어떻게 빠르게 감지할 수 있는지 정리합니다.

## 무슨 일이 있었나

Anthropic은 2026년 4월 23일 공식 포스트모템을 공개했습니다. 세 가지 변경이 서로 다른 시점에 적용됐고, 각각의 증상이 겹쳐 원인을 파악하기 어려웠습니다.

| 변경 날짜 | 내용 | 증상 | 수정 날짜 |
|-----------|------|------|-----------|
| 3월 4일 | 기본 추론 노력을 `high`→`medium`으로 변경 | 응답 품질 저하, 복잡한 코드 실수 증가 | 4월 7일 |
| 3월 26일 | 유휴 세션 캐시 최적화 버그 | 에이전트가 이전 결정을 잊음, 반복적 동작 | 4월 10일 |
| 4월 16일 | 시스템 프롬프트에 응답 길이 제한 추가 | 코드 설명 생략, 중요한 주의사항 누락 | 4월 20일 |

## 개별 변경 내용 분석

### 변경 1: 추론 노력 기본값 하향

Claude Code는 추론 노력을 `xhigh / high / medium / low` 4단계로 설정할 수 있습니다. 기본값이 `high`에서 `medium`으로 바뀌었고, 이로 인해 복잡한 리팩토링이나 버그 진단에서 품질이 눈에 띄게 떨어졌습니다.

Anthropic의 설명에 따르면 내부 평가에서는 `medium`이 대부분의 태스크에서 크게 차이가 없었습니다. 하지만 실제 사용자 워크로드에서는 달랐습니다.

**개발자 관점에서 배울 점:**

```bash
# 현재 설정된 추론 노력 확인
/effort

# 복잡한 태스크에서 명시적으로 높은 추론 설정
/effort high
ultrathink 이 버그의 근본 원인을 분석해줘
```

추론 노력은 세션 단위로 유지됩니다. 복잡한 작업 전에는 `/effort high` 또는 `ultrathink` 접두사를 명시적으로 쓰는 습관이 도움됩니다.

### 변경 2: 유휴 세션 캐시 버그

설계 의도는 단순했습니다. 1시간 이상 유휴 상태가 된 세션을 재개할 때, 오래된 추론 블록을 정리해서 불필요한 토큰 비용을 줄이는 것이었습니다.

```
API 헤더: clear_thinking_20251015
파라미터: keep:1 (최신 추론 블록 1개만 유지)
```

구현 버그는 '한 번만 정리'가 아니라 '매 턴마다 정리'로 동작한 것입니다. 유휴 상태를 한 번 넘기면, 그 이후 모든 요청에서 이전 추론을 삭제했습니다. 에이전트는 각 턴마다 새로 시작하는 것처럼 행동했습니다.

**이 버그가 특히 잡기 어려웠던 이유:**

- 유휴 상태(>1시간) 이후에만 발생 → 짧은 테스트 세션에서 재현 불가
- 내부 서버 실험과 상호작용 → 일부 환경에서만 발생
- 증상(건망증, 반복)이 모델 자체의 확률적 특성과 구분 어려움

### 변경 3: 응답 길이 제한 시스템 프롬프트

Claude Opus 4.7은 이전 모델보다 출력이 길고 자세한 경향이 있습니다. 이를 줄이기 위해 시스템 프롬프트에 한 줄이 추가됐습니다:

> "Length limits: keep text between tool calls to ≤25 words. Keep final responses to ≤100 words unless the task requires more detail."

이 변경은 여러 주 동안 내부 평가를 통과했습니다. 하지만 더 넓은 평가 세트로 테스트했을 때 코딩 품질이 3% 낮아졌습니다.

25단어 제한은 도구 호출 사이의 설명에 적용됐는데, 코딩에서 도구 호출 사이의 설명은 다음 행동의 이유를 포함합니다. 이를 제한하면 컨텍스트 추론이 끊겼습니다.

## AI 에이전트 품질 저하를 빠르게 감지하는 방법

이번 사건의 핵심 교훈은 **에이전트 품질 변화를 측정하는 기준선이 없었다면 감지가 늦어진다**는 것입니다.

### 기준선 테스트 만들기

일정 주기로 동일한 태스크를 실행하고 결과를 비교합니다:

```bash
# 기준선 태스크 파일 (benchmark/baseline-tasks.md)
cat > benchmark/baseline-tasks.md << 'EOF'
# AI 에이전트 기준선 태스크

## Task 1: 버그 진단 (난이도: 중)
다음 함수의 엣지 케이스 버그를 찾고 수정해줘.

## Task 2: 리팩토링 (난이도: 고)
이 모듈을 단일 책임 원칙에 맞게 분리해줘.

## Task 3: 테스트 생성 (난이도: 중)
이 함수에 대한 단위 테스트를 작성해줘.
EOF
```

```python
# benchmark/measure_quality.py
import subprocess, json, time

def run_benchmark_task(task_prompt: str) -> dict:
    start = time.time()
    result = subprocess.run(
        ["claude", "--print", task_prompt],
        capture_output=True, text=True
    )
    elapsed = time.time() - start
    output = result.stdout
    
    return {
        "response_length": len(output),
        "elapsed_seconds": round(elapsed, 1),
        "has_code_block": "```" in output,
        "timestamp": time.strftime("%Y-%m-%d %H:%M"),
    }
```

### 이상 징후 체크리스트

에이전트 동작이 달라졌다고 느낄 때 빠르게 확인할 수 있는 항목들입니다:

| 증상 | 가능한 원인 | 확인 방법 |
|------|-----------|-----------|
| 복잡한 코드에서 실수가 늘었다 | 추론 노력 저하 | `/effort` 확인, `/effort high`로 강제 설정 |
| 이전 결정을 자꾸 잊는다 | 컨텍스트 관리 버그 | 세션 재시작 후 동작 비교 |
| 설명이 갑자기 짧아졌다 | 응답 길이 제한 | `claude --verbose` 또는 API로 직접 테스트 |
| 토큰 사용량이 급증했다 | 캐시 히트율 저하 | 사용량 대시보드 확인 |
| 에이전트가 이미 한 작업을 반복한다 | 추론 히스토리 손실 | 새 세션에서 동일 태스크 비교 |

### 공급업체 발표 모니터링

AI 코딩 도구 품질은 모델 자체가 아닌 제품 레이어 변경으로도 바뀔 수 있습니다:

```bash
# 주요 모니터링 소스
# 1. Anthropic 엔지니어링 블로그
# https://www.anthropic.com/engineering

# 2. @ClaudeDevs X/Twitter (공식 제품 업데이트)
# 3. Claude Code GitHub Releases
# https://github.com/anthropics/claude-code/releases

# 4. HN (hacker news) — 실제 사용자 경험이 빠르게 모임
curl -s "https://hn.algolia.com/api/v1/search?query=claude+code&tags=story&hitsPerPage=5" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
for h in d['hits']:
    print(h['points'], h['title'])
"
```

## 개발자가 직접 할 수 있는 완화 전략

### 전략 1: 추론 노력 명시적 지정

현재는 Opus 4.7 기본값이 `xhigh`, 나머지 모델은 `high`로 다시 돌아왔습니다. 하지만 언제 다시 바뀔지 모릅니다:

```markdown
# CLAUDE.md에 추가

## AI 에이전트 설정
- 복잡한 디버깅/아키텍처 결정: `ultrathink` 접두사 사용
- 단순 코드 생성: 기본값 유지
- 긴 세션 작업: 1시간마다 세션 재시작 고려
```

### 전략 2: 세션 길이 관리

3월 26일 캐싱 버그의 트리거는 1시간 이상 유휴 세션이었습니다. 비슷한 버그가 재발할 경우를 대비해:

```bash
# 긴 작업은 tmux 세션으로 관리하되 주기적으로 재시작
# tmux 기반 세션 재시작 스크립트
#!/bin/bash
THRESHOLD_HOURS=2
SESSION_NAME="claude-work"

while true; do
  tmux new-session -d -s "$SESSION_NAME" 2>/dev/null || true
  sleep $((THRESHOLD_HOURS * 3600))
  echo "세션 재시작: $(date)" >> ~/.claude-session.log
  tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
done
```

### 전략 3: 출력 길이 변화 감지

응답이 갑자기 짧아지면 프롬프트 레벨 제한이 추가됐을 가능성이 있습니다:

```python
# quality_monitor.py — 응답 길이 추적
import json, os, datetime

def log_response(task_name: str, response: str):
    log_path = os.path.expanduser("~/.claude-quality-log.jsonl")
    entry = {
        "date": datetime.date.today().isoformat(),
        "task": task_name,
        "length": len(response),
        "has_code": "```" in response,
    }
    with open(log_path, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

def check_trend():
    """최근 7일 평균 응답 길이를 비교"""
    from collections import defaultdict
    import statistics
    
    log_path = os.path.expanduser("~/.claude-quality-log.jsonl")
    if not os.path.exists(log_path):
        return
    
    daily = defaultdict(list)
    with open(log_path) as f:
        for line in f:
            e = json.loads(line)
            daily[e["date"]].append(e["length"])
    
    dates = sorted(daily.keys())[-14:]
    for d in dates:
        avg = statistics.mean(daily[d])
        print(f"{d}: 평균 {avg:.0f}자 ({len(daily[d])}개 샘플)")
```

## Anthropic이 약속한 개선 사항

포스트모템에서 Anthropic은 다음을 약속했습니다:

1. **시스템 프롬프트 변경 통제 강화** — 모든 시스템 프롬프트 변경에 광범위한 모델별 평가 실행, ablation 테스트 의무화
2. **내부 테스트 강화** — 직원들이 새 기능 빌드가 아닌 퍼블릭 빌드를 사용하도록 전환
3. **Code Review 도구 개선** — Opus 4.7이 실제로 해당 PR의 버그를 찾아낸 것처럼, 리포지토리 컨텍스트를 갖춘 코드 리뷰로 유사 버그 조기 감지
4. **점진적 롤아웃** — 지능 트레이드오프가 있는 변경은 소크 기간과 단계적 출시 적용

## 이번 사건이 주는 더 큰 교훈

AI 에이전트 도구는 소프트웨어입니다. 소프트웨어는 업데이트됩니다. 업데이트는 예상치 못한 방식으로 상호작용할 수 있습니다.

**개발 워크플로우에서 AI 에이전트를 신뢰성 있게 쓰려면:**

- 평소에 에이전트 동작의 기준선을 기록해두세요
- 품질 변화가 느껴지면 도구 버전 변경 이력을 먼저 확인하세요
- 중요한 코드에는 사람의 검수 단계를 유지하세요
- 공급업체의 공식 채널을 팔로우해서 알려진 이슈를 빠르게 파악하세요

AI 코딩 도구는 점점 더 유능해지고 있습니다. 하지만 의존도가 높은 도구일수록 예상치 못한 변화가 미치는 영향도 큽니다. 기준선을 갖고 변화를 측정하는 것이 안정적인 AI 협업의 핵심입니다.

---

**다음 가이드:** [가이드 58: AI 에이전트 오케스트레이터-워커 패턴](./58-ai-agent-orchestrator-patterns.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
