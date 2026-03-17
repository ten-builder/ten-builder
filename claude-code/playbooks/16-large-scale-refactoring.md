# 플레이북 16: 대규모 리팩토링

> AI 코딩 에이전트로 수십~수백 개 파일을 안전하게 리팩토링하는 단계별 워크플로우

## 언제 쓰나요?

- 프로젝트 전체에 걸친 네이밍 컨벤션을 통일해야 할 때
- 레거시 패턴을 새로운 패턴으로 일괄 교체해야 할 때
- 타입 시스템을 도입하거나 강화해야 할 때
- 디렉토리 구조를 재편해야 하는데 임포트 경로가 수백 개일 때
- 외부 라이브러리 메이저 버전 업그레이드가 필요할 때

## 소요 시간

30-60분 (규모에 따라 다름)

## 사전 준비

- AI 코딩 도구 설치 (Claude Code, Cursor 등)
- Git 워킹 트리가 클린한 상태
- 테스트 스위트 (유닛 테스트, 타입 체크 등)
- 리팩토링 대상 범위 정의

## Step 1: 리팩토링 범위 정의하기

대규모 리팩토링에서 가장 중요한 건 "한 번에 전부"를 시도하지 않는 것이에요. 범위를 명확히 잡아야 AI가 정확하게 작업합니다.

### 범위 분석 프롬프트

```
프로젝트에서 [대상 패턴]을 사용하는 모든 파일을 찾아줘.
파일 경로, 사용 횟수, 의존 관계를 표로 정리해줘.
```

```bash
# 예: 특정 패턴 사용처 파악
grep -rn "oldFunction" src/ --include="*.ts" | wc -l
grep -rn "oldFunction" src/ --include="*.ts" | cut -d: -f1 | sort -u
```

### 범위 분류 기준

| 규모 | 파일 수 | 전략 |
|------|---------|------|
| 소규모 | 1-10개 | 한 번에 처리 가능 |
| 중규모 | 10-50개 | 디렉토리/모듈 단위로 분할 |
| 대규모 | 50개 이상 | 레이어별 순차 처리 필수 |

> **핵심:** 50개 이상 파일을 건드려야 한다면, 반드시 레이어를 나누세요. 유틸리티 → 서비스 → 컴포넌트 → 페이지 순서로 진행하는 게 안전합니다.

## Step 2: 안전 장치 설정하기

리팩토링 시작 전에 되돌릴 수 있는 환경을 만들어야 해요.

### Git 브랜치 전략

```bash
# 리팩토링 전용 브랜치 생성
git checkout -b refactor/naming-convention

# 작업 시작점 태그 (롤백 기준점)
git tag refactor-start
```

### 검증 스크립트 준비

```bash
#!/bin/bash
# verify.sh — 리팩토링 후 매번 실행

echo "=== 타입 체크 ==="
npx tsc --noEmit

echo "=== 린트 ==="
npx eslint src/ --quiet

echo "=== 테스트 ==="
npm test -- --watchAll=false

echo "=== 빌드 ==="
npm run build
```

```bash
chmod +x verify.sh
```

> **팁:** 이 스크립트를 AI에게 알려주세요. "매 단계가 끝나면 `./verify.sh`를 실행해서 통과하는지 확인해" 라고 지시하면 됩니다.

## Step 3: 점진적 변경 실행하기

AI에게 리팩토링을 시킬 때 가장 효과적인 패턴은 "작은 단위 반복"이에요.

### 패턴 A: 찾아-바꾸기 + 검증 루프

```
1단계: src/utils/ 디렉토리의 모든 파일에서 
[oldPattern]을 [newPattern]으로 변경해줘.
변경 후 타입 에러가 없는지 확인해.

변경한 파일 목록을 알려줘.
```

각 단계가 끝나면:

```bash
# 변경 확인
git diff --stat

# 검증
./verify.sh

# 통과하면 중간 커밋
git add -A
git commit -m "refactor: rename oldPattern to newPattern in utils"
```

### 패턴 B: 타입 기반 점진적 마이그레이션

타입스크립트 프로젝트에서 특히 효과적인 방법이에요.

```
1. 새로운 타입/인터페이스를 정의해줘 (기존 것과 공존 가능하게)
2. 새 타입으로 유틸리티 함수를 먼저 마이그레이션해줘
3. 유틸리티가 통과하면 서비스 레이어를 마이그레이션해줘
4. 마지막으로 컴포넌트를 변경해줘
```

