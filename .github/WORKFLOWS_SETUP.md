# GitHub Actions CI/CD Pipeline Setup Guide

This guide provides step-by-step instructions to set up the GitHub Actions workflows for the Express.js application with AWS ECS deployment.

## Overview

The pipeline consists of three workflows:

1. **CI Workflow** (`ci.yml`) - Runs on every push and PR to main
   - Lints and tests the application across Node.js 18 and 20
   - Validates Docker image can be built
   - Uploads coverage reports to Codecov

2. **CD Workflow** (`cd.yml`) - Runs on pushes to main only
   - Builds Docker image with BuildKit for layer caching
   - Pushes images to AWS ECR with multiple tags (SHA and 'latest')
   - Updates ECS task definition with new image
   - Deploys to ECS service with stability checks

3. **Security Workflow** (`security.yml`) - Optional, runs on schedule and PRs
   - Performs npm audit for vulnerable dependencies
   - Scans Docker image with Trivy
   - Runs CodeQL analysis for code vulnerabilities

## Prerequisites

1. AWS Account with:
   - ECR repository created
   - ECS cluster configured
   - ECS service running
   - ECS task definition defined
   - IAM user with appropriate permissions (see IAM Policy section)

2. GitHub Repository with:
   - Admin access to configure secrets
   - Access to the Actions tab

## Step 1: Create AWS IAM User with ECS/ECR Permissions

Create a dedicated IAM user for GitHub Actions with minimal required permissions.

### Option A: AWS Console

1. Navigate to IAM > Users > Create User
2. Name it `github-actions-user`
3. Skip "Add permissions" for now
4. Create inline policy with the JSON below

### Option B: Create Inline Policy

