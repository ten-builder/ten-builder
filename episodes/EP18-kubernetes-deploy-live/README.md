# EP18: AI 에이전트로 Kubernetes 앱 처음부터 배포하기

> Claude Code + kubectl + Helm으로 Node.js 마이크로서비스를 Kubernetes에 배포하는 전체 과정 라이브 코딩 — Deployment부터 HPA, 롤링 업데이트, 트러블슈팅까지

## 📺 영상

**[YouTube에서 보기](https://youtube.com/@ten-builder)**

---

## 이 에피소드에서 다루는 것

- Kubernetes의 핵심 리소스(Deployment, Service, Ingress, HPA)를 AI 에이전트로 빠르게 설정하는 방법
- Helm 차트를 처음부터 직접 만들고 버전 관리하는 실전 흐름
- 롤링 업데이트와 롤백을 Claude Code와 함께 자동화하는 패턴
- kubectl 오류를 AI 에이전트가 분석하고 수정하는 트러블슈팅 데모
- 실제 클러스터에 올라간 결과물 데모

---

## 스택

| 레이어 | 기술 |
|--------|------|
| 애플리케이션 | Node.js 22 + TypeScript + Fastify |
| 컨테이너 | Docker + Docker Buildx (멀티 플랫폼) |
| 오케스트레이션 | Kubernetes 1.32 (k3s 로컬 또는 EKS) |
| 패키지 관리 | Helm 3.17 |
| 인그레스 | NGINX Ingress Controller |
| 오토스케일 | Horizontal Pod Autoscaler (HPA) |
| AI 에이전트 | Claude Code + AGENTS.md |
| CI/CD | GitHub Actions |

---

## 타임라인

### Part 1 (0-30분): 환경 설정 + 첫 배포

```
0min  → k3s 클러스터 설치 + kubectl 컨텍스트 설정
5min  → Node.js 앱 Dockerfile 작성 (AI 에이전트 위임)
15min → Deployment + Service 매니페스트 생성
25min → 첫 배포 성공 확인
```

### Part 2 (30-60분): Helm 차트 + Ingress

```
30min → Helm 차트 구조 생성 (helm create)
40min → values.yaml 환경별 분리 (dev/prod)
50min → NGINX Ingress + TLS 설정
60min → 도메인 연결 확인
```

### Part 3 (60-90분): 자동화 + 트러블슈팅

```
60min → HPA 설정 + 부하 테스트
75min → 롤링 업데이트 시연
80min → 실패 시뮬레이션 + 롤백
90min → GitHub Actions CI/CD 파이프라인 연결
```

---

## 핵심 코드 & 설정

### AGENTS.md (Kubernetes 프로젝트용)

```markdown
# AGENTS.md

## 프로젝트
Node.js 마이크로서비스 Kubernetes 배포

## 기술 스택
- Node.js 22 + TypeScript
- Kubernetes 1.32 + Helm 3.17
- NGINX Ingress

## 중요 명령어
- 배포: `helm upgrade --install app ./charts/app -f values.prod.yaml`
- 상태 확인: `kubectl get pods -n production`
- 로그: `kubectl logs -l app=api -n production --tail=100`
- 롤백: `helm rollback app 0 -n production`

## 주의사항
- ConfigMap에 시크릿 직접 넣지 않기 (Kubernetes Secret 사용)
- requests/limits 반드시 설정
- liveness/readiness probe 누락 금지
```

### Deployment 매니페스트

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: your-registry/api:latest
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        envFrom:
        - configMapRef:
            name: api-config
        - secretRef:
            name: api-secrets
```

### HPA 설정

```yaml
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Helm values.yaml

```yaml
# charts/app/values.yaml
replicaCount: 2

image:
  repository: your-registry/api
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 3000

ingress:
  enabled: true
  className: nginx
  host: api.yourdomain.com
  tls: true

resources:
  requests:
    memory: 128Mi
    cpu: 100m
  limits:
    memory: 256Mi
    cpu: 500m

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yaml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Docker 빌드 & 푸시
      run: |
        docker buildx build \
          --platform linux/amd64,linux/arm64 \
          -t ${{ secrets.REGISTRY }}/api:${{ github.sha }} \
          --push .

    - name: Helm 배포
      run: |
        helm upgrade --install api ./charts/app \
          --namespace production \
          --set image.tag=${{ github.sha }} \
          --wait --timeout 5m
```

---

## AI 에이전트 활용 포인트

| 상황 | 프롬프트 예시 |
|------|-------------|
| 매니페스트 첫 생성 | `Node.js 앱을 위한 Deployment, Service, Ingress 매니페스트를 작성해줘. HPA와 PDB도 포함해서.` |
| 오류 분석 | `kubectl describe pod api-xxx 출력 붙여넣고: 이 에러의 원인과 해결법을 알려줘` |
| Helm 차트 생성 | `기존 k8s/ 폴더의 YAML들을 Helm 차트로 변환해줘. values.yaml에서 환경별로 분리 가능하게.` |
| 성능 튜닝 | `현재 requests/limits 설정을 보고 p95 응답시간 200ms 목표로 최적화 제안해줘` |
| 롤백 자동화 | `배포 후 healthcheck 실패하면 자동 롤백하는 스크립트를 작성해줘` |

---

## 트러블슈팅 실전

### Pod CrashLoopBackOff

```bash
# AI 에이전트에게 전달할 정보 수집
kubectl describe pod <pod-name> -n production
kubectl logs <pod-name> -n production --previous

# 프롬프트: "위 로그를 분석하고 CrashLoopBackOff 원인을 찾아줘"
```

### Pending 상태 해결

```bash
# 리소스 부족 확인
kubectl describe nodes | grep -A5 "Allocated resources"

# AI 에이전트 프롬프트: "노드 리소스 현황을 보고 Pending Pod을 해결하는 방법을 알려줘"
```

### Ingress 연결 안 됨

```bash
# 인그레스 상태 확인
kubectl get ingress -n production
kubectl describe ingress api-ingress -n production

# 인그레스 컨트롤러 로그 확인
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
```

---

## 따라하기

### Step 1: k3s 로컬 클러스터 설치

```bash
# macOS (Lima 사용)
brew install lima
limactl start template://k3s

# 또는 Docker Desktop Kubernetes 활성화
# kubectl 컨텍스트 확인
kubectl config current-context
```

### Step 2: 앱 + AGENTS.md 설정

```bash
mkdir my-k8s-app && cd my-k8s-app

# Claude Code 시작
claude

# 프롬프트: "Fastify 기반 REST API를 만들고 /healthz, /ready 엔드포인트를 포함해줘.
#            Dockerfile도 멀티스테이지로 작성해줘."
```

### Step 3: Helm 차트 생성

```bash
helm create charts/app

# Claude Code 프롬프트:
# "기존 k8s/*.yaml 파일들을 Helm 차트로 마이그레이션해줘.
#  values.yaml에서 image.tag, replicaCount, resources를 외부에서 주입 가능하게."
```

### Step 4: 배포 + 검증

```bash
# 로컬 배포
helm upgrade --install app ./charts/app \
  --namespace default \
  --create-namespace

# 상태 확인
kubectl get pods
kubectl get svc
kubectl port-forward svc/app 8080:80

# 테스트
curl localhost:8080/healthz
```

---

## 더 알아보기

- [AI 에이전트 기반 인프라 코드(IaC) 리뷰 워크플로우](../../workflows/ai-iac-code-review.md)
- [AI 에이전트 기반 API 게이트웨이 설계 워크플로우](../../workflows/ai-api-gateway-design-workflow.md)
- [AI 에이전트 그린필드 프로젝트 킥오프 플레이북](../../claude-code/playbooks/56-greenfield-project-kickoff.md)

---

**구독하기:** [@ten-builder](https://youtube.com/@ten-builder) | [뉴스레터](https://maily.so/tenbuilder)
