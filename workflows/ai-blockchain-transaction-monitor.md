# AI 에이전트 기반 블록체인 트랜잭션 모니터링 워크플로우

> Solana 온체인 이벤트를 실시간으로 구독하고, AI가 이상 거래를 자동 감지하여 알림을 전송하는 모니터링 파이프라인

## 이 워크플로우가 해결하는 문제

블록체인 트랜잭션은 수십 밀리초 단위로 발생하고, 고래 이동·플래시 론 공격·컨트랙트 이상 등 중요한 이벤트는 눈깜짝할 사이에 지나갑니다. 수동 모니터링은 불가능에 가깝고, 단순 임계값 알림은 맥락 없는 노이즈를 쏟아냅니다.

AI 에이전트를 결합하면 다음이 가능합니다.

- WebSocket으로 온체인 이벤트 실시간 구독
- 트랜잭션 패턴을 AI가 맥락 있게 분석
- 이상 거래만 골라 Discord/Slack으로 요약 전송
- 24시간 무인 운영

## 사전 준비

- Solana RPC 엔드포인트 (Helius, QuickNode, 또는 공개 RPC)
- Python 3.11+
- Anthropic API 키
- Discord/Slack Webhook URL

```bash
pip install solana solders anthropic websockets python-dotenv
```

## 아키텍처

```
Solana RPC (WebSocket)
        │
        ▼
  이벤트 수신 레이어
  (subscribe_logs / accountSubscribe)
        │
        ▼
  필터링 레이어
  (프로그램 ID, 트랜잭션 유형, 금액 임계값)
        │
        ▼
  AI 분석 레이어
  (Claude API — 패턴 분석, 위험도 평가)
        │
        ▼
  알림 레이어
  (Discord/Slack Webhook)
```

## Step 1: 환경 설정

```python
# .env
SOLANA_RPC_WS=wss://mainnet.helius-rpc.com/?api-key=YOUR_KEY
ANTHROPIC_API_KEY=sk-ant-...
DISCORD_WEBHOOK=https://discord.com/api/webhooks/...
TARGET_PROGRAM=TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA  # SPL Token
ALERT_THRESHOLD_SOL=100  # 100 SOL 이상 거래만 분석
```

```python
# monitor.py
import asyncio
import json
import os
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

SOLANA_RPC_WS = os.getenv("SOLANA_RPC_WS")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
DISCORD_WEBHOOK = os.getenv("DISCORD_WEBHOOK")
TARGET_PROGRAM = os.getenv("TARGET_PROGRAM")
ALERT_THRESHOLD = float(os.getenv("ALERT_THRESHOLD_SOL", "100"))
```

## Step 2: WebSocket 이벤트 구독

```python
import websockets
import anthropic

async def subscribe_program_logs(program_id: str):
    """프로그램 로그 실시간 구독"""
    subscribe_msg = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "logsSubscribe",
        "params": [
            {"mentions": [program_id]},
            {"commitment": "finalized"}
        ]
    }

    async with websockets.connect(SOLANA_RPC_WS) as ws:
        await ws.send(json.dumps(subscribe_msg))
        
        # 구독 확인
        response = await ws.recv()
        sub_data = json.loads(response)
        subscription_id = sub_data.get("result")
        print(f"구독 시작: {subscription_id}")
        
        while True:
            try:
                message = await asyncio.wait_for(ws.recv(), timeout=30)
                event = json.loads(message)
                
                if "params" in event:
                    log_data = event["params"]["result"]["value"]
                    await process_transaction(log_data)
                    
            except asyncio.TimeoutError:
                # 연결 유지를 위한 ping
                await ws.ping()
            except websockets.exceptions.ConnectionClosed:
                print("연결 끊김 — 재시도 중...")
                break
```

## Step 3: 트랜잭션 필터링

```python
def extract_transaction_info(log_data: dict) -> dict | None:
    """트랜잭션 기본 정보 추출 및 1차 필터링"""
    signature = log_data.get("signature", "")
    logs = log_data.get("logs", [])
    
    # 에러 트랜잭션 필터
    if log_data.get("err"):
        return None
    
    # 관련 로그 키워드 추출
    relevant_logs = [
        log for log in logs
        if any(kw in log for kw in [
            "Transfer", "Burn", "Mint", 
            "swap", "liquidat", "flash"
        ])
    ]
    
    if not relevant_logs:
        return None
    
    return {
        "signature": signature,
        "logs": relevant_logs[:10],  # 최대 10줄
        "timestamp": datetime.utcnow().isoformat(),
        "program": TARGET_PROGRAM[:8] + "..."
    }
```

## Step 4: AI 분석

