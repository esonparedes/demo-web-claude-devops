# Terraform Files Overview

This guide explains each file in the terraform directory and what it does.

## File Structure

```
terraform/
├── README.md                    # Comprehensive deployment guide
├── QUICKSTART.md               # 10-minute quick start
├── ARCHITECTURE.md             # System architecture & design
├── FILES_OVERVIEW.md           # This file
│
├── providers.tf                # AWS provider configuration
├── main.tf                     # Core infrastructure resources
├── variables.tf                # Input variables & validation
├── outputs.tf                  # Output values (URLs, ARNs, etc.)
├── terraform.tfvars            # Your variable values (DO NOT COMMIT)
├── terraform.tfvars.example    # Example variables (safe to commit)
│
├── deploy.sh                   # Script to build & push Docker image
├── .gitignore                  # Files to ignore in version control
├── .terraform/                 # (Auto-created) Terraform provider files
└── .terraform.lock.hcl         # (Auto-created) Provider version lock file
```

## Core Terraform Files

### 1. providers.tf

**Purpose**: Configure the AWS provider

**What it does**:
- Specifies AWS provider version constraints (~> 5.0)
- Sets the AWS region (default: us-east-1)
- Defines default tags for all resources

**Key Points**:
- Required for any Terraform AWS configuration
- Minimal configuration - just points to AWS
- All resources automatically tagged with Environment and Project

**Example**:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allows 5.0 - 5.999
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {  # All resources get these tags
    tags = {
      Environment = var.environment
      Project     = var.project_name
    }
  }
}
```

### 2. variables.tf

**Purpose**: Define input variables with validation

**What it does**:
- Declares all configurable parameters
- Validates input values
- Provides descriptions for each variable
- Sets sensible defaults

**Variable Categories**:

1. **AWS Configuration**
   - `aws_region`: Where to deploy (default: us-east-1)

2. **Project Naming**
   - `project_name`: Used in all resource names (default: demo-web)
   - `environment`: dev/staging/prod (default: dev)

3. **Application Settings**
   - `app_port`: Container port (default: 3000)
   - `container_image`: Docker image URI (leave empty for ECR default)

4. **Resource Sizing**
   - `container_cpu`: CPU units (default: 256)
   - `container_memory`: Memory in MB (default: 512)
   - `desired_count`: Number of running tasks (default: 1)

5. **Logging**
   - `enable_logging`: CloudWatch logs enabled (default: true)
   - `log_retention_days`: Days to keep logs (default: 7)

**Validation Examples**:
```hcl
# Project name must be lowercase with hyphens only
validation {
  condition     = can(regex("^[a-z0-9-]+$", var.project_name))
  error_message = "Project name must be lowercase alphanumeric with hyphens only."
}

# Memory must be valid Fargate value
validation {
  condition = contains([512, 1024, 2048, 3072, 4096], var.container_memory)
  error_message = "Memory must be a valid Fargate memory value."
}
```

### 3. main.tf

**Purpose**: Define all infrastructure resources (18 total)

**Resources Created**:

1. **Data Sources** (reference existing AWS resources)
   - Default VPC: `data.aws_vpc.default`
   - Default Subnets: `data.aws_subnets.default`

2. **Container Registry** (ECR)
   - `aws_ecr_repository.app`: Docker image repository
   - `aws_ecr_lifecycle_policy.app`: Auto-cleanup old images

3. **Logging**
   - `aws_cloudwatch_log_group.ecs`: Container logs

4. **Identity & Access Management** (IAM)
   - `aws_iam_role.ecs_task_execution_role`: ECS task execution
   - `aws_iam_role_policy_attachment`: Attach policies to role
   - `aws_iam_role_policy.ecs_task_execution_logs`: CloudWatch permissions
   - `aws_iam_role.ecs_task_role`: Application permissions

5. **Container Orchestration** (ECS)
   - `aws_ecs_cluster.app`: Container cluster
   - `aws_ecs_cluster_capacity_providers.app`: Enable Fargate
   - `aws_ecs_task_definition.app`: Define container configuration
   - `aws_ecs_service.app`: Manage running tasks

6. **Networking** (Security Groups)
   - `aws_security_group.alb`: ALB traffic rules
   - `aws_security_group.ecs_tasks`: ECS task traffic rules

7. **Load Balancing** (ALB)
   - `aws_lb.app`: Application Load Balancer
   - `aws_lb_target_group.app`: Task targeting
   - `aws_lb_listener.app`: Port 80 listener

**Why This Design?**:
- Minimal yet complete
- Uses default VPC for simplicity
- All resources properly networked and secured
- Follows AWS best practices

### 4. outputs.tf

**Purpose**: Expose useful information after deployment

**Outputs Provided**:

1. **ECR Information**
   - `ecr_repository_url`: Image URL for pushing
   - `ecr_repository_arn`: ARN for reference

2. **Load Balancer**
   - `load_balancer_dns`: Public DNS name
   - `load_balancer_arn`: ARN for reference
   - `load_balancer_url`: Full HTTP URL

3. **ECS Service**
   - `ecs_cluster_name`: Cluster name
   - `ecs_service_name`: Service name
   - `ecs_task_definition_arn`: Task definition ARN

4. **Deployment Summary**
   - `deployment_info`: All critical values in one place

**Example Output**:
```bash
$ terraform output deployment_info

