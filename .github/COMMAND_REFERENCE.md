# GitHub Actions Command Reference and Cheat Sheet

Quick reference for common commands and operations related to the CI/CD pipeline.

## AWS CLI Commands

### Verify Credentials

```bash
# Test AWS credentials (lists repositories)
aws ecr describe-repositories --region us-east-1

# If successful, credentials are valid
# If fails: "Unable to locate credentials" - check env variables
```

### ECR (Container Registry) Commands

```bash
# List all ECR repositories
aws ecr describe-repositories --region us-east-1

# Get details of specific repository
aws ecr describe-repositories \
  --repository-names demo-web-claude-devops \
  --region us-east-1

# List images in repository
aws ecr describe-images \
  --repository-name demo-web-claude-devops \
  --region us-east-1

# Get latest image
aws ecr describe-images \
  --repository-name demo-web-claude-devops \
  --region us-east-1 \
  --query 'sort_by(imageDetails,&imagePushedAt)[-1]'

# Get image URI
aws ecr describe-repositories \
  --repository-names demo-web-claude-devops \
  --region us-east-1 \
  --query 'repositories[0].repositoryUri' \
  --output text
```

### ECS (Container Orchestration) Commands

```bash
# List all ECS clusters
aws ecs list-clusters --region us-east-1

# Get cluster details
aws ecs describe-clusters \
  --clusters production-cluster \
  --region us-east-1

# List services in cluster
aws ecs list-services \
  --cluster production-cluster \
  --region us-east-1

# Get service details
aws ecs describe-services \
  --cluster production-cluster \
  --services demo-web-service \
  --region us-east-1

# Get service current deployment
aws ecs describe-services \
  --cluster production-cluster \
  --services demo-web-service \
  --region us-east-1 \
  --query 'services[0].deployments'

# Get service running task count
aws ecs describe-services \
  --cluster production-cluster \
  --services demo-web-service \
  --region us-east-1 \
  --query 'services[0].[runningCount,desiredCount]'

# Get latest tasks
aws ecs list-tasks \
  --cluster production-cluster \
  --service-name demo-web-service \
  --region us-east-1

# Get task details
aws ecs describe-tasks \
  --cluster production-cluster \
  --tasks arn:aws:ecs:region:account:task/cluster/task-id \
  --region us-east-1
```

### ECS Task Definition Commands

```bash
# List all task definitions
aws ecs list-task-definitions --region us-east-1

# List revisions of a task definition
aws ecs list-task-definition-revisions \
  --family-prefix demo-web-claude-devops \
  --region us-east-1

# Get latest task definition
aws ecs describe-task-definition \
  --task-definition demo-web-claude-devops \
  --region us-east-1

# Get specific revision
aws ecs describe-task-definition \
  --task-definition demo-web-claude-devops:5 \
  --region us-east-1

# Get image from task definition
aws ecs describe-task-definition \
  --task-definition demo-web-claude-devops \
  --region us-east-1 \
  --query 'taskDefinition.containerDefinitions[0].image'

# Save task definition to file
aws ecs describe-task-definition \
  --task-definition demo-web-claude-devops \
  --region us-east-1 \
  --query 'taskDefinition' > task-definition.json
```

### Deployment Commands

```bash
# Trigger new deployment
aws ecs update-service \
  --cluster production-cluster \
  --service demo-web-service \
  --force-new-deployment \
  --region us-east-1

# Update service with specific task definition
aws ecs update-service \
  --cluster production-cluster \
  --service demo-web-service \
  --task-definition demo-web-claude-devops:10 \
  --region us-east-1

# Check deployment status
aws ecs describe-services \
  --cluster production-cluster \
  --services demo-web-service \
  --region us-east-1 | jq '.services[0].deployments'

# Wait for service stable
aws ecs wait services-stable \
  --cluster production-cluster \
  --services demo-web-service \
  --region us-east-1
```

### IAM Commands

