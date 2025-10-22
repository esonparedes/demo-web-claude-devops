# Architecture Overview

## High-Level Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet Users                            │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ HTTP (Port 80)
                       ▼
      ┌─────────────────────────────────────┐
      │  Application Load Balancer (ALB)    │
      │  - Public IP address                │
      │  - Handles incoming HTTP traffic    │
      │  - Routes to ECS tasks              │
      └────────┬────────────────────────────┘
               │
               │ Forwards to Port 3000
               ▼
      ┌─────────────────────────────────────┐
      │     ECS Fargate Cluster             │
      │  ┌──────────────┐  ┌──────────────┐ │
      │  │ ECS Task     │  │ ECS Task     │ │
      │  │ (Container 1)│  │ (Container 2)│ │
      │  │              │  │              │ │
      │  │ Node.js      │  │ Node.js      │ │
      │  │ Express.js   │  │ Express.js   │ │
      │  │ Port 3000    │  │ Port 3000    │ │
      │  └──────────────┘  └──────────────┘ │
      │  (Scales from 1-10 tasks)            │
      └──────────────────────────────────────┘
```

## AWS Services Used

### 1. ECR (Elastic Container Registry)
- **Purpose**: Store Docker images of your application
- **Features**:
  - Image scanning on push (security scanning)
  - Lifecycle policy to keep last 10 images
  - Automatic cleanup of old images
- **Cost**: Minimal (~$0.10/month for storage)

### 2. ECS Fargate (Elastic Container Service)
- **Purpose**: Run containers without managing EC2 instances
- **Benefits**:
  - Serverless container orchestration
  - Auto-managed infrastructure
  - Pay only for running tasks
  - No EC2 instances to maintain
- **Configuration**:
  - 256 CPU units (0.25 vCPU)
  - 512 MB memory
  - Configurable task count (1-10)
- **Cost**: ~$7.50/month per task (256 CPU, 512 MB)

### 3. Application Load Balancer (ALB)
- **Purpose**: Route HTTP traffic to ECS tasks
- **Features**:
  - Automatic health checks
  - Distributes traffic across multiple tasks
  - Public DNS name for access
  - HTTP/2 support
- **Cost**: ~$16.20/month base + $0.006/hour per GB processed

### 4. CloudWatch Logs
- **Purpose**: Centralized logging for container output
- **Features**:
  - 7-day retention (configurable)
  - Real-time log streaming
  - Log filtering and search
- **Cost**: ~$0.50/month for typical usage

### 5. IAM Roles
- **Purpose**: Control permissions for ECS tasks
- **Components**:
  - **Task Execution Role**: Allows ECS agent to pull images, write logs
  - **Task Role**: Permissions for the application itself (unused in basic setup)
- **Security**: Follows principle of least privilege

### 6. Security Groups
- **ALB Security Group**:
  - Allows inbound HTTP (port 80) from anywhere (0.0.0.0/0)
  - Allows all outbound traffic
  - Used for: Internet-facing traffic

- **ECS Tasks Security Group**:
  - Allows inbound traffic on port 3000 from ALB only
  - Allows all outbound traffic
  - Used for: Container networking

### 7. Virtual Private Cloud (VPC)
- **Type**: Default VPC (simplicity)
- **Subnets**: Uses existing default subnets
- **CIDR**: 172.31.0.0/16 (default VPC standard)

## Resource Dependency Flow

```
terraform init
    │
    ├── Download AWS provider
    └── Create .terraform directory

terraform plan
    │
    ├── Validate configuration
    │
    ├── Create ECR Repository
    │   └── Create Lifecycle Policy
    │
    ├── Create CloudWatch Log Group
    │
    ├── Create IAM Roles
    │   ├── Task Execution Role
    │   ├── Attach policy for ECR/Logs access
    │   └── Task Role (for app permissions)
    │
    ├── Create ECS Cluster
    │   └── Enable Fargate capacity providers
    │
    ├── Create Task Definition
    │   ├── References ECR image
    │   ├── Assigns 256 CPU / 512 MB memory
    │   ├── Links to IAM roles
    │   └── Configures CloudWatch logs
    │
    ├── Create Security Groups
    │   ├── ALB security group (allows HTTP)
    │   └── ECS tasks security group (allows port 3000)
    │
    ├── Create Application Load Balancer
    │
    ├── Create Target Group
    │   └── Health check configuration
    │
    ├── Create ALB Listener
    │   └── Routes port 80 to target group
    │
    └── Create ECS Service
        ├── References cluster
        ├── References task definition
        ├── Sets desired task count
        ├── Assigns security groups
        └── Registers with load balancer
```

## Data Flow

### 1. User Request
```
User Browser → http://alb-dns-name:80
```

### 2. ALB Processing
```
ALB (port 80)
  ├── Receives request
  ├── Checks target health
  └── Forwards to healthy ECS task (port 3000)
```

### 3. ECS Task Processing
```
ECS Task (Express.js running on port 3000)
  ├── Receives request
  ├── Renders Google-like search UI (views/index.ejs)
  ├── Handles /api/search endpoint
  └── Returns response to ALB
