# 플레이북 20: 로컬 LLM 코딩

> 클라우드 API 없이 내 컴퓨터에서 AI 코딩 도구를 돌리는 단계별 가이드 — 프라이빗 코드베이스, 오프라인 개발, 비용 절감

## 언제 쓰나요?

- 회사 보안 정책 때문에 코드를 외부 API로 보낼 수 없을 때
- 비행기, 카페 등 인터넷이 불안정한 환경에서 AI 코딩을 하고 싶을 때
- API 비용을 줄이면서도 AI 보조를 유지하고 싶을 때
- 민감한 데이터(의료, 금융, 군사)가 포함된 코드베이스를 다룰 때
- AI 코딩 도구를 실험해보고 싶지만 아직 구독하기엔 이를 때

## 소요 시간

20-40분

## 사전 준비

- macOS / Linux / Windows (WSL2 권장)
- 최소 16GB RAM (32GB 이상 권장)
- GPU 있으면 좋지만 없어도 됨 (Apple Silicon은 Metal 가속 지원)
- 디스크 여유 공간 10GB 이상
- VS Code 또는 JetBrains IDE

## Step 1: Ollama 설치하기

Ollama는 로컬 LLM을 가장 쉽게 실행할 수 있는 도구입니다. Docker 없이 한 줄로 설치하고, 모델 다운로드부터 서빙까지 자동으로 처리해줍니다.

```bash
# macOS (Homebrew)
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# 설치 확인
ollama --version
```

설치 후 Ollama 서버를 실행합니다:

```bash
# 서버 시작 (백그라운드로 실행됨)
ollama serve

# macOS의 경우 앱을 설치하면 자동으로 서버가 실행됩니다
```

## Step 2: 코딩용 모델 선택하기

로컬에서 쓸 수 있는 코딩 모델은 생각보다 다양합니다. 핵심은 내 하드웨어에 맞는 모델을 고르는 것이에요.

| 모델 | 파라미터 | 최소 RAM | 용도 | 추천 환경 |
|------|----------|----------|------|-----------|
| `qwen2.5-coder:7b` | 7B | 8GB | 자동완성, 간단한 코딩 | 16GB 노트북 |
| `qwen2.5-coder:32b` | 32B | 24GB | 복잡한 코딩, 리팩토링 | 32GB+ 데스크톱 |
| `codellama:13b` | 13B | 16GB | 코드 생성, 인필 | 16GB 이상 |
| `deepseek-coder-v2:16b` | 16B | 16GB | 다국어 코딩 | 16GB 이상 |
| `llama3.1:8b` | 8B | 8GB | 범용 (코딩 + 설명) | 16GB 노트북 |

```bash
# 추천 모델 다운로드 (처음 한 번만)
ollama pull qwen2.5-coder:7b      # 가벼운 모델 (4.7GB)
ollama pull qwen2.5-coder:32b     # 성능 좋은 모델 (19GB)

# 모델 목록 확인
ollama list

# 빠르게 테스트
ollama run qwen2.5-coder:7b "Python으로 피보나치 함수 작성해줘"
```

**모델 선택 팁:**
- Apple Silicon M1/M2/M3: Metal 가속 덕분에 7B 모델이 충분히 빠릅니다
- NVIDIA GPU: VRAM에 맞춰 선택 (8GB VRAM → 7B, 24GB VRAM → 32B)
- CPU만 있는 경우: 7B 모델까지만 실용적입니다

## Step 3: VS Code에 Continue 연결하기

Continue는 VS Code/JetBrains에서 로컬 LLM을 연결할 수 있는 오픈소스 확장입니다. Copilot과 비슷한 경험을 로컬에서 할 수 있어요.

```bash
# VS Code에서 Continue 확장 설치
code --install-extension Continue.continue
```

설치 후 `~/.continue/config.json`을 편집합니다:

```json
{
  "models": [
    {
      "title": "Qwen 2.5 Coder 7B",
      "provider": "ollama",
      "model": "qwen2.5-coder:7b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "Qwen 2.5 Coder 32B (Heavy)",
      "provider": "ollama",
      "model": "qwen2.5-coder:32b",
      "apiBase": "http://localhost:11434"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Qwen Autocomplete",
    "provider": "ollama",
    "model": "qwen2.5-coder:7b",
    "apiBase": "http://localhost:11434"
  },
  "allowAnonymousTelemetry": false
}
```

| 설정 | 설명 |
|------|------|
| `models` | 채팅에서 사용할 모델 목록 |
| `tabAutocompleteModel` | 탭 자동완성에 사용할 모델 (가벼운 모델 추천) |
| `allowAnonymousTelemetry` | 텔레메트리 비활성화 (프라이버시) |

## Step 4: 터미널에서 AI 코딩하기

IDE 없이 터미널에서도 로컬 LLM을 코딩 도구로 쓸 수 있습니다.

### Ollama CLI 직접 사용

```bash
# 파일 내용을 넘겨서 코드 리뷰 요청
cat src/utils.py | ollama run qwen2.5-coder:7b "이 코드를 리뷰하고 개선점을 알려줘"

# 에러 메시지 분석
echo "TypeError: Cannot read properties of undefined (reading 'map')" | \
  ollama run qwen2.5-coder:7b "이 에러의 원인과 해결 방법을 설명해줘"
```

