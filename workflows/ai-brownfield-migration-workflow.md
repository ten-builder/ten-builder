# AI 기반 브라운필드 마이그레이션 워크플로우 — 레거시에서 현대 아키텍처로

> 수년된 레거시 시스템을 AI 에이전트로 단계적으로 현대화하는 전략 — 위험 분류, 점진적 교체, 호환성 레이어 생성 자동화

## 개요

2026년 현재, 전체 소프트웨어 엔지니어링 팀의 상당수가 레거시 마이그레이션 작업에 시간을 쏟고 있습니다. 전면 재작성(Big Bang Rewrite)은 너무 위험하고, 그렇다고 아무것도 안 할 수는 없는 상황에서 **점진적 교체 전략**이 현실적 대안으로 자리잡았습니다.

AI 에이전트는 이 과정에서 세 가지 역할을 합니다:

1. **분석자** — 레거시 코드의 의존성과 위험 구역을 파악
2. **생성자** — 호환성 레이어와 새 모듈을 만드는 역할
3. **검증자** — 교체 전후 동작 일치 여부 테스트

이 워크플로우는 Strangler Fig 패턴을 기반으로, AI 에이전트가 각 단계를 보조하는 실전 방법을 다룹니다.

## 사전 준비

- Claude Code (또는 Codex CLI) 설치
- 레거시 레포에 대한 읽기/쓰기 권한
- 기존 테스트 스위트 (없어도 무방하지만 있으면 훨씬 안전)
- Git 브랜치 전략 결정 (trunk-based 권장)

## Step 1: 레거시 코드 지도 그리기

가장 먼저 할 일은 "뭘 건드리면 위험한가"를 파악하는 것입니다.

```bash
# Claude Code로 의존성 분석 실행
claude "이 레포의 모든 모듈 간 의존성을 분석하고,
변경 빈도(git log 기반)와 다른 모듈에서 참조되는 횟수를
조합한 위험 점수를 계산해서 표로 정리해줘.
위험 점수 = (의존 모듈 수 × 2) + (최근 6개월 커밋 수)"
```

AI가 생성하는 위험 분류표 예시:

| 모듈 | 의존 수 | 커밋 수 | 위험 점수 | 마이그레이션 순서 |
|------|--------|--------|----------|-----------------|
| `user-auth` | 12 | 3 | 27 | 마지막 |
| `email-sender` | 2 | 8 | 12 | 중간 |
| `report-generator` | 1 | 2 | 4 | 먼저 |

**원칙:** 위험 점수가 낮은 모듈부터 시작합니다.

## Step 2: 교체 대상 첫 번째 후보 선정

점수가 가장 낮고 비즈니스 가치가 있는 모듈을 첫 번째 교체 대상으로 선택합니다.

```bash
# 선택된 모듈의 현재 동작을 명세로 추출
claude "src/report-generator.js 파일을 분석해서
이 모듈이 현재 어떤 입력을 받아 어떤 출력을 내는지
행동 명세(behavioral spec)를 마크다운으로 작성해줘.
외부에서 관찰 가능한 동작만 기록하고,
내부 구현 세부사항은 제외해."
```

이 명세가 새 구현의 계약서(Contract)가 됩니다.

## Step 3: 호환성 레이어(Facade) 만들기

Strangler Fig의 핵심은 기존 시스템을 당장 건드리지 않고 **앞단에 파사드를 두는 것**입니다.

```bash
# AI로 파사드 생성
claude "src/report-generator.js의 공개 인터페이스를 분석해서
동일한 시그니처를 가진 TypeScript 파사드를 생성해줘.
파사드는 기본적으로 기존 구현을 그대로 호출하되,
feature flag(USE_NEW_REPORT_GENERATOR)가 활성화된 경우에만
새 구현을 호출하도록 라우팅 로직을 포함해."
```

생성된 파사드 예시:

```typescript
// src/facades/report-generator.facade.ts
export class ReportGeneratorFacade {
  private legacy = new LegacyReportGenerator();
  private modern = new ModernReportGenerator();

  async generate(params: ReportParams): Promise<Report> {
    if (process.env.USE_NEW_REPORT_GENERATOR === 'true') {
      return this.modern.generate(params);
    }
    return this.legacy.generate(params);
  }
}
```

## Step 4: 새 구현 작성 + 동작 일치 검증

```bash
# 새 구현 생성
claude "Step 2에서 작성한 행동 명세를 기반으로
TypeScript로 ReportGenerator를 새로 구현해줘.
레거시 코드의 구현 방식에 의존하지 말고
명세의 입출력 계약만 만족시키면 돼."

# 동작 비교 테스트 생성
claude "두 구현이 동일한 입력에 대해 동일한 출력을 내는지
검증하는 비교 테스트를 작성해줘.
기존 프로덕션 로그에서 실제 입력 샘플 20개를 추출하고,
두 구현의 출력을 JSON 깊이 비교하는 방식으로."
```

## Step 5: 점진적 트래픽 전환

파사드가 준비되면 feature flag로 트래픽을 서서히 전환합니다.

| 단계 | 설정 | 검증 기간 |
|------|------|---------|
| 카나리 | 1% → 신규 | 24시간 |
| 검증 | 10% → 신규 | 48시간 |
| 확장 | 50% → 신규 | 24시간 |
| 완료 | 100% → 신규 | 72시간 |

```bash
# 에러율 모니터링 자동화
claude "두 구현의 에러율과 응답 시간을 비교하는
모니터링 스크립트를 작성해줘.
신규 구현의 에러율이 레거시 대비 1.5배 이상이면
자동으로 feature flag를 false로 되돌려."
```

## Step 6: 레거시 코드 제거

100% 전환 후 안정화 기간이 지나면 레거시를 정리합니다.

```bash
# 레거시 코드 안전 제거
claude "USE_NEW_REPORT_GENERATOR feature flag 분기를 제거하고
파사드에서 직접 새 구현을 호출하도록 리팩터링해줘.
레거시 클래스와 관련 테스트도 함께 삭제하고,
변경 사항을 커밋 단위로 분리해서 PR 설명에 정리해줘."
```

## 반복 적용

한 모듈이 완료되면 위험 점수 다음 순위로 이동합니다. 각 사이클의 교훈을 CLAUDE.md에 누적하면 AI가 다음 모듈을 더 잘 처리합니다.

```bash
# CLAUDE.md에 교훈 추가
claude "이번 report-generator 마이그레이션에서 배운 점과
다음 모듈에 적용할 주의사항을 CLAUDE.md에 추가해줘."
```

## 흔한 실수 & 해결

| 실수 | 해결 |
|------|------|
| 파사드 없이 바로 교체 시도 | 항상 파사드를 먼저 — 롤백 경로 확보 |
| 의존성 많은 모듈부터 시작 | 위험 점수 낮은 리프 모듈부터 |
| 동작 비교 테스트 생략 | AI가 놓치는 엣지 케이스를 비교 테스트가 잡음 |
| 한 번에 여러 모듈 교체 | 한 번에 하나씩 — 문제 추적 가능 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
