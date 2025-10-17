# Terraform: Deploy Express.js App to AWS ECS Fargate

This Terraform configuration deploys the Express.js demo application to AWS ECS Fargate with an Application Load Balancer for public access.

## Architecture Overview

The configuration creates:

- **ECR Repository**: Stores Docker images of your application
- **ECS Fargate Cluster**: Serverless container orchestration (no EC2 management)
- **Application Load Balancer (ALB)**: Routes HTTP traffic to your application
- **CloudWatch Logs**: Centralized logging for application output
- **IAM Roles**: Proper permissions for ECS tasks and logging
- **Security Groups**: Controlled network access

## Prerequisites

1. **AWS Account** with appropriate credentials configured
   ```bash
   aws configure
   ```

2. **Terraform** installed (version 1.0 or later)
   ```bash
   terraform version
   ```

3. **Docker** installed (for building and pushing images)
   ```bash
   docker --version
   ```

4. **AWS CLI** installed and configured
   ```bash
   aws sts get-caller-identity
   ```

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform

# Download Terraform provider dependencies
terraform init
```

### 2. Review Configuration

```bash
# Validate the Terraform configuration
terraform validate

# Format code to canonical style
terraform fmt
```

### 3. Create terraform.tfvars

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (optional - defaults are reasonable for dev)
cat terraform.tfvars
```

Example `terraform.tfvars`:
```hcl
aws_region       = "us-east-1"
project_name     = "demo-web"
environment      = "dev"
app_port         = 3000
container_cpu    = 256
container_memory = 512
desired_count    = 1
enable_logging   = true
log_retention_days = 7
```

### 4. Preview Changes

```bash
# Preview all resources that will be created
terraform plan -out=tfplan

# Review the plan output - look for 18 resources to be created
```

### 5. Build and Push Docker Image to ECR

```bash
# Make script executable (first time only)
chmod +x deploy.sh

# Build image and push to ECR
./deploy.sh dev us-east-1
```

This script:
- Gets your AWS Account ID
- Creates ECR repository (if needed)
- Logs in to ECR
- Builds the Docker image
- Pushes the image with "latest" tag and timestamp tag
- Outputs the image URI for next step

### 6. Deploy Infrastructure

Option A: Using the latest image in ECR (automatic)
```bash
terraform apply tfplan
```

Option B: Specifying a specific image URI
```bash
terraform apply \
  -var='container_image=<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/demo-web-dev:latest'
```

When prompted, review the plan and type `yes` to confirm deployment.

### 7. Access Your Application

After deployment completes, Terraform will output the ALB DNS name:

```bash
# Get all outputs
terraform output

# Get just the application URL
terraform output load_balancer_url
```

Visit the URL in your browser (may take 1-2 minutes for health checks to pass):
```
http://<load-balancer-dns-name>
```

## Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region for deployment |
| `project_name` | `demo-web` | Project name for resource naming |
| `environment` | `dev` | Environment: dev, staging, or prod |
| `app_port` | `3000` | Container port (matches Dockerfile EXPOSE) |
| `container_cpu` | `256` | Fargate CPU units (256, 512, 1024, etc.) |
| `container_memory` | `512` | Fargate memory in MB |
| `desired_count` | `1` | Number of running tasks |
| `enable_logging` | `true` | Enable CloudWatch logs |
| `log_retention_days` | `7` | CloudWatch log retention |
| `container_image` | (empty) | Docker image URI (auto-set from ECR) |

## Deployment Workflow

### Complete First Deployment

```bash
# 1. Initialize
terraform init

# 2. Validate and preview
terraform validate
terraform plan

# 3. Build and push Docker image
./deploy.sh dev us-east-1

# 4. Deploy infrastructure
terraform apply

# 5. Get application URL
terraform output load_balancer_url
```

### Updating Your Application

When you make code changes and want to deploy a new version:

```bash
# 1. Rebuild and push new image
./deploy.sh dev us-east-1

# 2. Force ECS service to pull latest image
# Option A: Update and reapply
terraform apply

# Option B: Manual ECS update (faster)
aws ecs update-service \
  --cluster demo-web-cluster-dev \
  --service demo-web-service-dev \
  --force-new-deployment \
  --region us-east-1
```

### Scaling

Increase the number of running tasks:

```bash
# Scale to 3 tasks
terraform apply -var='desired_count=3'

# Or modify terraform.tfvars and run
terraform apply
```

