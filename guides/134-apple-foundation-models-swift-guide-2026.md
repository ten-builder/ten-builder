# Apple Foundation Models 실전 가이드 2026 — 온디바이스 AI를 Swift로 구현하기

> API 키 없이 무료로 iOS/macOS 앱에 AI를 내장하는 방법 — `LanguageModelSession`부터 Tool Calling까지

## 왜 지금 Foundation Models인가

WWDC 2026에서 Apple은 Foundation Models 프레임워크를 iOS 26, macOS 26, visionOS 26에 정식 탑재했다. 앱 내에서 Apple Intelligence의 온디바이스 LLM에 직접 접근할 수 있고, 인터넷 연결 없이 실행되며, API 비용도 없다.

클라우드 AI와 비교했을 때 세 가지 핵심 차이가 있다:

| 항목 | Foundation Models | 클라우드 API |
|------|------------------|------------|
| 실행 위치 | 기기 내부 | 외부 서버 |
| 비용 | 무료 | 토큰당 과금 |
| 오프라인 | 가능 | 불가 |
| 프라이버시 | 기기 밖으로 데이터 미전송 | 서버 전송 |

단점은 모델 크기의 한계다. 복잡한 추론, 대규모 코드 생성은 클라우드 모델이 낫다. 그래서 Foundation Models는 Claude Code, Antigravity CLI 같은 도구와 역할을 나눠 쓰는 게 현실적이다.

## 사전 준비

- Xcode 27 이상
- iOS 26 / macOS 26 SDK
- Apple Developer 계정 (개발 중 디바이스 테스트 필요)

시뮬레이터에서도 작동하지만, 온디바이스 성능 측정은 실제 기기에서 해야 한다.

## Step 1: 기본 텍스트 생성

```swift
import FoundationModels

// 가장 단순한 사용 예
let session = LanguageModelSession()

let response = try await session.respond(
    to: "Swift에서 async/await를 사용하는 이유를 2문장으로 설명해줘"
)
print(response.content)
```

`LanguageModelSession`을 생성하면 즉시 온디바이스 모델에 연결된다. `respond(to:)` 호출 한 번으로 결과를 받는다.

시스템 지시사항을 추가하면 세션 전체에 일관된 컨텍스트가 적용된다:

```swift
let session = LanguageModelSession(
    instructions: """
    당신은 Swift 코딩 어시스턴트입니다.
    항상 간결하고 실용적인 코드 예제를 제공하세요.
    최신 Swift 문법(6.0+)을 사용하세요.
    """
)
```

## Step 2: 구조화된 출력 — @Generable

Foundation Models의 핵심 기능은 Swift 타입을 직접 받는 구조화된 출력이다. JSON 파싱이 필요 없다.

```swift
import FoundationModels

@Generable
struct CodeReview {
    @Guide("코드의 주요 문제점 목록")
    var issues: [String]
    
    @Guide("개선 제안 사항")
    var suggestions: [String]
    
    @Guide("전체 품질 점수 1-10")
    var qualityScore: Int
    
    @Guide("간단한 총평")
    var summary: String
}

let session = LanguageModelSession(
    instructions: "Swift 코드를 리뷰하는 전문가입니다."
)

let codeToReview = """
func fetchUser(id: String) {
    let url = URL(string: "https://api.example.com/user/\(id)")!
    let data = try! Data(contentsOf: url)
    let user = try! JSONDecoder().decode(User.self, from: data)
    return user
}
"""

let review = try await session.respond(
    to: "다음 Swift 코드를 리뷰해주세요:\n\(codeToReview)",
    generating: CodeReview.self
).content

print("품질 점수: \(review.qualityScore)/10")
print("주요 문제:")
review.issues.forEach { print("  - \($0)") }
```

`@Guide` 어노테이션이 모델에게 각 필드의 의미를 설명한다. 타입 제약도 자동으로 적용된다.

## Step 3: 스트리밍 응답

긴 응답을 기다리지 않고 실시간으로 UI를 업데이트하려면 스트리밍을 쓴다:

```swift
import SwiftUI
import FoundationModels

struct ContentView: View {
    @State private var generatedText = ""
    let session = LanguageModelSession()
    
    var body: some View {
        VStack {
            ScrollView {
                Text(generatedText)
                    .padding()
            }
            
            Button("코드 설명 생성") {
                Task {
                    generatedText = ""
                    let stream = session.streamResponse(
                        to: "클로저와 함수의 차이를 Swift 예제로 설명해줘"
                    )
                    for try await partial in stream {
                        generatedText = partial.content
                    }
                }
            }
        }
    }
}
```

`streamResponse`는 `AsyncSequence`를 반환한다. `for await` 루프에서 각 청크를 받을 때마다 UI가 업데이트된다.

구조화된 타입도 스트리밍으로 받을 수 있다:

```swift
@Generable
struct Itinerary {
    @Guide("각 날짜별 일정")
    var days: [DayPlan]
    
    @Guide("전체 여행 요약")
    var summary: String
}

@Generable
struct DayPlan {
    var date: String
    var activities: [String]
}

let stream = session.streamResponse(
    to: "3일간 제주도 여행 일정을 만들어줘",
    generating: Itinerary.self
)

for try await partial in stream {
    // partial은 PartiallyGenerated<Itinerary> 타입
    // 아직 완성되지 않은 필드는 nil
    if let days = partial.days {
        print("현재까지 \(days.count)일 일정 완성")
    }
}
```

