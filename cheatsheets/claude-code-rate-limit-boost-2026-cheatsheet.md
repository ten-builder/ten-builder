# Claude Code 주간 한도 50% 증가 — 실전 활용 치트시트

> Anthropic이 7월 13일까지 한시적으로 주간 사용 한도를 50% 높였다. 이 기회에 어떻게 더 많이 쓸 수 있는지 정리했다.

## 변경 내용 한눈에 보기

| 구분 | 기존 | 6월~7월 13일 |
|------|------|-------------|
| Pro 주간 한도 | 기준치 | +50% |
| Max 주간 한도 | 기준치 | +50% |
| 적용 시작 | — | 2026년 6월 |
| 적용 종료 | — | 2026년 7월 13일 |
| 이유 | — | 컴퓨팅 파트너십 확장 |

> 일시적 확대라는 점을 기억해야 한다. 7월 13일 이후 원복 가능성이 있으므로 의존하는 워크플로우는 여유를 두고 설계해야 한다.

---

## 한도가 늘었을 때 해볼 만한 것들

### 1. 장시간 에이전트 작업

```bash
# /goal 모드로 연속 작업 — 한도 여유가 생겼으니 더 긴 목표 설정 가능
claude /goal "전체 테스트 커버리지를 60% → 80%로 높이기. 누락된 유닛 테스트를 모두 작성하고 CI를 통과시켜."
```

### 2. 멀티에이전트 병렬 작업

```bash
# git worktree로 3개 에이전트 동시 실행
git worktree add ../feat-auth feature/auth-refactor
git worktree add ../feat-perf feature/performance-pass
git worktree add ../feat-docs feature/docs-update

# 각 worktree에서 별도 Claude Code 세션 시작
# (tmux 3 pane 또는 Claude Code 데스크탑 사이드바 활용)
```

### 3. 대형 리팩토링

```
# 한 세션에 몰아서 처리하기 좋은 작업들
- 전체 코드베이스 ESLint/Prettier 일괄 적용
- 레거시 콜백 → async/await 전환
- 의존성 메이저 버전 업그레이드
- TypeScript strict 모드 활성화 + 타입 오류 일괄 수정
```

---

## 세션 설계 패턴 — 한도를 낭비 없이 쓰는 법

### 긴 세션 설계

| 우선순위 | 작업 유형 | 이유 |
|---------|----------|------|
| 높음 | 코드 생성/리팩토링 | 컨텍스트 연속성 필요 |
| 높음 | 테스트 작성 전체 패스 | 파일 간 의존성 파악 |
| 보통 | 문서 자동 생성 | 독립적 작업 가능 |
| 낮음 | 단순 질문/설명 | 짧게 끝낼 수 있음 |

### PreToolUse Hook으로 낭비 방지

한도가 늘었다고 토큰을 낭비하면 금방 소진된다. 다음 Hook을 설정해두면 불필요한 호출을 15~20% 줄일 수 있다.

```json
// claude-code settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "python3 -c \"import sys, json; d=json.load(sys.stdin); print('block') if d.get('file_path') in open('/tmp/cc-reads.txt').read().split() else (open('/tmp/cc-reads.txt','a').write(d.get('file_path','')+' '), print('ok'))\""
          }
        ]
      }
    ]
  }
}
```

> 같은 파일을 세션 내 여러 번 읽는 것을 방지한다. 서브에이전트 작업에서 특히 효과적이다.

---

## 플랜별 활용 전략

### Pro ($20/월)

```
# 평소 아꼈던 작업들 이번 주에 몰아서 처리
1. 레거시 코드베이스 전체 분석
2. CLAUDE.md 초안 자동 생성
3. 전체 API 문서 동기화
```

### Max ($100~200/월)

```
# 멀티에이전트 대형 프로젝트에 집중
1. Dynamic Workflows로 수백 개 파일 동시 마이그레이션
2. 병렬 에이전트 3~5개로 스프린트 전체 태스크 처리
3. 전체 테스트 스위트 자동 생성 + CI 통합
```

---

## 주의할 점

| 상황 | 권장 대응 |
|------|----------|
| 한도 원복(7/13 이후) | 핵심 워크플로우만 유지, 낭비성 반복 제거 |
| 기업/팀 플랜 | 관리자 콘솔에서 실제 적용 여부 확인 |
| API 사용자 | 별도 고지 확인 필요 (구독 플랜과 다를 수 있음) |
| 레이트 리밋 오류 | `/resume` 명령으로 세션 재개 시도 |

---

## 사용량 확인

```bash
# 현재 세션 토큰 확인 (claude-code UI 상단)
# 또는 API 사용자라면 Usage 대시보드에서 일별 소비량 추적
# https://console.anthropic.com/usage
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
