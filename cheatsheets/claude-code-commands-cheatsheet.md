# Claude Code 커스텀 커맨드 치트시트

> 반복 작업을 슬래시 커맨드로 만들어 재사용하는 방법 — 한 페이지 요약

## 커스텀 커맨드란?

자주 쓰는 프롬프트를 `/명령어`로 등록해두면, 매번 같은 내용을 타이핑할 필요 없이 한 줄로 실행할 수 있어요. 프로젝트별로 `.claude/commands/` 디렉토리에 Markdown 파일을 만들면 됩니다.

## 커맨드 디렉토리 구조

| 위치 | 범위 | 공유 방식 |
|------|------|----------|
| `.claude/commands/` | 프로젝트 전체 | Git 커밋으로 팀 공유 |
| `~/.claude/commands/` | 사용자 개인 (전역) | 모든 프로젝트에서 사용 |

```
.claude/
├── commands/
│   ├── review.md          # /project:review
│   ├── test-gen.md        # /project:test-gen
│   ├── refactor.md        # /project:refactor
│   └── deploy-check.md    # /project:deploy-check
└── settings.json
```

**규칙:** 파일명이 곧 커맨드 이름이에요. `review.md` → `/project:review`로 호출합니다.

## 커맨드 파일 작성법

### 기본 구조

```markdown
# review.md
현재 Git diff를 분석해서 코드 리뷰를 해줘.

체크 항목:
1. 버그 가능성이 있는 코드
2. 성능 이슈
3. 보안 취약점
4. 네이밍 컨벤션 위반

각 항목마다 파일명:라인 형태로 위치를 알려줘.
```

### 파라미터 사용 ($ARGUMENTS)

커맨드 호출 시 뒤에 붙인 텍스트가 `$ARGUMENTS`로 치환돼요.

```markdown
# explain.md
$ARGUMENTS 파일의 코드를 분석해서 설명해줘.

다음 형식으로 정리해줘:
- 파일의 역할
- 주요 함수/클래스 목록
- 외부 의존성
- 개선할 수 있는 부분
```

```bash
# 사용법
/project:explain src/auth/middleware.ts
```

## 실전 커맨드 모음

### 코드 리뷰

```markdown
# review.md
git diff --staged의 변경사항을 리뷰해줘.

확인 사항:
1. 로직 오류나 엣지 케이스
2. 에러 처리 누락
3. 타입 안전성 (TypeScript인 경우)
4. 불필요한 복잡도

문제가 없으면 "LGTM"만 출력해줘.
```

### 테스트 생성

```markdown
# test-gen.md
$ARGUMENTS 파일에 대한 테스트 코드를 작성해줘.

규칙:
- 기존 테스트 파일이 있으면 거기에 추가
- 없으면 __tests__/ 디렉토리에 새로 생성
- 정상 케이스, 에러 케이스, 엣지 케이스 각 1개 이상
- mock은 최소한으로만 사용
```

### 커밋 메시지 생성

```markdown
# commit.md
현재 staged 변경사항을 분석해서 커밋 메시지를 작성해줘.

형식:
- Conventional Commits 스타일 (feat/fix/refactor/docs/chore)
- 제목은 50자 이내, 영어
- 본문은 변경 이유와 영향을 간결하게

git commit -m 으로 바로 쓸 수 있게 출력해줘.
```

### 문서화

```markdown
# doc.md
$ARGUMENTS 파일/디렉토리의 README를 작성해줘.

포함할 내용:
- 개요 (한 문장)
- 설치/설정 방법
- 사용 예시 (코드 블록)
- API 레퍼런스 (함수/클래스가 있는 경우)
- 주의사항
```

### 리팩토링 제안

```markdown
# refactor.md
$ARGUMENTS 파일의 리팩토링 포인트를 분석해줘.

기준:
- 중복 코드 제거
- 함수 분리 (20줄 초과 함수)
- 네이밍 개선
- 디자인 패턴 적용 가능한 곳

각 제안마다 Before/After 코드를 보여줘.
변경하지 말고 제안만 해줘.
```

