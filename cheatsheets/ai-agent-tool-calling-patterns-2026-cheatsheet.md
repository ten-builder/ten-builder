# AI 에이전트 Tool Calling 패턴 치트시트 2026

> Claude, GPT, Gemini 등 주요 AI 에이전트에서 Tool Calling을 제대로 쓰는 패턴 — 도구 설계부터 병렬 호출, 에러 처리, MCP 연동까지 한 페이지 정리

## 도구 스키마 설계 원칙

| 원칙 | 나쁜 예 | 좋은 예 |
|------|---------|---------|
| **이름은 동사_명사** | `data` | `fetch_user_profile` |
| **설명은 언제 쓰는지** | "데이터를 가져온다" | "사용자 ID로 프로필 조회 — 이메일·닉네임 필요 시 사용" |
| **파라미터 최소화** | 30개 필드 | 필수 3개 + 선택 2개 |
| **중복 도구 금지** | `get_data`, `fetch_data` | `fetch_user_profile` 하나로 통합 |

```python
# 좋은 도구 스키마 예시
{
  "name": "search_codebase",
  "description": "파일명·심벌·내용으로 코드베이스 검색. grep/ripgrep 불필요할 때 사용.",
  "input_schema": {
    "type": "object",
    "properties": {
      "query": {"type": "string", "description": "검색할 키워드 또는 정규식"},
      "path": {"type": "string", "description": "검색 범위 경로 (기본: 전체)"},
      "file_ext": {"type": "string", "description": "확장자 필터 (예: .ts, .py)"}
    },
    "required": ["query"]
  }
}
```

---

## 플랫폼별 Tool Calling 형식 비교

| 항목 | Claude (Anthropic) | GPT (OpenAI) | Gemini (Google) |
|------|-------------------|--------------|-----------------|
| **도구 결과 role** | `"user"` | `"tool"` | `"user"` (parts) |
| **ID 참조 필드** | `tool_use_id` | `tool_call_id` | 함수 이름 |
| **에러 표시** | `is_error: true` 블록 | 에러 문자열 반환 | response dict에 포함 |
| **병렬 호출** | 지원 (단일 메시지 내) | 지원 | 지원 |

---

## 병렬 Tool Calling — 핵심 패턴

### 올바른 결과 반환 방법

```python
# Claude 병렬 호출 — 결과는 반드시 하나의 user 메시지에 묶어야 함

# ❌ 잘못된 방식: 각 결과를 별도 메시지로 전송
messages.append({"role": "user", "content": result_1})
messages.append({"role": "user", "content": result_2})  # 에러 원인

# 올바른 방식: 모든 결과를 하나의 메시지에 배열로
messages.append({
  "role": "user",
  "content": [
    {"type": "tool_result", "tool_use_id": "tool_1", "content": result_1},
    {"type": "tool_result", "tool_use_id": "tool_2", "content": result_2}
  ]
})
```

### W&D 프레임워크 (Wide and Deep, 2026)

```
Depth  = 순차적 추론 단계 늘리기 (기존 방식)
Width  = 한 단계에서 병렬 호출 늘리기 (새로운 스케일링 축)

병렬 호출이 효과적인 상황:
  - 서로 의존성 없는 여러 API 조회
  - 멀티 레포 동시 검색
  - 독립적인 파일 읽기 배치

병렬 호출을 피해야 하는 상황:
  - 앞 호출 결과가 뒤 호출에 필요한 경우
  - 공유 상태(파일, DB)를 수정하는 경우
```

---

## 에러 처리 패턴

### 3단계 에러 복구 전략

```python
def call_tool_with_retry(tool_name, args, max_retries=2):
    for attempt in range(max_retries + 1):
        try:
            result = execute_tool(tool_name, args)
            if result.get("is_error"):
                # 1단계: 파라미터 수정 후 재시도
                if attempt < max_retries:
                    args = fix_params(args, result["error"])
                    continue
            return result
        except TimeoutError:
            # 2단계: 타임아웃 — 간소화된 대안 도구로 폴백
            return fallback_tool(tool_name, args)
        except Exception as e:
            # 3단계: 에러를 에이전트에게 명확히 전달
            return {"is_error": True, "error": str(e), "suggestion": suggest_fix(e)}
```

### Claude is_error 패턴

```python
# 에러를 에이전트가 이해할 수 있게 구조화
{
  "type": "tool_result",
  "tool_use_id": "toolu_abc123",
  "is_error": True,
  "content": "파일을 찾을 수 없습니다: /src/auth.ts\n"
             "힌트: /src/auth/ 디렉토리 내 파일 목록을 먼저 확인하세요."
}
```

---

## MCP 도구 연동 패턴

### alwaysLoad vs 필요 시 로드

```json
// .claude/settings.json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "alwaysLoad": true    // 세션 시작 시 항상 활성화
    },
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp"],
      "alwaysLoad": false   // 필요할 때만 /mcp 명령으로 로드
    }
  }
}
```

### MCP 도구 우선순위 설계

```
레이어 1 — 읽기 전용 도구 (자유롭게 사용)
  ✅ search_files, read_file, list_directory
  ✅ github_get_pr, linear_get_issue

레이어 2 — 쓰기 도구 (PreToolUse 훅으로 검증)
  ⚠️  write_file, create_pr, post_comment

레이어 3 — 파괴적 도구 (명시적 승인 필요)
  🔴 delete_file, merge_pr, deploy_production
```

```jsonc
// PreToolUse 훅으로 위험 도구 차단
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "delete_.*|.*destroy.*|.*drop_table.*",
      "hooks": [{"type": "block",
                 "message": "파괴적 작업입니다. 명시적 승인 후 진행하세요."}]
    }]
  }
}
```

---

## 도구 수 최적화

| 도구 수 | 모델 동작 | 권장 여부 |
|---------|----------|----------|
| 1~5개 | 정확하고 빠른 선택 | ✅ 최적 |
| 6~15개 | 약간의 선택 지연 | ✅ 허용 |
| 16~30개 | 도구 혼동 증가 | ⚠️ 카테고리로 분리 권장 |
| 30개 이상 | 성능 저하, 비용 증가 | ❌ 재설계 필요 |

```python
# 도구가 많을 때 — 동적 필터링으로 컨텍스트에 맞는 도구만 제공
def get_relevant_tools(task_type: str) -> list:
    if task_type == "code_review":
        return [read_file, list_files, search_code]
    elif task_type == "deployment":
        return [run_tests, build_docker, push_registry]
    else:
        return core_tools  # 기본 5개만
```

---

## 빠른 진단 체크리스트

```
도구 설계
  □ 도구 이름이 동작을 명확히 설명하는가?
  □ description에 "언제 써야 하는지"가 포함되어 있는가?
  □ 필수 파라미터는 3개 이하인가?
  □ 유사한 도구를 통합할 수 있는가?

병렬 호출
  □ 각 결과를 단일 user 메시지로 묶고 있는가?
  □ 서로 의존성 없는 호출만 병렬 처리하는가?

에러 처리
  □ is_error 시 힌트 메시지를 포함하는가?
  □ 재시도 로직이 무한 루프에 빠지지 않는가?
  □ 폴백 도구가 정의되어 있는가?

MCP 연동
  □ 파괴적 도구에 PreToolUse 훅이 설정되어 있는가?
  □ alwaysLoad는 자주 쓰는 도구에만 적용했는가?
```

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
