# Codex Cloud Agent 치트시트 — 비동기 에이전트 완전 정복

> 터미널 밖으로 나온 Codex — ChatGPT·Slack·GitHub에서 태스크를 던지면 클라우드가 PR을 만들어주는 비동기 에이전트 워크플로우를 한 페이지로 정리.

## Codex CLI vs Codex Cloud 비교

| 항목 | Codex CLI | Codex Cloud |
|------|-----------|-------------|
| 실행 위치 | 내 터미널 (로컬) | OpenAI 클라우드 샌드박스 |
| 상호작용 방식 | 실시간 REPL | 비동기 태스크 디스패치 |
| 진입 방법 | `codex` 명령어 | ChatGPT, Slack, `codex cloud` |
| 결과물 | 로컬 변경사항 | PR, 커밋, 파일 diff |
| 병렬 실행 | 세션당 1개 | 여러 태스크 동시 가능 |
| 적합한 작업 | 빠른 반복, 탐색 | 긴 작업, 백그라운드 처리 |

## 클라우드 태스크 디스패치 방법

### ChatGPT에서

```
[ChatGPT → Codex 탭]

저장소를 연결한 뒤 태스크를 입력:
"users 테이블의 N+1 쿼리를 해결하고 PR 만들어줘"
```

### Codex CLI 클라우드 모드

```bash
# 클라우드 모드로 태스크 전송
codex cloud "결제 모듈 단위 테스트 커버리지 80%로 올려줘"

# 특정 저장소 지정
codex cloud --repo org/repo "인증 미들웨어 리팩토링해줘"

# 실행 중인 태스크 목록 확인
codex cloud list

# 태스크 결과 확인
codex cloud status <task-id>
```

### Slack 통합

```
/codex "마이그레이션 스크립트에서 발생하는 TypeError 수정해줘"
```

## 클라우드 에이전트 실행 흐름

```
1. 태스크 입력 (ChatGPT / CLI / Slack)
      ↓
2. 격리된 샌드박스 컨테이너 생성
   - 연결된 저장소 코드 사전 로드
   - GPT-5.4-Codex 모델 (1M 컨텍스트 윈도우)
      ↓
3. 코드 읽기 → 계획 수립 → 실행
   - 파일 수정, 테스트 실행, 빌드 검증
      ↓
4. PR 또는 diff 생성
      ↓
5. 결과 알림 (ChatGPT 채팅 또는 GitHub PR)
```

## Workflows 기능 — 멀티 단계 작업

```
[Codex Workflows 탭]

Step 1. 큰 작업을 입력
"전체 API 레이어를 REST에서 GraphQL로 마이그레이션 계획 세워줘"

Step 2. Codex가 마일스톤 계획 생성
→ Milestone 1: 스키마 정의
→ Milestone 2: 리졸버 구현
→ Milestone 3: 클라이언트 코드 수정
→ Milestone 4: 테스트 업데이트

Step 3. 단계별 실행 (다음 프롬프트)
"Milestone 1 구현해줘"

Step 4. 클라우드 diff 검토 → 승인 → PR 생성
```

## 저장소 연결 설정

```bash
# GitHub 저장소 연결 (최초 1회)
codex setup --repo github.com/org/repo

# 연결된 저장소 목록
codex repos list

# 저장소별 환경 변수 설정 (secrets)
codex repos secrets set --repo org/repo DATABASE_URL=...
```

## 병렬 태스크 실행 패턴

```bash
# 독립된 태스크를 동시에 처리
codex cloud "로그인 API 유닛 테스트 작성"     # Task A
codex cloud "대시보드 컴포넌트 접근성 개선"   # Task B
codex cloud "의존성 취약점 스캔 및 업데이트"  # Task C

# 1시간 후 결과 확인
codex cloud list
```

## 태스크 품질을 높이는 프롬프트 패턴

| 상황 | 좋은 예 | 나쁜 예 |
|------|---------|---------|
| 버그 수정 | "src/auth.ts 144번째 줄 TypeError 수정, 타입 가드 추가" | "버그 고쳐줘" |
| 리팩토링 | "UserService를 Strategy 패턴으로 리팩토링, 기존 테스트 통과 유지" | "리팩토링해줘" |
| 테스트 작성 | "PaymentController의 엣지 케이스 포함 Jest 테스트, 커버리지 85%" | "테스트 만들어줘" |
| 성능 개선 | "products 엔드포인트 응답 200ms 이내로 최적화, N+1 쿼리 제거" | "빠르게 만들어줘" |

## 샌드박스 설정 (codex.json)

```json
{
  "model": "gpt-5.4-codex",
  "setup_commands": [
    "npm install",
    "npm run db:migrate"
  ],
  "env": {
    "NODE_ENV": "test",
    "DATABASE_URL": "$DATABASE_URL"
  },
  "timeout_minutes": 30
}
```

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| 태스크가 너무 광범위 | 마일스톤 단위로 쪼개서 순차 실행 |
| 코드 컨텍스트 부족 | 관련 파일 경로를 프롬프트에 명시 |
| 테스트 환경 설정 안 됨 | `codex.json`의 `setup_commands`에 환경 초기화 포함 |
| PR이 너무 큰 단위 | 태스크 1개 = 파일 5개 이내 기준 유지 |
| secrets 노출 | GitHub Actions secrets와 동일하게 `codex repos secrets`로 관리 |

## CLI vs Cloud 선택 기준

```
즉각적인 피드백이 필요한가?
├─ 예 → Codex CLI (로컬, 실시간)
└─ 아니오 → Codex Cloud (비동기)
    ├─ 긴 작업 (30분+) → Cloud Workflows
    ├─ 병렬 처리 → Cloud 멀티 태스크
    └─ CI/CD 통합 → Cloud API
```

---

**CLI 버전 참고:** [codex-cli-cheatsheet.md](./codex-cli-cheatsheet.md)

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
