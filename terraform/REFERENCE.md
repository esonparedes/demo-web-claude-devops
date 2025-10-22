# Terraform Reference Card

Quick reference for common commands and configurations.

## Essential Commands

### Setup & Validation

```bash
# Initialize Terraform (run once)
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Format all files recursively
terraform fmt -recursive
```

### Planning & Deployment

```bash
# Preview changes (no modifications)
terraform plan

# Save plan to file
terraform plan -out=tfplan

# Apply saved plan
terraform apply tfplan

# Apply with variable override
terraform apply -var='desired_count=3'

# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=aws_ecs_service.app
```

### State Management

```bash
# List all resources in state
terraform state list

# Show specific resource details
terraform state show aws_ecs_cluster.app

# Refresh state from AWS (sync)
terraform refresh

# Show state in JSON format
terraform show -json > state.json
```

### Information & Debugging

```bash
# Show all outputs
terraform output

# Show specific output
terraform output load_balancer_url

# Show in JSON format
terraform output -json

# Generate dependency graph
terraform graph

# Validate JSON syntax
terraform validate

# Get provider version
terraform version
```

### Workspaces (for multiple environments)

```bash
# List workspaces
terraform workspace list

# Create new workspace
terraform workspace new staging

# Switch workspace
terraform workspace select staging

# Delete workspace
terraform workspace delete dev
```

## Variables

### Using terraform.tfvars

```bash
# Create from example
cp terraform.tfvars.example terraform.tfvars

# Edit your configuration
vi terraform.tfvars
```

### Command-line Overrides

```bash
# Override single variable
terraform apply -var='desired_count=3'

# Override multiple variables
terraform apply \
  -var='environment=prod' \
  -var='desired_count=5' \
  -var='container_cpu=512'

# Use variables file
terraform apply -var-file='prod.tfvars'

# Use environment variable
export TF_VAR_desired_count=3
terraform apply
```

### Variable File Format

```hcl
# terraform.tfvars example
aws_region          = "us-east-1"
project_name        = "demo-web"
environment         = "dev"
app_port           = 3000
container_cpu      = 256
container_memory   = 512
desired_count      = 1
enable_logging     = true
log_retention_days = 7
```

## Configuration Examples

### Development Environment

```hcl
aws_region          = "us-east-1"
project_name        = "demo-web"
environment         = "dev"
container_cpu       = 256       # Small
container_memory    = 512       # Small
desired_count       = 1
enable_logging      = true
```

### Staging Environment

```hcl
aws_region          = "us-east-1"
project_name        = "demo-web"
environment         = "staging"
container_cpu       = 512       # Medium
container_memory    = 1024      # Medium
desired_count       = 2         # Some redundancy
enable_logging      = true
```

### Production Environment

```hcl
aws_region          = "us-east-1"
project_name        = "demo-web"
environment         = "prod"
container_cpu       = 1024      # Large
container_memory    = 2048      # Large
desired_count       = 3         # High availability
enable_logging      = true
log_retention_days  = 30        # Longer retention
```

## Fargate CPU & Memory Combinations

Valid CPU and Memory combinations for Fargate:

| CPU | Memory Options (MB) |
|-----|-------------------|
| 256 | 512, 1024, 2048 |
| 512 | 1024, 2048, 3072, 4096 |
| 1024 | 2048, 3072, 4096, 5120, 6144, 7168, 8192 |
| 2048 | 4096-16384 (1 GB increments) |
| 4096 | 8192-30720 (1 GB increments) |

## AWS CLI Integration

### View Deployed Resources

```bash
# Get cluster name
CLUSTER=$(terraform output -raw ecs_cluster_name)

# Get service name
SERVICE=$(terraform output -raw ecs_service_name)

# Get load balancer URL
ALB_URL=$(terraform output -raw load_balancer_url)
```

### ECS Commands

```bash
# List tasks
aws ecs list-tasks --cluster $CLUSTER

# Describe service
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE

# Describe task definition
aws ecs describe-task-definition \
  --task-definition demo-web-task-dev

# Force service update
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment

# View task logs
aws logs tail /ecs/demo-web-dev --follow

# Get last 10 log entries
aws logs tail /ecs/demo-web-dev --max-items 10
```

### ECR Commands

```bash
# List repositories
aws ecr describe-repositories

# List images in repo
aws ecr describe-images --repository-name demo-web-dev

# Push image
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/demo-web-dev:latest

# Pull image
docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/demo-web-dev:latest
```

### ALB Commands

```bash
# Describe load balancers
aws elbv2 describe-load-balancers

# Describe target groups
aws elbv2 describe-target-groups

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...
```

## Data Sources (Read-Only)

```hcl
# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get specific AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}
```

## Lifecycle Rules

```hcl
# Control resource replacement
resource "aws_ecs_task_definition" "app" {
  # ... config ...

  lifecycle {
    create_before_destroy = true  # Create new before destroying old
    ignore_changes = [container_definitions]  # Don't update this
    prevent_destroy = true        # Prevent accidental deletion
  }
}
```

## Conditionals

