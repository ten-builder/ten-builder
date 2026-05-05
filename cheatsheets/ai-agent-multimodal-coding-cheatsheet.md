# AI 에이전트 멀티모달 입력 활용 치트시트 — 스크린샷, 다이어그램, 문서로 코딩하기

> 텍스트만 입력하던 시대는 끝났다. 이미지, PDF, 스크린샷을 직접 넘기면 AI 에이전트가 더 정확하게 일한다.

## 멀티모달 입력이 중요한 이유

말로 설명하기 어려운 UI 레이아웃, 에러 화면, 아키텍처 다이어그램을 이미지로 바로 전달하면 대화 왕복 횟수가 크게 줄어든다. 이미지 한 장이 설명 수백 자를 대신한다.

## 도구별 멀티모달 입력 지원 현황

| 도구 | 이미지 | PDF | 스크린샷 붙여넣기 | 동영상 |
|------|--------|-----|-----------------|--------|
| Claude Code | ✅ | ✅ | ✅ (paste) | ❌ |
| Gemini CLI | ✅ | ✅ | ✅ (`@파일` 첨부) | ✅ (Gemini 3) |
| Codex CLI | ✅ | ❌ | ✅ | ❌ |
| Cursor Composer | ✅ | ❌ | ✅ | ❌ |
| GitHub Copilot | ✅ | ❌ | ✅ | ❌ |

## 활용 패턴 1: 스크린샷 → 코드 구현

### Claude Code에서 스크린샷 첨부

```bash
# 스크린샷 파일을 /screenshots 폴더에 저장하는 스크립트
mkdir -p ~/project/screenshots

# macOS: 특정 영역 스크린샷 저장
screencapture -i ~/project/screenshots/ui-design.png

# Claude Code 채팅에서 이미지 붙여넣기 (⌘+V) 또는 드래그 앤 드롭
# "이 UI를 React 컴포넌트로 구현해줘"
```

**CLAUDE.md에 스크린샷 경로 명시:**

```markdown
## 시각 자료
- UI 목업: `screenshots/` 폴더 참조
- 에러 캡처: 문제 재현 시 스크린샷 첨부
- 아키텍처: `docs/diagrams/` 폴더
```

### 활용 시나리오

| 상황 | 입력 방식 | 프롬프트 예시 |
|------|----------|-------------|
| 피그마 목업 구현 | 목업 이미지 붙여넣기 | `이 디자인을 Tailwind CSS로 구현해줘` |
| 에러 화면 디버깅 | 에러 스크린샷 첨부 | `이 에러를 어떻게 해결하지?` |
| 기존 UI 복제 | 경쟁사 화면 캡처 | `이 레이아웃 구조를 분석해줘` |
| 콘솔 오류 | 터미널 화면 캡처 | `이 스택 트레이스를 해석해줘` |

## 활용 패턴 2: 다이어그램 → 코드 설계

### 아키텍처 다이어그램 → 코드 생성

```bash
# Mermaid 다이어그램 이미지를 첨부하거나
# draw.io 내보내기 파일(PNG)을 첨부

# 프롬프트 예시:
# "이 ERD를 기반으로 Prisma 스키마를 작성해줘"
# "이 시퀀스 다이어그램대로 API 엔드포인트를 구현해줘"
# "이 클래스 다이어그램을 TypeScript 인터페이스로 변환해줘"
```

**ERD → Prisma 스키마 예시:**

```prisma
// ERD 이미지 첨부 후 생성된 스키마 예시
model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  posts     Post[]
  createdAt DateTime @default(now())
}

model Post {
  id       Int    @id @default(autoincrement())
  title    String
  author   User   @relation(fields: [authorId], references: [id])
  authorId Int
}
```

### Gemini CLI에서 이미지 파일 참조

