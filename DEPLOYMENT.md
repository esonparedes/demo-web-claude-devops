# Deployment Guide - Express.js to AWS ECS Fargate

This project now includes a complete Terraform configuration to deploy the Express.js application to AWS ECS Fargate with an Application Load Balancer.

## Quick Links

- **Quick Start**: See `terraform/QUICKSTART.md` - Deploy in 10 minutes
- **Full Guide**: See `terraform/README.md` - Comprehensive documentation
- **Architecture**: See `terraform/ARCHITECTURE.md` - System design and flow
- **File Overview**: See `terraform/FILES_OVERVIEW.md` - Understanding each file

## What Gets Deployed

### Services

1. **ECR (Elastic Container Registry)**
   - Stores your Docker images
   - Automatic image scanning
   - Lifecycle policy to keep last 10 images

2. **ECS Fargate Cluster**
   - Serverless container orchestration (no EC2 management)
   - Configurable task count (1-10)
   - Configurable CPU and memory (256-4096 CPU, 512-8192 MB)

3. **Application Load Balancer (ALB)**
   - Public-facing HTTP endpoint
   - Automatic health checks
   - Distributes traffic across tasks

4. **CloudWatch Logs**
   - Centralized application logging
   - 7-day retention (configurable)
   - Real-time log streaming

5. **IAM Roles & Policies**
   - Task execution role (for ECS management)
   - Task role (for application permissions)
   - Follows principle of least privilege

6. **Security Groups**
   - ALB accepts HTTP from anywhere
   - ECS tasks only accept port 3000 from ALB
   - Proper network isolation

## Prerequisites

Ensure you have:

1. **AWS Account**
   ```bash
   aws sts get-caller-identity
   ```

2. **AWS Credentials Configured**
   ```bash
   aws configure
   ```

3. **Terraform Installed** (1.0+)
   ```bash
   terraform version
   ```

4. **Docker Installed and Running**
   ```bash
   docker --version
   docker ps
   ```

5. **AWS CLI Installed**
   ```bash
   aws --version
   ```

## Directory Structure

```
demo-web-claude-devops/
├── server.js                   # Express.js application
├── Dockerfile                  # Container image definition
├── package.json               # Node.js dependencies
├── views/                     # EJS templates
├── public/                    # Static files (CSS, etc.)
├── tests/                     # Jest test files
│
└── terraform/                 # Terraform configuration
    ├── README.md              # Full deployment guide
    ├── QUICKSTART.md          # 10-minute quick start
    ├── ARCHITECTURE.md        # System design and flow
    ├── FILES_OVERVIEW.md      # Understanding each file
    │
    ├── providers.tf           # AWS provider config
    ├── main.tf                # Infrastructure resources (18 total)
    ├── variables.tf           # Input variables
    ├── outputs.tf             # Output values
    │
    ├── terraform.tfvars       # Your configuration (DO NOT COMMIT)
    ├── terraform.tfvars.example # Template for tfvars
    │
    ├── deploy.sh              # Docker build & push script
    └── .gitignore             # Git ignore rules
```

## Deployment Steps Summary

### 1. Initialize (1 minute)
```bash
cd terraform
terraform init
```

### 2. Validate (30 seconds)
```bash
terraform validate
terraform fmt
```

### 3. Configure (1 minute)
```bash
cp terraform.tfvars.example terraform.tfvars
# Optionally edit terraform.tfvars for your environment
```

### 4. Preview (1-2 minutes)
```bash
terraform plan
```

### 5. Build & Push Image (2-3 minutes)
```bash
chmod +x deploy.sh
./deploy.sh dev us-east-1
```

### 6. Deploy (3-5 minutes)
```bash
terraform apply
```

### 7. Access (30 seconds)
```bash
terraform output load_balancer_url
# Visit URL in browser or curl
```

## Key Configurations

