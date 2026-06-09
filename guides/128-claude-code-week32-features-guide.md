# Claude Code Week 32 실전 가이드 — fallbackModel, 플러그인 자동 로딩, 보안 강화

> 2026년 6월 2~6일 업데이트(v2.1.153~v2.1.156)에서 챙겨야 할 핵심 변경 정리

## 소요 시간

15–20분

## 이번 주 핵심 요약

| 기능 | 변경 내용 | 영향 |
|------|-----------|------|
| `fallbackModel` 설정 | 기본 모델 장애 시 최대 3개 대체 모델 자동 전환 | 장시간 에이전트 세션 안정성 향상 |
| 플러그인 자동 로딩 | `.claude/skills` 폴더 플러그인 자동 감지 | 마켓플레이스 없이 팀 플러그인 즉시 공유 |
| `claude plugin init` | 플러그인 스캐폴드 커맨드 추가 | 새 플러그인 제작 시간 단축 |
| 보안 강화 | `SendMessage` 세션 간 권한 격리 | 다중 에이전트 환경 보안 사고 방지 |
| deny rule 글로브 지원 | `""` 하나로 전체 툴 차단 | 권한 최소화 설정 간소화 |
| `claude agents` URL 필터 | 에이전트 목록에서 URL로 세션 검색 | 멀티 세션 관리 효율화 |

---

## 1. fallbackModel — 모델 장애 시 자동 전환

### 1-1. 설정 방법

기본 모델이 과부하 또는 장애 상태일 때 순서대로 대체 모델을 시도하는 `fallbackModel` 설정이 추가됐습니다.

`settings.json`에 다음을 추가하세요:

```json
{
  "model": "claude-opus-4-8",
  "fallbackModel": [
    "claude-opus-4-7",
    "claude-sonnet-4-6",
    "claude-haiku-3-7"
  ]
}
```

CLI에서도 직접 지정할 수 있습니다:

```bash
# 인터랙티브 세션에서도 fallback 적용
claude --model claude-opus-4-8 --fallback-model claude-sonnet-4-6
```

### 1-2. 언제 작동하나요?

| 상황 | 동작 |
|------|------|
| 기본 모델 과부하 | 첫 번째 fallback 모델로 자동 전환 |
| API 비예기치 오류 | 한 번 재시도 후 fallback 시도 |
| 인증/레이트 리밋 오류 | fallback 없이 즉시 오류 표시 |
| 요청 크기 초과 | fallback 없이 즉시 오류 표시 |

**실전 팁:** 장시간 실행 에이전트(예: Dynamic Workflow, 레거시 마이그레이션)에 `fallbackModel` 설정을 꼭 넣어두면 중간에 모델 장애로 작업이 중단되는 상황을 예방할 수 있어요.

```json
{
  "model": "claude-opus-4-8",
  "fallbackModel": ["claude-opus-4-7"]
}
```

---

## 2. 플러그인 자동 로딩 — 마켓플레이스 없이 팀 플러그인 공유

### 2-1. `.claude/skills` 자동 감지

이제 프로젝트 루트의 `.claude/skills/` 폴더에 플러그인을 넣으면 Claude Code가 자동으로 인식합니다.

```
my-project/
  .claude/
    skills/
      code-review-bot/
        plugin.json
        index.ts
      doc-generator/
        plugin.json
        index.ts
  src/
  ...
```

기존에는 마켓플레이스 등록이나 수동 설치가 필요했지만, 이제 Git 저장소에 폴더만 커밋하면 팀원 모두가 자동으로 같은 플러그인을 씁니다.

### 2-2. 새 플러그인 만들기

```bash
# 플러그인 스캐폴드 생성
claude plugin init my-plugin

# 생성되는 구조
.claude/skills/my-plugin/
  plugin.json     # 플러그인 메타데이터
  index.ts        # 진입점
  README.md       # 설명서
```

