# 가이드 38: AI 생성 코드 보안 거버넌스

> AI가 만든 코드를 프로덕션에 배포하기 전, 팀이 갖춰야 할 보안 검증 체계와 거버넌스 프레임워크 구축법

## 왜 별도의 거버넌스가 필요한가

2026년 기준, AI 코딩 에이전트가 작성한 코드는 사람이 쓴 코드 대비 15~18% 더 많은 보안 취약점을 포함한다는 분석이 있어요. 구문 정확도는 95%를 넘지만, 보안 통과율은 55% 수준에 머물고 있죠. 데이터 유출 사고 중 약 20%가 AI 생성 코드에서 기인한다는 보고도 나오고 있어요.

문제는 AI 에이전트가 코드를 빠르게 생산하면서 리뷰 병목이 생기고, 검증 없이 머지되는 비율이 높아진다는 점이에요. 팀 단위에서 이걸 체계적으로 관리하는 프레임워크가 없으면, 기술 부채가 아니라 **보안 부채**가 쌓이게 돼요.

## 거버넌스 프레임워크 구성

### 3계층 구조

```
┌─────────────────────────────────────────┐
│  Policy Layer (정책)                      │
│  - AI 코드 사용 범위 정의                   │
│  - 금지 패턴 목록 관리                       │
│  - 리뷰 의무 기준                           │
├─────────────────────────────────────────┤
│  Process Layer (프로세스)                   │
│  - PR 시 자동 보안 스캔                      │
│  - 의존성 감사 파이프라인                     │
│  - 시크릿 탐지 + 차단                        │
├─────────────────────────────────────────┤
│  Tooling Layer (도구)                      │
│  - SAST/DAST 통합                          │
│  - SCA (Software Composition Analysis)    │
│  - 라이선스 컴플라이언스 체커                  │
└─────────────────────────────────────────┘
```

## Policy Layer: 정책 수립

### AI 코드 사용 범위 매트릭스

| 영역 | AI 생성 허용 | 필수 리뷰 | 자동 머지 가능 |
|------|:----------:|:--------:|:-----------:|
| 테스트 코드 | ✅ | 1인 | ✅ |
| 유틸리티/헬퍼 | ✅ | 1인 | ✅ |
| 비즈니스 로직 | ✅ | 2인 | ❌ |
| 인증/권한 | ⚠️ 조건부 | 2인 + 보안 | ❌ |
| 암호화/시크릿 처리 | ❌ | - | ❌ |
| 인프라(IaC) | ⚠️ 조건부 | 2인 + DevOps | ❌ |

### 금지 패턴 목록 예시

```yaml
# .ai-governance/blocked-patterns.yaml
patterns:
  - name: hardcoded-credentials
    regex: "(password|secret|api_key)\\s*=\\s*['\"][^'\"]+['\"]"
    severity: critical
    
  - name: eval-execution
    regex: "eval\\(|exec\\(|Function\\("
    severity: high
    
  - name: sql-string-concat
    regex: "SELECT.*\\+.*WHERE|f\"SELECT.*{|'SELECT.*' \\+"
    severity: high
    
  - name: insecure-random
    regex: "Math\\.random\\(\\)|random\\.random\\(\\)"
    severity: medium
    context: "보안 관련 코드에서만 차단"
```

## Process Layer: 검증 파이프라인

### PR 보안 게이트 워크플로우

```yaml
# .github/workflows/ai-code-security-gate.yaml
name: AI Code Security Gate

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Step 1: AI 생성 코드 감지
      - name: Detect AI-generated changes
        id: detect
        run: |
          # 커밋 author, PR 라벨, 변경 패턴으로 판별
          CHANGED_FILES=$(git diff --name-only origin/main)
          echo "changed_files=$CHANGED_FILES" >> $GITHUB_OUTPUT
      
      # Step 2: SAST 스캔
      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/owasp-top-ten
            p/javascript
            p/typescript
      
      # Step 3: 의존성 취약점 체크
      - name: Dependency audit
        run: |
          npm audit --audit-level=high
          # 또는 pip-audit, cargo-audit
      
      # Step 4: 시크릿 탐지
      - name: Secret scanning
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified
      
      # Step 5: 금지 패턴 검사
      - name: Check blocked patterns
        run: |
          python3 scripts/check-blocked-patterns.py \
            --config .ai-governance/blocked-patterns.yaml \
            --files ${{ steps.detect.outputs.changed_files }}
```

### 시크릿 탐지 자동화

```bash
# pre-commit 훅으로 시크릿 유출 차단
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

## Tooling Layer: 도구 통합

### 필수 도구 스택

| 도구 | 역할 | 무료 여부 |
|------|------|:--------:|
| Semgrep | SAST (정적 분석) | ✅ OSS |
| TruffleHog | 시크릿 탐지 | ✅ OSS |
| npm audit / pip-audit | 의존성 취약점 | ✅ |
| Snyk | SCA + 컨테이너 스캔 | Free tier |
| FOSSA | 라이선스 컴플라이언스 | Free tier |
| Scorecard | 오픈소스 프로젝트 건강도 | ✅ OSS |

### Semgrep 커스텀 룰 예시

```yaml
# .semgrep/ai-code-rules.yaml
rules:
  - id: ai-unsafe-deserialization
    pattern: |
      pickle.loads(...)
    message: "pickle.loads는 임의 코드 실행 위험. json.loads 사용 권장"
    severity: ERROR
    languages: [python]
    
  - id: ai-missing-input-validation
    patterns:
      - pattern: |
          @app.route(...)
          def $FUNC($REQ):
              ... = $REQ.args.get(...)
              ...
      - pattern-not: |
          ... = validate(...)
    message: "사용자 입력값 검증 누락"
    severity: WARNING
    languages: [python]
