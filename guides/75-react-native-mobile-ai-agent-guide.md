# React Native + Expo AI 에이전트 개발 가이드 2026

> 모바일 앱 개발에 AI 에이전트를 도입하는 실전 전략 — React Native, Expo, Claude Code로 iOS/Android 앱을 2배 빠르게 만들기

## 왜 모바일 개발에 AI 에이전트인가

웹 개발과 달리 모바일 개발은 플랫폼 파편화, 네이티브 브릿지, 빌드 파이프라인 복잡도가 높아 AI 에이전트 적용이 늦었습니다. 하지만 2026년 기준으로 Expo Skills, Claude Code, Callstack의 React Native 가이드라인이 정비되면서 **모바일 개발에서도 AI 에이전트가 실질적인 생산성 향상**을 만들어내고 있습니다.

실제 팀에서 검증된 수치:

- UI 컴포넌트 구현 시간: 평균 60% 단축
- 네이티브 모듈 설정 오류: 40% 감소
- E2E 테스트 작성: 70% 자동화 가능

## 사전 준비

- Node.js 20 이상
- Expo CLI (`npm install -g expo`)
- Claude Code 설치 및 구독
- Xcode 또는 Android Studio (시뮬레이터 실행용)

## Step 1: CLAUDE.md 모바일 프로젝트 설정

Claude Code가 React Native / Expo 프로젝트를 제대로 이해하려면 프로젝트 루트에 `CLAUDE.md`를 배치해야 합니다.

```markdown
# 프로젝트 컨텍스트

## 기술 스택

- React Native + Expo SDK 53
- TypeScript strict 모드
- Expo Router v4 (파일 기반 라우팅)
- NativeWind v4 (Tailwind 기반 스타일링)
- Zustand (전역 상태)
- React Query v5 (서버 상태)

## 디렉토리 구조

```
app/           # Expo Router 페이지
components/    # 재사용 UI 컴포넌트
features/      # 기능별 모듈 (hooks + 컴포넌트 + API)
lib/           # 유틸리티, 타입, 상수
assets/        # 이미지, 폰트
```

## 개발 규칙

- 모든 컴포넌트는 TypeScript로 작성
- Platform.select()로 iOS/Android 분기 처리
- 스타일은 NativeWind 클래스 우선, StyleSheet는 예외 케이스에만
- 네이티브 모듈은 항상 try-catch로 감싸기

## 주의사항

- `window`, `document` 등 웹 API는 사용 불가
- 이미지는 반드시 `require()` 또는 URI 방식
- async/await 사용 시 항상 에러 핸들링 포함
```

### 왜 이렇게 설정하는가

모바일 개발의 핵심 실수는 AI가 웹 API를 사용하는 코드를 생성하는 것입니다. `CLAUDE.md`에 플랫폼 제약을 명시하면 이런 오류가 크게 줄어듭니다.

## Step 2: Expo Skills 연동

2026년 기준 Expo는 AI 에이전트를 위한 공식 Skills 파일을 제공합니다. 이를 `CLAUDE.md`에 참조하면 빌드, 배포, 디버깅 워크플로우를 에이전트가 직접 실행할 수 있습니다.

```bash
# Expo Skills 파일 확인
curl -s https://docs.expo.dev/llms.txt | head -50

# CLAUDE.md에 Expo Skills 참조 추가
echo "\n## 참조 문서\n@https://docs.expo.dev/llms.txt" >> CLAUDE.md
```

Expo Skills를 통해 AI 에이전트가 직접 수행할 수 있는 작업:

| 작업 | 에이전트 명령 |
|------|-------------|
| 새 스크린 생성 | `create a new screen for user profile in app/(tabs)/profile.tsx` |
| 네이티브 권한 추가 | `add camera permission to app.json and implement permission request` |
| EAS 빌드 설정 | `configure EAS Build for iOS production` |
| OTA 업데이트 | `set up Expo Updates with channel staging` |

## Step 3: 컴포넌트 개발 워크플로우

