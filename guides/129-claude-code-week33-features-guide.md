# Claude Code Week 33 실전 가이드 — 플러그인 자동 로딩, `plugin init` 스캐폴딩, MCP 전환 총정리

> 2026년 6월 8~12일 릴리스 핵심 업데이트 — 플러그인 생태계 진입 장벽을 낮추는 두 가지 변경과, MCP `sse` 트랜스포트 종료 준비 가이드

## 이번 주 핵심 변경 요약

| 항목 | 변경 내용 | 영향 |
|------|-----------|------|
| 플러그인 자동 로딩 | `.claude/skills` 디렉토리 존재만으로 자동 인식 | 마켓플레이스 등록 없이 사용 가능 |
| `claude plugin init` | 새 플러그인 스캐폴딩 CLI 명령어 추가 | 플러그인 구조를 직접 만들지 않아도 됨 |
| `/plugin` 자동완성 | 서브커맨드 및 설치된 플러그인 이름 자동완성 | 탭 완성으로 빠른 접근 |
| 오류 재시도 개선 | 예상치 못한 오류 발생 시 폴백 모델로 1회 재시도 | 중단 없이 작업 지속 |
| MCP `sse` 트랜스포트 | Deprecated → `streamable-http` 전환 권장 | 1개 릴리스 사이클 내 마이그레이션 필요 |

---

## 1. 플러그인 자동 로딩 — 마켓플레이스 없이 바로 쓰기

이전에는 플러그인을 쓰려면 마켓플레이스 등록이나 별도 설치 과정이 필요했어요. 이번 업데이트로 `.claude/skills` 디렉토리에 플러그인 폴더만 있으면 자동으로 인식해요.

**프로젝트 로컬 플러그인 경로:**

```
.claude/
  skills/
    my-pr-review/
      SKILL.md
    api-docs-gen/
      SKILL.md
```

**사용자 전역 플러그인 경로:**

```
~/.claude/
  skills/
    code-reviewer/
      SKILL.md
```

플러그인을 특정 프로젝트에만 적용하려면 `.claude/skills/`에, 모든 프로젝트에 적용하려면 `~/.claude/skills/`에 배치하면 돼요. Claude Code 실행 시 두 경로를 모두 스캔해 자동으로 로딩합니다.

---

## 2. `claude plugin init` — 스캐폴딩으로 플러그인 빠르게 만들기

플러그인 디렉토리 구조를 직접 만드는 번거로움을 없애주는 CLI 명령어가 추가됐어요.

```bash
# 전역 위치에 플러그인 초기화
claude plugin init my-custom-skill

# 생성되는 구조:
# ~/.claude/skills/my-custom-skill/
#   SKILL.md          ← 메인 스킬 명세
#   plugin.json       ← 플러그인 메타데이터
#   commands/         ← 커스텀 슬래시 커맨드
#   hooks/            ← 훅 정의
#   bin/              ← 실행 스크립트
```

**plugin.json 예시:**

```json
{
  "name": "my-custom-skill",
  "version": "1.0.0",
  "description": "PR 리뷰 자동화 스킬",
  "skills": ["SKILL.md"],
  "commands": [],
  "hooks": []
}
```

초기화 후 `SKILL.md`에 스킬 절차를 작성하면 바로 Claude Code에서 `/my-custom-skill`로 호출할 수 있어요.

---

## 3. `/plugin` 자동완성 개선

`/plugin` 명령어에 탭 자동완성이 붙었어요. 세 가지 범위를 자동완성해요:

- **서브커맨드**: `install`, `list`, `remove`, `init`, `update`
- **설치된 플러그인 이름**: 로컬에 있는 플러그인 이름
- **마켓플레이스**: 알려진 공개 플러그인 이름

```bash
# 예시: 설치된 플러그인 확인
/plugin list

# 플러그인 제거 시 이름 자동완성
/plugin remove <Tab>  # 설치된 이름 목록 표시
```

---

## 4. 오류 재시도 개선 — 폴백 모델로 자동 복구

예상치 못한 API 오류 발생 시 Claude Code가 폴백 모델로 1회 재시도하도록 바뀌었어요.

**재시도 대상 오류:**

| 오류 유형 | 재시도 여부 | 비고 |
|-----------|------------|------|
| 예상치 못한 non-retryable 오류 | 폴백 모델로 1회 재시도 | 작업 지속 |
| 인증(auth) 오류 | 즉시 표면화 | 재시도 없음 |
| 레이트 리밋 오류 | 즉시 표면화 | 대기 후 수동 재시도 |
| 요청 크기 초과 오류 | 즉시 표면화 | 컨텍스트 축소 필요 |

장시간 자율 실행 중 일시적인 API 오류로 작업이 중단되는 경우가 줄어들어요.

---

## 5. MCP `sse` 트랜스포트 마이그레이션 — 지금 바꿔야 해요

`sse` (Server-Sent Events) 트랜스포트가 deprecated 됐어요. 1개 릴리스 사이클 내에 `streamable-http`로 전환해야 합니다.

**기존 설정 (마이그레이션 대상):**

```json
{
  "mcpServers": {
    "my-server": {
      "transport": "sse",
      "url": "http://localhost:3000/sse"
    }
  }
}
```

**새 설정 (`streamable-http` 또는 별칭 `http`):**

```json
{
  "mcpServers": {
    "my-server": {
      "transport": "streamable-http",
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

`streamable-http`는 `http`로 짧게 쓸 수도 있어요. 기존 `sse` 설정은 이번 릴리스에서는 동작하지만 다음 릴리스에서 제거될 예정이므로 지금 바꾸는 게 안전합니다.

---

## 이번 주 체크리스트

- [ ] `.claude/skills/` 또는 `~/.claude/skills/` 경로에 기존 스킬 파일 이동 여부 검토
- [ ] `claude plugin init` 으로 자주 쓰는 워크플로우 플러그인화 시도
- [ ] MCP 설정에서 `sse` 트랜스포트 사용 여부 확인 → `streamable-http` 전환
- [ ] `/plugin list`로 현재 로딩된 플러그인 목록 확인

---

**이전 가이드:** [Week 32 — Opus 4.8 Dynamic Workflows](./128-claude-code-week32-features-guide.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
