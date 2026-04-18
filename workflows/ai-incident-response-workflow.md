# AI 에이전트 기반 인시던트 대응 워크플로우

> 프로덕션 장애가 터졌을 때 AI 에이전트를 보조로 활용해 원인을 빠르게 파악하고 핫픽스를 배포하는 실전 워크플로우

## 개요

프로덕션 인시던트에서 가장 중요한 것은 속도입니다. 로그를 찾고, 패턴을 파악하고, 범인 커밋을 추적하는 데 걸리는 시간을 AI 에이전트로 절반 이하로 줄일 수 있어요.

57%의 조직이 이미 프로덕션에서 에이전트를 운영하고 있지만, 대부분 인시던트 대응 플레이북은 아직 준비되지 않은 상태입니다. 이 워크플로우는 그 공백을 메우는 실전 가이드예요.

**이 워크플로우로 해결하는 문제:**
- 장애 원인 파악에 30분 이상 소요되는 상황
- 로그와 배포 이력을 수동으로 교차 검증하는 비효율
- 핫픽스 작성 후 테스트 없이 배포했다가 2차 장애 발생

## 사전 준비

- Claude Code 또는 Gemini CLI 설치
- PagerDuty/Slack 알림 연동
- 로그 접근 권한 (CloudWatch, Datadog, Grafana 등)
- `gh` CLI 설치 및 인증

## 워크플로우 개요

```
알림 수신 → P1 판단 → AI 초기 진단 → 원인 격리 → 핫픽스 → 배포 → 회고 문서화
```

---

## Phase 1: 알림 수신 및 초기 진단 (0~5분)

### 1-1. 인시던트 컨텍스트 수집

장애 알림을 받으면 AI에게 첫 번째 질문을 던지기 전에, 가능한 한 많은 컨텍스트를 모으세요.

```bash
# 최근 배포 이력 확인
gh run list --repo org/repo --limit 10 --json conclusion,displayTitle,createdAt,headBranch

# 최근 1시간 에러 로그 추출 (CloudWatch 예시)
aws logs filter-log-events \
  --log-group-name "/aws/lambda/api-prod" \
  --start-time $(date -v-1H +%s000) \
  --filter-pattern "ERROR" \
  --limit 50 \
  --query 'events[*].message' \
  --output text > /tmp/recent-errors.txt
```

### 1-2. AI 초기 진단 요청

```bash
# 로그를 AI에게 분석 요청
cat /tmp/recent-errors.txt | claude --print \
  "이 에러 로그를 분석해서 다음을 알려줘:
   1. 에러 패턴 (어떤 에러가 몇 번 반복되는지)
   2. 가능한 근본 원인 3가지 (가능성 순으로)
   3. 즉시 확인해야 할 파일/함수
   4. 임시 완화 조치 가능한지 여부"
```

**AI 진단 결과 예시:**
```
에러 패턴:
- DatabaseConnectionError: 147회 (전체 에러의 89%)
- TimeoutError: 12회 (주로 payment 서비스)
- NullPointerException: 5회 (user-session.ts:142)

가능한 원인:
1. DB 커넥션 풀 고갈 (가능성 높음 — 배포 직후 급증)
2. 새 배포의 쿼리 최적화 문제 (가능성 중간)
3. 인프라 수준 DB 과부하 (가능성 낮음)

즉시 확인: src/db/connection-pool.ts, 오늘 배포된 PR #234
```

---

## Phase 2: 원인 격리 (5~15분)

### 2-1. 범인 커밋 추적

```bash
# 최근 배포된 커밋 목록
git log --oneline -20 origin/main

# AI에게 에러와 관련된 커밋 분석 요청
git diff HEAD~5..HEAD -- src/db/ | claude --print \
  "이 diff에서 DatabaseConnectionError를 유발할 수 있는 변경사항을 찾아줘.
   특히 커넥션 풀 설정, 트랜잭션 처리, 타임아웃 값 변경에 집중해서."
```

