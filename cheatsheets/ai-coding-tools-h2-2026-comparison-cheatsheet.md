# AI 코딩 도구 2026 하반기 비교 치트시트

> 5대 터미널·에이전트 도구 요금제, 컨텍스트 크기, SWE-bench 스코어 한 페이지 정리

## 한눈에 비교

| 도구 | 개발사 | 요금 (최저) | 컨텍스트 | SWE-bench | 라이선스 |
|------|--------|-----------|---------|-----------|---------|
| Claude Code | Anthropic | Pro $20/월 | 1M (Max 이상) | ~80.8% | 독점 |
| Antigravity CLI | Google | 무료 티어 | 1M | ~76%+ | 오픈소스 |
| Codex CLI | OpenAI | Plus $20/월 | 400K~1M | ~77.3% | Apache 2.0 |
| Cursor | Anysphere | Pro $20/월 | 200K | ~51.7% | 독점 |
| Cline | Cline AI | Pro $15/월 | BYOM 의존 | BYOM 의존 | MIT |

---

## Claude Code

```
플랜           월 요금    특징
──────────────────────────────────────
Pro            $20        표준 속도 제한, Opus 4.8 포함
Max (5x)       $100       1M 컨텍스트, 레이트 리밋 5배
Max (20x)      $200       레이트 리밋 20배, 우선 큐
Team           $25/유저   공유 워크스페이스, SAML SSO
Enterprise     협의       온프레미스, 고급 감사 로그
```

**강점:** 가장 높은 SWE-bench, Hooks 자동화, 멀티에이전트 팀, Dynamic Workflows  
**주의:** 무료 티어 없음, 고사용량이면 비용 상승

---

## Antigravity CLI (Google)

```
플랜           월 요금    특징
──────────────────────────────────────
무료 티어       $0         Gemini 3 Flash 기반, 제한 호출
Developer      $19        Gemini 3 Pro, 멀티에이전트
Enterprise     협의        Vertex AI 연동, 사내 배포
```

**강점:** Gemini CLI 후속, 동적 서브에이전트 병렬 실행, Google 생태계 연동  
**주의:** 2026 H2 기준 일부 기능 베타, enterprise 기능 미성숙

---

## Codex CLI (OpenAI)

```
플랜           월 요금    특징
──────────────────────────────────────
ChatGPT Plus   $20        GPT-5.3-Codex, 400K 컨텍스트
ChatGPT Pro    $200       GPT-5.4 포함, 1M 컨텍스트 (실험)
오픈소스       무료        자체 OpenAI API 키 사용 가능
```

**강점:** Apache 2.0 오픈소스, 클라우드 샌드박스, /goal 자율 루프  
**주의:** GPT 모델 품질 천장이 Claude Opus 4.8 대비 낮음

---

## Cursor

```
플랜           월 요금    특징
──────────────────────────────────────
무료           $0         월 2,000 완성, 제한 채팅
Pro            $20        무제한 완성, Agent 모드
Pro+           $60        고급 모델 우선 접근
Team           $40/유저   공유 룰, Admin 패널
Enterprise     협의       SSO, 데이터 격리
```

**강점:** IDE-native UX, .cursorrules 에코시스템, Background Agents  
**주의:** SWE-bench 상대적 낮음, 터미널 에이전트보다 IDE에 최적화

---

## Cline (VS Code 에이전트)

```
플랜           월 요금    특징
──────────────────────────────────────
무료           $0         자체 API 키 BYOM
Pro            $15        관리형 API, 우선 지원
Enterprise     협의       팀 정책, 사내 모델 연동
```

**강점:** MIT 오픈소스, 모든 LLM 연동 가능(BYOM), Plan/Act 분리 모드  
**주의:** 성능은 연결된 모델에 전적으로 의존

---

## 작업 유형별 선택 기준

| 상황 | 권장 도구 | 이유 |
|------|----------|------|
| 복잡한 리팩토링 | Claude Code Max | 1M 컨텍스트 + Opus 4.8 추론 |
| IDE 중심 개발 | Cursor Pro | Background Agents + 풍부한 UX |
| 예산 절약 | Antigravity CLI / Cline Free | 무료 티어 또는 저렴한 BYOM |
| 오픈소스 기여 | Codex CLI | Apache 2.0, 로컬 실행 |
| AWS/GCP 인프라 | Antigravity CLI | Google 생태계 연동 강점 |
| 멀티 LLM 실험 | Cline | 모델 교체 자유도 최고 |
| 팀 협업 자동화 | Claude Code Team | Channels + Managed Agents |

---

## 컨텍스트 크기 체감 가이드

```
64K 토큰  → 파일 ~5개, 함수 단위 작업
200K 토큰 → 중소 레포 전체 파악 가능
400K 토큰 → 대형 서비스 핵심 경로 일괄 수정
1M 토큰   → 모노레포 전체, 대규모 마이그레이션
```

---

## 개발자 비용 스택 예시

| 월 예산 | 추천 조합 | 적합 대상 |
|--------|----------|----------|
| $0 | Antigravity CLI + Cline (무료) | 입문자, 사이드 프로젝트 |
| $20 | Claude Code Pro | 솔로 개발자, 보통 사용량 |
| $40 | Claude Code Pro + Cursor Free | 풀스택, IDE + 터미널 병행 |
| $120 | Claude Code Max + Cursor Pro | 고강도 코딩, 팀 리드 |
| $220+ | Claude Code Max 20x + Cursor Pro | 에이전트 팀 풀 운영 |

---

**관련 가이드:** [claude-code/playbooks](../claude-code/playbooks/) · [AI 코딩 도구 2026 상반기 총정리](ai-coding-tools-h1-2026-comparison-cheatsheet.md)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
