# Junie CLI 실전 가이드 2026 — JetBrains 터미널 AI 에이전트 제대로 쓰기

> JetBrains가 만든 LLM-독립적 터미널 에이전트 — IDE와 연동하거나 독립 실행, 원하는 모델을 직접 연결해서 쓰는 Junie CLI 완전 가이드

## Junie CLI가 뭔가요?

Junie는 원래 JetBrains IDE(PyCharm, IntelliJ, WebStorm 등) 안에서 동작하는 AI 코딩 에이전트였습니다. 2026년 3월, JetBrains는 Junie를 터미널에서 독립적으로 실행할 수 있는 **Junie CLI**를 베타로 출시했습니다.

핵심 특징:

- **LLM-독립적(BYOK):** Anthropic, OpenAI, Google 등 원하는 모델을 직접 연결
- **IDE 연동:** 실행 중인 JetBrains IDE를 자동 감지하여 더 깊은 컨텍스트 활용
- **터미널 친화적:** tmux, SSH, 원격 서버 등 어디서든 실행 가능
- **JetBrains AI 구독 선택적:** 구독 없이도 BYOK로 사용 가능

Claude Code가 Anthropic 모델에 특화되었다면, Junie CLI는 모델을 자유롭게 선택하면서 JetBrains 생태계와 연동되는 것이 강점입니다.

## 설치

```bash
# macOS / Linux
curl -fsSL https://junie.jetbrains.com/install.sh | bash

# 또는 Homebrew
brew install jetbrains-junie

# 설치 확인
junie --version
```

Windows는 `.exe` 인스톨러로 설치합니다.

## 인증 설정

### BYOK (직접 API 키 사용)

```bash
# Anthropic Claude 연결
junie config set llm.provider anthropic
junie config set llm.api-key $ANTHROPIC_API_KEY

# OpenAI 연결
junie config set llm.provider openai
junie config set llm.api-key $OPENAI_API_KEY

# Google Gemini 연결
junie config set llm.provider google
junie config set llm.api-key $GOOGLE_API_KEY
```

### JetBrains AI 구독 사용

```bash
junie auth login
# 브라우저에서 JetBrains Account 로그인
```

구독이 있으면 별도 API 키 없이 바로 사용할 수 있습니다.

## 기본 사용법

```bash
# 인터랙티브 모드 시작
junie

# 특정 디렉토리에서 시작
junie --cwd ~/projects/my-app

# 단일 태스크 실행 (non-interactive)
junie exec "이 파일의 테스트를 작성해줘"
```

### 인터랙티브 모드 주요 명령어

| 명령어 | 설명 |
|--------|------|
| `/model` | LLM 모델 변경 (세션 중에도 가능) |
| `/context` | 현재 컨텍스트에 파일/폴더 추가 |
| `/history` | 대화 이력 확인 |
| `/quit` | 세션 종료 (로그인 유지) |
| `/reset` | 컨텍스트 초기화 후 재시작 |
| `Ctrl+C` 2회 | 강제 종료 |

## IDE 연동 — Junie CLI의 진짜 강점

Junie CLI는 실행 중인 JetBrains IDE를 자동 감지합니다. IDE가 열려 있으면 단순한 파일 읽기를 넘어 더 풍부한 컨텍스트를 활용합니다.

```bash
# PyCharm이나 IntelliJ가 열린 상태에서 Junie CLI 실행
junie

# IDE 연동 상태 확인
/status
```

IDE 연동 시 추가로 활용 가능한 정보:

- 프로젝트 구조와 모듈 의존성
- 실행 설정(Run Configurations)
- 인덱싱된 심볼과 타입 정보
- 현재 열린 파일과 커서 위치

대규모 Java/Kotlin/Python 프로젝트에서 특히 유용합니다. Claude Code가 파일을 읽어서 파악하는 동안 Junie는 IDE 인덱스를 직접 참조합니다.

## 실전 워크플로우

### 1. 기능 구현 + 테스트 생성

```bash
cd ~/projects/my-django-app
junie exec "UserProfile 모델에 avatar_url 필드를 추가하고, 마이그레이션 파일과 테스트를 작성해줘. 기존 테스트 패턴을 따를 것."
```

