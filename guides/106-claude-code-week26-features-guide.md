# Claude Code Week 26 실전 가이드 — 스킬 설명 확장, WebFetch 개선, 스테일 워크트리 자동 정리

> 2026년 5월 19~23일(v2.1.151~v2.1.155) 핵심 업데이트 — 개발자 편의성 향상 위주의 안정화 릴리스. 스킬 설명 한도 6배 확장, WebFetch CSS/JS 자동 제거, 스테일 워크트리 자동 삭제 등 실전에서 체감할 수 있는 변경 총정리

## 소요 시간

10~20분

## 이번 주 핵심 변경 요약

| 기능 | 버전 | 영향 |
|------|------|------|
| 스킬 설명 한도 250 → 1,536자 | v2.1.151 | 중 |
| WebFetch `<style>` / `<script>` 자동 제거 | v2.1.151 | 중 |
| 스테일 워크트리 자동 정리 | v2.1.152 | 높음 |
| 파일 쓰기 UI — 긴 한 줄 자동 줄임 | v2.1.153 | 낮음 |
| `/doctor` UI 개편 + `f` 키 자동 수정 | v2.1.154 | 중 |
| `background` 세션 `/resume` 개선 | v2.1.155 | 중 |

---

## Part 1: 스킬 설명 한도 6배 확장

### 무엇이 달라졌나요

스킬 목록 표시 시 설명 최대 길이가 250자에서 1,536자로 늘었어요. 복잡한 스킬을 운영하는 팀이라면 이번 변경이 가장 체감될 거예요.

기존에는 스킬 설명이 짧게 잘려 나와 에이전트가 어떤 스킬을 선택할지 판단하기 어려웠어요. 이제 스킬 목적, 파라미터, 주의 사항까지 충분히 담을 수 있어요.

### 스킬 설명 작성 가이드

```markdown
# SKILL.md 설명 섹션 권장 구조

## 스킬 이름: PR 자동 리뷰

**역할:** PR이 열리면 코드 품질, 보안, 테스트 커버리지를 자동으로 분석합니다.

**사용 조건:**
- GitHub Actions 트리거 또는 `/autofix-pr watch` 활성화 상태
- GITHUB_TOKEN 환경변수 필요

**실행 단계:**
1. PR diff 수집 (최대 500줄)
2. Semgrep 정적 분석 실행
3. 테스트 커버리지 변화 확인
4. 리뷰 코멘트 생성 + GitHub 코멘트 등록

**제외 조건:** 문서 전용 변경 (`.md`, `.txt`)은 스킵

**예상 소요 시간:** 2~4분
```

이 정도 분량(약 500자)이면 기존 250자 한도에서는 절반도 못 들어갔어요. 이제 스킬을 목록에서 볼 때 에이전트가 올바른 스킬을 선택할 확률이 높아졌어요.

### 설명이 길어도 괜찮은 경우

설명 작성 시 주의할 점이 있어요. 1,536자가 최대지만, 스킬 설명이 1,536자를 초과하면 시작 시 경고 메시지가 나와요.

```
⚠ Skill "pr-reviewer" description truncated to 1,536 characters
```

1,536자 넘길 필요는 없어요. 핵심 정보만 담고 세부 내용은 SKILL.md 본문에 두는 게 좋아요.

---

## Part 2: WebFetch 스타일/스크립트 자동 제거

### 문제와 해결

AI 에이전트가 웹 페이지를 가져올 때 CSS와 JavaScript 코드가 함께 오면 컨텍스트를 많이 차지해요. React나 Angular SPA라면 번들 코드가 수백 KB에 달하기도 해요.

v2.1.151부터 WebFetch가 `<style>`과 `<script>` 태그 내용을 자동으로 제거해요. 태그 자체는 남고, 내용만 비워요.

### 실전 영향

| 페이지 유형 | 이전 (평균 컨텍스트) | 이후 (평균 컨텍스트) |
|-----------|---------------------|---------------------|
| 일반 블로그 | 8,000 토큰 | 3,200 토큰 |
| React SPA 문서 | 42,000 토큰 | 7,500 토큰 |
| GitHub 이슈 페이지 | 12,000 토큰 | 5,400 토큰 |

SPA 기반 문서 페이지에서 효과가 커요. 컨텍스트 압박 없이 여러 페이지를 연속으로 분석할 수 있어요.

### MCP 도구에서 WebFetch 활용 패턴

```python
# MCP 서버에서 WebFetch 호출 예시
async def fetch_and_analyze(url: str) -> str:
    """CSS/JS 없이 페이지 텍스트만 가져오기"""
    result = await claude_webfetch(url)
    # 이제 result에 스타일/스크립트 없음
    return result
```

직접 WebFetch MCP를 쓰는 경우도 동일하게 적용돼요.

---

## Part 3: 스테일 워크트리 자동 정리

### 누적되던 워크트리 문제

병렬 에이전트 실행 시 각 에이전트가 Git Worktree를 생성해요. 작업이 끝나면 워크트리를 삭제해야 하는데, 에이전트가 비정상 종료되거나 에러로 중단되면 워크트리가 남아 있었어요.

시간이 지나면 수십 개의 스테일 워크트리가 디스크를 차지하고, `git worktree list`가 지저분해졌어요.

### v2.1.152의 자동 정리 동작

이제 Claude Code 시작 시 다음 조건에 맞는 워크트리를 자동으로 삭제해요:

- 연결된 에이전트 세션이 종료된 상태
- 마지막 수정 시각이 24시간 이상 경과
- 커밋되지 않은 변경사항 없음