```bash
# Create IAM user
aws iam create-user --user-name github-actions-user

# List IAM users
aws iam list-users

# Create inline policy
aws iam put-user-policy \
  --user-name github-actions-user \
  --policy-name github-actions-policy \
  --policy-document file://policy.json

# Create access keys
aws iam create-access-key --user-name github-actions-user

# List access keys
aws iam list-access-keys --user-name github-actions-user

# Delete access key
aws iam delete-access-key \
  --user-name github-actions-user \
  --access-key-id AKIA...
```

## GitHub CLI Commands

### Workflow Management

```bash
# List recent workflow runs
gh run list --limit 10

# List runs for specific workflow
gh run list --workflow ci.yml --limit 10

# Watch a workflow run
gh run watch <run-id>

# View logs from a run
gh run view <run-id> --log

# View a specific job
gh run view <run-id> --job <job-id>

# Cancel a run
gh run cancel <run-id>

# Rerun a failed workflow
gh run rerun <run-id>

# Rerun failed jobs only
gh run rerun <run-id> --failed

# Delete workflow run artifacts
gh run delete <run-id>
```

### Pull Request Management

```bash
# Create PR from current branch
gh pr create --title "Fix: Bug description" --body "Details"

# Create PR with automatic merge on CI pass
gh pr create --title "PR title" --auto-merge --merge-method squash

# View PR status
gh pr view

# List open PRs
gh pr list --state open

# Close PR without merging
gh pr close <pr-number>

# Merge PR
gh pr merge <pr-number> --merge

# Request review
gh pr review <pr-number> --request-review @username
```

### Repository Settings

```bash
# List repository secrets
gh secret list

# Set a secret
gh secret set SECRET_NAME --body "secret-value"

# Delete a secret
gh secret delete SECRET_NAME

# List variables
gh variable list

# Set a variable
gh variable set VARIABLE_NAME --body "value"
```

## Local Testing Commands

### Test Locally Before Pushing

```bash
# Run tests locally
npm test

# Run tests in watch mode
npx jest --watch

# Run specific test file
npx jest tests/server.test.js

# Run with coverage
npm test -- --coverage

# Run tests with specific Node version
nvm use 20
npm test

# Build Docker image locally
docker build -t demo-web-claude-devops:test .

# Run container locally
docker run -p 3000:3000 demo-web-claude-devops:test

# Check if port 3000 is working
curl http://localhost:3000/

# Check API endpoint
curl http://localhost:3000/api/search?q=test
```

## GitHub Settings Commands

### Configure Repository

```bash
# Clone with Git (for first time setup)
git clone https://github.com/your-org/demo-web-claude-devops.git

# Add secrets via GitHub CLI
gh secret set AWS_ACCESS_KEY_ID --body "AKIA..."
gh secret set AWS_SECRET_ACCESS_KEY --body "wJalr..."
gh secret set AWS_REGION --body "us-east-1"
gh secret set ECR_REPOSITORY --body "demo-web-claude-devops"
gh secret set ECS_CLUSTER --body "production-cluster"
gh secret set ECS_SERVICE --body "demo-web-service"
gh secret set ECS_TASK_DEFINITION --body "demo-web-claude-devops"
gh secret set CONTAINER_NAME --body "demo-web-claude-devops"

# Verify secrets are set
gh secret list
```

## Development Workflow Commands

### Creating and Testing

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
echo "code changes" > file.js

# Commit changes
git add .
git commit -m "feat: add new feature"

# Push to origin
git push origin feature/new-feature

# Create pull request
gh pr create --title "Add new feature" --body "Description"

# Wait for CI to pass, then merge
gh pr merge --auto --squash

# Clean up local branch
git checkout main
git pull origin main
git branch -d feature/new-feature
```

### Testing Deployment

```bash
# Create test branch
git checkout -b test/workflows

# Make small test change
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "test: verify workflows"
git push origin test/workflows

# Create PR and watch CI
gh pr create --title "Test: CI workflow" --body "Testing CI"

# View workflow runs
gh run list --limit 5

# Merge PR
gh pr merge --auto --squash

