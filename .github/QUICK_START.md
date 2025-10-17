# Quick Start - GitHub Actions CI/CD Pipeline

Follow these steps to get the CI/CD pipeline running in 10 minutes.

## Prerequisites Checklist

- [ ] AWS Account with ECR repository created
- [ ] AWS ECS cluster and service running
- [ ] ECS task definition defined
- [ ] Admin access to GitHub repository

## 5-Minute Setup

### 1. Create AWS IAM User

```bash
# Using AWS CLI (replace with your account ID)
aws iam create-user --user-name github-actions-user

# Attach inline policy (save this JSON to policy.json first)
aws iam put-user-policy --user-name github-actions-user \
  --policy-name github-actions-ecs-ecr \
  --policy-document file://policy.json

# Create access keys
aws iam create-access-key --user-name github-actions-user
# Save the output - you'll need AccessKeyId and SecretAccessKey
```

See `WORKFLOWS_SETUP.md` for the full IAM policy JSON.

### 2. Add GitHub Secrets

Go to GitHub Repository > Settings > Secrets and variables > Actions

**Add these 8 secrets:**

```
AWS_ACCESS_KEY_ID = <from step 1>
AWS_SECRET_ACCESS_KEY = <from step 1>
AWS_REGION = us-east-1
ECR_REPOSITORY = demo-web-claude-devops
ECS_CLUSTER = <your-cluster-name>
ECS_SERVICE = <your-service-name>
ECS_TASK_DEFINITION = demo-web-claude-devops
CONTAINER_NAME = demo-web-claude-devops
```

### 3. Verify ECS Configuration

```bash
# List your ECS clusters
aws ecs list-clusters --region us-east-1

# List services in your cluster
aws ecs list-services --cluster your-cluster-name --region us-east-1

# Get task definition details
aws ecs describe-task-definition --task-definition demo-web-claude-devops
```

Update the secrets with your actual cluster and service names.

### 4. Test the Pipeline

Create a test branch and PR:

```bash
git checkout -b test/workflows
echo "# Test" >> README.md
git add README.md
git commit -m "test: verify workflows"
git push origin test/workflows
```

Open a PR and watch the CI workflow run in the Actions tab.

### 5. Merge and Deploy

Once the PR checks pass:
1. Click "Merge pull request"
2. Go to Actions tab and watch the CD workflow run
3. Verify deployment in ECS console or:

```bash
aws ecs describe-services --cluster your-cluster \
  --services your-service --region us-east-1
```

## Workflow Files

Your workflows are now available in `.github/workflows/`:

- **ci.yml** - Runs tests and validates Docker build on every PR and push
- **cd.yml** - Builds image, pushes to ECR, and deploys to ECS
- **security.yml** - Runs security scans (optional)

## What Happens Automatically

### On Pull Request to Main
- Tests run on Node 18 and 20
- Docker image is built (but not pushed)
- Code coverage is checked
- Status checks appear on the PR

### On Push to Main (After PR Merge)
- All CI checks run again
- Docker image is built AND pushed to ECR with 2 tags:
  - Git commit SHA (e.g., `abc123def456`)
  - `latest` tag
- ECS task definition is updated with new image
- Service is updated and deployment begins
- Workflow waits for service to stabilize

## Next Steps

1. **Configure branch protection** (optional but recommended):
   - Settings > Branches > Add rule for `main`
   - Require status checks to pass
   - Require approvals before merge

2. **Enable environment approvals** for production deployments:
   - Settings > Environments > production
   - Add required reviewers

3. **Add notifications** (optional):
   - Set up Slack webhook for deployment notifications
   - See `WORKFLOWS_SETUP.md` for details

4. **Monitor deployments**:
   - GitHub: Actions tab shows all workflow runs
   - CloudWatch: Monitor ECS service health
   - ECR: View pushed images with their tags

## Common Commands

View workflow runs:
```bash
# List latest workflow runs
gh run list --limit 10

# Watch a specific workflow
gh run watch <run-id>

# View logs from a failed run
gh run view <run-id> --log
```

Manage deployments:
```bash
# See current deployment
aws ecs describe-services --cluster your-cluster \
  --services your-service --region us-east-1 \
  --query 'services[0].deployments' | jq

# Check task definition versions
aws ecs list-task-definition-revisions \
  --family-prefix demo-web-claude-devops
```

## Troubleshooting

See `WORKFLOWS_SETUP.md` for detailed troubleshooting and common issues.

**Quick checks:**
1. Verify all 8 secrets are set (Settings > Secrets)
2. Check ECR repository exists: `aws ecr describe-repositories --region us-east-1`
3. Check ECS cluster is active: `aws ecs describe-clusters --clusters your-cluster`
4. Check service has desired count: `aws ecs describe-services --cluster your-cluster --services your-service`

## Secrets Validation

To verify your secrets are correct, look at the workflow logs:
1. Go to Actions > CD workflow > Latest run
2. Click "build-and-push" job
3. Expand "Configure AWS credentials" step
4. Should show: "Found credentials in secret"
5. Should NOT show: "Unable to locate credentials"

If you see credential errors, re-check your secrets in Settings.

## Scale Up

Once the basic pipeline is working:

1. Add more test cases in `tests/server.test.js`
2. Add staging environment for testing before production
3. Set up CloudWatch alarms for failed deployments
4. Integrate with PagerDuty or Slack for alerts
5. Add performance monitoring
6. Set up automated rollback procedures

## Support

Full documentation: See `WORKFLOWS_SETUP.md` in `.github/` directory

For issues:
1. Check Actions tab for workflow logs
2. Verify all 8 secrets are configured
3. Confirm AWS resources (ECR, ECS) exist and are accessible
4. Check AWS IAM permissions match the policy in setup guide
