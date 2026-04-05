# AI 에이전트 기반 성능 프로파일링 워크플로우

> 병목 지점을 AI가 찾아주고, 최적화 코드까지 제안받는 실전 파이프라인

## 개요

"느려요"라는 피드백을 받으면 보통 개발자가 직접 프로파일러를 돌리고, 결과를 해석하고, 최적화 코드를 작성해요. 이 과정 전체를 AI 에이전트에게 위임하면 병목 탐지부터 수정 PR까지 한 사이클로 처리할 수 있어요.

이 워크플로우는 백엔드(Node.js/Python) 프로젝트에서 AI 에이전트가 성능 프로파일링을 자동 실행하고, 결과를 분석해서 최적화 제안과 코드 패치를 생성하는 구조를 다뤄요.

## 사전 준비

- AI 코딩 에이전트 (Claude Code, Cursor, Gemini CLI 등)
- Node.js 프로젝트: `clinic.js`, `0x`, 또는 내장 `--prof` 플래그
- Python 프로젝트: `py-spy`, `cProfile`, `memray`
- 테스트용 부하 생성 도구: `autocannon`, `wrk`, `locust`
- Git 워크트리 또는 별도 브랜치 (프로파일링 결과를 메인 코드와 분리)

## 설정

### Step 1: 프로파일링 스크립트 준비

**Node.js — clinic.js 기반:**

```bash
# clinic.js 설치
npm install -g clinic autocannon

# 프로파일링 실행 스크립트
cat > scripts/profile.sh << 'EOF'
#!/bin/bash
set -e

echo "[profile] Starting server with clinic doctor..."
clinic doctor --on-port 'autocannon -c 50 -d 10 http://localhost:3000/api/target' \
  -- node server.js

echo "[profile] Flamegraph 생성 중..."
clinic flame --on-port 'autocannon -c 50 -d 10 http://localhost:3000/api/target' \
  -- node server.js

echo "[profile] 결과 → .clinic/ 디렉토리"
EOF
chmod +x scripts/profile.sh
```

**Python — py-spy 기반:**

```bash
# py-spy 설치
pip install py-spy memray

# 프로파일링 실행 스크립트
cat > scripts/profile.sh << 'EOF'
#!/bin/bash
set -e

echo "[profile] py-spy로 CPU 프로파일링..."
py-spy record -o profile.svg --duration 30 -- python app.py &
sleep 2
# 부하 생성
wrk -t4 -c50 -d25s http://localhost:8000/api/target
wait

echo "[profile] memray로 메모리 프로파일링..."
memray run -o mem_profile.bin app.py &
sleep 2
wrk -t4 -c50 -d15s http://localhost:8000/api/target
kill %1 2>/dev/null
memray flamegraph mem_profile.bin -o mem_flamegraph.html

echo "[profile] 결과: profile.svg, mem_flamegraph.html"
EOF
chmod +x scripts/profile.sh
```

### Step 2: AI 에이전트 프롬프트 템플릿

```markdown
## 성능 프로파일링 분석 요청

### 컨텍스트
- 프로젝트: {프로젝트명}
- 대상 엔드포인트: {API 경로}
- 현재 응답 시간: {p95 기준 ms}
- 목표 응답 시간: {목표 ms}

### 프로파일링 결과
{프로파일링 출력 텍스트 또는 요약}

### 요청사항
1. 상위 5개 병목 함수를 식별하고 각각 소요 시간 비율을 알려줘
2. 각 병목에 대한 최적화 방법을 구체적 코드와 함께 제안해줘
3. 최적화 적용 시 예상 개선 효과를 수치로 추정해줘
4. 메모리 누수 패턴이 있다면 별도로 표시해줘
```

## 사용 방법

### 전체 파이프라인 흐름

```
1. 부하 테스트 실행    → baseline 측정
2. 프로파일러 실행     → CPU/메모리 스냅샷
3. AI에 결과 전달      → 병목 분석 + 최적화 제안
4. AI 코드 패치 생성   → 최적화 코드 자동 작성
5. 부하 재테스트       → 개선 효과 검증
6. PR 생성            → before/after 비교 포함
```

### 실전 예시: Node.js Express API 최적화

