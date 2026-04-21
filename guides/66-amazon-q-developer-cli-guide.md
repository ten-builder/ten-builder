# Amazon Q Developer CLI 실전 가이드 2026 — AWS 환경에서 AI 에이전트 제대로 쓰기

> Claude Code, Gemini CLI와 다른 선택지 — AWS 중심 개발자라면 무료로 쓸 수 있는 Amazon Q Developer CLI를 실전 기준으로 정리했습니다.

## 소요 시간

20-30분 (설치 + 기본 워크플로우 세팅)

## Amazon Q Developer CLI란?

Amazon Q Developer CLI는 AWS가 제공하는 터미널 기반 AI 코딩 에이전트입니다. Claude Code가 코드베이스 전체를 이해하는 데 집중한다면, Q Developer CLI는 AWS 서비스와의 통합을 중심으로 인프라 코드 생성, 클라우드 리소스 조회, 보안 취약점 스캔까지 한 번에 처리합니다.

2026년 기준 주목할 이유는 두 가지입니다:

- **무료 티어**: 월 50회 에이전트 채팅 + 1,000줄 코드 변환 제공
- **AWS 생태계 통합**: CloudFormation, CDK, Terraform IaC 생성부터 IAM 정책 작성까지 AWS 맥락을 이해한 코드 생성

## Amazon Q Developer CLI vs 주요 경쟁 도구

| 항목 | Amazon Q Developer CLI | Claude Code | Gemini CLI |
|------|------------------------|-------------|------------|
| 가격 | 무료 티어 있음 | $20/월 | 무료 (API 사용량 별도) |
| AWS 통합 | 네이티브 | 없음 | 없음 |
| 컨텍스트 윈도우 | 200,000 토큰 | 400,000+ 토큰 | 1,000,000 토큰 |
| 내부 AI 모델 | Claude 3.7 Sonnet | Claude 4.5+ | Gemini 3 Pro |
| IaC 코드 생성 | CloudFormation, CDK, Terraform | 범용 | 범용 |
| 코드 보안 스캔 | 내장 | 없음 | 없음 |
| 대화 저장/불러오기 | 있음 | 없음 | 없음 |
| OS 지원 | Windows, macOS, Linux | macOS, Linux, WSL | macOS, Linux, Windows |

**실전 선택 기준:**
- AWS 인프라 중심 개발 → Amazon Q Developer CLI
- 대규모 코드베이스 멀티파일 작업 → Claude Code
- 거대 컨텍스트 + 비용 절감 → Gemini CLI

## 설치 및 초기 설정

### Step 1: 설치

```bash
# macOS (Homebrew)
brew install amazon-q

# Linux
curl --proto '=https' --tlsv1.2 -sSf https://desktop-release.q.us-east-1.amazonaws.com/latest/linux/amazon-q.sh | sh

# 설치 확인
q --version
```

### Step 2: 인증 설정

```bash
# AWS 계정으로 로그인
q login

# Builder ID (무료 계정) 또는 AWS IAM Identity Center 선택
# 브라우저가 열리면 로그인 완료
```

### Step 3: 대화 시작

```bash
# 기본 채팅 모드
q chat

# 특정 디렉터리에서 시작
cd ~/my-project && q chat
```

## 핵심 기능별 활용 패턴

### AWS 리소스 조회 + 코드 생성

Q Developer CLI의 가장 큰 차별점은 실제 AWS 환경을 읽고 그에 맞는 코드를 생성한다는 점입니다.

```bash
# 예시 1: 현재 계정의 S3 버킷 구조 파악 후 접근 제어 코드 생성
q chat --message "내 S3 버킷 목록을 확인하고 각 버킷의 퍼블릭 접근 설정을 점검하는 Lambda 함수를 작성해줘"

# 예시 2: VPC 구성 기반 보안 그룹 검토
q chat --message "현재 VPC 설정을 기반으로 불필요하게 열린 포트가 있는지 확인하고 수정 방안을 제시해줘"
```

에이전트가 `aws` CLI를 직접 실행하여 실제 리소스를 확인한 뒤 코드를 생성합니다.

### IaC 코드 자동 생성

