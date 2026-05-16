# Claude Code /autofix-pr 치트시트 — CI 자동 수정 패턴 한 페이지 정리

> CI 실패와 리뷰 코멘트를 직접 고치던 반복 루프를 끊는 법 — `/autofix-pr` 하나면 Claude가 대신 지켜보고 수정한다.

## /autofix-pr 기본 사용법

| 명령어 | 설명 |
|--------|------|
| `/autofix-pr` | 현재 브랜치의 열린 PR 자동 감지 + 클라우드 Auto-Fix 활성화 |
| `/autofix-pr --pr 123` | 특정 PR 번호 지정 |
| `/autofix-pr --off` | 해당 PR의 Auto-Fix 비활성화 |
| `/autofix-pr --status` | 현재 Auto-Fix 실행 상태 확인 |

## Auto-Fix가 처리하는 것

| 유형 | 처리 범위 |
|------|-----------|
| CI 실패 | 린트, 타입체크, 테스트 실패 자동 수정 후 push |
| 리뷰 코멘트 | 승인된 제안, 명확한 수정 요청 자동 반영 |
| 빌드 오류 | 의존성 불일치, import 오류 자동 교정 |
| 포맷 오류 | prettier, eslint 자동 적용 |

## 처리하지 않는 것

- 아키텍처 결정이 필요한 코멘트
- 기능 요구사항 변경 요청
- 보안 검토가 필요한 코드 변경
- `CODEOWNERS` 강제 리뷰 블록

## 전형적인 /autofix-pr 워크플로우

```bash
# 1. 브랜치 push + PR 생성
git push origin feature/my-feature
gh pr create --title "feat: 새 기능 추가" --body "..."

# 2. Auto-Fix 활성화 (터미널 닫아도 동작)
/autofix-pr

# 3. Claude가 클라우드에서 자동으로:
#    - CI 결과 폴링
#    - 실패 원인 분석
#    - 수정 코드 생성 + push
#    - 리뷰 코멘트 반영

# 4. 상태 확인 (나중에)
/autofix-pr --status
```

## CI 실패 유형별 Auto-Fix 성공률

| CI 실패 유형 | 자동 수정 성공률 |
|-------------|----------------|
| 린트/포맷 오류 | ~95% |
| 타입스크립트 타입 오류 | ~80% |
| 단위 테스트 실패 | ~65% |
| 통합 테스트 실패 | ~40% |
| 빌드 의존성 문제 | ~70% |

## CLAUDE.md 설정 — Auto-Fix 동작 제어

```markdown
## Auto-Fix 정책

### 자동 수정 허용
- 린트 오류 (eslint, prettier)
- 타입 오류 (tsc --strict)
- import 정렬

### 자동 수정 금지 (사람 검토 필요)
- auth/ 디렉토리 변경
- DB 스키마 파일 수정
- 환경변수 관련 코드
```

## 리뷰 코멘트 자동 반영 조건

```
✅ 자동 반영 가능:
- "이 변수명을 X로 바꿔주세요"
- "이 함수를 분리해주세요"
- "에러 처리를 추가해주세요"

❌ 자동 반영 불가 (태그 필요):
- "이 아키텍처는 재고해봐야 할 것 같습니다"
- "보안 검토 후 머지"
- "요구사항 명세 확인 필요"
```

## GitHub Actions 연동 설정

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [feature/**, fix/**]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        run: npm run lint
        # Auto-Fix가 이 실패를 감지하고 수정

  type-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npx tsc --noEmit
        # 타입 오류도 자동 수정 대상
```

## 흔한 실수와 대응

| 실수 | 원인 | 해결 |
|------|------|------|
| Auto-Fix 무한 루프 | 테스트 자체에 버그 | `/autofix-pr --off` 후 수동 수정 |
| 의도치 않은 리뷰 반영 | 모호한 코멘트 | CLAUDE.md에 금지 패턴 정의 |
| push 권한 없음 | 브랜치 보호 규칙 | PR 권한 설정 확인 |
| CI 타임아웃 | 실행 시간 초과 | 캐시 설정 추가 |

## Cursor Bugbot Autofix vs Claude Code /autofix-pr

| 항목 | Claude Code | Cursor Bugbot |
|------|-------------|---------------|
| PR 이슈 해결율 | ~72% | ~78% |
| 직접 머지 비율 | ~30% | ~35% |
| 리뷰 코멘트 처리 | 지원 | 지원 |
| 설정 방식 | CLI 명령어 | IDE 설정 패널 |
| 터미널 종료 후 동작 | 지원 (클라우드) | 지원 (클라우드) |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