```

### 4. Response Path
```
ECS Task → ALB → User Browser
```

## Deployment Sequence

### First Time Setup
```
1. Prepare AWS account
   └── Have AWS credentials configured

2. Initialize Terraform
   └── terraform init

3. Validate configuration
   └── terraform validate && terraform fmt

4. Build Docker image
   └── ./deploy.sh dev us-east-1
       ├── Creates ECR repository
       ├── Logs into ECR
       ├── Builds Docker image
       └── Pushes to ECR

5. Deploy infrastructure
   └── terraform apply
       ├── Creates all resources
       ├── Links ECS to ECR image
       ├── Starts ECS tasks
       └── Configures load balancer

6. Wait for health checks
   └── ALB performs health checks on targets
       └── Takes 1-2 minutes

7. Access application
   └── curl http://<alb-dns-name>
```

### Update Deployment
```
1. Update application code
   └── Modify server.js, views/, etc.

2. Rebuild Docker image
   └── ./deploy.sh dev us-east-1
       └── Creates new image with :latest tag

3. Force ECS update
   └── Option A: terraform apply
   └── Option B: aws ecs update-service --force-new-deployment
       └── Pulls new image
       └── Stops old tasks
       └── Starts new tasks
       └── Health checks pass
       └── Requests routed to new tasks
```

## Scaling

### Horizontal Scaling (More Tasks)
```
Current: 1 task
Desired: 3 tasks

Process:
  1. terraform apply -var='desired_count=3'
  2. ECS launches 2 additional tasks
  3. ALB discovers new tasks
  4. Requests distributed across 3 tasks
  5. Load reduced per task
```

### Vertical Scaling (More CPU/Memory)
```
Current: 256 CPU, 512 MB
Desired: 512 CPU, 1024 MB

Process:
  1. Update terraform.tfvars
  2. terraform plan (review changes)
  3. terraform apply
  4. ECS creates new task definition revision
  5. Old tasks gradually replaced
  6. New tasks with more resources start
```

## Cost Breakdown (Monthly Estimate)

| Component | Count | Size | Cost |
|-----------|-------|------|------|
| ECS Fargate | 1 | 256 CPU, 512 MB | $7.50 |
| ALB | 1 | - | $16.20 |
| ALB Data | 1 | 10 GB/month | $0.10 |
| ECR Storage | 1 | 100 MB | $0.10 |
| CloudWatch Logs | 1 | 1 GB/month | $0.50 |
| **Total** | | | **~$24.40** |

Notes:
- Costs vary by AWS region
- Scaling to 3 tasks adds ~$22.50/month
- Data processing costs depend on actual usage
- Free tier: first 1M requests to ALB, 10 GB ECR storage

## Security Considerations

### Network Security
- ALB accepts HTTP from anywhere (0.0.0.0/0)
- ECS tasks only accept port 3000 from ALB
- No direct internet access to ECS tasks
- Production: Add HTTPS with ACM certificate

### Access Control
- IAM roles restrict permissions to minimum needed
- Task execution role can only:
  - Pull from specific ECR repository
  - Write to specific CloudWatch log group
- Application runs as non-root container user

### Data Security
- No hardcoded secrets in container
- Use AWS Secrets Manager for sensitive data
- ECR images scanned for vulnerabilities

### Compliance
- CloudWatch logs retention: 7 days (configurable)
- All resources tagged for audit trails
- Terraform state contains sensitive data
  - Store tfstate in remote backend with encryption
  - Don't commit tfstate to git

## Monitoring & Debugging

### Key Metrics to Watch
- **ALB Target Health**: Should be "Healthy"
- **ECS Task Count**: Should match desired_count
- **CPU Utilization**: Watch for bottlenecks
- **Memory Utilization**: Adjust container memory as needed
- **ALB Response Time**: Monitor performance

### Troubleshooting Checklist
```
Application not accessible?
  └── Check ALB DNS name accessible: curl <alb-dns>

Targets showing unhealthy?
  └── Check ECS task logs
  └── Verify application listening on port 3000
  └── Check security group allows port 3000 from ALB

ECS tasks won't start?
  └── Check CloudWatch logs for startup errors
  └── Verify Docker image exists in ECR
  └── Check task definition references correct image

High latency or errors?
  └── Scale up (more tasks)
  └── Increase container resources (CPU/memory)
  └── Check application logs for errors
```

## Production Recommendations

1. **Use HTTPS**: Add ACM certificate to ALB
2. **Auto-scaling**: Add target tracking policies
3. **Remote State**: Store tfstate in S3 with encryption
4. **Environments**: Create separate dev/staging/prod
5. **Monitoring**: Add CloudWatch alarms and dashboards
6. **Backup**: Enable automated snapshots if using databases
7. **CI/CD**: Automate docker build → push → deploy
8. **Secrets**: Use AWS Secrets Manager for credentials
9. **Logging**: Aggregate logs across services
10. **Disaster Recovery**: Document runbooks and procedures
