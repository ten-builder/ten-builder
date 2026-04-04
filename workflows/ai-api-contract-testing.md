# AI 에이전트 기반 API 계약 테스트 자동화

> OpenAPI 스펙에서 계약 테스트를 자동 생성하고, API 변경 시 호환성을 CI에서 검증하는 워크플로우

## 개요

마이크로서비스가 늘어날수록 API 변경이 다른 서비스를 깨뜨리는 일도 늘어나요. "내 서비스에서는 잘 되는데?" 하면서 배포했는데, 소비자 서비스가 줄줄이 터지는 상황이죠.

계약 테스트(Contract Testing)는 이 문제를 잡아주는데, 직접 작성하면 번거롭고 스펙 변경 때마다 동기화하기 귀찮아요. 이 워크플로우는 AI 에이전트가 OpenAPI 스펙을 읽고 계약 테스트를 자동 생성한 뒤, PR마다 호환성을 검증하는 파이프라인을 구성합니다.

실제 팀에서 적용했을 때 API 관련 프로덕션 장애가 70% 넘게 줄었다는 사례가 많아요.

## 사전 준비

- OpenAPI 3.0+ 스펙 파일 (YAML 또는 JSON)
- AI 코딩 도구 (Claude Code, Cursor 등)
- Node.js 18+ 또는 Python 3.10+
- CI/CD 파이프라인 (GitHub Actions, GitLab CI 등)
- Pact 또는 유사 계약 테스트 프레임워크 (선택)

## 핵심 개념

계약 테스트를 처음 접하면 E2E 테스트와 헷갈리기 쉬워요. 차이를 정리하면:

| 구분 | 계약 테스트 | E2E 테스트 |
|------|-----------|-----------|
| 검증 범위 | API 인터페이스 (요청/응답 스키마) | 전체 비즈니스 플로우 |
| 실행 속도 | 수 초 | 수 분~수십 분 |
| 의존성 | 스텁/목 사용, 독립 실행 | 실제 서비스 전부 필요 |
| 변경 감지 | 스키마 변경 즉시 감지 | 통합 환경에서만 감지 |
| 유지보수 | 스펙 기반 자동 생성 가능 | 수동 업데이트 필수 |

## 설정

### Step 1: OpenAPI 스펙 기반 테스트 구조 설계

먼저 프로젝트에 계약 테스트 디렉토리를 구성합니다.

```
project-root/
├── openapi/
│   ├── user-service.yaml      # Provider 스펙
│   └── order-service.yaml     # Provider 스펙
├── contract-tests/
│   ├── generated/             # AI가 자동 생성한 테스트
│   ├── custom/                # 수동 추가 테스트
│   ├── schemas/               # 스냅샷 스키마
│   └── config.yaml            # 계약 테스트 설정
└── .github/
    └── workflows/
        └── contract-test.yaml # CI 파이프라인
```

### Step 2: AI 에이전트에게 테스트 생성 요청

OpenAPI 스펙 파일을 AI 에이전트에게 넘기고 계약 테스트를 생성합니다.

```bash
# Claude Code에서 실행
claude "openapi/user-service.yaml을 읽고 다음 기준으로 계약 테스트를 생성해줘:
1. 모든 엔드포인트에 대해 요청/응답 스키마 검증 테스트
2. 필수 필드 누락 시 400 응답 검증
3. 인증 없이 접근 시 401 응답 검증
4. 각 응답 코드별 스키마 일치 검증
테스트 프레임워크: Jest + supertest
출력 경로: contract-tests/generated/"
```

AI가 생성하는 테스트 예시:

```typescript
// contract-tests/generated/user-service.contract.test.ts
import { validateSchema } from '../helpers/schema-validator';
import spec from '../../openapi/user-service.yaml';

describe('User Service Contract', () => {
  describe('GET /users/{id}', () => {
    it('200 응답이 스키마와 일치해야 한다', async () => {
      const response = await request(app).get('/users/1');
      const schema = spec.paths['/users/{id}'].get.responses['200'];
      expect(validateSchema(response.body, schema)).toBe(true);
    });

    it('존재하지 않는 ID로 요청하면 404를 반환해야 한다', async () => {
      const response = await request(app).get('/users/999999');
      expect(response.status).toBe(404);
      const schema = spec.paths['/users/{id}'].get.responses['404'];
      expect(validateSchema(response.body, schema)).toBe(true);
    });

    it('필수 헤더 없이 요청하면 401을 반환해야 한다', async () => {
      const response = await request(app)
        .get('/users/1')
        .unset('Authorization');
      expect(response.status).toBe(401);
    });
  });

  describe('POST /users', () => {
    it('필수 필드 누락 시 400을 반환해야 한다', async () => {
      const response = await request(app)
        .post('/users')
        .send({ name: 'test' }); // email 누락
      expect(response.status).toBe(400);
    });
  });
});
```

### Step 3: 스키마 스냅샷 생성

API 변경을 추적하기 위해 현재 스키마를 스냅샷으로 저장합니다.

