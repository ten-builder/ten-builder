# GitHub Copilot 클라우드 에이전트 자동화 실전 가이드 2026

> Copilot 클라우드 에이전트가 스케줄과 이벤트로 움직인다 — 반복 작업을 사람 없이 처리하는 새 패러다임

## 배경: 클라우드 에이전트의 변화

GitHub Copilot 클라우드 에이전트는 2026년 6월 초 핵심 기능 하나를 추가했다. **Automations** — 스케줄이나 레포지터리 이벤트를 트리거로 에이전트를 자동 실행하는 기능이다.

기존에는 에디터나 GitHub 인터페이스에서 직접 프롬프트를 입력해야만 에이전트가 동작했다. 이제는 "매주 월요일 오전에 의존성 취약점 확인하고 PR 열어" 같은 명령을 한 번 등록해두면 사람 없이 반복 실행된다.

이 문서는 Automations 설정 방법, 실전 패턴, Claude Code와의 역할 분담을 정리한다.

## Automations란

Automations는 Copilot 클라우드 에이전트에 **트리거 + 지시사항** 조합을 사전 등록하는 기능이다.

| 트리거 유형 | 예시 |
|------------|------|
| **일정 스케줄** | 매일 오전 9시, 매주 월요일 |
| **레포 이벤트** | PR 오픈, 이슈 생성, 코드 푸시 |
| **수동 실행** | GitHub Actions workflow_dispatch 방식 |

에이전트는 지정된 트리거가 발생하면 자동으로 코드를 읽고, 변경사항을 만들고, PR을 생성한다.

## 설정 방법

### Step 1: Automations 접근

1. GitHub.com에서 레포지터리 이동
2. **Settings → Copilot → Automations** 탭 클릭
3. **New automation** 버튼 클릭

### Step 2: 트리거 설정

**스케줄 트리거:**

```yaml
trigger:
  type: schedule
  cron: "0 9 * * 1"  # 매주 월요일 오전 9시 UTC
```

**이벤트 트리거:**

```yaml
trigger:
  type: event
  events:
    - pull_request.opened
    - pull_request.synchronize
```

### Step 3: 지시사항 작성

지시사항은 에이전트에게 내리는 자연어 명령이다. 명확할수록 좋다.

```
# 의존성 보안 감사 자동화
매주 실행할 때마다:
1. npm audit 또는 pip-audit 실행
2. 중간 심각도 이상 취약점 목록 정리
3. 각 취약점에 대해 업데이트 가능한 버전 확인
4. 안전하게 업그레이드 가능한 패키지 자동 업데이트
5. 변경사항을 브랜치에 커밋 후 PR 생성
6. PR 본문에 취약점 요약과 변경 내용 명시
```

### Step 4: 권한 범위 설정

| 권한 | 설명 |
|------|------|
| `read` | 코드 읽기만 가능 |
| `write` | 코드 수정, 브랜치 생성 |
| `pull_requests: write` | PR 생성 및 코멘트 |
| `issues: write` | 이슈 코멘트, 레이블 |

최소 권한 원칙: 작업에 필요한 권한만 부여한다.

## 실전 패턴 5가지

### 패턴 1: 주간 의존성 보안 감사

```
트리거: 매주 월요일 오전 9시

지시사항:
- 프로젝트 의존성 전체 보안 감사 실행
- 중간 심각도(medium) 이상 취약점을 이슈로 정리
- 자동 수정 가능한 항목은 즉시 패치 PR 생성
- 수동 검토 필요한 항목은 레이블 attached: security-review 추가
```

**효과:** 매주 수동으로 `npm audit` 돌리는 작업 제거. 팀이 결과만 확인하면 된다.

### 패턴 2: PR 오픈 시 자동 코드 리뷰

```
트리거: pull_request.opened, pull_request.synchronize

지시사항:
- 변경된 파일 분석
- 코드 스타일 가이드(.cursorrules 또는 CLAUDE.md) 준수 여부 확인
- 잠재적 버그, 보안 문제, 성능 이슈 감지 시 인라인 코멘트 추가
- 전체 리뷰 요약을 PR 코멘트로 작성
- 중요 이슈 없으면 LGTM 코멘트 추가
```

**주의:** PR 오너와 동일한 계정으로 코멘트가 달리는 경우 알림이 자신에게는 오지 않을 수 있다. GitHub 논의 중인 개선 예정 기능.

### 패턴 3: 이슈 트리아지 자동화