```bash
# 자동 정리 로그 확인
claude worktree list --include-cleaned

# 정리에서 제외할 워크트리 지정
claude worktree protect <WORKTREE_PATH>

# 자동 정리 비활성화
claude settings set worktree.autoCleanup false
```

### 중요한 주의 사항

자동 정리가 편리하지만 주의할 상황도 있어요. 아직 PR을 열지 않은 브랜치 작업이 워크트리에 있다면 삭제될 수 있어요.

안전하게 쓰려면 작업 완료 후 바로 커밋 + PR 생성하는 습관이 중요해요. 또는 `worktree.protect`로 중요한 워크트리를 명시적으로 보호하세요.

```bash
# 현재 작업 중인 워크트리 보호
claude worktree protect ~/projects/myapp-feature-xyz

# 보호 해제
claude worktree unprotect ~/projects/myapp-feature-xyz
```

---

## Part 4: `/doctor` UI 개편 — `f` 키로 즉시 수정

### 새로운 `/doctor` 화면

기존 `/doctor` 명령어는 텍스트 목록으로 문제를 보여줬어요. v2.1.154부터 상태 아이콘이 추가되고, `f` 키를 누르면 감지된 문제를 Claude가 바로 수정해요.

```
/doctor 실행 결과 (새 UI)

✅ Git 설정 — 정상
✅ Node.js v22.11 — 호환
⚠️  MCP 서버 연결 끊김 — github-mcp
❌ ANTHROPIC_API_KEY — 누락
❌ .husky/pre-commit — 실행 권한 없음

[f] 자동 수정   [Enter] 닫기
```

`f`를 누르면 Claude가 환경 변수 설정 방법을 안내하거나, 권한 수정 명령을 실행해줘요.

### 팀 도입 초기 활용법

신규 팀원이 Claude Code를 처음 설치한 직후 `/doctor` + `f`를 실행하면 환경 설정 오류를 대부분 자동으로 해결할 수 있어요. 온보딩 문서에 이 단계를 추가하면 setup 관련 문의가 줄어요.

| 자동 수정 가능한 오류 | 수동 처리 필요한 오류 |
|--------------------|---------------------|
| 파일 권한 오류 | API 키 발급 |
| `.husky` 설정 | MCP 서버 인증 |
| worktree 설정 누락 | 네트워크 프록시 설정 |
| Node.js 버전 불일치 경고 | 기업 방화벽 허용 목록 |

---

## Part 5: background 세션 `/resume` 개선

### 변경 전후 비교

```bash
# 이전: --bg 로 시작한 세션은 /resume 에서 안 보임
claude --bg "PR #123 코드 리뷰 실행"
/resume  # 목록에 없음

# 이후: bg 세션도 /resume 목록에 표시
/resume
> 최근 세션
  ● bg  PR #123 코드 리뷰 (3h 21m 경과)
  ○     feature/payment 구현 (어제)
  ○     README 업데이트 (3일 전)
```

`bg` 표시가 붙은 세션이 백그라운드 세션이에요. 선택하면 해당 세션의 로그와 현재 상태를 확인할 수 있어요.

### 경과 시간 표시

백그라운드 서브에이전트 완료 알림에도 경과 시간이 추가됐어요.

```
✅ Agent completed · 2h 17m 43s
   PR #123 리뷰 완료 — 코멘트 7건 작성
```

장시간 실행 작업의 실제 소요 시간을 파악할 수 있어요. 팀 생산성 측정이나 비용 추적에 활용할 수 있어요.

---

## Part 6: 파일 쓰기 UI — 긴 한 줄 자동 줄임

미니파이드 JSON이나 CSS 번들처럼 한 줄이 매우 긴 파일을 쓸 때 터미널 화면이 여러 페이지에 걸쳐 스크롤되던 문제가 있었어요.

v2.1.153부터 긴 한 줄은 UI에서 자동으로 줄여서 표시해요. 실제 파일 내용은 변경되지 않아요.

```bash
# 쓰기 전
Writing dist/bundle.min.js (1 line, 847,293 chars)
[... 수백 줄 스크롤 ...]

# 쓰기 후 (v2.1.153)
Writing dist/bundle.min.js (1 line, 847,293 chars) [truncated in UI]
```

빌드 산출물 생성이나 JSON 데이터 파일 작업 시 화면 정리가 훨씬 깔끔해졌어요.

---

## Week 26 적용 체크리스트

- [ ] 기존 스킬 SKILL.md 설명 섹션 확장 (핵심 정보 500~800자로 재작성)
- [ ] `claude worktree list` 실행해 스테일 워크트리 현황 확인
- [ ] 중요한 진행 중 워크트리 `claude worktree protect` 처리
- [ ] `/doctor` 실행 후 환경 문제 `f` 키로 자동 수정
- [ ] 팀 온보딩 문서에 `/doctor` + `f` 단계 추가
- [ ] 백그라운드 세션 있다면 `/resume`으로 상태 확인

## 다음 단계

- [Claude Code Week 25 실전 가이드](./100-claude-code-week25-features-guide.md) — /autofix-pr, Managed Agents Webhooks 등 직전 주 업데이트
- [Git Worktree 기반 병렬 에이전트 실전 가이드](./91-git-worktree-parallel-agents-guide.md) — 자동 정리가 생긴 지금 워크트리 전략 재검토
- [AI 에이전트 스킬 시스템 가이드 2026](./92-ai-agent-skills-guide-2026.md) — 스킬 설명 확장을 최대한 활용하는 방법

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
