# AI 코딩 에이전트 설정 최적화 워크플로우

> 기본 설정으로 쓰면 50%밖에 못 쓰는 거예요 — settings.json, 환경 변수, 권한 체계를 프로젝트에 맞게 튜닝하는 방법

## 개요

Claude Code, Cursor, Codex CLI 같은 AI 코딩 에이전트를 설치하면 바로 쓸 수 있어요. 하지만 기본 설정 그대로 쓰면 토큰 낭비, 불필요한 권한 프롬프트, 비효율적인 모델 선택 등의 문제가 생겨요.

이 워크플로우는 AI 코딩 에이전트의 설정을 프로젝트 특성에 맞게 최적화하는 단계별 가이드예요. 한 번 세팅하면 매일 반복되는 비효율을 없앨 수 있어요.

## 사전 준비

- Claude Code 또는 다른 AI 코딩 에이전트 설치 완료
- 프로젝트 루트에 CLAUDE.md (또는 동등한 설정 파일) 존재
- `settings.json` 파일 위치 확인 (`~/.claude/settings.json`)

## Step 1: 현재 설정 진단

### 설정 파일 계층 구조 이해

AI 코딩 에이전트의 설정은 여러 레벨에서 적용돼요. 우선순위를 이해해야 충돌을 피할 수 있어요.

| 레벨 | 위치 | 우선순위 | 용도 |
|------|------|----------|------|
| 환경 변수 | 셸/터미널 | 최상 | 임시 오버라이드 |
| CLI 플래그 | 실행 시 인자 | 높음 | 세션별 설정 |
| 프로젝트 설정 | `.claude/settings.json` | 중간 | 프로젝트별 설정 |
| 글로벌 설정 | `~/.claude/settings.json` | 낮음 | 기본 설정 |
| 기본값 | 에이전트 내장 | 최하 | 폴백 |

### 현재 상태 확인

```bash
# 글로벌 설정 확인
cat ~/.claude/settings.json | jq .

# 프로젝트 설정 확인
cat .claude/settings.json 2>/dev/null || echo "프로젝트 설정 없음"

# 활성 환경 변수 확인
env | grep -E "CLAUDE_|ANTHROPIC_" | sort
```

## Step 2: 권한 설정 최적화

### 문제: 반복되는 권한 프롬프트

기본 설정에서는 파일 읽기/쓰기, 명령어 실행 때마다 확인을 요청해요. 프로젝트에서 안전하다고 판단되는 도구는 미리 허용해두면 작업 흐름이 빨라져요.

### 권한 설정 패턴

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write(src/)",
      "Write(tests/)",
      "Write(docs/)",
      "Bash(npm run lint)",
      "Bash(npm run test *)",
      "Bash(npm run build)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git status)"
    ],
    "deny": [
      "Bash(curl *)",
      "Bash(wget *)",
      "Read(.env)",
      "Read(.env.*)",
      "Write(production.*)",
      "Bash(rm -rf *)",
      "Bash(git push *)"
    ]
  }
}
```

### 프로젝트 유형별 권한 프리셋

| 프로젝트 유형 | 추가 허용 | 추가 차단 |
|-------------|----------|----------|
| Next.js | `Bash(npx next *)`, `Write(public/)` | `Write(.next/)` |
| Python | `Bash(python -m pytest *)`, `Bash(pip install *)` | `Bash(pip install --user *)` |
| Go | `Bash(go test *)`, `Bash(go build *)` | `Bash(go install *)` |
| Rust | `Bash(cargo test *)`, `Bash(cargo build *)` | `Bash(cargo publish *)` |

### 주의사항

- `deny` 규칙은 `allow`보다 우선해요
- 와일드카드(`*`)는 명령어 뒤에만 사용 가능
- `.env` 파일은 반드시 차단 — AI 에이전트가 시크릿을 컨텍스트에 포함시키면 안 돼요

## Step 3: 모델 선택 최적화

### 작업별 모델 라우팅

모든 작업에 같은 모델을 쓰는 건 비용 낭비예요. 작업 복잡도에 따라 모델을 나누면 비용 대비 효율이 올라요.

| 작업 유형 | 적합한 모델 | 이유 |
|----------|-----------|------|
| 간단한 수정, 포맷팅 | Haiku / Flash | 빠르고 저렴 |
| 일반 코딩, 테스트 작성 | Sonnet | 균형잡힌 성능 |
| 아키텍처 설계, 복잡한 리팩토링 | Opus | 깊은 추론 필요 |
| 대규모 코드 분석 | Gemini 2.5 Pro | 긴 컨텍스트 윈도우 |

### 모델 오버라이드 설정

```json
{
  "model": "claude-sonnet-4-20250514",
  "modelOverrides": {
    "claude-opus-4-20260301": "claude-opus-4-20260301",
    "claude-haiku-3-5-20241022": "claude-haiku-3-5-20241022"
  }
}
```

### 환경 변수로 임시 전환

```bash
# 복잡한 작업에 Opus 사용
CLAUDE_CODE_DEFAULT_MODEL=claude-opus-4-20260301 claude

