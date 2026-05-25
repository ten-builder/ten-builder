# 가이드 108: Claude Code Week 28 실전 가이드 — 멀티에이전트 & Dreaming 완전 정복

> 2026년 5월 말 기준 Claude Code의 핵심 기능 세 가지 — 멀티에이전트 오케스트레이션, Dreaming, Outcomes — 를 실전에서 어떻게 쓰는지 정리합니다.

## 소요 시간

20-30분

## 사전 준비

- Claude Code 최신 버전 설치
- Claude Managed Agents 접근 권한 (public beta)
- GitHub 레포 + 기본 CLAUDE.md 설정 완료

---

## 핵심 변경 사항 요약

| 기능 | 상태 | 주요 변화 |
|------|------|----------|
| 멀티에이전트 오케스트레이션 | public beta | 에이전트 팀을 단일 명령으로 실행 |
| Dreaming | public beta | 에이전트가 이전 세션에서 스스로 학습 |
| Outcomes | public beta | 성공 기준을 설정하면 에이전트가 자체 검증 |
| VS Code 병렬 서브에이전트 | GA | IDE에서 바로 여러 에이전트 실행 |

---

## Step 1: 멀티에이전트 오케스트레이션 설정

### 에이전트 팀 정의

가장 빠른 시작 방법은 단일 프롬프트로 에이전트 팀을 구성하는 것입니다.

```bash
# PR 리뷰 에이전트 팀 실행
claude "PR #142를 리뷰하는 에이전트 팀을 만들어줘.
에이전트 3개:
- 보안 검토 전담 (인증, 권한, 인젝션 취약점)
- 성능 분석 전담 (쿼리, 번들 크기, 메모리)
- 코드 품질 전담 (가독성, 테스트, 문서화)

각 에이전트는 독립적으로 리뷰 후 결과를 취합해줘."
```

### git worktree 병렬 작업 패턴

서로 다른 기능을 동시에 개발할 때:

```bash
# worktree 3개 생성
git worktree add ../feature-auth -b feature/auth-refactor
git worktree add ../feature-api -b feature/api-optimization
git worktree add ../feature-ui -b feature/ui-components

# 각 worktree에 에이전트 배정
cd ../feature-auth && claude "인증 모듈 리팩토링 완료 후 PR 생성까지" &
cd ../feature-api && claude "API 응답 캐싱 구현" &
cd ../feature-ui && claude "공통 컴포넌트 라이브러리 구축" &
```

### CLAUDE.md에 팀 역할 정의

```markdown
# 에이전트 팀 구성 (멀티에이전트 모드)

## 오케스트레이터
- 전체 작업 계획 및 서브에이전트 지시
- 결과 취합 및 최종 검토

## 서브에이전트 역할
- **개발자**: 기능 구현, 테스트 작성
- **리뷰어**: 코드 품질, 보안 검토
- **문서화**: README, 주석, API 문서

## 통신 규칙
- 중간 결과는 /tmp/agent-{role}-output.md에 저장
- 충돌 발생 시 오케스트레이터에 에스컬레이션
```

---

## Step 2: Dreaming으로 에이전트 자기 학습 설정

Dreaming은 에이전트가 이전 세션을 분석해서 반복 실수를 줄이고 작업 패턴을 개선하는 기능입니다.

### 어떻게 작동하는가

Dreaming은 세션 사이에 비동기로 실행됩니다:

1. 에이전트가 이전 세션 트랜스크립트를 분석
2. 반복된 실수 패턴, 성공한 워크플로우를 메모리에 저장
3. 다음 세션에서 개선된 방식으로 시작

### API 설정 (Managed Agents 사용 시)

```python
import anthropic

client = anthropic.Anthropic()

# Dream 실행 요청
dream = client.beta.managed_agents.dreams.create(
    inputs=[
        {
            "type": "memory_store",
            "memory_store_id": "memstore_01Hx..."
        },
        {
            "type": "sessions",
            "session_ids": ["sesn_01...", "sesn_02...", "sesn_03..."]
        }
    ],
    instructions="코드 리뷰 패턴과 반복 실수를 분석해서 메모리를 업데이트해줘"
)

print(f"Dream ID: {dream.id}, Status: {dream.status}")
```

### 실전 활용: 주간 Dreaming 스케줄

```bash
# cron으로 매주 금요일 오후 6시 Dreaming 실행
0 18 * * 5 /usr/local/bin/trigger-dreaming.sh
```

