# 플레이북 70: 기업 AI 코딩 도구 승인 플레이북 — Shadow IT에서 안전한 도입까지

> 허가받지 않은 AI 코딩 도구는 2026년 Shadow IT의 핵심 위험 요소입니다. 도구 인벤토리 구축부터 리스크 등급화, CI/CD 승인 게이트, 팀 교육까지 — 기업 환경에서 AI 코딩 도구를 안전하게 도입하는 단계별 플레이북입니다.

## 소요 시간

초기 설정: 1~2일 / 지속 운영: 주 1회 30분 점검

## 사전 준비

- 개발 조직 규모 파악 (팀 수, 개발자 수)
- IT 보안 정책 담당자 또는 CISO 연락처
- GitHub/GitLab 조직 관리자 권한
- CI/CD 파이프라인 접근 권한

---

## Step 1: 현황 감사 — 어떤 도구가 쓰이고 있나요?

먼저 조직에서 실제로 사용 중인 AI 코딩 도구를 파악해야 해요. 공식 승인 없이 사용 중인 도구가 많을수록 리스크도 커집니다.

### 1-1. 도구 사용 현황 설문 (빠른 파악)

팀 전체에 간단한 설문을 돌려요. 익명으로 진행하면 솔직한 답변을 얻을 수 있습니다.

```
질문 항목:
1. 현재 사용 중인 AI 코딩 도구는? (Claude Code, Cursor, Copilot, Gemini CLI, 기타)
2. 사용 목적은? (코드 작성, 리뷰, 문서화, 디버깅)
3. 회사 코드를 도구에 전달하나요? (예/아니요/부분적으로)
4. 팀 공식 승인을 받은 도구인가요?
```

### 1-2. 네트워크 트래픽 분석

IT 보안팀과 협력해서 외부 AI API 호출 패턴을 확인해요.

```bash
# 주요 AI 서비스 도메인 트래픽 확인 (예시: 방화벽 로그 분석)
# Anthropic, OpenAI, Google AI, GitHub Copilot 등 도메인 필터링

grep -E "anthropic\.com|openai\.com|googleapis\.com/ai|copilot\.github\.com" \
  /var/log/firewall/outbound-*.log | \
  awk '{print $5}' | sort | uniq -c | sort -rn | head -20
```

### 1-3. 도구 인벤토리 시트 작성

```markdown
| 도구명 | 사용 팀 | 사용 목적 | 데이터 전송 여부 | 승인 상태 |
|--------|---------|----------|-----------------|---------|
| Claude Code | 백엔드 팀 | 코드 작성, 리팩토링 | 코드베이스 전달 | 미승인 |
| GitHub Copilot | 전체 팀 | 자동완성 | 코드 스니펫 | 승인됨 |
| Cursor | 프론트엔드 | 코드 생성 | 전체 파일 | 검토 중 |
```

---

## Step 2: 리스크 등급화 — 어떤 도구가 위험한가요?

모든 AI 도구가 동일한 리스크를 갖지는 않아요. 4가지 기준으로 등급을 나눕니다.

| 등급 | 기준 | 예시 도구 | 처리 방식 |
|------|------|---------|----------|
| 🔴 고위험 | 전체 코드베이스 전달, 외부 서버 저장 | 일부 무료 AI 도구 | 즉시 사용 금지 |
| 🟠 중위험 | 코드 스니펫 전달, 학습 데이터 활용 가능 | Claude Code (기본) | 기업 플랜 전환 필요 |
| 🟡 검토 | 로컬 처리 + 선택적 클라우드 | Ollama + 로컬 모델 | 조건부 승인 |
| 🟢 저위험 | 기업 계약, 데이터 학습 제외 | Claude Code (기업), Copilot Business | 승인됨 |

### 리스크 평가 체크리스트

```
□ 코드가 외부 서버로 전달되나요?
□ 전달된 데이터가 모델 학습에 사용되나요?
□ SOC 2 / ISO 27001 인증이 있나요?
□ 기업용 데이터 처리 계약(DPA)이 있나요?
□ EU AI Act 규정 준수 여부는?
□ 저장된 데이터의 보존 기간은?
```

---

## Step 3: 승인 워크플로우 구축

### 3-1. 신규 도구 도입 신청 프로세스

```markdown
## AI 코딩 도구 도입 신청서 템플릿

**도구명:** [도구명]
**신청 팀:** [팀명]
**신청자:** [이름]
**사용 목적:** [구체적 사용 시나리오]

**보안 검토 항목:**
- [ ] 개인 정보 처리 여부
- [ ] 지식재산권(IP) 영향
- [ ] 라이선스 검토
- [ ] 데이터 전송 범위

**위험 완화 방안:**
[도구 사용 시 민감 데이터 보호 방법]
```

### 3-2. 승인 의사결정 트리

```
신청 도입
    ↓
데이터 외부 전송? → 예 → 기업 플랜 있나요? → 아니오 → 거부
                          ↓ 예
                     DPA 체결? → 아니오 → 법무팀 검토 필요
                          ↓ 예
                     조건부 승인 (민감 파일 제외 설정)

데이터 외부 전송? → 아니오 → 로컬 실행 검증 → 승인
```

