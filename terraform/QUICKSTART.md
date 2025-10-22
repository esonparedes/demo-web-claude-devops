# Quick Start Guide - 10 Minutes to Deployment

This guide gets your Express.js app running on AWS ECS Fargate in about 10 minutes.

## Prerequisites Checklist

Before starting, verify you have:

```bash
# Check AWS CLI is installed and configured
aws sts get-caller-identity

# Check Terraform is installed
terraform version

# Check Docker is installed and running
docker --version
docker ps

# Verify repository is cloned
cd /workspaces/demo-web-claude-devops
```

## Step 1: Initialize Terraform (1 minute)

```bash
cd terraform

# Download AWS provider and dependencies
terraform init

# Output should show "Terraform has been successfully initialized!"
```

## Step 2: Validate Configuration (30 seconds)

```bash
# Check that all code is valid
terraform validate

# Format code to canonical style
terraform fmt

# Output should show "Success! The configuration is valid."
```

## Step 3: Review Variables (1 minute)

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# View current settings (for dev environment)
cat terraform.tfvars

# Optional: Edit for your needs
# - Change aws_region if needed
# - Adjust container_cpu/memory if needed
# - Modify project_name if needed
```

## Step 4: Preview Infrastructure (1-2 minutes)

```bash
# See what will be created (doesn't make any changes)
terraform plan

# Review output - you should see:
# - 18 resources to be created
# - ECR repository
# - ECS cluster, service, task definition
# - Application Load Balancer
# - Security groups
# - IAM roles

# If successful, save the plan to a file
terraform plan -out=tfplan
```

## Step 5: Build and Push Docker Image (2-3 minutes)

```bash
# Make script executable (first time only)
chmod +x deploy.sh

# Build Docker image and push to ECR
./deploy.sh dev us-east-1

# Script will:
# - Get your AWS Account ID
# - Create ECR repository (if needed)
# - Login to ECR
# - Build Docker image
# - Push to ECR with :latest tag
# - Output the image URI

# At the end, note the ECR URI - you'll use it next
```

## Step 6: Deploy to AWS (3-5 minutes)

```bash
# Deploy all infrastructure using saved plan
terraform apply tfplan

# Terraform will:
# - Create all resources
# - Link ECS to your Docker image
# - Start ECS tasks
# - Configure the load balancer
# - Show outputs when complete

# When done, look for outputs like:
# load_balancer_dns = "demo-web-alb-dev-1234567890.us-east-1.elb.amazonaws.com"
# load_balancer_url = "http://demo-web-alb-dev-1234567890.us-east-1.elb.amazonaws.com"
```

## Step 7: Wait for Health Checks (1-2 minutes)

```bash
# Get the load balancer DNS name
terraform output load_balancer_dns

# The ALB performs health checks on ECS tasks
# This typically takes 1-2 minutes to show "Healthy"

# Monitor health status
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw | grep -o 'arn.*targetgroup.*' | head -1) \
  --region us-east-1
```

## Step 8: Access Your Application (30 seconds)

```bash
# Get the application URL
terraform output load_balancer_url

# Copy the URL and open in browser
# Or use curl
curl $(terraform output -raw load_balancer_url)

# You should see the Google-like search interface!
```

## Verification Checklist

After deployment completes, verify everything is working:

```bash
# 1. Get application URL
APP_URL=$(terraform output -raw load_balancer_url)

# 2. Test the homepage
curl $APP_URL
# Should return HTML with "Google" text

# 3. Test the API
curl "$APP_URL/api/search?q=test"
# Should return JSON with search results

# 4. Check ECS service
terraform output ecs_service_name
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --region us-east-1

# 5. View application logs
aws logs tail /ecs/demo-web-dev --follow --region us-east-1

# If all checks pass, deployment is successful!
```

## Making Changes

### Update Application Code

```bash
# 1. Edit application code
vim ../server.js

# 2. Rebuild Docker image
./deploy.sh dev us-east-1

