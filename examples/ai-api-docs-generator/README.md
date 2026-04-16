# AI 에이전트 기반 API 문서 자동 생성기

> FastAPI, Express 코드를 AI 에이전트로 분석해 OpenAPI 스펙과 개발자 문서를 자동 생성하는 예제 프로젝트

## 이 예제에서 배울 수 있는 것

- AI 에이전트로 기존 코드에서 OpenAPI 스펙을 자동 추출하는 방법
- FastAPI와 Express 각각의 문서 자동화 패턴
- AI가 생성한 문서를 사람이 읽기 좋게 다듬는 후처리 워크플로우
- GitHub Actions로 코드 변경 시 문서를 자동 갱신하는 파이프라인

## 프로젝트 구조

```
ai-api-docs-generator/
├── README.md
├── scripts/
│   ├── generate-docs.sh        # 메인 실행 스크립트
│   ├── analyze-fastapi.py      # FastAPI 엔드포인트 분석
│   └── analyze-express.js      # Express 라우터 분석
├── prompts/
│   ├── openapi-extractor.md    # AI 에이전트용 프롬프트 템플릿
│   └── doc-enricher.md         # 문서 보강 프롬프트
├── output/
│   ├── openapi.yaml            # 생성된 OpenAPI 스펙
│   └── docs/                   # 생성된 마크다운 문서
└── .github/
    └── workflows/
        └── auto-docs.yml       # 자동화 파이프라인
```

## 시작하기

```bash
# 레포 클론
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-api-docs-generator

# 의존성 설치 (FastAPI 예제)
pip install fastapi uvicorn pyyaml

# 의존성 설치 (Express 예제)
npm install express swagger-jsdoc

# AI 문서 생성 실행
./scripts/generate-docs.sh --target fastapi --source ./sample-api/
```

## 핵심 코드

### 1. FastAPI 엔드포인트 자동 분석

```python
# scripts/analyze-fastapi.py
import ast
import sys
from pathlib import Path

def extract_routes(file_path: str) -> list[dict]:
    """FastAPI 라우터에서 엔드포인트 정보를 추출합니다."""
    source = Path(file_path).read_text()
    tree = ast.parse(source)
    
    routes = []
    for node in ast.walk(tree):
        # @app.get, @app.post 등 데코레이터 탐지
        if isinstance(node, ast.FunctionDef):
            for decorator in node.decorator_list:
                if isinstance(decorator, ast.Call):
                    if hasattr(decorator.func, 'attr'):
                        method = decorator.func.attr.upper()
                        if method in ('GET', 'POST', 'PUT', 'DELETE', 'PATCH'):
                            path = ast.literal_eval(decorator.args[0]) if decorator.args else '/'
                            routes.append({
                                'method': method,
                                'path': path,
                                'function': node.name,
                                'docstring': ast.get_docstring(node) or '',
                                'args': [arg.arg for arg in node.args.args]
                            })
    return routes

if __name__ == '__main__':
    routes = extract_routes(sys.argv[1])
    for route in routes:
        print(f"{route['method']} {route['path']} → {route['function']}")
```

**왜 이렇게 했나요?**

AST(추상 구문 트리) 파싱으로 코드를 실행하지 않고도 엔드포인트 구조를 파악할 수 있습니다. AI 에이전트에 이 구조 정보를 넘기면 훨씬 정확한 문서를 생성할 수 있어요.

### 2. AI 에이전트용 OpenAPI 추출 프롬프트

```markdown
# prompts/openapi-extractor.md

다음 API 코드를 분석해서 OpenAPI 3.0 스펙을 YAML 형식으로 생성해 주세요.

## 분석할 코드

{{source_code}}

## 추출된 엔드포인트 목록

{{route_list}}

## 생성 규칙

1. 각 엔드포인트의 request body와 response schema를 명시합니다
2. 파라미터 타입과 필수 여부를 정확히 표현합니다
3. 실제 사용 예시를 `example` 필드에 포함합니다
4. 에러 응답 (400, 401, 404, 500)도 반드시 정의합니다
5. 한국어 description을 사용합니다

## 출력 형식

openapi: 3.0.0
info:
  title: {{api_name}}
  version: "1.0.0"
  description: {{api_description}}
paths:
  ...
```