```bash
# CloudFormation 스택 생성
q chat --message "Node.js 앱을 위한 ECS Fargate + ALB + RDS 스택을 CloudFormation으로 작성해줘. 프로덕션 보안 설정 포함."

# Terraform으로 변환
q chat --message "위 CloudFormation을 Terraform HCL로 변환해줘"

# AWS CDK (TypeScript)
q chat --message "S3 버킷 + CloudFront + Route53을 CDK TypeScript로 구성해줘"
```

생성된 IaC 코드를 직접 파일로 저장하려면:

```bash
q chat --message "ECS 스택 CloudFormation 작성" > infrastructure/ecs-stack.yaml
```

### 대화 저장 및 재개

장기 프로젝트 작업 시 진행 상황을 저장할 수 있습니다.

```bash
# 현재 대화 저장
/save ecs-migration-progress

# 다른 세션에서 이어서 작업
q chat --resume

# 저장된 대화 목록
/list

# 특정 대화 불러오기
/load ecs-migration-progress
```

이 기능은 Claude Code에 없는 Q Developer CLI만의 기능으로, 멀티 세션 프로젝트에서 유용합니다.

### 보안 취약점 스캔

```bash
# 코드베이스 전체 스캔
q scan --directory ./src

# 특정 파일 스캔
q scan --file app.py

# OWASP Top 10 기준 검사
q chat --message "현재 프로젝트의 OWASP Top 10 취약점을 점검하고 수정 코드를 제안해줘"
```

스캔 결과는 파일 경로, 취약점 유형, 수정 방법까지 함께 출력됩니다.

### 커스텀 에이전트 설정

프로젝트에 맞는 규칙을 정의해 에이전트를 특화할 수 있습니다.

```bash
# 프로젝트 룰 파일 생성
mkdir -p .amazonq
cat > .amazonq/rules.md << 'EOF'
## 코딩 규칙
- TypeScript 사용, any 타입 금지
- 모든 AWS SDK 호출에 에러 핸들링 포함
- 환경변수는 SSM Parameter Store에서 조회

## 승인 없이 실행 가능한 툴
- read_file
- list_directory
- aws_describe (읽기 전용 AWS 명령)
EOF
```

## 실전 워크플로우: Lambda 함수 개발

### 전체 흐름

```bash
cd ~/lambda-project

# 1. 요구사항 설명
q chat --message "S3에 파일이 업로드되면 이미지를 리사이즈하고 썸네일을 생성하는 Lambda 함수 작성해줘. Node.js 18, Sharp 라이브러리 사용."

# 2. 테스트 코드 생성 요청
q chat --message "방금 작성한 Lambda 함수의 단위 테스트를 Jest로 작성해줘"

# 3. IAM 역할 생성
q chat --message "이 Lambda 함수에 필요한 최소 권한 IAM 역할을 CloudFormation으로 작성해줘"

# 4. 배포 설정
q chat --message "SAM 템플릿으로 로컬 테스트 + 배포 설정을 구성해줘"
```

### 체크리스트

- [ ] q login으로 인증 완료
- [ ] 프로젝트 디렉터리에서 q chat 실행
- [ ] .amazonq/rules.md로 프로젝트 규칙 설정
- [ ] AWS CLI 프로파일 설정 (`~/.aws/credentials`)
- [ ] 코드 생성 후 q scan으로 보안 검토

## 흔한 실수와 해결

| 실수 | 해결 |
|------|------|
| AWS 리소스 조회 실패 | `aws configure`로 크레덴셜 설정 확인 |
| IaC 코드가 너무 범용적 | 실제 VPC ID, Subnet ID를 프롬프트에 포함 |
| 대화가 길어지면 응답 품질 저하 | `/save`로 저장 후 새 대화에서 `/load` |
| 무료 티어 한도 초과 | 핵심 작업만 에이전트 채팅, 나머지는 일반 채팅 사용 |
| 생성된 IAM 정책이 너무 넓음 | "최소 권한 원칙 적용" 명시적으로 요청 |

## 다음 단계

→ [커스텀 MCP 서버 빌드 및 배포](../claude-code/playbooks/45-custom-mcp-server-build-deploy.md)
→ [AI 에이전트 기반 인프라 코드(IaC) 리뷰 워크플로우](../workflows/ai-iac-code-review.md)
→ [AI 에이전트 보안 취약점 자동 패치 플레이북](../claude-code/playbooks/48-security-vulnerability-auto-patch.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
