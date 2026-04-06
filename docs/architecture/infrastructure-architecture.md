# Infrastructure Architecture

## AWS Resource Layout

```
us-east-1
├── VPC (10.0.0.0/16)
│   ├── Public Subnets (3 AZs)
│   │   ├── 10.0.1.0/24 (us-east-1a)
│   │   ├── 10.0.2.0/24 (us-east-1b)
│   │   └── 10.0.3.0/24 (us-east-1c)
│   ├── Private Subnets (3 AZs)
│   │   ├── 10.0.10.0/24 (us-east-1a)
│   │   ├── 10.0.20.0/24 (us-east-1b)
│   │   └── 10.0.30.0/24 (us-east-1c)
│   ├── Internet Gateway
│   ├── NAT Gateway
│   └── Route Tables (Public + Private)
│
├── Compute
│   ├── Auto Scaling Group (2-6 instances)
│   │   ├── Launch Template (Amazon Linux 2)
│   │   ├── CPU-based Scaling Policy
│   │   └── CloudWatch Alarm (CPU > 70%)
│   └── Application Load Balancer
│       ├── Target Group (port 5000)
│       └── Health Check (/health)
│
├── Database
│   └── RDS PostgreSQL
│       ├── Multi-AZ (staging/prod)
│       ├── Automated Backups (7-30 days)
│       ├── Encryption at Rest
│       └── Performance Insights
│
├── Storage
│   └── S3 Buckets
│       ├── Artifacts Bucket
│       │   ├── Versioning Enabled
│       │   ├── SSE-KMS Encryption
│       │   ├── Lifecycle Policies
│       │   └── Public Access Blocked
│       └── Terraform State Bucket
│           ├── Versioning
│           └── DynamoDB Lock Table
│
├── Security
│   ├── IAM Roles & Policies
│   │   ├── EC2 Instance Role
│   │   ├── S3 Access Policy (least privilege)
│   │   ├── CloudWatch Logs Policy
│   │   └── SSM Parameter Access
│   └── Security Groups
│       ├── ALB SG (80, 443)
│       ├── EC2 SG (5000 from ALB)
│       └── RDS SG (5432 from EC2 SG)
│
└── Monitoring
    ├── CloudWatch Metrics
    ├── CloudWatch Logs
    ├── CloudWatch Alarms
    └── Cost Explorer
```

## Terraform Module Dependency Graph

```
┌─────────────┐
│   Provider   │
│   (AWS)      │
└──────┬───────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│    VPC       │────▶│    IAM       │
│   Module     │     │   Module     │
└──────┬───────┘     └──────┬───────┘
       │                    │
       ▼                    ▼
┌─────────────┐     ┌─────────────┐
│    EC2       │     │    S3        │
│   Module     │     │   Module     │
└─────────────┘     └─────────────┘
       │
       ▼
┌─────────────┐
│    RDS       │
│   Module     │
└─────────────┘
```

## Security Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Internet                               │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│              WAF + Shield (Optional)                      │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│              Application Load Balancer                    │
│         Security Group: 80, 443 (0.0.0.0/0)              │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│              EC2 Auto Scaling Group                       │
│    Security Group: 5000 (from ALB SG only)               │
│    IAM Role: Least privilege, SSM access                 │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│              RDS PostgreSQL (Private Subnet)              │
│    Security Group: 5432 (from EC2 SG only)               │
│    Encryption: At rest + in transit                      │
└──────────────────────────────────────────────────────────┘
```

## Cost Optimization Strategies

| Strategy | Implementation | Estimated Savings |
|----------|---------------|-------------------|
| **Right-sizing** | Monitor CPU/memory, adjust instance types | 20-30% |
| **Auto-scaling** | Scale based on demand, not peak capacity | 30-40% |
| **Reserved Instances** | Commit to 1-year RI for baseline load | 30-40% |
| **S3 Lifecycle** | Auto-transition to IA/Glacier | 50-70% on storage |
| **Spot Instances** | Use for non-critical workloads | 60-90% |
| **EBS Optimization** | Use gp3 instead of gp2 | 20% |
| **Cleanup Scripts** | Automated removal of unused resources | 10-15% |