```
트리거: issues.opened

지시사항:
- 새 이슈 내용 분석
- 적절한 레이블 자동 부착 (bug, enhancement, documentation, question)
- 유사 이슈 검색 후 관련 이슈 링크 코멘트 추가
- 재현 방법이 없는 버그 리포트에는 재현 절차 요청 코멘트 작성
- 우선순위 예측 (P1/P2/P3) 후 milestone 태그
```

### 패턴 4: 일일 CI 실패 요약

```
트리거: 매일 오전 8시

지시사항:
- 지난 24시간 내 실패한 GitHub Actions 워크플로우 목록 조회
- 각 실패 원인 분석 및 요약
- 같은 원인으로 반복 실패 중인 항목 강조
- 수정 가능한 항목은 fix-ci 브랜치에 패치 PR 생성
- 요약 리포트를 팀 이슈로 생성
```

### 패턴 5: 주간 기술 부채 감사

```
트리거: 매주 금요일 오후 5시

지시사항:
- TODO, FIXME, HACK 주석 전체 목록 추출
- 6개월 이상 된 주석 우선 정리
- 각 항목별 예상 수정 복잡도 (S/M/L) 평가
- 상위 5개 항목을 기술 부채 이슈로 생성
- 스프린트 계획에 반영할 수 있도록 project 보드에 추가
```

## Claude Code와의 역할 분담

Automations와 Claude Code는 경쟁 관계가 아니라 **보완 관계**다.

| 작업 유형 | Copilot Automations | Claude Code |
|----------|--------------------|--------------------|
| 반복 스케줄 작업 | ✅ 적합 | 부적합 |
| 이벤트 기반 자동화 | ✅ 적합 | 부적합 |
| 복잡한 아키텍처 결정 | 부적합 | ✅ 적합 |
| 대화형 코딩 세션 | 부적합 | ✅ 적합 |
| GitHub 네이티브 통합 | ✅ 적합 | 추가 설정 필요 |
| 터미널/로컬 작업 | 불가 | ✅ 적합 |

**추천 조합:**

```
Copilot Automations → 반복 감사, PR 리뷰 초안, 이슈 트리아지
Claude Code → 기능 구현, 리팩토링, 아키텍처 설계
```

## 주의사항과 한계

### 알려진 제약

1. **알림 이슈:** 자동화가 PR 코멘트를 작성할 때 설정한 사용자 계정으로 달리는 경우 본인 알림이 오지 않을 수 있다. 팀 계정 또는 GitHub App 전용 계정으로 설정하면 해결된다.

2. **레포 지원 범위:** 현재 공개 레포와 일부 GitHub Teams/Enterprise 플랜에서 지원. 개인 무료 플랜은 제한적.

3. **자율성 한계:** 에이전트가 사람 없이 main에 직접 푸시하지 않는다. 항상 브랜치 + PR 방식으로 작동한다.

4. **컨텍스트 한계:** 대규모 모노레포에서는 컨텍스트 윈도우 초과 가능. CLAUDE.md 또는 지시사항에서 범위를 명확히 제한하는 것이 중요.

### 보안 고려사항

```
# 최소 권한 설정 예시
permissions:
  contents: write          # 파일 변경 필요 시
  pull-requests: write     # PR 생성 필요 시
  issues: write            # 이슈 코멘트 필요 시
  # 나머지는 기본값(read) 또는 none 유지
```

- Automation 로그는 **Settings → Copilot → Automations → Logs**에서 확인
- 민감 데이터(secrets, API 키)가 있는 파일은 `.copilotignore`로 제외

## 체크리스트

- [ ] Automations 권한 범위 최소화 설정
- [ ] 첫 실행은 테스트 브랜치에서 검증
- [ ] 지시사항에 "main에 직접 push 금지" 명시
- [ ] 실패 알림 채널 연결 (Slack, Teams 등)
- [ ] 주간 Automation 로그 리뷰 습관 추가
- [ ] Claude Code와 역할 중복 방지 — 각 도구가 잘하는 것만 맡기기

## 다음 단계

→ [GitHub Copilot 팀 맞춤 설정 가이드](64-github-copilot-customization-guide.md)
→ [AI 에이전트 주간 보안 감사 워크플로우](../workflows/ai-weekly-security-audit-workflow.md)
→ [AI 에이전트 코드 리뷰 자동화 플레이북](../claude-code/playbooks/73-ai-code-review-automation-playbook.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