```typescript
// Step 1: 새 타입 정의 (기존과 공존)
/** @deprecated Use UserProfile instead */
interface User {
  name: string;
  email: string;
}

interface UserProfile {
  displayName: string;
  emailAddress: string;
  createdAt: Date;
}

// Step 2: 변환 헬퍼 (임시, 마이그레이션 완료 후 제거)
function toUserProfile(user: User): UserProfile {
  return {
    displayName: user.name,
    emailAddress: user.email,
    createdAt: new Date(),
  };
}
```

### 패턴 C: 디렉토리 구조 재편

임포트 경로가 많이 바뀌는 경우에 효과적이에요.

```
src/components/에 있는 컴포넌트를 기능별로 재분류해줘:
- src/features/auth/ — 인증 관련
- src/features/dashboard/ — 대시보드 관련
- src/shared/ui/ — 공통 UI

파일을 옮기고 모든 import 경로도 함께 업데이트해줘.
각 기능 디렉토리마다 index.ts barrel file을 만들어줘.
```

> **주의:** 디렉토리 이동은 한 기능 단위씩 진행하세요. "전부 한번에 옮겨줘"는 임포트 꼬임의 원인이 됩니다.

## Step 4: 검증과 중간 커밋

매 변경 단위마다 다음 3단계를 반복해요.

```bash
# 1. 변경 내역 확인
git diff --stat
git diff -- "*.ts" | head -100  # 변경 패턴 샘플 확인

# 2. 자동 검증
./verify.sh

# 3. 통과하면 커밋
git add -A
git commit -m "refactor: migrate auth components to features/auth"
```

### 검증 실패 시 대응

| 실패 유형 | 대응 방법 |
|-----------|----------|
| 타입 에러 | AI에게 에러 메시지 전달, 해당 파일만 수정 |
| 테스트 실패 | 실패한 테스트 코드와 에러를 AI에게 전달 |
| 빌드 에러 | 순환 의존성 확인, 임포트 정리 |
| 린트 경고 | `--fix` 옵션으로 자동 수정 후 재확인 |

```bash
# 검증 실패 시 되돌리기
git stash  # 또는
git checkout -- .  # 해당 단계 전체 되돌리기

# 특정 커밋까지 되돌리기 (최후의 수단)
git reset --hard refactor-start
```

## Step 5: 정리와 PR 생성

모든 리팩토링이 완료되면 커밋 히스토리를 정리하고 PR을 만들어요.

### 커밋 정리 (선택)

```bash
# 중간 커밋이 너무 많으면 squash
git rebase -i refactor-start

# PR 생성 전 main과 rebase
git fetch origin
git rebase origin/main
```

### PR 설명 작성 팁

```markdown
## 변경 사항
- [x] utils/ 레이어 마이그레이션 완료
- [x] services/ 레이어 마이그레이션 완료
- [x] components/ 레이어 마이그레이션 완료

## 검증
- 타입 체크 통과
- 전체 테스트 스위트 통과 (XX개)
- 빌드 성공

## 리뷰 포인트
- `src/features/` 디렉토리 구조 적절한지
- barrel export 패턴이 기존 컨벤션과 맞는지
```

## 자주 하는 실수와 해결

| 실수 | 왜 문제인지 | 해결 |
|------|-----------|------|
| "전부 한번에 바꿔줘" | AI가 일부 파일을 누락하거나 임포트를 놓침 | 레이어별 순차 처리 |
| 테스트 없이 진행 | 사이드 이펙트를 늦게 발견 | 매 단계 `verify.sh` 실행 |
| 중간 커밋 안 함 | 문제 발생 시 전체 롤백만 가능 | 단계마다 커밋 |
| 한 PR에 다 담기 | 리뷰어가 확인 불가능 | 기능 단위로 PR 분리 |
| 자동 생성 파일 수정 | 다음 빌드에서 덮어씌워짐 | `.lock`, `dist/` 등 제외 |

## 체크리스트

- [ ] 리팩토링 범위와 대상 파일 목록 정리
- [ ] 전용 브랜치 생성 + 시작점 태그
- [ ] verify.sh 스크립트 준비 및 초기 실행 통과
- [ ] 레이어별 순차 처리 (유틸 → 서비스 → UI)
- [ ] 매 단계 검증 + 중간 커밋
- [ ] 전체 테스트 스위트 최종 통과
- [ ] PR 생성 + 변경 사항 문서화

## 다음 단계

→ [AI 에이전트 감독 워크플로우](../../workflows/ai-agent-supervision.md)
→ [AI 보안 감사 플레이북](./11-security-audit.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