```hcl
# Conditional resource creation
resource "aws_cloudwatch_log_group" "ecs" {
  count = var.enable_logging ? 1 : 0
  # ... config ...
}

# Use in other resources
log_group_name = var.enable_logging ? aws_cloudwatch_log_group.ecs[0].name : ""

# Conditional variable value
some_value = var.environment == "prod" ? "prod-value" : "dev-value"
```

## Common Patterns

### Tag All Resources

```hcl
# In providers.tf
provider "aws" {
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      CreatedBy   = "Terraform"
      Date        = timestamp()
    }
  }
}

# Access in resource
tags = {
  Name = "${var.project_name}-resource"
}
# Note: tags_all includes both resource tags and default tags
```

### String Interpolation

```hcl
# Concatenate strings
name = "${var.project_name}-${var.environment}"
# Result: demo-web-dev

# Use in URL
repository_url = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/..."

# Multi-line
name = join("-", [var.project_name, var.environment, "cluster"])
# Result: demo-web-dev-cluster
```

### JSON Encoding

```hcl
# Convert HCL to JSON for APIs
policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Allow"
      Action = ["ecs:*"]
      Resource = "*"
    }
  ]
})
```

### For Each Loops

```hcl
# Create multiple resources
resource "aws_security_group" "app" {
  for_each = toset(["alb", "ecs"])

  name = "${each.value}-sg"
  # ...
}

# Reference: aws_security_group.app["alb"].id
```

## Debugging

### Enable Debug Logging

```bash
# Show detailed logs
TF_LOG=DEBUG terraform plan > plan.log 2>&1

# Levels: TRACE, DEBUG, INFO, WARN, ERROR
export TF_LOG=DEBUG

# Save to file
export TF_LOG_PATH=terraform.log
```

### Common Issues

```bash
# Too many resources?
# Use -target for specific resources during development
terraform plan -target=aws_ecs_cluster.app

# Stuck in loop?
# Check for circular dependencies
terraform graph | grep -E "->.*<-"

# State corruption?
# Backup state and refresh
cp terraform.tfstate terraform.tfstate.backup
terraform refresh
```

## Performance Tips

### Speed Up Planning

```bash
# Use parallelism
terraform plan -parallelism=10

# Skip refresh (use cached state)
terraform plan -refresh=false
```

### Reduce State Size

```bash
# Remove unneeded data sources
terraform state rm data.aws_availability_zones.available
```

## Security Best Practices

### Never Commit Secrets

```bash
# .gitignore
*.tfvars          # Variable files
terraform.tfstate*  # State files
```

### Use Remote State

```bash
# terraform cloud (main.tf)
terraform {
  cloud {
    organization = "my-org"
    workspaces {
      name = "my-app-dev"
    }
  }
}
```

### Rotate Credentials

```bash
# For destroyed/recreated resources
terraform taint aws_ecs_task_definition.app
terraform apply  # Forces recreation
```

## Useful Tools

### Terraform Linting

```bash
# Install tflint
brew install tflint

# Check your code
tflint terraform/
```

### Terraform Formatting

```bash
# Install terraform-docs
brew install terraform-docs

# Generate documentation
terraform-docs markdown terraform/ > terraform/DOCS.md
```

### Visualization

```bash
# Generate graph
terraform graph | dot -Tsvg > graph.svg
open graph.svg
```

## Cost Estimation

### Estimate Costs

```bash
# Use Infracost (free)
brew install infracost

# Estimate plan
infracost breakdown --path terraform/
```

### By Service

| Service | Usage | Estimated Cost |
|---------|-------|-----------------|
| ECS Fargate | 256 CPU, 512 MB, 730 hrs | $7.50 |
| ALB | Per ALB, 730 hrs | $16.20 |
| ALB LCU | Per LCU, 730 hrs | $6-10 |
| ECR | 100 MB storage | $0.10 |
| CloudWatch | 1 GB logs | $0.50 |

## Quick Deployment Checklist

```bash
# 1. Initialize
terraform init

# 2. Validate
terraform validate

# 3. Review variables
cat terraform.tfvars

# 4. Preview
terraform plan

# 5. Build image
./deploy.sh dev us-east-1

# 6. Deploy
terraform apply

# 7. Verify
terraform output load_balancer_url
curl $(terraform output -raw load_balancer_url)

# 8. Monitor
aws logs tail /ecs/demo-web-dev --follow
```

## Common Errors & Fixes

| Error | Cause | Solution |
|-------|-------|----------|
| `Error: no AWS credentials` | Missing credentials | Run `aws configure` |
| `Invalid or unknown key` | Typo in variable | Check variable names |
| `Resource already exists` | Name collision | Change project_name |
| `Unhealthy targets` | App not listening | Check logs, port 3000 |
| `Too many open files` | Resource limit | Increase system limit |

## Resources

- Terraform Docs: https://www.terraform.io/docs
- AWS Docs: https://docs.aws.amazon.com
- Terraform Registry: https://registry.terraform.io
- AWS CLI Docs: https://docs.aws.amazon.com/cli
- Terraform Best Practices: https://www.terraform.io/docs/glossary

---

For more help:
- See `README.md` for comprehensive guide
- See `QUICKSTART.md` for quick start
- See `ARCHITECTURE.md` for design details
- See `FILES_OVERVIEW.md` for file descriptions
