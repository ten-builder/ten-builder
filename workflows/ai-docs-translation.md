# AI 코드 문서 자동 번역 워크플로우

> README, API 문서, 가이드를 다국어로 자동 번역하고 CI에서 동기화하는 파이프라인

## 개요

오픈소스 프로젝트나 글로벌 팀을 운영하면 문서 번역은 피할 수 없는 작업이에요. 영어로 작성한 README를 한국어, 일본어, 중국어로 번역하고, 원본이 바뀔 때마다 번역본도 업데이트해야 하죠. AI 코딩 에이전트를 CI 파이프라인에 연결하면 이 과정을 자동화할 수 있어요.

이 워크플로우가 해결하는 문제:
- 원본 문서 변경 시 번역본이 뒤처지는 drift 문제
- 기술 용어의 일관성 없는 번역
- 수동 번역 작업의 반복적인 시간 소모
- 번역 상태 추적의 어려움

## 사전 준비

- GitHub 레포 + GitHub Actions (또는 동등한 CI/CD)
- AI 코딩 에이전트 (Claude Code, Cursor 등)
- Node.js 18+ 또는 Python 3.10+
- 번역 대상 마크다운 문서

## 설정

### Step 1: 디렉토리 구조 설계

번역 파일을 관리하는 두 가지 패턴이 있어요:

```
# 패턴 A: suffix 방식 (소규모 프로젝트)
docs/
├── README.md          # 원본 (영어)
├── README.ko.md       # 한국어
├── README.ja.md       # 일본어
└── README.zh.md       # 중국어

# 패턴 B: 디렉토리 방식 (대규모 프로젝트)
docs/
├── en/
│   ├── getting-started.md
│   └── api-reference.md
├── ko/
│   ├── getting-started.md
│   └── api-reference.md
└── ja/
    ├── getting-started.md
    └── api-reference.md
```

소규모 프로젝트에는 패턴 A가 간편하고, 문서가 10개 이상이면 패턴 B가 관리하기 좋아요.

### Step 2: 번역 설정 파일 생성

프로젝트 루트에 번역 규칙을 정의해요:

```yaml
# .translation.yaml
source_language: en
target_languages:
  - ko
  - ja
  - zh

# 번역 대상 파일 (glob 패턴)
include:
  - "README.md"
  - "docs/**/*.md"

# 제외 대상
exclude:
  - "docs/CHANGELOG.md"
  - "docs/internal/**"

# 기술 용어 사전 (일관성 유지)
glossary:
  - term: "agent"
    ko: "에이전트"
    ja: "エージェント"
    zh: "代理"
  - term: "context window"
    ko: "컨텍스트 윈도우"
    ja: "コンテキストウィンドウ"
    zh: "上下文窗口"
  - term: "prompt"
    ko: "프롬프트"
    ja: "プロンプト"
    zh: "提示词"
  - term: "scaffolding"
    ko: "스캐폴딩"
    ja: "スキャフォールディング"
    zh: "脚手架"

# 번역 스타일
style:
  ko: "해요체, 자연스러운 한국어"
  ja: "です・ます体"
  zh: "简体中文, 技术文档风格"
```

### Step 3: 번역 스크립트 작성

AI API를 호출하는 번역 스크립트를 만들어요:

```python
#!/usr/bin/env python3
# scripts/translate_docs.py

import os
import yaml
import hashlib
from pathlib import Path
from anthropic import Anthropic

def load_config():
    with open(".translation.yaml") as f:
        return yaml.safe_load(f)

def compute_hash(content: str) -> str:
    return hashlib.sha256(content.encode()).hexdigest()[:12]

def load_translation_state():
    state_path = Path(".translation-state.json")
    if state_path.exists():
        import json
        return json.loads(state_path.read_text())
    return {}

def save_translation_state(state):
    import json
    Path(".translation-state.json").write_text(
        json.dumps(state, indent=2, ensure_ascii=False)
    )

def needs_translation(source_path: str, target_lang: str, state: dict) -> bool:
    content = Path(source_path).read_text()
    current_hash = compute_hash(content)
    key = f"{source_path}:{target_lang}"
    return state.get(key) != current_hash

def translate_file(source_path: str, target_lang: str, config: dict) -> str:
    client = Anthropic()
    source_content = Path(source_path).read_text()

    # 용어 사전을 프롬프트에 포함
    glossary_text = ""
    for entry in config.get("glossary", []):
        if target_lang in entry:
            glossary_text += f"- {entry['term']} → {entry[target_lang]}\n"

    style = config.get("style", {}).get(target_lang, "")

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        messages=[{
            "role": "user",
            "content": f"""다음 마크다운 문서를 {target_lang}로 번역해주세요.

규칙:
1. 마크다운 서식(헤딩, 코드 블록, 링크, 표)을 그대로 유지
2. 코드 블록 안의 코드는 번역하지 않음 (주석만 번역)
3. 파일 경로, 명령어, 변수명은 번역하지 않음
4. 스타일: {style}

용어 사전 (반드시 준수):
{glossary_text}

원본 문서:
{source_content}"""
        }]
    )
    return response.content[0].text

def get_target_path(source_path: str, target_lang: str, config: dict) -> str:
    p = Path(source_path)
    return str(p.parent / f"{p.stem}.{target_lang}{p.suffix}")

def main():
    config = load_config()
    state = load_translation_state()
    import glob

    translated_count = 0

    for pattern in config["include"]:
        for source_path in glob.glob(pattern, recursive=True):
            # 제외 대상 체크
            if any(Path(source_path).match(exc) for exc in config.get("exclude", [])):
                continue

            for lang in config["target_languages"]:
                if not needs_translation(source_path, lang, state):
                    print(f"  skip {source_path} → {lang} (unchanged)")
                    continue

                print(f"  translate {source_path} → {lang}")
                translated = translate_file(source_path, lang, config)
                target_path = get_target_path(source_path, lang, config)
                Path(target_path).parent.mkdir(parents=True, exist_ok=True)
                Path(target_path).write_text(translated)

                # 상태 업데이트
                key = f"{source_path}:{lang}"
                content = Path(source_path).read_text()
                state[key] = compute_hash(content)
                translated_count += 1

    save_translation_state(state)
    print(f"\n  {translated_count} files translated")

if __name__ == "__main__":
    main()
```

