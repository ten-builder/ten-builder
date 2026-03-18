# EP08: OpenAI Codex CLI 실전 리뷰 — Claude Code와 뭐가 다를까

> 같은 프로젝트에 두 도구를 투입해서 직접 비교한 실전 기록

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- OpenAI Codex CLI 설치부터 첫 실행까지 세팅 과정
- Claude Code와 동일한 작업을 시켜봤을 때 체감 차이
- 각 도구가 잘하는 영역과 아쉬운 점
- 실전에서 두 도구를 함께 쓰는 패턴

## 왜 Codex CLI인가

2025년 말에 OpenAI가 Codex CLI를 오픈소스로 공개했어요. 터미널에서 `codex` 명령어 하나로 코드를 생성하고 수정할 수 있는 도구예요. Claude Code와 직접 경쟁하는 포지션이에요.

둘 다 터미널 기반이고, 둘 다 코드베이스를 이해하고, 둘 다 파일을 직접 수정해요. 그래서 "실제로 써보면 뭐가 다른가?"가 궁금했어요.

## 설치 및 세팅

### Codex CLI 설치

```bash
# npm으로 전역 설치
npm install -g @openai/codex

# API 키 설정
export OPENAI_API_KEY="sk-..."

# 버전 확인
codex --version
```

### Claude Code 설치 (비교용)

```bash
# npm으로 전역 설치
npm install -g @anthropic-ai/claude-code

# 인증 (브라우저 OAuth)
claude auth

# 버전 확인
claude --version
```

## 실전 비교 테스트

같은 프로젝트에서 동일한 작업을 시켜보고 결과를 비교했어요.

### 테스트 1: 새 API 엔드포인트 추가

**프롬프트:** "users 라우터에 GET /users/:id/activity 엔드포인트를 추가해줘. 최근 30일 활동 로그를 반환하고, 페이지네이션을 지원해야 해."

```bash
# Codex CLI
codex "users 라우터에 GET /users/:id/activity 엔드포인트를 추가해줘"

# Claude Code
claude "users 라우터에 GET /users/:id/activity 엔드포인트를 추가해줘"
```

| 항목 | Codex CLI | Claude Code |
|------|-----------|-------------|
| 완료 시간 | ~15초 | ~25초 |
| 파일 수정 | 1개 (라우터만) | 3개 (라우터+서비스+타입) |
| 테스트 생성 | 자동 생성 안 함 | 물어본 뒤 생성 |
| 에러 처리 | 기본 try-catch | 커스텀 에러 클래스 |

**체감:** Codex CLI가 속도는 빠르지만, Claude Code가 주변 코드 스타일을 더 잘 따라가요.

### 테스트 2: 버그 수정

**프롬프트:** "로그인할 때 간헐적으로 세션이 유지되지 않는 버그가 있어. auth 미들웨어를 확인하고 수정해줘."

| 항목 | Codex CLI | Claude Code |
|------|-----------|-------------|
| 원인 파악 | 쿠키 설정 누락 지적 | 쿠키 + 세션 스토어 동시 확인 |
| 수정 범위 | 1곳 | 2곳 (근본 원인 추적) |
| 설명 | 간결한 한 줄 | 단계별 추론 과정 |

**체감:** 디버깅은 Claude Code가 더 깊이 파고들어요. 원인을 찾는 과정을 보여주는 것도 좋아요.

### 테스트 3: 리팩토링

**프롬프트:** "utils/helpers.js가 500줄이 넘어. 기능별로 파일을 분리하고 import를 수정해줘."

| 항목 | Codex CLI | Claude Code |
|------|-----------|-------------|
| 분리 전략 | 3개 파일로 분리 | 5개 파일로 분리 |
| import 수정 | 직접 참조만 수정 | re-export index 파일 추가 |
| 기존 코드 호환 | 일부 깨짐 | 하위 호환 유지 |

## 핵심 차이점 정리

### Codex CLI의 특징

```
┌─────────────────────────────────────────────┐
│  Codex CLI 강점                              │
├─────────────────────────────────────────────┤
│  ✅ 빠른 실행 속도 (간단한 작업에 유리)         │
│  ✅ 오픈소스 — 커스터마이징 가능                │
│  ✅ 클라우드 샌드박스에서 안전하게 실행           │
│  ✅ 멀티 에이전트 병렬 실행 지원                │
│  ✅ --full-auto 모드로 무인 자동화 가능          │
├─────────────────────────────────────────────┤
│  ⚠️ 아쉬운 점                                │
├─────────────────────────────────────────────┤
│  △ 한글 프롬프트 처리가 불안정할 때 있음         │
│  △ 큰 코드베이스에서 컨텍스트 누락 발생          │
│  △ 인터랙티브 모드의 UX가 아직 거친 편           │
└─────────────────────────────────────────────┘
```

### Claude Code의 특징

```
┌─────────────────────────────────────────────┐
│  Claude Code 강점                            │
├─────────────────────────────────────────────┤
│  ✅ 코드 맥락 이해도가 높음                    │
│  ✅ 단일 작업 깊이가 깊음 (복잡한 리팩토링)      │
│  ✅ CLAUDE.md로 프로젝트별 규칙 설정            │
│  ✅ Hooks로 워크플로우 자동화 가능               │
│  ✅ 한글 프롬프트 자연스럽게 처리                │
├─────────────────────────────────────────────┤
│  ⚠️ 아쉬운 점                                │
├─────────────────────────────────────────────┤
│  △ 속도가 Codex보다 느린 경우가 많음            │
│  △ API 비용이 상대적으로 높음                   │
│  △ 오픈소스가 아님 (확장성 제한)                │
└─────────────────────────────────────────────┘
```

