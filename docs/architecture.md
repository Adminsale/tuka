# Architecture Overview

## System Diagram

```
                        ┌─────────────────────────────────────┐
                        │           GitHub Actions             │
                        │  test → build → push → deploy        │
                        └──────────────┬──────────────────────┘
                                       │ ghcr.io image
                                       ▼
┌──────────┐   HTTP    ┌───────────────────────────────────────┐
│  Client  │──────────▶│  Ingress (nginx)                      │
└──────────┘           │  sre-demo.local                       │
                        └──────────────┬───────────────────────┘
                                       │
                        ┌──────────────▼───────────────────────┐
                        │  Deployment: sre-app (2–10 replicas)  │
                        │  Flask API   :5000                    │
                        │  /products  /orders  /health /metrics │
                        └──────────────┬───────────────────────┘
                                       │  /metrics
              ┌────────────────────────▼────────────────────────┐
              │              Prometheus  :9090                   │
              │  scrape_interval=10s                             │
              │  recording rules → SLI time-series              │
              │  alerting rules  → Alertmanager                  │
              └──────────┬──────────────────┬───────────────────┘
                         │                  │
          ┌──────────────▼──┐   ┌───────────▼──────────────────┐
          │  Alertmanager   │   │  Grafana  :3000               │
          │  :9093          │   │  SLI/SLO dashboard           │
          │  webhook alerts │   │  error budget gauge           │
          └─────────────────┘   └──────────────────────────────┘
```

## Components

### Application (`app/`)
- **Runtime**: Python 3.12 / Flask 3.0
- **Endpoints**: `GET /`, `GET /health`, `GET /ready`, `GET /products`, `GET /products/{id}`, `POST /orders`, `GET /metrics`
- **Observability**: exposes Prometheus metrics via `prometheus_client`
  - `http_requests_total` — counter, labelled by method / endpoint / status
  - `http_request_duration_seconds` — histogram with 10 buckets
  - `http_active_requests` — gauge

### Infrastructure as Code (`terraform/`)
- **Provider**: `kreuzwerker/docker ~> 3.0`
- **Backend**: local (`terraform.tfstate`)
- **Resources**: Docker network + containers for app, Prometheus, Alertmanager, Grafana
- Volumes mount config files read-only into each container

### CI/CD (`.github/workflows/ci-cd.yml`)
1. **test** — lint with flake8, unit tests with pytest
2. **build** — Docker Buildx with layer cache (GHA cache), push to GHCR with `sha-<commit>` and `latest` tags
3. **deploy** — substitute image tag in `k8s/deployment.yml`, apply manifests (requires `KUBE_CONFIG` secret)

### Kubernetes (`k8s/`)
- **Namespace**: `sre-demo`
- **Deployment**: 2 replicas, `RollingUpdate` with `maxUnavailable=0`
- **Service**: ClusterIP on port 80 → 5000
- **HPA**: scale 2–10 replicas, CPU target 70%, memory target 80%, scale-down stabilisation 5 min
- **Ingress**: nginx, host `sre-demo.local`

### Monitoring (`monitoring/`)
- **Prometheus**: scrapes app every 10 s, evaluates recording + alerting rules every 30 s, retains 15 days of data
- **Alertmanager**: groups alerts, suppresses warnings when critical fired, routes to webhook
- **Grafana**: auto-provisioned datasource (Prometheus) and dashboard (SLI/SLO)

### Load Testing (`load-testing/`)
- **Locust**: `ECommerceUser` (browse + order) and `SpikeUser` (traffic burst) scenarios
- **Apache Benchmark**: quick latency / throughput baseline for individual endpoints
