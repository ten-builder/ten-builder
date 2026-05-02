# AI 에이전트 기반 로그 분석 및 이상 감지 시스템

> 대규모 서비스 로그에서 이상 패턴을 실시간으로 감지하고, AI가 근본 원인까지 분석하는 Python 예제 프로젝트

## 이 예제에서 배울 수 있는 것

- OpenSearch Random Cut Forest(RCF) 알고리즘으로 로그 이상 감지 설정하기
- Claude API Tool Use로 이상 감지 결과를 자연어 분석으로 연결하기
- 실시간 로그 스트리밍 + AI 분석 파이프라인 구성 패턴
- 에러 급증, 응답 지연, 비정상 트래픽 패턴을 자동으로 분류하기

## 프로젝트 구조

```
ai-log-anomaly-detection/
├── README.md
├── requirements.txt
├── config.py                   # OpenSearch + Claude 설정
├── log_ingestion.py            # 로그 수집 & 전처리
├── anomaly_detector.py         # RCF 이상 감지 + AI 분석
├── alert_handler.py            # 알림 전송 (Slack/PagerDuty)
├── dashboard.py                # 이상 감지 대시보드 (Streamlit)
└── examples/
    ├── sample_logs.json        # 테스트용 샘플 로그
    └── demo_scenario.py        # 데모 시나리오 실행
```

## 시작하기

```bash
# 의존성 설치
pip install opensearch-py anthropic streamlit pandas numpy python-dotenv

# OpenSearch 로컬 실행 (Docker)
docker run -d -p 9200:9200 -p 9600:9600 \
  -e "discovery.type=single-node" \
  -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=Admin@1234!" \
  opensearchproject/opensearch:2.13.0

# 환경변수 설정
cp .env.example .env
# ANTHROPIC_API_KEY, OPENSEARCH_HOST 입력

# 실행
python anomaly_detector.py --demo
```

## 핵심 코드

### 1. OpenSearch 이상 감지 설정

```python
# anomaly_detector.py
from opensearchpy import OpenSearch
import anthropic
import json

class LogAnomalyDetector:
    def __init__(self):
        self.os_client = OpenSearch(
            hosts=[{"host": "localhost", "port": 9200}],
            http_auth=("admin", "Admin@1234!"),
            use_ssl=False
        )
        self.claude = anthropic.Anthropic()
        self._setup_detector()

    def _setup_detector(self):
        """RCF 기반 이상 감지기 생성"""
        detector_config = {
            "name": "service-log-anomaly-detector",
            "description": "서비스 로그 이상 패턴 실시간 감지",
            "time_field": "@timestamp",
            "indices": ["service-logs-*"],
            "feature_attributes": [
                {
                    "feature_name": "error_rate",
                    "feature_enabled": True,
                    "aggregation_query": {
                        "error_rate": {
                            "avg": {"field": "error_count"}
                        }
                    }
                },
                {
                    "feature_name": "response_time_p99",
                    "feature_enabled": True,
                    "aggregation_query": {
                        "response_time_p99": {
                            "percentiles": {
                                "field": "response_time_ms",
                                "percents": [99]
                            }
                        }
                    }
                }
            ],
            "detection_interval": {"period": {"interval": 1, "unit": "Minutes"}},
            "window_delay": {"period": {"interval": 0, "unit": "Minutes"}}
        }

        response = self.os_client.transport.perform_request(
            "POST",
            "/_plugins/_anomaly_detection/detectors",
            body=detector_config
        )
        self.detector_id = response["_id"]
        print(f"이상 감지기 생성: {self.detector_id}")
```

### 2. AI 근본 원인 분석

```python
    def analyze_anomaly_with_ai(self, anomaly_result: dict) -> str:
        """Claude로 이상 감지 결과 분석"""
        
        # 주변 로그 컨텍스트 수집
        context_logs = self._get_context_logs(
            anomaly_result["data_start_time"],
            anomaly_result["data_end_time"]
        )

        tools = [
            {
                "name": "query_logs",
                "description": "특정 조건으로 로그 쿼리",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "query": {"type": "string", "description": "OpenSearch DSL 쿼리"},
                        "time_range": {"type": "string"}
                    }
                }
            },
            {
                "name": "check_deployment_events",
                "description": "이상 감지 시점의 배포/변경 이벤트 확인",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "start_time": {"type": "string"},
                        "end_time": {"type": "string"}
                    }
                }
            }
        ]

        response = self.claude.messages.create(
            model="claude-opus-4-7-20260401",
            max_tokens=1500,
            tools=tools,
            messages=[{
                "role": "user",
                "content": f"""다음 이상 감지 결과를 분석해 주세요.

이상 감지 결과:
- 감지 시각: {anomaly_result['data_start_time']}
- 이상 점수: {anomaly_result['anomaly_grade']:.2f} (0~1, 높을수록 이상)
- 신뢰도: {anomaly_result['confidence']:.2f}
- 주요 피처: {json.dumps(anomaly_result['feature_data'], ensure_ascii=False)}

주변 로그 샘플:
{context_logs[:3000]}

다음을 분석해 주세요:
1. 이상 패턴의 성격 (에러 급증 / 지연 증가 / 트래픽 이상)
2. 가능한 근본 원인 (3가지 이내)
3. 즉시 확인해야 할 사항
4. 심각도 등급 (P1~P4)"""
            }]
        )

        # Tool 호출 처리
        if response.stop_reason == "tool_use":
            return self._handle_tool_calls(response, tools)
        
        return response.content[0].text
```

