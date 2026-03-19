# 25. Background Agent 병렬 개발 가이드

> AI 코딩 에이전트 한 대로는 부족하다면? 여러 에이전트를 동시에 돌려서 개발 속도를 배로 높이는 실전 전략을 다룹니다.

## 왜 병렬 개발인가

대부분의 프로젝트에서 작업은 독립적인 단위로 나눌 수 있어요. 로그인 기능과 대시보드 UI는 서로 의존하지 않고, 테스트 작성과 문서 업데이트도 마찬가지입니다. 이런 작업들을 순차적으로 하나씩 처리하면 시간 낭비예요.

Background Agent와 Git Worktree를 조합하면 **여러 작업을 동시에 격리된 환경에서** 진행할 수 있어요. 충돌 걱정 없이요.

## 사전 준비

- Git 2.20 이상 (worktree 기능)
- Claude Code, Codex, 또는 Gemini CLI 설치
- tmux 또는 터미널 멀티플렉서 (선택)

## Step 1: Git Worktree로 작업 공간 분리

Worktree는 하나의 레포에서 여러 브랜치를 동시에 체크아웃하는 기능이에요. 각 에이전트가 독립된 디렉토리에서 작업하므로 서로 파일이 겹치지 않습니다.

```bash
# 메인 레포 기준으로 worktree 생성
cd ~/projects/my-app

# 작업별 worktree 생성
git worktree add ../my-app-auth feature/auth
git worktree add ../my-app-dashboard feature/dashboard
git worktree add ../my-app-tests feature/test-coverage
```

이제 세 개의 디렉토리가 각각 독립된 브랜치를 체크아웃한 상태입니다:

| 디렉토리 | 브랜치 | 작업 |
|----------|--------|------|
| `my-app/` | main | 기준 브랜치 |
| `my-app-auth/` | feature/auth | 인증 기능 |
| `my-app-dashboard/` | feature/dashboard | 대시보드 UI |
| `my-app-tests/` | feature/test-coverage | 테스트 보강 |

## Step 2: 에이전트별 태스크 할당

각 worktree 디렉토리에서 별도의 에이전트 세션을 실행해요. 핵심은 **태스크 범위를 명확하게 제한**하는 것입니다.

```bash
# 터미널 1: 인증 에이전트
cd ../my-app-auth
claude "auth 모듈을 구현해줘. JWT 기반 로그인/회원가입 API. \
  src/auth/ 디렉토리만 수정하고, 기존 코드는 건드리지 마."

# 터미널 2: 대시보드 에이전트  
cd ../my-app-dashboard
claude "대시보드 페이지를 만들어줘. React 컴포넌트 + 차트 라이브러리. \
  src/pages/dashboard/만 수정해."

# 터미널 3: 테스트 에이전트
cd ../my-app-tests
claude "기존 API 엔드포인트에 대한 통합 테스트를 작성해줘. \
  tests/ 디렉토리만 수정하고, 소스 코드는 절대 변경하지 마."
```

### 태스크 할당 체크리스트

- [ ] 각 에이전트의 **수정 범위**를 디렉토리/파일 단위로 지정
- [ ] 에이전트 간 **겹치는 파일이 없는지** 확인
- [ ] 공유 의존성(package.json 등)은 **한 에이전트만** 수정하도록 지정
- [ ] 각 에이전트에게 **완료 조건**을 명시

## Step 3: Background Agent 활용

Claude Code의 Background Agent는 터미널을 점유하지 않고 백그라운드에서 작업을 수행해요. 긴 작업에 적합합니다.

```bash
# 백그라운드로 에이전트 실행
cd ../my-app-auth
claude --background "JWT 인증 모듈 전체를 구현하고 테스트까지 작성해줘"

# 진행 상황 확인
claude --status

# 결과 확인
claude --resume
```

### Background Agent가 적합한 작업

| 작업 유형 | 예시 | 예상 시간 |
|-----------|------|-----------|
| 대규모 리팩토링 | 파일 50개 이상 수정 | 10~30분 |
| 테스트 일괄 생성 | 엔드포인트 20개 테스트 | 15~25분 |
| 문서 자동 생성 | API 전체 문서화 | 5~15분 |
| 마이그레이션 | JS→TS 전환 | 20~40분 |

