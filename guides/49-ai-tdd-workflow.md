# 가이드 49: AI 코딩 에이전트와 TDD — Red-Green-Refactor 실전 워크플로우

> 테스트를 먼저 작성하고, AI가 구현하고, 사람이 검증하는 — AI 시대의 TDD가 왜 더 중요해졌는지와 실전 적용법

## 왜 AI 시대에 TDD가 더 중요한가

AI 코딩 에이전트는 코드를 빠르게 만들어요. 하지만 "빠르게 만든 코드"와 "올바른 코드"는 다른 문제예요.

2026년 Sonar 개발자 서베이에 따르면 AI 도구를 쓰는 팀의 83%가 내부 소프트웨어에 AI 생성 코드를 사용하고 있어요. 하지만 같은 서베이에서 AI가 생성한 코드를 "충분히 신뢰한다"고 답한 개발자는 3%에 불과했어요.

이 격차를 메우는 가장 실용적인 방법이 TDD예요. 테스트가 먼저 존재하면:

- AI가 무엇을 구현해야 하는지 명확하게 정의돼요
- 생성된 코드의 정확성을 자동으로 검증할 수 있어요
- 리팩토링할 때 안전망이 있어요
- "잘 돌아가는 것 같은데..." 같은 막연한 판단을 없앨 수 있어요

## Red-Green-Refactor + AI 에이전트 패턴

기존 TDD의 Red-Green-Refactor 사이클을 AI 에이전트와 함께 쓸 때는 역할이 명확하게 나뉘어요.

| 단계 | 사람이 하는 일 | AI가 하는 일 |
|------|---------------|-------------|
| **Red** | 실패하는 테스트 작성 | 테스트 스켈레톤 제안 (선택) |
| **Green** | 테스트 통과 확인 | 최소 구현 코드 생성 |
| **Refactor** | 코드 리뷰, 설계 판단 | 리팩토링 후보 제안 |

### 핵심 원칙: 테스트는 사람이 주도한다

AI에게 "기능 X를 만들어줘"라고 하면 테스트와 구현을 한꺼번에 만들어 버려요. 이렇게 되면 테스트가 구현에 맞춰져서, 스펙을 검증하는 게 아니라 "이미 만든 코드를 그대로 확인하는" 테스트가 돼요.

```
-- 잘못된 방식 --
"로그인 기능을 만들고 테스트도 작성해줘"
→ 구현에 종속된 테스트 (항상 통과, 의미 없음)

-- 올바른 방식 --
"이 테스트를 통과하는 로그인 기능을 구현해줘"
→ 스펙 기반 구현 (테스트가 계약 역할)
```

## 실전 워크플로우: 5단계

### Step 1: 요구사항을 테스트로 변환

기능 요구사항을 받으면 먼저 테스트 케이스 목록을 만들어요.

```
요구사항: "사용자가 이메일과 비밀번호로 회원가입할 수 있다"

테스트 케이스:
1. 유효한 이메일과 비밀번호로 회원가입 → 성공
2. 이미 존재하는 이메일 → 409 에러
3. 비밀번호 8자 미만 → 400 에러
4. 이메일 형식 오류 → 400 에러
5. 비밀번호에 특수문자 없음 → 400 에러
```

이 단계에서 AI를 활용할 수 있어요:

```
프롬프트: "회원가입 API의 엣지 케이스를 10개 이상 나열해줘.
입력: 이메일, 비밀번호. 응답: 201 성공, 4xx 에러."
```

AI가 사람이 놓칠 수 있는 엣지 케이스(Unicode 이메일, 매우 긴 입력, SQL 인젝션 패턴 등)를 잡아줘요.

### Step 2: 실패하는 테스트 작성 (Red)

테스트 케이스를 실제 테스트 코드로 작성해요.

```typescript
// signup.test.ts
describe('POST /api/signup', () => {
  it('유효한 이메일과 비밀번호로 회원가입하면 201을 반환한다', async () => {
    const res = await request(app)
      .post('/api/signup')
      .send({ email: 'test@example.com', password: 'Str0ng!Pass' });
    
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('userId');
    expect(res.body.email).toBe('test@example.com');
  });

  it('이미 존재하는 이메일이면 409를 반환한다', async () => {
    await createUser({ email: 'exists@example.com', password: 'Str0ng!Pass' });
    
    const res = await request(app)
      .post('/api/signup')
      .send({ email: 'exists@example.com', password: 'An0ther!Pass' });
    
    expect(res.status).toBe(409);
    expect(res.body.error).toMatch(/already exists/i);
  });

  it('비밀번호가 8자 미만이면 400을 반환한다', async () => {
    const res = await request(app)
      .post('/api/signup')
      .send({ email: 'test@example.com', password: 'Sh0rt!' });
    
    expect(res.status).toBe(400);
  });
});
```

테스트를 실행해서 **전부 실패하는지 확인**해요. 실패하지 않으면 테스트가 잘못된 거예요.

```bash
npm test -- signup.test.ts
# 모든 테스트 FAIL 확인
```

### Step 3: AI에게 구현 요청 (Green)

이제 AI 에이전트에게 테스트를 통과시키라고 요청해요.

```
프롬프트: "signup.test.ts의 모든 테스트를 통과하는
POST /api/signup 핸들러를 구현해줘.
테스트 파일을 수정하지 마. 구현 코드만 작성해."
```

중요한 가드레일:

- **"테스트 파일을 수정하지 마"** — AI가 테스트를 쉽게 통과하려고 테스트 자체를 바꾸는 걸 방지
- **최소 구현만 요청** — 불필요한 기능이 섞이는 걸 방지

```bash
npm test -- signup.test.ts
# 모든 테스트 PASS 확인
```

