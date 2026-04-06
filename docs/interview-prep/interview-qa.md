# Cloud & DevOps Interview Preparation Guide

## Table of Contents
1. [Cloud Fundamentals](#cloud-fundamentals)
2. [Docker & Containerization](#docker--containerization)
3. [Kubernetes](#kubernetes)
4. [Terraform & IaC](#terraform--iac)
5. [CI/CD](#cicd)
6. [Scripting & Automation](#scripting--automation)
7. [Monitoring & Observability](#monitoring--observability)
8. [Security](#security)
9. [System Design Scenarios](#system-design-scenarios)
10. [Troubleshooting Scenarios](#troubleshooting-scenarios)

---

## Cloud Fundamentals

### Q1: Explain the difference between IaaS, PaaS, and SaaS.

**Answer:**
- **IaaS (Infrastructure as a Service)**: Provides virtualized computing resources over the internet. You manage OS, middleware, runtime, data, and applications. Example: AWS EC2, Azure VMs.
- **PaaS (Platform as a Service)**: Provides a platform allowing customers to develop, run, and manage applications without dealing with infrastructure. Example: AWS Elastic Beanstalk, Google App Engine.
- **SaaS (Software as a Service)**: Complete software solution managed by a third party. Example: Gmail, Salesforce.

**Interview tip**: Use the "pizza analogy" - IaaS is like making pizza at home (you buy ingredients, oven), PaaS is like pizza delivery (you just eat), SaaS is like dining at a restaurant (everything handled).

### Q2: What is the Well-Architected Framework? Name its pillars.

**Answer:** The AWS Well-Architected Framework helps cloud architects build secure, high-performing, resilient, and efficient infrastructure. Six pillars:

1. **Operational Excellence** - Run and monitor systems, improve processes
2. **Security** - Protect information and systems
3. **Reliability** - Recover from failures, meet demand
4. **Performance Efficiency** - Use resources efficiently
5. **Cost Optimization** - Avoid unnecessary costs
6. **Sustainability** - Minimize environmental impact

### Q3: How do you choose between EC2, ECS, EKS, and Lambda?

**Answer:**
| Service | Best For | Trade-off |
|---------|----------|-----------|
| **EC2** | Full control, legacy apps | More management overhead |
| **ECS** | Docker containers, AWS-native | AWS lock-in |
| **EKS** | Kubernetes, multi-cloud | Complex, expensive |
| **Lambda** | Event-driven, serverless | Cold starts, 15-min limit |

---

## Docker & Containerization

### Q4: Explain Docker multi-stage builds and why they matter.

**Answer:** Multi-stage builds use multiple `FROM` statements in a single Dockerfile. Each stage can copy artifacts from previous stages. Benefits:

```dockerfile
FROM python:3.11 AS builder
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

FROM python:3.11-slim AS production
COPY --from=builder /install /usr/local
COPY . .
```

- **Smaller final image**: Build dependencies excluded from final image
- **Security**: No build tools in production image
- **Example**: Our Flask API image went from 1.2GB to 180MB

### Q5: What is the difference between CMD and ENTRYPOINT?

**Answer:**
- **ENTRYPOINT**: Configures the container to run as an executable. Cannot be overridden easily.
- **CMD**: Provides default arguments to ENTRYPOINT or command. Can be overridden.

```dockerfile
ENTRYPOINT ["gunicorn"]
CMD ["--bind", "0.0.0.0:5000", "app:create_app()"]
```

Running `docker run myimage --bind 0.0.0.0:8080` overrides CMD but keeps ENTRYPOINT.

### Q6: How do you optimize Docker images?

**Answer:**
1. Use slim/alpine base images (`python:3.11-slim` vs `python:3.11`)
2. Multi-stage builds
3. Combine RUN commands to reduce layers
4. Use `.dockerignore` to exclude unnecessary files
5. Order layers from least to most frequently changing
6. Clean up package manager cache in same RUN command

---

## Kubernetes

### Q7: Explain the difference between Deployment, StatefulSet, and DaemonSet.

**Answer:**
- **Deployment**: For stateless applications. Pods are interchangeable. Supports rolling updates. Use for web APIs.
- **StatefulSet**: For stateful applications. Pods have stable identities and persistent storage. Use for databases.
- **DaemonSet**: Ensures one pod runs on every node. Use for log collectors, monitoring agents.

### Q8: How does Kubernetes handle pod failures?

**Answer:**
1. **Liveness Probe**: Detects if pod is running. If fails, kubelet kills and restarts the pod.
2. **Readiness Probe**: Detects if pod is ready to serve traffic. If fails, pod is removed from Service endpoints.
3. **Restart Policy**: Default is `Always` - kubelet restarts failed containers.
4. **ReplicaSet**: Ensures desired number of replicas are running.
5. **PodDisruptionBudget**: Limits voluntary disruptions during maintenance.

### Q9: Explain Horizontal Pod Autoscaler (HPA).

**Answer:** HPA automatically scales the number of pods based on observed metrics:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: flask-api
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

**Key concepts**:
- Uses metrics-server for CPU/memory metrics
- Can scale on custom metrics (Prometheus adapter)
- Has stabilization windows to prevent flapping

---

## Terraform & IaC

### Q10: What is Terraform state and why is it important?

**Answer:** Terraform state (`terraform.tfstate`) is a JSON file that maps real-world resources to your configuration. It:

1. **Tracks metadata**: Resource IDs, attributes, dependencies
2. **Improves performance**: Caches attributes instead of querying APIs
3. **Enables planning**: Compares desired vs actual state
4. **Supports collaboration**: Remote state with locking (S3 + DynamoDB)

**Best practices**:
- Store remotely (S3, GCS, Terraform Cloud)
- Enable state locking (DynamoDB)
- Enable encryption at rest
- Never commit state to version control
- Use state workspaces for environments

### Q11: Explain Terraform modules and their benefits.

**Answer:** Modules are containers for multiple resources used together. Our project structure:

```
modules/
├── vpc/      # Network infrastructure
├── ec2/      # Compute resources
├── s3/       # Storage
├── rds/      # Database
└── iam/      # Access control
```

**Benefits**:
- **Reusability**: Use same VPC module across dev/staging/prod
- **Consistency**: Standardized infrastructure patterns
- **Maintainability**: Changes in one place propagate everywhere
- **Testing**: Modules can be tested independently

### Q12: How do you handle secrets in Terraform?

**Answer:**
1. **Variables with `sensitive = true`**: Masks output but doesn't encrypt state
2. **AWS Secrets Manager / SSM Parameter Store**: Reference secrets dynamically
3. **Environment variables**: `TF_VAR_db_password`
4. **Vault integration**: Dynamic secrets with HashiCorp Vault
5. **Never hardcode**: Always use variables or data sources

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

data "aws_ssm_parameter" "db_password" {
  name = "/${var.environment}/db/password"
}
```

---

## CI/CD

### Q13: Explain blue-green vs rolling deployments.

**Answer:**

**Rolling Deployment**:
- Gradually replaces old instances with new ones
- Zero downtime, but mixed versions during deployment
- Lower resource cost (no duplicate infrastructure)
- Slower rollback (need to redeploy old version)

**Blue-Green Deployment**:
- Two identical environments (blue = current, green = new)
- Instant switch via load balancer
- Instant rollback (switch back to blue)
- Higher cost (double infrastructure)

**When to use which**:
- Rolling: Cost-sensitive, non-critical services
- Blue-Green: Zero-downtime requirement, easy rollback needed

### Q14: How do you implement a CI/CD pipeline for a microservice?

**Answer:** Using our GitLab CI/CD pipeline as example:

```
Push → Lint → Test → Build → Security Scan → Deploy
```

**Key principles**:
1. **Fast feedback**: Lint and test run first (fail fast)
2. **Immutable artifacts**: Build once, deploy everywhere (same Docker image)
3. **Environment promotion**: Same artifact moves dev → staging → prod
4. **Manual gates**: Approval required for staging/production
5. **Rollback strategy**: Previous version always available

### Q15: What are pipeline best practices?

**Answer:**
- **Idempotent pipelines**: Can run multiple times with same result
- **Parallel stages**: Run independent stages concurrently
- **Artifact caching**: Cache dependencies between runs
- **Branch protection**: Require passing pipelines before merge
- **Secrets management**: Use CI/CD variables, never hardcode
- **Pipeline as code**: Version control your pipeline configuration

---

## Scripting & Automation

### Q16: Write a Bash script to find and kill processes using more than 80% CPU.

**Answer:**
```bash
#!/bin/bash
THRESHOLD=80
ps aux | awk -v threshold="$THRESHOLD" '$3 > threshold {print $2, $3, $11}' | \
while read pid cpu cmd; do
    echo "Killing PID $pid ($cmd) using ${cpu}% CPU"
    kill -15 "$pid"
done
```

**Interview points to mention**:
- Use `kill -15` (SIGTERM) before `kill -9` (SIGKILL)
- Add logging and alerting
- Consider using `cgroups` for CPU limits instead

### Q17: How would you automate log rotation?

**Answer:**
```bash
#!/bin/bash
LOG_DIR="/var/log/app"
MAX_SIZE="100M"
RETENTION=7

find "$LOG_DIR" -name "*.log" -size +$MAX_SIZE | while read logfile; do
    timestamp=$(date +%Y%m%d_%H%M%S)
    mv "$logfile" "${logfile}.${timestamp}"
    gzip "${logfile}.${timestamp}"
    touch "$logfile"
    chmod 644 "$logfile"
done

find "$LOG_DIR" -name "*.gz" -mtime +$RETENTION -delete
```

---

## Monitoring & Observability

### Q18: What are the Four Golden Signals of monitoring?

**Answer:** (Google SRE book)
1. **Latency**: Time to serve a request (distinguish between successful and failed)
2. **Traffic**: Demand on your system (requests/sec, concurrent users)
3. **Errors**: Rate of failed requests (explicit, implicit, policy violations)
4. **Saturation**: How "full" your service is (CPU, memory, disk, connection pool)

**In our project**: All four signals are tracked via Prometheus metrics and Grafana dashboards.

### Q19: Difference between monitoring and observability?

**Answer:**
- **Monitoring**: Checking predefined metrics against thresholds. "Is the system healthy?"
- **Observability**: Ability to understand system state from external outputs. "Why is the system unhealthy?"

**Three pillars of observability**:
1. **Metrics**: Aggregated numeric data (Prometheus)
2. **Logs**: Discrete events (structured logging)
3. **Traces**: Request flow across services (Jaeger)

### Q20: How do you set up alerting without alert fatigue?

**Answer:**
1. **Alert on symptoms, not causes**: "High error rate" vs "CPU high"
2. **Use SLOs/SLIs**: Alert when error budget is burning too fast
3. **Multi-window multi-burn rate**: Different thresholds for different time windows
4. **Actionable alerts**: Every alert should require human action
5. **Escalation policies**: Route to right team, auto-escalate if unacknowledged

---

## Security

### Q21: Explain the principle of least privilege in AWS IAM.

**Answer:** Grant only the permissions needed to perform a task, nothing more.

**In our project**:
```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::my-bucket/*"
}
```

**Best practices**:
- Use specific resource ARNs, not `*`
- Use conditions (IP, time, MFA)
- Regular permission audits
- Use IAM Access Analyzer
- Prefer roles over access keys

### Q22: How do you secure a containerized application?

**Answer:**
1. **Image security**: Scan for vulnerabilities (Trivy), use minimal base images
2. **Runtime security**: Run as non-root, read-only filesystem, drop capabilities
3. **Network security**: Network policies, service mesh, TLS
4. **Secret management**: Kubernetes Secrets (encrypted), external vault
5. **Supply chain**: Sign images, verify provenance (cosign, Notary)

---

## System Design Scenarios

### Q23: Design a scalable web application on AWS.

**Answer:** (Reference our architecture)

```
Users → Route 53 → CloudFront → ALB → EKS (Auto-scaled)
                                        ↓
                                    RDS (Multi-AZ)
                                        ↓
                                    ElastiCache (Redis)
                                        ↓
                                    S3 (static assets)
```

**Key decisions**:
- **ALB** for Layer 7 routing, health checks
- **EKS** for container orchestration, auto-scaling
- **RDS Multi-AZ** for high availability
- **ElastiCache** for session caching, reduce DB load
- **S3 + CloudFront** for static content delivery
- **Auto-scaling** based on CPU and request rate

### Q24: How would you handle a database migration with zero downtime?

**Answer:**
1. **Backward-compatible changes first**: Add columns, never remove
2. **Dual-write**: Write to old and new schema simultaneously
3. **Backfill**: Migrate existing data in background
4. **Switch reads**: Point reads to new schema
5. **Remove old**: Drop old columns after verification
6. **Use tools**: AWS DMS, Flyway, or Liquibase

---

## Troubleshooting Scenarios

### Q25: A deployment failed. How do you troubleshoot?

**Answer:** Systematic approach:

1. **Check CI/CD logs**: Identify which stage failed
2. **Check application logs**: `kubectl logs <pod> --previous`
3. **Check pod status**: `kubectl get pods`, `kubectl describe pod <pod>`
4. **Check events**: `kubectl get events --sort-by='.lastTimestamp'`
5. **Check resource limits**: OOMKilled, CPU throttling
6. **Check networking**: DNS, service discovery, network policies
7. **Check dependencies**: Database connectivity, external APIs
8. **Rollback if needed**: `kubectl rollout undo deployment/<name>`

### Q26: Your application is slow. How do you diagnose?

**Answer:**
1. **Check metrics**: Grafana dashboards for latency, error rate, throughput
2. **Check resources**: CPU, memory, disk I/O, network
3. **Check database**: Slow query log, connection pool, indexes
4. **Check application**: Profiling, APM traces, garbage collection
5. **Check external dependencies**: API response times, rate limits
6. **Check infrastructure**: Network latency, load balancer health
7. **Use tools**: `top`, `htop`, `iostat`, `netstat`, `strace`

---

## Behavioral Questions

### Q27: Tell me about a time you improved a CI/CD pipeline.

**Answer framework (STAR)**:
- **Situation**: Pipeline took 45 minutes, developers avoided running tests
- **Task**: Reduce pipeline time while maintaining quality
- **Action**: Parallelized stages, added caching, removed redundant steps, implemented incremental builds
- **Result**: Reduced to 12 minutes, test coverage increased from 60% to 85%

### Q28: How do you handle disagreements between Dev and Ops teams?

**Answer:**
- Focus on shared goals (reliable software delivery)
- Use data and metrics, not opinions
- Implement blameless post-mortems
- Create shared ownership through SRE practices
- Establish clear SLAs and error budgets
- Regular cross-team communication and knowledge sharing