## Step 4: 서브에이전트 패턴

하나의 메인 에이전트가 여러 서브에이전트를 오케스트레이션하는 패턴이에요. 태스크 분배와 결과 통합을 자동화할 수 있습니다.

```markdown
# 메인 에이전트에게 주는 프롬프트

다음 3개 작업을 서브에이전트로 병렬 실행해줘:

1. **auth-agent**: src/auth/ 에 JWT 인증 구현
2. **dashboard-agent**: src/pages/dashboard/ 에 대시보드 UI 구현  
3. **test-agent**: tests/ 에 통합 테스트 작성

각 에이전트는 자기 디렉토리만 수정할 것.
모두 완료되면 결과를 요약해줘.
```

### 오케스트레이션 시 주의사항

```bash
# 의존성이 있는 작업은 순차 실행
# 1단계: 스키마 정의 (선행)
claude "데이터베이스 스키마를 설계해줘"

# 2단계: 스키마에 의존하는 작업들 (병렬)
claude --background "API 엔드포인트 구현"   # agent-1
claude --background "프론트엔드 타입 생성"   # agent-2
claude --background "시드 데이터 작성"       # agent-3
```

## Step 5: 결과 통합과 충돌 해결

모든 에이전트가 완료되면 결과를 main 브랜치로 통합해요.

```bash
cd ~/projects/my-app

# 각 feature 브랜치를 main에 머지
git merge feature/auth
git merge feature/dashboard
git merge feature/test-coverage

# 충돌 발생 시
git mergetool  # 또는 AI에게 충돌 해결 요청
```

### 충돌 최소화 전략

| 전략 | 설명 |
|------|------|
| 디렉토리 분리 | 에이전트별 수정 범위를 폴더 단위로 격리 |
| 인터페이스 먼저 | 공유 인터페이스/타입을 먼저 정의한 뒤 구현 분배 |
| Lock 파일 단독 | package.json, requirements.txt는 한 에이전트만 수정 |
| 짧은 주기 | 오래 분기하지 않고 자주 통합 |

## Step 6: Worktree 정리

작업이 끝나면 worktree를 정리해요.

```bash
# worktree 목록 확인
git worktree list

# 완료된 worktree 제거
git worktree remove ../my-app-auth
git worktree remove ../my-app-dashboard
git worktree remove ../my-app-tests

# 정리
git worktree prune
```

## 실전 팁

### 1. tmux로 세션 관리

```bash
# 에이전트별 tmux 패널
tmux new-session -s coding
tmux split-window -h
tmux split-window -v

# 패널 0: auth agent
# 패널 1: dashboard agent  
# 패널 2: test agent
```

### 2. 에이전트 간 컨텍스트 공유

```bash
# 공유 컨텍스트 파일 작성
cat > SHARED_CONTEXT.md << 'EOF'
## 프로젝트 컨벤션
- TypeScript strict mode
- Prettier + ESLint
- React Query로 서버 상태 관리
- Zod로 런타임 검증
EOF

# 각 에이전트 실행 시 참조
claude "SHARED_CONTEXT.md를 먼저 읽고 작업해줘. ..."
```

### 3. 병렬 개발 시 피해야 할 것

- 같은 파일을 여러 에이전트가 동시에 수정
- 공유 상태(전역 변수, 싱글톤)에 의존하는 작업을 분리
- 데이터베이스 마이그레이션을 병렬로 실행
- 에이전트에게 범위를 지정하지 않고 "알아서 해줘" 요청

## 체크리스트

- [ ] 작업을 독립적인 단위로 분해했는가
- [ ] 각 에이전트의 수정 범위가 겹치지 않는가
- [ ] 의존성이 있는 작업은 순서를 정했는가
- [ ] 공유 파일(설정, 의존성)은 한 에이전트만 담당하는가
- [ ] 통합 전 각 브랜치에서 테스트를 통과했는가

## 다음 단계

→ [코드베이스 온보딩 플레이북](../claude-code/playbooks/15-codebase-onboarding.md)
→ [AI 에이전트 감독 워크플로우](../workflows/ai-agent-supervision.md)
→ [서브에이전트 병렬 개발 예제](../examples/subagent-parallel-dev/README.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