AI 에이전트로 React Native 컴포넌트를 만들 때 효과적인 프롬프트 패턴입니다.

### 프롬프트 패턴: 디자인 → 구현

```
[컴포넌트명] 컴포넌트를 만들어줘.

요구사항:
- 용도: 상품 카드 (이미지, 제목, 가격, 찜하기 버튼)
- 플랫폼: iOS/Android 동일하게
- 스타일: NativeWind 사용
- 접근성: accessibilityLabel 포함
- 애니메이션: 찜 버튼 탭 시 heart 애니메이션 (Reanimated v3)

타입 정의도 함께 작성해줘.
```

### 자주 쓰는 컴포넌트 템플릿 요청

```bash
# 스크린 컴포넌트 생성
claude "app/(tabs)/home.tsx 스크린을 만들어줘. 
  - FlatList로 상품 목록 표시
  - pull-to-refresh 포함
  - 로딩/에러/빈 상태 처리
  - React Query로 /api/products 호출"

# 공통 컴포넌트 생성  
claude "components/ui/Button.tsx 버튼 컴포넌트를 만들어줘.
  - variant: primary, secondary, ghost, destructive
  - size: sm, md, lg
  - loading state (ActivityIndicator)
  - disabled state"
```

## Step 4: 네이티브 기능 통합

AI 에이전트가 실수하기 쉬운 네이티브 기능 영역에서 올바른 접근법을 정의합니다.

### 카메라 / 갤러리

```typescript
// AI 에이전트에게 이렇게 요청하면 정확한 코드를 얻을 수 있습니다
// "expo-image-picker로 카메라와 갤러리에서 이미지를 선택하는 hook을 만들어줘.
//  iOS의 Info.plist 권한과 Android의 manifest 권한 설정도 포함해서."
```

AI가 생성해주는 올바른 패턴:

```typescript
import * as ImagePicker from 'expo-image-picker';

export function useImagePicker() {
  const pickFromCamera = async () => {
    const { status } = await ImagePicker.requestCameraPermissionsAsync();
    if (status !== 'granted') {
      throw new Error('카메라 권한이 필요합니다');
    }
    
    const result = await ImagePicker.launchCameraAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.8,
    });
    
    if (!result.canceled) {
      return result.assets[0];
    }
    return null;
  };
  
  return { pickFromCamera };
}
```

### 푸시 알림 설정

```bash
# AI 에이전트에게 Expo Notifications 전체 설정을 위임할 수 있습니다
claude "expo-notifications로 푸시 알림을 설정해줘.
  - 권한 요청 로직
  - 토큰 발급 및 서버 전송
  - 포그라운드/백그라운드 핸들러
  - app.json 플러그인 설정"
```

## Step 5: 테스트 자동화

모바일 테스트는 설정이 복잡해서 개발자들이 자주 건너뛰는 부분입니다. AI 에이전트를 활용하면 테스트 작성 비용을 크게 낮출 수 있습니다.

### 단위 테스트 (Jest + React Native Testing Library)

```bash
claude "components/ProductCard.tsx에 대한 테스트를 작성해줘.
  - 렌더링 테스트 (스냅샷 포함)
  - 찜하기 버튼 클릭 이벤트
  - 로딩 상태 표시
  - 에러 상태 표시
  - 접근성 레이블 확인"
```

### E2E 테스트 (Maestro)

Detox보다 설정이 간단한 Maestro로 AI 에이전트가 E2E 시나리오를 생성할 수 있습니다:

```yaml
# AI 에이전트에게 Maestro 플로우 작성을 요청한 결과 예시
appId: com.yourapp.example
---
- launchApp
- tapOn: "로그인"
- inputText:
    id: "email-input"
    text: "test@example.com"
- inputText:
    id: "password-input"  
    text: "password123"
- tapOn: "로그인 버튼"
- assertVisible: "홈 화면"
```