{
  "alb_dns_name" = "demo-web-alb-dev-123456.us-east-1.elb.amazonaws.com"
  "app_url" = "http://demo-web-alb-dev-123456.us-east-1.elb.amazonaws.com"
  "cluster_name" = "demo-web-cluster-dev"
  "repository_url" = "123456789012.dkr.ecr.us-east-1.amazonaws.com/demo-web-dev"
  "service_name" = "demo-web-service-dev"
}
```

### 5. terraform.tfvars

**Purpose**: Set variable values (DO NOT COMMIT THIS FILE)

**What it contains**:
- Your actual configuration values
- AWS region, environment, scaling settings
- Should be in .gitignore (secret values stored here)

**Example**:
```hcl
aws_region       = "us-east-1"
project_name     = "demo-web"
environment      = "dev"
container_cpu    = 256
container_memory = 512
desired_count    = 1
```

**Security Note**:
- Never commit this file to version control
- It's in .gitignore for your protection
- Always use `terraform.tfvars` locally
- In CI/CD, pass values via `-var` flags

### 6. terraform.tfvars.example

**Purpose**: Template for creating terraform.tfvars

**What it contains**:
- Example values showing all available options
- Safe to commit (no secrets)
- Helps new team members understand configuration

**Usage**:
```bash
# Copy example to create your own
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vi terraform.tfvars
```

## Scripts

### deploy.sh

**Purpose**: Build Docker image and push to ECR

**What it does**:
1. Validates prerequisites (Dockerfile, AWS credentials)
2. Gets your AWS Account ID
3. Creates ECR repository (if needed)
4. Logs in to ECR
5. Builds Docker image
6. Tags with `:latest` and timestamp
7. Pushes both tags to ECR
8. Displays image URI for next steps

**Usage**:
```bash
chmod +x deploy.sh
./deploy.sh dev us-east-1
```

**Output Example**:
```
=== Docker Build and ECR Push Script ===
Project: demo-web
Environment: dev
AWS Region: us-east-1

Getting AWS Account ID...
Account ID: 123456789012
Checking ECR repository...
ECR repository does not exist. Creating...
...
ECR Repository: demo-web-dev
ECR URI: 123456789012.dkr.ecr.us-east-1.amazonaws.com/demo-web-dev:latest
```

## Version Control Files

### .gitignore

**Purpose**: Prevent committing sensitive files

**What it ignores**:
- `*.tfstate`: Terraform state (contains sensitive data)
- `*.tfvars`: Variable files (contains secrets)
- `.terraform/`: Provider directories (regenerated by init)
- `*.log`: Log files
- IDE files: `.vscode/`, `.idea/`, etc.

**Why?**:
- State files contain resource IDs and sensitive data
- Variable files may contain passwords/secrets
- Terraform will regenerate these automatically

## Auto-Generated Files

### .terraform/ (directory)

**Purpose**: Provider plugins and modules cache

**Created by**: `terraform init`

**Content**:
- AWS provider binary
- Version information
- Lock files

**Action**: Don't commit, don't delete locally

### .terraform.lock.hcl

**Purpose**: Lock provider versions for reproducibility

**Created by**: `terraform init`

**Importance**: COMMIT THIS FILE
- Ensures all team members use same provider version
- Prevents unexpected behavior from provider updates

**Why commit it?**:
- Different versions might behave differently
- Locked version ensures reproducibility
- Team consistency

## Workflow Summary

```
1. Variables Flow:
   terraform.tfvars.example (read-only template)
         ↓
   terraform.tfvars (your values - ignored by git)
         ↓
   variables.tf (constraints & descriptions)
         ↓
   Used in main.tf for resource configuration

