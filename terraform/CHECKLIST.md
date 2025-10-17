# Deployment Checklist

Use this checklist to ensure your deployment is successful.

## Pre-Deployment Checklist

### Prerequisites Verification

```
[ ] AWS Account created
[ ] AWS credentials configured
    Verify: aws sts get-caller-identity

[ ] Terraform installed (version 1.0+)
    Verify: terraform version

[ ] Docker installed and running
    Verify: docker --version && docker ps

[ ] AWS CLI installed
    Verify: aws --version

[ ] Internet connection working
    Verify: ping 8.8.8.8

[ ] Sufficient AWS API quotas
    Verify: https://console.aws.amazon.com/servicequotas/
```

### Repository Verification

```
[ ] Repository cloned
    Location: /workspaces/demo-web-claude-devops

[ ] Terraform directory exists
    Verify: ls -la terraform/

[ ] Dockerfile exists
    Verify: test -f Dockerfile

[ ] package.json exists
    Verify: test -f package.json

[ ] Application code exists
    Verify: test -f server.js
```

### Terraform Configuration Verification

```
[ ] providers.tf exists
    Verify: test -f terraform/providers.tf

[ ] main.tf exists (18 resources)
    Verify: test -f terraform/main.tf

[ ] variables.tf exists
    Verify: test -f terraform/variables.tf

[ ] outputs.tf exists
    Verify: test -f terraform/outputs.tf

[ ] terraform.tfvars exists
    Verify: test -f terraform/terraform.tfvars

[ ] terraform.tfvars.example exists
    Verify: test -f terraform/terraform.tfvars.example

[ ] deploy.sh exists
    Verify: test -f terraform/deploy.sh

[ ] .gitignore exists
    Verify: test -f terraform/.gitignore
```

### Documentation Verification

```
[ ] README.md exists
    Verify: test -f terraform/README.md

[ ] QUICKSTART.md exists
    Verify: test -f terraform/QUICKSTART.md

[ ] ARCHITECTURE.md exists
    Verify: test -f terraform/ARCHITECTURE.md

[ ] FILES_OVERVIEW.md exists
    Verify: test -f terraform/FILES_OVERVIEW.md

[ ] REFERENCE.md exists
    Verify: test -f terraform/REFERENCE.md

[ ] DEPLOYMENT.md exists
    Verify: test -f ../DEPLOYMENT.md
```

## Deployment Checklist

### Step 1: Initialize Terraform

```
[ ] Change to terraform directory
    cd terraform

[ ] Run terraform init
    terraform init

[ ] Verify .terraform directory created
    test -d .terraform

[ ] Verify .terraform.lock.hcl created
    test -f .terraform.lock.hcl

[ ] See success message
    "Terraform has been successfully initialized!"
```

### Step 2: Validate & Format

```
[ ] Run terraform validate
    terraform validate

[ ] Verify success message
    "Success! The configuration is valid."

[ ] Run terraform fmt
    terraform fmt

[ ] Verify no errors
    (no output = success)
```

### Step 3: Configure Variables

```
[ ] Review terraform.tfvars
    cat terraform.tfvars

[ ] Verify values are correct
    - aws_region: us-east-1
    - project_name: demo-web
    - environment: dev
    - app_port: 3000
    - container_cpu: 256
    - container_memory: 512
    - desired_count: 1

[ ] Optionally modify values
    vi terraform.tfvars

[ ] Save configuration
    (if edited)
```

### Step 4: Preview Infrastructure

```
[ ] Run terraform plan
    terraform plan

[ ] Verify 18 resources to be created
    "Plan: 18 to add, 0 to change, 0 to destroy"

[ ] Review resource types:
    - ECR Repository
    - CloudWatch Log Group
    - IAM Roles
    - ECS Cluster
    - ECS Task Definition
    - ECS Service
    - Security Groups
    - Application Load Balancer
    - Target Group
    - ALB Listener

[ ] No errors in plan output
    No "Error:" messages

[ ] Save plan to file (optional)
    terraform plan -out=tfplan
```

### Step 5: Build Docker Image

```
[ ] Make deploy script executable
    chmod +x deploy.sh

[ ] Run deploy script
    ./deploy.sh dev us-east-1

[ ] Script gets AWS Account ID
    Look for: "Account ID: [number]"

[ ] Script creates/checks ECR repository
    Look for: "ECR repository" message

[ ] Script logs into ECR
    Look for: "ECR login successful"

[ ] Script builds Docker image
    Look for: "Docker image built successfully"

[ ] Script pushes to ECR
    Look for: "Image pushed to ECR successfully"

[ ] Note the ECR URI
    Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/demo-web-dev:latest
```