```bash
# 스냅샷 생성 스크립트
cat > contract-tests/snapshot.sh << 'EOF'
#!/bin/bash
# OpenAPI 스펙에서 엔드포인트별 스키마 스냅샷 생성

SPEC_DIR="openapi"
SNAPSHOT_DIR="contract-tests/schemas"

for spec_file in "$SPEC_DIR"/*.yaml; do
  service=$(basename "$spec_file" .yaml)
  mkdir -p "$SNAPSHOT_DIR/$service"

  # yq로 각 엔드포인트 스키마 추출
  yq eval '.paths | keys | .[]' "$spec_file" | while read -r path; do
    safe_name=$(echo "$path" | tr '/' '_' | tr -d '{}')
    yq eval ".paths[\"$path\"]" "$spec_file" \
      > "$SNAPSHOT_DIR/$service/${safe_name}.yaml"
  done
done

echo "스냅샷 생성 완료: $SNAPSHOT_DIR"
EOF
chmod +x contract-tests/snapshot.sh
```

### Step 4: 변경 감지 + AI 분석 파이프라인

```yaml
# .github/workflows/contract-test.yaml
name: API Contract Test

on:
  pull_request:
    paths:
      - 'openapi/**'
      - 'src/api/**'
      - 'src/routes/**'

jobs:
  contract-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: OpenAPI 스펙 변경 감지
        id: detect
        run: |
          CHANGED=$(git diff origin/main --name-only -- openapi/)
          if [ -z "$CHANGED" ]; then
            echo "changed=false" >> $GITHUB_OUTPUT
          else
            echo "changed=true" >> $GITHUB_OUTPUT
            echo "$CHANGED" > /tmp/changed-specs.txt
          fi

      - name: 이전 스펙과 비교
        if: steps.detect.outputs.changed == 'true'
        run: |
          git show origin/main:openapi/ > /tmp/old-specs/ 2>/dev/null || true
          # 스키마 호환성 체크
          npx @openapitools/openapi-diff \
            /tmp/old-specs/user-service.yaml \
            openapi/user-service.yaml \
            --fail-on-incompatible

      - name: 계약 테스트 실행
        run: |
          npm ci
          npm run test:contract

      - name: 호환성 리포트 생성
        if: always()
        run: |
          # 결과를 PR 코멘트로 생성
          node contract-tests/report.js > /tmp/report.md

      - name: PR 코멘트 작성
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('/tmp/report.md', 'utf8');
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: report
            });
```

## 사용 방법

### 새 API 엔드포인트 추가 시

1. OpenAPI 스펙 파일에 새 엔드포인트 정의
2. AI 에이전트에게 테스트 생성 요청

```bash
claude "openapi/user-service.yaml의 새 엔드포인트 POST /users/batch에 대한
계약 테스트를 contract-tests/generated/에 추가해줘.
기존 테스트 스타일과 동일하게 작성하고,
배열 입력 유효성 검사와 부분 실패 응답 케이스도 포함해줘."
```

3. PR 생성 → CI가 자동으로 계약 테스트 실행

### 기존 API 수정 시

스펙 변경이 하위 호환성을 깨뜨리면 CI에서 잡아줍니다:

```
[FAIL] Breaking Change Detected
  - GET /users/{id}: 응답 필드 'email' 타입 변경 (string → object)
  - POST /users: 필수 필드 'phone' 추가 (기존 소비자 호환성 깨짐)

권장 조치:
  1. 새 필드를 optional로 변경하거나
  2. API 버전을 올려서 v2 엔드포인트로 분리
```

### AI 에이전트로 깨진 테스트 자동 수정

```bash
claude "contract-tests/generated/user-service.contract.test.ts에서
실패하는 테스트 3건을 확인하고, openapi/user-service.yaml의
최신 스펙에 맞게 테스트를 업데이트해줘.
변경 사유를 주석으로 남겨줘."
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `strictMode` | `true` | 하위 호환성 깨지면 CI 실패 |
| `autoGenerate` | `true` | 스펙 변경 시 테스트 자동 재생성 |
| `snapshotUpdate` | `manual` | 스냅샷 업데이트 방식 (manual/auto) |
| `excludePaths` | `["/health", "/metrics"]` | 테스트 제외 경로 |
| `responseValidation` | `schema` | 검증 수준 (schema/example/both) |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 스펙과 실제 API 응답 불일치 | 스펙 먼저 업데이트 후 구현 → 계약 우선(Contract-First) 방식 적용 |
| 테스트가 너무 많이 생성됨 | `config.yaml`에서 `excludePaths`로 헬스체크 등 제외 |
| AI가 생성한 테스트가 틀림 | `custom/` 디렉토리에 수동 수정 버전 유지, generated는 재생성 |
| CI 시간이 오래 걸림 | 변경된 스펙 관련 테스트만 선택 실행 (파일 변경 감지 활용) |
| Pact Broker 연동 | `config.yaml`에 `pactBrokerUrl` 설정, CI에서 자동 퍼블리시 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