2. Resource Flow:
   main.tf (define resources)
         ↓
   terraform plan (show what will change)
         ↓
   terraform apply (create resources)
         ↓
   outputs.tf (display useful info)

3. Image Flow:
   deploy.sh (build & push image)
         ↓
   ECR repository (store image)
         ↓
   Task definition (reference image)
         ↓
   ECS service (run containers)
```

## When to Edit Each File

### Never Edit (Auto-generated)
- `.terraform/` directory
- `terraform.tfstate*`
- `.terraform.lock.hcl` (but DO commit)

### Rarely Edit (Architecture)
- `providers.tf`: Change provider version constraints
- `main.tf`: Only to add/remove resources
- `outputs.tf`: Only to add/remove outputs

### Sometimes Edit (Configuration)
- `variables.tf`: Add new input variables
- `terraform.tfvars`: Adjust for your deployment
- `deploy.sh`: Modify build process

### View Only (Documentation)
- `README.md`, `QUICKSTART.md`, `ARCHITECTURE.md`, `FILES_OVERVIEW.md`

## Configuration Variations

### Different Environments

**For staging**:
```bash
# Copy and modify
cp terraform.tfvars terraform.tfvars.staging
vi terraform.tfvars.staging  # Set environment=staging

# Use different tfvars
terraform apply -var-file=terraform.tfvars.staging
```

**For production**:
```bash
# Production best practices
- Use HTTPS (ALB with ACM certificate)
- Enable auto-scaling
- Use RDS database
- Enable enhanced monitoring
- Configure backups
```

### Multiple Regions

**Deploy to multiple regions**:
```bash
# Create region-specific configs
terraform workspace new us-west-1
terraform apply -var='aws_region=us-west-1'

terraform workspace new eu-west-1
terraform apply -var='aws_region=eu-west-1'
```

### Custom Infrastructure

**Extend with new resources** (edit main.tf):
```hcl
# Example: Add RDS database
resource "aws_db_instance" "postgres" {
  # ... configuration
}

# Add ECR push notification
resource "aws_ecr_notification" "image_push" {
  # ... configuration
}
```

## Key Takeaways

1. **providers.tf**: AWS configuration (rarely changes)
2. **main.tf**: Resources definition (architecture)
3. **variables.tf**: Input parameters (infrastructure tuning)
4. **outputs.tf**: Results display (for your reference)
5. **terraform.tfvars**: Your actual values (keep secret)
6. **deploy.sh**: Automates Docker build & push
7. **.gitignore**: Protects secrets (critical!)
8. **.terraform.lock.hcl**: Version consistency (commit it!)

## Files by Size

| File | Lines | Complexity | Purpose |
|------|-------|-----------|---------|
| main.tf | ~300 | High | All resources |
| README.md | ~400 | Low | Documentation |
| variables.tf | ~70 | Medium | Input validation |
| ARCHITECTURE.md | ~300 | Low | Design docs |
| outputs.tf | ~30 | Low | Results display |
| providers.tf | ~25 | Low | AWS setup |
| deploy.sh | ~100 | Medium | Build automation |
| QUICKSTART.md | ~350 | Low | Getting started |
| terraform.tfvars | ~10 | Low | Configuration |

## Next Steps

1. Read QUICKSTART.md for 10-minute deployment
2. Review ARCHITECTURE.md to understand design
3. Edit terraform.tfvars for your environment
4. Run `terraform plan` to preview changes
5. Run `./deploy.sh` to build Docker image
6. Run `terraform apply` to deploy
