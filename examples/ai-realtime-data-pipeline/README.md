# AI 에이전트 실시간 데이터 파이프라인 예제

> Kafka + Python + Claude API로 이벤트 스트림을 실시간 처리하는 완전한 예제 프로젝트

## 이 예제에서 배울 수 있는 것

- Apache Kafka 기반 Producer/Consumer 구조 설계
- Claude API를 파이프라인 중간 처리 단계로 통합하는 패턴
- 비동기 이벤트 처리와 AI 분석을 결합하는 방법
- 실제 운영 환경에서 쓸 수 있는 에러 핸들링 및 재시도 전략

## 프로젝트 구조

```
ai-realtime-data-pipeline/
├── README.md
├── requirements.txt
├── docker-compose.yml        # Kafka + Zookeeper 로컬 환경
├── producer/
│   ├── __init__.py
│   └── event_producer.py     # 이벤트 생성 및 Kafka 전송
├── processor/
│   ├── __init__.py
│   ├── consumer.py           # Kafka Consumer
│   └── ai_analyzer.py        # Claude API 분석 레이어
├── config/
│   └── settings.py           # 환경 변수 및 설정
└── tests/
    ├── test_producer.py
    └── test_analyzer.py
```

## 시작하기

### 1. 환경 설정

```bash
# 저장소 클론
git clone https://github.com/ten-builder/ten-builder.git
cd ten-builder/examples/ai-realtime-data-pipeline

# 의존성 설치
pip install -r requirements.txt

# 환경 변수 설정
cp .env.example .env
# .env 파일에 ANTHROPIC_API_KEY, Kafka 설정 입력
```

### 2. Kafka 실행

```bash
# Docker Compose로 로컬 Kafka 실행
docker-compose up -d

# 토픽 생성 확인
docker exec -it kafka kafka-topics.sh --list --bootstrap-server localhost:9092
```

### 3. 파이프라인 실행

```bash
# Consumer/Processor 먼저 실행
python -m processor.consumer &

# Producer로 이벤트 전송 시작
python -m producer.event_producer
```

## 핵심 코드

### Producer — 이벤트 생성 및 전송

```python
# producer/event_producer.py
from confluent_kafka import Producer
import json
import time
from config.settings import KAFKA_BOOTSTRAP_SERVERS, TOPIC_NAME

def create_producer() -> Producer:
    return Producer({
        "bootstrap.servers": KAFKA_BOOTSTRAP_SERVERS,
        "acks": "all",           # 모든 복제본 확인 후 전송
        "retries": 3,
        "retry.backoff.ms": 1000,
    })

def delivery_callback(err, msg):
    if err:
        print(f"[ERROR] 전송 실패: {err}")
    else:
        print(f"[OK] 전송 완료 → topic={msg.topic()}, offset={msg.offset()}")

def send_event(producer: Producer, event: dict) -> None:
    producer.produce(
        topic=TOPIC_NAME,
        key=str(event["id"]).encode("utf-8"),
        value=json.dumps(event, ensure_ascii=False).encode("utf-8"),
        callback=delivery_callback,
    )
    producer.poll(0)  # 콜백 처리

def main():
    producer = create_producer()
    sample_events = [
        {"id": 1, "type": "user_action", "data": "로그인", "timestamp": time.time()},
        {"id": 2, "type": "purchase",    "data": "상품 구매 완료", "timestamp": time.time()},
        {"id": 3, "type": "error",       "data": "결제 실패 — 잔액 부족", "timestamp": time.time()},
    ]
    for event in sample_events:
        send_event(producer, event)
        time.sleep(0.5)

    producer.flush()  # 버퍼에 남은 메시지 전부 전송
    print("모든 이벤트 전송 완료")

if __name__ == "__main__":
    main()
```

**왜 이렇게 했나요?**

`acks="all"`은 성능보다 신뢰성을 우선하는 설정이에요. 리더와 모든 팔로워가 메시지를 받은 뒤 확인하기 때문에, 브로커 장애가 생겨도 데이터가 유실되지 않아요. 실시간 처리라고 해서 반드시 최고 속도가 필요한 건 아닙니다 — 유실이 치명적인 데이터라면 이 옵션을 기본으로 써요.

### Consumer + AI 분석 레이어