## 실전 사용 패턴: 두 도구 함께 쓰기

둘 다 장점이 있으니까, 작업 유형에 따라 골라 쓰는 게 효과적이에요.

### 작업별 추천 도구

| 작업 유형 | 추천 도구 | 이유 |
|-----------|-----------|------|
| 간단한 파일 수정 | Codex CLI | 빠르게 끝남 |
| 복잡한 리팩토링 | Claude Code | 맥락 이해도 높음 |
| 병렬 멀티태스크 | Codex CLI | 멀티 에이전트 지원 |
| 디버깅 | Claude Code | 추론 과정이 도움됨 |
| 자동화 스크립트 | Codex CLI | `--full-auto` 모드 |
| 코드 리뷰 | Claude Code | 상세한 피드백 |
| 보일러플레이트 생성 | Codex CLI | 속도 우선 |
| 아키텍처 설계 | Claude Code | 깊은 분석 |

### 워크플로우 예시: 듀얼 에이전트

```bash
#!/bin/bash
# dual-agent.sh — 두 도구를 순차 실행하는 예시

# Step 1: Codex로 보일러플레이트 빠르게 생성
codex exec "src/components/ 안에 UserDashboard 컴포넌트 스캐폴딩을 만들어줘" \
  --full-auto

# Step 2: Claude Code로 비즈니스 로직 채우기
claude "UserDashboard 컴포넌트에 실제 API 연동과 에러 처리를 추가해줘. 
기존 프로젝트 패턴을 따라줘."

# Step 3: Codex로 테스트 코드 빠르게 생성
codex exec "UserDashboard의 단위 테스트를 작성해줘" --full-auto
```

### 비용 비교

```
┌─────────────────────────────────────────────┐
│  월간 비용 예상 (하루 2-3시간 사용 기준)         │
├─────────────────────────────────────────────┤
│  Codex CLI (API)         │  $30-50/월       │
│  Codex (Pro 구독)         │  $200/월         │
│  Claude Code (API)       │  $50-80/월       │
│  Claude Code (Max 구독)   │  $100-200/월     │
│  듀얼 사용 (API)          │  $60-100/월      │
└─────────────────────────────────────────────┘
```

> Codex CLI는 오픈소스라서 API 키만 있으면 무료로 쓸 수 있어요. 다만 API 호출 비용은 별도.

## CLAUDE.md vs codex.md

두 도구 모두 프로젝트 루트에 설정 파일을 두는 방식을 지원해요.

```bash
# Claude Code: CLAUDE.md
cat > CLAUDE.md << 'EOF'
# Project Rules
- 한국어로 커밋 메시지 작성
- src/ 내 파일만 수정 가능
- 테스트 없이 커밋 금지
EOF

# Codex: codex.md (또는 AGENTS.md)
cat > codex.md << 'EOF'
# Codex Instructions
- Korean commit messages
- Only modify files in src/
- Must include tests
EOF
```

| 비교 | CLAUDE.md | codex.md |
|------|-----------|----------|
| 위치 | 프로젝트 루트 또는 ~/.claude/ | 프로젝트 루트 |
| 상속 | 글로벌 → 프로젝트 → 로컬 | 프로젝트 단위 |
| 포맷 | Markdown (자유 형식) | Markdown (자유 형식) |
| 커스텀 명령어 | /.claude/commands/ | 미지원 (CLI 플래그) |

## 따라하기

### Step 1: 테스트 프로젝트 준비

```bash
mkdir codex-vs-claude-test && cd codex-vs-claude-test
npm init -y
npm install express

cat > server.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.listen(3000, () => console.log('Server running on :3000'));
EOF
```

### Step 2: 동일 프롬프트로 비교

```bash
# 같은 작업을 양쪽에 시켜보세요
PROMPT="server.js에 POST /api/notes 엔드포인트를 추가해줘. 
인메모리 배열에 저장하고, 유효성 검사도 포함해줘."

# Codex
codex "$PROMPT"

# Claude Code (별도 터미널)
claude "$PROMPT"
```

### Step 3: 결과 비교 체크리스트

```markdown
- [ ] 코드가 실행되는가? (node server.js)
- [ ] 엔드포인트가 정상 동작하는가? (curl 테스트)
- [ ] 에러 처리가 있는가?
- [ ] 기존 코드 스타일을 따르는가?
- [ ] 추가 파일이 생성되었는가?
- [ ] 실행 시간은 얼마나 걸렸는가?
```

## 정리

| 결론 | 내용 |
|------|------|
| 속도 | Codex CLI가 빠름 (특히 단순 작업) |
| 정확도 | Claude Code가 맥락을 더 잘 이해 |
| 비용 | Codex CLI가 저렴한 편 |
| 자동화 | Codex CLI의 `--full-auto`가 편리 |
| 복잡한 작업 | Claude Code의 추론 깊이가 우수 |
| 추천 | 둘 다 써보고 작업에 맞게 선택 |

어느 한쪽이 절대적으로 낫다기보다는, 작업 성격에 맞는 도구를 고르는 게 중요해요. 간단하고 반복적인 작업은 Codex CLI, 복잡하고 맥락이 중요한 작업은 Claude Code가 맞아요.

## 더 알아보기

- [Codex CLI GitHub](https://github.com/openai/codex)
- [Claude Code 문서](https://docs.anthropic.com/en/docs/claude-code)
- [AI 에이전트 모드 비교 치트시트](../cheatsheets/agent-mode-comparison-cheatsheet.md)
- [AI CLI 도구 비교 치트시트](../cheatsheets/ai-cli-tools-comparison.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
