# Codex × ChatGPT 통합 + GitHub Copilot Max — 2026년 6월 AI 코딩 지형 변화 가이드

> 2026년 6월, AI 코딩 도구 시장에 가장 큰 변화가 한꺼번에 터졌다. OpenAI는 Codex를 ChatGPT 비즈니스 플러그인으로 풀었고, GitHub는 Copilot Max를 출시했으며, Devin은 데스크탑 앱에서 멀티에이전트를 지원하기 시작했다.

## 소요 시간

30분 (읽기 + 기존 워크플로우 재검토)

## 사전 준비

- Claude Code 또는 Cursor 현재 사용 중
- OpenAI, GitHub Copilot 계정 (선택)
- 현재 AI 코딩 도구 월 지출액 파악

---

## 1. OpenAI Codex × ChatGPT 통합 — 뭐가 달라졌나

### 1-1. 팀 통합의 의미

2026년 5월 16일, OpenAI는 ChatGPT, Codex, 개발자 API 팀을 Greg Brockman 주도로 단일 팀으로 합쳤다. 표면적으로는 조직 개편이지만, 실질적 변화는 Codex가 터미널 전용 도구에서 벗어나 ChatGPT 사용자 전체에게 노출된다는 점이다.

### 1-2. 6월 2일: 비즈니스 플러그인 6개 출시

2026년 6월 2일 "Intelligence at Work" 발표에서 OpenAI는 Codex를 ChatGPT 비즈니스/엔터프라이즈 사용자에게 6가지 역할별 플러그인으로 제공한다고 밝혔다.

| 플러그인 | 역할 | 주요 기능 |
|---------|------|-----------|
| `@Codex` | 개발자 | 코드 생성, 디버깅, PR 자동화 |
| `@Sites` | 프론트엔드 | 웹 앱 생성 + 호스팅 (ChatGPT 인프라) |
| `@Operator` | 비개발자 | 브라우저 조작, 폼 자동 입력 |
| `@Research` | 분석가 | 웹 검색 + 문서 요약 |
| `@Scheduler` | PM | 작업 예약, 비동기 실행 |
| `@Annotations` | QA | 코드/문서 인라인 코멘트 |

**개발자에게 실질적으로 중요한 것은 `@Codex`와 `@Sites`다.**

### 1-3. Codex Sites — 프롬프트 한 줄로 웹 앱 배포

`@Sites` 플러그인은 ChatGPT 대화에서 바로 웹 앱을 빌드하고 OpenAI 인프라에 호스팅한다.

```
사용자: @Sites 할 일 관리 앱 만들어줘. 로그인 없이 로컬스토리지 기반으로.

ChatGPT: [빌드 중...]
앱이 준비됐습니다: https://sites.chatgpt.com/todos-abc123
팀원들에게 링크를 공유하거나 워크스페이스 내 프로젝트로 저장하세요.
```

**현재 제약:**
- ChatGPT Business / Enterprise 전용 (Pro, Plus, Free 제외)
- 미리보기(preview) 단계 — 커스텀 도메인 없음
- 환경변수와 시크릿은 Sites 사이드바에서 관리

**실용 시나리오:**
- 내부 데모 프로토타입 빠르게 공유
- 기획자/디자이너가 기능 확인용 화면 즉시 생성
- 개발자가 API 명세 시각화 도구 공유

---

## 2. GitHub Copilot Max — $100/월의 새 선택지

### 2-1. 플랜 비교 (2026년 6월 기준)

| 플랜 | 가격 | 크레딧 | 특이사항 |
|------|------|--------|---------|
| Free | $0 | 2,000 완성/월 | 무제한 인라인 완성 불포함 |
| Pro | $10/월 | 1,500 크레딧 ($15 가치) | 코드 리뷰 에이전트 포함 |
| Pro+ | $39/월 | 7,000 크레딧 ($70 가치) | Opus 모델 접근 |
| **Max** | **$100/월** | **20,000 크레딧 ($200 가치)** | **신모델 우선 접근** |

> **주의:** 2026년 4월 20일부터 신규 가입이 일시 중단됨. 기존 플랜 업그레이드는 가능.

### 2-2. Copilot Max의 실제 가치

**크레딧 소비 기준 (추정):**

```
Claude Sonnet 4급 요청 1회 ≈ 1 크레딧
Opus 4급 요청 1회 ≈ 5~10 크레딧
코드 리뷰 에이전트 PR 1개 ≈ 20~50 크레딧
백그라운드 에이전트 작업 1회 ≈ 50~200 크레딧
```

**Max(20,000 크레딧)로 할 수 있는 것:**
- 일평균 60~70회 Opus급 요청 + 코드 완성 무제한
- 월 100~400개 PR 자동 리뷰
- 백그라운드 에이전트 월 100~400회 실행

**결론:** 헤비유저(하루 4시간 이상 AI 코딩)에게 Claude Code Max $100와 직접 경쟁한다. 둘 다 가입하기보다 워크플로우에 맞게 선택해야 한다.

### 2-3. Copilot Max vs Claude Code Max — 선택 기준

| 기준 | Copilot Max | Claude Code Max |
|------|-------------|-----------------|
| 주 인터페이스 | VS Code / IDE | 터미널 |
| 멀티에이전트 | Bug Bot (백그라운드) | claude agents (병렬) |
| 컨텍스트 크기 | 비공개 | 200K 토큰 |
| 주요 강점 | IDE 통합, PR 리뷰 자동화 | 자율 실행, Hooks, 스킬 |
| 적합한 팀 | VS Code 중심 팀 | 터미널 중심 개발자 |