# Watch CD workflow deploy
gh run list --workflow cd.yml --limit 1 --watch
```

## Docker Commands

### Build and Test Locally

```bash
# Build image with tag
docker build -t demo-web-claude-devops:latest .

# Build with specific tag
docker build -t demo-web-claude-devops:1.0.0 .

# Build and tag multiple times
docker build \
  -t demo-web-claude-devops:latest \
  -t demo-web-claude-devops:v1.0.0 \
  .

# Run container
docker run -p 3000:3000 demo-web-claude-devops:latest

# Run with environment variable
docker run -p 3000:3000 -e NODE_ENV=production demo-web-claude-devops:latest

# Run container in background
docker run -d -p 3000:3000 --name web demo-web-claude-devops:latest

# View running containers
docker ps

# View container logs
docker logs container-name

# Stop container
docker stop container-name

# Remove container
docker rm container-name

# Remove image
docker rmi demo-web-claude-devops:latest

# View images
docker images

# Push to ECR
docker tag demo-web-claude-devops:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/demo-web-claude-devops:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/demo-web-claude-devops:latest
```

## Troubleshooting Commands

### Debugging Failed Workflows

```bash
# View latest failed run
gh run list --limit 1 --status failure

# Get detailed logs
gh run view <run-id> --log

# Check specific job
gh run view <run-id> --job lint-and-test

# Rerun failed workflow
gh run rerun <run-id>

# Debug mode (if secrets.ACTIONS_STEP_DEBUG is set)
# Logs will show more details
```

### Checking Resources

```bash
# Verify AWS access
aws sts get-caller-identity

# Check ECR access
aws ecr get-authorization-token

# Check ECS cluster health
aws ecs describe-clusters --clusters production-cluster

# Check service tasks
aws ecs list-tasks --cluster production-cluster --service-name demo-web-service

# View service events (shows recent failures/deployments)
aws ecs describe-services \
  --cluster production-cluster \
  --services demo-web-service \
  --query 'services[0].events[:5]'

# Check logs in CloudWatch
aws logs tail /ecs/demo-web-claude-devops --follow
```

### Cleanup Commands

```bash
# Remove old task definitions
aws ecs deregister-task-definition --task-definition demo-web-claude-devops:1

# Delete old images from ECR
aws ecr batch-delete-image \
  --repository-name demo-web-claude-devops \
  --image-ids imageTag=old-tag

# Clean up local Docker
docker system prune  # Remove unused images, containers, networks
docker system prune -a  # Also remove unused images not referenced by containers
```

## Git Commands

### Branch Management

```bash
# Create new branch
git checkout -b feature/my-feature

# List all branches
git branch -a

# Delete local branch
git branch -d feature/my-feature

# Delete remote branch
git push origin --delete feature/my-feature

# Sync with main
git fetch origin
git rebase origin/main

# Create PR from CLI
gh pr create

# Merge locally (when needed)
git checkout main
git pull origin main
git merge --squash feature/my-feature
git commit -m "feat: my feature description"
git push origin main
```

## Monitoring Commands

### Real-time Monitoring

```bash
# Watch workflow run in real-time
gh run watch <run-id>

# Poll for workflow completion
while ! gh run list --limit 1 --status completed | grep -q completed; do
  echo "Waiting for workflow..."
  sleep 10
done
echo "Workflow complete!"

# Monitor ECS service deployment
while true; do
  aws ecs describe-services \
    --cluster production-cluster \
    --services demo-web-service \
    --region us-east-1 \
    --query 'services[0].[runningCount,desiredCount]'
  sleep 5
done

# Check task status loop
for task in $(aws ecs list-tasks --cluster production-cluster); do
  aws ecs describe-tasks --cluster production-cluster --tasks $task
  sleep 2