```bash
#!/bin/bash
# trigger-dreaming.sh
# 지난 주 세션 ID 수집 후 Dreaming API 호출
python3 << 'EOF'
import anthropic
from datetime import datetime, timedelta

client = anthropic.Anthropic()

# 지난 7일 세션 조회
sessions = client.beta.managed_agents.sessions.list(
    created_after=(datetime.now() - timedelta(days=7)).isoformat()
)

# Dreaming 실행
dream = client.beta.managed_agents.dreams.create(
    inputs=[
        {"type": "sessions", "session_ids": [s.id for s in sessions.data]}
    ]
)
print(f"Dreaming started: {dream.id}")
EOF
```

---

## Step 3: Outcomes로 자체 검증 설정

Outcomes는 에이전트에게 "완료 기준"을 명확히 주는 기능입니다. 에이전트가 스스로 기준을 충족했는지 확인하고 반복합니다.

### 기본 사용법

```bash
claude --outcomes "$(cat outcomes.yaml)" "결제 모듈 구현해줘"
```

```yaml
# outcomes.yaml
success_criteria:
  - description: "단위 테스트 커버리지 80% 이상"
    check: "pytest --cov=payment --cov-report=term | grep TOTAL | awk '{print $4}'"
    expected: ">= 80%"
  
  - description: "결제 API 엔드포인트 모두 응답"
    check: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/api/payments"
    expected: "200"
  
  - description: "타입 에러 없음"
    check: "mypy payment/ --ignore-missing-imports"
    expected: "exit_code: 0"

max_iterations: 5
on_failure: "에러 로그를 분석하고 수정 방향을 제시해줘"
```

### 실전 패턴: 빌드 + 배포 파이프라인

```bash
claude "스테이징 배포 완료해줘" --outcomes "$(cat << 'EOF'
success_criteria:
  - description: "빌드 성공"
    check: "npm run build 2>&1 | tail -1"
    expected: "Build completed"
  - description: "테스트 통과"
    check: "npm test -- --passWithNoTests"
    expected: "exit_code: 0"
  - description: "헬스체크 통과"
    check: "curl -f https://staging.myapp.com/health"
    expected: "exit_code: 0"
EOF
)"
```

---

## Step 4: VS Code에서 병렬 서브에이전트 실행

VS Code January 2026 (1.109) 이상에서 GitHub Copilot과 함께 Claude/Codex 에이전트를 병렬로 실행할 수 있습니다.

### 설정 방법

```json
// .vscode/settings.json
{
  "github.copilot.chat.agent.enabled": true,
  "claude.agent.maxParallel": 3,
  "claude.agent.worktreeEnabled": true
}
```

### 사용 패턴

| 상황 | 추천 방식 |
|------|----------|
| 빠른 코드 질문 | Copilot 로컬 에이전트 |
| 긴 리팩토링 작업 | Claude 비동기 에이전트 |
| 병렬 기능 개발 | Claude worktree 멀티에이전트 |
| 코드 리뷰 | Claude 리뷰어 에이전트 팀 |

---

## 체크리스트

- [ ] CLAUDE.md에 에이전트 팀 역할과 통신 규칙 정의
- [ ] Outcomes 기준 파일(outcomes.yaml) 레포에 추가
- [ ] git worktree 병렬 작업 패턴 팀에 공유
- [ ] Dreaming 주간 스케줄 설정 (Managed Agents 사용 시)
- [ ] VS Code 병렬 서브에이전트 설정 확인

## 실전 팁

**에이전트 팀 크기:** 3-5개가 최적입니다. 그 이상은 오케스트레이션 비용이 급증합니다.

**Dreaming 빈도:** 프로젝트 초기는 매일, 안정 단계는 주 1회로 줄여도 충분합니다.

**Outcomes 기준:** 너무 엄격하면 반복이 무한히 돌 수 있습니다. `max_iterations`를 반드시 설정하세요.

---

## 다음 단계

→ [플레이북 72: 마이크로프론트엔드 아키텍처](../claude-code/playbooks/72-micro-frontend-architecture-playbook.md)
→ [가이드 107: Claude Code Week 27](107-claude-code-week27-features-guide.md)
→ [워크플로우: 멀티 레포 동기화](../workflows/ai-multi-repo-synchronized-workflow.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder) | **YouTube:** [@ten-builder](https://youtube.com/@ten-builder)
