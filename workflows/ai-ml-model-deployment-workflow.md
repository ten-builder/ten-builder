# AI 에이전트 기반 머신러닝 모델 배포 워크플로우

> Hugging Face 모델을 AI 에이전트로 최적화하고 프로덕션 API 서버로 배포하는 단계별 워크플로우

## 개요

직접 학습한 모델이든 Hugging Face의 사전 학습 모델이든, "로컬에서 잘 돌아가는 모델"을 "프로덕션에서 안정적으로 서비스하는 API"로 만드는 과정은 생각보다 복잡합니다.

이 워크플로우는 AI 에이전트(Claude Code, Codex 등)를 활용해 모델 양자화 → FastAPI 래핑 → Docker 컨테이너화 → Kubernetes 배포 → A/B 테스트까지 자동화하는 방법을 다룹니다.

**이 워크플로우로 해결하는 문제:**
- 모델 크기가 너무 커서 서빙 비용이 높음
- 추론 속도가 느려 API 응답 시간이 허용 범위를 초과함
- 배포 과정이 반복적이고 실수가 잦음
- 새 모델 버전 배포 시 롤백이 어려움

## 사전 준비

- Python 3.10+, Docker, kubectl 설치
- Hugging Face 모델 (또는 로컬 `.safetensors` / `.gguf` 파일)
- Kubernetes 클러스터 접근 권한 (로컬 테스트는 minikube 가능)
- MLflow 또는 동등한 모델 레지스트리 (선택 사항이지만 권장)

## Step 1: AI 에이전트로 모델 양자화 설정

모델을 서빙하기 전에 크기를 줄이는 게 먼저입니다. AI 에이전트에 다음과 같이 요청하세요:

```
"transformers와 optimum 라이브러리를 사용해서
{모델명} 모델을 INT8 양자화하는 스크립트를 작성해줘.
원본 모델과 양자화 모델의 크기 비교, 추론 속도 벤치마크도 포함해줘."
```

에이전트가 생성하는 기본 양자화 코드:

```python
from transformers import AutoModelForSequenceClassification, AutoTokenizer
from optimum.onnxruntime import ORTModelForSequenceClassification
import torch

model_id = "klue/roberta-base"

# 원본 모델 로드
tokenizer = AutoTokenizer.from_pretrained(model_id)

# ONNX 변환 + INT8 양자화
ort_model = ORTModelForSequenceClassification.from_pretrained(
    model_id,
    export=True,
    provider="CPUExecutionProvider",
)

# 정적 양자화 적용
from optimum.onnxruntime.configuration import AutoQuantizationConfig
qconfig = AutoQuantizationConfig.arm64(is_static=False, per_channel=False)

from optimum.onnxruntime import ORTQuantizer
quantizer = ORTQuantizer.from_pretrained(ort_model)
quantizer.quantize(save_dir="./quantized_model", quantization_config=qconfig)
```

**에이전트 활용 팁:** 양자화 후 정확도 손실이 허용 범위(보통 1~2% 이내)를 넘으면 에이전트에게 "FP16 양자화로 재시도해달라"고 요청하세요. INT8보다 크기 감소가 적지만 정확도 손실이 거의 없습니다.

## Step 2: FastAPI 서버 생성

AI 에이전트에게 FastAPI 래퍼 작성을 맡깁니다:

```
"위에서 만든 양자화 모델을 FastAPI로 서빙하는 코드를 작성해줘.
- /predict 엔드포인트 (POST, 배치 처리 지원)
- /health 엔드포인트
- Pydantic으로 입출력 검증
- 모델 로드는 앱 시작 시 1회만
- 비동기 처리로 동시 요청 처리"
```

에이전트가 생성하는 기본 구조:

```python
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
import asyncio
from concurrent.futures import ThreadPoolExecutor

app = FastAPI(title="ML Model API", version="1.0.0")
executor = ThreadPoolExecutor(max_workers=4)

# 모델 전역 로드 (시작 시 1회)
model = None
tokenizer = None

@app.on_event("startup")
async def load_model():
    global model, tokenizer
    from optimum.onnxruntime import ORTModelForSequenceClassification
    from transformers import AutoTokenizer
    tokenizer = AutoTokenizer.from_pretrained("./quantized_model")
    model = ORTModelForSequenceClassification.from_pretrained("./quantized_model")

class PredictRequest(BaseModel):
    texts: List[str]
    max_length: int = 512

class PredictResponse(BaseModel):
    predictions: List[dict]
    processing_time_ms: float

@app.post("/predict", response_model=PredictResponse)
async def predict(request: PredictRequest):
    import time
    start = time.time()
    
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        executor,
        lambda: _run_inference(request.texts, request.max_length)
    )
    
    elapsed = (time.time() - start) * 1000
    return PredictResponse(predictions=result, processing_time_ms=elapsed)

@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": model is not None}

def _run_inference(texts: List[str], max_length: int):
    inputs = tokenizer(
        texts, return_tensors="pt",
        padding=True, truncation=True,
        max_length=max_length
    )
    outputs = model(**inputs)
    # 분류 태스크 예시
    import torch
    probs = torch.softmax(outputs.logits, dim=-1)
    return [{"label": int(p.argmax()), "score": float(p.max())} for p in probs]
```

