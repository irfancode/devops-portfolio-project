# Cloud & DevOps Portfolio Project

> **Automated API Deployment Pipeline on AWS with GitLab CI/CD, Terraform, Docker & Kubernetes**

## Project Goal

This project demonstrates end-to-end Cloud & DevOps expertise by building, deploying, and monitoring a production-ready Flask REST API on AWS. It showcases hands-on skills in containerization, Infrastructure as Code, CI/CD automation, monitoring, security, and cost optimization — designed to attract customers and win technical interview rounds.

## Technologies & Tools Used

| Category | Technologies |
|----------|-------------|
| **Cloud Platform** | AWS (EC2, S3, RDS, IAM, VPC, ALB) |
| **Containers** | Docker, Kubernetes (Minikube/EKS) |
| **Infrastructure as Code** | Terraform, Ansible |
| **CI/CD** | GitLab CI/CD, Jenkins |
| **Scripting** | Python, Bash |
| **Monitoring** | Prometheus, Grafana, CloudWatch |
| **Database** | PostgreSQL (RDS) |
| **Version Control** | Git, GitHub/GitLab |

## Project Components

| Component | Description | Key Skills Demonstrated |
|-----------|-------------|------------------------|
| **Flask REST API** | CRUD API with health checks, metrics endpoint, and structured logging | Docker, API design, Python |
| **Docker Container** | Multi-stage Dockerfile, optimized image, health checks | Containerization, best practices |
| **Kubernetes** | Deployments, Services, HPA, ConfigMaps, Secrets | Orchestration, scaling |
| **Terraform IaC** | Modular VPC, EC2, S3, RDS, IAM with environments | Cloud provisioning, modules |
| **CI/CD Pipeline** | Build → Test → Security Scan → Deploy with GitLab CI/CD | Automation, testing, deployment |
| **Monitoring** | Prometheus metrics scraping, Grafana dashboards, alerting | Observability, SRE practices |
| **Automation Scripts** | Python (AWS SDK), Bash (system monitoring, log parsing) | Scripting, DevOps automation |
| **Security** | IAM least privilege, security groups, secrets management | Cloud security, hardening |
| **Cost Optimization** | Rightsizing, auto-scaling, lifecycle policies | FinOps, cloud economics |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                            AWS Cloud                                │
│                                                                     │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────┐    │
│  │   Route 53  │───▶│  ALB/NLB     │───▶│  EKS Cluster         │    │
│  │  (DNS)      │    │  (Load Bal.) │    │  ┌───────────────┐   │    │
│  └─────────────┘    └──────────────┘    │  │ Flask API Pods │   │    │
│                                         │  │ (Auto-scaled)  │   │    │
│  ┌─────────────┐                        │  └───────────────┘   │    │
│  │   RDS       │◀───────────────────────│         │             │    │
│  │ (PostgreSQL)│                        └─────────┼─────────────┘    │
│  └─────────────┘                                  │                  │
│                                                   │                  │
│  ┌─────────────┐                        ┌─────────▼─────────────┐    │
│  │    S3       │◀───────────────────────│  Prometheus + Grafana │    │
│  │ (Artifacts) │                        │  (Monitoring Stack)   │    │
│  └─────────────┘                        └───────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
         ▲
         │ Git Push
┌────────┴─────────┐    ┌──────────────────┐    ┌────────────────┐
│   GitLab/GitHub  │───▶│  GitLab CI/CD    │───▶│  Docker Hub    │
│   (Source Code)  │    │  (Pipeline)      │    │  (Registry)    │
└──────────────────┘    └──────────────────┘    └────────────────┘
                              │
                              ▼
                       ┌──────────────┐
                       │  Terraform   │
                       │  (IaC)       │
                       └──────────────┘
