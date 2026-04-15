# AI 에이전트 기반 인프라 코드(IaC) 리뷰 워크플로우

> Terraform, Pulumi 등 인프라 코드를 AI 에이전트가 자동 리뷰하고, 보안/비용/모범 사례 개선점을 PR로 제안하는 워크플로우

## 개요

코드 리뷰는 열심히 하면서 인프라 변경은 `terraform plan` 결과를 눈으로만 훑고 머지하는 경우가 많습니다. 실제 사고 대부분은 여기서 나옵니다.

이 워크플로우는 AI 에이전트를 IaC 리뷰 파이프라인에 연결해 세 가지를 자동화합니다:

- **보안 리스크 감지** — 과도한 권한, 암호화 미설정, 퍼블릭 노출
- **비용 이상 탐지** — 예상보다 큰 인스턴스, 삭제되는 예약 리소스
- **모범 사례 위반** — 태그 누락, 하드코딩된 값, 모듈 미사용

## 사전 준비

- GitHub Actions 또는 GitLab CI 환경
- Terraform 또는 Pulumi 프로젝트
- Claude API 키 또는 claude-code GitHub App 설치
- `terraform plan -json` 출력 가능한 환경

## 아키텍처

```
PR 오픈
  └─▶ GitHub Actions 트리거
        ├─ terraform plan -json 실행
        ├─ tfsec / checkov 정적 분석
        └─ AI 에이전트 리뷰 (Claude)
              ├─ plan diff 분석
              ├─ 보안 이슈 정리
              ├─ 비용 변화 요약
              └─ PR 코멘트 게시
```

## 설정

### Step 1: GitHub Actions 워크플로우 작성

`.github/workflows/iac-review.yml`:

```yaml
name: IaC AI Review

on:
  pull_request:
    paths:
      - '**.tf'
      - '**.ts'      # Pulumi TypeScript
      - '**.py'      # Pulumi Python
      - 'Pulumi.*.yaml'

jobs:
  iac-review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Init
        run: terraform init -backend=false
        working-directory: ${{ env.TF_DIR }}
        env:
          TF_DIR: ./infra

      - name: Terraform Plan (JSON)
        id: plan
        run: |
          terraform plan -json -out=plan.tfplan 2>&1 | tee plan.json
          terraform show -json plan.tfplan > plan-show.json
        working-directory: ./infra
        env:
          TF_TOKEN_app_terraform_io: ${{ secrets.TF_TOKEN }}

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: ./infra
          soft_fail: true
          format: json
          additional_args: --out tfsec-results.json

      - name: AI Review
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          direct_prompt: |
            아래 파일들을 분석해서 PR 코멘트를 작성해줘:
            - plan-show.json: terraform plan 결과
            - tfsec-results.json: 정적 분석 결과

            리뷰 항목:
            1. 삭제/교체되는 리소스 목록 (🔴 위험 변경)
            2. 보안 이슈 (IAM 과도한 권한, 퍼블릭 버킷, 미암호화)
            3. 비용 영향 (새 리소스 타입, 예약 인스턴스 삭제)
            4. 태그/명명 규칙 위반
            5. 전반적인 승인 권고 여부

            한국어로 작성, 마크다운 테이블 활용
```

### Step 2: Pulumi 프로젝트 연동

Pulumi는 `pulumi preview --json`으로 동일하게 연동합니다:

```yaml
      - name: Pulumi Preview (JSON)
        run: pulumi preview --json > pulumi-preview.json
        env:
          PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Step 3: AI 리뷰 프롬프트 커스터마이징

프로젝트 루트에 `.iac-review-prompt.md` 파일을 두면 AI가 자동으로 읽습니다:

```markdown
## 프로젝트 컨텍스트

- 환경: AWS (us-east-1)
- 비용 예산: 월 $2,000 이하
- 보안 기준: SOC2 Type II 준수 필요
- 금지 사항: S3 퍼블릭 버킷, 0.0.0.0/0 인그레스

## 중점 리뷰 항목

1. RDS 멀티 AZ 설정 확인
2. KMS 암호화 적용 여부
3. VPC 외부 노출 최소화
4. 모든 리소스에 Environment/Team 태그 필수
```

## 리뷰 결과 예시

AI 에이전트가 PR에 게시하는 코멘트 형식:

```markdown
## IaC 리뷰 결과

### 변경 요약

| 작업 | 리소스 | 타입 |
|------|--------|------|
| +추가 | aws_rds_instance.main | db.t3.medium |
| ~변경 | aws_security_group.app | 인그레스 규칙 수정 |
| -삭제 | aws_elasticache_cluster.old | 예약 캐시 삭제 |

### 🔴 즉시 수정 필요

**aws_s3_bucket.logs**: `acl = "public-read"` 설정 발견
→ 로그 버킷은 퍼블릭 노출 불가. `acl = "private"`으로 변경 필요

### 🟡 비용 영향

- `aws_elasticache_cluster.old` 삭제: 예약 인스턴스 할인 손실 가능
- 남은 예약 기간 확인 후 처리 권장

### ✅ 승인 조건

위 🔴 항목 수정 후 머지 권고
```

## 로컬에서 직접 실행

CI 없이 로컬에서 리뷰할 때:

```bash
# plan.json 생성
cd infra
terraform plan -json 2>&1 | tee /tmp/plan.json

# Claude Code로 리뷰
claude --print "
다음 terraform plan 결과를 리뷰해줘.
보안 이슈, 비용 영향, 위험 변경 순서로 정리해줘.

$(cat /tmp/plan.json | python3 -c 'import sys,json; [print(json.dumps(json.loads(l))) for l in sys.stdin if json.loads(l).get(\"@level\")==\"info\"]')
"
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `soft_fail` | `true` | tfsec 실패해도 파이프라인 계속 |
| `working_directory` | `./infra` | IaC 파일 위치 |
| `paths` | `**.tf` | 변경 감지 경로 패턴 |
| `permissions.pull-requests` | `write` | PR 코멘트 작성 권한 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| `terraform init` 실패 | 백엔드 설정 확인, `-backend=false` 옵션 추가 |
| plan JSON 파싱 오류 | Terraform 1.8+ 사용 권장 |
| AI 코멘트 미게시 | `pull-requests: write` 권한 확인 |
| tfsec 오탐 | `.tfsec/config.yml`에 예외 처리 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