```bash
# 1. baseline 측정
autocannon -c 100 -d 30 http://localhost:3000/api/users \
  --json > baseline.json

# 2. 프로파일링
node --prof server.js &
SERVER_PID=$!
autocannon -c 100 -d 30 http://localhost:3000/api/users
kill $SERVER_PID

# isolate 파일 처리
node --prof-process isolate-*.log > profile_analysis.txt

# 3. AI에 결과 전달 (Claude Code 예시)
cat profile_analysis.txt
# → "이 프로파일링 결과를 분석해서 상위 5개 병목과 최적화 코드를 제안해줘"
```

### 실전 예시: Python FastAPI 최적화

```bash
# 1. baseline
wrk -t4 -c100 -d30s http://localhost:8000/api/reports \
  --latency > baseline.txt

# 2. CPU 프로파일링
py-spy record -o flamegraph.svg --format speedscope \
  --duration 30 -- python -m uvicorn app:app --port 8000 &
sleep 2
wrk -t4 -c100 -d25s http://localhost:8000/api/reports
wait

# 3. AI에 speedscope JSON 전달
# → "이 프로파일에서 가장 느린 코드 경로를 찾아서 비동기 처리로 변환해줘"
```

## 자주 쓰는 AI 프롬프트 패턴

| 상황 | 프롬프트 |
|------|----------|
| CPU 병목 분석 | `프로파일링 결과에서 self time 상위 5개 함수를 찾아서 각각 최적화 방안을 코드로 보여줘` |
| 메모리 누수 탐지 | `memray 결과를 보고 할당 후 해제되지 않는 객체 패턴을 찾아줘` |
| DB 쿼리 최적화 | `느린 쿼리 로그를 분석해서 인덱스 추가와 쿼리 리팩토링을 제안해줘` |
| N+1 문제 탐지 | `프로파일에서 반복 호출되는 DB 접근 패턴을 찾아서 batch 쿼리로 변환해줘` |
| 캐시 도입 | `반복 연산 비용이 높은 함수에 적절한 캐시 레이어를 추가하는 코드를 작성해줘` |
| 비동기 전환 | `동기 I/O 호출을 비동기로 변환하고, 병렬 처리가 가능한 부분을 Promise.all로 묶어줘` |

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 부하 동시 접속 수 | 100 | `autocannon -c` 또는 `wrk -c` 값 |
| 테스트 지속 시간 | 30초 | 안정적인 결과를 위해 최소 20초 권장 |
| 프로파일 포맷 | speedscope | `py-spy --format` — AI가 파싱하기 쉬운 JSON 형태 |
| 메모리 임계값 | RSS 500MB | 이 값을 초과하면 메모리 프로파일링 우선 실행 |
| 타겟 개선율 | 30% | 이 수치 이하의 개선은 코드 복잡도 대비 효과가 낮을 수 있음 |

## CI 연동: 성능 회귀 자동 탐지

```yaml
# .github/workflows/perf-check.yml
name: Performance Regression Check
on:
  pull_request:
    paths: ['src/**', 'app/**']

jobs:
  perf:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: npm ci

      - name: Start server
        run: node server.js &
        env:
          NODE_ENV: production

      - name: Run baseline comparison
        run: |
          npx autocannon -c 50 -d 15 http://localhost:3000/api/target \
            --json > current.json

          # 이전 결과와 비교 (main 브랜치 artifact에서 가져오기)
          PREV_RPS=$(cat baseline.json | jq '.requests.average')
          CURR_RPS=$(cat current.json | jq '.requests.average')

          # 10% 이상 하락 시 실패
          THRESHOLD=$(echo "$PREV_RPS * 0.9" | bc)
          if (( $(echo "$CURR_RPS < $THRESHOLD" | bc -l) )); then
            echo "성능 회귀 감지: $CURR_RPS < $THRESHOLD (기준 $PREV_RPS)"
            exit 1
          fi
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| 프로파일 결과가 너무 김 | `--duration`을 10초로 줄이거나, 상위 20개 함수만 추출해서 AI에 전달 |
| AI가 프레임그래프를 못 읽음 | SVG 대신 텍스트 기반 출력 사용 (`--format speedscope` → JSON) |
| 프로덕션 프로파일링 부담 | `py-spy`는 attach 방식이라 오버헤드 1% 미만, `--pid`로 실행 중 프로세스에 연결 |
| 메모리 프로파일이 너무 큼 | `memray`의 `--follow-fork` 빼고, 단일 프로세스만 추적 |
| baseline이 불안정 | 3회 실행 후 중앙값 사용, 웜업 요청 100개 먼저 보내기 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
