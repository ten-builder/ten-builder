# MCP 컨텍스트 최적화 치트시트

> MCP 서버가 AI 에이전트의 컨텍스트 윈도우를 잡아먹는 문제를 해결하는 실전 패턴 — 한 페이지 요약

## 문제: MCP 도구가 많을수록 컨텍스트가 줄어든다

MCP 서버를 여러 개 연결하면 각 도구의 스키마(이름, 설명, 파라미터)가 시스템 프롬프트에 포함돼요.
도구가 20개만 넘어도 수천 토큰이 사라지고, 정작 코드 분석에 쓸 컨텍스트가 부족해집니다.

| 도구 수 | 예상 토큰 소비 | 남은 컨텍스트 비율 |
|---------|--------------|-----------------|
| 5개 이하 | ~500 토큰 | 99%+ |
| 10~20개 | ~2,000 토큰 | 98% |
| 30~50개 | ~5,000 토큰 | 95% |
| 100개+ | ~15,000 토큰 | 90% 이하 |

## 패턴 1: 도구 세그멘테이션

**모든 MCP 서버를 한꺼번에 켜지 말고, 도메인별로 나눠서 필요한 것만 활성화하세요.**

```json
// .claude/settings.json - 프로젝트별 MCP 설정
{
  "mcpServers": {
    "db-tools": {
      "command": "mcp-server-postgres",
      "args": ["--connection", "postgresql://..."]
    }
    // git-tools, deploy-tools 등은 별도 프로필로 분리
  }
}
```

| 작업 유형 | 활성화할 MCP 서버 | 비활성화 |
|----------|-----------------|---------|
| DB 스키마 작업 | postgres, prisma | git, deploy, monitoring |
| 프론트엔드 개발 | browser, figma | db, deploy |
| 배포/인프라 | deploy, aws | db, browser, figma |
| 코드 리뷰 | git, github | db, deploy, browser |

## 패턴 2: 도구 마스킹 (Tool Masking)

**동적 로딩 대신, 불필요한 도구를 마스킹해서 스키마 전송 자체를 막는 방식이에요.**

```yaml
# 도구 마스킹 설정 예시
tool_visibility:
  default: hidden          # 기본은 숨김
  active:
    - file_read            # 항상 활성
    - file_write           # 항상 활성
    - search               # 항상 활성
  on_demand:
    - database_query       # "DB" 키워드 감지 시 활성
    - deploy_trigger       # "배포" 키워드 감지 시 활성
```

**장점:** 서버 재시작 없이 도구 노출 범위를 제어할 수 있어요.

## 패턴 3: 응답 압축

**MCP 도구의 응답이 길면 컨텍스트를 빠르게 소모합니다. 서버 측에서 압축하세요.**

```typescript
// MCP 서버 구현 시 응답 제한
const handler = async (request: ToolCallRequest) => {
  const result = await queryDatabase(request.params);

  // 전체 결과 대신 요약만 반환
  return {
    summary: `${result.rows.length}건 조회`,
    columns: result.columns,
    sample: result.rows.slice(0, 5),  // 상위 5건만
    totalRows: result.rows.length
  };
};
```

| 응답 타입 | 압축 전 | 압축 후 | 절약 |
|----------|--------|--------|------|
| DB 쿼리 결과 100행 | ~8,000 토큰 | ~1,500 토큰 | 81% |
| 파일 트리 | ~3,000 토큰 | ~800 토큰 | 73% |
| API 응답 | ~5,000 토큰 | ~1,200 토큰 | 76% |

## 패턴 4: 레이지 로딩 (Just-in-Time)

**세션 시작 시 모든 도구를 로드하지 말고, 사용자 요청에 따라 필요한 도구만 로드하세요.**

```bash
# Phase 1: 기본 도구만 로드
claude --mcp-config minimal.json

# Phase 2: 필요 시 추가 서버 연결
# "DB 작업해줘" → postgres MCP 서버 추가 연결
```

### 단계별 로딩 전략

```
세션 시작 → 기본 도구 (file, search) 로드
         → 사용자: "DB 스키마 수정해줘"
         → postgres MCP 서버 활성화
         → 작업 완료
         → postgres 비활성화, 컨텍스트 회수
```

## 패턴 5: 고수준 도구 설계

**저수준 도구 10개보다 고수준 도구 1개가 컨텍스트를 아껴요.**

```
// 저수준 (토큰 소비 높음)
도구 10개: list_tables, describe_table, query, insert,
          update, delete, create_index, alter_table,
          backup, restore

// 고수준 (토큰 소비 낮음)
도구 2개: database_operation(action, params)
          database_admin(action, params)
```

| 방식 | 도구 수 | 스키마 토큰 | 유연성 |
|------|--------|-----------|--------|
| 저수준 개별 도구 | 10개 | ~2,500 | 높음 |
| 고수준 통합 도구 | 2개 | ~600 | 중간 |
| 하이브리드 | 4개 | ~1,200 | 높음 |

## 실전 체크리스트

### MCP 서버 추가 전

- [ ] 현재 활성 도구 수 확인 (30개 넘으면 분리 고려)
- [ ] 새 서버의 도구가 기존 도구와 겹치는지 확인
- [ ] 응답 사이즈 예상 — 대량 데이터 반환 도구는 압축 적용

### 프로젝트 설정 시

- [ ] 작업 유형별 MCP 프로필 분리 (dev, review, deploy)
- [ ] 기본 활성 도구는 5개 이하로 유지
- [ ] 도구 설명(description)을 간결하게 작성 (50자 이내)
- [ ] 불필요한 파라미터 설명 제거

### 성능 모니터링

- [ ] 세션당 평균 도구 호출 횟수 추적
- [ ] 사용하지 않는 MCP 서버 정기 정리 (월 1회)
- [ ] 도구 응답 사이즈 로깅으로 이상치 감지

## 흔한 실수와 해결

| 실수 | 문제점 | 해결 |
|------|-------|------|
| MCP 서버 10개 동시 연결 | 도구 스키마만 10K+ 토큰 | 프로필 분리, 3개 이하 활성 |
| DB 전체 테이블 반환 | 응답 1회에 5K 토큰 | 샘플 + 카운트만 반환 |
| 도구 설명에 예시 3개씩 | 스키마 비대화 | 설명 1줄, 예시는 문서로 분리 |
| 모든 도구 항상 활성 | 불필요한 토큰 소비 | 마스킹 또는 레이지 로딩 |
| 커스텀 도구에 중복 기능 | 같은 기능 다른 이름 | 통합 도구로 리팩토링 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
