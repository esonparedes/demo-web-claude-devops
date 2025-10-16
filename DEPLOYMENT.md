# Deployment Guide

This guide provides step-by-step instructions for deploying the demo-web-claude-devops application to AWS ECS using Terraform.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Testing](#local-testing)
3. [Initial AWS Setup](#initial-aws-setup)
4. [Infrastructure Deployment](#infrastructure-deployment)
5. [Application Deployment](#application-deployment)
6. [Verification](#verification)
7. [Monitoring](#monitoring)
8. [Updates and Rollbacks](#updates-and-rollbacks)
9. [Cleanup](#cleanup)

## Prerequisites

### Required Tools

Install the following tools before starting:

1. **AWS CLI** (v2 or higher)
   ```bash
   # Install AWS CLI
   # macOS
   brew install awscli

   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Verify installation
   aws --version
   ```

2. **Terraform** (v1.0 or higher)
   ```bash
   # macOS
   brew install terraform

   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/

   # Verify installation
   terraform version
   ```

3. **Docker** (v20 or higher)
   ```bash
   # macOS
   brew install --cask docker

   # Linux (Ubuntu/Debian)
   sudo apt-get update
   sudo apt-get install docker.io

   # Verify installation
   docker --version
   ```

### AWS Account Setup

1. **Create AWS Account** (if you don't have one)
   - Visit https://aws.amazon.com
   - Sign up for a new account

2. **Create IAM User with Required Permissions**
   ```bash
   # Create IAM user (via AWS Console or CLI)
   aws iam create-user --user-name terraform-deploy

   # Attach required policies
   aws iam attach-user-policy --user-name terraform-deploy \
     --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

   # Create access key
   aws iam create-access-key --user-name terraform-deploy
   ```

3. **Configure AWS CLI**
   ```bash
   aws configure
   # Enter your AWS Access Key ID
   # Enter your AWS Secret Access Key
   # Enter default region (e.g., us-east-1)
   # Enter default output format (json)

   # Verify configuration
   aws sts get-caller-identity
   ```

## Local Testing

Before deploying to AWS, test the application locally:

### Method 1: Using Docker (Recommended)

```bash
# Test using the provided script
./scripts/test-local.sh

# Or manually:
docker build -t demo-web-claude-devops:test .
docker run -p 3000:3000 demo-web-claude-devops:test

# Access the application
open http://localhost:3000
```

### Method 2: Using Node.js Directly

```bash
# Install dependencies
npm install

# Run the application
npm start

# Access the application
open http://localhost:3000
```

### Verify Functionality

1. Open http://localhost:3000 in your browser
2. Enter a search query and click "Google Search"
3. Verify results are displayed
4. Check the API endpoint: http://localhost:3000/api/search?q=test

If everything works locally, proceed to AWS deployment.

## Initial AWS Setup

### Step 1: Setup Remote State (Production Recommended)

For production environments, store Terraform state remotely:

```bash
# Set variables
STATE_BUCKET="your-company-terraform-state"
STATE_LOCK_TABLE="terraform-state-lock"
AWS_REGION="us-east-1"

# Create S3 bucket for state
aws s3api create-bucket \
  --bucket $STATE_BUCKET \
  --region $AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $STATE_BUCKET \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $STATE_BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $STATE_BUCKET \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name $STATE_LOCK_TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION

# Update backend.tf with your bucket name
# Uncomment the backend configuration in terraform/backend.tf
```

### Step 2: Choose Environment

Decide which environment to deploy:

- **Development**: For testing, minimal resources, cost-optimized
- **Staging**: Pre-production environment, mirrors production
- **Production**: Full production deployment with HA and auto-scaling

## Infrastructure Deployment

### Step 1: Initialize Terraform

```bash
cd terraform

# Initialize Terraform (downloads providers and modules)
terraform init
```

### Step 2: Review Configuration

```bash
# Review the configuration for your environment
cat environments/dev/dev.tfvars

# Customize if needed (optional)
# Edit the tfvars file to adjust CPU, memory, scaling, etc.
```

### Step 3: Plan Infrastructure

```bash
# Run Terraform plan for development
terraform plan -var-file="environments/dev/dev.tfvars"

# Review the plan carefully:
# - Check resource counts
# - Verify CIDR ranges don't conflict
# - Confirm region and availability zones
```

Expected resources to be created:
- VPC with subnets, NAT gateways, route tables
- Security groups for ALB and ECS
- IAM roles and policies
- ECR repository
- Application Load Balancer
- ECS cluster, task definition, and service
- CloudWatch log groups
- Auto-scaling policies

### Step 4: Apply Infrastructure

```bash
# Apply the configuration
terraform apply -var-file="environments/dev/dev.tfvars"

# Type 'yes' when prompted

# Wait for completion (typically 3-5 minutes)
```

### Step 5: Save Outputs

```bash
# Display all outputs
terraform output

# Save important values
export ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
export ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
export ECS_SERVICE=$(terraform output -raw ecs_service_name)
export ALB_DNS=$(terraform output -raw alb_dns_name)

# Display the values
echo "ECR Repository: $ECR_REPO_URL"
echo "ECS Cluster: $ECS_CLUSTER"
echo "ECS Service: $ECS_SERVICE"
echo "Application URL: http://$ALB_DNS"
```

## Application Deployment

### Method 1: Using Deployment Script (Recommended)

```bash
# From project root, run the complete deployment script
./scripts/deploy.sh dev latest

# This script will:
# 1. Run terraform plan and apply
# 2. Build Docker image
# 3. Push to ECR
# 4. Update ECS service
```

### Method 2: Manual Deployment

#### Step 1: Build Docker Image

```bash
# From project root
docker build -t demo-web-claude-devops:latest .

# Verify image was built
docker images | grep demo-web-claude-devops
```

#### Step 2: Login to ECR

```bash
# Get login credentials
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REPO_URL

# You should see "Login Succeeded"
```

#### Step 3: Tag and Push Image

```bash
# Tag the image for ECR
docker tag demo-web-claude-devops:latest $ECR_REPO_URL:latest

# Push to ECR
docker push $ECR_REPO_URL:latest

# Verify image was pushed
aws ecr describe-images --repository-name demo-web-app-dev
```

#### Step 4: Deploy to ECS

```bash
# Update ECS service to deploy the new image
aws ecs update-service \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --force-new-deployment \
  --region us-east-1

# Monitor deployment
aws ecs describe-services \
  --cluster $ECS_CLUSTER \
  --services $ECS_SERVICE \
  --region us-east-1 \
  --query 'services[0].deployments'
```

## Verification

### Step 1: Check ECS Service Status

```bash
# Check service status
aws ecs describe-services \
  --cluster $ECS_CLUSTER \
  --services $ECS_SERVICE \
  --region us-east-1 \
  --query 'services[0].[status,runningCount,desiredCount,deployments]'

# Wait until runningCount == desiredCount
# This typically takes 2-3 minutes
```

### Step 2: Check Task Health

```bash
# List running tasks
aws ecs list-tasks \
  --cluster $ECS_CLUSTER \
  --service-name $ECS_SERVICE \
  --region us-east-1

# Get task details
TASK_ARN=$(aws ecs list-tasks \
  --cluster $ECS_CLUSTER \
  --service-name $ECS_SERVICE \
  --region us-east-1 \
  --query 'taskArns[0]' --output text)

aws ecs describe-tasks \
  --cluster $ECS_CLUSTER \
  --tasks $TASK_ARN \
  --region us-east-1
```

### Step 3: Check ALB Target Health

```bash
# Get target group ARN
cd terraform
TG_ARN=$(terraform output -raw alb_target_group_arn)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN

# All targets should show "healthy" status
```

### Step 4: Test Application

```bash
# Get ALB DNS name
ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)

# Test homepage
curl http://$ALB_DNS/

# Test API endpoint
curl "http://$ALB_DNS/api/search?q=terraform"

# Open in browser
open http://$ALB_DNS
```

Expected results:
- Homepage loads successfully (200 status)
- Search functionality works
- API returns JSON results

## Monitoring

### CloudWatch Logs

```bash
# View real-time logs
aws logs tail /ecs/demo-web-app-dev --follow

# View logs from last hour
aws logs tail /ecs/demo-web-app-dev --since 1h

# Filter logs by pattern
aws logs tail /ecs/demo-web-app-dev --filter-pattern "ERROR"
```

### CloudWatch Metrics

Visit AWS Console → CloudWatch → Container Insights:
1. Select your ECS cluster
2. View CPU, memory, network metrics
3. Set up alarms for critical metrics

### ECS Console

Visit AWS Console → ECS:
1. Select your cluster
2. View service details
3. Monitor task status
4. View deployment history

## Updates and Rollbacks

### Deploying Application Updates

```bash
# Option 1: Quick update (same image tag)
./scripts/build-and-push.sh dev latest

# Option 2: Version-tagged update
./scripts/build-and-push.sh dev v1.1.0

# Option 3: Complete deployment with infrastructure changes
./scripts/deploy.sh dev v1.1.0
```

### Rolling Back

```bash
# Get previous task definition
aws ecs list-task-definitions \
  --family-prefix demo-web-app-dev \
  --sort DESC

# Update service to use previous task definition
aws ecs update-service \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --task-definition demo-web-app-dev:X \
  --region us-east-1

# Or push previous image version
docker tag $ECR_REPO_URL:v1.0.0 $ECR_REPO_URL:latest
docker push $ECR_REPO_URL:latest
aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment
```

### Infrastructure Updates

```bash
# Update tfvars file as needed
vim terraform/environments/dev/dev.tfvars

# Plan changes
cd terraform
terraform plan -var-file="environments/dev/dev.tfvars"

# Apply changes
terraform apply -var-file="environments/dev/dev.tfvars"
```

## Cleanup

### Option 1: Destroy Everything

```bash
# CAUTION: This destroys all infrastructure!
cd terraform
terraform destroy -var-file="environments/dev/dev.tfvars"

# Type 'yes' to confirm
```

### Option 2: Scale to Zero (Keep Infrastructure)

```bash
# Stop all tasks but keep infrastructure
aws ecs update-service \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --desired-count 0 \
  --region us-east-1

# Resume later
aws ecs update-service \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --desired-count 2 \
  --region us-east-1
```

## Estimated Costs

Monthly costs for each environment (approximate):

### Development
- NAT Gateway: $32/month × 2 = $64
- ALB: $16/month
- ECS Fargate: ~$10/month (1 task, 256 CPU, 512 MB)
- Data Transfer: ~$5/month
- **Total: ~$95/month**

### Staging
- NAT Gateway: $32/month × 2 = $64
- ALB: $16/month
- ECS Fargate: ~$40/month (2 tasks, 512 CPU, 1 GB)
- Data Transfer: ~$10/month
- **Total: ~$130/month**

### Production
- NAT Gateway: $32/month × 3 = $96
- ALB: $16/month
- ECS Fargate: ~$150/month (3 tasks, 1 vCPU, 2 GB)
- Data Transfer: ~$20/month
- **Total: ~$282/month**

Cost-saving tips:
1. Use single NAT Gateway in dev (saves $32/month)
2. Stop tasks when not in use (development)
3. Use smaller task sizes for low-traffic applications
4. Enable AWS Cost Explorer for detailed tracking

## Troubleshooting

See the [Terraform README](terraform/README.md#troubleshooting) for detailed troubleshooting steps.

Common issues:
- **Tasks not starting**: Check CloudWatch logs and task stopped reason
- **Health checks failing**: Verify application responds on port 3000
- **Cannot push to ECR**: Re-authenticate with ECR
- **Terraform errors**: Ensure AWS credentials are configured

## Next Steps

After successful deployment:

1. **Set up monitoring alerts** (CloudWatch Alarms)
2. **Configure custom domain** (Route53 + ACM)
3. **Add HTTPS support** (ACM certificate)
4. **Implement CI/CD** (GitHub Actions, GitLab CI)
5. **Add database if needed** (RDS module)
6. **Configure backup strategy**
7. **Implement WAF for security** (AWS WAF)
8. **Set up cost alerts** (AWS Budgets)

## Support

For issues or questions:
- Review the [Terraform README](terraform/README.md)
- Check CloudWatch logs
- Verify security group rules
- Review IAM permissions
- Check AWS service limits

## Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Docker Documentation](https://docs.docker.com/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
