# AI 에이전트 기반 시장 데이터 분석기

> Claude API의 Tool Use 기능으로 주식/암호화폐 실시간 데이터를 가져오고, 종합 분석 리포트를 자동 생성하는 Python 프로젝트

## 이 예제에서 배울 수 있는 것

- Claude API Tool Use로 외부 데이터 소스를 연결하는 패턴
- `yfinance`로 실시간 주가 및 재무 데이터를 가져오는 방법
- AI 에이전트가 데이터를 해석해 서사 형태의 리포트를 생성하는 구조
- 다단계 도구 호출(multi-step tool use)로 복잡한 분석을 자동화하는 흐름

## 프로젝트 구조

```
ai-market-data-analyzer/
├── README.md
├── requirements.txt
├── analyzer.py          # 메인 분석 에이전트
├── tools.py             # Tool Use 정의 (데이터 수집 함수들)
├── report.py            # 리포트 포맷팅
└── examples/
    └── sample_report.md # 샘플 출력 결과
```

## 시작하기

```bash
# 저장소 클론
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-market-data-analyzer

# 의존성 설치
pip install -r requirements.txt

# API 키 설정
export ANTHROPIC_API_KEY="your_api_key"

# 실행
python analyzer.py --ticker AAPL --period 3mo
```

**requirements.txt:**
```
anthropic>=0.40.0
yfinance>=0.2.50
pandas>=2.0.0
```

## 핵심 코드

### tools.py — Tool Use 정의

```python
import yfinance as yf
import json

# Claude에게 제공할 도구 정의
TOOLS = [
    {
        "name": "get_stock_price",
        "description": "특정 주식의 현재 가격과 기본 지표를 가져옵니다.",
        "input_schema": {
            "type": "object",
            "properties": {
                "ticker": {
                    "type": "string",
                    "description": "주식 티커 (예: AAPL, MSFT, 005930.KS)"
                },
                "period": {
                    "type": "string",
                    "description": "조회 기간 (1mo, 3mo, 6mo, 1y)",
                    "default": "3mo"
                }
            },
            "required": ["ticker"]
        }
    },
    {
        "name": "get_financial_metrics",
        "description": "PER, PBR, 배당수익률 등 재무 지표를 가져옵니다.",
        "input_schema": {
            "type": "object",
            "properties": {
                "ticker": {"type": "string"}
            },
            "required": ["ticker"]
        }
    },
    {
        "name": "compare_stocks",
        "description": "여러 종목의 수익률을 비교합니다.",
        "input_schema": {
            "type": "object",
            "properties": {
                "tickers": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "비교할 티커 목록"
                },
                "period": {"type": "string", "default": "3mo"}
            },
            "required": ["tickers"]
        }
    }
]

def execute_tool(tool_name: str, tool_input: dict) -> str:
    """도구 호출을 실행하고 결과를 문자열로 반환"""
    try:
        if tool_name == "get_stock_price":
            ticker = yf.Ticker(tool_input["ticker"])
            period = tool_input.get("period", "3mo")
            hist = ticker.history(period=period)
            
            current = hist["Close"].iloc[-1]
            start = hist["Close"].iloc[0]
            change_pct = ((current - start) / start) * 100
            
            result = {
                "ticker": tool_input["ticker"],
                "current_price": round(current, 2),
                "period_change_pct": round(change_pct, 2),
                "period_high": round(hist["High"].max(), 2),
                "period_low": round(hist["Low"].min(), 2),
                "avg_volume": int(hist["Volume"].mean())
            }
            return json.dumps(result, ensure_ascii=False)
        
        elif tool_name == "get_financial_metrics":
            ticker = yf.Ticker(tool_input["ticker"])
            info = ticker.info
            
            result = {
                "ticker": tool_input["ticker"],
                "per": info.get("trailingPE"),
                "pbr": info.get("priceToBook"),
                "dividend_yield": info.get("dividendYield"),
                "market_cap": info.get("marketCap"),
                "52w_high": info.get("fiftyTwoWeekHigh"),
                "52w_low": info.get("fiftyTwoWeekLow")
            }
            return json.dumps(result, ensure_ascii=False)
        
        elif tool_name == "compare_stocks":
            tickers = tool_input["tickers"]
            period = tool_input.get("period", "3mo")
            comparison = {}
            
            for t in tickers:
                hist = yf.Ticker(t).history(period=period)
                if not hist.empty:
                    start = hist["Close"].iloc[0]
                    end = hist["Close"].iloc[-1]
                    comparison[t] = round(((end - start) / start) * 100, 2)
            
            return json.dumps(comparison, ensure_ascii=False)
    
    except Exception as e:
        return json.dumps({"error": str(e)})
```

**왜 이렇게 했나요?**

Tool Use 방식의 핵심은 Claude가 직접 데이터를 수집하지 않고, 에이전트가 "어떤 데이터가 필요한지 판단 → 도구 호출 → 결과 해석"하는 루프를 돌린다는 점입니다. 분석 로직은 Python에, 판단과 해석은 Claude에게 맡기는 역할 분리 구조입니다.

### analyzer.py — 메인 에이전트 루프

```python
import anthropic
from tools import TOOLS, execute_tool

def analyze_stock(ticker: str, period: str = "3mo") -> str:
    client = anthropic.Anthropic()
    
    messages = [
        {
            "role": "user",
            "content": f"""
{ticker} 종목을 분석해 투자 판단에 도움이 되는 리포트를 작성해주세요.

분석 기간: {period}
포함할 내용:
1. 현재 가격과 기간 대비 수익률
2. 재무 지표 (PER, PBR, 배당수익률)
3. 기술적 분석 (고점/저점 대비 현재 위치)
4. 종합 평가 (한국어로 작성)
"""
        }
    ]
    
    # 에이전트 루프 — 도구 호출이 없을 때까지 반복
    while True:
        response = client.messages.create(
            model="claude-opus-4-6",
            max_tokens=4096,
            tools=TOOLS,
            messages=messages
        )
        
        # 도구 호출이 없으면 최종 응답
        if response.stop_reason == "end_turn":
            for block in response.content:
                if hasattr(block, "text"):
                    return block.text
            break
        
        # 도구 호출 처리
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                result = execute_tool(block.name, block.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": result
                })
        
        # 대화 이력에 추가
        messages.append({"role": "assistant", "content": response.content})
        messages.append({"role": "user", "content": tool_results})
    
    return "분석 실패"

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticker", required=True)
    parser.add_argument("--period", default="3mo")
    args = parser.parse_args()
    
    print(analyze_stock(args.ticker, args.period))
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 섹터 비교 분석 | `"반도체 섹터 상위 5개 종목을 비교해서 가장 저평가된 종목을 골라줘"` |
| 포트폴리오 리뷰 | `"내 포트폴리오 [AAPL, MSFT, NVDA]의 3개월 성과를 평가하고 리밸런싱 의견을 줘"` |
| 리스크 점검 | `"삼성전자 현재 52주 고점 대비 낙폭과 재무 건전성을 기준으로 투자 위험도를 평가해줘"` |
| 뉴스 연계 분석 | `"최근 AI 관련 뉴스를 반영해 NVDA 단기 전망을 분석해줘"` |

## 확장 아이디어

- **웹훅 연동**: 분석 결과를 Slack이나 Discord로 자동 전송
- **정기 리포트**: cron으로 매일 오전 포트폴리오 요약 알림
- **암호화폐 지원**: `ccxt` 라이브러리로 업비트/바이낸스 데이터 연동
- **백테스팅**: AI 분석 결과를 과거 데이터로 검증하는 모듈 추가

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
