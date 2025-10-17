# GitHub Actions CI/CD Pipeline Documentation

This directory contains production-grade GitHub Actions workflows for the Express.js application with AWS ECS deployment integration.

## What's Included

### Workflow Files

1. **ci.yml** - Continuous Integration
   - Runs on: Push to main, Pull requests to main, Manual dispatch
   - Tests on Node.js 18.x and 20.x
   - Validates Docker image can be built
   - Uploads code coverage to Codecov
   - Duration: ~2-5 minutes

2. **cd.yml** - Continuous Deployment
   - Runs on: Push to main only, Manual dispatch
   - Builds Docker image with multi-layer caching
   - Pushes to AWS ECR with SHA and 'latest' tags
   - Updates ECS task definition
   - Deploys to ECS service with stability checks
   - Duration: ~5-15 minutes (includes ECS stabilization)

3. **security.yml** - Security Scans (Optional)
   - Runs on: Push to main, Pull requests to main, Daily schedule
   - npm audit for vulnerable dependencies
   - Trivy vulnerability scanning of Docker image
   - CodeQL static code analysis
   - Reports to GitHub Security tab

### Documentation Files

1. **QUICK_START.md** - Get up and running in 10 minutes
   - Minimal setup steps
   - Prerequisites checklist
   - Common commands
   - Quick troubleshooting

2. **WORKFLOWS_SETUP.md** - Complete setup and configuration guide
   - Detailed prerequisites
   - AWS IAM policy and user setup
   - GitHub secrets configuration
   - Branch protection rules
   - Testing procedures
   - Troubleshooting guide
   - Performance optimization tips
   - Rollback procedures

3. **ADVANCED_WORKFLOWS.md** - Optional enhancements
   - Manual approval workflows
   - Multi-environment deployments
   - Automated dependency updates with Dependabot
   - Performance monitoring
   - Cost optimization strategies
   - Advanced Docker techniques
   - Image signing and SBOM generation
   - Slack/Teams notifications

4. **ECS_TASK_DEFINITION_EXAMPLE.json** - Reference task definition
   - Fargate-compatible configuration
   - Health checks configured
   - CloudWatch logging setup
   - Port mapping for Express.js (3000)

## Quick Start

For fastest setup, follow these steps:

### 1. Create AWS Resources (5 minutes)

```bash
# Create IAM user for GitHub Actions
aws iam create-user --user-name github-actions-user

# Note: You'll need to add the IAM policy from WORKFLOWS_SETUP.md
# and create access keys for the next step
```

### 2. Add GitHub Secrets (3 minutes)

Go to **Settings > Secrets and variables > Actions** and add:

```
AWS_ACCESS_KEY_ID              # Your IAM user access key
AWS_SECRET_ACCESS_KEY          # Your IAM user secret key
AWS_REGION                     # e.g., us-east-1
ECR_REPOSITORY                 # e.g., demo-web-claude-devops
ECS_CLUSTER                    # Your ECS cluster name
ECS_SERVICE                    # Your ECS service name
ECS_TASK_DEFINITION            # Your task definition family
CONTAINER_NAME                 # Container name in task definition
```

### 3. Test the Pipeline (2 minutes)

```bash
git checkout -b test/workflows
echo "# Test" >> README.md
git add README.md
git commit -m "test: verify workflows"
git push origin test/workflows
```

Then open a PR and watch the CI workflow run.

### 4. Deploy (1 minute)

Merge the PR to main and watch the CD workflow deploy your application.

**See QUICK_START.md for detailed steps.**

## Workflow Features

### CI Workflow Benefits

- **Multi-version testing**: Tests on both Node 18 and 20 for compatibility
- **Dependency caching**: Speeds up subsequent runs by ~60%
- **Early validation**: Catches issues before deployment
- **Code coverage**: Tracks test coverage over time
- **Docker validation**: Ensures image builds correctly

### CD Workflow Benefits