### 3. 실시간 스트리밍 파이프라인

```python
    def stream_and_detect(self, index_pattern: str):
        """실시간 로그 스트리밍 + 이상 감지"""
        import time
        
        print(f"로그 스트리밍 시작: {index_pattern}")
        
        while True:
            # 최신 이상 감지 결과 조회
            results = self.os_client.transport.perform_request(
                "GET",
                f"/_plugins/_anomaly_detection/detectors/{self.detector_id}/results",
                params={
                    "start_time_ms": int(time.time() * 1000) - 300000,  # 최근 5분
                    "end_time_ms": int(time.time() * 1000),
                    "anomaly_threshold": 0.6  # 이상 점수 0.6 이상만
                }
            )
            
            anomalies = results.get("anomalies", [])
            
            for anomaly in anomalies:
                if anomaly["anomaly_grade"] >= 0.7:  # 높은 이상 점수
                    print(f"[ALERT] 이상 감지! 점수: {anomaly['anomaly_grade']:.2f}")
                    
                    # AI 분석 실행
                    analysis = self.analyze_anomaly_with_ai(anomaly)
                    
                    # 알림 전송
                    self.alert_handler.send(
                        level="P1" if anomaly["anomaly_grade"] > 0.9 else "P2",
                        message=analysis,
                        raw_data=anomaly
                    )
            
            time.sleep(60)  # 1분마다 체크
```

## 설정 파일

```python
# config.py
from dataclasses import dataclass

@dataclass
class DetectorConfig:
    # OpenSearch
    os_host: str = "localhost"
    os_port: int = 9200
    os_user: str = "admin"
    os_password: str = "Admin@1234!"
    
    # 이상 감지 민감도
    anomaly_threshold: float = 0.6   # 이상 점수 임계값 (0~1)
    confidence_threshold: float = 0.9 # 신뢰도 임계값
    
    # AI 분석 설정
    ai_model: str = "claude-sonnet-4-6"  # 빠른 분석용
    ai_model_deep: str = "claude-opus-4-7-20260401"  # P1 심층 분석용
    
    # 알림
    alert_channels: list = None  # ["slack", "pagerduty"]
    check_interval_sec: int = 60
```

## AI 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 초기 설정 | `"이 서비스 로그 형식에 맞는 OpenSearch 이상 감지기 설정을 만들어줘: {로그_샘플}"` |
| 임계값 조정 | `"지난 1주일 이상 감지 결과를 분석해서 false positive를 줄이는 임계값을 제안해줘"` |
| 패턴 학습 | `"이 에러 패턴이 배포와 관련 있는지 배포 이력과 비교해줘"` |
| 알림 최적화 | `"중복 알림을 줄이기 위한 이상 감지 그룹핑 전략을 제안해줘"` |

## 문제 해결

| 문제 | 해결 |
|------|------|
| false positive 많음 | `anomaly_threshold` 0.6→0.75로 상향, window_delay 늘리기 |
| 감지 지연 심함 | `detection_interval`을 5분→1분으로 줄이기 |
| OpenSearch 연결 오류 | `docker ps`로 컨테이너 상태 확인, 9200 포트 개방 여부 점검 |
| API 비용 과다 | P2 이하 알림은 `claude-sonnet-4-6`으로 처리, P1만 Opus 사용 |

## 다음 단계

- 여러 서비스의 이상 패턴을 상관 분석하는 [멀티 서비스 이상 감지](../ai-realtime-collab-editor/) 패턴
- 이상 감지와 자동 롤백을 연결하는 [자율 에러 복구 워크플로우](../../workflows/ai-autonomous-error-recovery.md)

---

**더 자세한 가이드:** [claude-code/playbooks](../../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
