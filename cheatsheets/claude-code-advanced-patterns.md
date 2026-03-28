# Claude Code 고급 패턴 치트시트

> 멀티 파일 편집, 커스텀 커맨드, 컨텍스트 관리 등 중급자를 위한 고급 사용 패턴 — 한 페이지 요약

## 컨텍스트 윈도우 관리

Claude Code의 성능은 컨텍스트 윈도우 사용량에 직접적으로 연결돼요. 가득 차면 응답 품질이 떨어지니, 적극적으로 관리해야 해요.

| 명령어 | 용도 | 언제 사용하나 |
|--------|------|-------------|
| `/compact` | 대화 내용 압축 | 컨텍스트 85% 이상일 때 |
| `/clear` | 전체 대화 초기화 | 새로운 작업 시작할 때 |
| `/cost` | 토큰 사용량 확인 | 비용 추적 시 |
| `Shift+Tab` | Plan 모드 전환 | 분석만 필요할 때 (도구 실행 안 함) |

### 컨텍스트 최적화 팁

```bash
# 1. .claudeignore로 불필요한 파일 제외
echo "node_modules/
dist/
*.lock
coverage/" > .claudeignore

# 2. PreCompact 훅으로 중요 정보 보존
# .claude/settings.json
{
  "hooks": {
    "PreCompact": [{
      "type": "command",
      "command": "echo '현재 작업 브랜치: '$(git branch --show-current)"
    }]
  }
}
```

## 멀티 파일 편집 패턴

### 패턴 1: 명시적 파일 목록 지정

프롬프트에서 변경할 파일을 구체적으로 지정하면 정확도가 올라가요.

```
# 좋은 예시
"src/api/users.ts에서 getUserById 함수의 반환 타입을 변경하고,
 src/types/user.ts에서 User 인터페이스도 같이 수정해줘"

# 나쁜 예시
"유저 관련 타입을 수정해줘"
```

### 패턴 2: 변경 범위 제한

```
# 파일 수를 명시적으로 제한
"이 리팩터링은 src/services/ 디렉토리 안에서만 진행해줘.
 다른 디렉토리의 파일은 절대 수정하지 마"
```

### 패턴 3: 단계별 분할 편집

대규모 변경은 한 번에 요청하지 말고 단계별로 나눠요.

```
Step 1: "먼저 타입 정의만 변경해줘 (src/types/)"
Step 2: "이제 서비스 레이어를 새 타입에 맞게 수정해줘"
Step 3: "마지막으로 컴포넌트의 props를 업데이트해줘"
```

## 커스텀 슬래시 커맨드

`.claude/commands/` 디렉토리에 Markdown 파일을 만들면 커스텀 명령어가 돼요.

### 기본 구조

```bash
mkdir -p .claude/commands
```

```markdown
# .claude/commands/review.md
현재 브랜치의 변경사항을 리뷰해줘.

1. `git diff main...HEAD`로 변경 내용 확인
2. 각 파일별로 잠재적 버그, 성능 이슈, 보안 문제 점검
3. 개선 제안을 파일별로 정리해서 출력

출력 형식:
- 파일명: 이슈 설명 + 수정 제안
```

### 실전 커맨드 예시

| 커맨드 파일 | 용도 | 호출 방법 |
|------------|------|----------|
| `review.md` | 코드 리뷰 자동화 | `/project:review` |
| `test-gen.md` | 테스트 코드 생성 | `/project:test-gen` |
| `migrate.md` | DB 마이그레이션 생성 | `/project:migrate` |
| `deploy-check.md` | 배포 전 체크리스트 | `/project:deploy-check` |
| `onboard.md` | 코드베이스 온보딩 | `/project:onboard` |

### 인자 전달

```markdown
# .claude/commands/ticket.md
JIRA 티켓 $ARGUMENTS 의 요구사항을 분석하고
구현 계획을 작성해줘.
```

```bash
# 사용: /project:ticket PROJ-123
```

## 서브에이전트 활용 패턴

서브에이전트는 독립된 컨텍스트에서 작업하므로, 메인 세션의 컨텍스트를 소비하지 않아요.

### 언제 서브에이전트를 쓰나

