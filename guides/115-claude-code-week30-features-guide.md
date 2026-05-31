# Claude Code Week 30 실전 가이드 — /ultrareview, 웹 재설계, 세션 요약 총정리

> Week 17 업데이트로 등장한 /ultrareview, 웹 재설계, 세션 요약 기능이 실제로 어떻게 쓰이는지, 6월 기준으로 정리했어요.

## 이번 가이드에서 다루는 것

- /ultrareview — 멀티에이전트 버그 탐지를 CI/CD에 연결하는 방법
- 세션 요약(Session Recap) — 자리를 비운 사이 에이전트가 한 일 추적하기
- claude.ai/code 웹 재설계 — 세션 사이드바와 드래그앤드롭 레이아웃 활용법

---

## /ultrareview — 일반 리뷰와 무엇이 다른가

`/review`가 로컬 단일 패스 리뷰라면, `/ultrareview`는 클라우드에서 여러 에이전트가 동시에 코드를 검사합니다. 에이전트마다 발견한 문제를 직접 재현해서 확인한 뒤 결과를 돌려보내기 때문에, 스타일 지적은 걸러지고 실제 버그만 남아요.

### 4단계 파이프라인

| 단계 | 내용 |
|------|------|
| 1. 변경 분석 | diff를 읽고 코드 경로별로 에이전트 분배 |
| 2. 병렬 탐색 | 각 에이전트가 독립 샌드박스에서 실행 경로 추적 |
| 3. 재현 검증 | 발견 항목을 실제로 재현할 수 없으면 드롭 |
| 4. 결과 집계 | CLI 또는 데스크탑에 확인된 버그 목록 반환 |

소요 시간은 변경 규모에 따라 10~20분이에요.

### 기본 사용법

```bash
# 현재 변경사항 검토
claude > /ultrareview

# 특정 태스크 기술 후 검토
claude > /ultrareview 인증 미들웨어 엣지 케이스 집중 검토
```

### /review vs /ultrareview 선택 기준

| 상황 | 추천 |
|------|------|
| 빠른 스타일/로직 점검 | /review |
| 머지 전 중요 변경 최종 확인 | /ultrareview |
| 결제·인증·데이터 처리 코드 | /ultrareview |
| 작은 수정, 문서 변경 | /review |

### CI/CD 파이프라인 연동

비대화 모드로 실행하면 PR 머지 전 게이트로 쓸 수 있어요.

```yaml
# .github/workflows/ultrareview.yml
name: ultrareview gate

on:
  pull_request:
    branches: [main]
    types: [opened, synchronize]

jobs:
  ultrareview:
    runs-on: ubuntu-latest
    # 중요 경로 변경 시에만 실행
    if: |
      contains(github.event.pull_request.changed_files, 'auth/') ||
      contains(github.event.pull_request.changed_files, 'payments/')
    steps:
      - uses: actions/checkout@v4
      - name: Run ultrareview
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          npm install -g @anthropic-ai/claude-code
          claude ultrareview --output json > ultrareview-result.json
          
      - name: Check result
        run: |
          BUGS=$(jq '.findings | length' ultrareview-result.json)
          if [ "$BUGS" -gt "0" ]; then
            echo "ultrareview: $BUGS개 확인된 버그 발견"
            jq '.findings[] | "- " + .description' ultrareview-result.json
            exit 1
          fi
```

**주의사항:**
- Pro 또는 Max 플랜 필요 (무료 실행 소진 후 추가 사용량 과금)
- Zero Data Retention 설정 시 사용 불가
- 결과는 CLI와 데스크탑 앱 동시에 전달됨

---

## 세션 요약(Session Recap) — 비운 자리 추적하기

백그라운드에서 에이전트를 돌린 뒤 터미널로 돌아오면 요약이 자동으로 표시돼요. "내가 없는 동안 무슨 일이 있었나"를 빠르게 파악하는 기능이에요.

### 요약에 포함되는 정보

- 완료된 태스크 목록
- 만든/수정한 파일 목록
- 실행한 명령어
- 발생한 에러와 처리 방법
- 다음 단계 제안

### 설정 방법

