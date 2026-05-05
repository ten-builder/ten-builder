# AI 에이전트 기반 오픈소스 기여 워크플로우 — 이슈 탐색부터 PR 머지까지

> 처음 오픈소스에 기여하려면 어디서 시작할지 막막하다. AI 에이전트를 활용하면 이슈 탐색부터 코드 수정, PR 제출까지 전 과정을 체계적으로 진행할 수 있다.

## 개요

오픈소스 기여는 코드 실력 향상, 포트폴리오 구축, 커뮤니티 참여라는 세 가지 가치를 동시에 얻는 방법이다. 그런데 현실은 다르다. 처음 레포지토리를 열면 수천 개의 파일, 복잡한 기여 가이드, 낯선 코드베이스가 기다린다. AI 에이전트는 이 진입 장벽을 낮춰준다. 코드베이스를 빠르게 파악하고, 적절한 이슈를 찾고, 패치를 작성하는 데 실질적인 도움이 된다.

## 사전 준비

- GitHub CLI (`gh`) 설치 및 인증 완료
- Claude Code 또는 Gemini CLI 설치
- 기여하려는 오픈소스 프로젝트 선정
- Git 기본 사용법 숙지

---

## Step 1: 기여할 프로젝트 탐색

### 1-1. `good first issue` 검색

```bash
# 관심 주제의 good first issue 탐색
gh search issues --label "good first issue" \
  --state open \
  --language typescript \
  --sort "updated" \
  --limit 20 \
  --json title,url,repository

# 특정 레포에서 탐색
gh issue list --repo <owner>/<repo> \
  --label "good first issue" \
  --state open \
  --json number,title,body,comments
```

### 1-2. AI에게 이슈 분석 위임

```bash
# 이슈 내용을 AI에게 전달해서 난이도와 접근 방법 파악
gh issue view <issue_number> --repo <owner>/<repo> --json title,body,comments \
  | claude -p "이 GitHub 이슈를 분석해줘.
    1. 무엇을 수정해야 하는지
    2. 예상 난이도 (초급/중급/고급)
    3. 관련 파일이 어디 있을지
    4. 접근 방법 추천"
```

### 1-3. 좋은 첫 이슈 기준

| 기준 | 확인 방법 |
|------|-----------|
| 명확한 재현 방법 있음 | 이슈 본문에 steps-to-reproduce 포함 여부 |
| 최근 2주 이내 업데이트 | `gh issue view` 날짜 확인 |
| 담당자 없음 | `assignees: []` 확인 |
| 관련 코드 범위가 작음 | AI에게 예상 파일 수 물어보기 |
| 메인테이너 반응 있음 | 이슈 댓글 확인 |

---

## Step 2: 레포지토리 파악

### 2-1. 클론 및 빠른 구조 파악

```bash
# 레포 클론
gh repo clone <owner>/<repo>
cd <repo>

# 프로젝트 구조를 AI에게 분석 요청
find . -type f -name "*.md" | head -5 | xargs cat | \
  claude -p "이 오픈소스 프로젝트의 구조를 요약해줘.
    - 핵심 디렉토리와 역할
    - 기여 방법 (CONTRIBUTING.md 내용)
    - 빌드/테스트 방법
    - 코드 스타일 규칙"
```

### 2-2. 환경 설정

```bash
# 대부분의 프로젝트는 README에 설정 방법이 있음
cat README.md | claude -p "이 프로젝트 로컬 개발 환경 설정 명령어를 순서대로 알려줘"

# 설정 진행 중 오류 발생 시
npm install 2>&1 | claude -p "이 에러를 어떻게 해결하면 좋을까?"
```

### 2-3. 이슈 관련 코드 탐색

```bash
# 이슈에서 언급된 키워드로 관련 파일 검색
grep -r "<이슈 키워드>" --include="*.ts" -l | \
  xargs claude -p "<이슈 번호> 이슈를 수정하려면 이 파일들 중 어디를 수정해야 할까?"
```

---

## Step 3: 수정 작업

### 3-1. 작업 브랜치 생성

```bash
# 브랜치명은 간결하게 — 이슈 번호 포함 권장
git checkout -b fix/issue-<번호>-<간단한-설명>
# 예시: fix/issue-123-null-pointer-error
```

### 3-2. AI와 함께 수정