## Step 3: Docker 컨테이너화

```
"위 FastAPI 앱을 Dockerfile로 컨테이너화해줘.
멀티스테이지 빌드로 이미지 크기를 최소화하고,
비루트 사용자로 실행하게 해줘."
```

```dockerfile
# 빌드 스테이지
FROM python:3.11-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# 런타임 스테이지
FROM python:3.11-slim

# 비루트 사용자
RUN useradd -m -u 1000 mluser
WORKDIR /app

# 의존성 복사
COPY --from=builder /root/.local /home/mluser/.local
COPY --chown=mluser:mluser . .

USER mluser
ENV PATH=/home/mluser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "2"]
```

빌드 및 로컬 테스트:

```bash
docker build -t ml-api:v1.0.0 .
docker run -p 8080:8080 ml-api:v1.0.0

# 헬스체크
curl http://localhost:8080/health

# 추론 테스트
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"texts": ["테스트 문장입니다"]}'
```

## Step 4: Kubernetes 배포 설정

AI 에이전트에게 Kubernetes 매니페스트 생성을 요청합니다:

```
"이 Docker 이미지를 Kubernetes에 배포하는 매니페스트를 작성해줘.
- Deployment: 2 replicas, 리소스 제한 포함
- Service: ClusterIP
- HorizontalPodAutoscaler: CPU 70% 기준 2~10개 스케일
- ConfigMap: 환경변수 분리"
```

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-api
  labels:
    app: ml-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ml-api
  template:
    metadata:
      labels:
        app: ml-api
    spec:
      containers:
      - name: ml-api
        image: ml-api:v1.0.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
---
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ml-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ml-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

배포 실행:

```bash
kubectl apply -f deployment.yaml
kubectl apply -f hpa.yaml

# 배포 확인
kubectl rollout status deployment/ml-api
kubectl get pods -l app=ml-api
```

## Step 5: A/B 테스트 설정

새 모델 버전을 안전하게 배포하려면 트래픽을 분산시킵니다:

```bash
# v2 모델 배포 (트래픽 20% 할당)
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-api-v2
spec:
  replicas: 1  # 전체 5개 중 1개 = 20%
  selector:
    matchLabels:
      app: ml-api
      version: v2
  template:
    metadata:
      labels:
        app: ml-api
        version: v2
    spec:
      containers:
      - name: ml-api
        image: ml-api:v2.0.0
        # ... 나머지 동일
EOF
```

A/B 테스트 메트릭 수집을 에이전트에게 요청:

```
"Prometheus + Grafana로 두 버전의 응답시간, 에러율,
추론 정확도를 비교하는 대시보드 설정을 작성해줘."
```

## 커스터마이징

| 설정 | 기본값 | 설명 |
|------|--------|------|
| 양자화 방식 | INT8 | FP16(정확도 우선) / INT8(속도 우선) / GGUF(엣지) |
| API 워커 수 | 2 | CPU 코어 수 × 0.5~1 권장 |
| HPA 최대 복제 | 10 | 트래픽 패턴에 따라 조정 |
| 배치 최대 크기 | 32 | GPU 메모리 또는 CPU 메모리에 맞게 조정 |
| 요청 타임아웃 | 30초 | 모델 크기에 따라 조정 |

## 문제 해결

| 문제 | 확인 사항 | 해결 |
|------|-----------|------|
| 추론 속도 느림 | `top`으로 CPU 사용률 확인 | 워커 수 늘리기 또는 GPU 인스턴스 전환 |
| OOMKilled 에러 | `kubectl describe pod` | 메모리 제한 상향 또는 배치 크기 축소 |
| 모델 로드 실패 | 컨테이너 로그 확인 | 모델 파일 경로, 의존성 버전 점검 |
| HPA 스케일 안됨 | metrics-server 설치 여부 | `kubectl top nodes` 동작 확인 |
| 정확도 저하 | 양자화 전후 비교 | FP16으로 전환하거나 원본 모델 유지 |

## AI 에이전트 활용 포인트

| 단계 | 에이전트 프롬프트 예시 |
|------|----------------------|
| 초기 설정 | `"이 모델의 추론 벤치마크를 측정하는 스크립트 작성해줘"` |
| 최적화 | `"INT8 양자화 후 정확도 손실이 3%야. FP16으로 재시도해줘"` |
| 디버깅 | `"kubectl logs에 이 에러가 있어. 원인과 수정 방법 알려줘: {에러}"` |
| 모니터링 | `"응답시간 P95가 500ms 넘으면 Slack 알림 보내는 설정 만들어줘"` |
| 롤백 | `"v2 배포 후 에러율이 올랐어. v1으로 즉시 롤백하는 방법 알려줘"` |

---

**더 자세한 가이드:** [claude-code/playbooks](../claude-code/playbooks/)

**뉴스레터:** [maily.so/tenbuilder](https://maily.so/tenbuilder)
