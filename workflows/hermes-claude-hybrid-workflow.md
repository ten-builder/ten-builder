# Hermes Agent + Claude Code 하이브리드 워크플로우

> Claude Code는 책상 앞 일상 코딩에, Hermes Agent는 백그라운드 자동화와 장기 실행 태스크에 — 두 도구의 강점을 조합해 개발 생산성을 높이는 실전 워크플로우

## 개요

두 도구를 동시에 쓴다고 해서 단순히 중복 사용이 되지는 않아요. 각각이 잘하는 일이 다릅니다.

| 역할 | Claude Code | Hermes Agent |
|------|-------------|--------------|
| 주 사용 시나리오 | 대화형 코딩, 즉각 피드백 | 장기 실행, 스케줄 자동화 |
| 메모리 구조 | CLAUDE.md + 세션 컨텍스트 | SKILL.md + 영구 메모리 |
| 실행 방식 | 포어그라운드 (터미널) | 백그라운드 (데몬) |
| 병렬 처리 | 서브에이전트 | cron + 스킬 체인 |

이 두 도구를 연결하면 "인간이 직접 감독하는 코딩"과 "자율 백그라운드 자동화"를 동시에 돌릴 수 있어요.

## 사전 준비

- Claude Code 설치 및 `claude` CLI 명령어 사용 가능
- Hermes Agent Docker 컨테이너 실행 중 (`hermes` CLI 명령어 사용 가능)
- 공유 프로젝트 디렉토리 구성 (아래 참조)

## 디렉토리 구조 설정

두 에이전트가 같은 작업 공간을 공유하도록 구성합니다.

```bash
mkdir -p ~/workspace/shared/{handoff,completed,logs}
```

```
~/workspace/
├── shared/
│   ├── handoff/      # Claude Code → Hermes 작업 전달
│   ├── completed/    # Hermes → Claude Code 결과 반환
│   └── logs/         # 양쪽 에이전트 실행 로그
└── myproject/        # 실제 프로젝트 코드
```

## 패턴 1: 포어그라운드 + 백그라운드 분리

Claude Code로 새 기능을 개발하는 동안, Hermes Agent가 백그라운드에서 테스트와 문서를 처리하는 패턴입니다.

### Step 1: Hermes에 위임 태스크 정의

```yaml
# ~/workspace/shared/handoff/test-gen-task.yaml
task_id: test-gen-2026-05-15
type: parallel_background
project: ~/workspace/myproject
actions:
  - run_tests: true
  - generate_docs: true
  - check_coverage: true
trigger: on_file_change
watch_path: src/
notify: ~/workspace/shared/completed/
```

### Step 2: Claude Code 포어그라운드 개발

Claude Code가 기능을 구현하는 동안 Hermes가 자동으로 테스트와 문서를 생성합니다.

```bash
# 터미널 1: Claude Code 포어그라운드 개발
claude "src/user/auth.ts에 OAuth2 로그인 기능을 추가해줘. 기존 JWT 구조 유지."

# 터미널 2: Hermes 백그라운드 실행 (별도 터미널)
hermes run --background --task ~/workspace/shared/handoff/test-gen-task.yaml
```

### Step 3: 결과 통합

```bash
# Hermes 완료 확인
ls ~/workspace/shared/completed/

# Claude Code로 Hermes 결과를 코드에 통합
claude "completed/test-gen-2026-05-15.md를 읽고, 빠진 테스트 케이스가 있으면 추가해줘"
```

## 패턴 2: 역할 기반 모델 라우팅

Hermes Agent의 `/model` 전환 기능으로 작업 복잡도에 따라 모델을 바꾸고, Claude Code는 고성능 모델을 유지합니다.

| 작업 유형 | 담당 에이전트 | 권장 모델 |
|----------|-------------|---------|
| 아키텍처 설계, 복잡한 리팩토링 | Claude Code | Opus/Sonnet |
| 보일러플레이트 생성, 포맷팅 | Hermes Agent | Haiku (비용 절감) |
| 스케줄 자동화, 모니터링 | Hermes Agent | Haiku 4.5 |
| 코드 리뷰, 보안 분석 | Claude Code | Opus |

```bash
# Hermes에서 작업별 모델 전환
hermes /model claude-haiku-4-5   # 단순 포맷팅 태스크
hermes /model claude-sonnet-4-5  # 복잡한 스킬 실행
```

## 패턴 3: Hermes 스킬 → Claude Code 서브에이전트 연계

Hermes의 스킬 시스템으로 반복 작업을 패키징하고, Claude Code 서브에이전트가 필요할 때 호출합니다.

### Hermes 스킬 정의

```markdown
# ~/.hermes/skills/pr-checker.md
## PR 품질 체크

새 PR이 열리면 자동으로 실행:
1. 변경 파일 목록 추출
2. 테스트 커버리지 확인
3. 린트 오류 스캔
4. 결과를 shared/completed/에 저장

ALWAYS 결과 파일에 pr_number를 포함할 것
NEVER main 브랜치에 직접 커밋하지 말 것
```

### Claude Code 서브에이전트에서 Hermes 스킬 트리거

```bash
# Claude Code에서 Hermes 스킬 결과를 활용
claude "shared/completed/pr-check-result.md를 읽고,
       린트 오류 목록을 받아서 자동으로 수정해줘.
       수정 완료 후 git commit -m 'fix: lint errors' 실행"
```

## 패턴 4: 시간 기반 자동화 파이프라인

Hermes의 cron 기능으로 정기 작업을 예약하고, 결과를 Claude Code가 처리합니다.

```bash
# Hermes cron 설정 (매일 오전 9시 코드 품질 체크)
hermes cron add "0 9 * * *" run-skill code-health-check \
  --output ~/workspace/shared/completed/daily-health-$(date +%Y%m%d).md
```

```bash
# Claude Code에서 Hermes 리포트 처리 (수동 또는 훅)
claude "shared/completed/daily-health-$(date +%Y%m%d).md를 읽고,
       우선순위 높은 기술 부채 항목 3개를 골라서
       GitHub Issue로 등록해줘"
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| 두 에이전트가 같은 파일 동시 수정 | handoff/ 폴더로 작업 분리, 파일 잠금 패턴 사용 |
| Hermes 결과가 Claude Code 컨텍스트에 없음 | CLAUDE.md에 shared/ 폴더 경로 명시 |
| 모델 비용 과다 | Hermes 단순 태스크는 Haiku로, Claude Code는 Sonnet/Opus 유지 |
| 스킬 실행 충돌 | Hermes `/usage`로 토큰 소비 확인 후 간격 조정 |

## 체크리스트

- [ ] 공유 handoff/ 폴더 생성 완료
- [ ] Hermes 백그라운드 실행 확인 (`hermes status`)
- [ ] Claude Code CLAUDE.md에 공유 폴더 경로 추가
- [ ] 작업 유형별 모델 라우팅 기준 팀 합의
- [ ] Hermes cron 스케줄 설정 완료

## 다음 단계

→ [Hermes Agent 실전 가이드](../guides/95-hermes-agent-practical-guide-2026.md)
→ [Claude Code 서브에이전트 병렬 실행](../workflows/ai-claude-code-subagent-parallel-workflow.md)
→ [AI 에이전트 팀 구성 가이드](../guides/72-ai-coding-agent-team-composition-guide.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
