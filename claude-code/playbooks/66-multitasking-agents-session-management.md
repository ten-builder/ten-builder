# 플레이북 66: 멀티에이전트 세션 병렬 관리

> 여러 Claude Code 에이전트를 동시에 돌릴 때 세션 충돌 없이 병렬 작업을 완료하는 실전 플레이북

## 소요 시간

20-30분 (초기 설정) / 이후 반복 사용

## 사전 준비

- Claude Code Max 플랜 (멀티에이전트 기능 필요)
- 실험 플래그 활성화: `claude config set multiagent.enabled true`
- Git 워크트리 또는 독립 작업 디렉토리
- 각 에이전트 태스크를 명확히 분리한 스펙 파일

## Step 1: 세션 아키텍처 설계

에이전트를 켜기 전에 먼저 "어떤 작업을 분리할 수 있는가"를 따져야 해요.

**병렬화에 적합한 작업:**

| 유형 | 예시 | 주의사항 |
|------|------|----------|
| 독립 파일 수정 | 프론트엔드 / 백엔드 분리 작업 | 동일 파일 동시 편집 금지 |
| 테스트 생성 | 유닛 테스트 / E2E 테스트 분리 | 공유 픽스처 충돌 주의 |
| 리서치 태스크 | 문서 조사 / 코드 분석 | 읽기 전용이면 충돌 없음 |
| 독립 모듈 개발 | 서비스 A / 서비스 B 동시 개발 | 인터페이스 정의 선행 필수 |

**병렬화를 피해야 할 작업:**

- 동일 파일을 여러 에이전트가 편집
- 패키지 lock 파일 동시 수정
- 동일 DB 스키마 마이그레이션 동시 실행

## Step 2: Git 워크트리로 에이전트별 독립 환경 구성

세션 충돌의 가장 흔한 원인은 같은 브랜치를 여러 에이전트가 공유하는 거예요. 워크트리로 해결합니다.

```bash
# 에이전트별 독립 작업 디렉토리 생성
cd ~/projects/myapp

# 에이전트 1: 기능 A 개발
git worktree add ../myapp-agent-feature-a -b feature/agent-feature-a

# 에이전트 2: 기능 B 개발
git worktree add ../myapp-agent-feature-b -b feature/agent-feature-b

# 에이전트 3: 테스트 작성 (읽기 전용 가능)
git worktree add ../myapp-agent-tests -b chore/agent-tests
```

각 에이전트는 자신의 워크트리 디렉토리에서만 작업합니다. 파일 충돌이 구조적으로 불가능해요.

## Step 3: 에이전트 팀 세션 시작

Claude Code의 멀티에이전트 모드를 사용하면 코디네이터 에이전트가 서브에이전트를 관리해요.

```bash
# 코디네이터 세션 시작 (관리 전용)
claude --session coordinator --role lead

# 별도 터미널에서 에이전트 1 시작
cd ~/projects/myapp-agent-feature-a
claude --session agent-1 --parent coordinator

# 에이전트 2 시작
cd ~/projects/myapp-agent-feature-b
claude --session agent-2 --parent coordinator
```

코디네이터에서 각 에이전트에 명령을 위임하는 방식:

```
[coordinator] agent-1: src/auth/ 디렉토리에서 JWT 리프레시 로직 구현해줘.
              테스트 파일도 함께 작성. 완료되면 알려줘.

[coordinator] agent-2: src/payments/ 디렉토리에서 환불 처리 API 구현해줘.
              agent-1과 공유 파일 없음. 완료되면 알려줘.
```

## Step 4: 세션 상태 모니터링

Agent View를 사용하면 여러 세션을 하나의 대시보드에서 볼 수 있어요.

```bash
# Agent View 실행
claude --agent-view

# 또는 터미널에서 세션 목록 확인
claude sessions list
```

| 명령어 | 용도 |
|--------|------|
| `claude sessions list` | 전체 세션 상태 확인 |
| `claude sessions log <id>` | 특정 세션 로그 확인 |
| `claude sessions kill <id>` | 문제 세션 강제 종료 |
| `claude sessions pause <id>` | 세션 일시 중단 |
| `claude sessions resume <id>` | 세션 재개 |

**모니터링 시 체크 포인트:**

- 에이전트가 예상 범위를 벗어난 파일을 편집하려는지 확인
- 에이전트 간 커뮤니케이션 루프 (서로 기다리는 상황) 감지
- 에러 없이 진행 중인지 5-10분마다 로그 체크

## Step 5: 충돌 없는 머지 전략

각 에이전트 작업이 완료되면 순서대로 머지합니다.

```bash
# 에이전트 1 결과 리뷰 + 머지
cd ~/projects/myapp
git diff main..feature/agent-feature-a --stat

# 충돌 없으면 머지
git merge feature/agent-feature-a

# 에이전트 2 결과 리뷰 (에이전트 1 머지 후)
git diff main..feature/agent-feature-b --stat

# 충돌 있으면 에이전트에게 수정 요청
cd ~/projects/myapp-agent-feature-b
claude "main 브랜치와 충돌 발생. src/shared/types.ts 파일의 충돌을 해결하고
        내 변경사항을 유지하면서 main 변경사항과 통합해줘."

# 수정 후 머지
cd ~/projects/myapp
git merge feature/agent-feature-b
```

## Step 6: 병렬 작업 완료 후 워크트리 정리

```bash
# 머지 완료된 워크트리 제거
git worktree remove ../myapp-agent-feature-a
git worktree remove ../myapp-agent-feature-b
git worktree remove ../myapp-agent-tests

# 완료된 브랜치 삭제
git branch -d feature/agent-feature-a feature/agent-feature-b chore/agent-tests

# 원격 브랜치도 정리
git push origin --delete feature/agent-feature-a feature/agent-feature-b
```

## 자주 발생하는 문제 & 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| 에이전트가 멈춤 (무응답) | 입력 대기 상태 | `sessions log`로 마지막 메시지 확인 후 응답 전송 |
| package-lock.json 충돌 | 두 에이전트가 npm install | 한 에이전트만 의존성 설치 담당으로 지정 |
| 에이전트가 타 에이전트 파일 수정 | 경계 미설정 | 에이전트 프롬프트에 "src/auth/ 디렉토리만" 명시 |
| 컨텍스트 오염 | 세션 재사용 | `--fresh` 플래그로 새 세션 시작 |
| 머지 충돌 | 공유 파일 동시 수정 | 순차 머지 + 충돌 시 에이전트에게 해결 위임 |

## 체크리스트

- [ ] 병렬화 가능한 작업 단위로 태스크 분리
- [ ] 에이전트별 Git 워크트리 생성 (공유 브랜치 없음)
- [ ] 각 에이전트 프롬프트에 담당 디렉토리/파일 범위 명시
- [ ] Agent View 또는 세션 로그로 진행 상황 주기적 확인
- [ ] 충돌 방지를 위해 머지는 순서대로 (에이전트 1 → 2 → 3)
- [ ] 완료 후 워크트리 및 임시 브랜치 정리

## 다음 단계

→ [플레이북 67 준비 중]

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