### Step 4: GitHub Actions 워크플로우

PR이 머지될 때 자동으로 번역을 실행해요:

```yaml
# .github/workflows/translate-docs.yaml
name: Translate Documentation

on:
  push:
    branches: [main]
    paths:
      - "README.md"
      - "docs/**/*.md"
      - ".translation.yaml"

jobs:
  translate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2  # diff 비교용

      - name: Check changed docs
        id: changed
        run: |
          CHANGED=$(git diff --name-only HEAD~1 HEAD -- '*.md' | grep -v '\.\(ko\|ja\|zh\)\.' || true)
          echo "files=$CHANGED" >> $GITHUB_OUTPUT
          echo "count=$(echo "$CHANGED" | grep -c . || echo 0)" >> $GITHUB_OUTPUT

      - name: Setup Python
        if: steps.changed.outputs.count != '0'
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        if: steps.changed.outputs.count != '0'
        run: pip install anthropic pyyaml

      - name: Run translation
        if: steps.changed.outputs.count != '0'
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: python scripts/translate_docs.py

      - name: Create PR with translations
        if: steps.changed.outputs.count != '0'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          BRANCH="chore/update-translations-$(date +%Y%m%d%H%M)"
          git checkout -b "$BRANCH"
          git add -A '*.ko.md' '*.ja.md' '*.zh.md'

          if git diff --staged --quiet; then
            echo "No translation changes"
            exit 0
          fi

          git commit -m "docs: update translations"
          git push origin "$BRANCH"
          gh pr create \
            --title "docs: update translations" \
            --body "Automated translation update triggered by docs changes." \
            --base main
```

## 사용 방법

### 수동 실행: AI 에이전트에게 직접 요청

CI 없이도 AI 코딩 에이전트에게 직접 번역을 요청할 수 있어요:

```
이 README.md를 한국어로 번역해서 README.ko.md로 저장해줘.
코드 블록은 그대로 두고, 기술 용어는 영어 병기해줘.
```

### 용어 사전 활용 팁

| 상황 | 접근법 |
|------|--------|
| 새 프로젝트 | 핵심 기술 용어 10~20개로 시작 |
| 번역 불일치 발견 | `.translation.yaml`에 해당 용어 추가 |
| 팀 리뷰 | 번역 PR에서 용어 사전 개선 사항 코멘트 |
| 도메인 특화 | 분야별 용어 사전 파일 분리 (`glossary-blockchain.yaml`) |

### 변경 감지 전략

모든 문서를 매번 번역하면 비용과 시간이 낭비돼요. 해시 기반 변경 감지로 실제 변경된 파일만 처리하는 게 핵심이에요:

```bash
# 변경된 원본 문서만 확인
git diff --name-only HEAD~1 HEAD -- '*.md' | grep -v '\.\(ko\|ja\|zh\)\.'
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `source_language` | `en` | 원본 문서 언어 |
| `target_languages` | `[ko, ja, zh]` | 번역 대상 언어 목록 |
| `include` | `["README.md"]` | 번역할 파일 glob 패턴 |
| `glossary` | `[]` | 기술 용어 사전 |
| `style` | 언어별 기본 스타일 | 번역 톤앤매너 지정 |

## 문제 해결

| 문제 | 해결 |
|------|------|
| 코드 블록 내용이 번역됨 | 프롬프트에 "코드 블록 내부는 번역하지 않음" 명시 강화 |
| 기술 용어 번역 불일치 | `.translation.yaml` 용어 사전에 해당 용어 추가 |
| 번역 품질이 낮음 | 모델을 Opus로 업그레이드하거나 few-shot 예제 추가 |
| CI 비용이 높음 | 해시 기반 변경 감지로 불필요한 번역 제거 |
| 마크다운 서식 깨짐 | 번역 후 markdownlint로 자동 검증 추가 |
| 번역 PR이 너무 많음 | 배치 처리: 주 1회 정기 실행으로 변경 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
