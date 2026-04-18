# AI 코딩 에이전트 실수 패턴 치트시트

> AI 코딩 에이전트가 자주 실수하는 유형을 패턴별로 정리 — 즉시 감지하고 교정하는 방법

## 1. 맥락 오해 패턴

| 실수 유형 | 증상 | 교정 방법 |
|-----------|------|-----------|
| 파일 범위 초과 | 요청하지 않은 파일까지 수정 | 수정 대상 파일을 명시적으로 지정 |
| 프레임워크 혼동 | React 코드에 Vue 패턴 적용 | CLAUDE.md에 프레임워크 명시 |
| 이전 대화 망각 | 같은 실수 반복 | 핵심 결정사항을 CLAUDE.md에 기록 |
| 비즈니스 로직 무시 | 기술적으로 맞지만 요구사항에 맞지 않는 코드 | 요구사항을 코드 주석으로 삽입 |

## 2. 보안 취약점 패턴

AI가 편의를 위해 보안을 타협하는 케이스들:

```python
# 위험: AI가 자주 생성하는 패턴
def get_user(user_id):
    query = f"SELECT * FROM users WHERE id = {user_id}"  # SQL 인젝션
    
# 교정: 파라미터 바인딩 명시 요청
def get_user(user_id):
    query = "SELECT * FROM users WHERE id = %s"
    cursor.execute(query, (user_id,))
```

**즉시 확인할 보안 체크포인트:**

- [ ] 시크릿/API 키가 코드에 하드코딩되지 않았는지
- [ ] SQL 쿼리에 사용자 입력이 직접 포함되지 않았는지
- [ ] 에러 메시지에 내부 스택 트레이스가 노출되지 않았는지
- [ ] 인증/인가 로직이 누락되지 않았는지

## 3. 할루시네이션 패턴

### 3-1. 존재하지 않는 API/라이브러리 사용

```typescript
// 위험: 에이전트가 만들어낸 API
import { useAIContext } from 'react-ai-hooks';  // 실제로 존재하지 않음

// 교정: 공식 문서 URL을 프롬프트에 포함
// "React 공식 문서(https://react.dev/reference)의 useContext를 사용해줘"
```

### 3-2. 버전 불일치

| 증상 | 원인 | 해결 |
|------|------|------|
| deprecated 메서드 사용 | 훈련 데이터 날짜 이후 변경 | package.json 버전 명시 |
| 타입 에러 대량 발생 | 타입 정의 버전 불일치 | tsconfig.json 첨부 |
| 빌드 실패 | Node.js/Python 버전 차이 | `.nvmrc`, `.python-version` 파일 생성 |

## 4. 과잉 생성 패턴

AI가 요청보다 많은 코드를 만드는 경우:

```bash
# 증상 감지
git diff --stat  # 변경 파일이 요청보다 많으면 의심

# 교정 프롬프트 패턴
"딱 {파일명} 파일만 수정해줘. 다른 파일은 건드리지 마."
"최소한의 변경으로 해결해줘."
```

**과잉 생성 유발 프롬프트 vs 교정:**

| 유발 패턴 | 교정 패턴 |
|-----------|-----------|
| "이 기능을 추가해줘" | "auth.ts에만 JWT 검증 함수 추가해줘" |
| "리팩토링해줘" | "이 함수만 단일 책임 원칙으로 분리해줘" |
| "테스트 작성해줘" | "userService.ts의 getUser 메서드 단위 테스트만" |

## 5. 컨텍스트 드리프트 패턴

긴 세션에서 초반 지시사항을 잊는 현상:

```markdown
# CLAUDE.md에 추가할 세션 앵커
## 절대 규칙 (매 응답 전 확인)
- 언어: TypeScript (JavaScript 금지)
- 스타일: ESLint airbnb 규칙
- 테스트: Vitest (Jest 금지)
- DB: PostgreSQL (SQLite 금지)
```

**드리프트 감지 신호:**
- 갑자기 다른 언어/프레임워크 제안
- 이미 결정한 아키텍처를 바꾸려는 시도
- "더 좋은 방법이 있어요" 식의 재협상 시도

## 6. 불완전 구현 패턴

```typescript
// 에이전트가 자주 남기는 TODO 폭탄
function processPayment(amount: number) {
  // TODO: 실제 결제 로직 구현
  // TODO: 에러 핸들링 추가
  // TODO: 로깅 구현
  return { success: true };  // 하드코딩
}
```

**교정 프롬프트:**
```
"TODO 주석 없이 완전히 구현해줘. 
불확실한 부분은 구현하기 전에 먼저 물어봐."
```

## 즉시 실행 교정 체크리스트

작업 완료 후 **30초 안에** 확인:

- [ ] `git diff --name-only` — 예상 파일만 변경됐는지
- [ ] `grep -r "TODO\|FIXME\|HACK" --include="*.ts"` — 미완성 코드 없는지
- [ ] `grep -rn "console.log\|debugger"` — 디버그 코드 잔존 여부
- [ ] 테스트 실행: `npm test` — 기존 테스트 깨지지 않았는지
- [ ] 타입 체크: `tsc --noEmit` — 타입 에러 없는지

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