### 3. 메인 실행 스크립트

```bash
#!/bin/bash
# scripts/generate-docs.sh

TARGET=${1:-fastapi}
SOURCE=${2:-./api/}
OUTPUT_DIR="./output"

mkdir -p "$OUTPUT_DIR/docs"

echo "=== API 코드 분석 중 ==="

if [ "$TARGET" = "fastapi" ]; then
    # Python AST로 라우터 추출
    ROUTES=$(python3 scripts/analyze-fastapi.py "$SOURCE/main.py")
    SOURCE_CODE=$(cat "$SOURCE/main.py")
elif [ "$TARGET" = "express" ]; then
    # Node.js로 라우터 추출
    ROUTES=$(node scripts/analyze-express.js "$SOURCE/app.js")
    SOURCE_CODE=$(cat "$SOURCE/app.js")
fi

echo "=== AI 에이전트로 OpenAPI 스펙 생성 중 ==="

# Claude Code에 프롬프트 전달
PROMPT=$(cat prompts/openapi-extractor.md | \
    sed "s|{{source_code}}|$SOURCE_CODE|g" | \
    sed "s|{{route_list}}|$ROUTES|g")

claude --print "$PROMPT" > "$OUTPUT_DIR/openapi.yaml"

echo "=== 생성된 스펙으로 마크다운 문서 생성 중 ==="

DOC_PROMPT=$(cat prompts/doc-enricher.md | \
    sed "s|{{openapi_spec}}|$(cat $OUTPUT_DIR/openapi.yaml)|g")

claude --print "$DOC_PROMPT" > "$OUTPUT_DIR/docs/API_REFERENCE.md"

echo "=== 완료 ==="
echo "OpenAPI 스펙: $OUTPUT_DIR/openapi.yaml"
echo "개발자 문서: $OUTPUT_DIR/docs/API_REFERENCE.md"
```

### 4. GitHub Actions 자동화 파이프라인

```yaml
# .github/workflows/auto-docs.yml
name: Auto Generate API Docs

on:
  push:
    branches: [main]
    paths:
      - 'api/**'
      - 'routes/**'
      - '*.py'
      - '*.js'

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Python 환경 설정
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'
          
      - name: Claude CLI 설치
        run: npm install -g @anthropic-ai/claude-code
        
      - name: API 문서 생성
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          ./scripts/generate-docs.sh fastapi ./api/
          
      - name: 문서 변경사항 커밋
        run: |
          git config user.name "docs-bot"
          git config user.email "docs@example.com"
          git add output/
          git diff --staged --quiet || git commit -m "docs: API 문서 자동 갱신"
          git push
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 엔드포인트 설명 작성 | `이 GET /users/{id} 엔드포인트의 목적, 파라미터, 응답 형식을 개발자가 이해하기 쉽게 설명해줘` |
| 에러 케이스 문서화 | `이 API가 반환할 수 있는 모든 에러 상황과 HTTP 상태 코드를 정리해줘` |
| 예제 요청 생성 | `이 엔드포인트를 curl, Python requests, JavaScript fetch로 호출하는 예제 코드를 작성해줘` |
| 변경사항 감지 | `기존 OpenAPI 스펙과 새 코드를 비교해서 breaking change가 있는지 알려줘` |
| README 자동 생성 | `이 OpenAPI 스펙을 기반으로 개발자 온보딩용 README를 작성해줘` |

## 다음 단계

이 패턴을 확장하면 다음과 같은 자동화도 가능해요:

- **다국어 SDK 자동 생성**: OpenAPI 스펙 → Python, TypeScript, Go 클라이언트 자동 생성
- **Postman 컬렉션 자동 변환**: 생성된 스펙을 Postman/Insomnia 형식으로 내보내기
- **변경 로그 자동 작성**: API 버전 간 diff를 AI가 분석해 Changelog 자동 생성
- **테스트 케이스 생성**: OpenAPI 스펙에서 pytest/Jest 테스트 코드 자동 생성

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