done
```

## Common Task Combinations

### Complete Setup Flow

```bash
# 1. Set up secrets
gh secret set AWS_ACCESS_KEY_ID --body "AKIA..."
gh secret set AWS_SECRET_ACCESS_KEY --body "wJalr..."
gh secret set AWS_REGION --body "us-east-1"
gh secret set ECR_REPOSITORY --body "demo-web-claude-devops"
gh secret set ECS_CLUSTER --body "production-cluster"
gh secret set ECS_SERVICE --body "demo-web-service"
gh secret set ECS_TASK_DEFINITION --body "demo-web-claude-devops"
gh secret set CONTAINER_NAME --body "demo-web-claude-devops"

# 2. Verify secrets
gh secret list

# 3. Test locally
npm test
docker build -t demo-web-claude-devops:test .

# 4. Create test branch
git checkout -b test/workflows
git push origin test/workflows

# 5. Create PR
gh pr create --title "Test: CI/CD pipeline"

# 6. Watch CI
gh run watch $(gh run list --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')

# 7. Merge PR
gh pr merge --auto --squash

# 8. Watch CD
gh run watch $(gh run list --workflow cd.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

### Rollback Flow

```bash
# 1. Get previous task definition
aws ecs list-task-definition-revisions \
  --family-prefix demo-web-claude-devops \
  --query 'taskDefinitionArns' | jq '.[1]'

# 2. Extract revision number
PREV_REVISION=demo-web-claude-devops:REVISION_NUMBER

# 3. Update service to use previous revision
aws ecs update-service \
  --cluster production-cluster \
  --service demo-web-service \
  --task-definition $PREV_REVISION

# 4. Monitor rollback
aws ecs wait services-stable \
  --cluster production-cluster \
  --services demo-web-service

# 5. Verify old version is running
aws ecs describe-task-definition \
  --task-definition $PREV_REVISION \
  --query 'taskDefinition.containerDefinitions[0].image'
```

### Get All Information

```bash
# Get everything about current state
echo "=== Secrets ==="
gh secret list

echo "=== Latest Workflow Run ==="
gh run list --limit 1 --json status,name,createdAt,updatedAt

echo "=== ECR Images ==="
aws ecr describe-images \
  --repository-name demo-web-claude-devops \
  --query 'sort_by(imageDetails,&imagePushedAt)[-3:]'

echo "=== ECS Service ==="
aws ecs describe-services \
  --cluster production-cluster \
  --services demo-web-service

echo "=== Running Tasks ==="
aws ecs list-tasks --cluster production-cluster --service-name demo-web-service

echo "=== Task Definition ==="
aws ecs describe-task-definition --task-definition demo-web-claude-devops
```

## Tips and Tricks

### Batch Operations

```bash
# Delete all failed runs
gh run list --status failure --limit 100 --json databaseId --jq '.[].databaseId' | \
  xargs -I {} gh run delete {}

# Get all run times
gh run list --limit 20 --json name,durationMinutes,conclusion --jq '.[] | "\(.name): \(.durationMinutes)m (\(.conclusion))"'
```

### One-Liners

```bash
# Get current image in ECS
aws ecs describe-task-definition --task-definition demo-web-claude-devops --query 'taskDefinition.containerDefinitions[0].image' --output text

# Get latest ECR image URI
aws ecr describe-images --repository-name demo-web-claude-devops --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageName' --output text

# Check if CI passed
gh run list --workflow ci.yml --limit 1 --json conclusion | grep -q success && echo "CI Passed" || echo "CI Failed"

# Get deployment time
gh run view $(gh run list --workflow cd.yml --limit 1 --json databaseId --jq '.[0].databaseId') --json durationMinutes

# Force redeploy without code changes
aws ecs update-service --cluster production-cluster --service demo-web-service --force-new-deployment
```

---

**Pro Tip**: Save commonly used commands in shell aliases for faster execution:

```bash
# Add to ~/.bashrc or ~/.zshrc
alias check-secrets='gh secret list'
alias watch-ci='gh run watch $(gh run list --workflow ci.yml --limit 1 --json databaseId --jq ".[0].databaseId")'
alias watch-cd='gh run watch $(gh run list --workflow cd.yml --limit 1 --json databaseId --jq ".[0].databaseId")'
alias ecs-status='aws ecs describe-services --cluster production-cluster --services demo-web-service'
```

