# Claude Code 데스크탑 앱 재설계 실전 가이드 — 세션 사이드바와 병렬 에이전트 관리

> 2026년 4월 재설계된 Claude Code 데스크탑 앱의 핵심 — 세션 사이드바로 여러 에이전트를 동시에 돌리는 방법을 실전 기준으로 정리했어요.

## 뭐가 바뀌었나요?

이번 재설계의 핵심은 단순합니다. 개발자의 역할이 **"코드를 직접 짜는 사람"에서 "여러 에이전트를 지휘하는 오케스트레이터"로** 바뀐다는 걸 앱이 직접 반영했어요.

기존 Claude Code는 하나의 세션에서 순차적으로 작업했는데, 이번 버전부터는 여러 세션을 동시에 열고 각각의 진행 상황을 한 화면에서 볼 수 있습니다.

재설계된 주요 구성 요소:

| 구성 요소 | 설명 |
|-----------|------|
| 세션 사이드바 | 활성/최근 세션 전체를 한곳에서 관리 |
| 통합 터미널 | 앱 내에서 테스트, 빌드 명령 직접 실행 |
| 인앱 파일 에디터 | 간단한 수정은 에디터 이탈 없이 처리 |
| 새 Diff 뷰어 | 대형 변경셋에 최적화, 속도 개선 |
| 확장 프리뷰 창 | HTML, PDF, 로컬 앱 서버 미리보기 |
| 드래그&드롭 레이아웃 | 작업 흐름에 맞게 패널 자유 배치 |
| 3단계 뷰 모드 | Verbose / Normal / Summary 선택 |

## 세션 사이드바 사용법

### 기본 조작

세션 사이드바는 왼쪽 패널에 고정되어 있어요. 각 세션에는 상태 표시가 붙어 있어서 어떤 세션이 작업 중인지 한눈에 보입니다.

```bash
# 새 세션 시작 (앱 내 터미널에서)
claude

# 특정 프로젝트 디렉토리로 세션 시작
claude --dir ~/projects/my-app
```

**사이드 챗 단축키:** `Command + ;`

실행 중인 작업을 방해하지 않고 빠르게 질문을 던질 수 있어요. 메인 스레드 컨텍스트를 오염시키지 않으면서 현재 상황을 체크하거나 간단한 질문을 할 때 씁니다.

### 세션 필터링과 그룹화

사이드바에서 세션을 정리하는 방법:

```
상태별 필터  →  실행 중 / 대기 중 / 완료 / 오류
프로젝트별   →  같은 디렉토리 세션끼리 묶기
환경별       →  SSH 세션 / 로컬 세션 분리
```

프로젝트가 여러 개라면 "프로젝트별 그룹화"를 켜두는 게 편해요.

## 병렬 에이전트 실전 설정

여러 세션을 동시에 돌릴 때 가장 큰 문제는 **파일 충돌**입니다. 에이전트 A가 `api.ts`를 수정하는 동안 에이전트 B도 같은 파일을 건드리면 엉망이 돼요.

이걸 해결하는 표준 패턴이 **Git Worktree + 세션 격리**입니다.

### Git Worktree로 에이전트 격리하기

```bash
# 메인 레포 디렉토리 기준
cd ~/projects/my-app

# 에이전트 A용 워크트리 (feature 작업)
git worktree add ../my-app-feature feature/user-auth

# 에이전트 B용 워크트리 (버그 수정)
git worktree add ../my-app-bugfix fix/payment-bug

# 현재 워크트리 목록 확인
git worktree list
```

각 워크트리 디렉토리에서 별도 Claude Code 세션을 열면, 두 에이전트가 완전히 독립된 환경에서 작업합니다.

### 3레이어 격리 스택

| 레이어 | 도구 | 목적 |
|--------|------|------|
| 코드 격리 | Git Worktree | 브랜치별 독립 작업 디렉토리 |
| DB 격리 | DB 브랜치 (PlanetScale 등) | 스키마 변경 충돌 방지 |
| 포트 격리 | 포트 번호 분리 | 로컬 서버 충돌 방지 |

```bash
# 포트 격리 예시 — 에이전트별 개발 서버 포트 분리
# 에이전트 A: 3001번
PORT=3001 npm run dev

# 에이전트 B: 3002번
PORT=3002 npm run dev
```

## 뷰 모드 선택 가이드

Claude Code가 도구 호출을 실행하는 과정을 얼마나 보여줄지 선택합니다.

| 모드 | 용도 | 추천 상황 |
|------|------|-----------|
| **Summary** | 최종 결과만 표시 | 여러 세션 동시 모니터링 시 |
| **Normal** | 주요 단계만 표시 | 일반적인 작업 |
| **Verbose** | 모든 도구 호출 표시 | 디버깅, 문제 추적 |

병렬 세션을 여러 개 돌릴 때는 **Summary 모드**를 추천해요. 각 세션의 노이즈를 줄이고 전체 진행 상황을 파악하기 쉬워집니다.

## 실전 워크플로우: 풀스택 병렬 개발

실제로 이렇게 씁니다.

**시나리오:** 신규 기능 개발 (백엔드 API + 프론트엔드 UI + 테스트를 동시에)

```bash
# 1. 워크트리 3개 준비
git worktree add ../app-backend feature/new-feature-backend
git worktree add ../app-frontend feature/new-feature-frontend
git worktree add ../app-tests feature/new-feature-tests

# 2. 각 디렉토리에서 Claude Code 세션 시작
# (앱에서 각 디렉토리를 새 세션으로 열기)

# 3. 작업 완료 후 워크트리 정리
git worktree remove ../app-backend
git worktree remove ../app-frontend
git worktree remove ../app-tests
```

**세션별 역할 분배:**

```
세션 1 (백엔드)  →  "users 테이블에 avatar 필드 추가하고 REST API 엔드포인트 만들어줘"
세션 2 (프론트)  →  "프로필 이미지 업로드 UI 컴포넌트 만들어줘, API는 /api/users/:id/avatar"
세션 3 (테스트)  →  "avatar 업로드 기능 E2E 테스트 작성해줘, Playwright 사용"
```

세 작업이 동시에 진행되고, 사이드바에서 각 세션 상태를 모니터링합니다.

## SSH 세션 지원

재설계된 앱은 **macOS와 Linux 모두에서 SSH 세션**을 지원합니다. 원격 서버의 코드베이스를 로컬 앱에서 직접 다룰 수 있어요.

```bash
# SSH 원격 Claude Code 세션 예시
ssh user@server "cd /app && claude"
```

서버에서 실행되는 에이전트를 로컬 사이드바에서 같이 관리할 수 있습니다.

## 체크리스트

- [ ] 세션 사이드바에서 프로젝트별 그룹화 설정 확인
- [ ] 병렬 작업 전 Git Worktree 디렉토리 구조 준비
- [ ] 포트 번호 사전 분리 (3001, 3002, 3003...)
- [ ] Summary 모드로 전환하여 멀티 세션 모니터링
- [ ] `Command + ;` 단축키 숙지 (사이드 챗)
- [ ] 작업 완료 후 워크트리 정리 (`git worktree remove`)

## 다음 단계

→ [병렬 에이전트 데이터베이스 쿼리 최적화](../claude-code/playbooks/62-database-query-optimization.md)

→ [AI 에이전트 기반 웹 접근성 자동화 워크플로우](../workflows/ai-accessibility-automation.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
