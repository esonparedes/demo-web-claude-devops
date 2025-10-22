# Demo: Google-like search UI

Minimal Express app that renders a Google-like homepage and serves a tiny JSON search API for demo/testing.

Quick start

1. Install dependencies

```bash
npm install
```

2. Run app

```bash
npm start
# then open http://localhost:3000
```

Run tests

```bash
npm test
```

Docker

Build image:

```bash
docker build -t demo-web-claude-devops .
```

Run:

```bash
docker run -p 3000:3000 demo-web-claude-devops
```

Security & vulnerabilities

This project uses a minimal set of dependencies and pins versions in package.json. For production use, run `npm audit` and keep dependencies updated.

## Code Quality & CI/CD

### SonarQube Integration

This project includes SonarQube integration for continuous code quality analysis:

- Automated code quality scans on every push and PR
- Quality gate enforcement that **halts builds on quality issues**
- Code coverage tracking
- Security vulnerability detection
- Technical debt monitoring

**Setup Instructions**: See [.github/SONARQUBE_SETUP.md](.github/SONARQUBE_SETUP.md) for complete setup guide.

**Required GitHub Secrets**:
- `SONAR_TOKEN`: Authentication token from SonarQube/SonarCloud
- `SONAR_HOST_URL`: SonarQube server URL (e.g., `https://sonarcloud.io`)

### GitHub Actions Workflows

The project includes several automated workflows:

1. **CI Workflow** (`.github/workflows/ci.yml`)
   - Runs tests and linting
   - Executes SonarQube scans with quality gate checks
   - Builds and validates Docker images
   - Performs security scans with Trivy
   - **Fails if SonarQube quality gate does not pass**

2. **Docker Push** (`.github/workflows/docker-push.yml`)
   - Runs SonarQube quality gate check first
   - Builds and pushes Docker images only if quality gate passes
   - Generates SBOM (Software Bill of Materials)
   - **Blocks deployments if code quality is insufficient**

3. **Release** (`.github/workflows/release.yml`)
   - Creates GitHub releases for version tags
   - Generates changelog

4. **Health Check** (`.github/workflows/health-check.yml`)
   - Daily smoke tests
   - Validates application and container health

## AWS Deployment (Terraform)

Deploy this application to AWS ECS with Fargate using the included Terraform infrastructure:

### Quick Deploy

```bash
# Test locally first
./scripts/test-local.sh

# Deploy to AWS (dev environment)
cd terraform
terraform init
terraform apply -var-file="environments/dev/dev.tfvars"

# Build and push Docker image
cd ..
./scripts/build-and-push.sh dev latest
```

### Documentation

- **[Deployment Guide](DEPLOYMENT.md)**: Step-by-step deployment instructions
- **[Architecture Documentation](ARCHITECTURE.md)**: Detailed architecture and design
- **[Terraform README](terraform/README.md)**: Complete Terraform documentation
- **[Summary](TERRAFORM_SUMMARY.md)**: Quick overview of infrastructure

### Infrastructure Includes

- VPC with multi-AZ public and private subnets
- Application Load Balancer for traffic distribution
- ECS Fargate cluster for serverless containers
- ECR repository for Docker images
- Auto-scaling based on CPU, memory, and requests
- CloudWatch logging and monitoring
- Security groups and IAM roles
- VPC Flow Logs for security

### Estimated Costs

- Development: ~$95-130/month
- Staging: ~$130-180/month
- Production: ~$280-500/month

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed cost breakdown and optimization tips.

## Claude Code

Claude Code is an agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster by executing routine tasks, explaining complex code, and handling git workflows -- all through natural language commands.

Install Claude Code CLI:

```bash
npm install -g @anthropic-ai/claude-code
```

Run in the current directory:
```bash
claude
```