Create an inline policy named `github-actions-ecs-ecr` with the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuthToken",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRPushImages",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:REGION:ACCOUNT_ID:repository/ECR_REPOSITORY_NAME"
    },
    {
      "Sid": "ECSDescribeAndRegister",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeServices"
      ],
      "Resource": [
        "arn:aws:ecs:REGION:ACCOUNT_ID:task-definition/TASK_DEFINITION_FAMILY:*",
        "arn:aws:ecs:REGION:ACCOUNT_ID:service/CLUSTER_NAME/SERVICE_NAME"
      ]
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
        "arn:aws:iam::ACCOUNT_ID:role/ecsTaskRole"
      ]
    }
  ]
}
```

Replace the following placeholders:
- `REGION`: Your AWS region (e.g., us-east-1)
- `ACCOUNT_ID`: Your AWS account ID
- `ECR_REPOSITORY_NAME`: Name of your ECR repository
- `TASK_DEFINITION_FAMILY`: Name of your ECS task definition
- `CLUSTER_NAME`: Name of your ECS cluster
- `SERVICE_NAME`: Name of your ECS service
- `ecsTaskExecutionRole` and `ecsTaskRole`: Names of your IAM roles used by ECS tasks

## Step 2: Generate AWS Access Keys

1. In AWS IAM console, select the `github-actions-user`
2. Navigate to "Security credentials" tab
3. Click "Create access key"
4. Select "Application running outside AWS"
5. Copy the Access Key ID and Secret Access Key (store securely)

## Step 3: Configure GitHub Repository Secrets

Navigate to your GitHub repository:
1. Settings > Secrets and variables > Actions

### Add the following secrets:

#### AWS Credentials (Required)

```
AWS_ACCESS_KEY_ID = <your-access-key-id>
AWS_SECRET_ACCESS_KEY = <your-secret-access-key>
AWS_REGION = us-east-1 (or your region)
```

#### ECR and ECS Configuration (Required)

```
ECR_REPOSITORY = demo-web-claude-devops
ECS_CLUSTER = your-cluster-name
ECS_SERVICE = your-service-name
ECS_TASK_DEFINITION = demo-web-claude-devops
CONTAINER_NAME = demo-web-claude-devops
```

### All Required Secrets Summary

| Secret Name | Description | Example |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key | AKIAIOSFODNN7EXAMPLE |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key | wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY |
| `AWS_REGION` | AWS region | us-east-1 |
| `ECR_REPOSITORY` | ECR repository name | demo-web-claude-devops |
| `ECS_CLUSTER` | ECS cluster name | production-cluster |
| `ECS_SERVICE` | ECS service name | demo-web-service |
| `ECS_TASK_DEFINITION` | Task definition family | demo-web-claude-devops |
| `CONTAINER_NAME` | Container name in task def | demo-web-claude-devops |

## Step 4: Configure GitHub Environments (Optional but Recommended)

For enhanced security and approval gates:

1. Go to Settings > Environments > New environment
2. Create two environments:
   - `staging`
   - `production`

3. For the `production` environment:
   - Add required reviewers (team members who must approve deployments)
   - Add deployment branches (allow deployments only from main)
   - Consider adding environment secrets specific to production

## Step 5: Configure Branch Protection Rules

Recommended protection rules for the `main` branch:

1. Go to Settings > Branches > Add rule
2. Create rule for pattern `main`
3. Enable:
   - Require a pull request before merging
   - Require approvals (at least 1)
   - Dismiss stale pull request approvals when new commits are pushed
   - Require status checks to pass before merging:
     - Select the following workflow jobs:
       - `lint-and-test`
       - `build-image`
   - Require branches to be up to date before merging

## Step 6: Test the Pipeline

### Test CI Workflow

1. Create a test branch from main:
   ```bash
   git checkout -b test/ci-pipeline
   ```

2. Make a small change and commit:
   ```bash
   echo "# Test" >> README.md
   git add README.md
   git commit -m "test: verify CI pipeline"
   ```

3. Push and create a pull request:
   ```bash
   git push origin test/ci-pipeline
   ```

4. Observe the CI workflow running on the PR

### Test CD Workflow

1. Verify your ECS cluster and service are running:
   ```bash
   aws ecs describe-services \
     --cluster your-cluster-name \
     --services your-service-name \
     --region us-east-1
   ```

2. Merge the PR to main (after CI passes)

3. Monitor the CD workflow:
   - Watch the build-and-push job push to ECR
   - Watch the deploy-to-ecs job update the service
   - Verify the ECS service updated with the new task definition

4. Confirm deployment:
   ```bash
   aws ecs describe-task-definition \
     --task-definition demo-web-claude-devops \
     --region us-east-1 | jq '.taskDefinition.containerDefinitions[0].image'
   ```

## Workflow Details

### CI Workflow (ci.yml)

**Triggers:**
- Push to main branch
- Pull requests to main branch
- Manual dispatch (workflow_dispatch)

**Jobs:**
1. `lint-and-test`: Tests on Node 18 and 20, uploads coverage
2. `build-image`: Builds Docker image to validate it builds correctly

**Key Features:**
- Runs on multiple Node versions for compatibility
- Uses GitHub Actions cache for npm dependencies
- Uploads coverage to Codecov (optional, requires codecov.io account)
- Uses Docker BuildKit with layer caching
- Short runtime (typically 2-5 minutes)

### CD Workflow (cd.yml)

**Triggers:**
- Push to main branch only
- Manual dispatch with environment selection

**Jobs:**
1. `build-and-push`: Builds and pushes image to ECR with SHA and latest tags
2. `deploy-to-ecs`: Updates task definition and deploys to ECS

**Key Features:**
- Concurrent runs are prevented to avoid race conditions
- Outputs image URI for use in deployment
- Updates task definition with new image
- Waits for ECS service stability (typically 2-10 minutes for deployment)
- Production environment protection rules apply

**Outputs (stored as job outputs):**
- `image-uri`: Full ECR image URI with SHA tag (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/demo-web:abc123)
- `image-tag`: Short SHA tag used for image

### Security Workflow (security.yml)

**Triggers:**
- Push to main branch
- Pull requests to main branch
- Daily schedule (2 AM UTC)
- Manual dispatch

**Jobs:**
1. `dependency-check`: Runs npm audit for vulnerable dependencies
2. `trivy-scan`: Scans Docker image for vulnerabilities
3. `codeql`: Performs CodeQL security analysis

**Key Features:**
- Identifies vulnerable npm packages
- Scans container image layer vulnerabilities
- Performs static code analysis
- Findings appear in GitHub Security tab
- Fails on high/critical vulnerabilities

## Monitoring and Troubleshooting

### View Workflow Runs

1. Go to Actions tab in your GitHub repository
2. Click on a workflow name to see all runs
3. Click a specific run to see detailed logs

### Common Issues and Solutions

#### Issue: "ECR login failed"
- **Cause**: AWS credentials are incorrect or permissions insufficient
- **Solution**: Verify AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and IAM policy

#### Issue: "Task definition not found"
- **Cause**: ECS_TASK_DEFINITION name doesn't match actual task definition
- **Solution**: Get the task definition family name from AWS ECS console

#### Issue: "Service update failed"
- **Cause**: Task definition incompatible or service can't reach desired count
- **Solution**: Check CloudWatch logs in ECS service, verify service settings

#### Issue: "Port already in use" in CI tests
- **Cause**: Previous test didn't clean up properly
- **Solution**: Tests use `--detectOpenHandles` flag; verify no lingering processes

### Debug Mode

Enable debug logging by creating a GitHub secret:

```
ACTIONS_STEP_DEBUG = true
```

This will provide verbose output from all workflow steps. Note: This may expose sensitive data in logs.

## Customization

### Modify Node.js Versions

Edit `ci.yml`, line with `node-version`:
```yaml
strategy:
  matrix:
    node-version: ['16.x', '18.x', '20.x']  # Add/remove versions