### Step 4: 리팩토링 (Refactor)

테스트가 통과하면 코드 품질을 개선해요. 이 단계에서도 AI가 유용해요.

```
프롬프트: "signup.ts의 구현을 리뷰하고 리팩토링 제안을 해줘.
조건:
1. 기존 테스트가 모두 통과해야 해
2. 에러 핸들링이 일관적인지 확인
3. 비밀번호 검증 로직을 별도 함수로 분리
4. 변경 후 npm test 실행해서 통과 확인"
```

리팩토링 후에도 테스트가 통과하는지 반드시 확인해요. 테스트가 깨지면 리팩토링이 잘못된 거예요.

### Step 5: 다음 기능으로 이동

한 기능의 TDD 사이클이 완료되면 다음 기능으로 넘어가요. 이전 테스트들은 계속 회귀 테스트 역할을 해요.

```bash
# 전체 테스트 실행으로 회귀 확인
npm test
```

## AI 에이전트별 TDD 설정 팁

### Claude Code

```bash
# Plan Mode로 테스트 전략 먼저 논의
claude "Plan Mode: 결제 모듈의 테스트 전략을 짜줘. 구현은 하지 마."

# 이후 테스트 작성 → 구현 요청
claude "payment.test.ts의 모든 테스트를 통과시켜줘. 테스트 파일은 수정하지 마."
```

CLAUDE.md에 TDD 규칙을 추가하면 에이전트가 자동으로 따라요:

```markdown
## TDD 규칙
- 새 기능 구현 시 반드시 테스트 먼저 확인
- 테스트 파일은 사람이 작성한 것만 사용
- 구현 완료 후 전체 테스트 실행 필수
- 테스트 없이 "완료"라고 말하지 않기
```

### Cursor

Cursor의 Composer에서 TDD를 적용하려면:

1. 테스트 파일을 먼저 열어두고 컨텍스트에 포함
2. "이 테스트를 통과시키는 구현을 만들어줘"라고 요청
3. Inline Diff로 변경 사항을 리뷰

### GitHub Copilot

Copilot의 자동완성은 TDD와 잘 맞아요:

1. 테스트 파일에서 `it('...'` 까지 입력하면 테스트 본문 제안
2. 구현 파일로 이동하면 테스트에 맞는 코드 제안
3. Copilot Chat에서 "Make all tests pass" 명령 사용

## 흔한 실수와 해결

| 실수 | 왜 문제인가 | 해결 |
|------|-----------|------|
| AI에게 테스트+구현 동시 요청 | 테스트가 구현에 종속됨 | 테스트 먼저, 구현은 별도 요청 |
| 테스트 실패를 확인 안 함 | Red 단계 생략 → 테스트 신뢰도 하락 | 반드시 `npm test`로 실패 확인 |
| AI가 테스트를 수정함 | 스펙이 바뀌어버림 | "테스트 파일 수정 금지" 명시 |
| 구현 세부사항 테스트 | 리팩토링할 때마다 테스트 깨짐 | 행위(behavior) 기반으로 테스트 작성 |
| 100% 커버리지 집착 | 의미 없는 테스트 증가 | 핵심 로직과 엣지케이스에 집중 |
| 리팩토링 건너뛰기 | 기술 부채 누적 | Green 후 반드시 Refactor 단계 실행 |

## CI에 TDD 가드레일 넣기

AI가 만든 코드가 테스트 없이 머지되는 걸 방지하는 GitHub Actions 예시:

```yaml
# .github/workflows/tdd-guard.yml
name: TDD Guard
on: pull_request

jobs:
  tdd-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Check test coverage for changed files
        run: |
          # 변경된 소스 파일 목록
          CHANGED=$(git diff --name-only origin/main -- 'src/**/*.ts' \
            | grep -v '.test.ts' | grep -v '.spec.ts')
          
          for file in $CHANGED; do
            test_file="${file%.ts}.test.ts"
            if [ ! -f "$test_file" ]; then
              echo "Missing test: $test_file for $file"
              exit 1
            fi
          done
      
      - name: Run tests
        run: npm test -- --coverage --ci
      
      - name: Coverage threshold
        run: |
          # 신규/변경 파일의 커버리지 80% 이상 확인
          npx istanbul check-coverage --lines 80 --functions 80
```

## 추천하는 TDD 리듬

하루 개발 흐름에 TDD를 녹이는 패턴이에요:

```
1. 아침: 요구사항 정리 → 테스트 케이스 목록 작성 (15분)
2. 오전: Red-Green-Refactor 2~3 사이클 (2시간)
3. 점심 전: 전체 테스트 실행 + 커밋 (10분)
4. 오후: 새 기능 TDD 사이클 (2시간)
5. 퇴근 전: 전체 테스트 + PR 생성 (15분)
```

AI 에이전트와 함께하면 Green 단계(구현)가 빨라지니까, Red 단계(테스트 설계)에 더 많은 시간을 쓸 수 있어요. 좋은 테스트를 작성하는 데 시간을 투자하면 AI가 만드는 코드의 품질도 함께 올라가요.

## 정리

AI 코딩 에이전트는 코드를 빠르게 생성하지만, 그 코드가 올바른지 보장하지는 않아요. TDD는 AI가 만든 코드의 품질을 검증하는 가장 실용적인 프레임워크예요.

핵심은 간단해요:

1. **테스트를 먼저 작성한다** (사람이 스펙을 정의)
2. **AI에게 테스트를 통과시키라고 한다** (AI가 구현)
3. **리팩토링 후 테스트가 통과하는지 확인한다** (AI가 제안, 사람이 판단)

이 사이클을 반복하면 AI가 아무리 빠르게 코드를 만들어도, 품질은 사람이 정한 기준을 따라가게 돼요.

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