### 2-2. 빠른 코드 원인 분석

```bash
# 의심 파일 집중 분석
cat src/db/connection-pool.ts | claude --print \
  "이 파일에서 고부하 시 커넥션 풀이 고갈될 수 있는 패턴을 찾아줘.
   프로덕션 에러 패턴: 초당 요청 500+, 평균 쿼리 시간 2.3초"
```

**분석 결과 활용 기준:**

| 확인 항목 | 정상 | 위험 신호 |
|-----------|------|-----------|
| 커넥션 풀 사이즈 | 요청량 × 평균 처리 시간 여유 있음 | 풀 사이즈 < 동시 요청 수 |
| 트랜잭션 범위 | 좁고 명확함 | 여러 서비스 묶음 |
| 타임아웃 설정 | 서비스별 적정 값 | 전역 기본값 그대로 |
| 커넥션 반환 | `finally` 블록에서 명시적 반환 | 예외 시 반환 누락 |

### 2-3. 임시 완화 조치 결정

원인 파악 전에도 서비스를 살릴 수 있는 조치를 먼저 실행하세요:

```bash
# 옵션 1: 이전 버전으로 롤백
gh run list --workflow=deploy.yml --limit 5
# 이전 성공 배포 ID로 재실행

# 옵션 2: 피처 플래그로 문제 기능 비활성화
# (LaunchDarkly, Unleash 등 사용 시)

# 옵션 3: 서버 증설로 시간 벌기 (쿠버네티스)
kubectl scale deployment api-prod --replicas=10
```

---

## Phase 3: 핫픽스 작성 (15~30분)

### 3-1. AI와 함께 핫픽스 작성

```bash
# 원인 파악 후 핫픽스 요청
cat src/db/connection-pool.ts | claude --print \
  "이 파일의 문제를 수정해줘.
   
   확인된 문제:
   - maxConnections: 10 (너무 낮음, 현재 초당 150 요청)
   - 트랜잭션 finally 블록에서 connection.release() 누락 (line 89)
   
   수정 기준:
   - 최소 변경 원칙 (핫픽스이므로 리팩토링 금지)
   - 기존 테스트 통과 유지
   - maxConnections는 환경변수로 설정 가능하게"
```

### 3-2. 핫픽스 검증

AI가 작성한 코드는 반드시 검증하세요:

```bash
# 테스트 실행
npm test -- --testPathPattern=connection-pool

# 로컬 부하 테스트 (간단하게)
npx autocannon -c 50 -d 10 http://localhost:3000/api/health

# AI에게 테스트 케이스 추가 요청
claude --print "방금 수정한 connection-pool.ts의 핫픽스를 검증하는
                단위 테스트를 3개 작성해줘. 특히:
                1. 커넥션 풀 고갈 시나리오
                2. 트랜잭션 실패 시 커넥션 반환 확인
                3. maxConnections 환경변수 적용 확인"
```

### 3-3. 핫픽스 PR 생성

```bash
# 핫픽스 브랜치 생성
git checkout -b hotfix/db-connection-pool-exhaustion

# 변경사항 커밋
git add src/db/connection-pool.ts
git commit -m "fix: resolve DB connection pool exhaustion on high load

- increase maxConnections from 10 to env.DB_POOL_SIZE (default: 50)
- fix missing connection.release() in transaction finally block (line 89)
- add DB_POOL_SIZE to environment variable documentation

Root cause: PR #234 changed query pattern without adjusting pool size.
Incident: 2026-04-19 00:12 KST — DatabaseConnectionError spike"

# PR 생성 (main으로 직접 머지 요청)
gh pr create \
  --title "fix: DB connection pool exhaustion hotfix" \
  --body "## 인시던트 요약
  
**발생 시각:** 2026-04-19 00:12 KST  
**영향:** API 에러율 89% (DatabaseConnectionError)  
**원인:** PR #234 이후 커넥션 풀 고갈

## 수정 내용

- \`maxConnections\`: 10 → 환경변수 \`DB_POOL_SIZE\` (기본값 50)
- \`connection.release()\` 누락 수정 (line 89, finally 블록)

## 검증

- [ ] 단위 테스트 통과
- [ ] 로컬 부하 테스트 50 동시 요청 정상
- [ ] 스테이징 배포 에러율 0%

## 롤백 방법

\`\`\`bash
git revert HEAD && git push origin main
\`\`\`" \
  --base main
```