세션 요약은 기본 활성화되어 있어요. Bedrock, Vertex, Foundry 환경 또는 텔레메트리 비활성화 시에도 쓸 수 있어요.

```bash
# 설정 확인
claude > /config
# CLAUDE_CODE_ENABLE_AWAY_SUMMARY 항목에서 on/off 전환

# 환경변수로 비활성화
export CLAUDE_CODE_ENABLE_AWAY_SUMMARY=0
```

### 장시간 에이전트 작업 패턴

```bash
# 1. 에이전트 시작 후 자리 비우기
claude "전체 테스트 suite 실행, 실패 수정, PR 초안 작성"

# (몇 시간 후 돌아와서)
# 요약 자동 표시됨

# 2. 요약 다시 보기
claude > /recap
```

---

## claude.ai/code 웹 재설계

### 세션 사이드바

새 레이아웃에서는 왼쪽 사이드바에 모든 활성 세션이 표시돼요. 세션 간 이동이 탭 전환처럼 바뀌었어요.

```
┌─────────────────────────────────────┐
│  세션 목록          | 현재 세션     │
│  ─────────────      | ─────────── │
│  • backend-refactor | > /ultrareview│
│  • docs-update      |              │
│  • test-fixes       |   실행 중... │
│                     |              │
└─────────────────────────────────────┘
```

**활용 팁:** 에이전트 팀을 구성할 때 각 역할(백엔드/프론트엔드/테스트)을 별도 세션으로 실행하고 웹에서 한눈에 모니터링할 수 있어요.

### 드래그앤드롭 레이아웃

```
웹 재설계 주요 변경

변경 전: 단일 대화 화면
변경 후:
  - 세션 사이드바 (좌측)
  - 주 작업 영역 (중앙)
  - 파일/도구 패널 (우측, 선택)
  - 드래그앤드롭으로 패널 재배치 가능
```

### 모바일에서 세션 이어받기

원격 제어 기능과 조합하면 터미널 세션을 웹이나 모바일에서 이어받을 수 있어요.

```bash
# 터미널에서 세션 시작
claude --session my-project "리팩토링 시작"

# 이후 웹 또는 모바일에서 같은 세션에 접속
# claude.ai/code → 세션 목록 → my-project 선택
```

---

## 세 기능을 함께 쓰는 워크플로우

### 프리 머지 체크리스트

```bash
# 1. 기능 개발 완료
git commit -m "feat(auth): refresh token rotation"

# 2. 세션 요약으로 작업 내용 확인
claude > /recap

# 3. 일반 리뷰로 스타일/로직 점검
claude > /review

# 4. 중요 변경이면 ultrareview로 최종 확인
claude > /ultrareview 인증 로직 버그 집중 탐지

# 5. 결과 확인 후 PR 생성
gh pr create
```

### 팀 협업 시나리오

| 상황 | 도구 |
|------|------|
| 스프린트 시작 — 큰 기능 개발 | 웹 세션 사이드바로 에이전트 팀 관리 |
| 작업 중 자리 비움 | 세션 요약으로 복귀 시 빠르게 파악 |
| PR 제출 전 | /ultrareview로 머지 전 최종 버그 탐지 |
| 긴급 온콜 대응 | 모바일에서 웹 인터페이스로 세션 모니터링 |

---

## 자주 하는 실수

| 실수 | 해결 |
|------|------|
| 모든 PR에 ultrareview 실행 | 중요 경로(auth, payments)만 선택적으로 실행 |
| 세션 요약 없이 복귀 | /recap 먼저 확인 후 작업 재개 |
| 웹 세션을 로컬 세션과 혼용 | 세션 이름으로 구분 (--session 플래그) |

---

## 체크리스트

- [ ] Claude Code Pro/Max 플랜 확인 (ultrareview 요구)
- [ ] CI/CD 파이프라인에 ultrareview 조건부 추가 (중요 경로만)
- [ ] 세션 요약 설정 확인 (`/config`)
- [ ] 웹 인터페이스에서 세션 사이드바 레이아웃 설정
- [ ] 원격 제어로 터미널↔웹 세션 이어받기 테스트

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