### Container Settings
- Port: 3000 (matches Dockerfile)
- CPU: 256 CPU units (0.25 vCPU)
- Memory: 512 MB
- Task count: 1 (configurable 1-10)

### Networking
- VPC: Default VPC (simplified)
- Subnets: Default subnets
- ALB: Public-facing on port 80
- Tasks: Private on port 3000

### Monitoring
- CloudWatch Logs: Enabled
- Log retention: 7 days
- Log group: `/ecs/demo-web-dev`
- Image scanning: Enabled

### Security
- ALB Security Group: HTTP from anywhere (0.0.0.0/0)
- ECS Security Group: Port 3000 from ALB only
- IAM Roles: Minimal permissions (principle of least privilege)

## Environment Variables

### Available in Terraform

```hcl
aws_region          = "us-east-1"      # AWS region
project_name        = "demo-web"       # Project name
environment         = "dev"            # dev/staging/prod
app_port           = 3000             # Container port
container_cpu      = 256              # CPU units
container_memory   = 512              # Memory in MB
desired_count      = 1                # Number of tasks
enable_logging     = true             # CloudWatch logs
log_retention_days = 7                # Log retention
```

### Available in Container

```bash
NODE_ENV=dev                          # Environment
PORT=3000                             # Application port
```

## Cost Estimate

Monthly costs (approximate, varies by region):

- ECS Fargate (1 task, 256 CPU, 512 MB): $7.50
- Application Load Balancer: $16.20
- ALB Data Processing (10 GB/month): $0.10
- ECR Storage (100 MB): $0.10
- CloudWatch Logs (1 GB/month): $0.50
- **Total**: ~$24.40/month

### Cost Reduction Options
- Scale down task count
- Use smaller CPU/memory allocations
- Deploy to cheaper region (us-west, eu-west)
- Use FARGATE_SPOT instead of FARGATE

## Common Tasks

### Update Application Code

```bash
# 1. Modify code (server.js, views/, etc.)
vim ../server.js

# 2. Rebuild image
./deploy.sh dev us-east-1

# 3. Redeploy
terraform apply
```

### Scale Application

```bash
# Scale to 3 tasks
terraform apply -var='desired_count=3'

# Scale to 1 task
terraform apply -var='desired_count=1'
```

### View Logs

```bash
# View recent logs
aws logs tail /ecs/demo-web-dev --follow

# View logs for specific time
aws logs filter-log-events \
  --log-group-name /ecs/demo-web-dev
```

### Monitor Service

```bash
# Check service status
aws ecs describe-services \
  --cluster demo-web-cluster-dev \
  --services demo-web-service-dev

# List running tasks
aws ecs list-tasks --cluster demo-web-cluster-dev

# Check target health
terraform output deployment_info
```

### Clean Up

```bash
# Delete all AWS resources (cannot be undone!)
terraform destroy

# Confirm by typing 'yes'
```

## Troubleshooting

### Terraform Errors

**Problem**: `terraform init` fails
- Check AWS credentials: `aws sts get-caller-identity`
- Check internet connection
- Try reinitializing: `terraform init -upgrade`

**Problem**: `terraform plan` shows permission error
- Verify AWS credentials have ECS/EC2/IAM permissions
- Check if credentials are expired
- Reconfigure AWS CLI: `aws configure`

### Deployment Errors

**Problem**: Application not accessible after deployment
- Wait 1-2 minutes for health checks
- Check target health: `aws elbv2 describe-target-health ...`
- View logs: `aws logs tail /ecs/demo-web-dev --follow`
- Verify port 3000 in security groups

**Problem**: ECS tasks won't start
- Check CloudWatch logs for startup errors
- Verify Docker image exists in ECR
- Check task execution role permissions
- Increase log retention to see more details

**Problem**: Docker build fails
- Check Docker is running: `docker ps`
- Check Dockerfile exists: `ls ../Dockerfile`
- Check Docker daemon: `docker version`
- Verify AWS ECR login in deploy.sh

