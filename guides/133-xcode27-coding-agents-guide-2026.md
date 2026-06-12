# Xcode 27 코딩 에이전트 실전 가이드 2026

> WWDC 2026에서 공개된 Xcode 27은 Claude, Gemini, Codex 에이전트를 IDE에 직접 통합했다. 설치부터 실전 워크플로우까지 한 번에 정리한다.

## Xcode 27이 달라진 점

2026년 6월 8일 WWDC 2026에서 공개된 Xcode 27 베타는 AI 코딩 에이전트를 IDE의 핵심 기능으로 탑재했다. 기존에는 Claude Code 같은 외부 CLI를 터미널에서 따로 실행해야 했지만, 이제 Xcode 안에서 에이전트와 대화하고, 테스트를 실행하고, Simulator로 결과를 바로 확인할 수 있다.

주요 변화:
- **에이전트 퍼스트 IDE**: Anthropic(Claude), Google(Gemini), OpenAI(Codex) 에이전트가 네이티브 통합
- **Apple Silicon 전용**: Intel 지원 종료, Neural Engine 활용으로 30% 성능 향상
- **Device Hub**: 여러 시뮬레이터·실기기를 한 화면에서 관리
- **ACP(Agent Client Protocol) 지원**: 외부 에이전트와 Xcode 간 표준 통신 프로토콜
- **플러그인 시스템**: Skills, MCP 서버, ACP 에이전트 설정을 플러그인으로 확장 가능

## 사전 준비

- macOS 26 이상 + Apple Silicon Mac
- Apple Developer Program 가입 (베타 접근 필요)
- Xcode 27 베타 설치 (`xcode-select` 재설정 필요)

```bash
# 커맨드 라인 도구를 Xcode 27로 전환
sudo xcode-select -s /Applications/Xcode-beta.app

# 확인
xcrun swift --version
# agent skills 명령어 확인
xcrun agent skills --help
```

> **Intel Mac 사용자:** Xcode 27은 Apple Silicon 전용이다. Intel Mac에서는 Xcode 26.x 이하를 계속 사용해야 한다.

## Step 1: 에이전트 연결 설정

### 1-1. Xcode 설정 열기

`Xcode → Settings → Coding Intelligence → Agents`

에이전트 목록에서 사용할 AI를 선택하고 API 키 또는 구독 인증을 완료한다.

| 에이전트 | 인증 방식 | 비고 |
|----------|----------|------|
| Claude (Anthropic) | API Key 또는 Claude Code 구독 | Max 플랜 권장 |
| Gemini (Google) | Google 계정 (Antigravity) | Gemini 2.5 Pro 사용 |
| Codex (OpenAI) | OpenAI API Key | ChatGPT Plus 연동 가능 |
| Apple Agent Skills | 자동 (Xcode 내장) | Swift/SwiftUI 전용 태스크 |

### 1-2. 보안 레이어 활성화

Xcode 27은 에이전트가 파일시스템에 접근할 때 모니터링·제어하는 보안 레이어를 제공한다.

`Settings → Coding Intelligence → Security`에서 **File System Monitoring** 활성화를 권장한다.

### 1-3. 플러그인 설정 (선택)

MCP 서버나 커스텀 ACP 에이전트를 연결하려면 플러그인을 설치한다.

```bash
# 플러그인 URL로 설치 (예: GitHub MCP)
xcrun agent plugin install --url https://example.com/github-mcp-plugin.xcagentplugin
```

플러그인은 `/xcode-slash` 커맨드로 실행 가능하다. 예: `/github-pr`

## Step 2: Conversations 뷰에서 플래닝하기

Xcode 27의 핵심은 **Conversations 뷰**다. 에이전트와 멀티턴 대화로 기능을 설계하고, 에이전트가 직접 코드를 작성·테스트·수정한다.

### 기본 흐름

1. `Cmd+Shift+A`로 Conversations 뷰 열기
2. 에이전트 선택 (Claude, Gemini, Codex 중 택일)
3. 요청 입력

```
Swift로 사용자 프로필 화면을 구현해줘.
- SwiftUI 사용
- 이름, 이메일, 프로필 사진 표시
- 편집 모드 지원
- iOS 27 디자인 가이드라인 따를 것
```

에이전트가 계획을 제시하면 승인(Accept)하거나 수정 요청을 보낸다.

### 에이전트 작업 순서

```
[계획 단계]
에이전트: "다음 파일을 생성하겠습니다:
- Views/ProfileView.swift
- ViewModels/ProfileViewModel.swift
- Models/UserProfile.swift
진행할까요?"

[구현 단계]
에이전트: 코드 작성 → 테스트 실행 → Playground/Simulator 검증

[검증 단계]
에이전트: 테스트 통과 확인 → 코드 변경사항 요약 → 완료 보고
```

## Step 3: Device Hub 활용

Device Hub는 여러 시뮬레이터와 실기기를 한 화면에서 관리하는 기능이다. 에이전트가 코드를 작성하면 **자동으로** Device Hub에서 결과를 확인한다.

### 주요 활용 패턴

