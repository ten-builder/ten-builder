# 플레이북 38: AI 의존성 업그레이드

> 레거시 의존성을 AI와 함께 안전하게 올리는 방법 — 호환성 확인부터 회귀 테스트까지

## 소요 시간

30-90분 (프로젝트 규모에 따라)

## 사전 준비

- 업그레이드할 프로젝트 (npm, pip, cargo 등)
- AI 코딩 도구 (Claude Code, Cursor 등)
- 기본 테스트 스위트 (없으면 먼저 작성 권장)

---

## Step 1: 현황 파악

먼저 어떤 의존성이 오래됐는지 파악합니다.

### npm/yarn 프로젝트

```bash
# 업데이트 가능한 패키지 확인
npm outdated

# 보안 취약점 포함
npm audit

# 메이저 버전 업그레이드 포함 체크 (npx 필요)
npx npm-check-updates
```

### pip 프로젝트

```bash
# 구버전 패키지 목록
pip list --outdated

# requirements.txt 기반 확인
pip install pip-review
pip-review --local --interactive
```

### cargo 프로젝트

```bash
# 업데이트 가능한 크레이트 확인
cargo outdated

# 보안 감사
cargo audit
```

AI에게 결과를 그대로 붙여주고 우선순위를 잡아달라고 합니다:

```
현재 프로젝트의 npm outdated 결과야.
보안 위험도와 브레이킹 체인지 가능성 기준으로 업그레이드 우선순위를 정해줘.
패치 버전 → 마이너 버전 → 메이저 버전 순서로 구분해서 표로 정리해줘.
```

---

## Step 2: 브레이킹 체인지 사전 분석

메이저 버전 업그레이드는 반드시 AI와 함께 변경 사항을 먼저 파악합니다.

```bash
# 예: React 18 → 19 업그레이드 전 분석
```

AI 프롬프트:

```
{패키지명} v{현재 버전}에서 v{목표 버전}으로 올릴 때
브레이킹 체인지 목록을 알려줘.
우리 코드에서 영향받을 수 있는 패턴을 CHANGELOG 기준으로 정리해줘.
```

| 확인할 항목 | 방법 |
|------------|------|
| CHANGELOG / Release Notes | GitHub Releases 탭 |
| 마이그레이션 가이드 | 공식 문서 |
| TypeScript 타입 변경 | @types 패키지 diff |
| 제거된 API | 'deprecated since' 검색 |

---

## Step 3: 단계별 업그레이드 계획 수립

한 번에 모두 올리면 어디서 깨졌는지 추적하기 어렵습니다.

```
현재 package.json이야. 다음 우선순위로 업그레이드 플랜을 짜줘:
1. 패치/마이너 버전 (호환 가능)
2. 메이저 버전 (브레이킹 없는 것)
3. 메이저 버전 (코드 수정 필요한 것)

각 단계를 별도 브랜치로 분리해서 PR을 올리는 전략도 포함해줘.
```

---

## Step 4: 호환성 검사 + 자동 수정

패치/마이너 버전은 AI에게 한번에 맡겨도 됩니다.

```bash
# npm: 안전한 범위 내 자동 업데이트
npm update

# npx로 특정 패키지만 최신으로
npx npm-check-updates -u --target minor
npm install
```

메이저 버전 업그레이드 시 AI에게 자동 코드마이그레이션을 요청:

```
{패키지명} v{이전}에서 v{현재}로 올렸더니 타입 에러가 발생했어.
tsconfig와 에러 메시지를 첨부할게.
영향받는 파일을 전부 수정해줘.
```

---

## Step 5: 회귀 테스트

```bash
# 전체 테스트 실행
npm test
# 또는
pytest
# 또는
cargo test
```

테스트가 깨지면 AI에게 에러를 그대로 전달:

```
{패키지명} 업그레이드 후 테스트가 깨졌어.
에러 로그 첨부할게.
v{이전}와 v{현재}의 차이 중 원인을 찾고 수정해줘.
```

E2E 테스트가 없다면 AI에게 중요 경로를 먼저 커버하는 테스트를 요청하세요:

```
이 컴포넌트/함수에서 의존성 업그레이드 전에 스모크 테스트를 추가해줘.
핵심 기능 3가지를 커버하는 최소한의 테스트야.
```

---

## Step 6: Renovate로 자동화 설정

의존성 업그레이드를 일회성으로 끝내지 않고 자동화합니다.

```json
// renovate.json (레포 루트에 추가)
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "schedule": ["every weekend"],
  "packageRules": [
    {
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true,
      "automergeType": "pr"
    },
    {
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["dependency-upgrade", "review-needed"]
    }
  ],
  "prConcurrentLimit": 5
}
```

| 설정 | 설명 |
|------|------|
| `schedule` | 업데이트 실행 주기 |
| `automerge` | 패치/마이너는 자동 머지 |
| `prConcurrentLimit` | 동시에 열린 PR 최대 수 |
| `matchUpdateTypes: major` | 메이저 버전은 수동 검토 |

---

## Step 7: PR + 검토

```bash
# 업그레이드 내용을 브랜치로 분리
git checkout -b chore/dependency-upgrade-{package}-v{version}
git add package.json package-lock.json
git commit -m "chore(deps): upgrade {package} from v{old} to v{new}"
git push origin HEAD
```

PR 설명에 포함할 내용:

```markdown
## 변경 사항
- {패키지명}: v{이전} → v{현재}

## 브레이킹 체인지
- 없음 / 있다면 목록

## 영향받은 파일
- {파일 목록}

## 테스트
- [ ] 단위 테스트 통과
- [ ] 수동 확인 항목
```

---

## 체크리스트

- [ ] `npm outdated` / `pip list --outdated` 로 전체 현황 파악
- [ ] 메이저 버전 업그레이드 전 CHANGELOG 확인
- [ ] 패치/마이너 먼저, 메이저는 별도 브랜치
- [ ] 업그레이드 후 전체 테스트 실행
- [ ] 테스트 없는 핵심 경로는 AI에게 스모크 테스트 추가 요청
- [ ] renovate.json 설정으로 향후 업그레이드 자동화

---

## 흔한 실패 패턴

| 실수 | 해결 |
|------|------|
| 한 번에 모두 올리기 | 단계별로 분리, 커밋 단위 관리 |
| 테스트 없이 업그레이드 | 최소 스모크 테스트라도 먼저 작성 |
| CHANGELOG 안 읽기 | AI에게 브레이킹 체인지 요약 요청 |
| 잠금 파일 커밋 누락 | `package-lock.json`, `Cargo.lock` 반드시 포함 |
| 개발 의존성 방치 | devDependencies도 주기적으로 정리 |

---

## 다음 단계

→ [보안 감사 플레이북](./11-security-audit.md)
→ [CI 디버깅 플레이북](./31-ai-ci-debugging.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