```python
# processor/consumer.py
from confluent_kafka import Consumer, KafkaError
import json
from processor.ai_analyzer import analyze_event
from config.settings import KAFKA_BOOTSTRAP_SERVERS, TOPIC_NAME, CONSUMER_GROUP

def create_consumer() -> Consumer:
    return Consumer({
        "bootstrap.servers": KAFKA_BOOTSTRAP_SERVERS,
        "group.id": CONSUMER_GROUP,
        "auto.offset.reset": "earliest",
        "enable.auto.commit": False,   # 수동 커밋으로 처리 보장
    })

def process_message(msg_value: str) -> None:
    event = json.loads(msg_value)
    result = analyze_event(event)
    print(f"[분석 완료] id={event['id']} → {result['summary']}")

def run():
    consumer = create_consumer()
    consumer.subscribe([TOPIC_NAME])

    try:
        while True:
            msg = consumer.poll(timeout=1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                print(f"[ERROR] {msg.error()}")
                continue

            process_message(msg.value().decode("utf-8"))
            consumer.commit(asynchronous=False)  # 처리 성공 후 커밋

    except KeyboardInterrupt:
        print("Consumer 종료")
    finally:
        consumer.close()

if __name__ == "__main__":
    run()
```

```python
# processor/ai_analyzer.py
import anthropic

client = anthropic.Anthropic()

EVENT_TYPE_PROMPTS = {
    "error":       "다음 에러 이벤트의 심각도와 즉각적인 대응 방안을 한 문장으로 요약하세요.",
    "purchase":    "다음 구매 이벤트에서 비정상 패턴이 있는지 간략히 판단하세요.",
    "user_action": "다음 사용자 행동이 UX 개선에 참고할 만한 패턴인지 한 문장으로 판단하세요.",
}

def analyze_event(event: dict) -> dict:
    event_type = event.get("type", "unknown")
    prompt = EVENT_TYPE_PROMPTS.get(
        event_type,
        "다음 이벤트를 간략히 요약하세요."
    )

    response = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=150,
        messages=[{
            "role": "user",
            "content": f"{prompt}\n\n이벤트: {event['data']}"
        }]
    )

    return {
        "event_id":  event["id"],
        "event_type": event_type,
        "summary":   response.content[0].text.strip(),
    }
```

**왜 이렇게 했나요?**

`enable.auto.commit=False` + `commit(asynchronous=False)` 조합은 "처리 완료 후에만 오프셋을 앞당기는" 패턴이에요. AI 분석 도중 예외가 발생하면 오프셋이 전진하지 않아서, 재시작 시 해당 메시지를 다시 처리할 수 있어요. 자동 커밋은 처리가 실패해도 오프셋이 이미 넘어가는 함정이 있어 at-least-once 보장이 필요한 파이프라인에서는 수동 커밋이 기본이에요.

### Docker Compose 설정

```yaml
# docker-compose.yml
version: "3.8"

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.6.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  kafka:
    image: confluentinc/cp-kafka:7.6.0
    depends_on: [zookeeper]
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
```

### 의존성

```text
# requirements.txt
confluent-kafka==2.8.0
anthropic>=0.30.0
python-dotenv>=1.0.0
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| Consumer 로직 추가 | `Consumer에 Dead Letter Queue 패턴을 추가해줘. 처리 실패 이벤트는 'dlq-events' 토픽으로 보내야 해` |
| 분석 결과 저장 | `analyze_event 결과를 PostgreSQL에 upsert하는 코드를 추가해줘. asyncpg 써도 좋아` |
| 토픽 분기 처리 | `이벤트 type에 따라 서로 다른 Kafka 토픽으로 라우팅하는 Producer 라우터 클래스를 만들어줘` |
| 성능 튜닝 | `Consumer를 asyncio 기반으로 바꿔서 AI 분석을 병렬로 실행할 수 있게 해줘` |
| 모니터링 추가 | `Prometheus 메트릭 수집 코드를 추가해줘. 처리 속도와 에러율을 측정하고 싶어` |

## 확장 아이디어

이 예제를 기반으로 더 복잡한 시나리오를 구성할 수 있어요:

- **다중 토픽 처리:** 이벤트 종류별로 토픽을 분리하고, 각 토픽마다 전용 Consumer를 붙이는 구조
- **AI 결과 재스트리밍:** Claude 분석 결과를 또 다른 Kafka 토픽에 발행해서 하류 서비스가 소비하는 패턴
- **배치 + 스트리밍 혼용:** 짧은 시간 내 도착한 이벤트를 모아 한 번에 AI에 보내면 API 비용과 처리 속도 모두 잡을 수 있어요

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