`plugin.json` 기본 구조:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "팀 전용 코드 검사 플러그인",
  "skills": [
    {
      "name": "check-naming",
      "description": "변수/함수 네이밍 컨벤션 자동 검사"
    }
  ]
}
```

### 2-3. 플러그인 자동완성

`/plugin` 커맨드에 자동완성이 추가됐습니다:

```bash
/plugin <Tab>          # 서브커맨드 목록
/plugin install <Tab>  # 설치된 플러그인 + 마켓플레이스 플러그인 목록
/plugin tag <Tab>      # 버전 태그 생성 (릴리스용)
```

**배포 팁:** `claude plugin tag v1.2.0` 커맨드로 버전 검증 후 Git 릴리스 태그를 자동 생성할 수 있어요.

---

## 3. 보안 강화 — 세션 간 권한 격리

### 3-1. SendMessage 권한 분리

이번 업데이트에서 다중 에이전트 환경의 보안이 강화됐습니다.

기존에는 `SendMessage`로 다른 Claude 세션에서 메시지를 보낼 때 발신 세션의 권한이 수신 세션에 전달되는 경우가 있었습니다. 이제 이 동작이 차단됩니다:

```
변경 사항:
- 다른 세션이 릴레이한 메시지는 user authority를 갖지 않음
- 수신 세션이 릴레이된 권한 요청을 거부
- auto 모드에서 릴레이 요청 자동 차단
```

**실전 영향:** 오케스트레이터-워커 패턴에서 워커 에이전트에 별도 권한을 명시적으로 부여해야 합니다. 오케스트레이터의 권한이 자동으로 상속되지 않아요.

### 3-2. deny rule 글로브 패턴

deny rule의 툴 이름 위치에 글로브 패턴을 쓸 수 있습니다:

```json
{
  "autoMode": {
    "deny": [
      {"tool": ""},           // 모든 툴 차단
      {"tool": "Bash(rm*)"}   // rm으로 시작하는 Bash 커맨드 차단
    ]
  }
}
```

| 패턴 | 효과 |
|------|------|
| `""` | 모든 툴 차단 |
| `"Bash(rm*)"` | `rm` 시작 커맨드 차단 |
| `"mcp__*"` | 모든 MCP 툴 차단 |

**주의:** allow rule에는 MCP가 아닌 글로브 패턴 사용이 차단됩니다. deny rule에만 적용됩니다.

---

## 4. `claude agents` URL 필터링

장시간 에이전트를 여러 개 운영할 때 특정 세션을 빠르게 찾는 방법이 추가됐습니다.

```bash
# 특정 URL을 처음 프롬프트에 포함한 세션 찾기
claude agents
# 목록 열린 상태에서 URL 입력 → 해당 세션 필터링

# JSON으로 전체 목록 확인
claude agents --json | python3 -c "
import sys, json
agents = json.load(sys.stdin)
for a in agents:
    print(f\"{a['id'][:8]}... | {a['status']} | {a['title'][:50]}\")
"
```

멀티 에이전트 환경에서 GitHub 이슈 URL, 태스크 URL 등으로 세션을 구분해 두면 나중에 빠르게 찾을 수 있어요.

---

## 5. 그 외 주요 업데이트

### 5-1. `MAX_THINKING_TOKENS` 제한 해제

이전까지 모델별로 최대 사고 토큰에 상한이 있었습니다. 이번 업데이트에서 `MAX_THINKING_TOKENS` 제한이 모델 기본값 이상으로 늘릴 수 있게 변경됐습니다.

```bash
# 환경변수로 최대 사고 토큰 설정
MAX_THINKING_TOKENS=32000 claude
```

복잡한 아키텍처 설계나 대규모 리팩토링 시 더 긴 사고 체인을 허용해 품질을 높일 수 있습니다.

### 5-2. `claude update` 투명성 개선

```bash
claude update
# 이전: 다운로드 중 화면 무반응
# 이후: "v2.1.153 → v2.1.156 다운로드 중..." 진행 상황 표시
```

### 5-3. 버그 수정 요약

| 버그 | 상태 |
|------|------|
| tmux + copy-on-select 클립보드 미도달 | 수정 |
| `--resume`로 서브에이전트 실행 중 상태 미표시 | 수정 |
| `--worktree` 옵션이 저장소 루트로 복귀하는 문제 | 수정 |
| 이미지 처리 불가 반복 오류 + 과도한 토큰 소비 | 수정 |
| 원격 세션 일시 장애 후 영구 중단 | 수정 |

---

## 6. 실전 적용 체크리스트

### 이번 주에 바로 적용할 것들

```bash
# 1. fallbackModel 설정 추가
cat ~/.claude/settings.json | python3 -m json.tool  # 현재 설정 확인
# settings.json에 fallbackModel 배열 추가

# 2. 팀 플러그인을 .claude/skills/로 이전
mkdir -p .claude/skills
# 기존 수동 설치 플러그인을 폴더로 이동

# 3. deny rule 글로브 패턴으로 간소화
# 기존: 툴마다 개별 deny 항목
# 이후: "" 하나로 전체 차단 후 필요한 것만 allow

# 4. claude agents --json 모니터링 스크립트 업데이트
```

### 멀티 에이전트 보안 체크

```bash
# 오케스트레이터 → 워커 권한 설정 확인
claude agents --json | python3 -c "
import sys, json
agents = json.load(sys.stdin)
for a in agents:
    if a.get('permissionMode') == 'default':
        print(f\"권한 미설정: {a['id'][:8]}...\")
"
```

---

## 더 알아보기

- [Claude Code 공식 변경 로그](https://code.claude.com/docs/en/changelog)
- [플러그인 개발 가이드](../claude-code/playbooks/)
- [멀티 에이전트 보안 설정](../cheatsheets/owasp-agentic-ai-security-cheatsheet-2026.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
