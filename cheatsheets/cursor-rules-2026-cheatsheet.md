# Cursor Rules 2026 치트시트 — .cursorrules 완전 정복

> Cursor 2.6+ 기준 `.cursorrules` 파일 작성 패턴, 스코프 설정, 팀 공유 전략, 자주 쓰는 규칙 블록 모음

## 파일 위치 & 구조

| 방식 | 경로 | 특징 |
|------|------|------|
| 단일 파일 | `.cursorrules` (레포 루트) | 구버전 호환, 간단한 프로젝트에 적합 |
| 디렉토리 방식 | `.cursor/rules/` (2.6+ 권장) | 스코프별 분리, 팀 협업에 유리 |
| 글로벌 규칙 | Cursor 설정 → Rules for AI | 모든 프로젝트에 공통 적용 |

```
.cursor/
  rules/
    base.mdc          # 전체 프로젝트 기본 규칙
    frontend.mdc      # src/components/** 스코프
    backend.mdc       # src/api/** 스코프
    tests.mdc         # **/*.test.* 스코프
    meta-rules.mdc    # 에이전트 동작 방식 제어
```

## 핵심 규칙 블록

### 1. 프로젝트 기본 규칙

```markdown
# 프로젝트 규칙

## 기술 스택
- 언어: TypeScript (strict mode)
- 프레임워크: Next.js 15 App Router
- 스타일링: Tailwind CSS + shadcn/ui
- 상태 관리: Zustand
- 데이터 페칭: TanStack Query v5

## 하지 말 것 (절대 금지)
- axios 설치 금지 — fetch API 사용
- moment.js 사용 금지 — date-fns 사용
- any 타입 사용 금지
- console.log 남기기 금지 (logger 모듈 사용)
- pages/ 디렉토리 생성 금지 (App Router만 사용)

## 코드 스타일
- 함수는 화살표 함수로 작성
- 컴포넌트는 named export 사용
- 파일명: kebab-case.tsx
```

### 2. 스코프 기반 규칙 (.mdc 형식)

```markdown
---
glob: src/components/**
---

# 컴포넌트 규칙

- Server Component를 기본으로 사용, 클라이언트 상태 필요 시에만 'use client' 추가
- Props 타입은 항상 interface로 정의
- 컴포넌트당 파일 1개 원칙
- shadcn/ui 컴포넌트를 우선 사용, 커스텀 구현 지양
```

```markdown
---
glob: src/api/**
---

# API 라우트 규칙

- 모든 응답은 { data, error, status } 구조 유지
- 인증 확인은 미들웨어에서 처리
- DB 쿼리는 항상 try/catch로 감싸기
- 응답 타입은 zod 스키마로 검증
```

### 3. Meta-Rules — 에이전트 동작 제어

```markdown
# Meta-Rules

## 작업 방식
- 변경 전 현재 코드를 반드시 먼저 읽기
- 기존 패턴과 일관성 유지 (새로운 패턴 임의 도입 금지)
- 여러 파일 변경 시 의존성 순서 준수
- 불확실하면 코드 생성 전 질문하기

## 안전 규칙
- 환경변수 파일(.env) 절대 수정 금지
- 마이그레이션 파일 자동 생성 금지 (반드시 확인 후 진행)
- 프로덕션 설정 파일 수정 시 명시적 승인 요청
- 재귀 에이전트 실행은 최대 3단계로 제한

## 코드 리뷰 기준
- 새 의존성 추가 시 이유 명시
- 성능에 영향 있는 변경은 주석으로 설명
- 타입 단언(as, !) 사용 시 이유 주석 필수
```

## 팀 공유 전략

### Git 버전 관리

```bash
# .cursorrules는 반드시 git에 포함
git add .cursorrules
git add .cursor/rules/

# .gitignore에서 제외 확인
echo "# .cursorrules는 팀 공유 파일" >> .gitignore
```

### 모노레포 중첩 규칙

```
monorepo/
  .cursorrules          # 공통 기본 규칙
  apps/
    frontend/
      .cursorrules      # 프론트엔드 추가 규칙 (루트 규칙 오버라이드)
    backend/
      .cursorrules      # 백엔드 추가 규칙
  packages/
    ui/
      .cursorrules      # UI 라이브러리 규칙
```

> 하위 폴더 `.cursorrules`는 루트 규칙을 **오버라이드**하지 않고 **추가**됨

### 규칙 업데이트 프로세스

```markdown
## 규칙 변경 워크플로우
1. 팀 채널에서 변경 제안 논의
2. PR로 .cursorrules 변경
3. 코드 리뷰 (적어도 1명 승인)
4. main 머지 후 팀 전체 자동 적용
```

## 자주 쓰는 규칙 블록 모음

### Python / FastAPI

```markdown
# Python 규칙

- Python 3.12+ 문법 사용
- 타입 힌트 필수 (함수 시그니처 전부)
- Pydantic v2 모델로 요청/응답 검증
- async/await 기본, 동기 함수는 run_in_executor 사용
- 금지: wildcard import, mutable default argument
```

### Go

```markdown
# Go 규칙

- Go 1.22+ 사용
- 에러는 항상 명시적으로 처리 (ignore 금지)
- 패키지명은 소문자 단수형
- goroutine 생성 시 항상 context 전달
- 금지: panic 직접 사용, init() 함수 남용
```

### 테스트 규칙

```markdown
---
glob: **/*.test.*,**/*.spec.*
---

# 테스트 규칙

- 테스트 설명은 "should [동작]" 형식
- 각 테스트는 독립적으로 실행 가능해야 함
- 외부 API 호출은 반드시 mock 처리
- 테스트당 하나의 assertion 원칙
- Given-When-Then 구조 권장
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 규칙이 너무 많아 무시됨 | 우선순위 높은 10개 이내로 압축 |
| 서로 충돌하는 규칙 존재 | 규칙 작성 시 예외 케이스 명시 |
| 아웃데이트된 규칙 방치 | 분기별 규칙 리뷰 세션 진행 |
| 영어/한국어 혼용 | 언어 통일 (팀 언어 기준) |
| 파일 경로 없이 모호한 지시 | 실제 파일 경로 예시 포함 |

## 효과적인 규칙 작성 원칙

1. **구체적으로** — "좋은 코드를 작성하라" 대신 "함수 길이 50줄 이하 유지"
2. **부정형 포함** — 하지 말 것을 명시하면 일관성이 크게 올라감
3. **실제 경로 사용** — `src/components/Button.tsx` 같은 실제 파일 참조
4. **이유 설명** — 왜 이 규칙인지 한 줄 주석으로 설명
5. **작게 시작** — 처음부터 완벽한 규칙보다 핵심 5개로 시작해 점진적으로 확장

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
