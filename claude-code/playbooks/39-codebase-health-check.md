# 플레이북 39: AI 에이전트 코드베이스 헬스체크

> 코드베이스의 기술 부채, 보안 취약점, 테스트 커버리지, 의존성 상태를 AI 에이전트로 종합 진단해요

## 소요 시간

30-45분 (전체 진단 기준)

## 사전 준비

- Claude Code 또는 터미널 기반 AI 코딩 에이전트
- 프로젝트 레포 (Git 이력 포함)
- Node.js/Python/Go 등 프로젝트 런타임 환경
- CI 파이프라인 접근 권한 (선택)

---

## 왜 코드베이스 헬스체크가 필요한가

프로젝트가 커지면 기술 부채는 눈에 보이지 않게 쌓여요. 테스트 커버리지가 언제부터 떨어졌는지, 어떤 의존성이 취약점을 가지고 있는지, deprecated API를 어디서 쓰고 있는지 — 수동으로 추적하기엔 범위가 너무 넓죠.

AI 에이전트는 코드베이스 전체를 빠르게 스캔하고, 패턴을 인식하고, 우선순위를 매길 수 있어요. 이 플레이북은 4가지 영역을 체계적으로 진단하는 방법을 다뤄요.

---

## Step 1: 기술 부채 스캔

AI 에이전트에게 코드베이스의 기술 부채를 식별하도록 요청해요.

```bash
# Claude Code에서 실행
claude "이 프로젝트의 기술 부채를 분석해줘. 다음 항목을 중심으로:
1. TODO/FIXME/HACK 주석 목록과 위치
2. 중복 코드 패턴 (유사 로직이 2곳 이상)
3. 복잡도 높은 함수 (조건 분기 5개 이상)
4. deprecated API 사용 위치
5. 매직 넘버/하드코딩된 값
각 항목별로 파일 경로, 라인, 심각도(high/medium/low)를 표로 정리해줘."
```

### 기술 부채 심각도 기준

| 심각도 | 기준 | 예시 |
|--------|------|------|
| **High** | 런타임 에러 가능성 | deprecated API, 미처리 에러 |
| **Medium** | 유지보수 비용 증가 | 중복 코드, 복잡한 함수 |
| **Low** | 코드 품질 저하 | TODO 주석, 매직 넘버 |

### 자동 스캔 스크립트

```bash
#!/bin/bash
# codebase-debt-scan.sh

echo "=== TODO/FIXME/HACK 주석 ==="
grep -rn "TODO\|FIXME\|HACK\|XXX" src/ --include="*.ts" --include="*.py" --include="*.go" | wc -l
grep -rn "TODO\|FIXME\|HACK\|XXX" src/ --include="*.ts" --include="*.py" --include="*.go"

echo ""
echo "=== 파일별 라인 수 (복잡도 후보) ==="
find src/ -name "*.ts" -o -name "*.py" -o -name "*.go" | xargs wc -l | sort -rn | head -20

echo ""
echo "=== 최근 6개월 미변경 파일 (방치 코드) ==="
git log --since="6 months ago" --name-only --pretty=format: | sort -u > /tmp/recent_files.txt
find src/ -name "*.ts" -o -name "*.py" -o -name "*.go" | while read f; do
  grep -q "$f" /tmp/recent_files.txt || echo "STALE: $f"
done
```

---

## Step 2: 보안 취약점 진단

```bash
# 의존성 취약점 스캔
npm audit --json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
vulns = data.get('vulnerabilities', {})
for name, info in vulns.items():
    severity = info.get('severity', 'unknown')
    print(f'{severity.upper():8s} {name}: {info.get(\"title\", \"N/A\")}')
"

# Python 프로젝트
pip audit --format json 2>/dev/null

# Go 프로젝트
govulncheck ./... 2>/dev/null
```

### AI 에이전트 보안 리뷰 프롬프트

```bash
claude "보안 관점에서 이 코드베이스를 검토해줘:
1. 하드코딩된 시크릿/API 키 (.env가 아닌 소스코드에 있는 것)
2. SQL 인젝션 가능 쿼리 (문자열 연결로 만든 쿼리)
3. XSS 취약점 (사용자 입력 미이스케이프)
4. 인증/인가 누락 엔드포인트
5. 에러 메시지에 민감 정보 노출
파일 경로와 구체적인 코드 라인을 표시하고, 수정 방법도 같이 알려줘."
```

### 보안 체크 자동화

| 영역 | 도구 | 명령어 |
|------|------|--------|
| 의존성 취약점 | `npm audit` / `pip audit` | `npm audit --production` |
| 시크릿 탐지 | `gitleaks` | `gitleaks detect --source .` |
| SAST 스캔 | `semgrep` | `semgrep scan --config auto` |
| 라이선스 검사 | `license-checker` | `npx license-checker --summary` |

---

## Step 3: 테스트 커버리지 분석

```bash
# 커버리지 리포트 생성
# Node.js
npx jest --coverage --coverageReporters=text-summary 2>&1

# Python
pytest --cov=src --cov-report=term-missing 2>&1

# Go
go test ./... -coverprofile=coverage.out && go tool cover -func=coverage.out
```

### AI 에이전트 테스트 갭 분석

