# CI/CD Pipeline Architecture

## Pipeline Flow

```
Developer
    │
    ▼
┌─────────────┐
│  Git Push   │
│ (main/dev)  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────────┐
│              GitLab CI/CD Pipeline               │
│                                                  │
│  ┌─────────┐    ┌─────────┐    ┌──────────┐    │
│  │  Lint   │───▶│  Test   │───▶│  Build   │    │
│  │         │    │         │    │ (Docker) │    │
│  │ flake8  │    │ pytest  │    │  image   │    │
│  │ black   │    │ 85%+cov │    │  push    │    │
│  └─────────┘    └─────────┘    └─────┬────┘    │
│                                       │         │
│                              ┌────────▼────┐    │
│                              │  Security   │    │
│                              │   Scan      │    │
│                              │  (Trivy)    │    │
│                              └──────┬──────┘    │
│                                     │           │
│                    ┌────────────────┼────────┐  │
│                    ▼                ▼        ▼  │
│              ┌─────────┐   ┌─────────┐ ┌────────┐│
│              │   Dev   │   │ Staging │ │  Prod  ││
│              │ (auto)  │   │ (manual)│ │(manual)││
│              └─────────┘   └─────────┘ └────────┘│
└─────────────────────────────────────────────────┘
       │                │              │
       ▼                ▼              ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Dev Env    │  │ Staging Env │  │  Prod Env   │
│  1 replica  │  │ 2 replicas  │  │ 3+ replicas │
│  t3.micro   │  │ t3.small    │  │ t3.medium   │
│  Single AZ  │  │ Multi-AZ    │  │ Multi-AZ    │
└─────────────┘  └─────────────┘  └─────────────┘
```

## Stage Details

### 1. Lint Stage
- **Tools**: Flake8, Black, isort
- **Purpose**: Enforce code quality and formatting standards
- **Trigger**: Changes to Python files

### 2. Test Stage
- **Tools**: pytest, pytest-cov
- **Purpose**: Run unit tests with coverage reporting
- **Gate**: Minimum 85% coverage required
- **Artifact**: Coverage report (HTML + Cobertura XML)

### 3. Build Stage
- **Tools**: Docker
- **Purpose**: Build multi-stage Docker image
- **Output**: Push to container registry with commit SHA tag

### 4. Security Scan Stage
- **Tools**: Trivy (container), Safety (dependencies)
- **Purpose**: Detect vulnerabilities in images and dependencies
- **Gate**: Block on HIGH/CRITICAL vulnerabilities

### 5. Deploy Stages
- **Dev**: Automatic on develop branch
- **Staging**: Manual approval on main branch
- **Production**: Manual approval on version tags (vX.Y.Z)

## Environment Strategy

| Aspect | Dev | Staging | Production |
|--------|-----|---------|------------|
| **Trigger** | Auto (develop) | Manual (main) | Manual (tag) |
| **Replicas** | 1 | 2 | 3+ |
| **Instance** | t3.micro | t3.small | t3.medium |
| **Multi-AZ** | No | Yes | Yes |
| **RDS** | Single-AZ | Multi-AZ | Multi-AZ + Read Replica |
| **Backups** | 7 days | 14 days | 30 days |
| **Monitoring** | Basic | Full | Full + Alerting |