- **Automated deployment**: One-click deployments after merge
- **Layer caching**: Docker builds use cached layers for speed
- **Image tagging**: Multiple tags for easy rollback and tracking
- **Task definition updates**: Automatically updates ECS configuration
- **Service stability**: Waits for ECS service to stabilize before completing
- **Concurrent safety**: Prevents race conditions with concurrency control

### Security Workflow Benefits (Optional)

- **Vulnerability detection**: Identifies unsafe packages
- **Image scanning**: Detects CVEs in base images and dependencies
- **Code analysis**: Finds security vulnerabilities in source code
- **Automated reporting**: Findings appear in GitHub Security tab

## File Structure

```
.github/
├── workflows/
│   ├── ci.yml                           # Continuous Integration
│   ├── cd.yml                           # Continuous Deployment
│   └── security.yml                     # Security Scans (optional)
├── README.md                            # This file
├── QUICK_START.md                       # 10-minute setup guide
├── WORKFLOWS_SETUP.md                   # Complete setup documentation
├── ADVANCED_WORKFLOWS.md                # Advanced customizations
└── ECS_TASK_DEFINITION_EXAMPLE.json     # Reference task definition
```

## Workflow Execution Flow

### Pull Request to Main

```
1. Code pushed to PR branch
   ↓
2. CI Workflow Triggered
   ├─ Lint and Test (Node 18 & 20)
   └─ Build Docker Image
3. GitHub shows status check on PR
4. Reviewer must approve PR
5. Status checks must pass before merge
```

### Push to Main (After Merge)

```
1. PR merged to main
   ↓
2. CI Workflow Runs (again)
   ├─ Lint and Test (Node 18 & 20)
   └─ Build Docker Image
   ↓
3. CD Workflow Runs (only on push to main)
   ├─ Build and Push to ECR
   │  ├─ Build image
   │  ├─ Tag as <SHA> and 'latest'
   │  └─ Push to ECR
   │  ↓
   └─ Deploy to ECS
      ├─ Get current task definition
      ├─ Update with new image
      ├─ Register new task revision
      ├─ Update service to use new revision
      └─ Wait for service stability
   ↓
4. Application running with new version
5. Commit history shows deployment tags
```

## Key Secrets Required

All secrets must be set in GitHub before running workflows:

| Secret | Purpose | Example |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Authenticate with AWS | AKIA... |
| `AWS_SECRET_ACCESS_KEY` | Authenticate with AWS | wJalr... |
| `AWS_REGION` | AWS region for resources | us-east-1 |
| `ECR_REPOSITORY` | ECR repository name | demo-web-claude-devops |
| `ECS_CLUSTER` | ECS cluster name | production-cluster |
| `ECS_SERVICE` | ECS service name | demo-web-service |
| `ECS_TASK_DEFINITION` | Task definition family | demo-web-claude-devops |
| `CONTAINER_NAME` | Container name in task def | demo-web-claude-devops |

**See WORKFLOWS_SETUP.md > Step 3 for detailed instructions.**

## Monitoring and Debugging

### View Workflow Status

In GitHub repository:
1. Click **Actions** tab
2. Select workflow name (CI, CD, or Security)
3. View recent runs and their status

### Check Logs

1. Click on a specific run
2. Click the failed job to expand
3. Expand individual steps to see logs
4. Look for error messages or failed assertions

### Common Issues and Fixes

| Issue | Cause | Solution |
|---|---|---|
| Auth failed | Wrong AWS credentials | Verify secrets in Settings > Secrets |
| Task def not found | Wrong task definition name | Check exact name in AWS ECS console |
| Service update failed | Task can't reach desired count | Check CloudWatch logs, verify service config |
| Port in use during CI | Tests didn't clean up | This is normal, tests use proper cleanup flags |
| Image won't push | ECR permissions missing | Verify IAM policy in WORKFLOWS_SETUP.md |