| 시나리오 | 에이전트 지시 방법 |
|---------|-----------------|
| 다크 모드 확인 | "iPhone 16 Pro 다크 모드에서 프로필 화면 확인해줘" |
| 다양한 기기 크기 | "iPhone SE와 iPhone 16 Pro Max 두 기기에서 레이아웃 확인" |
| 접근성 테스트 | "VoiceOver 활성화 상태에서 모든 버튼이 접근 가능한지 확인" |
| 성능 확인 | "에너지 영향(Energy Impact)이 낮은지 Instruments로 프로파일링해줘" |

## Step 4: Apple Agent Skills 활용

Xcode 27에는 Apple이 직접 만든 **Agent Skills**가 내장되어 있다. Swift·SwiftUI 전용 작업에 최적화되어 있어 서드파티 에이전트보다 정확하다.

```bash
# 사용 가능한 스킬 목록 확인
xcrun agent skills list
```

자주 쓰는 내장 스킬:

| 스킬 | 용도 |
|------|------|
| `/localize` | 앱의 문자열을 다국어로 자동 번역 |
| `/ui-prototype` | 설명으로 SwiftUI 뷰 프로토타입 생성 |
| `/accessibility-audit` | 접근성 이슈 자동 탐지 및 수정 |
| `/test-generate` | 기존 코드 기반 단위 테스트 자동 생성 |
| `/swift-migration` | 이전 Swift 버전 코드를 최신 패턴으로 마이그레이션 |

## Step 5: Claude Code + Xcode 27 역할 분담

Xcode 27 에이전트는 UI·Swift 코드 작성에 강하지만, 복잡한 백엔드 로직이나 터미널 작업에는 Claude Code가 더 적합하다.

| 작업 유형 | 추천 도구 |
|----------|---------|
| SwiftUI 뷰 구현 | Xcode 27 에이전트 (Apple Skills) |
| Swift 알고리즘·비즈니스 로직 | Xcode 27 에이전트 (Claude/Gemini) |
| 서버 API 설계 및 구현 | Claude Code (터미널) |
| CI/CD 스크립트 설정 | Claude Code |
| 코드베이스 전반 리팩토링 | Claude Code (컨텍스트 더 넓음) |
| Simulator UI 테스트 | Xcode 27 에이전트 |
| 배포·앱스토어 제출 | Claude Code + Fastlane |

### 워크플로우 예시

```bash
# 1. 서버 API를 Claude Code로 구현
claude "REST API 서버 Node.js로 구현, /users, /profile 엔드포인트 포함"

# 2. iOS 클라이언트는 Xcode 27 에이전트로 구현
# Xcode → Conversations 뷰에서:
# "방금 만든 REST API와 통신하는 Swift NetworkManager 구현해줘"
# "ProfileView를 API 데이터와 연결해줘"

# 3. 통합 테스트는 두 도구 모두 활용
xcrun agent skills /test-generate --target NetworkManagerTests
```

## Foundation Models 프레임워크 (iOS 앱 내 AI 기능)

Xcode 27과 함께 **Foundation Models** 프레임워크도 업데이트됐다. 앱 내에서 Apple 온디바이스 AI를 Swift API로 직접 호출할 수 있다.

```swift
import FoundationModels

// 기본 텍스트 생성
let session = LanguageModelSession()
let response = try await session.respond(to: "Swift 코드에서 메모리 누수를 찾는 방법은?")
print(response.content)

// 이미지 입력 지원 (iOS 27+)
let imageInput = LanguageModelInput.image(profileImage)
let description = try await session.respond(to: "이 이미지를 설명해줘", with: [imageInput])

// 스트리밍 응답
for try await token in session.streamResponse(to: prompt) {
    updateUI(with: token)
}
```

주요 특징:
- **온디바이스 처리**: Private Cloud Compute 연동으로 서버 없이 처리
- **Dynamic Profiles**: 작업 복잡도에 따라 모델 크기 자동 선택
- **커스텀 LLM 연결**: 서드파티 모델을 동일 API로 연결 가능

```swift
// 커스텀 LLM 프로바이더 연결
struct MyCustomProvider: LanguageModelExecutor {
    func respond(to request: LanguageModelExecutorGenerationRequest,
                 model: MyLanguageModel,
                 streamingInto channel: LanguageModelExecutorGenerationChannel) async throws {
        // 스트리밍 토큰 전송
        await channel.send(token: "응답 텍스트")
    }
}
```

## 체크리스트

- [ ] Xcode 27 베타 설치 및 커맨드 라인 도구 전환
- [ ] 에이전트 API 키 설정 (Claude, Gemini, Codex 중 택일 이상)
- [ ] 보안 레이어 (File System Monitoring) 활성화
- [ ] Agent Skills 목록 확인 및 자주 쓰는 스킬 파악
- [ ] Device Hub에서 테스트 기기 설정
- [ ] Claude Code + Xcode 에이전트 역할 분담 기준 정의
- [ ] Foundation Models 프레임워크 필요 여부 검토

## 알려진 제한사항 (베타 기준)

| 항목 | 현재 상태 |
|------|---------|
| 정식 출시 | 2026년 9월 예정 |
| Intel Mac 지원 | 없음 (Apple Silicon 전용) |
| 에이전트 작업 동시 실행 | 베타에서는 1개씩 순차 처리 |
| Foundation Models 외부 모델 | 일부 API 미완성 상태 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
