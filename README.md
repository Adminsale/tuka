# SRE Capstone Project - Production Readiness Review

## E-Commerce Platform Infrastructure

A production-ready microservice infrastructure demonstrating SRE practices including Infrastructure as Code (IaC), CI/CD, observability, and automation.

## Team Members

| Name | Role | Responsibility |
|------|------|----------------|
| Marat Turarbek | SRE Lead              | Architecture, Terraform, CI/CD   |
| Erik Abai      | Observability Engineer | Prometheus, Grafana, Alerting   |
| Marat Turarbek | Operations Engineer   | HPA, Load Testing, SLOs          |
| Erik Abai      | DevOps Engineer       | Docker, K8s, Automation          |

## Project Structure

```
.
├── .github/workflows/     # CI/CD pipeline (GitHub Actions)
├── terraform/             # Infrastructure as Code
│   ├── main.tf            # Main Terraform configuration
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values
│   └── terraform.tfvars.example
├── app/                   # Microservice application
│   ├── app.py             # Flask e-commerce API
│   ├── Dockerfile         # Docker image definition
│   └── requirements.txt   # Python dependencies
├── k8s/                   # Kubernetes manifests
│   ├── namespace.yml
│   ├── deployment.yml
│   ├── service.yml
│   ├── hpa.yml
│   └── ingress.yml
├── monitoring/            # Observability stack
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   ├── alert.rules.yml
│   │   └── alertmanager.yml
│   ├── grafana/
│   │   ├── dashboards/sli-dashboard.json
│   │   └── provisioning/
│   └── docker-compose.monitoring.yml
├── load-testing/          # Load testing tools
│   ├── locustfile.py
│   ├── Dockerfile
│   ├── run-load-test.sh
│   └── run-ab-test.sh
└── docs/                  # Documentation
    ├── architecture.md
    └── slo-definitions.md
```

## Quick Start

### Prerequisites
- Python 3.11+
- Docker & Docker Compose
- Terraform >= 1.5
- kubectl
- Minikube or Kubernetes cluster

### 1. Run the Microservice Locally

```bash
cd app
pip install -r requirements.txt
python app.py
```

Test: `curl http://localhost:5000/health`

### 2. Build and Run with Docker

```bash
docker build -t ecommerce-api ./app
docker run -p 5000:5000 ecommerce-api
```

### 3. Deploy to Kubernetes

```bash
# Apply manifests
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/
```

### 4. Provision with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### 5. Start Monitoring Stack

```bash
cd monitoring
docker-compose -f docker-compose.monitoring.yml up -d
```

Access:
- Grafana: http://localhost:3000 (admin/admin123)
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093

### 6. Run Load Tests

```bash
# With Locust (web UI)
cd load-testing
locust -f locustfile.py --host=http://localhost:5000

# With Locust (headless)
./run-load-test.sh http://localhost:5000

# With Apache Benchmark
./run-ab-test.sh http://localhost:5000
```

## CI/CD Pipeline

The GitHub Actions workflow (`ci-cd.yml`) automates:
1. **Test**: Python linting and unit tests
2. **Build & Push**: Docker image build and push to registry
3. **Deploy-Staging**: Automatic deploy on develop branch
4. **Deploy-Production**: Manual or main branch deploy

### Required GitHub Secrets
| Secret | Description |
|--------|-------------|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub password/token |
| `KUBE_CONFIG` | Base64-encoded kubeconfig |

## SLOs Summary

| SLI | Target | Window |
|-----|--------|--------|
| Availability | >= 99.5% | 30 days |
| P95 Latency | <= 500ms | 5 min |
| P99 Latency | <= 1s | 5 min |
| Error Rate | < 5% | 5 min |

## Alerts

Configured alerts in `monitoring/prometheus/alert.rules.yml`:
- **HighErrorRate** (critical): >5% errors in 5m
- **HighLatency** (warning): P95 > 500ms
- **CriticalLatency** (critical): P99 > 1s
- **InstanceDown** (critical): Pod unavailable
- **LowAvailability** (critical): <99% in 1h

## License

MIT

