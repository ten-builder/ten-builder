# AI 에이전트 다중 저장소 동시 작업 워크플로우

> 여러 레포에 걸친 변경사항을 AI 에이전트로 일관성 있게 적용하는 실전 패턴

## 개요

마이크로서비스 구조에서 하나의 기능을 추가하면 최소 3~5개 레포를 동시에 수정해야 하는 경우가 많아요. API 스펙 변경이 백엔드, 프론트엔드, SDK, 문서 레포 모두에 영향을 주는 식이죠.

AI 에이전트 없이 이런 작업을 하면 순서를 놓치거나, 한 레포의 변경이 다른 레포와 맞지 않아 통합 테스트에서 실패하는 일이 생겨요. 이 워크플로우는 AI 에이전트가 의존성 순서를 분석하고, 레포별로 격리된 작업 공간을 만들어 PR 묶음을 일관되게 생성하는 방법을 다뤄요.

## 사전 준비

- 대상 레포 목록 및 로컬 클론 경로 파악
- 레포 간 의존성 관계 문서화 (없으면 이 워크플로우에서 작성)
- 각 레포에 `AGENTS.md` 또는 `CLAUDE.md` 존재 확인

## Step 1: 솔루션 루트 레포 구성

각 레포를 개별로 다루면 AI 에이전트의 컨텍스트가 분산돼요. 가벼운 조율 레포를 하나 만들어 전체 구조를 한눈에 볼 수 있게 해줘요.

```bash
mkdir multi-repo-root && cd multi-repo-root

# 각 레포를 서브디렉토리로 추가 (클론이 아닌 심볼릭 링크 또는 git submodule)
ln -s ~/projects/api-service ./api-service
ln -s ~/projects/web-client ./web-client
ln -s ~/projects/mobile-client ./mobile-client
ln -s ~/projects/shared-types ./shared-types
```

루트에 `AGENTS.md`를 작성해 레포 간 의존성을 명시해요:

```markdown
# AGENTS.md — Multi-Repo Root

## 레포 구조 및 의존성

| 레포 | 역할 | 의존 레포 |
|------|------|-----------|
| shared-types | 공통 타입 정의 | 없음 (최상위) |
| api-service | 백엔드 API | shared-types |
| web-client | 웹 프론트엔드 | shared-types, api-service |
| mobile-client | 모바일 앱 | shared-types, api-service |

## 변경 우선순위

shared-types → api-service → (web-client, mobile-client) 순서로 적용
```

## Step 2: 의존성 맵 기반 변경 계획 수립

AI 에이전트에게 변경 범위를 정의할 때 의존성 순서를 명시해요.

```bash
# 변경 태스크 파일 작성
cat > change-plan.md << 'EOF'
## 변경 목표
User 엔티티에 `timezone` 필드 추가

## 영향 레포 (의존성 순서대로)
1. shared-types — UserProfile 타입에 timezone?: string 추가
2. api-service — User 테이블 마이그레이션 + API 응답 포함
3. web-client — 프로필 편집 UI에 타임존 선택기 추가
4. mobile-client — 설정 화면에 타임존 섹션 추가

## 검증 기준
- shared-types: TypeScript 빌드 통과
- api-service: 마이그레이션 성공 + 단위 테스트 통과
- web/mobile: 스냅샷 테스트 통과
EOF
```

## Step 3: Git Worktree로 격리 작업 공간 생성

각 레포에서 독립 브랜치를 만들어 AI 에이전트가 충돌 없이 작업하게 해요.

```bash
# 각 레포에 worktree 생성
FEATURE_NAME="feat/user-timezone"

cd ~/projects/shared-types
git worktree add ../worktrees/shared-types-timezone -b "$FEATURE_NAME"

cd ~/projects/api-service
git worktree add ../worktrees/api-service-timezone -b "$FEATURE_NAME"

cd ~/projects/web-client
git worktree add ../worktrees/web-client-timezone -b "$FEATURE_NAME"

cd ~/projects/mobile-client
git worktree add ../worktrees/mobile-client-timezone -b "$FEATURE_NAME"
```

각 Worktree는 독립된 파일시스템을 가지므로 AI 에이전트가 동시에 여러 레포를 수정해도 충돌이 생기지 않아요.

## Step 4: 의존성 순서에 따라 순차 적용