---

## Phase 4: 배포 및 모니터링 (30~60분)

### 4-1. 단계적 배포

핫픽스는 단계적으로 배포하세요:

```bash
# 1단계: 스테이징 배포 및 10분 관찰
gh workflow run deploy.yml -f environment=staging -f branch=hotfix/db-connection-pool-exhaustion

# 2단계: 프로덕션 1개 인스턴스 카나리 배포
# (ArgoCD, Flux 등 사용 시 웨이트 조정)

# 3단계: 에러율 확인 후 전체 배포
```

### 4-2. AI 기반 배포 후 모니터링

```bash
# 배포 5분 후 에러 패턴 재확인
aws logs filter-log-events \
  --log-group-name "/aws/lambda/api-prod" \
  --start-time $(date -v-10M +%s000) \
  --filter-pattern "ERROR" \
  --output text > /tmp/post-deploy-errors.txt

cat /tmp/post-deploy-errors.txt | claude --print \
  "핫픽스 배포 후 에러 로그야. 
   - DatabaseConnectionError가 사라졌는지 확인
   - 새로운 에러 패턴이 발생했는지 확인
   - 정상 복구 여부 판단해줘"
```

**모니터링 체크리스트:**

- [ ] 에러율 정상 범위 복귀 (< 0.1%)
- [ ] 응답 시간 정상화
- [ ] DB 커넥션 풀 사용률 안정
- [ ] 새로운 에러 패턴 없음

---

## Phase 5: 인시던트 회고 문서화

### 5-1. AI로 회고 초안 생성

```bash
# 인시던트 타임라인을 AI에게 전달하여 회고 문서 초안 작성
claude --print "다음 인시던트 타임라인으로 회고 문서를 작성해줘.

타임라인:
- 00:12 KST: PagerDuty 알림 수신 (에러율 89%)
- 00:15: AI 로그 분석 → 커넥션 풀 고갈 가능성 파악
- 00:22: PR #234 범인 커밋 확인
- 00:35: 핫픽스 코드 작성 완료
- 00:42: 스테이징 배포 및 검증
- 00:51: 프로덕션 배포 완료
- 01:05: 에러율 0.03%로 정상화

포함 내용:
- 5 whys 분석
- 타임라인
- 재발 방지 액션 아이템 3개"
```

---

## 문제 해결

| 상황 | 대응 |
|------|------|
| AI 진단이 틀렸을 때 | 로그를 더 구체적으로 제공, 에러 발생 직전 컨텍스트 추가 |
| 핫픽스 테스트 실패 | AI에게 실패 로그 다시 전달 → 추가 수정 요청 |
| 배포 후 새 에러 발생 | 즉시 롤백 후 원인 재분석 |
| 원인 파악 30분 초과 | 일단 롤백으로 서비스 복구 → 충분히 분석 후 재시도 |
| AI 응답이 애매할 때 | "가장 가능성 높은 원인 1개만 말해줘" 로 범위 좁히기 |

## 핵심 원칙

1. **먼저 서비스 복구, 원인 파악은 그 다음** — 롤백이 분석보다 먼저
2. **AI 진단은 출발점** — AI가 틀릴 수 있으므로 반드시 직접 검증
3. **최소 변경 핫픽스** — 인시던트 대응 시 리팩토링은 금지
4. **배포는 단계적으로** — 카나리 없이 전체 배포는 2차 인시던트 위험
5. **회고는 비난 없이** — 무엇을 어떻게 개선할지에 집중

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