# 3. Update ECS service to use new image
terraform apply

# New tasks will automatically be deployed
```

### Scale Application

```bash
# Scale to 3 tasks
terraform apply -var='desired_count=3'

# Scale back to 1 task
terraform apply -var='desired_count=1'
```

### Change Container Resources

```bash
# Increase to 512 CPU and 1024 MB memory
terraform apply \
  -var='container_cpu=512' \
  -var='container_memory=1024'

# This requires redeploying tasks
```

## Cleanup / Destroy

```bash
# Remove all AWS resources (cannot be undone!)
terraform destroy

# Confirm by typing 'yes' when prompted

# This deletes:
# - ECS cluster and services
# - Application Load Balancer
# - ECR repository and images
# - IAM roles
# - Security groups
# - CloudWatch logs
```

## Troubleshooting

### Issue: "terraform init" fails

```bash
# Check AWS credentials are configured
aws sts get-caller-identity

# Check Terraform version
terraform version  # Should be >= 1.0

# Try reinitializing
terraform init -upgrade
```

### Issue: "terraform plan" fails with permission error

```bash
# Check AWS credentials have EC2/ECS permissions
aws iam get-user

# Verify credentials are valid
aws sts get-caller-identity

# Try specifying AWS region explicitly
terraform plan -var='aws_region=us-east-1'
```

### Issue: Docker build fails in deploy.sh

```bash
# Check Docker is running
docker ps

# Check Dockerfile exists
ls -la ../Dockerfile

# Check Docker can build
docker build -t test-build ../

# Try deploy script with debug output
bash -x ./deploy.sh dev us-east-1
```

### Issue: Application not accessible after deployment

```bash
# Check ALB health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region us-east-1

# Check ECS task status
aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name) \
  --region us-east-1

# Check application logs
aws logs tail /ecs/demo-web-dev --follow --region us-east-1

# Health checks fail? Application must:
# - Listen on port 3000
# - Return 200-299 status on GET /
# - Start within 30 seconds
```

## Cost Management

Current monthly cost: ~$24

To reduce costs:

```bash
# Option 1: Use smaller instance
terraform apply -var='container_cpu=256' -var='container_memory=512'

# Option 2: Deploy to cheaper region (e.g., us-west-1)
terraform apply -var='aws_region=us-west-1'

# Option 3: Use spot instances (cheaper but less reliable)
# Would require modifying main.tf

# Option 4: Stop temporarily (remove all resources)
terraform destroy
```

## Next Steps

1. **Add HTTPS**: Configure ACM certificate with ALB listener
2. **Auto-scaling**: Add target tracking policies
3. **CI/CD**: Automate deployments with GitHub Actions
4. **Monitoring**: Add CloudWatch alarms for metrics
5. **Database**: Add RDS for persistent storage
6. **Secrets**: Use AWS Secrets Manager for credentials

## Common Commands Reference

```bash
# Plan infrastructure changes
terraform plan

# Apply (deploy) infrastructure
terraform apply

# Destroy all resources
terraform destroy

# View current outputs
terraform output

# View specific output
terraform output load_balancer_url

# View current state
terraform state list

# Refresh state from AWS
terraform refresh

# Format all .tf files
terraform fmt

# Validate configuration
terraform validate

# View resource details
terraform state show aws_ecs_cluster.app

# View Terraform graph
terraform graph | dot -Tsvg > graph.svg
```

## Getting Help

- Terraform Docs: https://www.terraform.io/docs
- AWS ECS Docs: https://docs.aws.amazon.com/ecs/
- AWS Fargate Docs: https://docs.aws.amazon.com/fargate/
- AWS ALB Docs: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/
- ECR Docs: https://docs.aws.amazon.com/ecr/

## Success!

If you've followed all steps and can access the application in your browser, deployment is complete! Your Express.js app is now running on AWS ECS Fargate with automatic load balancing and scaling.
