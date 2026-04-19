# Ollama + Claude Code 하이브리드 워크플로우

> 로컬 모델과 클라우드 AI를 조합해 비용을 절감하면서 성능을 유지하는 실전 워크플로우

## 개요

AI 코딩 도구 비용이 늘어나면서 모든 작업에 최고 성능 모델을 쓰는 방식은 지속 가능하지 않습니다. Ollama로 로컬 모델을 실행하고, Claude Code는 복잡한 작업에만 투입하는 하이브리드 전략을 사용하면 API 비용을 60-80% 줄이면서도 품질을 유지할 수 있습니다.

## 사전 준비

- macOS / Linux 환경 (RAM 16GB 이상 권장)
- [Ollama](https://ollama.com) 설치
- Claude Code 설치
- 터미널 기본 사용 가능

## 설정

### Step 1: Ollama 설치 및 모델 다운로드

```bash
# Ollama 설치 (macOS)
brew install ollama

# 서비스 시작
ollama serve &

# 코딩에 적합한 로컬 모델 다운로드
# 경량 (8GB RAM): 빠른 응답, 단순 작업
ollama pull qwen2.5-coder:7b

# 중급 (16GB RAM): 대부분의 일상 작업
ollama pull qwen2.5-coder:14b

# 고성능 (32GB RAM): 복잡한 리팩토링
ollama pull deepseek-coder-v2:16b
```

### Step 2: Claude Code와 Ollama 연동

Ollama 0.14.0 이상은 Anthropic Messages API와 호환됩니다.

```bash
# Claude Code가 Ollama 로컬 서버를 사용하도록 설정
export ANTHROPIC_BASE_URL=http://localhost:11434/v1
export ANTHROPIC_MODEL=qwen2.5-coder:14b

# 또는 셸 설정에 추가
echo 'export OLLAMA_CLAUDE_MODEL=qwen2.5-coder:14b' >> ~/.zshrc
```

### Step 3: 작업별 모델 라우팅 설정

```yaml
# ~/.claude/settings.json
{
  "defaultModel": "claude-sonnet-4-6",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Using cloud model for terminal ops'"
          }
        ]
      }
    ]
  }
}
```

## 사용 방법

### 작업 유형별 모델 선택 기준

| 작업 유형 | 권장 모델 | 이유 |
|-----------|-----------|------|
| 변수명 정리, 주석 추가 | Ollama 로컬 (7B) | 단순 작업, 비용 불필요 |
| 함수 구현, 단위 테스트 | Ollama 로컬 (14B) | 중간 복잡도, 빠른 응답 |
| 신규 기능 설계, 아키텍처 | Claude Sonnet | 복잡한 추론 필요 |
| 보안 코드, 결제 로직 | Claude Sonnet/Opus | 신뢰도 최우선 |
| 대규모 리팩토링 | Claude Opus | 전체 맥락 이해 필요 |

### 일상 워크플로우 예시

```bash
#!/bin/bash
# ai-task.sh — 작업 복잡도에 따라 모델 자동 선택

classify_task() {
  local task="$1"
  # 키워드 기반 분류 (간단한 휴리스틱)
  if echo "$task" | grep -qiE "refactor|architect|security|payment|auth"; then
    echo "cloud"
  elif echo "$task" | grep -qiE "rename|comment|format|lint|test"; then
    echo "local"
  else
    echo "local"  # 기본값: 로컬 모델 먼저 시도
  fi
}

run_with_model() {
  local task="$1"
  local model_type=$(classify_task "$task")

  if [ "$model_type" = "local" ]; then
    echo "로컬 모델 사용 중..."
    ANTHROPIC_BASE_URL=http://localhost:11434/v1 \
    ANTHROPIC_MODEL=qwen2.5-coder:14b \
    claude -p "$task" --dangerously-skip-permissions
  else
    echo "클라우드 모델 사용 중..."
    claude -p "$task" --dangerously-skip-permissions
  fi
}

# 사용 예시
run_with_model "auth.ts 파일의 JWT 검증 로직을 보안 관점에서 리뷰해줘"
```

### 프롬프트 캐싱으로 추가 절감

클라우드 모델을 사용할 때 프롬프트 캐싱을 적용하면 반복 작업 비용을 90%까지 절감할 수 있습니다.

```python
import anthropic

client = anthropic.Anthropic()

# 자주 쓰는 시스템 프롬프트를 캐시에 등록
# 첫 호출: cache_write_input_tokens 발생 (1.25x 비용)
# 이후 호출: cache_read_input_tokens 사용 (0.1x 비용)
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=4096,
    system=[
        {
            "type": "text",
            "text": """당신은 시니어 백엔드 개발자입니다.
TypeScript, Node.js, PostgreSQL 전문가로서
보안을 최우선으로 코드를 리뷰하고 개선합니다.
항상 한국어로 답변하세요.""",
            "cache_control": {"type": "ephemeral"}  # 5분 캐시
        }
    ],
    messages=[{"role": "user", "content": "auth.ts 코드를 리뷰해줘"}]
)

# 사용량 확인
usage = response.usage
print(f"캐시 읽기: {usage.cache_read_input_tokens} tokens")
print(f"캐시 쓰기: {usage.cache_creation_input_tokens} tokens")
```

## 커스터마이징

| 설정 | 권장값 | 설명 |
|------|--------|------|
| 로컬 모델 크기 | 14B | RAM 16GB 기준 최적 균형 |
| 클라우드 fallback | Claude Sonnet | 비용-성능 균형 |
| 캐시 TTL | ephemeral (5분) | 연속 대화에 적합 |
| Ollama threads | CPU 코어 수 | `OLLAMA_NUM_THREAD=8` |
| Ollama context | 32768 | 긴 파일 처리용 |

```bash
# Ollama 성능 최적화
export OLLAMA_NUM_THREAD=8          # CPU 코어 활용
export OLLAMA_FLASH_ATTENTION=1     # 메모리 효율화
export OLLAMA_KEEP_ALIVE=30m        # 모델 메모리 유지 (30분)
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| Ollama 응답 느림 | 작은 모델로 변경 (`7b`), GPU 가속 확인 |
| `connection refused` | `ollama serve` 실행 여부 확인 |
| 로컬 모델 품질 저하 | 해당 작업은 Claude Sonnet으로 전환 |
| 캐시 miss 지속 | 시스템 프롬프트 앞부분 일관성 유지 |
| 메모리 부족 | `OLLAMA_MAX_LOADED_MODELS=1` 설정 |

## 예상 비용 절감

팀 기준 (개발자 5명, 월 API 사용):

- 기존 (전량 Claude Sonnet): 월 약 $200
- 하이브리드 (80% 로컬 + 20% 클라우드): 월 약 $40
- **절감: 약 80%, 월 $160**

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