# 간단한 작업에 Haiku 사용
CLAUDE_CODE_DEFAULT_MODEL=claude-haiku-3-5-20241022 claude
```

## Step 4: Extended Thinking 최적화

### Adaptive Thinking 이해

최신 모델(Opus 4.6, Sonnet 4.6)은 adaptive reasoning을 지원해요. 에이전트가 스스로 "이 작업에 깊은 사고가 필요한가?"를 판단해서 thinking 토큰을 조절해요.

### 설정 옵션

```bash
# Thinking 토큰 예산 설정 (기본: 모델 최대 출력 토큰 - 1)
export MAX_THINKING_TOKENS=16000

# Adaptive thinking 비활성화 (항상 고정 예산 사용)
export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=true

# Thinking 완전 비활성화 (빠른 작업용)
export MAX_THINKING_TOKENS=0
```

### 언제 Thinking을 조절해야 하나

| 상황 | 설정 | 이유 |
|------|------|------|
| 아키텍처 결정 | 기본값 유지 또는 예산 증가 | 깊은 사고가 품질에 직접 영향 |
| 단순 파일 수정 | `MAX_THINKING_TOKENS=0` | 토큰 절약 |
| 디버깅 | 기본값 유지 | 문제 분석에 추론 필요 |
| 코드 포맷팅 | `MAX_THINKING_TOKENS=0` | 추론 불필요 |

## Step 5: 출력 토큰 최적화

### 문제: 응답이 잘리는 경우

기본 출력 토큰 한도가 너무 낮으면 코드 생성 도중 응답이 잘릴 수 있어요.

```bash
# 출력 토큰 한도 설정
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=16384
```

### 프로젝트별 권장값

| 작업 | 권장 토큰 | 설명 |
|------|----------|------|
| 코드 리뷰 | 8192 | 피드백 + 수정 제안 |
| 파일 생성 | 16384 | 긴 파일 한 번에 작성 |
| 리팩토링 | 16384 | 여러 파일 수정 |
| 간단한 질문 | 4096 | 빠른 응답 |

## Step 6: 프로젝트별 설정 파일 관리

### 설정 파일 구조

```
my-project/
├── .claude/
│   └── settings.json     ← 프로젝트 권한/모델 설정
├── CLAUDE.md              ← 프로젝트 컨텍스트/규칙
├── .cursorrules           ← Cursor 전용 규칙
└── .github/
    └── copilot-instructions.md  ← Copilot 전용 규칙
```

### 팀 공유 설정

프로젝트 `.claude/settings.json`은 Git에 커밋해서 팀 전체가 같은 설정을 쓸 수 있어요.

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write(src/)",
      "Write(tests/)",
      "Bash(pnpm lint)",
      "Bash(pnpm test *)",
      "Bash(pnpm build)"
    ],
    "deny": [
      "Read(.env*)",
      "Bash(rm -rf *)",
      "Bash(*production*)"
    ]
  }
}
```

### .gitignore에 민감 설정 제외

```gitignore
# 개인 설정은 커밋하지 않음
.claude/settings.local.json
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `model` | `claude-sonnet-4` | 기본 모델 |
| `MAX_THINKING_TOKENS` | 모델 최대값 | Thinking 토큰 예산 |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | 4096 | 최대 응답 길이 |
| `permissions.allow` | `[]` | 자동 승인 도구 목록 |
| `permissions.deny` | `[]` | 차단 도구 목록 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 설정이 적용되지 않음 | `jq . ~/.claude/settings.json`으로 문법 확인 |
| 권한 프롬프트가 계속 뜸 | `allow` 패턴에 명령어 접두사가 정확한지 확인 |
| 모델 전환이 안 됨 | `modelOverrides`에 정확한 모델 ID 입력 |
| 응답이 잘림 | `CLAUDE_CODE_MAX_OUTPUT_TOKENS` 값 증가 |
| Thinking이 너무 느림 | `MAX_THINKING_TOKENS` 값 줄이거나 0으로 설정 |
| WSL2에서 느림 | 프로젝트를 `~/` 아래로 이동 (`/mnt/c/` 피하기) |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