```bash
# @파일명으로 직접 첨부
gemini "이 ERD를 분석하고 테이블 관계를 설명해줘" @./docs/erd-diagram.png

# 여러 이미지 동시 첨부
gemini "이 두 화면의 차이점을 분석해줘" @./before.png @./after.png

# PDF 첨부
gemini "이 API 문서를 바탕으로 TypeScript 클라이언트를 만들어줘" @./api-docs.pdf
```

## 활용 패턴 3: PDF 문서 → 코드 변환

### API 문서 PDF → 클라이언트 코드

```bash
# Claude Code에서 PDF 드래그 앤 드롭 후
# "이 API 스펙을 기반으로 fetch 래퍼 함수를 만들어줘"
# "이 문서의 인증 방식을 구현해줘"
```

**자동화 스크립트 예시:**

```python
# PDF를 이미지로 변환하여 AI 에이전트에 제공
import subprocess
import os

def pdf_to_screenshots(pdf_path: str, output_dir: str) -> list[str]:
    """PDF를 페이지별 PNG로 변환"""
    os.makedirs(output_dir, exist_ok=True)
    subprocess.run([
        "pdftoppm", "-png", "-r", "150",
        pdf_path, f"{output_dir}/page"
    ], check=True)
    return sorted([
        f"{output_dir}/{f}"
        for f in os.listdir(output_dir)
        if f.endswith(".png")
    ])

# 사용법
pages = pdf_to_screenshots("api-spec.pdf", "screenshots/api")
# Claude Code에서 첫 페이지부터 순서대로 첨부
```

## 활용 패턴 4: 실시간 에러 캡처 자동화

### 스크린샷 자동 저장 워크플로우

```bash
#!/bin/bash
# watch-and-screenshot.sh
# 에러 발생 시 자동 스크린샷 저장

PROJECT_DIR="$1"
SCREENSHOT_DIR="$PROJECT_DIR/screenshots/errors"
mkdir -p "$SCREENSHOT_DIR"

# 빌드 실패 시 스크린샷
npm run build 2>&1 | tee /tmp/build-log.txt
if [ $? -ne 0 ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    screencapture "$SCREENSHOT_DIR/build-error-$TIMESTAMP.png"
    echo "에러 캡처: $SCREENSHOT_DIR/build-error-$TIMESTAMP.png"
fi
```

```yaml
# .github/workflows/error-capture.yml
# CI에서 실패 시 화면 캡처
- name: Capture test failure screenshot
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: failure-screenshots
    path: screenshots/
```

## 멀티모달 입력 효과적으로 쓰는 팁

| 팁 | 설명 |
|----|------|
| 해상도 최적화 | 이미지는 1200px 이하로 리사이즈. 너무 크면 토큰 소비 증가 |
| 크롭 먼저 | 전체 화면보다 관련 부분만 크롭하여 첨부 |
| 레이블 추가 | 이미지에 번호나 화살표를 추가하면 AI가 더 정확하게 참조 |
| 텍스트 병행 | 이미지만 단독으로 넘기지 말고 핵심 질문을 함께 작성 |
| 순서 명시 | 여러 이미지 첨부 시 "첫 번째는 before, 두 번째는 after" |

## 흔한 실수와 해결법

| 실수 | 해결 |
|------|------|
| 전체 화면 스크린샷 첨부 | 관련 컴포넌트만 크롭하여 첨부 |
| 이미지 설명 없이 첨부 | "이 이미지에서 X를 Y로 바꿔줘"처럼 명확히 작성 |
| 저해상도 이미지 사용 | 텍스트가 읽힐 정도 해상도(최소 72dpi) 확보 |
| PDF 전체 첨부 | 관련 페이지만 지정하거나 핵심 내용 발췌 |

## 모델별 멀티모달 강점

| 모델 | 강점 |
|------|------|
| Claude Opus 4.7 | 긴 문서 OCR, 복잡한 레이아웃 분석 |
| GPT-5.5 | 차트·인포그래픽 해석, 코드-비전 통합 |
| Gemini 3 | 동영상 이해, 실시간 화면 스트리밍 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