### Scaling Issues

**Problem**: Scaling doesn't work
- Verify ALB target group health checks
- Check ECS cluster has capacity
- Review CPU/memory allocation
- Check IAM role has ecs:UpdateService permission

## Production Considerations

1. **HTTPS/SSL**
   - Add ACM certificate to ALB
   - Redirect HTTP to HTTPS

2. **Auto-scaling**
   - Add target tracking policies
   - Scale based on CPU/memory metrics

3. **Database**
   - Add RDS for persistent data
   - Configure connection pooling

4. **Monitoring**
   - Set up CloudWatch alarms
   - Create dashboards
   - Log aggregation

5. **Backup & Recovery**
   - Implement RDS snapshots
   - Test disaster recovery
   - Document runbooks

6. **Security**
   - Use AWS Secrets Manager for credentials
   - Enable CloudTrail for audit logs
   - Implement VPC security best practices
   - Use private subnets where possible

7. **Cost Management**
   - Use Reserved Instances or Savings Plans
   - Set up budget alerts
   - Implement auto-scaling to right-size
   - Use Spot instances for non-critical workloads

## Support & Resources

### Terraform Documentation
- https://www.terraform.io/docs
- https://registry.terraform.io/providers/hashicorp/aws/latest

### AWS Documentation
- ECS: https://docs.aws.amazon.com/ecs/
- Fargate: https://docs.aws.amazon.com/fargate/
- ALB: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/
- ECR: https://docs.aws.amazon.com/ecr/

### AWS CLI Examples
- https://docs.aws.amazon.com/cli/latest/reference/

### Project Documentation
- See `terraform/README.md` for comprehensive guide
- See `terraform/QUICKSTART.md` for quick start
- See `terraform/ARCHITECTURE.md` for design details
- See `terraform/FILES_OVERVIEW.md` for file descriptions

## Next Steps

1. Follow the Quick Start: `terraform/QUICKSTART.md`
2. Read the full guide: `terraform/README.md`
3. Review architecture: `terraform/ARCHITECTURE.md`
4. Deploy to AWS
5. Monitor and scale as needed
6. Plan for production improvements

## Project Files Summary

### Application Files (Already Exist)
- `server.js` - Express.js application
- `Dockerfile` - Container image definition
- `package.json` - Dependencies
- `views/index.ejs` - Search UI template
- `public/styles.css` - Styling
- `tests/` - Test suite

### Terraform Files (New - In terraform/ directory)
- `providers.tf` - AWS provider setup
- `main.tf` - 18 infrastructure resources
- `variables.tf` - Input parameters with validation
- `outputs.tf` - Deployment information
- `terraform.tfvars` - Your configuration (secret - don't commit)
- `terraform.tfvars.example` - Configuration template
- `deploy.sh` - Docker build and ECR push script
- `.gitignore` - Ignore rules for sensitive files
- `README.md` - Full deployment documentation
- `QUICKSTART.md` - 10-minute quick start
- `ARCHITECTURE.md` - System design documentation
- `FILES_OVERVIEW.md` - Understanding each file

### This File
- `DEPLOYMENT.md` - This file (overview of deployment)

## Success Indicators

Deployment is successful when:

1. `terraform plan` shows 18 resources to create
2. `./deploy.sh` completes with ECR repository URL
3. `terraform apply` completes without errors
4. `terraform output` shows load_balancer_url
5. Health checks show targets as "Healthy"
6. Browser access to ALB URL shows the Google-like search interface
7. API endpoint returns search results: `curl http://<alb-dns>/api/search?q=test`
8. Application logs appear in CloudWatch

## Congratulations!

Your Express.js application is now ready to be deployed to AWS ECS Fargate. Follow the Quick Start guide in `terraform/QUICKSTART.md` to deploy in about 10 minutes.

---

Created: October 17, 2025
Terraform Version: 1.0+
AWS Provider Version: ~> 5.0
