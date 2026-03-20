# AI 크로스 언어 마이그레이션 워크플로우

> AI 코딩 에이전트로 프로젝트를 다른 프로그래밍 언어로 전환하는 워크플로우 — 패턴 매핑, 테스트 이관, 점진적 전환

## 개요

Python 프로토타입을 Rust로 옮기거나, JavaScript 프로젝트를 TypeScript 너머 Go로 전환하고 싶을 때가 있어요. 전통적으로 언어 마이그레이션은 "처음부터 다시 짜기"와 거의 같은 의미였는데, AI 코딩 도구를 사용하면 패턴 매핑과 코드 변환을 체계적으로 할 수 있어요.

핵심은 한 번에 전체를 바꾸지 않는 거예요. 모듈 단위로 전환하고, 매 단계마다 테스트로 검증하는 점진적 접근이 안전해요.

## 사전 준비

- 소스 언어와 타겟 언어의 개발 환경 모두 설정
- Claude Code 또는 Cursor Agent 설정
- 소스 프로젝트의 테스트 스위트 (전환 검증 기준)
- Git 레포 + 별도 브랜치

## 전체 흐름

```
코드베이스 분석 → 패턴 매핑 → 모듈 우선순위 결정 → 변환 + 테스트 → 통합 검증 → 점진적 교체
      ↑                                                              ↓
      └─────────────── 롤백 (문제 발생 시) ─────────────────────────────┘
```

## Step 1: 소스 코드베이스 분석

전환하기 전에 현재 코드의 구조와 의존성을 정확히 파악해요.

### 프로젝트 구조 파악

```bash
# 파일별 코드 라인 수 분석
find src/ -name "*.py" | xargs wc -l | sort -n

# 의존성 그래프 확인
pip install pydeps
pydeps src/main.py --max-bacon 3
```

### AI에게 분석 요청

```
이 프로젝트의 모듈 간 의존성을 분석해줘.
- 각 모듈의 역할과 크기
- 외부 라이브러리 의존성 목록
- 타겟 언어(Rust)에 대응하는 라이브러리 매핑
- 전환 난이도별 분류 (쉬움/보통/어려움)
```

## Step 2: 패턴 매핑 테이블 생성

소스 언어와 타겟 언어 사이의 패턴을 미리 정리하면, AI가 일관된 코드를 생성해요.

### Python → Rust 매핑 예시

| Python 패턴 | Rust 대응 | 주의 사항 |
|-------------|-----------|----------|
| `dict` | `HashMap<K, V>` | 소유권 주의 |
| `list comprehension` | `iter().map().collect()` | 타입 명시 필요 |
| `try/except` | `Result<T, E>` + `?` 연산자 | 에러 타입 정의 |
| `class + inheritance` | `struct + trait` | 상속 → 컴포지션 전환 |
| `async/await` | `tokio::spawn` | 런타임 선택 필요 |
| `None` | `Option<T>` | 패턴 매칭 활용 |

### JavaScript → Go 매핑 예시

| JS 패턴 | Go 대응 | 주의 사항 |
|---------|---------|----------|
| `Promise/async` | `goroutine + channel` | 동시성 모델 차이 |
| `object spread` | struct 복사 | 명시적 필드 복사 |
| `null/undefined` | 포인터 또는 zero value | nil 체크 필수 |
| `class` | `struct + method` | 인터페이스 활용 |
| `npm package` | Go module | 생태계 차이 큼 |

### AI에게 매핑 테이블 요청

```
Python에서 Rust로 전환할 때 자주 나오는 패턴을 표로 정리해줘.
각 패턴에 대해:
- 소스 코드 예시 (3줄 이내)
- 변환된 코드 예시
- 주의할 점
```

## Step 3: 모듈 우선순위 결정

전체를 한 번에 전환하면 디버깅이 불가능해요. 모듈별로 우선순위를 정하세요.

### 우선순위 기준

| 순서 | 대상 | 이유 |
|------|------|------|
| 1순위 | 유틸리티/헬퍼 모듈 | 의존성 없음, 단위 테스트 쉬움 |
| 2순위 | 데이터 모델/타입 | 나머지 모듈의 기반 |
| 3순위 | 비즈니스 로직 | 핵심이지만 테스트로 검증 가능 |
| 4순위 | I/O, API 레이어 | 외부 의존성 많음, 마지막에 전환 |
| 5순위 | 프레임워크 바인딩 | 대응 프레임워크 선택이 필요 |

### FFI 브릿지 전략

전환 중간에 두 언어가 공존해야 할 때 유용해요.

```bash
# Python에서 Rust 모듈 호출 (PyO3)
pip install maturin
maturin init --bindings pyo3

# Node.js에서 Rust 모듈 호출 (napi-rs)
npm install @napi-rs/cli
napi init
```

이 방식으로 전환된 모듈을 바로 기존 코드에서 사용할 수 있어요.

## Step 4: AI로 모듈별 변환

### 변환 프롬프트 패턴

