# EP13: 말로 코딩하기 — AI 에이전트 음성 워크플로우 실전

> 키보드 없이 Claude Code를 제어하며 실제 기능을 구현하는 라이브 코딩 에피소드 — 설정부터 실전 패턴까지

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

## 이 에피소드에서 다루는 것

- Claude Code `/voice` 명령어로 음성 프롬프트 입력 설정
- Wispr Flow / Willow Voice 등 외부 받아쓰기 도구와 연동
- 실제 기능 구현 시 효과적인 음성 패턴 (긴 컨텍스트 설명, 아키텍처 구술)
- 손이 자유로운 상태로 장시간 세션 유지하는 방법

## 핵심 코드 & 설정

### Claude Code 음성 모드 활성화

```bash
# Claude.ai 계정으로 인증된 상태에서 실행
claude

# 세션 내에서 음성 입력 활성화
/voice

# 마이크 권한 확인 (macOS)
# 시스템 설정 > 개인 정보 보호 > 마이크 > 터미널 허용
```

| 명령어 | 설명 |
|--------|------|
| `/voice` | 음성 입력 모드 켜기/끄기 |
| `/voice status` | 현재 마이크 연결 상태 확인 |
| `/login` | API 키 인증 → Claude.ai 계정으로 전환 |

### 외부 받아쓰기 도구 설정 (Wispr Flow)

```bash
# Wispr Flow 설치 후 전역 단축키 설정 예시
# 어떤 앱에서든 단축키를 누르면 음성 입력 시작
# 터미널 Claude Code 프롬프트 창에 커서를 두고 말하면 텍스트로 변환

# .zshrc에 추가 — 음성 코딩 세션 시작 alias
alias vc='cd ~/projects/current && claude'
```

### 오프라인 대안: Whisper 로컬 전사

```python
# whisper_to_claude.py — 로컬에서 전사 후 클립보드에 복사
import whisper
import pyperclip
import sounddevice as sd
import numpy as np

model = whisper.load_model("base")

def record_and_transcribe(duration=10, samplerate=16000):
    print(f"녹음 중... ({duration}초)")
    audio = sd.rec(
        int(duration * samplerate),
        samplerate=samplerate,
        channels=1,
        dtype=np.float32
    )
    sd.wait()
    
    result = model.transcribe(audio.squeeze(), language="ko")
    text = result["text"].strip()
    
    pyperclip.copy(text)
    print(f"클립보드 복사 완료: {text}")
    return text

if __name__ == "__main__":
    record_and_transcribe()
```

## 따라하기

### Step 1: 음성 입력 환경 세팅

```bash
# macOS 받아쓰기 기능 확인 (기본 제공)
# 시스템 설정 > 키보드 > 받아쓰기 활성화
# 단축키: fn fn (기본값)

# 또는 Wispr Flow 설치
brew install --cask wispr-flow
```

### Step 2: Claude Code 세션에서 첫 음성 프롬프트

```bash
# 터미널에서 Claude Code 시작
claude

# /voice 활성화 후 아래처럼 말하기:
# "현재 디렉토리 구조를 분석하고, src 폴더 안에
#  users 모듈을 생성해줘. 각 파일에 주석도 한국어로 달아줘"
/voice
```

### Step 3: 효과적인 음성 프롬프트 패턴 실습

```bash
# 긴 컨텍스트를 음성으로 전달할 때는 구조화해서 말한다
# 예시:
# "배경 설명: [현재 상황 30초]
#  목표: [만들고 싶은 것 20초]  
#  제약 조건: [지켜야 할 것 20초]
#  시작해줘"

# 반복 작업을 음성으로 처리할 때는 확인 패턴 사용
# "방금 생성한 파일에 테스트 코드 추가하고 통과하는지 확인해줘"
```

### Step 4: 세션 중 컨텍스트 관리

```bash
# 긴 음성 세션에서 컨텍스트가 쌓이면 요약 요청
# "지금까지 변경한 내용을 3줄로 요약해줘"

# 다음 작업으로 넘어가기 전 현재 상태 확인
# "현재 구현된 내용과 아직 남은 작업을 정리해줘"
```

## 음성 프롬프트 패턴 모음

| 상황 | 음성 패턴 |
|------|----------|
| 새 기능 구현 시작 | "이 파일을 보고, [기능]을 추가해줘. [조건]을 지켜줘" |
| 에러 디버깅 | "에러 메시지는 [내용]이야. 어디서 나는지 찾아서 고쳐줘" |
| 리팩토링 요청 | "[함수명] 함수가 너무 길어. [기준]으로 분리해줘" |
| 테스트 작성 | "방금 만든 [기능]에 대한 단위 테스트 3개 작성해줘" |
| 코드 설명 요청 | "이 파일 전체를 읽고 핵심 로직을 한국어로 설명해줘" |

## 자주 겪는 문제 & 해결

| 문제 | 해결 |
|------|------|
| 마이크 권한 오류 | 시스템 설정 > 개인정보 > 마이크에서 터미널 허용 |
| `/voice` 명령어 없음 | `/login`으로 Claude.ai 계정 연결 필요 |
| 전사 정확도 낮음 | 코드 용어는 철자로 또박또박 말하거나 외부 도구 사용 |
| 음성이 도중 끊김 | 문장 단위로 끊어 말하기, 구두점은 "쉼표", "마침표"로 |

## 이 에피소드의 핵심 요점

음성 워크플로우가 특히 유용한 세 가지 상황이 있어요.

첫째, 긴 컨텍스트를 전달할 때입니다. 복잡한 배경 설명이나 요구 사항을 타이핑으로 입력하면 시간이 많이 걸리는데, 말로 하면 생각하는 속도와 입력 속도가 맞춰져요.

둘째, 장시간 작업 세션에서 손목 피로를 줄일 때입니다. 개발자들이 실제로 보고하는 가장 큰 장점 중 하나예요.

셋째, 아이디어가 머릿속에서 흘러나오는 속도로 프롬프트를 작성할 때입니다. 타이핑 속도가 병목이 되지 않으면 생각의 흐름이 유지돼요.

아직 음성 코딩이 모든 상황에서 완벽하진 않아요. 특히 코드 변수명이나 함수명을 정확히 전달할 때는 여전히 키보드가 편한 경우도 있어요. 하지만 이번 에피소드에서 보여드린 것처럼, 긴 프롬프트와 컨텍스트 전달에선 충분히 실용적인 워크플로우예요.

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