**See WORKFLOWS_SETUP.md > Troubleshooting for more details.**

## Performance Characteristics

### CI Workflow Timing

Typical execution times on ubuntu-latest:

- Setup Node.js + cache: 10-15 seconds
- Install dependencies: 20-30 seconds (first run), 5-10 seconds (cached)
- Run tests: 30-45 seconds
- Build Docker image: 30-60 seconds
- **Total: 2-5 minutes**

### CD Workflow Timing

Typical execution times on ubuntu-latest:

- Setup AWS credentials: 5 seconds
- ECR login: 3 seconds
- Build Docker image: 30-60 seconds (first run), 10-20 seconds (cached)
- Push to ECR: 10-20 seconds
- Get task definition: 3 seconds
- Update task definition: 2 seconds
- Register new revision: 2 seconds
- Update service: 2 seconds
- Wait for stability: 3-10 minutes
- **Total: 5-15 minutes** (mostly ECS stabilization wait)

### Optimization Tips

1. **Docker caching**: Subsequent builds are faster due to layer caching
2. **npm caching**: Dependencies are cached between runs
3. **Matrix testing**: Node versions test in parallel, not sequentially
4. **Selective triggers**: Use path filters to skip workflows for non-code changes

## Security Best Practices

### Implemented

- All AWS credentials are GitHub secrets (never hardcoded)
- IAM uses least privilege (minimal required permissions)
- Docker images scanned for vulnerabilities
- Code analyzed with CodeQL for security issues
- npm dependencies audited for vulnerabilities
- All actions pinned to specific versions (immutable)

### Recommended Additions

1. **Branch protection**: Require checks to pass before merge
2. **Required reviewers**: Require approval before production deployment
3. **Status checks**: Require all CI jobs to pass
4. **OIDC provider**: Replace static AWS keys with short-lived tokens
5. **Secrets scanning**: Enable GitHub's native secrets scanner

See WORKFLOWS_SETUP.md > Security Best Practices for details.

## Customization

### Change Node.js Versions

Edit `ci.yml`:
```yaml
strategy:
  matrix:
    node-version: ['16.x', '18.x', '20.x']  # Add/remove versions
```

### Add Slack Notifications

See ADVANCED_WORKFLOWS.md > Slack/Teams Notifications

### Deploy to Multiple Environments

See ADVANCED_WORKFLOWS.md > Multi-Environment Deployments

### Enable Manual Approvals

See ADVANCED_WORKFLOWS.md > Manual Approval Workflows

### Add Image Signing

See ADVANCED_WORKFLOWS.md > Image Signing with Cosign

## Support and Resources

### Documentation

- [QUICK_START.md](QUICK_START.md) - Fast setup (10 min)
- [WORKFLOWS_SETUP.md](WORKFLOWS_SETUP.md) - Complete guide
- [ADVANCED_WORKFLOWS.md](ADVANCED_WORKFLOWS.md) - Advanced features
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [AWS ECS Docs](https://docs.aws.amazon.com/ecs/)

### Quick Commands

View workflow runs:
```bash
gh run list --limit 10
gh run view <run-id>
gh run watch <run-id>
```

Check deployment status:
```bash
aws ecs describe-services \
  --cluster your-cluster-name \
  --services your-service-name \
  --region us-east-1
```

## Version History

- **v1.0** (2025-01-17): Initial release
  - CI workflow with multi-version testing
  - CD workflow with ECR push and ECS deployment
  - Security workflow with npm audit and Trivy
  - Complete setup documentation
  - Advanced customization guide

## Next Steps

1. Follow [QUICK_START.md](QUICK_START.md) for setup
2. Test with a sample PR
3. Review [ADVANCED_WORKFLOWS.md](ADVANCED_WORKFLOWS.md) for enhancements
4. Set up branch protection rules
5. Configure production environment approvals

---

**Created**: 2025-01-17
**Status**: Production-Ready
**Maintained by**: DevOps Team
