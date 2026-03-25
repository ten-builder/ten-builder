# Aider — 터미널 AI 코딩 에이전트 치트시트

> Git 네이티브 터미널 AI 코딩 도구의 핵심 기능, 설치, 명령어, 설정 패턴 한 페이지 요약

## 한눈에 보기

| 항목 | 내용 |
|------|------|
| 유형 | 오픈소스 터미널 AI 코딩 에이전트 |
| 언어 | Python (pip 설치) |
| 라이선스 | Apache 2.0 |
| 핵심 차별점 | Git 네이티브 — 모든 변경이 자동 커밋 |
| 지원 모델 | Claude, GPT, Gemini, DeepSeek, Ollama 등 100+ |
| GitHub | [aider-chat/aider](https://github.com/aider-chat/aider) |

## 설치 & 시작

```bash
# 설치
pip install aider-chat

# API 키 설정 (택 1)
export ANTHROPIC_API_KEY="sk-..."    # Claude
export OPENAI_API_KEY="sk-..."       # GPT
export GEMINI_API_KEY="..."          # Gemini

# 실행 (프로젝트 루트에서)
cd my-project
aider                               # 기본 모델로 시작
aider --model claude-3-5-sonnet     # 모델 지정
aider --model ollama/llama3         # 로컬 모델
```

## 핵심 명령어

### 파일 관리

| 명령어 | 용도 |
|--------|------|
| `/add <파일>` | 편집 대상으로 파일 추가 |
| `/drop <파일>` | 채팅에서 파일 제거 |
| `/read <파일>` | 읽기 전용으로 참조 (편집 안 함) |
| `/ls` | 현재 추가된 파일 목록 |

### 모드 전환

| 명령어 | 용도 |
|--------|------|
| `/architect` | 설계 모드 (2모델 협업: 설계 + 편집) |
| `/code` | 코드 편집 모드 (기본) |
| `/ask` | 질문 전용 (코드 변경 없음) |
| `/help` | 코드베이스 관련 도움 |

### Git 연동

| 명령어 | 용도 |
|--------|------|
| `/commit` | 수동 커밋 |
| `/diff` | 변경 사항 확인 |
| `/undo` | 마지막 변경 되돌리기 |
| `/git <명령>` | Git 명령 직접 실행 |

### 기타

| 명령어 | 용도 |
|--------|------|
| `/model <모델명>` | 세션 중 모델 변경 |
| `/editor-model <모델명>` | 편집 모델 변경 |
| `/tokens` | 토큰 사용량 확인 |
| `/clear` | 채팅 히스토리 초기화 |
| `/web <URL>` | 웹 페이지 내용 참조 |
| `/run <명령>` | 셸 명령 실행 후 결과 공유 |
| `/test <명령>` | 테스트 실행 → 실패 시 자동 수정 |

## 모드별 사용 전략

### Code 모드 (기본)

단일 모델이 코드를 직접 편집해요. 빠른 수정이나 단순 작업에 적합합니다.

```bash
aider --model claude-3-5-sonnet
> /add src/api.py tests/test_api.py
> 이 API에 페이지네이션 파라미터를 추가해줘
```

### Architect 모드

설계 모델이 변경 계획을 세우고, 편집 모델이 실제 코드를 수정해요. 복잡한 작업에 유용합니다.

```bash
aider --architect --model claude-3-5-sonnet --editor-model claude-3-5-haiku
> /add src/
> 인증 시스템을 JWT에서 OAuth2로 전환하는 계획을 세우고 실행해줘
```

### Ask 모드

코드를 변경하지 않고 질문만 할 수 있어요. 코드 이해나 리뷰에 좋습니다.

```bash
> /ask 이 함수의 시간 복잡도가 어떻게 되나요?
> /ask 이 코드에서 보안 취약점이 있나요?
```

## 설정 파일 (.aider.conf.yml)

프로젝트 루트에 두면 자동 적용됩니다.

```yaml
# .aider.conf.yml
model: claude-3-5-sonnet
editor-model: claude-3-5-haiku
auto-commits: true
auto-lint: true
lint-cmd: "ruff check --fix"
test-cmd: "pytest -x -q"
dark-mode: true
```

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `model` | gpt-4o | 메인 모델 |
| `editor-model` | - | Architect 모드 편집 모델 |
| `auto-commits` | `true` | 변경마다 자동 Git 커밋 |
| `auto-lint` | `false` | 변경 후 린터 자동 실행 |
| `lint-cmd` | - | 린트 명령어 |
| `test-cmd` | - | 테스트 명령어 |
| `dark-mode` | `false` | 다크 모드 출력 |
| `read` | - | 항상 읽기 전용으로 포함할 파일 |
| `map-tokens` | `1024` | 레포 맵에 사용할 토큰 수 |

## 실전 패턴

### 패턴 1: 테스트 주도 개발

```bash
> /add src/utils.py tests/test_utils.py
> /test pytest tests/test_utils.py -x
> 이 테스트가 통과하도록 utils.py를 수정해줘
```

`/test`로 테스트를 실행하면, 실패 시 Aider가 자동으로 수정을 시도합니다.

### 패턴 2: 레포 탐색 후 작업

```bash
> /ask 이 프로젝트의 인증 로직이 어디에 있나요?
> /add src/auth/handler.py src/auth/middleware.py
> 세션 만료 시간을 환경변수로 설정 가능하게 바꿔줘
```

### 패턴 3: 린트 + 테스트 자동화

```yaml
# .aider.conf.yml
auto-lint: true
lint-cmd: "ruff check --fix"
test-cmd: "pytest -x -q"
```

이렇게 설정하면 매 편집 후 린트 → 테스트가 자동 실행되어 바로 피드백을 받을 수 있어요.

### 패턴 4: 비용 절약 모델 조합

```bash
# 설계는 큰 모델, 편집은 작은 모델
aider --architect --model claude-3-5-sonnet --editor-model deepseek/deepseek-chat

# 로컬 모델로 비용 0
aider --model ollama/qwen2.5-coder:32b
```

## 다른 도구와 비교

| 기능 | Aider | Claude Code | Cursor | OpenCode |
|------|-------|-------------|--------|----------|
| 환경 | 터미널 | 터미널 | IDE | 터미널 |
| Git 통합 | 자동 커밋 | 수동 | IDE 내장 | 수동 |
| 모델 자유도 | 100+ 모델 | Claude 전용 | 다양 | 다양 |
| Architect 모드 | O (2모델) | X | X | X |
| 오프라인/로컬 | Ollama 지원 | X | X | Ollama 지원 |
| 가격 | 무료 (API 비용만) | 구독 $20/월 | 구독 $20/월 | 무료 (API 비용만) |

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 파일을 `/add` 없이 편집 요청 | 편집 대상 파일은 반드시 `/add`로 먼저 추가 |
| 너무 많은 파일을 한꺼번에 추가 | 관련 파일만 추가, 나머지는 `/read`로 참조 |
| 컨텍스트 초과로 응답 품질 저하 | `/drop`으로 불필요한 파일 제거, `/clear`로 히스토리 리셋 |
| 자동 커밋이 너무 자주 생김 | `--no-auto-commits`로 끄고 `/commit`으로 수동 관리 |
| 로컬 모델 연결 실패 | Ollama 서버 실행 확인: `ollama serve` |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