```bash
# AI에게 특정 유저 플로우 E2E 테스트 생성 요청
claude "회원가입 플로우 E2E 테스트를 Maestro YAML로 작성해줘.
  이메일 입력 → 인증 코드 확인 → 프로필 설정 → 완료 화면 순서"
```

## Step 6: 성능 최적화

React Native 성능 문제의 80%는 JS/Native 브릿지 병목과 리렌더링에서 발생합니다. AI 에이전트로 이를 진단하고 수정하는 방법입니다.

### AI 진단 요청 패턴

| 증상 | 프롬프트 |
|------|---------|
| FlatList 스크롤 버벅임 | `FlatList 성능 최적화해줘. keyExtractor, getItemLayout, windowSize 적용` |
| 이미지 로딩 느림 | `expo-image로 이미지 캐싱 + 프로그레시브 로딩 구현해줘` |
| 불필요한 리렌더링 | `이 컴포넌트에서 불필요한 리렌더링 찾아서 memo, useCallback, useMemo 적용해줘` |
| 앱 시작 속도 느림 | `Metro 번들 분석해서 초기 로딩 최적화 방법 제안해줘` |

### Reanimated로 부드러운 애니메이션

```bash
# AI에게 60fps 애니메이션 구현 위임
claude "제품 카드 스와이프 삭제 애니메이션을 Reanimated v3로 구현해줘.
  - 왼쪽으로 스와이프 시 삭제 버튼 노출
  - 충분히 스와이프하면 자동 삭제
  - 스프링 애니메이션으로 자연스럽게
  - useAnimatedGestureHandler 사용"
```

## Step 7: CI/CD 파이프라인 설정

```bash
# EAS Build + GitHub Actions 설정을 AI에게 위임
claude "EAS Build와 GitHub Actions를 연결해줘.
  - PR 생성 시 development 빌드 자동 트리거
  - main 머지 시 preview 채널 OTA 업데이트
  - .env 시크릿을 EAS Secret으로 관리
  - 빌드 완료 시 Slack 알림"
```

AI가 생성하는 `.github/workflows/eas-build.yml` 예시:

```yaml
name: EAS Build
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - uses: expo/expo-github-action@v8
        with:
          expo-version: latest
          token: ${{ secrets.EXPO_TOKEN }}
      - name: Build on EAS
        run: eas build --platform all --non-interactive --profile preview
```

## 실전 팁: AI 에이전트가 자주 실수하는 부분

React Native 개발에서 AI가 생성한 코드를 검토할 때 특히 확인해야 할 항목입니다:

| 확인 항목 | 이유 |
|----------|------|
| `window` / `document` 사용 여부 | 웹 전용 API — RN에서 즉시 오류 |
| `import { useRouter } from 'next/router'` | Next.js 라우터 — Expo Router와 혼동 |
| `<div>`, `<span>` 태그 | HTML 태그는 RN에서 사용 불가 |
| `fetch` 없이 `axios` 직접 사용 | RN에서는 fetch 기본 지원, 설정 확인 필요 |
| StyleSheet 없이 인라인 스타일 남발 | 성능에 영향, NativeWind 또는 StyleSheet 권장 |

## 체크리스트

- [ ] `CLAUDE.md`에 플랫폼 제약과 기술 스택 명시
- [ ] `@https://docs.expo.dev/llms.txt` 참조 추가
- [ ] 컴포넌트 요청 시 플랫폼, 스타일 도구, 접근성 요구사항 포함
- [ ] AI 생성 코드에서 웹 전용 API 사용 여부 확인
- [ ] 네이티브 권한 요청 로직 반드시 검토
- [ ] E2E 테스트 자동 생성으로 핵심 플로우 커버

## 다음 단계

→ [AI 에이전트 CLAUDE.md 설계 가이드](./52-custom-rules-file-design.md)

→ [AI 에이전트 기반 E2E 테스트 워크플로우](../workflows/ai-e2e-test-generation.md)

→ [Expo Skills 공식 문서](https://docs.expo.dev/llms.txt)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