### 3-3. 승인 도구 목록 관리

팀 위키 또는 Git 저장소에서 승인 목록을 버전 관리해요.

```yaml
# approved-ai-tools.yaml
approved_tools:
  - name: "GitHub Copilot Business"
    tier: low_risk
    approved_by: "CISO"
    approved_date: "2026-01-15"
    conditions:
      - "기업 조직 계정으로만 사용"
      - "개인 계정 연동 금지"
    data_policy: "코드 스니펫 전달, 학습 제외"

  - name: "Claude Code (Pro/Max)"
    tier: medium_risk
    approved_by: "CTO"
    approved_date: "2026-03-10"
    conditions:
      - "공개 레포 코드만 전달"
      - "내부 시스템 크리덴셜 노출 금지"
    data_policy: "코드 전달, 학습 제외 (API 사용 시)"

pending_review:
  - name: "Cursor"
    requested_by: "프론트엔드 팀"
    requested_date: "2026-05-01"
    status: "보안팀 검토 중"
```

---

## Step 4: CI/CD 보안 게이트 설정

승인되지 않은 AI 도구로 생성된 코드 패턴이나 민감 정보 노출을 자동으로 차단해요.

### 4-1. GitHub Actions 게이트 예시

```yaml
# .github/workflows/ai-governance.yml
name: AI Governance Gate

on:
  pull_request:
    branches: [main, develop]

jobs:
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: API 키 노출 스캔
        run: |
          # AI 도구 API 키가 코드에 포함되었는지 확인
          if grep -rE "(sk-ant|sk-|AIza|ANTHROPIC_API_KEY)" \
            --include="*.py" --include="*.ts" --include="*.js" .; then
            echo "::error::API 키가 코드에 포함되어 있습니다. 즉시 제거하세요."
            exit 1
          fi

  ai-generated-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: PR 크기 제한 확인 (AI 생성 코드 대량 주입 방지)
        run: |
          ADDED_LINES=$(git diff --stat origin/main HEAD | \
            tail -1 | awk '{print $4}')
          if [ "$ADDED_LINES" -gt 2000 ]; then
            echo "::warning::변경 라인이 2000줄을 초과합니다. AI 생성 코드 리뷰를 권장합니다."
          fi
```

### 4-2. pre-commit 훅 설정

```bash
# .pre-commit-config.yaml에 추가
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        
  - repo: local
    hooks:
      - id: check-approved-ai-tools
        name: AI 도구 승인 여부 확인
        entry: scripts/check-ai-tool-usage.sh
        language: script
        pass_filenames: false
```

---

## Step 5: 팀 교육 및 지속 운영

### 5-1. 온보딩 교육 핵심 항목

```
AI 코딩 도구 사용 가이드 (15분 필수 교육)

1. 승인된 도구 목록 확인 방법
   → 팀 위키 > 개발 환경 > AI 도구 목록

2. 절대 AI에 전달하지 않을 데이터
   → API 키, DB 패스워드, 개인 정보, 내부 시스템 IP

3. 새 도구 도입 신청 방법
   → Jira 티켓 > AI 도구 도입 신청 템플릿

4. 보안 사고 발생 시 연락처
   → security@company.com 또는 #security Slack 채널
```

### 5-2. 정기 점검 (주 1회)

| 점검 항목 | 방법 | 담당 |
|----------|------|------|
| 신규 AI 도구 사용 감지 | 네트워크 로그 검토 | IT 보안팀 |
| 승인 대기 도구 처리 | 도입 신청 티켓 확인 | 개발 리드 |
| API 키 노출 스캔 | GitGuardian / detect-secrets | DevSecOps |
| 승인 도구 목록 최신화 | approved-ai-tools.yaml 업데이트 | CTO / 팀 리드 |

---

## 체크리스트

- [ ] 전체 팀 AI 도구 사용 현황 설문 완료
- [ ] 도구 인벤토리 시트 작성 (리스크 등급 포함)
- [ ] 미승인 도구 사용 팀에 공식 통보
- [ ] 승인 도구 목록을 Git에서 관리
- [ ] CI/CD 시크릿 스캔 게이트 설정
- [ ] 신규 도입 신청 프로세스 문서화
- [ ] 팀 교육 자료 배포
- [ ] 정기 점검 일정 수립 (월 1회 최소)

## 다음 단계

- 승인된 도구의 효과적인 활용법: [guides/101-enterprise-ai-coding-governance-guide.md](../guides/101-enterprise-ai-coding-governance-guide.md)
- 보안 위협 대응: [cheatsheets/owasp-agentic-ai-security-cheatsheet-2026.md](../cheatsheets/owasp-agentic-ai-security-cheatsheet-2026.md)
- AI 코드 품질 게이트: [claude-code/playbooks/67-ai-code-quality-gates.md](67-ai-code-quality-gates.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