```

## Quick Start

### Prerequisites

- Docker Desktop installed
- kubectl configured (Minikube or EKS)
- Terraform >= 1.5
- AWS CLI configured with credentials
- Python 3.10+

### 1. Run Locally with Docker

```bash
cd api
docker build -t flask-api:latest .
docker run -p 5000:5000 flask-api:latest
```

### 2. Deploy to Kubernetes

```bash
kubectl apply -f kubernetes/base/
kubectl port-forward svc/flask-api-service 8080:80
```

### 3. Provision AWS Infrastructure with Terraform

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 4. Run CI/CD Pipeline

Push to the `main` branch to trigger the GitLab CI/CD pipeline:

```bash
git add .
git commit -m "feat: deploy API v1.0"
git push origin main
```

## Directory Structure

```
devops-portfolio-project/
├── api/                        # Flask REST API application
│   ├── app/                    # Application source code
│   │   ├── __init__.py
│   │   ├── routes.py           # API endpoints
│   │   ├── models.py           # Data models
│   │   ├── config.py           # Configuration
│   │   └── metrics.py          # Prometheus metrics
│   ├── tests/                  # Unit and integration tests
│   ├── Dockerfile              # Multi-stage container build
│   ├── requirements.txt        # Python dependencies
│   └── docker-compose.yml      # Local development stack
├── kubernetes/                 # Kubernetes manifests
│   ├── base/                   # Base K8s resources
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── hpa.yaml
│   │   └── ingress.yaml
│   └── overlays/               # Environment-specific configs
│       ├── dev/
│       ├── staging/
│       └── prod/
├── terraform/                  # Infrastructure as Code
│   ├── modules/                # Reusable Terraform modules
│   │   ├── vpc/
│   │   ├── ec2/
│   │   ├── s3/
│   │   ├── rds/
│   │   └── iam/
│   └── environments/           # Environment configurations
│       ├── dev/
│       ├── staging/
│       └── prod/
├── ci-cd/                      # CI/CD pipeline configurations
│   ├── .gitlab-ci.yml          # GitLab CI/CD pipeline
│   └── Jenkinsfile             # Jenkins pipeline
├── scripts/                    # Automation scripts
│   ├── monitoring/             # System monitoring scripts
│   ├── automation/             # AWS automation scripts
│   └── deployment/             # Deployment helper scripts
├── monitoring/                 # Observability stack
│   ├── prometheus/             # Prometheus configuration
│   └── grafana/                # Grafana dashboards
└── docs/                       # Documentation
    ├── architecture/           # Architecture diagrams
    └── interview-prep/         # Interview Q&A guide
```

## CI/CD Pipeline Stages

```
┌─────────┐    ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌─────────┐
│  Lint   │───▶│  Test   │───▶│  Build   │───▶│  Scan    │───▶│ Deploy  │
│  (Flake8│    │ (PyTest)│    │ (Docker) │    │(Trivy)   │    │ (AWS)   │
│  +Black)│    │         │    │          │    │          │    │         │
└─────────┘    └─────────┘    └──────────┘    └──────────┘    └─────────┘
```

## Monitoring & Observability

- **Prometheus**: Scrapes `/metrics` endpoint for custom application metrics
- **Grafana**: Pre-built dashboards for API performance, error rates, and infrastructure health
- **Alerting**: Configured alerts for high error rates, latency spikes, and resource utilization

## Security Best Practices Applied

- IAM roles with least privilege access
- Security groups with minimal open ports
- Secrets managed via Kubernetes Secrets / AWS Secrets Manager
- Container image vulnerability scanning with Trivy
- Network policies restricting pod-to-pod communication

## Cost Optimization

- Auto-scaling groups to match demand
- S3 lifecycle policies for artifact management
- Reserved instance recommendations
- Right-sized EC2 instances based on CloudWatch metrics
- Unused resource cleanup scripts

## Key Metrics & Achievements

| Metric | Value |
|--------|-------|
| Deployment Time | < 5 minutes (automated) |
| Test Coverage | 85%+ |
| API Response Time (p95) | < 200ms |
| Infrastructure Cost Savings | ~30% via right-sizing |
| Uptime (SLA Target) | 99.9% |

## Portfolio Links

- **GitHub Repository**: [Your Repo URL]
- **Demo Video**: [Optional - Loom/YouTube]
- **Blog Post / Documentation**: [Medium/DevOps Blog]
- **Live Demo**: [Optional - API Endpoint]

## Challenges & Solutions

| Challenge | Solution | Key Learning |
|-----------|----------|--------------|
| IAM permission errors during Terraform apply | Implemented least-privilege IAM policies with explicit resource ARNs | Importance of granular IAM permissions |
| Docker image too large (1.2GB) | Multi-stage build reduced to 180MB | Container optimization techniques |
| CI/CD pipeline flaky tests | Added test isolation and retry logic | Reliable automation requires idempotent tests |
| Kubernetes pod OOMKilled | Configured proper resource requests/limits | Resource management is critical in K8s |

## Interview Preparation

This project is designed to help you answer common Cloud & DevOps interview questions. See [docs/interview-prep/](docs/interview-prep/) for:

- Common interview questions with detailed answers
- System design scenarios
- Troubleshooting exercises
- Terraform and Kubernetes deep-dive questions

## License

MIT License - see [LICENSE](LICENSE) for details.

---

> **Built as a portfolio project to demonstrate Cloud & DevOps expertise for 2026 interviews.**
