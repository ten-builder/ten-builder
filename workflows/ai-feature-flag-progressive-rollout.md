# AI 에이전트 피처 플래그 기반 점진적 롤아웃 워크플로우

> 새 기능을 한 번에 전체 배포하면 사고 납니다. AI 에이전트가 피처 플래그로 카나리 → 10% → 100% 단계를 자동 관리하고, 이상 감지 시 즉시 롤백하는 워크플로우를 소개합니다.

## 왜 점진적 롤아웃인가

프로덕션에서 새 기능이 나쁜 결과를 내는 경우는 생각보다 자주 있습니다. 문제는 *언제* 나쁜 결과가 나오는지 미리 알 수 없다는 점입니다. 점진적 롤아웃은 전체 사용자가 영향받기 전에 소수 집단에서 먼저 검증합니다.

피처 플래그를 AI 에이전트와 결합하면:

- 배포와 릴리스를 분리해서 **코드는 늘 프로덕션에 있지만 기능만 켜고 끌 수** 있어요
- 에러율, 응답 시간, 전환율 메트릭을 AI가 지속 감시하다가 임계치 초과 시 자동 플래그 해제
- 개발자가 잠자는 동안에도 배포가 진행되고 문제가 생기면 스스로 롤백

## 사전 준비

- OpenFeature SDK 또는 LaunchDarkly / Flagsmith 계정
- Prometheus + Grafana 또는 Datadog (메트릭 수집)
- GitHub Actions (배포 파이프라인)
- Claude Code, Gemini CLI 등 AI 에이전트

## Step 1: 피처 플래그 설계

피처 플래그 하나에 담을 정보를 먼저 정의합니다.

```typescript
// feature-flags.ts
interface FeatureFlag {
  key: string;           // "new-checkout-flow"
  rolloutPercentage: number;  // 0 ~ 100
  targeting: {
    internal: boolean;   // 내부 직원 먼저
    canary: string[];    // 카나리 사용자 ID 목록
  };
  autoRollback: {
    enabled: boolean;
    errorRateThreshold: number;   // %
    latencyThreshold: number;     // ms (p99)
    evaluationWindowSec: number;  // 감시 윈도우
  };
}

const newCheckoutFlow: FeatureFlag = {
  key: "new-checkout-flow",
  rolloutPercentage: 0,
  targeting: {
    internal: true,
    canary: [],
  },
  autoRollback: {
    enabled: true,
    errorRateThreshold: 2.0,   // 에러율 2% 초과 시 롤백
    latencyThreshold: 500,      // p99 500ms 초과 시 롤백
    evaluationWindowSec: 300,   // 5분 윈도우
  },
};
```

## Step 2: OpenFeature SDK 통합

OpenFeature는 LaunchDarkly, Flagsmith, Unleash 등 다양한 피처 플래그 서비스를 공통 인터페이스로 다룹니다.

```typescript
// 설치
// npm install @openfeature/server-sdk @openfeature/launchdarkly-provider

import { OpenFeature } from "@openfeature/server-sdk";
import { LaunchDarklyProvider } from "@openfeature/launchdarkly-provider";

// 초기화 (앱 시작 시 1회)
await OpenFeature.setProvider(
  new LaunchDarklyProvider(process.env.LD_SDK_KEY)
);

const client = OpenFeature.getClient();

// 기능 분기
const useNewFlow = await client.getBooleanValue(
  "new-checkout-flow",
  false,    // 기본값 (플래그 없으면 false)
  { targetingKey: userId }
);

if (useNewFlow) {
  return newCheckoutHandler(req, res);
} else {
  return legacyCheckoutHandler(req, res);
}
```

## Step 3: 단계별 롤아웃 파이프라인

GitHub Actions에서 배포 후 AI 에이전트가 각 단계를 자동 진행합니다.

```yaml
# .github/workflows/progressive-rollout.yml
name: Progressive Rollout

on:
  workflow_dispatch:
    inputs:
      flag_key:
        description: "피처 플래그 키"
        required: true
      target_percentage:
        description: "최종 목표 % (기본 100)"
        default: "100"

jobs:
  rollout:
    runs-on: ubuntu-latest
    steps:
      - name: Phase 1 - Internal (0% → 직원만)
        run: |
          curl -s -X PATCH "$LD_API_URL/flags/${{ inputs.flag_key }}" \
            -H "Authorization: ${{ secrets.LD_API_KEY }}" \
            -d '{"targeting": {"internal": true}}'
          echo "내부 직원 대상 활성화 완료"

      - name: Wait and check metrics (5 min)
        run: |
          sleep 300
          python3 scripts/check-metrics.py \
            --flag "${{ inputs.flag_key }}" \
            --phase internal

      - name: Phase 2 - Canary (5%)
        if: success()
        run: |
          ./scripts/set-rollout.sh "${{ inputs.flag_key }}" 5

      - name: Wait and check metrics (15 min)
        run: |
          sleep 900
          python3 scripts/check-metrics.py \
            --flag "${{ inputs.flag_key }}" \
            --phase canary

      - name: Phase 3 - 10% rollout
        if: success()
        run: ./scripts/set-rollout.sh "${{ inputs.flag_key }}" 10

      - name: Phase 4 - 50% rollout
        if: success()
        run: |
          sleep 1800
          python3 scripts/check-metrics.py --flag "${{ inputs.flag_key }}" --phase 10pct
          ./scripts/set-rollout.sh "${{ inputs.flag_key }}" 50

      - name: Phase 5 - Full rollout
        if: success()
        run: ./scripts/set-rollout.sh "${{ inputs.flag_key }}" 100
```

