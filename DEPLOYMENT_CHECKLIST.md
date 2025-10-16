# Deployment Checklist

Use this checklist to ensure a successful deployment of the demo-web-claude-devops application to AWS ECS.

## Pre-Deployment Checklist

### Local Environment Setup

- [ ] AWS CLI installed and configured
  ```bash
  aws --version
  aws sts get-caller-identity
  ```

- [ ] Terraform installed (v1.0+)
  ```bash
  terraform version
  ```

- [ ] Docker installed and running
  ```bash
  docker --version
  docker ps
  ```

- [ ] Git repository cloned
  ```bash
  cd /path/to/demo-web-claude-devops
  git status
  ```

### AWS Account Preparation

- [ ] AWS account created and accessible
- [ ] IAM user created with appropriate permissions
- [ ] AWS credentials configured (`~/.aws/credentials` or environment variables)
- [ ] Verify AWS access
  ```bash
  aws sts get-caller-identity
  ```

### Local Testing

- [ ] Application runs locally with Node.js
  ```bash
  npm install
  npm start
  # Verify at http://localhost:3000
  ```

- [ ] Application runs in Docker container
  ```bash
  ./scripts/test-local.sh
  # Verify at http://localhost:3000
  ```

- [ ] Tests pass
  ```bash
  npm test
  ```

## Infrastructure Deployment Checklist

### Remote State Setup (Production Recommended)

- [ ] S3 bucket created for Terraform state
  ```bash
  aws s3api create-bucket --bucket your-terraform-state-bucket --region us-east-1
  ```

- [ ] Versioning enabled on state bucket
  ```bash
  aws s3api put-bucket-versioning \
    --bucket your-terraform-state-bucket \
    --versioning-configuration Status=Enabled
  ```

- [ ] DynamoDB table created for state locking
  ```bash
  aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
  ```

- [ ] Backend configuration updated in `terraform/backend.tf`

### Terraform Initialization

- [ ] Navigate to terraform directory
  ```bash
  cd terraform
  ```

- [ ] Review environment configuration
  ```bash
  cat environments/dev/dev.tfvars
  ```

- [ ] Customize configuration if needed
  - VPC CIDR ranges
  - Availability zones
  - Task CPU and memory
  - Scaling parameters

- [ ] Initialize Terraform
  ```bash
  terraform init
  ```

- [ ] Verify initialization success
  - `.terraform` directory created
  - Provider plugins downloaded
  - Backend configured (if using remote state)

### Infrastructure Planning

- [ ] Run Terraform plan
  ```bash
  terraform plan -var-file="environments/dev/dev.tfvars"
  ```

- [ ] Review planned changes
  - [ ] Verify resource count (~40 resources)
  - [ ] Check VPC CIDR doesn't conflict
  - [ ] Confirm region and availability zones
  - [ ] Review security group rules
  - [ ] Check IAM roles and policies

- [ ] Save plan output (optional but recommended)
  ```bash
  terraform plan -var-file="environments/dev/dev.tfvars" -out=tfplan
  ```

### Infrastructure Deployment

- [ ] Apply Terraform configuration
  ```bash
  terraform apply -var-file="environments/dev/dev.tfvars"
  # or
  terraform apply tfplan
  ```

- [ ] Confirm with 'yes' when prompted

- [ ] Wait for completion (5-10 minutes)

- [ ] Verify no errors in output

- [ ] Save outputs
  ```bash
  terraform output > outputs.txt
  ```

- [ ] Record important values
  ```bash
  export ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
  export ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
  export ECS_SERVICE=$(terraform output -raw ecs_service_name)
  export ALB_DNS=$(terraform output -raw alb_dns_name)
  ```

## Application Deployment Checklist

### Docker Image Build

- [ ] Return to project root
  ```bash
  cd ..
  ```

- [ ] Build Docker image
  ```bash
  docker build -t demo-web-claude-devops:latest .
  ```

- [ ] Verify image built successfully
  ```bash
  docker images | grep demo-web-claude-devops
  ```

- [ ] Test image locally (optional)
  ```bash
  docker run -d -p 3000:3000 --name test demo-web-claude-devops:latest
  curl http://localhost:3000
  docker stop test && docker rm test
  ```

### ECR Push

- [ ] Login to ECR
  ```bash
  aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin $ECR_REPO_URL
  ```

- [ ] Verify login success ("Login Succeeded")

- [ ] Tag image for ECR
  ```bash
  docker tag demo-web-claude-devops:latest $ECR_REPO_URL:latest
  ```

- [ ] Push image to ECR
  ```bash
  docker push $ECR_REPO_URL:latest
  ```