### 2. 코드 리뷰 보조

```bash
# 변경 사항을 컨텍스트로 넘기기
git diff HEAD~1 | junie exec "이 변경사항에서 잠재적 버그나 개선점을 분석해줘"
```

### 3. CI/CD 파이프라인에서 활용

```yaml
# .github/workflows/ai-review.yml
- name: Junie Code Analysis
  run: |
    junie exec "변경된 파일의 보안 취약점과 테스트 누락을 확인해줘" \
      --output-format json > analysis.json
```

### 4. tmux 세션에서 장시간 태스크

```bash
# tmux 세션 시작
tmux new-session -d -s junie-work

# Junie 실행 후 detach
tmux send-keys -t junie-work 'junie' Enter
# 나중에 재접속
tmux attach -t junie-work
```

## 모델 선택 전략

Junie CLI의 `/model` 명령어로 태스크에 맞는 모델을 선택할 수 있습니다.

| 상황 | 권장 모델 | 이유 |
|------|----------|------|
| 복잡한 아키텍처 설계 | claude-opus-4 / gpt-4o | 추론 깊이 필요 |
| 반복 코드 생성 | claude-haiku-4 / gpt-4o-mini | 속도 + 비용 |
| 대형 코드베이스 분석 | gemini-2.5-pro | 긴 컨텍스트 윈도우 |
| 빠른 수정/수정 | claude-sonnet-4 | 균형 |

세션 중에도 `/model`로 전환할 수 있어서 태스크마다 최적 모델을 선택할 수 있습니다.

## Claude Code vs Junie CLI — 실용적 비교

| 항목 | Claude Code | Junie CLI |
|------|------------|-----------|
| 모델 | Anthropic 전용 | 다중 LLM (BYOK) |
| IDE 통합 | VS Code 중심 | JetBrains 전 제품 |
| 터미널 | 네이티브 | 네이티브 |
| 가격 | $20~$200/월 (구독) | API 비용 직접 부담 or JB 구독 |
| SWE-bench | 72.5% (Claude Opus 4) | 모델에 따라 다름 |
| 적합한 팀 | Anthropic 모델 선호 | JetBrains 사용자, 멀티 모델 전략 |

## Junie Guidelines — 프로젝트 컨텍스트 설정

Claude Code의 CLAUDE.md처럼, Junie도 프로젝트별 지시사항 파일을 지원합니다.

```bash
# 프로젝트 루트에 junie.md 생성
cat > junie.md << 'EOF'
# 프로젝트 가이드라인

## 코드 스타일
- Python: Black 포맷터 사용
- 타입 힌트 필수
- docstring: Google 스타일

## 테스트
- pytest 사용
- 커버리지 80% 이상 유지
- fixtures는 conftest.py에

## 커밋 규칙
- Conventional Commits 형식
- 이모지 금지
EOF
```

JetBrains의 공개 저장소 `JetBrains/junie-guidelines`에서 언어별/프레임워크별 가이드라인 템플릿을 참조할 수 있습니다.

## 실수 패턴 & 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| IDE 연동 안 됨 | IDE 실행 안 됨 or 버전 불일치 | JetBrains IDE 재시작 후 재시도 |
| 모델 응답 느림 | API 키 직접 사용 시 레이트 리밋 | `/model`로 빠른 모델로 전환 |
| 컨텍스트 초과 | 파일이 너무 많음 | `/context`로 범위 제한 |
| SSH 세션 끊김 | 네트워크 불안정 | tmux + `junie` 조합으로 세션 유지 |

## 정리

Junie CLI는 JetBrains 생태계 사용자, 또는 하나의 AI 모델에 묶이고 싶지 않은 개발자에게 좋은 선택입니다. BYOK로 API 비용을 직접 제어하면서 IDE의 풍부한 컨텍스트를 활용할 수 있습니다.

당장 써보고 싶다면:

```bash
brew install jetbrains-junie
junie config set llm.api-key $ANTHROPIC_API_KEY
junie
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