| 상황 | 직접 처리 | 서브에이전트 |
|------|----------|------------|
| 단일 파일 수정 | ✅ | |
| 10개+ 파일 리팩터링 | | ✅ |
| 빠른 질문 답변 | ✅ | |
| 테스트 스위트 전체 생성 | | ✅ |
| 설정 파일 1개 수정 | ✅ | |
| 코드베이스 분석 리포트 | | ✅ |

### Task 프롬프트 작성법

```
# 서브에이전트에게 넘길 때 핵심 컨텍스트 포함
"src/api/ 디렉토리의 모든 엔드포인트에 대해
 통합 테스트를 작성해줘.

 참고:
 - 테스트 프레임워크: vitest
 - DB: PostgreSQL (테스트용 docker-compose.test.yml 있음)
 - 인증: Bearer 토큰 (fixtures/auth.ts에 헬퍼 있음)"
```

## CLAUDE.md 계층 구조

```
~/.claude/CLAUDE.md          ← 전역 (모든 프로젝트 공통)
project/CLAUDE.md            ← 프로젝트 루트
project/src/CLAUDE.md        ← 디렉토리별 (해당 경로 작업 시만 로드)
project/.claude/settings.json ← 도구 권한, 훅 설정
```

### CLAUDE.md 작성 팁

```markdown
# 좋은 CLAUDE.md 구조

## 빌드/테스트 명령어
- `pnpm dev` — 개발 서버
- `pnpm test` — 전체 테스트
- `pnpm test:unit src/path` — 단일 파일 테스트

## 코드 규칙
- TypeScript strict 모드
- 함수형 컴포넌트만 사용
- 에러는 Result 타입으로 처리 (throw 금지)

## 금지 사항
- any 타입 사용 금지
- console.log 커밋 금지
- 직접 DOM 조작 금지
```

| 항목 | 포함 여부 | 이유 |
|------|----------|------|
| 빌드/테스트 명령어 | ✅ 필수 | 매번 확인하는 시간 절약 |
| 코드 스타일 규칙 | ✅ 필수 | 일관성 유지 |
| 프로젝트 구조 설명 | ⚠️ 선택 | 대규모 프로젝트에서만 |
| API 키/시크릿 | ❌ 금지 | 보안 리스크 |
| 장문 문서 복붙 | ❌ 금지 | 컨텍스트 낭비 |

## 자주 쓰는 고급 패턴 모음

### Git 연동 패턴

```bash
# 커밋 메시지 자동 생성
# Claude Code에서:
"지금까지 변경사항을 git diff로 확인하고
 conventional commit 형식으로 커밋 메시지를 만들어줘"

# PR 설명 자동 생성
"main 브랜치와의 diff를 분석해서 PR 설명을 작성해줘.
 변경 요약, 테스트 방법, 스크린샷 필요 여부를 포함해줘"
```

### 디버깅 패턴

```bash
# 에러 로그 분석 요청
"아래 에러 로그를 분석해줘:
 $(cat /tmp/error.log | tail -50)

 1. 근본 원인 파악
 2. 관련 소스 파일 찾기
 3. 수정 방안 제시"
```

### 성능 분석 패턴

```bash
# 번들 사이즈 분석
"npx webpack-bundle-analyzer를 실행해서
 번들 사이즈가 큰 상위 5개 모듈을 찾고
 각각 최적화 방법을 제안해줘"
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 컨텍스트 가득 찬 채로 작업 계속 | `/compact` 또는 `/clear` 후 핵심 컨텍스트만 재전달 |
| 모든 파일을 한 번에 수정 요청 | 3~5개 파일 단위로 나눠서 요청 |
| CLAUDE.md에 너무 많은 내용 | 핵심 명령어 + 규칙만 유지, 나머지는 하위 디렉토리별 분리 |
| 서브에이전트에 컨텍스트 미전달 | 필요한 파일 경로, 규칙, 도구 정보를 명시적으로 포함 |
| MCP 서버 과다 등록 | 실제 사용하는 서버만 유지, 미사용 서버는 제거 |
| `--dangerously-skip-permissions` 남용 | 개발 환경에서만, 허용할 도구를 `.claude/settings.json`에 명시 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