## Step 4: 메트릭 감시 + 자동 롤백 스크립트

```python
# scripts/check-metrics.py
import sys
import requests
import argparse

def check_metrics(flag_key: str, phase: str) -> bool:
    """Prometheus에서 메트릭을 조회하고 임계치를 초과하면 False 반환"""
    
    base_url = "http://prometheus:9090/api/v1/query"
    
    # 에러율 쿼리
    error_rate_query = f"""
        sum(rate(http_requests_total{{status=~"5..", feature="{flag_key}"}}[5m]))
        / sum(rate(http_requests_total{{feature="{flag_key}"}}[5m])) * 100
    """
    
    # p99 응답시간 쿼리
    latency_query = f"""
        histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket{{feature="{flag_key}"}}[5m]))
            by (le)
        ) * 1000
    """
    
    error_rate = float(query_prometheus(base_url, error_rate_query))
    latency_p99 = float(query_prometheus(base_url, latency_query))
    
    print(f"[{phase}] 에러율: {error_rate:.2f}% | p99: {latency_p99:.0f}ms")
    
    if error_rate > 2.0:
        print(f"에러율 임계치 초과 ({error_rate:.2f}% > 2%). 롤백 시작.")
        rollback(flag_key)
        sys.exit(1)
    
    if latency_p99 > 500:
        print(f"응답시간 임계치 초과 ({latency_p99:.0f}ms > 500ms). 롤백 시작.")
        rollback(flag_key)
        sys.exit(1)
    
    print("통과. 다음 단계 진행.")
    return True


def rollback(flag_key: str):
    """피처 플래그를 비활성화하여 즉시 롤백"""
    requests.patch(
        f"{LD_API_URL}/flags/{flag_key}",
        headers={"Authorization": LD_API_KEY},
        json={"on": False, "rolloutPercentage": 0}
    )
    # Slack/Discord 알림
    notify_team(f"자동 롤백 완료: {flag_key}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--flag", required=True)
    parser.add_argument("--phase", required=True)
    args = parser.parse_args()
    check_metrics(args.flag, args.phase)
```

## Step 5: AI 에이전트 프롬프트로 롤아웃 관리

```bash
# AI 에이전트에게 롤아웃 상황 설명 + 판단 위임
cat <<'EOF' | claude --print
현재 new-checkout-flow 피처 플래그 10% 롤아웃 중입니다.
지난 30분 메트릭:
- 에러율: 1.3% (기준: 2%)
- p99 응답시간: 280ms (기준: 500ms)
- 전환율: +4.2% (기존 대비)
- 이탈률: -0.8%

판단: 50%로 확대해도 되나요? 핵심 메트릭 분석 후 Go/No-Go 결정해주세요.
EOF
```

## 커스터마이징

| 설정 | 기본값 | 조정 시나리오 |
|------|--------|---------------|
| 카나리 비율 | 5% | 트래픽 많은 서비스는 1~2%로 시작 |
| 단계별 대기 시간 | 5~30분 | 결제/보안 기능은 24시간 이상 |
| 에러율 임계치 | 2% | 중요 API는 0.5%로 낮추기 |
| p99 임계치 | 500ms | UX 민감한 기능은 200ms |
| 평가 윈도우 | 5분 | 트래픽 적은 서비스는 15~30분 |

## 피처 플래그 청소 체크리스트

플래그를 방치하면 코드베이스가 복잡해집니다. 롤아웃 완료 후 2주 이내 정리합니다.

```bash
# AI 에이전트로 오래된 피처 플래그 탐지
grep -r "getBooleanValue\|isFeatureEnabled" src/ | \
  awk '{print $1}' | sort | uniq | \
  xargs -I{} bash -c 'echo "플래그: {}"'

# 또는 AI에게 요청
claude "src/ 디렉토리에서 feature flag 사용 코드를 찾아서, 
  90일 이상 된 플래그 목록을 만들어주세요. 
  내용: 플래그명, 파일 경로, 삭제 안전 여부"
```

## 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| 롤백 후 플래그가 다시 켜짐 | 파이프라인 재실행 | 플래그 상태를 CI 변수로 고정 |
| 카나리 사용자 경험 일관성 없음 | 세션 기반 타겟팅 미설정 | `targetingKey`에 세션 ID 사용 |
| 메트릭 지연으로 롤백 놓침 | 평가 윈도우 너무 짧음 | 최소 5분 이상으로 설정 |
| 플래그 SDK 장애 시 전체 비활성화 | 기본값이 false | 안전한 기능은 기본값 true 검토 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