### 의존성 점검

```markdown
# deps.md
프로젝트의 의존성을 점검해줘.

확인 사항:
1. 사용하지 않는 패키지 (package.json/requirements.txt 기준)
2. 메이저 버전 업데이트가 필요한 패키지
3. 보안 취약점이 알려진 패키지
4. 번들 사이즈가 큰 패키지 (대안 제안)

테이블 형태로 정리해줘.
```

## 고급 패턴

### 체이닝: 여러 작업을 순서대로

```markdown
# full-check.md
다음 순서로 $ARGUMENTS 파일을 점검해줘:

1단계 — 타입 체크:
tsc --noEmit 실행 결과 확인

2단계 — 린트:
eslint 실행 결과 확인

3단계 — 테스트:
관련 테스트 파일 실행

4단계 — 요약:
발견된 이슈를 심각도 순으로 정리
```

### 컨텍스트 주입: CLAUDE.md와 조합

```markdown
# pr-ready.md
PR을 올리기 전에 다음을 확인해줘:

1. CLAUDE.md의 코딩 컨벤션을 모두 따르고 있는지
2. 변경된 파일마다 테스트가 있는지
3. git diff에 console.log나 debugger가 남아있지 않은지
4. 커밋 메시지가 Conventional Commits 형식인지

통과하면 PR 제목과 본문 초안을 작성해줘.
```

### 조건부 동작: 프로젝트 타입 감지

```markdown
# setup.md
프로젝트 루트의 설정 파일을 확인해서 환경을 세팅해줘.

- package.json 있으면 → npm install (lock 파일에 따라 yarn/pnpm)
- requirements.txt 있으면 → pip install -r requirements.txt
- go.mod 있으면 → go mod download
- Cargo.toml 있으면 → cargo build

설치 후 기본 테스트를 실행해서 환경이 정상인지 확인해줘.
```

## 빌트인 슬래시 커맨드

| 커맨드 | 기능 |
|--------|------|
| `/init` | CLAUDE.md 생성 |
| `/compact` | 대화 컨텍스트 압축 |
| `/clear` | 대화 초기화 |
| `/cost` | 현재 세션 비용 확인 |
| `/doctor` | 설정 진단 |
| `/memory` | CLAUDE.md 관련 메모리 관리 |
| `/review` | 최근 diff 코드 리뷰 (빌트인) |
| `/pr-comments` | PR 리뷰 코멘트 반영 |

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 파일 확장자 `.md` 빼먹음 | 반드시 `.md`로 저장 — 다른 확장자는 인식 안 됨 |
| `$ARGUMENTS` 대신 `$1` 사용 | Claude Code는 `$ARGUMENTS`만 지원 |
| 커맨드 이름에 공백 사용 | 파일명에 하이픈(`-`) 사용: `test-gen.md` |
| 전역 커맨드가 안 보임 | `~/.claude/commands/`가 정확한 경로인지 확인 |
| 팀원에게 커맨드가 안 보임 | `.claude/commands/`를 Git에 커밋했는지 확인 |
| 프롬프트가 너무 길어서 비효율적 | 핵심 지시만 남기고, 부가 규칙은 CLAUDE.md에 작성 |

## 커맨드 설계 팁

1. **한 커맨드 = 한 작업**: 여러 작업을 하나에 넣으면 결과가 흐려져요
2. **출력 형식 명시**: "테이블로", "코드 블록으로" 등 원하는 포맷을 적어두세요
3. **제약 조건 추가**: "변경하지 말고 제안만" 같은 가드레일이 중요해요
4. **$ARGUMENTS 활용**: 범용 커맨드를 만들려면 파라미터를 적극 활용하세요
5. **팀 공유**: 프로젝트 `.claude/commands/`에 넣고 커밋하면 온보딩이 빨라져요

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