## Step 4: Tool Calling — 기기 데이터 연동

Tool Calling은 모델이 앱의 실제 데이터에 접근하게 해주는 핵심 기능이다. 연락처, 캘린더, 위치 정보를 AI와 연동할 수 있다.

```swift
import FoundationModels

// 도구 정의
struct GetWeatherTool: Tool {
    let name = "get_weather"
    let description = "특정 도시의 현재 날씨 정보를 가져옵니다"
    
    @Generable
    struct Input {
        @Guide("날씨를 조회할 도시 이름")
        var city: String
    }
    
    func call(arguments: Input) async throws -> ToolOutput {
        // 실제 구현에서는 날씨 API 호출
        let weatherData = "서울: 맑음, 23°C, 습도 45%"
        return ToolOutput(weatherData)
    }
}

// 세션에 도구 등록
let session = LanguageModelSession(
    instructions: "날씨 정보를 활용해 도움이 되는 조언을 제공합니다.",
    tools: [GetWeatherTool()]
)

let response = try await session.respond(
    to: "서울 날씨에 맞는 오늘 옷차림 추천해줘"
)
// 모델이 자동으로 get_weather 도구를 호출하고, 결과를 바탕으로 답변 생성
print(response.content)
```

여러 도구를 조합하면 더 복잡한 시나리오가 가능하다:

```swift
let session = LanguageModelSession(
    instructions: "사용자의 일정을 관리하는 어시스턴트입니다.",
    tools: [
        GetCalendarEventsTool(),
        AddCalendarEventTool(),
        GetContactsTool()
    ]
)
```

## Step 5: 동적 스키마

컴파일 타임에 타입을 알 수 없는 경우 런타임에 스키마를 정의할 수 있다:

```swift
// 사용자가 직접 구조를 정의하는 경우
func generateStructuredData(fields: [(name: String, type: String)]) async throws -> [String: Any] {
    var properties: [String: JSONSchema] = [:]
    
    for field in fields {
        switch field.type {
        case "String":
            properties[field.name] = .string
        case "Int":
            properties[field.name] = .integer
        case "Bool":
            properties[field.name] = .boolean
        default:
            properties[field.name] = .string
        }
    }
    
    let schema = JSONSchema.object(properties: properties)
    let session = LanguageModelSession()
    
    // 동적 스키마로 응답 생성
    let result = try await session.respond(
        to: "샘플 데이터를 생성해주세요",
        schema: schema
    )
    
    return result.content
}
```

## 실전 패턴: Claude Code와의 역할 분담

Foundation Models만으로 모든 AI 기능을 처리하려고 하면 한계가 있다. 실전에서는 역할을 나눠 쓰는 게 효과적이다.

| 작업 | 권장 도구 | 이유 |
|------|----------|------|
| UI 텍스트 생성 | Foundation Models | 빠르고, 오프라인 가능 |
| 간단한 분류/태깅 | Foundation Models | 지연 없음, 무료 |
| 앱 데이터 질의응답 | Foundation Models | 프라이버시 보장 |
| 복잡한 코드 생성 | Claude Code | 품질이 중요한 경우 |
| 다국어 번역 (고품질) | 클라우드 API | 모델 크기 필요 |
| 실시간 정보 조회 | Antigravity CLI + 웹 검색 | 온디바이스 불가 |

```swift
// 예시: 로컬 우선, 복잡한 경우에만 클라우드
func generateCodeExplanation(code: String) async throws -> String {
    let localSession = LanguageModelSession()
    
    // 코드 길이 기준으로 로컬/클라우드 선택
    if code.count < 500 {
        // 짧은 코드는 온디바이스로
        let response = try await localSession.respond(
            to: "다음 코드를 설명해줘:\n\(code)"
        )
        return response.content
    } else {
        // 긴 코드는 클라우드 API로 전환
        return try await callClaudeAPI(code: code)
    }
}
```

## 오류 처리

Foundation Models는 기기 상태, 모델 가용성에 따라 실패할 수 있다:

```swift
do {
    let response = try await session.respond(to: prompt)
    return response.content
} catch LanguageModelSession.Error.notAvailable {
    // Foundation Models를 지원하지 않는 기기
    return fallbackToCloudAPI(prompt: prompt)
} catch LanguageModelSession.Error.safetyFilter {
    // 안전 필터에 걸린 경우
    return "요청을 처리할 수 없습니다."
} catch {
    // 기타 오류
    print("오류: \(error)")
    throw error
}
```

## 체크리스트

- [ ] `@Generable` 타입에 `@Guide` 어노테이션으로 각 필드 설명 추가
- [ ] 스트리밍 응답으로 긴 생성 작업의 UX 개선
- [ ] Tool Calling으로 앱 데이터와 AI 연동
- [ ] Foundation Models 실패 시 클라우드 API로 fallback 처리
- [ ] 실제 기기에서 성능 측정 (시뮬레이터는 참고용)
- [ ] 시스템 지시사항을 세션 레벨에서 한 번만 설정

## 다음 단계

- Xcode 27 코딩 에이전트 환경 → [guides/133-xcode27-coding-agents-guide-2026.md](133-xcode27-coding-agents-guide-2026.md)
- 온디바이스 AI와 클라우드 AI 조합 → [workflows/ollama-claude-hybrid-workflow.md](../workflows/ollama-claude-hybrid-workflow.md)

---

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