---

## 3. Devin Desktop — 멀티에이전트 동시 실행

### 3-1. Devin Desktop의 변화

Devin 2.0 이후 Desktop 앱이 동일 프로젝트에 여러 에이전트를 동시 실행하는 기능을 추가했다.

```
프로젝트: my-saas-app
├── Devin Agent 1: "로그인 페이지 리팩토링"   ← 진행 중
├── Devin Agent 2: "결제 API 연동 버그 수정"  ← 진행 중
└── Devin Agent 3: "E2E 테스트 추가"          ← 대기 중
```

**인간 개발자의 역할:**
- 태스크 설명 작성 + 우선순위 지정
- 중간 체크포인트에서 방향 승인
- 완성된 PR 리뷰

### 3-2. Devin 플랜 (2026년 6월)

| 플랜 | 가격 | 에이전트 실행 시간 |
|------|------|-----------------|
| Starter | $20/월 | 10 ACUs |
| Pro | $100/월 | 50 ACUs |
| Max | $200/월 | 120 ACUs (멀티에이전트) |

> ACU(Agent Compute Unit): 에이전트가 1분간 실행되는 단위. 복잡한 태스크는 30~60 ACU 소비.

---

## 4. 2026년 6월 기준 도구 선택 전략

### 4-1. 역할별 조합 추천

**개인 개발자 / 1인 사이드 프로젝트:**
```
Claude Code Pro ($20) + Antigravity CLI (무료)
→ 터미널 에이전트 + 대규모 컨텍스트로 충분
```

**팀 단위 (3~10인):**
```
Claude Code Pro ($20) + GitHub Copilot Pro ($10)
→ 개인 딥워크는 Claude Code, PR 리뷰 자동화는 Copilot
월 $30으로 두 도구의 핵심 기능 활용
```

**헤비유저 / 기업 개발자:**
```
Claude Code Max ($100) 또는 Copilot Max ($100) — 둘 중 하나
→ 두 개 동시 구독은 비용 대비 효율 낮음
→ 주 IDE가 터미널이면 Claude Code, VS Code면 Copilot Max
```

**AI 중심 자동화 팀:**
```
Claude Code Max ($100) + Devin Pro/Max ($100~200)
→ 동기 코딩은 Claude Code, 비동기 장기 태스크는 Devin
```

### 4-2. Codex ChatGPT 플러그인 활용 시점

현재 Codex의 ChatGPT 통합은 **비개발자와 협업하는 개발자**에게 가장 유용하다.

```
기획자: @Codex 이 API 스펙으로 목업 화면 만들어줘
→ @Sites로 즉시 배포 → 개발자에게 링크 공유

QA: @Annotations 이 코드에서 엣지 케이스 찾아줘
→ 인라인 코멘트로 티켓 없이 직접 피드백

PM: @Scheduler 매주 월요일 오전 9시에 기술 부채 리포트 보내줘
→ 비동기 자동화
```

---

## 5. 실전 체크리스트

### 기존 워크플로우 점검

- [ ] 현재 AI 코딩 도구 월 비용 합산
- [ ] 주 인터페이스 확인 (터미널 vs IDE vs 브라우저)
- [ ] Claude Code Max vs Copilot Max 중 하나로 통합 검토
- [ ] Codex ChatGPT 플러그인 — 팀 내 비개발자 협업 시나리오 파악
- [ ] Devin Desktop — 비동기 작업 목록 중 에이전트 위임 가능한 것 선별

### 6월 신규 기능 온보딩

```bash
# Claude Code 최신 버전 확인
claude --version

# Antigravity CLI (전 Gemini CLI 대체) — 6월 18일 이전 마이그레이션
# guides/130-gemini-cli-to-antigravity-migration-guide.md 참고

# GitHub Copilot 플랜 현황 확인
gh api /user/copilot_business_organization_settings 2>/dev/null || \
gh api /user -q '.plan.name'
```

---

## 6. 앞으로 6개월 전망

2026년 하반기에 주목할 변화:

1. **Codex Sites GA** — 현재 Business/Enterprise 미리보기에서 일반 출시로 전환 예상
2. **Copilot Max 신규 가입 재개** — 4월부터 일시 중단된 신규 가입이 재개될 가능성
3. **Claude Code x Copilot 연동** — Claude Code를 Copilot의 서드파티 에이전트로 사용하는 공식 통합 예정
4. **Devin 멀티에이전트 확대** — 현재 Max 플랜 전용인 동시 에이전트가 Pro로 확대될 것
5. **AI 코딩 도구 통합 플랫폼화** — 단일 구독으로 여러 에이전트를 통합 관리하는 흐름 강화

---

## 다음 단계

→ [AI 코딩 도구 2026 하반기 비교 치트시트](../cheatsheets/ai-coding-tools-h2-2026-comparison-cheatsheet.md)
→ [Antigravity CLI 마이그레이션 가이드](./130-gemini-cli-to-antigravity-migration-guide.md)
→ [AI 코딩 에이전트 비용 거버넌스 플레이북](../claude-code/playbooks/79-ai-agent-cost-governance-playbook.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
