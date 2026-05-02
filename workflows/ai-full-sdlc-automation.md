# AI 에이전트 기반 SDLC 전 단계 자동화 워크플로우

> 요구사항 분석부터 배포·모니터링까지 소프트웨어 개발 생명주기(SDLC) 전 단계를 AI 에이전트로 자동화하는 통합 워크플로우

## 개요

AI 에이전트가 코드 작성을 넘어 SDLC 전 단계에 관여하기 시작했습니다. 기능 요청 하나가 들어오면 AI 에이전트가 요구사항을 정리하고, 설계를 제안하고, 코드를 작성하고, 테스트를 생성하고, CI/CD를 통해 배포하고, 배포 후 이상을 감지하는 전 과정을 처리합니다.

이 워크플로우는 6단계 ADLC(Agentic Development Lifecycle)를 기준으로, 각 단계에서 AI 에이전트가 실제로 어떻게 작동하는지 다룹니다. 개발자는 코드 작성자가 아닌 **오케스트레이터**가 됩니다.

## 사전 준비

- Claude Code 또는 Codex CLI 설치
- GitHub Actions 또는 GitLab CI 설정된 레포
- Docker + Kubernetes (또는 동등한 배포 환경)
- 기본 모니터링 스택 (Prometheus + Grafana 권장)

## Step 1: 요구사항 분석 및 스펙 생성

이슈나 PRD 초안을 AI 에이전트에게 주면 실행 가능한 스펙으로 변환합니다.

```bash
# 자연어 요구사항 → 구조화된 스펙
claude "다음 기능 요청을 분석해서 구현 스펙을 작성해줘:
'사용자가 게시글에 이모지 반응을 추가할 수 있어야 하고,
실시간으로 카운트가 업데이트되어야 함'

포함 항목:
1. 유저 스토리 (Given-When-Then 형식)
2. API 엔드포인트 설계 (HTTP 메서드, 경로, 페이로드)
3. 데이터 모델 변경사항
4. 엣지 케이스 목록
5. 완료 기준 체크리스트"
```

AI가 생성하는 스펙 예시:

| 항목 | 내용 |
|------|------|
| 유저 스토리 | Given 로그인한 사용자, When 게시글에 이모지 클릭, Then DB에 반응 저장 + 실시간 카운트 업데이트 |
| API | `POST /posts/:id/reactions`, `DELETE /posts/:id/reactions/:emoji` |
| 실시간 | WebSocket 또는 SSE로 카운트 브로드캐스트 |
| 엣지 케이스 | 동일 사용자 중복 반응, 로그인 없는 접근, 삭제된 게시글 반응 |

이 스펙이 이후 모든 단계의 기준이 됩니다.

## Step 2: 아키텍처 설계 및 코드 생성

스펙을 기반으로 AI 에이전트가 구현 계획을 수립하고 코드를 생성합니다.

```bash
# 기존 코드베이스 맥락을 주고 구현 계획 수립
claude "reactions-spec.md와 현재 레포 구조를 분석해서
구현 계획을 단계별로 수립해줘.
변경할 파일 목록, 순서, 각 파일에서 할 작업을 정리하고
기존 패턴(컨트롤러/서비스/리포지토리 구조)을 따라줘."

# 계획 확인 후 구현 실행
claude "계획대로 이모지 반응 기능을 구현해줘.
테스트 코드도 함께 작성하고,
변경 완료 후 git diff를 보여줘."
```

**포인트:** 한 번에 전부 맡기지 말고, 계획 확인 → 구현 → 리뷰 순서로 진행합니다.

## Step 3: 테스트 자동화

AI 에이전트가 구현과 동시에 또는 직후에 테스트 스위트를 생성합니다.

```bash
# 단위 테스트 + 통합 테스트 일괄 생성
claude "방금 구현한 reactions 모듈에 대해
다음 테스트를 작성해줘:
1. 단위 테스트: ReactionService 각 메서드
2. 통합 테스트: POST /reactions API 엔드포인트
3. 엣지 케이스: 중복 반응, 인증 없는 요청, 존재하지 않는 게시글

기존 테스트 파일 구조와 동일한 패턴을 사용해줘."

# 테스트 실행 및 커버리지 확인
npm test -- --coverage
```