```bash
claude "테스트 커버리지를 분석하고 개선 계획을 세워줘:
1. 현재 커버리지 리포트를 확인하고
2. 테스트가 없는 핵심 비즈니스 로직 파일 목록을 만들어줘
3. 각 미커버 파일의 중요도를 high/medium/low로 분류하고
4. high 중요도 파일에 대한 테스트 작성 순서를 제안해줘
5. 각 파일에 필요한 테스트 케이스 수를 추정해줘"
```

### 커버리지 목표 설정

| 영역 | 목표 | 우선순위 |
|------|------|----------|
| 비즈니스 로직 | 80%+ | 최우선 |
| API 엔드포인트 | 70%+ | 높음 |
| 유틸리티 함수 | 90%+ | 보통 |
| UI 컴포넌트 | 60%+ | 낮음 |
| 설정/라우팅 | 필요 시 | 최하위 |

---

## Step 4: 의존성 상태 점검

```bash
# Node.js 의존성 업데이트 현황
npx npm-check-updates 2>/dev/null | tail -20

# Python
pip list --outdated --format=columns 2>/dev/null

# Go
go list -u -m all 2>/dev/null | grep '\[' | head -20
```

### AI 에이전트 의존성 리뷰

```bash
claude "의존성 상태를 종합 리뷰해줘:
1. 메이저 업데이트가 필요한 패키지 목록
2. 각 업데이트의 Breaking Change 요약
3. 보안 패치가 포함된 업데이트 (우선 적용 대상)
4. 더 이상 유지보수되지 않는 패키지 (대안 제시)
5. 업데이트 순서 — 의존 관계를 고려한 실행 계획"
```

### 의존성 건강 지표

```bash
#!/bin/bash
# dependency-health.sh

echo "=== 의존성 요약 ==="
echo "총 직접 의존성: $(cat package.json | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d.get("dependencies",{})))')"
echo "총 개발 의존성: $(cat package.json | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d.get("devDependencies",{})))')"

echo ""
echo "=== 업데이트 필요 ==="
npx npm-check-updates --format lines 2>/dev/null | grep -c "→"

echo ""
echo "=== 취약점 ==="
npm audit 2>/dev/null | grep -E "high|critical" | head -5
```

---

## Step 5: 종합 리포트 생성

모든 진단 결과를 하나의 리포트로 합쳐요.

```bash
claude "지금까지의 분석을 종합해서 코드베이스 헬스 리포트를 만들어줘.

포맷:
## 코드베이스 헬스 리포트 - {프로젝트명}
생성일: {오늘 날짜}

### 종합 점수: {A/B/C/D/F}

### 1. 기술 부채 ({점수}/100)
- 요약: ...
- Top 3 개선 항목: ...

### 2. 보안 ({점수}/100)
- 취약점 수: critical {N}, high {N}, medium {N}
- 즉시 조치 항목: ...

### 3. 테스트 ({점수}/100)
- 커버리지: {N}%
- 미커버 핵심 파일: ...

### 4. 의존성 ({점수}/100)
- 업데이트 필요: {N}개
- 보안 패치 대기: {N}개

### 액션 플랜
1주차: ...
2주차: ...
3주차: ...
4주차: ..."
```

### 점수 산정 기준

| 등급 | 점수 | 상태 |
|------|------|------|
| A | 90-100 | 건강 — 유지보수만 |
| B | 75-89 | 양호 — 마이너 개선 필요 |
| C | 60-74 | 주의 — 계획적 개선 필요 |
| D | 40-59 | 경고 — 즉시 개선 착수 |
| F | 0-39 | 위험 — 전면 리팩토링 검토 |

---

## CI 파이프라인 통합

헬스체크를 주간 CI 잡으로 자동화해요.

```yaml
# .github/workflows/codebase-health.yml
name: Codebase Health Check
on:
  schedule:
    - cron: '0 9 * * 1'  # 매주 월요일 09:00 UTC
  workflow_dispatch:

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Dependency audit
        run: npm audit --production --audit-level=high

      - name: Test coverage
        run: |
          npm test -- --coverage --coverageReporters=json-summary
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          echo "Line coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 70" | bc -l) )); then
            echo "::warning::Coverage below 70%: $COVERAGE%"
          fi

      - name: Tech debt scan
        run: |
          DEBT_COUNT=$(grep -rn "TODO\|FIXME\|HACK" src/ --include="*.ts" | wc -l)
          echo "Tech debt markers: $DEBT_COUNT"

      - name: Secret scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 반복 실행 패턴

| 빈도 | 체크 항목 | 방법 |
|------|----------|------|
| 매 커밋 | 시크릿 탐지 | pre-commit hook + gitleaks |
| 매일 | 의존성 취약점 | CI scheduled job |
| 매주 | 종합 헬스 리포트 | AI 에이전트 + CI |
| 매월 | 의존성 메이저 업데이트 | AI 에이전트 리뷰 |
| 분기별 | 기술 부채 정리 스프린트 | 팀 작업 |

## 체크리스트

- [ ] 기술 부채 스캔 완료 (TODO/중복/복잡도)
- [ ] 보안 취약점 진단 완료 (의존성 + 코드)
- [ ] 테스트 커버리지 확인 및 갭 분석
- [ ] 의존성 업데이트 상태 점검
- [ ] 종합 리포트 생성 및 공유
- [ ] CI 자동화 설정 (선택)
- [ ] 액션 플랜 수립 및 이슈 등록

## 다음 단계

→ [에러 핸들링 가드레일](./32-ai-error-retry-guardrails.md)
→ [코드 생성 검증 루프](./34-ai-code-generation-validation.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
