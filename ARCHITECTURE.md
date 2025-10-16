# AWS ECS Infrastructure Architecture

This document describes the architecture of the demo-web-claude-devops application deployed on AWS ECS with Fargate.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Network Architecture](#network-architecture)
3. [Compute Architecture](#compute-architecture)
4. [Security Architecture](#security-architecture)
5. [Monitoring and Logging](#monitoring-and-logging)
6. [High Availability and Scaling](#high-availability-and-scaling)
7. [Cost Optimization](#cost-optimization)
8. [Disaster Recovery](#disaster-recovery)

## Architecture Overview

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Internet (Users)                           │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 │ HTTPS/HTTP
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Application Load Balancer                        │
│                        (Public Subnets)                              │
│                    us-east-1a    us-east-1b                          │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 │ Target Group
                                 │ Health Checks
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         ECS Service (Fargate)                        │
│                         (Private Subnets)                            │
│                                                                       │
│    ┌──────────────┐              ┌──────────────┐                   │
│    │  ECS Task 1  │              │  ECS Task 2  │                   │
│    │  (Container) │              │  (Container) │                   │
│    │  us-east-1a  │              │  us-east-1b  │                   │
│    └──────────────┘              └──────────────┘                   │
│                                                                       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 │ NAT Gateway
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                            Internet                                  │
│                   (ECR, AWS APIs, Updates)                           │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Overview

| Component | Purpose | Type |
|-----------|---------|------|
| VPC | Network isolation | AWS VPC |
| Public Subnets | ALB, NAT Gateway | Multi-AZ |
| Private Subnets | ECS Tasks | Multi-AZ |
| ALB | Load balancing, SSL termination | Application Load Balancer |
| ECS Cluster | Container orchestration | Fargate |
| ECS Service | Task management, auto-scaling | ECS Service |
| ECR | Docker image registry | Elastic Container Registry |
| CloudWatch | Logging, monitoring, metrics | CloudWatch Logs & Metrics |
| IAM | Access control | IAM Roles & Policies |
| Security Groups | Network access control | VPC Security Groups |

## Network Architecture

### VPC Design

```
VPC: 10.0.0.0/16 (Development)
│
├── Public Subnets (Internet-facing)
│   ├── us-east-1a: 10.0.1.0/24
│   │   ├── Application Load Balancer (Primary)
│   │   └── NAT Gateway 1
│   │
│   └── us-east-1b: 10.0.2.0/24
│       ├── Application Load Balancer (Secondary)
│       └── NAT Gateway 2
│
└── Private Subnets (Internal only)
    ├── us-east-1a: 10.0.11.0/24
    │   └── ECS Tasks (Zone A)
    │
    └── us-east-1b: 10.0.12.0/24
        └── ECS Tasks (Zone B)
```

### Network Flow

1. **Inbound Traffic (User → Application)**
   ```
   User
     ↓ (HTTP/HTTPS)
   Internet Gateway
     ↓
   Application Load Balancer (Public Subnet)
     ↓ (HTTP on port 3000)
   ECS Tasks (Private Subnet)
   ```

2. **Outbound Traffic (Application → Internet)**
   ```
   ECS Tasks (Private Subnet)
     ↓
   NAT Gateway (Public Subnet)
     ↓
   Internet Gateway
     ↓
   Internet (ECR, AWS APIs, npm registry, etc.)
   ```

3. **AWS Service Communication**
   ```
   ECS Tasks
     ↓ (via NAT Gateway)
   AWS Services (ECR, CloudWatch, Secrets Manager)
   ```

### Routing

**Public Subnet Route Table:**
```
Destination       Target
10.0.0.0/16      local (VPC)
0.0.0.0/0        igw-xxxxx (Internet Gateway)
```

**Private Subnet Route Tables (per AZ):**
```
Destination       Target
10.0.0.0/16      local (VPC)
0.0.0.0/0        nat-xxxxx (NAT Gateway in same AZ)
```

### IP Address Allocation

- **VPC CIDR**: 10.0.0.0/16 (65,536 addresses)
- **Public Subnets**: /24 each (254 usable IPs per AZ)
- **Private Subnets**: /24 each (254 usable IPs per AZ)

Each ECS task gets a private IP from the private subnet.

## Compute Architecture

### ECS Cluster Configuration

```yaml
Cluster: demo-web-app-dev-cluster
├── Launch Type: FARGATE
├── Container Insights: ENABLED
└── Services:
    └── demo-web-app-dev-service
        ├── Task Definition: demo-web-app-dev:X
        ├── Desired Count: 2 (dev), 3 (prod)
        ├── Launch Type: FARGATE
        ├── Platform Version: LATEST
        ├── Networking:
        │   ├── VPC: demo-web-app-dev-vpc
        │   ├── Subnets: Private subnets (multi-AZ)
        │   └── Security Group: ecs-tasks-sg
        ├── Load Balancing:
        │   ├── Type: Application Load Balancer
        │   ├── Target Group: demo-web-app-dev-tg
        │   └── Health Check: / (port 3000)
        └── Auto Scaling:
            ├── Min: 1 (dev), 2 (prod)
            ├── Max: 4 (dev), 10 (prod)
            ├── Target CPU: 70%
            ├── Target Memory: 80%
            └── Target Requests: 1000 per target
```

### Task Definition

```json
{
  "family": "demo-web-app-dev",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::xxx:role/ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::xxx:role/ecs-task-role",
  "containerDefinitions": [
    {
      "name": "demo-web-app-dev-container",
      "image": "xxx.dkr.ecr.us-east-1.amazonaws.com/demo-web-app-dev:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "NODE_ENV", "value": "dev"},
        {"name": "PORT", "value": "3000"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/demo-web-app-dev",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "wget --spider http://localhost:3000/ || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

### Resource Allocation

**Development:**
- CPU: 256 units (0.25 vCPU)
- Memory: 512 MB
- Tasks: 1-2

**Staging:**
- CPU: 512 units (0.5 vCPU)
- Memory: 1024 MB (1 GB)
- Tasks: 2-4

**Production:**
- CPU: 1024 units (1 vCPU)
- Memory: 2048 MB (2 GB)
- Tasks: 3-10

## Security Architecture

### Defense in Depth Strategy

```
Layer 1: Network Security
  - VPC isolation
  - Private subnets for compute
  - Security groups (stateful firewall)
  - NACLs (optional, stateless firewall)

Layer 2: Access Control
  - IAM roles (no credentials in code)
  - Least privilege principle
  - Separate execution and task roles

Layer 3: Data Security
  - Encryption at rest (ECR images)
  - Encryption in transit (TLS for AWS APIs)
  - VPC Flow Logs

Layer 4: Application Security
  - Container image scanning
  - Security updates
  - Read-only root filesystem (optional)

Layer 5: Monitoring
  - CloudWatch Logs
  - VPC Flow Logs
  - Container Insights
  - AWS CloudTrail
```

### Security Groups

**ALB Security Group (alb-sg):**
```
Ingress:
  - Port 80 (HTTP) from 0.0.0.0/0
  - Port 443 (HTTPS) from 0.0.0.0/0 [when enabled]

Egress:
  - All traffic to 0.0.0.0/0
```

**ECS Tasks Security Group (ecs-sg):**
```
Ingress:
  - Port 3000 from alb-sg only

Egress:
  - All traffic to 0.0.0.0/0 (for AWS APIs, package downloads)
```

### IAM Roles and Policies

**Task Execution Role** (used by ECS to set up the task):
- Pull images from ECR
- Push logs to CloudWatch
- Get secrets from Secrets Manager (if configured)

**Task Role** (used by application code):
- CloudWatch Logs write access
- Additional AWS service access as needed

### Data Flow Security

```
User Request
  ↓ [TLS when HTTPS enabled]
ALB (Public Subnet)
  ↓ [HTTP, Security Group controlled]
ECS Task (Private Subnet)
  ↓ [TLS to AWS services via NAT]
AWS Services (ECR, CloudWatch, etc.)
```

### Secrets Management

Sensitive data should never be hardcoded:

1. **Environment Variables**: For non-sensitive config
2. **AWS Secrets Manager**: For sensitive data (DB passwords, API keys)
3. **AWS Systems Manager Parameter Store**: For application config

Example task definition with secrets:
```json
"secrets": [
  {
    "name": "DB_PASSWORD",
    "valueFrom": "arn:aws:secretsmanager:region:account:secret:db-password"
  }
]
```

## Monitoring and Logging

### CloudWatch Architecture

```
ECS Tasks
  ↓ (Container logs)
CloudWatch Logs
  ├── Log Group: /ecs/demo-web-app-dev
  │   ├── Log Stream: ecs/container-name/task-id-1
  │   └── Log Stream: ecs/container-name/task-id-2
  │
  └── Retention: 30 days

ECS Cluster
  ↓ (Metrics)
CloudWatch Metrics
  ├── Container Insights
  │   ├── CPU Utilization
  │   ├── Memory Utilization
  │   └── Network Metrics
  │
  └── Custom Metrics
      └── Application-specific metrics

VPC
  ↓ (Network traffic)
VPC Flow Logs → CloudWatch Logs
  └── Log Group: /aws/vpc/demo-web-app-dev
```

### Key Metrics to Monitor

**ECS Service Metrics:**
- CPUUtilization (target: < 70%)
- MemoryUtilization (target: < 80%)
- RunningTaskCount
- DesiredTaskCount
- HealthyHostCount

**ALB Metrics:**
- TargetResponseTime
- RequestCount
- HTTPCode_Target_2XX_Count
- HTTPCode_Target_4XX_Count
- HTTPCode_Target_5XX_Count
- UnHealthyHostCount

**Custom Application Metrics:**
- Request rate
- Error rate
- Response time percentiles (p50, p95, p99)

### Alerting Strategy

Recommended CloudWatch Alarms:

1. **ECS Task Health**: Alert when < desired count
2. **High CPU**: Alert when > 80% for 5 minutes
3. **High Memory**: Alert when > 90% for 5 minutes
4. **ALB 5xx Errors**: Alert when > 10 in 5 minutes
5. **Unhealthy Targets**: Alert when any target is unhealthy

## High Availability and Scaling

### Multi-AZ Deployment

```
Availability Zone 1 (us-east-1a)
├── Public Subnet
│   ├── ALB (Primary)
│   └── NAT Gateway 1
└── Private Subnet
    └── ECS Tasks (50% of traffic)

Availability Zone 2 (us-east-1b)
├── Public Subnet
│   ├── ALB (Secondary)
│   └── NAT Gateway 2
└── Private Subnet
    └── ECS Tasks (50% of traffic)

[Production: +AZ3 for 3-zone HA]
```

### Auto Scaling Policies

**1. CPU-Based Scaling:**
```yaml
Metric: ECSServiceAverageCPUUtilization
Target: 70%
Scale Out: Add 1 task when CPU > 70% for 60 seconds
Scale In: Remove 1 task when CPU < 70% for 300 seconds
```

**2. Memory-Based Scaling:**
```yaml
Metric: ECSServiceAverageMemoryUtilization
Target: 80%
Scale Out: Add 1 task when Memory > 80% for 60 seconds
Scale In: Remove 1 task when Memory < 80% for 300 seconds
```

**3. Request Count Scaling:**
```yaml
Metric: ALBRequestCountPerTarget
Target: 1000 requests per target
Scale Out: Add 1 task when requests > 1000 for 60 seconds
Scale In: Remove 1 task when requests < 1000 for 300 seconds
```

### Deployment Strategy

**Rolling Update:**
- Minimum healthy: 100%
- Maximum percent: 200%
- Process: Deploy new tasks → Health check → Drain old tasks

**Circuit Breaker:**
- Enabled for automatic rollback
- Triggers on repeated task failures
- Rolls back to previous task definition

### Failure Scenarios and Recovery

**Scenario 1: Single Task Failure**
- ECS detects unhealthy task (health check fails)
- ECS automatically replaces failed task
- New task joins ALB target group
- Recovery time: ~2 minutes

**Scenario 2: AZ Failure**
- Tasks in failed AZ become unreachable
- ALB removes unhealthy targets
- Traffic routes to remaining AZ
- Auto-scaling may add tasks in healthy AZ
- Recovery time: ~1 minute (automatic)

**Scenario 3: Deployment Failure**
- Circuit breaker detects repeated failures
- Deployment paused
- Automatic rollback to previous version
- Recovery time: ~3 minutes

## Cost Optimization

### Monthly Cost Breakdown (Development)

```
Component              Cost Calculation                      Monthly Cost
---------------------------------------------------------------------------
NAT Gateway (×2)       $0.045/hour × 2 × 730 hours          $65.70
NAT Data Processing    $0.045/GB × ~20GB                    $0.90
ALB                    $0.0225/hour × 730 hours             $16.43
ALB Data Processing    $0.008/LCU-hour × 730 × ~2 LCUs      $11.68
Fargate vCPU (0.25)    $0.04048/hour × 1 task × 730 hours   $29.55
Fargate Memory (0.5GB) $0.004445/GB-hour × 0.5 × 730        $1.62
Data Transfer Out      $0.09/GB × ~10GB                     $0.90
CloudWatch Logs        $0.50/GB × ~2GB                      $1.00
VPC Flow Logs          $0.50/GB × ~1GB                      $0.50
ECR Storage            $0.10/GB × ~0.5GB                    $0.05
---------------------------------------------------------------------------
Total                                                        ~$128/month
```

### Cost Optimization Strategies

1. **NAT Gateway Optimization**
   - Use single NAT Gateway in dev (saves ~$33/month)
   - Use VPC endpoints for AWS services (reduces data transfer)
   - Current: 2 NAT Gateways for HA

2. **Task Right-Sizing**
   - Monitor actual CPU/memory usage
   - Reduce allocated resources if under-utilized
   - Dev: 256 CPU / 512 MB (minimum viable)

3. **Auto-Scaling Tuning**
   - Scale to zero in dev during off-hours (saves ~$30/month)
   - Use scheduled scaling for predictable traffic patterns

4. **Log Retention**
   - Reduce retention period (30 days → 7 days for dev)
   - Use log filtering to reduce volume

5. **ECR Lifecycle Policies**
   - Automatically delete old images
   - Keep only last 10 tagged versions
   - Delete untagged images after 7 days

### Cost Monitoring

Set up AWS Budgets:
- Budget: $150/month for dev environment
- Alert at 80% ($120)
- Alert at 100% ($150)

Use Cost Explorer tags:
```yaml
Environment: dev
Project: demo-web-app
ManagedBy: terraform
```

## Disaster Recovery

### Backup Strategy

**Infrastructure (Terraform State):**
- Stored in S3 with versioning
- Backed up automatically
- Can recreate infrastructure from code

**Application Images:**
- Stored in ECR with lifecycle policies
- Keep last 10 versions
- Can roll back to any previous version

**Configuration:**
- Stored in Git (version controlled)
- Environment variables in Terraform
- Secrets in AWS Secrets Manager

### Recovery Procedures

**1. Complete Region Failure:**
```bash
# Deploy to different region
cd terraform
terraform apply -var-file="environments/prod/prod.tfvars" \
  -var="aws_region=us-west-2"

# Update DNS to point to new region
```
Recovery Time: 10-15 minutes

**2. Infrastructure Deletion:**
```bash
# Restore from Terraform state
cd terraform
terraform init
terraform apply -var-file="environments/prod/prod.tfvars"
```
Recovery Time: 5-10 minutes

**3. Bad Deployment:**
```bash
# Automatic rollback via circuit breaker (enabled)
# Or manual rollback:
aws ecs update-service --cluster <cluster> --service <service> \
  --task-definition <previous-version>
```
Recovery Time: 2-3 minutes

### Business Continuity

**RTO (Recovery Time Objective):** 15 minutes
- Time to restore service after disaster

**RPO (Recovery Point Objective):** 0 minutes
- No data loss (stateless application)

**Multi-Region Strategy (Future Enhancement):**
1. Deploy to multiple regions
2. Use Route53 for DNS failover
3. Share container images via ECR replication
4. Estimated RTO: < 5 minutes (automatic failover)

## Future Enhancements

Potential architectural improvements:

1. **HTTPS/SSL**
   - Add ACM certificate
   - Enable HTTPS listener on ALB
   - Redirect HTTP to HTTPS

2. **Custom Domain**
   - Route53 hosted zone
   - A record pointing to ALB
   - SSL certificate for domain

3. **CDN (CloudFront)**
   - Cache static assets
   - Reduce load on ALB
   - Improve global performance

4. **WAF (Web Application Firewall)**
   - SQL injection protection
   - XSS protection
   - Rate limiting
   - Geographic restrictions

5. **Database Layer**
   - RDS for persistent data
   - ElastiCache for caching
   - Private subnets for databases

6. **CI/CD Pipeline**
   - GitHub Actions / GitLab CI
   - Automated testing
   - Automated deployments
   - Blue/green deployments

7. **Enhanced Monitoring**
   - X-Ray for distributed tracing
   - Prometheus + Grafana
   - PagerDuty integration

8. **Security Enhancements**
   - GuardDuty for threat detection
   - Security Hub for compliance
   - AWS Config for configuration tracking
   - VPC Flow Logs analysis

## Architecture Principles

This architecture follows AWS Well-Architected Framework:

1. **Operational Excellence**
   - Infrastructure as Code (Terraform)
   - Automated deployments
   - Comprehensive logging and monitoring

2. **Security**
   - Defense in depth
   - Least privilege access
   - Encryption at rest and in transit
   - Network isolation

3. **Reliability**
   - Multi-AZ deployment
   - Auto-scaling
   - Health checks and automatic recovery
   - Deployment circuit breaker

4. **Performance Efficiency**
   - Right-sized resources
   - Auto-scaling based on demand
   - CloudWatch Container Insights

5. **Cost Optimization**
   - Pay-per-use (Fargate)
   - Auto-scaling to match demand
   - Lifecycle policies for resources
   - Cost monitoring and alerts

6. **Sustainability**
   - Efficient resource usage
   - Auto-scaling reduces waste
   - Serverless compute (Fargate)

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
