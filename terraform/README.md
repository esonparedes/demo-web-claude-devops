# Demo Web App - AWS ECS Infrastructure

This directory contains Terraform Infrastructure as Code (IaC) for deploying the demo-web-claude-devops application to AWS ECS (Elastic Container Service) using Fargate.

## Architecture Overview

The infrastructure includes:

- **VPC**: Multi-AZ Virtual Private Cloud with public and private subnets
- **Application Load Balancer (ALB)**: Internet-facing load balancer in public subnets
- **ECS Cluster**: Fargate-based cluster for running containerized applications
- **ECS Service**: Auto-scaling service with health checks and deployment circuit breakers
- **ECR Repository**: Private Docker image registry
- **Security Groups**: Network access controls following least privilege principle
- **IAM Roles**: Task execution and task roles with minimal required permissions
- **CloudWatch Logs**: Centralized logging for application and infrastructure
- **VPC Flow Logs**: Network traffic monitoring for security analysis
- **Auto Scaling**: CPU, memory, and request-based auto-scaling policies

### Architecture Diagram

```
Internet
    |
    v
[Application Load Balancer] (Public Subnets)
    |
    v
[ECS Tasks] (Private Subnets, Fargate)
    |
    v
[NAT Gateway] --> Internet (for pulling images, AWS API calls)
```

### High Availability

- Multi-AZ deployment across 2-3 availability zones
- ALB distributes traffic across all AZs
- Auto-scaling based on CPU, memory, and request count
- Health checks with automatic replacement of unhealthy tasks
- Deployment circuit breaker for automatic rollback

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **AWS Account**: With appropriate permissions to create resources
2. **AWS CLI**: Installed and configured with credentials
   ```bash
   aws configure
   ```
3. **Terraform**: Version 1.0 or higher
   ```bash
   terraform version
   ```
4. **Docker**: For building and testing container images
   ```bash
   docker --version
   ```

### Required AWS Permissions

Your AWS user/role needs permissions for:
- VPC, Subnet, Route Table, Internet Gateway, NAT Gateway
- ECS (Cluster, Service, Task Definition)
- ECR (Repository, Image Push/Pull)
- IAM (Role, Policy creation)
- Application Load Balancer, Target Groups
- Security Groups
- CloudWatch Logs
- S3 (if using remote state)
- DynamoDB (if using state locking)

## Directory Structure

```
terraform/
├── main.tf                 # Root module - orchestrates all resources
├── variables.tf            # Input variable definitions
├── outputs.tf              # Output value definitions
├── backend.tf              # Backend configuration for state management
├── terraform.tfvars.example # Example variables file
├── .gitignore              # Git ignore patterns
├── modules/                # Reusable Terraform modules
│   ├── vpc/                # VPC and networking
│   ├── ecr/                # Container registry
│   ├── security-groups/    # Network security rules
│   ├── iam/                # IAM roles and policies
│   ├── alb/                # Application load balancer
│   └── ecs/                # ECS cluster, service, task definition
└── environments/           # Environment-specific configurations
    ├── dev/
    │   └── dev.tfvars
    ├── staging/
    │   └── staging.tfvars
    └── prod/
        └── prod.tfvars
```

## Quick Start

### 1. Configure Backend (Optional but Recommended)

For production use, configure remote state storage:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Then uncomment and configure the backend in `backend.tf`.

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Plan Infrastructure Changes

For development environment:
```bash
terraform plan -var-file="environments/dev/dev.tfvars"
```

For staging:
```bash
terraform plan -var-file="environments/staging/staging.tfvars"
```

For production:
```bash
terraform plan -var-file="environments/prod/prod.tfvars"
```

### 4. Apply Infrastructure Changes

```bash
terraform apply -var-file="environments/dev/dev.tfvars"
```

Review the plan and type `yes` to confirm.

### 5. Get Infrastructure Outputs

```bash
terraform output
```

Important outputs:
- `alb_dns_name`: URL to access your application
- `ecr_repository_url`: ECR repository for Docker images
- `ecs_cluster_name`: ECS cluster name
- `cloudwatch_log_group_name`: CloudWatch log group

## Deployment Workflow

### Option 1: Manual Deployment

#### Step 1: Test Locally

Before deploying, test your application locally:

```bash
# From project root
./scripts/test-local.sh

# Application will be available at http://localhost:3000
```

#### Step 2: Deploy Infrastructure

```bash
cd terraform
terraform apply -var-file="environments/dev/dev.tfvars"
```

#### Step 3: Build and Push Docker Image

```bash
# Get ECR repository URL
cd terraform
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
AWS_REGION=us-east-1

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REPO_URL

# Build and push image
cd ..
docker build -t demo-web-claude-devops:latest .
docker tag demo-web-claude-devops:latest $ECR_REPO_URL:latest
docker push $ECR_REPO_URL:latest
```

#### Step 4: Deploy to ECS

```bash
cd terraform
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(terraform output -raw ecs_service_name)

aws ecs update-service \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --force-new-deployment \
  --region us-east-1
```

#### Step 5: Verify Deployment

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test the application
curl http://$ALB_DNS

# Check ECS service status
aws ecs describe-services \
  --cluster $ECS_CLUSTER \
  --services $ECS_SERVICE \
  --region us-east-1

# View logs
aws logs tail /ecs/demo-web-app-dev --follow
```

### Option 2: Using Deployment Scripts

We provide convenient scripts for common operations:

#### Test Locally
```bash
./scripts/test-local.sh [port]
```

#### Build and Push Image
```bash
./scripts/build-and-push.sh <environment> [image-tag]

# Examples:
./scripts/build-and-push.sh dev latest
./scripts/build-and-push.sh prod v1.0.0
```

#### Complete Deployment
```bash
./scripts/deploy.sh <environment> [image-tag]

# Examples:
./scripts/deploy.sh dev latest
./scripts/deploy.sh prod v1.2.0
```

The complete deployment script handles:
1. Terraform plan and apply
2. Docker image build
3. ECR push
4. ECS service update

## Environment Configuration

### Development (dev)
- Minimal resources (256 CPU, 512 MB memory)
- 1 task, scales up to 2
- Cost-optimized for testing
- Configuration: `environments/dev/dev.tfvars`

### Staging (staging)
- Moderate resources (512 CPU, 1 GB memory)
- 2 tasks, scales up to 4
- Mirrors production architecture
- Configuration: `environments/staging/staging.tfvars`

### Production (prod)
- Robust resources (1024 CPU, 2 GB memory)
- 3 tasks across 3 AZs, scales up to 10
- Deletion protection enabled
- Immutable image tags
- Configuration: `environments/prod/prod.tfvars`

## Configuration Variables

Key variables you can customize:

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | us-east-1 |
| `environment` | Environment name | dev |
| `vpc_cidr` | VPC CIDR block | 10.0.0.0/16 |
| `availability_zones` | AZ list | [us-east-1a, us-east-1b] |
| `task_cpu` | Task CPU units | 256 |
| `task_memory` | Task memory (MB) | 512 |
| `desired_count` | Number of tasks | 2 |
| `min_capacity` | Min auto-scale tasks | 1 |
| `max_capacity` | Max auto-scale tasks | 4 |

See `variables.tf` for complete list with descriptions.

## Security Best Practices

This infrastructure implements:

1. **Network Isolation**
   - ECS tasks run in private subnets (no direct internet access)
   - ALB in public subnets as the only entry point
   - Security groups with least privilege rules

2. **Encryption**
   - ECR images encrypted at rest (AES256)
   - VPC Flow Logs for security monitoring

3. **IAM Roles**
   - Separate task execution and task roles
   - Minimal required permissions
   - No hardcoded credentials

4. **Container Security**
   - Image scanning on push to ECR
   - Automated vulnerability detection
   - Immutable tags in production

5. **Monitoring and Logging**
   - CloudWatch Container Insights
   - Centralized application logs
   - VPC Flow Logs for network analysis

6. **High Availability**
   - Multi-AZ deployment
   - Auto-scaling based on metrics
   - Health checks with automatic recovery
   - Deployment circuit breaker

## Monitoring and Operations

### View Application Logs

```bash
# Tail logs in real-time
aws logs tail /ecs/demo-web-app-dev --follow

# View last 100 log lines
aws logs tail /ecs/demo-web-app-dev --since 1h
```

### Monitor ECS Service

```bash
# Service status
aws ecs describe-services \
  --cluster demo-web-app-dev-cluster \
  --services demo-web-app-dev-service