- [ ] Verify image in ECR
  ```bash
  aws ecr describe-images --repository-name demo-web-app-dev
  ```

### ECS Service Deployment

- [ ] Update ECS service
  ```bash
  aws ecs update-service \
    --cluster $ECS_CLUSTER \
    --service $ECS_SERVICE \
    --force-new-deployment \
    --region us-east-1
  ```

- [ ] Monitor deployment
  ```bash
  aws ecs describe-services \
    --cluster $ECS_CLUSTER \
    --services $ECS_SERVICE \
    --region us-east-1
  ```

- [ ] Wait for deployment to complete (2-3 minutes)

## Verification Checklist

### Infrastructure Verification

- [ ] VPC created
  ```bash
  aws ec2 describe-vpcs --filters "Name=tag:Project,Values=demo-web-app"
  ```

- [ ] Subnets created (public and private)
  ```bash
  aws ec2 describe-subnets --filters "Name=tag:Project,Values=demo-web-app"
  ```

- [ ] NAT Gateways operational
  ```bash
  aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=demo-web-app"
  ```

- [ ] Security groups created
  ```bash
  aws ec2 describe-security-groups --filters "Name=tag:Project,Values=demo-web-app"
  ```

- [ ] ALB created and active
  ```bash
  aws elbv2 describe-load-balancers --names demo-web-app-dev-alb
  ```

- [ ] Target group created
  ```bash
  aws elbv2 describe-target-groups --names demo-web-app-dev-tg
  ```

- [ ] ECS cluster created
  ```bash
  aws ecs describe-clusters --clusters $ECS_CLUSTER
  ```

### Service Verification

- [ ] ECS service running
  ```bash
  aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE
  ```

- [ ] Tasks running
  ```bash
  aws ecs list-tasks --cluster $ECS_CLUSTER --service-name $ECS_SERVICE
  ```

- [ ] Task count matches desired count
  ```bash
  aws ecs describe-services \
    --cluster $ECS_CLUSTER \
    --services $ECS_SERVICE \
    --query 'services[0].[runningCount,desiredCount]'
  ```

- [ ] All tasks healthy
  ```bash
  aws ecs describe-tasks \
    --cluster $ECS_CLUSTER \
    --tasks $(aws ecs list-tasks --cluster $ECS_CLUSTER --service-name $ECS_SERVICE --query 'taskArns[0]' --output text)
  ```

### Target Health Verification

- [ ] Get target group ARN
  ```bash
  cd terraform
  TG_ARN=$(terraform output -raw alb_target_group_arn)
  cd ..
  ```

- [ ] Check target health
  ```bash
  aws elbv2 describe-target-health --target-group-arn $TG_ARN
  ```

- [ ] Verify all targets show "healthy" state

- [ ] Wait for health checks to pass (may take 1-2 minutes)

### Application Verification

- [ ] Get application URL
  ```bash
  echo "Application URL: http://$ALB_DNS"
  ```

- [ ] Test homepage
  ```bash
  curl -I http://$ALB_DNS/
  # Should return 200 OK
  ```

- [ ] Test API endpoint
  ```bash
  curl "http://$ALB_DNS/api/search?q=test"
  # Should return JSON with test results
  ```

- [ ] Open in browser
  ```bash
  # macOS
  open http://$ALB_DNS
  # Linux
  xdg-open http://$ALB_DNS
  # Windows
  start http://$ALB_DNS
  ```

- [ ] Perform manual testing
  - [ ] Homepage loads
  - [ ] Search form works
  - [ ] Search results display
  - [ ] Page styling correct
  - [ ] No console errors

### Logging Verification

- [ ] CloudWatch log group exists
  ```bash
  aws logs describe-log-groups --log-group-name-prefix /ecs/demo-web-app
  ```

- [ ] Log streams created
  ```bash
  aws logs describe-log-streams \
    --log-group-name /ecs/demo-web-app-dev \
    --order-by LastEventTime \
    --descending \
    --max-items 5
  ```

- [ ] View recent logs
  ```bash
  aws logs tail /ecs/demo-web-app-dev --since 10m
  ```

- [ ] Verify application startup logs present

### Auto Scaling Verification

- [ ] Check auto-scaling target
  ```bash
  aws application-autoscaling describe-scalable-targets \
    --service-namespace ecs \
    --resource-id service/$ECS_CLUSTER/$ECS_SERVICE
  ```

- [ ] Check scaling policies
  ```bash
  aws application-autoscaling describe-scaling-policies \
    --service-namespace ecs \
    --resource-id service/$ECS_CLUSTER/$ECS_SERVICE
  ```