```bash
# 수정할 파일을 AI에게 전달하고 패치 요청
cat src/<target_file>.ts | claude -p "
이슈 #<번호>: <이슈 제목>

이슈 설명: <이슈 본문 요약>

이 파일에서 문제를 찾아 수정해줘.
- 기존 코드 스타일 유지
- 최소한의 변경
- 사이드 이펙트 없음"
```

### 3-3. 테스트 추가

```bash
# 기존 테스트 파일 패턴 파악
ls tests/ || ls __tests__/ || ls spec/

# AI에게 테스트 케이스 작성 요청
cat src/<modified_file>.ts | claude -p "
방금 수정한 함수에 대한 단위 테스트를 작성해줘.
- 프로젝트의 기존 테스트 스타일 따를 것
- 정상 케이스 + 엣지 케이스 포함
- 수정 전 버그를 재현하는 테스트도 포함"

# 테스트 실행
npm test || pytest || cargo test
```

---

## Step 4: PR 제출

### 4-1. 커밋 메시지 작성

```bash
git add -p  # 변경사항 꼼꼼히 확인
git commit -m "fix: <간결한 수정 설명>

Fixes #<이슈번호>

- <변경 사항 1>
- <변경 사항 2>"
```

### 4-2. PR 생성

```bash
# fork한 경우 push
git push origin fix/issue-<번호>-<설명>

# PR 생성 — 제목과 본문을 명확하게
gh pr create \
  --title "fix: <수정 내용 요약>" \
  --body "$(cat <<'EOF'
## 변경 내용

Fixes #<이슈번호>

## 수정 이유

<왜 이 버그가 발생했는지>

## 수정 방법

<어떻게 고쳤는지>

## 테스트

- [ ] 기존 테스트 통과
- [ ] 새로운 테스트 추가
- [ ] 로컬에서 수동 검증 완료
EOF
)"
```

### 4-3. AI로 PR 본문 점검

```bash
# PR 제출 전 AI로 검토
gh pr view --json title,body | claude -p "
이 PR 본문을 메인테이너 관점에서 검토해줘.
- 설명이 충분한지
- 놓친 내용이 있는지
- 개선할 부분 제안"
```

---

## Step 5: 리뷰 대응

### 5-1. 리뷰 댓글 처리

```bash
# 리뷰 댓글 가져오기
gh pr view <pr_number> --json reviews,comments | claude -p "
리뷰어 피드백을 요약하고, 각 항목을 어떻게 처리하면 좋을지 알려줘"

# 수정 후 재확인
git add .
git commit -m "review: <리뷰 반영 내용>"
git push
```

### 5-2. 메인테이너와 소통 팁

| 상황 | 대응 방법 |
|------|-----------|
| 리뷰가 2주 이상 없음 | 정중하게 핑 댓글 남기기 |
| 요청 범위가 너무 커짐 | 원래 이슈 범위로 제한 유지 |
| 방향성 불일치 | 수정 전 댓글로 먼저 논의 |
| CI 실패 | 로컬에서 재현 후 AI에게 분석 요청 |

---

## 문제 해결

| 문제 | 해결 |
|------|------|
| 로컬 빌드 실패 | `cat error.log \| claude -p "빌드 에러 원인과 해결 방법"` |
| 기존 테스트 깨짐 | AI에게 테스트 코드와 수정 코드를 함께 전달해서 원인 파악 |
| Merge conflict | `git diff HEAD...main \| claude -p "컨플릭트 해결 방법"` |
| 코드 스타일 위반 | `git diff \| claude -p "이 프로젝트 코드 스타일에 맞게 수정해줘"` |

---

## AI 활용 포인트

| 단계 | AI 활용 방법 |
|------|------------|
| 이슈 탐색 | `gh search issues` 결과를 AI에게 전달해서 적합한 이슈 선별 |
| 코드베이스 파악 | 디렉토리 구조와 README를 AI에게 요약 요청 |
| 버그 수정 | 관련 파일을 AI에게 전달하고 최소한의 패치 생성 |
| 테스트 작성 | 기존 테스트 파일 스타일을 AI에게 학습시키고 새 테스트 생성 |
| PR 작성 | AI에게 변경 요약 요청 후 PR 본문에 활용 |
| 리뷰 대응 | 리뷰 댓글 분석 및 수정 방향 제안 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