```

## 서플라이 체인 리스크 관리

AI 에이전트는 의존성을 추가할 때 인기도 기준으로 선택하는 경향이 있어요. 다운로드 수가 많다고 안전한 건 아니에요.

### 의존성 추가 규칙

```bash
# 새 패키지 추가 전 자동 체크 스크립트
check_dependency() {
  local pkg=$1
  
  # 1. 메인테이너 수 확인 (1명이면 위험)
  npm info "$pkg" maintainers 2>/dev/null
  
  # 2. 최근 업데이트 확인 (1년 이상 미업데이트 경고)
  npm info "$pkg" time.modified 2>/dev/null
  
  # 3. OpenSSF Scorecard 점수
  # https://securityscorecards.dev
  
  # 4. 알려진 취약점 확인
  npm audit --package "$pkg" 2>/dev/null
}
```

### 허용 목록 기반 관리

```yaml
# .ai-governance/allowed-dependencies.yaml
policy:
  auto_approve:
    - scope: "@types/*"     # 타입 정의는 자동 승인
    - scope: "@testing-library/*"
    
  require_review:
    - condition: "new_dependency"
      reviewers: ["security-team"]
    - condition: "major_version_bump"
      reviewers: ["tech-lead"]
      
  blocked:
    - name: "event-stream"   # 알려진 악성 패키지
    - name: "colors"         # 의도적 파괴 이력
    - pattern: "*-crypto-*"  # 암호화 관련은 직접 검증
```

## 라이선스 컴플라이언스

AI 에이전트는 학습 데이터에 포함된 오픈소스 코드를 기반으로 생성하기 때문에, 라이선스 문제가 발생할 수 있어요.

### 라이선스 등급 분류

| 등급 | 라이선스 | 사용 정책 |
|------|---------|----------|
| Green | MIT, Apache 2.0, BSD | 자유 사용 |
| Yellow | MPL 2.0, LGPL | 사용 가능, 파일 단위 고지 필요 |
| Red | GPL, AGPL | 별도 승인 필요 |
| Black | SSPL, BSL | 사용 금지 |

```bash
# FOSSA CLI로 라이선스 스캔
fossa analyze
fossa test --policy "ai-code-policy"
```

## 감사 추적 (Audit Trail)

AI 생성 코드의 변경 이력을 추적하는 건 향후 사고 대응에 필수적이에요.

### 추적 항목

```yaml
# 각 PR에 기록할 메타데이터
ai_code_audit:
  tool: "Claude Code"           # 사용된 AI 도구
  model_version: "claude-4"     # 모델 버전
  prompt_hash: "sha256:abc..."  # 프롬프트 해시 (원본 비공개)
  files_generated:              # AI가 생성/수정한 파일
    - src/auth/validator.ts
    - tests/auth.test.ts
  review_status: "approved"     # 리뷰 결과
  reviewer: "security-team"     # 리뷰어
  scan_results:
    semgrep: "pass"
    secret_scan: "pass"
    dependency_audit: "pass"
```

### 대시보드 지표

| 지표 | 측정 주기 | 목표 |
|------|----------|------|
| AI 코드 보안 스캔 통과율 | 주간 | > 90% |
| 시크릿 유출 감지 건수 | 일간 | 0건 |
| 취약 의존성 비율 | 주간 | < 5% |
| AI PR 리뷰 소요 시간 | 주간 | < 2시간 |
| 프로덕션 보안 인시던트 | 월간 | 0건 |

## 팀 도입 체크리스트

- [ ] AI 코드 사용 범위 매트릭스 정의
- [ ] 금지 패턴 목록 작성 (`.ai-governance/`)
- [ ] PR 보안 게이트 워크플로우 설정
- [ ] 시크릿 탐지 pre-commit 훅 설치
- [ ] 의존성 허용 목록 초기 세팅
- [ ] 라이선스 정책 문서화
- [ ] 감사 추적 템플릿 PR에 적용
- [ ] 팀 전원 보안 리뷰 가이드라인 공유
- [ ] 분기별 거버넌스 정책 리뷰 일정 수립

## 흔한 실수와 대응

| 실수 | 대응 |
|------|------|
| AI가 하드코딩한 테스트 시크릿이 프로덕션에 유입 | pre-commit 시크릿 스캔 필수화 |
| 취약한 패키지를 AI가 추천해서 추가 | 의존성 허용 목록 + 자동 감사 |
| GPL 코드를 AI가 거의 동일하게 재생성 | 라이선스 스캔 + 코드 유사도 체크 |
| AI 생성 코드에 SQL 인젝션 취약점 | Semgrep 룰 + 입력 검증 패턴 강제 |
| 보안 리뷰 없이 자동 머지된 PR | 인증/권한 관련 파일 변경 시 리뷰 강제 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