```bash
# 1단계: 타입 정의 (상위 의존성 먼저)
cd ../worktrees/shared-types-timezone
claude "UserProfile 타입에 timezone?: string 추가하고 관련 타입들 업데이트해줘. 
변경 후 tsc --noEmit 실행해서 빌드 확인까지 해줘."

# 2단계: 백엔드 (타입 변경 반영)
cd ../worktrees/api-service-timezone
claude "shared-types의 UserProfile에 timezone 필드가 추가됐어. 
User 테이블에 timezone 컬럼 추가 마이그레이션 만들고, 
API 응답 스키마와 서비스 로직 업데이트해줘."

# 3단계: 클라이언트 (병렬 가능)
cd ../worktrees/web-client-timezone
claude "프로필 편집 폼에 타임존 선택기 추가해줘. 
Intl.supportedValuesOf('timeZone')으로 옵션 리스트 만들고,
기존 UserProfile 타입의 timezone 필드 사용해줘."
```

## Step 5: 크로스 레포 테스트

각 레포 변경 후 통합 관점에서 호환성 확인이 필요해요.

```bash
# 타입 호환성 검증
cd ../worktrees/api-service-timezone
npm link ../../worktrees/shared-types-timezone
npx tsc --noEmit  # shared-types 변경과 호환되는지 확인

# 계약 테스트 실행
cd ../worktrees/api-service-timezone
npm run test:contract  # API 스펙 변경 후 계약 테스트
```

## Step 6: PR 묶음 생성

```bash
# 각 레포에서 순서대로 PR 생성
repos=("shared-types" "api-service" "web-client" "mobile-client")
pr_urls=()

for repo in "${repos[@]}"; do
  cd ~/projects/$repo
  pr_url=$(gh pr create \
    --title "feat: add timezone field to UserProfile" \
    --body "Part of user timezone feature. See related PRs in other repos." \
    --base main 2>&1)
  pr_urls+=("$repo: $pr_url")
  echo "PR created: $pr_url"
done

# PR 간 연결 정보를 각 PR 본문에 추가
echo "Related PRs:"
printf '%s\n' "${pr_urls[@]}"
```

## 상태 추적 템플릿

| 레포 | 브랜치 | PR 상태 | 테스트 | 머지 순서 |
|------|--------|---------|--------|----------|
| shared-types | feat/user-timezone | 대기 중 | ✅ 통과 | 1 |
| api-service | feat/user-timezone | 대기 중 | ✅ 통과 | 2 |
| web-client | feat/user-timezone | 대기 중 | ✅ 통과 | 3 |
| mobile-client | feat/user-timezone | 대기 중 | ⏳ 진행 | 3 |

## 머지 순서 관리

의존성이 있는 레포는 순서대로 머지해야 해요. 자동화가 가능하다면:

```bash
#!/bin/bash
# 의존성 순서 보장 머지 스크립트
REPOS_IN_ORDER=("shared-types" "api-service" "web-client" "mobile-client")
BRANCH="feat/user-timezone"

for repo in "${REPOS_IN_ORDER[@]}"; do
  echo "Merging $repo..."
  
  # PR 번호 조회
  PR_NUM=$(gh pr list --repo "org/$repo" \
    --head "$BRANCH" --json number --jq '.[0].number')
  
  # CI 상태 확인 후 머지
  gh pr merge "$PR_NUM" --repo "org/$repo" --squash \
    --auto  # CI 통과 시 자동 머지
  
  # 다음 레포 작업 전 패키지 배포 대기 (npm publish 등)
  sleep 30
done
```

## 주의사항

| 상황 | 대응 |
|------|------|
| 레포 간 타입 불일치 | shared-types부터 다시 검토, 타입 변경 먼저 적용 |
| 한 레포 CI 실패 | 실패한 레포의 PR만 수정, 의존 레포는 대기 |
| 머지 순서 실수 | 하위 의존 레포 롤백 후 재배포 |
| 컨텍스트 부족 | 솔루션 루트의 AGENTS.md에 레포 관계 추가 보완 |

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 브랜치명 | `feat/{feature-name}` | 모든 레포에 동일 브랜치명 사용 |
| 병렬 실행 | 동일 의존성 레벨끼리 | 의존 없는 레포끼리 동시 작업 가능 |
| 머지 방식 | squash | 레포별 커밋 히스토리 정리 |
| 통합 테스트 | 계약 테스트 | 레포 간 API 호환성 검증 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