# Task status
aws ecs list-tasks \
  --cluster demo-web-app-dev-cluster \
  --service-name demo-web-app-dev-service

# Task details
aws ecs describe-tasks \
  --cluster demo-web-app-dev-cluster \
  --tasks <task-arn>
```

### Access Container Shell (ECS Exec)

```bash
# List running tasks
aws ecs list-tasks \
  --cluster demo-web-app-dev-cluster \
  --service-name demo-web-app-dev-service

# Execute command in container
aws ecs execute-command \
  --cluster demo-web-app-dev-cluster \
  --task <task-id> \
  --container demo-web-app-dev-container \
  --interactive \
  --command "/bin/sh"
```

### CloudWatch Metrics

View metrics in AWS Console:
1. Navigate to CloudWatch → Container Insights
2. Select your cluster
3. View CPU, memory, network metrics

## Troubleshooting

### ECS Tasks Not Starting

```bash
# Check service events
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name> \
  --query 'services[0].events'

# Check task stopped reason
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-arn> \
  --query 'tasks[0].stoppedReason'
```

Common issues:
- **Image pull error**: Check ECR permissions and image existence
- **Port already in use**: Check security group rules
- **Health check failing**: Verify application starts on port 3000

### ALB Health Checks Failing

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

Common causes:
- Application not responding on port 3000
- Application not returning 200 status on `/`
- Security group blocking ALB → ECS traffic

### Cannot Push to ECR

```bash
# Re-authenticate
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ecr-url>

# Check repository exists
aws ecr describe-repositories --repository-names demo-web-app-dev
```

### High Costs

Check these resources:
- **NAT Gateways**: Most expensive component (~$32/month each)
- **ECS Tasks**: Running 24/7 (consider stopping in dev)
- **Data Transfer**: Monitor outbound traffic

## Cost Optimization

### Development Environment

```bash
# Stop all tasks (keeps infrastructure, stops compute)
aws ecs update-service \
  --cluster demo-web-app-dev-cluster \
  --service demo-web-app-dev-service \
  --desired-count 0

# Start tasks again
aws ecs update-service \
  --cluster demo-web-app-dev-cluster \
  --service demo-web-app-dev-service \
  --desired-count 1
```

### Cost-Saving Tips

1. **Use single NAT Gateway for dev** (modify VPC module)
2. **Reduce task size** (minimum: 256 CPU, 512 MB)
3. **Reduce desired count** in non-production environments
4. **Set CloudWatch log retention** to 7 days for dev
5. **Delete unused ECR images** (lifecycle policy included)

## Cleanup

To destroy all infrastructure:

```bash
# CAUTION: This will delete all resources!
terraform destroy -var-file="environments/dev/dev.tfvars"
```

Production environments have deletion protection. Disable it first:

```bash
# Remove deletion protection from ALB
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn <alb-arn> \
  --attributes Key=deletion_protection.enabled,Value=false

# Then destroy
terraform destroy -var-file="environments/prod/prod.tfvars"
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to AWS ECS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Deploy
        run: |
          chmod +x ./scripts/deploy.sh
          ./scripts/deploy.sh prod v${{ github.sha }}
```

## Advanced Topics

### Adding HTTPS Support

1. Request SSL certificate in ACM
2. Uncomment HTTPS listener in `modules/alb/main.tf`
3. Add `certificate_arn` variable
4. Update security groups for port 443

### Custom Domain Name

1. Create Route53 hosted zone
2. Add A record pointing to ALB
3. Configure SSL certificate for domain

### Secrets Management

Uncomment secrets sections in:
- `modules/iam/main.tf` (IAM policies)
- `modules/ecs/main.tf` (task definition secrets)

Store secrets in AWS Secrets Manager:
```bash
aws secretsmanager create-secret \
  --name demo-web-app/prod/api-key \
  --secret-string "your-secret-value"
```

### Database Integration

To add RDS database:
1. Create RDS module
2. Add security group rules (ECS → RDS)
3. Pass connection string via environment variables or secrets

## Support and Contributions

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS CloudWatch logs
3. Verify security group rules
4. Check IAM permissions

## Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [ECS Best Practices Guide](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)

## License

This infrastructure code follows the same license as the application.