- [ ] Verify policies exist
  - [ ] CPU-based scaling
  - [ ] Memory-based scaling
  - [ ] Request count-based scaling

## Monitoring Setup Checklist

### CloudWatch Setup

- [ ] Access CloudWatch Console
- [ ] Navigate to Container Insights
- [ ] Verify cluster appears in list
- [ ] View cluster metrics
  - [ ] CPU utilization
  - [ ] Memory utilization
  - [ ] Network metrics

### Alarms (Recommended)

- [ ] Create alarm for unhealthy tasks
  ```bash
  aws cloudwatch put-metric-alarm \
    --alarm-name demo-web-app-dev-unhealthy-tasks \
    --alarm-description "Alert when tasks are unhealthy" \
    --metric-name HealthyHostCount \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 60 \
    --threshold 1 \
    --comparison-operator LessThanThreshold \
    --evaluation-periods 2
  ```

- [ ] Create alarm for high CPU
- [ ] Create alarm for high memory
- [ ] Create alarm for 5xx errors
- [ ] Configure SNS topic for notifications

### Cost Monitoring

- [ ] Set up AWS Budget
  - [ ] Navigate to AWS Budgets
  - [ ] Create monthly cost budget
  - [ ] Set threshold at $150 (for dev)
  - [ ] Configure email alerts

- [ ] Enable Cost Explorer
- [ ] Tag all resources properly
  - Project: demo-web-app
  - Environment: dev/staging/prod
  - ManagedBy: terraform

## Post-Deployment Checklist

### Documentation

- [ ] Document infrastructure outputs
- [ ] Record ALB DNS name
- [ ] Save ECR repository URL
- [ ] Document any customizations made
- [ ] Update team wiki/documentation

### Security Review

- [ ] Review security group rules
- [ ] Verify IAM roles follow least privilege
- [ ] Check VPC Flow Logs are enabled
- [ ] Enable ECR image scanning
- [ ] Review CloudWatch log retention
- [ ] Verify no public IPs on ECS tasks

### Backup Verification

- [ ] Terraform state backed up (if using S3)
- [ ] ECR images present
- [ ] Configuration files in Git
- [ ] Document disaster recovery procedure

### Team Handoff

- [ ] Share deployment documentation
- [ ] Provide access credentials (if needed)
- [ ] Share monitoring dashboards
- [ ] Document update procedures
- [ ] Share troubleshooting guide
- [ ] Schedule knowledge transfer session

## Cleanup Checklist (Optional)

If you need to tear down the infrastructure:

- [ ] Backup any important data
- [ ] Document current configuration
- [ ] Scale ECS service to 0 (optional - keeps infra)
  ```bash
  aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --desired-count 0
  ```

- [ ] Destroy infrastructure
  ```bash
  cd terraform
  terraform destroy -var-file="environments/dev/dev.tfvars"
  ```

- [ ] Confirm with 'yes'
- [ ] Wait for completion (5-10 minutes)
- [ ] Verify all resources deleted
- [ ] Clean up ECR images manually (if needed)
- [ ] Remove state files (if using local state)

## Troubleshooting Quick Reference

### Common Issues

**Tasks not starting:**
- Check CloudWatch logs: `aws logs tail /ecs/demo-web-app-dev --follow`
- Verify ECR image exists: `aws ecr describe-images --repository-name demo-web-app-dev`
- Check task definition: `aws ecs describe-task-definition --task-definition demo-web-app-dev`

**Health checks failing:**
- Verify app responds on port 3000: Check container logs
- Check security group rules: ALB → ECS on port 3000
- Test locally: `./scripts/test-local.sh`

**Cannot push to ECR:**
- Re-authenticate: `aws ecr get-login-password | docker login...`
- Verify IAM permissions
- Check repository exists

**High costs:**
- Check NAT Gateway usage (biggest cost)
- Review number of running tasks
- Check data transfer charges
- Consider single NAT for dev

### Support Resources

- Terraform README: `terraform/README.md`
- Deployment Guide: `DEPLOYMENT.md`
- Architecture Docs: `ARCHITECTURE.md`
- AWS ECS Documentation: https://docs.aws.amazon.com/ecs/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/

## Success Criteria

Deployment is successful when:

- [ ] All Terraform resources created without errors
- [ ] ECS service running with desired task count
- [ ] All tasks healthy in target group
- [ ] Application accessible via ALB DNS
- [ ] Application functionality verified
- [ ] Logs appearing in CloudWatch
- [ ] Auto-scaling policies active
- [ ] No errors in CloudWatch Logs
- [ ] Health checks passing
- [ ] Monitoring dashboards showing data

Congratulations on your successful deployment!