### Step 6: Deploy Infrastructure

```
[ ] Run terraform apply
    terraform apply tfplan

    Or if using saved plan:
    terraform apply tfplan

    Or without saved plan:
    terraform apply

[ ] Review plan summary
    "Plan: 18 to add, 0 to change, 0 to destroy"

[ ] Type 'yes' to confirm

[ ] Resources being created
    Watch for: "aws_ecr_repository.app: Creating..."
    Continue until: "Apply complete!"

[ ] Verify completion message
    "Apply complete! Resources: 18 added, 0 changed, 0 destroyed"

[ ] Verify no errors
    No "Error:" messages at the end
```

### Step 7: Capture Output Values

```
[ ] Get all outputs
    terraform output

[ ] Capture ECR repository URL
    terraform output -raw ecr_repository_url

[ ] Capture load balancer DNS
    terraform output -raw load_balancer_dns

[ ] Capture application URL
    terraform output -raw load_balancer_url

[ ] Capture ECS cluster name
    terraform output -raw ecs_cluster_name

[ ] Capture deployment info
    terraform output deployment_info
```

### Step 8: Wait for Health Checks

```
[ ] Wait 1-2 minutes
    ALB needs time to perform health checks

[ ] Check target health (optional)
    aws elbv2 describe-target-health \
      --target-group-arn <arn> \
      --region us-east-1

[ ] Verify status shows "Healthy"
    (May show "healthy" after 1-2 minutes)
```

### Step 9: Access Application

```
[ ] Get application URL
    terraform output -raw load_balancer_url

[ ] Copy URL to browser
    Example: http://demo-web-alb-dev-123456.us-east-1.elb.amazonaws.com

[ ] Verify page loads
    [ ] Google-like search interface appears
    [ ] No 502/503 errors
    [ ] CSS styles applied correctly

[ ] Test API endpoint
    curl "http://<alb-dns>/api/search?q=test"

[ ] Verify JSON response
    Should return search results
```

### Step 10: Verify Logs

```
[ ] Check CloudWatch logs
    aws logs tail /ecs/demo-web-dev --follow

[ ] Verify logs showing
    Application startup messages
    Request logs
    No error messages

[ ] Exit logs (Ctrl+C)
```

## Post-Deployment Checklist

### Functionality Verification

```
[ ] Homepage accessible
    curl <alb-url> | grep -i "google"

[ ] Search API works
    curl "<alb-url>/api/search?q=test"

[ ] API returns JSON
    Check response is valid JSON

[ ] Results format correct
    [ ] items array present
    [ ] title fields present
    [ ] description fields present
    [ ] url fields present
```

### Infrastructure Verification

```
[ ] ECR repository exists
    aws ecr describe-repositories --region us-east-1

[ ] Docker image in ECR
    aws ecr describe-images --repository-name demo-web-dev

[ ] ECS cluster created
    aws ecs describe-clusters \
      --clusters demo-web-cluster-dev \
      --region us-east-1

[ ] ECS service running
    aws ecs describe-services \
      --cluster demo-web-cluster-dev \
      --services demo-web-service-dev \
      --region us-east-1

[ ] Tasks running
    aws ecs list-tasks --cluster demo-web-cluster-dev

[ ] ALB created
    aws elbv2 describe-load-balancers | grep "demo-web"

[ ] Target group exists
    aws elbv2 describe-target-groups | grep "demo-web"
```

### Security Verification

```
[ ] Security group allows ALB traffic
    aws ec2 describe-security-groups \
      --group-names demo-web-alb-sg-dev

[ ] Security group restricts ECS access
    aws ec2 describe-security-groups \
      --group-names demo-web-ecs-sg-dev

[ ] IAM roles created
    aws iam list-roles | grep demo-web

[ ] CloudWatch logs enabled
    aws logs describe-log-groups | grep demo-web
```

### Documentation Verification

```
[ ] All guides are readable
    [ ] terraform/README.md
    [ ] terraform/QUICKSTART.md
    [ ] terraform/ARCHITECTURE.md
    [ ] terraform/FILES_OVERVIEW.md
    [ ] terraform/REFERENCE.md

[ ] Guides contain helpful information
    [ ] Deployment instructions
    [ ] Troubleshooting tips
    [ ] Architecture diagrams
    [ ] Command reference
```

## Scaling Verification (Optional)