목표 커버리지 기준:

| 테스트 종류 | 최소 목표 |
|------------|---------|
| 단위 테스트 | 80% |
| 통합 테스트 | 핵심 경로 100% |
| E2E 테스트 | 주요 사용자 시나리오 |

## Step 4: CI/CD 파이프라인 통합

변경사항을 PR로 올리면 CI가 자동으로 검증하고 배포합니다.

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review + Deploy

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Tests
        run: npm test -- --coverage

      - name: Check Coverage Threshold
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% below threshold"
            exit 1
          fi

      - name: Security Scan
        run: npm audit --audit-level=high

  deploy-staging:
    needs: ai-review
    if: github.base_ref == 'main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Staging
        run: |
          docker build -t app:${{ github.sha }} .
          kubectl set image deployment/app app=app:${{ github.sha }} \
            --namespace=staging
```

## Step 5: 배포 후 모니터링

AI 에이전트를 배포 후 이상 감지에도 활용합니다.

```bash
# 배포 직후 헬스체크 스크립트
#!/bin/bash
DEPLOY_SHA=$1
BASELINE_ERROR_RATE=$(curl -s "http://prometheus/api/v1/query?query=error_rate[5m]&time=$(date -d '10 minutes ago' +%s)" | jq '.data.result[0].value[1]')
CURRENT_ERROR_RATE=$(curl -s "http://prometheus/api/v1/query?query=error_rate[2m]" | jq '.data.result[0].value[1]')

# 에러율이 2배 이상 증가하면 자동 롤백
if (( $(echo "$CURRENT_ERROR_RATE > $BASELINE_ERROR_RATE * 2" | bc -l) )); then
  echo "Error rate spike detected. Rolling back..."
  kubectl rollout undo deployment/app
  # AI 에이전트에게 로그 분석 요청
  kubectl logs -l app=api --since=10m | \
    claude "최근 10분간 에러 로그를 분석해서
    주요 에러 패턴과 가능한 원인을 정리해줘."
fi
```

## Step 6: 회고 및 지식 축적

각 기능 개발 후 AI 에이전트와 함께 개선점을 정리합니다.

```bash
# 이번 피처 개발 결과를 CLAUDE.md에 반영
claude "이번 reactions 기능 개발 과정에서
다음 항목을 분석하고 CLAUDE.md 개선 제안을 만들어줘:
1. 예상보다 시간이 걸린 부분 (이유와 해결책)
2. 테스트에서 발견된 버그 패턴
3. 다음에 비슷한 기능 개발 시 미리 설정할 것"
```

## 전체 흐름 요약

```
기능 요청
   ↓
[Step 1] AI → 구조화된 스펙 생성
   ↓
[Step 2] AI → 구현 계획 + 코드 생성
   ↓
[Step 3] AI → 테스트 자동 생성 + 실행
   ↓
[Step 4] CI → 검증 + 스테이징 배포
   ↓
개발자 리뷰 & 승인
   ↓
[Step 4] CD → 프로덕션 배포
   ↓
[Step 5] AI → 배포 후 이상 감지
   ↓
[Step 6] AI → 회고 + CLAUDE.md 갱신
```

## 개발자가 집중할 부분

AI 에이전트에게 작업을 위임해도 개발자 판단이 필요한 순간이 있습니다:

| 단계 | 개발자 역할 |
|------|-----------|
| 요구사항 | 비즈니스 맥락과 우선순위 결정 |
| 설계 | 아키텍처 방향 최종 확인 |
| 코드 리뷰 | 보안·성능 민감 로직 직접 검토 |
| 배포 | 프로덕션 배포 최종 승인 |
| 회고 | 팀 컨텍스트 반영 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| AI가 기존 패턴 무시하고 새 패턴 사용 | CLAUDE.md에 기존 패턴 명시 |
| 생성된 테스트가 너무 단순 | "엣지 케이스 5개 이상 포함" 지시 추가 |
| 배포 후 성능 저하 | 스테이징에서 부하 테스트 단계 추가 |
| 스펙이 모호해 AI가 잘못 구현 | 스펙 검증 단계를 Step 1.5로 추가 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