### API로 통합하기

Ollama는 OpenAI 호환 API를 제공합니다. 기존 도구와 연결이 쉬워요:

```bash
# OpenAI 호환 API 호출
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:7b",
    "messages": [
      {"role": "user", "content": "Python으로 JWT 인증 미들웨어 만들어줘"}
    ]
  }'
```

```python
# Python에서 사용 (openai 라이브러리 호환)
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="ollama"  # 로컬이라 아무 값이나 OK
)

response = client.chat.completions.create(
    model="qwen2.5-coder:7b",
    messages=[
        {"role": "user", "content": "FastAPI로 CRUD API 스키마 만들어줘"}
    ]
)
print(response.choices[0].message.content)
```

## Step 5: 하이브리드 전략 세우기

실전에서는 로컬 LLM만으로 모든 작업을 처리하기 어렵습니다. 작업 유형에 따라 로컬과 클라우드를 나눠 쓰는 것이 현실적이에요.

| 작업 | 추천 | 이유 |
|------|------|------|
| 탭 자동완성 | 로컬 (7B) | 빈도 높고, 빠른 응답 필요 |
| 코드 설명 / 주석 | 로컬 (7B-13B) | 민감도 낮은 작업 |
| 간단한 함수 생성 | 로컬 (7B-32B) | 충분한 품질 |
| 대규모 리팩토링 | 클라우드 API | 긴 컨텍스트 필요 |
| 복잡한 아키텍처 설계 | 클라우드 API | 추론 능력 중요 |
| 보안 감사 | 로컬 (32B) | 코드 외부 유출 방지 |
| 학습 / 실험 | 로컬 (아무거나) | 비용 0원 |

```json
// Continue config.json — 하이브리드 설정 예시
{
  "models": [
    {
      "title": "Local - Quick (Qwen 7B)",
      "provider": "ollama",
      "model": "qwen2.5-coder:7b"
    },
    {
      "title": "Cloud - Complex (Claude)",
      "provider": "anthropic",
      "model": "claude-sonnet-4-20250514",
      "apiKey": "YOUR_API_KEY"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Local Autocomplete",
    "provider": "ollama",
    "model": "qwen2.5-coder:7b"
  }
}
```

## Step 6: 성능 튜닝하기

로컬 LLM의 속도를 높이는 실전 팁들입니다.

### Ollama 환경 변수

```bash
# ~/.zshrc 또는 ~/.bashrc에 추가

# GPU 레이어 수 (높을수록 GPU 사용량 증가)
export OLLAMA_NUM_GPU=999

# 동시 요청 수
export OLLAMA_NUM_PARALLEL=2

# 컨텍스트 윈도우 크기 (기본 2048)
export OLLAMA_CONTEXT_LENGTH=8192

# 모델 메모리 유지 시간 (기본 5분)
export OLLAMA_KEEP_ALIVE=30m
```

### Modelfile로 커스텀 모델 만들기

프로젝트에 맞게 시스템 프롬프트를 미리 설정할 수 있습니다:

```dockerfile
# ~/Modelfile-project
FROM qwen2.5-coder:7b

PARAMETER temperature 0.2
PARAMETER num_ctx 8192

SYSTEM """
당신은 시니어 백엔드 개발자입니다.
- Python/FastAPI 프로젝트를 주로 다룹니다
- 코드는 항상 타입 힌트를 포함합니다
- 테스트 코드도 함께 제안합니다
- 간결하고 실용적인 답변을 합니다
"""
```

```bash
# 커스텀 모델 생성
ollama create my-backend-ai -f ~/Modelfile-project

# 사용
ollama run my-backend-ai "SQLAlchemy 모델에 soft delete 패턴 추가해줘"
```

## 체크리스트

- [ ] Ollama 설치 및 서버 실행 확인
- [ ] 내 하드웨어에 맞는 코딩 모델 다운로드
- [ ] Continue 확장 설치 및 Ollama 연결
- [ ] 탭 자동완성 동작 확인
- [ ] 하이브리드 전략 결정 (로컬 vs 클라우드 작업 분류)
- [ ] 성능 튜닝 환경 변수 설정

## 흔한 문제와 해결

| 문제 | 해결 |
|------|------|
| 모델 응답이 너무 느림 | 더 작은 모델로 변경, GPU 레이어 수 확인 |
| "connection refused" 에러 | `ollama serve`가 실행 중인지 확인 |
| 메모리 부족 (OOM) | 더 작은 모델 사용, 다른 앱 종료 |
| 한국어 응답 품질 낮음 | Qwen 계열이 한국어에 강함, Llama는 영어 위주 |
| 자동완성이 안 됨 | Continue 설정에서 `tabAutocompleteModel` 확인 |
| 코드 품질이 기대 이하 | temperature를 0.1~0.3으로 낮추기 |

## 다음 단계

→ [컨텍스트 관리 플레이북](12-context-management.md) — 로컬 LLM의 짧은 컨텍스트를 효과적으로 쓰는 법
→ [AI CLI 도구 비교 치트시트](../../cheatsheets/ai-cli-tools-comparison.md) — 로컬 vs 클라우드 도구 비교

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