```
아래 Python 모듈을 Rust로 변환해줘.

규칙:
1. 패턴 매핑 테이블을 따라줘 (첨부)
2. 에러 처리는 thiserror + anyhow 조합으로
3. 테스트 코드도 같이 변환해줘
4. 주석은 원본의 의도를 유지하되 Rust 관용구로

파일: src/utils/parser.py
테스트: tests/test_parser.py
```

### 변환 결과 검증 프롬프트

```
변환된 Rust 코드를 원본 Python과 비교해줘.
- 빠진 기능이 있는지
- 에러 핸들링이 동등한지
- 엣지 케이스 처리가 동일한지
- 성능상 주의할 차이점
```

### 배치 변환 스크립트

여러 파일을 순차적으로 변환할 때:

```bash
#!/bin/bash
# convert_modules.sh

MODULES=("utils/parser" "utils/validator" "models/user" "models/config")

for mod in "${MODULES[@]}"; do
    echo "=== Converting $mod ==="

    # 소스 파일 확인
    if [ ! -f "python_src/${mod}.py" ]; then
        echo "SKIP: $mod not found"
        continue
    fi

    # AI 변환 후 결과를 Rust 프로젝트에 배치
    RUST_PATH="rust_src/src/$(echo $mod | tr '/' '_').rs"
    echo "Output: $RUST_PATH"

    # 컴파일 체크
    cargo check 2>&1 | tail -5
    echo ""
done
```

## Step 5: 테스트 이관 전략

테스트가 전환의 "정답지" 역할을 해요.

### 3단계 테스트 전략

```
[1단계] 단위 테스트 → 모듈별 변환 직후 실행
[2단계] 통합 테스트 → FFI 브릿지 연결 후 실행
[3단계] E2E 테스트  → 전체 전환 후 실행
```

### 테스트 동등성 검증

```bash
# 원본 Python 테스트 실행
python -m pytest tests/ -v --tb=short > python_results.txt

# 변환된 Rust 테스트 실행
cargo test -- --nocapture > rust_results.txt

# 결과 비교
diff <(grep -E "PASSED|FAILED" python_results.txt | sort) \
     <(grep -E "ok|FAILED" rust_results.txt | sort)
```

### 프로퍼티 기반 테스트

언어 전환 시 동일한 입력에 동일한 출력을 보장하는 테스트:

```rust
// Rust (proptest)
use proptest::prelude::*;

proptest! {
    #[test]
    fn parse_matches_python(input in "[a-zA-Z0-9 ]{1,100}") {
        let rust_result = parse(&input);
        let python_result = call_python_parse(&input); // FFI
        prop_assert_eq!(rust_result, python_result);
    }
}
```

## Step 6: 점진적 교체와 롤백

### 카나리 배포 패턴

```yaml
# feature flag로 전환 모듈 제어
migration:
  use_rust_parser: true      # 전환 완료
  use_rust_validator: true    # 전환 완료
  use_rust_api: false         # 아직 Python 사용
  rollback_on_error: true     # 에러 시 자동 롤백
```

### 성능 비교 모니터링

```bash
# Python 버전 벤치마크
hyperfine 'python src/main.py benchmark' --warmup 3

# Rust 버전 벤치마크
hyperfine './target/release/app benchmark' --warmup 3
```

### 롤백 체크리스트

| 단계 | 확인 항목 | 롤백 조건 |
|------|----------|----------|
| 모듈 변환 | 단위 테스트 통과율 | 95% 미만이면 롤백 |
| FFI 연결 | 메모리 누수 없음 | valgrind 경고 시 |
| 통합 테스트 | 응답 시간 비교 | 20% 이상 느려지면 |
| 카나리 | 에러율 모니터링 | 0.1% 이상이면 |

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 변환 단위 | 모듈별 | 파일별/함수별로 조정 가능 |
| 테스트 통과 기준 | 95% | 프로젝트 성격에 따라 조절 |
| FFI 브릿지 | PyO3 | napi-rs, cgo 등 대안 |
| 벤치마크 도구 | hyperfine | criterion, wrk 등 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 타입 불일치 | 매핑 테이블에 없는 타입은 AI에게 변환 규칙 추가 요청 |
| 외부 라이브러리 대응 없음 | FFI로 기존 라이브러리 래핑 또는 직접 구현 |
| 비동기 모델 차이 | 런타임(tokio/async-std) 선택 후 일관되게 적용 |
| 메모리 모델 충돌 | 소유권/라이프타임 문제는 Clone으로 우회 후 최적화 |
| 빌드 시간 증가 | 변환 모듈별 별도 크레이트 분리 |

## 실전 팁

1. **매핑 테이블을 CLAUDE.md에 저장하세요** — 세션마다 다시 설명할 필요 없어요
2. **한 번에 500줄 이상 변환하지 마세요** — AI도 긴 코드에서 실수가 늘어요
3. **원본 코드를 지우지 마세요** — 전환 완료 후에도 최소 1주일은 유지
4. **타입 시스템이 있는 언어로 갈 때가 유리해요** — 컴파일러가 검증해주니까요
5. **성능 비교는 전환 초기부터 하세요** — 나중에 병목을 찾으면 되돌리기 어려워요

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