```python
client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

ANALYSIS_PROMPT = """다음 Solana 트랜잭션 로그를 분석하세요.

트랜잭션: {signature}
시각: {timestamp}
로그:
{logs}

다음 형식으로 간결하게 분석하세요:
1. 거래 유형 (한 줄)
2. 위험도: LOW / MEDIUM / HIGH
3. 주목 이유 (있으면)
4. 권장 조치 (HIGH인 경우만)

HIGH 위험도 기준:
- 플래시 론 패턴
- 이상 대량 토큰 소각/발행
- 알려진 취약 패턴과 유사
"""

async def analyze_with_ai(tx_info: dict) -> dict:
    """Claude로 트랜잭션 패턴 분석"""
    logs_text = "\n".join(tx_info["logs"])
    
    message = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=300,
        messages=[{
            "role": "user",
            "content": ANALYSIS_PROMPT.format(
                signature=tx_info["signature"],
                timestamp=tx_info["timestamp"],
                logs=logs_text
            )
        }]
    )
    
    analysis = message.content[0].text
    
    # 위험도 파싱
    risk_level = "LOW"
    if "HIGH" in analysis:
        risk_level = "HIGH"
    elif "MEDIUM" in analysis:
        risk_level = "MEDIUM"
    
    return {
        **tx_info,
        "analysis": analysis,
        "risk_level": risk_level
    }
```

## Step 5: 알림 전송

```python
import aiohttp

RISK_EMOJI = {
    "HIGH": "🔴",
    "MEDIUM": "🟡", 
    "LOW": "🟢"
}

async def send_discord_alert(result: dict):
    """Discord로 분석 결과 전송"""
    if result["risk_level"] == "LOW":
        return  # LOW는 알림 생략
    
    emoji = RISK_EMOJI[result["risk_level"]]
    sig_short = result["signature"][:16] + "..."
    
    payload = {
        "content": f"{emoji} **{result['risk_level']} 위험 트랜잭션 감지**",
        "embeds": [{
            "title": f"서명: `{sig_short}`",
            "description": result["analysis"],
            "fields": [
                {
                    "name": "시각",
                    "value": result["timestamp"],
                    "inline": True
                },
                {
                    "name": "Explorer",
                    "value": f"[Solscan](https://solscan.io/tx/{result['signature']})",
                    "inline": True
                }
            ],
            "color": 0xFF0000 if result["risk_level"] == "HIGH" else 0xFFFF00
        }]
    }
    
    async with aiohttp.ClientSession() as session:
        await session.post(DISCORD_WEBHOOK, json=payload)
```

## Step 6: 전체 파이프라인 실행

```python
async def process_transaction(log_data: dict):
    """트랜잭션 처리 파이프라인"""
    # 1. 정보 추출 및 필터링
    tx_info = extract_transaction_info(log_data)
    if not tx_info:
        return
    
    # 2. AI 분석
    result = await analyze_with_ai(tx_info)
    
    # 3. 알림 전송
    await send_discord_alert(result)
    
    # 4. 로그 기록
    if result["risk_level"] != "LOW":
        print(f"[{result['risk_level']}] {result['signature'][:16]}...")

async def main():
    """재연결 루프가 있는 메인 실행"""
    print("모니터링 시작...")
    
    while True:
        try:
            await subscribe_program_logs(TARGET_PROGRAM)
        except Exception as e:
            print(f"에러: {e} — 5초 후 재시도")
            await asyncio.sleep(5)

if __name__ == "__main__":
    asyncio.run(main())
```

## 실행

```bash
# 단순 실행
python monitor.py

# 백그라운드 실행 (tmux)
tmux new-session -d -s monitor 'python monitor.py'

# 프로세스 관리 (systemd)
# /etc/systemd/system/blockchain-monitor.service 작성 후:
sudo systemctl enable --now blockchain-monitor
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `TARGET_PROGRAM` | SPL Token | 모니터링할 프로그램 ID |
| `ALERT_THRESHOLD_SOL` | 100 | 알림 임계값 (SOL) |
| `commitment` | finalized | confirmed로 변경 시 더 빠른 알림 |
| `max_tokens` | 300 | AI 분석 길이 조정 |

### 여러 프로그램 동시 모니터링

```python
PROGRAMS = [
    os.getenv("TOKEN_PROGRAM"),
    os.getenv("DEX_PROGRAM"),    # Raydium, Orca 등
    os.getenv("LENDING_PROGRAM") # Kamino, Marginfi 등
]

tasks = [subscribe_program_logs(pid) for pid in PROGRAMS if pid]
await asyncio.gather(*tasks)
```

## 문제 해결

| 문제 | 해결 |
|------|------|
| WebSocket 연결 자주 끊김 | commitment를 `confirmed`로 변경, ping 간격 줄이기 |
| API 비용 과다 | `ALERT_THRESHOLD_SOL` 높이기, LOW 트랜잭션 필터 강화 |
| 알림 누락 | 공개 RPC 대신 유료 RPC 사용 (Helius, QuickNode) |
| 분석 속도 느림 | `asyncio.Queue`로 배치 처리, `haiku` 모델 사용 |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