## Monitoring

### View Application Logs

```bash
# Get log group name
terraform output -json | grep log

# View recent logs (last 100 lines)
aws logs tail /ecs/demo-web-dev --follow --region us-east-1

# View logs for specific time range
aws logs filter-log-events \
  --log-group-name /ecs/demo-web-dev \
  --region us-east-1
```

### Check ECS Service Status

```bash
# Get cluster and service names from Terraform
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)

# View service details
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region us-east-1

# View running tasks
aws ecs list-tasks --cluster $CLUSTER --region us-east-1

# Get task details
aws ecs describe-tasks \
  --cluster $CLUSTER \
  --tasks <task-id> \
  --region us-east-1
```

### Check ALB Health

```bash
# Get target group ARN
TG_ARN=$(terraform output -raw load_balancer_arn | sed 's/loadbalancer/targetgroup/')

# View target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-east-1
```

## Cleanup

To remove all AWS resources created by Terraform:

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm by typing 'yes' when prompted
```

This will:
- Terminate ECS tasks and service
- Delete load balancer
- Remove security groups
- Delete IAM roles
- Remove ECR repository (images included)

**Note**: You may need to manually delete the ALB if it has deletion protection enabled.

## Troubleshooting

### Problem: Terraform validation fails

```bash
# Check for configuration errors
terraform validate

# Format and validate again
terraform fmt
terraform validate
```

### Problem: Docker image not found in ECR

```bash
# List ECR repositories
aws ecr describe-repositories --region us-east-1

# List images in repository
aws ecr describe-images \
  --repository-name demo-web-dev \
  --region us-east-1
```

### Problem: ECS tasks won't start

```bash
# Check task definition
aws ecs describe-task-definition \
  --task-definition demo-web-task-dev \
  --region us-east-1

# View task logs
aws logs tail /ecs/demo-web-dev --follow --region us-east-1
```

### Problem: ALB shows unhealthy targets

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region us-east-1

# Common issues:
# - Security group not allowing inbound on port 3000
# - Application not listening on port 3000
# - Application startup takes longer than health check timeout
```

### Problem: ECR image push fails

```bash
# Verify Docker daemon is running
docker ps

# Re-authenticate with ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Try push again
./deploy.sh dev us-east-1
```

## Cost Estimation

Approximate monthly costs for this configuration (us-east-1):

- **ECS Fargate** (256 CPU, 512 MB, 1 task, 730 hours): ~$7.50
- **Application Load Balancer**: ~$16.20 + $0.006/hour for data
- **ECR Repository**: ~$0.10 (minimal storage)
- **CloudWatch Logs** (1 GB/month): ~$0.50

**Total**: ~$25-30/month for single task in dev environment

Costs scale with:
- Number of tasks (horizontal scaling)
- CPU/memory allocation
- Data processed by ALB
- Logging volume

## Best Practices

1. **State Management**: Store tfstate in remote backend (S3) for team environments
2. **Secrets**: Never commit `terraform.tfvars` with real values
3. **Environments**: Use separate directories or workspaces for dev/staging/prod
4. **Version Pinning**: Pin provider versions in production
5. **Tagging**: All resources are tagged with Environment and Project
6. **Logging**: CloudWatch logs enabled by default for troubleshooting
7. **Security**: Security groups follow principle of least privilege
8. **Auto-scaling**: Add auto-scaling policies for production workloads

## Next Steps

- Set up remote state backend (Terraform Cloud, S3, etc.)
- Add auto-scaling based on CPU/memory metrics
- Configure HTTPS with ACM certificate
- Add database (RDS) if needed
- Implement CI/CD pipeline for automatic deployments
- Create separate environments (dev, staging, prod) with different configs
- Add monitoring dashboards and alerts

## Files in This Directory

- `providers.tf` - AWS provider configuration
- `main.tf` - Core infrastructure resources (18 resources total)
- `variables.tf` - Input variables with validation
- `outputs.tf` - Output values (URLs, ARNs, etc.)
- `terraform.tfvars.example` - Example variable values
- `deploy.sh` - Script to build Docker image and push to ECR
- `.gitignore` - Files to exclude from version control
- `README.md` - This file

## Support

For Terraform documentation: https://www.terraform.io/docs
For AWS ECS documentation: https://docs.aws.amazon.com/ecs/
For Terraform AWS provider: https://registry.terraform.io/providers/hashicorp/aws/latest