```

### Disable Security Scans

Comment out or delete the `security.yml` file if not needed.

### Add Slack Notifications

Add a step to any workflow:
```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Deployment ${{ job.status }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "Workflow: *${{ github.workflow }}*\nStatus: *${{ job.status }}*\nRef: ${{ github.ref }}"
            }
          }
        ]
      }
```

Then add `SLACK_WEBHOOK_URL` secret.

### Change Deployment Regions

Update the `AWS_REGION` secret to deploy to different regions.

## Performance Optimization

### Docker Build Caching

The workflows use GitHub Actions cache backend for Docker builds. Caching is automatic and improves subsequent builds by ~60%.

### Parallel Execution

- CI tests run in parallel (Node 18 and 20 simultaneously)
- Dependencies are cached per workflow run
- Typical CI completion: 2-5 minutes
- Typical CD completion: 5-15 minutes (including ECS stability wait)

### Cost Optimization

- Uses ubuntu-latest runners (most cost-efficient)
- Caches dependencies to avoid re-downloading
- Limits security scans to schedule and main branch
- Concurrency control prevents wasted compute on CD workflow

## Security Best Practices

1. **Credentials**: All AWS credentials are secrets, never hardcoded
2. **IAM Permissions**: Uses minimal required permissions (least privilege)
3. **OIDC**: Consider replacing static keys with AWS OIDC provider for enhanced security
4. **Secrets Scanning**: GitHub automatically scans for leaked credentials in code
5. **Dependency Updates**: Use Dependabot for automated security updates
6. **Image Scanning**: Trivy scans container images for vulnerabilities
7. **Code Analysis**: CodeQL performs SAST analysis for security issues
8. **Branch Protection**: Requires passing tests before merge

## Rollback Procedures

If a deployment causes issues:

### Automatic Rollback (if available in ECS service)

ECS can automatically roll back if service fails health checks. Verify service configuration:
```bash
aws ecs describe-services --cluster cluster-name --services service-name
```

### Manual Rollback

1. Find the previous working task definition:
   ```bash
   aws ecs describe-task-definition --task-definition demo-web-claude-devops:REVISION
   ```

2. Update service to use previous revision:
   ```bash
   aws ecs update-service \
     --cluster cluster-name \
     --service service-name \
     --task-definition demo-web-claude-devops:PREVIOUS_REVISION
   ```

3. Monitor the rollback:
   ```bash
   aws ecs describe-services --cluster cluster-name --services service-name
   ```

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS ECS Deploy Task Definition Action](https://github.com/aws-actions/amazon-ecs-deploy-task-definition)
- [AWS Configure Credentials Action](https://github.com/aws-actions/configure-aws-credentials)
- [Docker Build and Push Action](https://github.com/docker/build-push-action)
- [AWS ECS User Guide](https://docs.aws.amazon.com/ecs/)

## Support and Questions

For issues or questions:
1. Check the GitHub Actions logs for detailed error messages
2. Review this setup guide and troubleshooting section
3. Consult AWS documentation for ECS-specific issues
4. Open an issue in the repository with workflow logs (sanitize credentials)