```
[ ] Scale to 3 tasks
    terraform apply -var='desired_count=3'

[ ] Verify 3 tasks running
    aws ecs list-tasks --cluster demo-web-cluster-dev

[ ] Verify all targets healthy
    aws elbv2 describe-target-health --target-group-arn <arn>

[ ] Application still accessible
    curl <alb-url>

[ ] Scale back to 1 task
    terraform apply -var='desired_count=1'
```

## Troubleshooting Checklist

### If terraform init fails

```
[ ] Check AWS credentials
    aws sts get-caller-identity

[ ] Check Terraform version
    terraform version  # Should be >= 1.0

[ ] Check internet connection
    ping 8.8.8.8

[ ] Try reinitializing
    rm -rf .terraform
    terraform init
```

### If terraform validate fails

```
[ ] Check syntax errors
    terraform validate

[ ] Format code
    terraform fmt

[ ] Revalidate
    terraform validate

[ ] Check for typos in main.tf
    grep -n "resource\|data" main.tf
```

### If terraform plan fails

```
[ ] Check AWS credentials
    aws sts get-caller-identity

[ ] Check AWS permissions
    aws iam get-user

[ ] Check default VPC exists
    aws ec2 describe-vpcs --filters "Name=isDefault,Values=true"

[ ] Try plan again
    terraform plan
```

### If docker build fails

```
[ ] Check Docker is running
    docker ps

[ ] Check Dockerfile exists
    test -f ../Dockerfile

[ ] Check Docker daemon
    docker version

[ ] Try rebuilding
    docker build -t test ../
```

### If deploy.sh fails

```
[ ] Check AWS credentials
    aws sts get-caller-identity

[ ] Check AWS region is valid
    AWS_REGION=us-east-1

[ ] Check Docker login
    aws ecr get-login-password | docker login

[ ] Check Dockerfile
    test -f ../Dockerfile

[ ] Try script again with debug
    bash -x ./deploy.sh dev us-east-1
```

### If application not accessible

```
[ ] Wait 1-2 minutes for health checks

[ ] Check ALB is created
    terraform output load_balancer_dns

[ ] Check targets are healthy
    aws elbv2 describe-target-health --target-group-arn <arn>

[ ] Check application logs
    aws logs tail /ecs/demo-web-dev --follow

[ ] Check ECS task is running
    aws ecs list-tasks --cluster demo-web-cluster-dev

[ ] Check security groups
    aws ec2 describe-security-groups | grep demo-web

[ ] Try accessing directly
    curl http://<load-balancer-dns>
```

## Cleanup Checklist (When Done)

```
[ ] Save all important outputs
    terraform output > outputs.txt

[ ] Backup Terraform state
    cp terraform.tfstate terraform.tfstate.backup

[ ] Remove all resources
    terraform destroy

[ ] Confirm destruction
    Type 'yes' when prompted

[ ] Verify resources deleted
    aws ec2 describe-security-groups | grep demo-web
    aws ecs describe-clusters --clusters demo-web-cluster-dev

[ ] Delete local Terraform files (optional)
    rm -rf .terraform terraform.tfstate*
```

## Success Criteria

Deployment is successful when ALL of these are true:

```
[ ] terraform validate passes
[ ] terraform plan shows 18 resources
[ ] terraform apply completes successfully
[ ] ECR repository created with image
[ ] ECS cluster created and running
[ ] ALB created and healthy
[ ] Application accessible via browser
[ ] API endpoint returns JSON
[ ] CloudWatch logs showing output
[ ] All documentation files exist
```

## Important Notes

- Never skip the "Wait for Health Checks" step
- Always verify outputs before proceeding to next step
- Check logs if anything fails
- Save outputs for future reference
- Document any custom configurations
- Keep terraform.tfstate secure
- Don't commit terraform.tfvars to git

## Getting Help

If something fails:

1. Check the relevant documentation
   - terraform/README.md - Common issues section
   - terraform/REFERENCE.md - Debugging section
   - terraform/ARCHITECTURE.md - Troubleshooting

2. Check CloudWatch logs
   - aws logs tail /ecs/demo-web-dev --follow

3. Check AWS resources
   - aws ecs describe-services --cluster demo-web-cluster-dev --services demo-web-service-dev

4. Review the error message carefully
   - Most errors suggest the solution

## Final Verification

Before considering deployment complete:

```
[ ] All prerequisite checks pass
[ ] All deployment steps complete
[ ] All post-deployment checks pass
[ ] Application is accessible
[ ] API endpoints work
[ ] Logs are being captured
[ ] Infrastructure matches expectations
[ ] Documentation is reviewed
[ ] Scaling works (optional)
```

Congratulations! Your Express.js application is now deployed on AWS ECS Fargate!
