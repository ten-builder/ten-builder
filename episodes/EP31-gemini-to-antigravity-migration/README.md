# EP31: Gemini CLI에서 Antigravity CLI로 실시간 마이그레이션

> 6월 18일 Gemini CLI 서비스 종료 전에 Antigravity CLI로 전환하는 전체 과정을 라이브 코딩으로 보여주는 에피소드 — 설정 이전, 워크플로우 재구성, 기존 스크립트 호환성, Claude Code 조합 패턴

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- Gemini CLI → Antigravity CLI 변경 사항 핵심 정리
- `agy` 명령어 설치 및 초기 설정 실전
- 기존 스크립트·Makefile·GitHub Actions의 `gemini` 명령어를 `agy`로 일괄 교체
- Agent Skills, Hooks, Subagents 마이그레이션
- Claude Code + Antigravity CLI 조합 워크플로우

## 배경: 왜 바뀌나요?

2026년 5월 19일 Google이 공식 발표했습니다. **2026년 6월 18일부터** Google AI Pro/Ultra 구독자와 무료 사용자는 Gemini CLI 대신 Antigravity CLI를 사용해야 합니다.

| 구분 | 내용 |
|------|------|
| 종료 대상 | 개인 Google AI Pro/Ultra/무료 사용자 |
| 엔터프라이즈 | 영향 없음 (별도 계약 유지) |
| 종료일 | **2026년 6월 18일** |
| 대체 도구 | Antigravity CLI (`agy`) |

> **핵심 포인트:** 명령어가 `gemini`에서 `agy`로 바뀝니다. 자동화 스크립트를 쓰고 있다면 지금 바로 확인하세요.

## Step 1: Antigravity CLI 설치

```bash
# npm으로 설치
npm install -g @google/antigravity-cli

# 설치 확인
agy --version

# 로그인 (기존 Google 계정 재사용)
agy auth login
```

Gemini CLI가 이미 설치된 환경에서는 두 도구가 일시적으로 공존합니다. 6월 18일 이후 `gemini` 명령어는 응답을 멈춥니다.

## Step 2: 기존 설정 이전

Gemini CLI의 `GEMINI.md`는 Antigravity CLI의 `ANTIGRAVITY.md`에 대응합니다.

```bash
# 기존 GEMINI.md 복사
cp GEMINI.md ANTIGRAVITY.md

# 프로젝트 루트에 있는 경우
cp ~/.config/gemini/GEMINI.md ~/.config/antigravity/ANTIGRAVITY.md
```

설정 파일 내부의 특정 구문 변경이 필요한 경우:

```bash
# Gemini CLI 전용 지시사항이 있다면 검토 후 수정
grep -r "gemini" ANTIGRAVITY.md
```

## Step 3: 스크립트 일괄 교체

자동화 스크립트에 `gemini` 명령어가 박혀 있다면 지금 찾아서 바꿔야 합니다.

```bash
# 프로젝트 전체에서 gemini 명령어 사용처 탐색
grep -r "gemini " . --include="*.sh" --include="*.yml" --include="*.yaml" --include="Makefile" --include="*.ps1"

# 간단한 일괄 치환 (확인 후 적용)
find . -name "*.sh" -exec sed -i '' 's/gemini /agy /g' {} \;
find . -name "*.yml" -exec sed -i '' 's/gemini /agy /g' {} \;
```

GitHub Actions를 사용하고 있다면:

```yaml
# 기존
- name: Run Gemini CLI
  run: gemini -p "코드 리뷰해줘" --yolo

# 변경 후
- name: Run Antigravity CLI
  run: agy -p "코드 리뷰해줘" --yolo
```

> **주의:** CI/CD headless 모드는 아직 공식 GitHub Actions가 없습니다. `--dangerously-skip-permissions` 플래그로 대체하거나, Claude Code의 headless 모드를 활용하세요.

## Step 4: Agent Skills 및 Hooks 재설정

Antigravity CLI는 Gemini CLI의 Agent Skills, Hooks, Subagents, Extensions를 지원합니다. Extensions는 이제 **Antigravity Plugins**로 불립니다.

```bash
# 기존 Skills 확인
ls ~/.gemini/skills/

# Antigravity CLI Skills 디렉토리로 이동
mkdir -p ~/.antigravity/skills
cp -r ~/.gemini/skills/* ~/.antigravity/skills/

# Hooks 이전
cp -r ~/.gemini/hooks ~/.antigravity/hooks
```

Hooks 설정 파일의 네임스페이스 확인:

```json
// 기존 Gemini CLI hooks 설정 예시
{
  "preToolUse": "./hooks/pre-tool-check.js"
}

// Antigravity CLI에서도 동일한 형식 지원
// 별도 변환 불필요
```

## Step 5: Antigravity CLI + Claude Code 조합

Antigravity CLI는 서브에이전트와 비동기 워크플로우가 강점입니다. Claude Code는 대규모 코드베이스 편집과 파일 조작에 더 정밀합니다.

| 작업 유형 | 추천 도구 |
|----------|----------|
| 빠른 질문 / 코드 조각 생성 | Antigravity CLI (`agy`) |
| 대규모 리팩토링 / 파일 편집 | Claude Code |
| 서브에이전트 병렬 작업 | Antigravity CLI |
| Git 커밋 / PR 자동화 | Claude Code |
| Google Cloud / GCP 작업 | Antigravity CLI |

```bash
# 빠른 코드 리뷰는 agy로
agy -p "이 함수의 문제점 찾아줘" < src/utils.ts

# 실제 수정은 Claude Code로 넘기기
claude "위 피드백 반영해서 src/utils.ts 수정해줘"
```

## 자주 겪는 문제

| 문제 | 해결 |
|------|------|
| `gemini: command not found` 아닌데 작동 안 함 | 6월 18일 이후 서버 종료됨, `agy` 사용 |
| 클립보드 스크린샷 붙여넣기 안 됨 | 아직 미지원, 파일로 첨부 |
| CI/CD headless 실패 | `--dangerously-skip-permissions` 또는 Claude Code headless 모드 대체 |
| Plugin 인식 안 됨 | `~/.antigravity/plugins/` 경로 확인 |

## 마이그레이션 체크리스트

- [ ] `agy --version`으로 설치 확인
- [ ] `agy auth login`으로 계정 연결
- [ ] `GEMINI.md` → `ANTIGRAVITY.md` 이전
- [ ] 스크립트/Makefile의 `gemini` → `agy` 교체
- [ ] GitHub Actions 워크플로우 업데이트
- [ ] Skills/Hooks 디렉토리 이전
- [ ] 6월 18일 이전 테스트 완료

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
