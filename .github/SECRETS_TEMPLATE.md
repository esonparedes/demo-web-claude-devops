# GitHub Secrets Configuration Template

This file provides a template and validation checklist for all required GitHub secrets.

## Required Secrets

Copy and fill in these values in GitHub Settings > Secrets and variables > Actions:

### AWS Credentials

```
Name: AWS_ACCESS_KEY_ID
Value: AKIA...
Description: AWS IAM user access key for GitHub Actions
```

```
Name: AWS_SECRET_ACCESS_KEY
Value: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Description: AWS IAM user secret access key
```

```
Name: AWS_REGION
Value: us-east-1
Description: AWS region where ECR and ECS resources are located
Options: us-east-1, us-west-2, eu-west-1, ap-southeast-1, etc.
```

### ECR Configuration

```
Name: ECR_REPOSITORY
Value: demo-web-claude-devops
Description: Name of the ECR repository
Note: Must match the repository name in your AWS account
```

### ECS Configuration

```
Name: ECS_CLUSTER
Value: production-cluster
Description: Name of the ECS cluster
Note: Must match the cluster name in your AWS account
Example values: production-cluster, staging-cluster, demo-cluster
```

```
Name: ECS_SERVICE
Value: demo-web-service
Description: Name of the ECS service
Note: Must match the service name within the ECS cluster
Example values: demo-web-service, demo-web-staging
```

```
Name: ECS_TASK_DEFINITION
Value: demo-web-claude-devops
Description: Family name of the ECS task definition
Note: This is the family name, not including revision number
Example values: demo-web-claude-devops, my-app-task
```

```
Name: CONTAINER_NAME
Value: demo-web-claude-devops
Description: Name of the container in the task definition
Note: Must match the containerDefinitions[].name in your task definition JSON
This is typically the same as ECS_TASK_DEFINITION
```

## Optional Secrets (for advanced workflows)

If using the advanced workflows from ADVANCED_WORKFLOWS.md:

```
Name: SLACK_WEBHOOK_URL
Value: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
Description: Slack webhook URL for deployment notifications
Setup: https://api.slack.com/messaging/webhooks
```

```
Name: CODECOV_TOKEN
Value: your-codecov-token
Description: Codecov.io token for coverage uploads
Setup: https://codecov.io/ (optional, provides better coverage tracking)
```

## Validation Checklist

Before testing your workflows, verify:

- [ ] All 8 required secrets are set (see list below)
- [ ] AWS credentials are correct (AccessKeyId and SecretAccessKey)
- [ ] AWS_REGION matches where your ECR/ECS resources exist
- [ ] ECR_REPOSITORY name exists in AWS ECR console
- [ ] ECS_CLUSTER name exists in AWS ECS console
- [ ] ECS_SERVICE exists within that cluster
- [ ] ECS_TASK_DEFINITION family exists in AWS ECS console
- [ ] CONTAINER_NAME matches the containerDefinitions name in task def
- [ ] No secrets contain spaces or quotes
- [ ] AWS credentials have appropriate IAM permissions

## Step-by-Step Verification

### 1. Verify AWS Credentials

```bash
# Test with your credentials
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="wJalr..."
export AWS_REGION="us-east-1"

# List ECR repositories (tests credentials)
aws ecr describe-repositories --region $AWS_REGION

# If this command succeeds, your credentials are valid
```

### 2. Verify ECR Repository

```bash
aws ecr describe-repositories \
  --repository-names demo-web-claude-devops \
  --region us-east-1
```

**Expected output**: Shows your ECR repository details
**If fails**: Verify ECR_REPOSITORY secret matches actual repo name

### 3. Verify ECS Cluster

```bash
aws ecs describe-clusters \
  --clusters production-cluster \
  --region us-east-1
```

**Expected output**: Shows your ECS cluster details
**If fails**: Verify ECS_CLUSTER secret matches actual cluster name

### 4. Verify ECS Service

```bash
aws ecs describe-services \
  --cluster production-cluster \
  --services demo-web-service \
  --region us-east-1
```

**Expected output**: Shows your ECS service details
**If fails**: Verify ECS_SERVICE secret and ECS_CLUSTER are correct

### 5. Verify Task Definition

```bash
aws ecs describe-task-definition \
  --task-definition demo-web-claude-devops \
  --region us-east-1
```

**Expected output**: Shows task definition with containerDefinitions
**If fails**: Verify ECS_TASK_DEFINITION matches the task definition family name

### 6. Verify Container Name

```bash
aws ecs describe-task-definition \
  --task-definition demo-web-claude-devops \
  --region us-east-1 \
  --query 'taskDefinition.containerDefinitions[0].name'
```

**Expected output**: Should match your CONTAINER_NAME secret
**Example**: "demo-web-claude-devops"

## Finding Your Values

If you don't know your values, find them in AWS:

### Finding ECR Repository Name

```bash
# List all ECR repositories
aws ecr describe-repositories --region us-east-1

# Look for your repository in the output, use the repositoryName value
```

### Finding ECS Cluster Name

```bash
# List all ECS clusters
aws ecs list-clusters --region us-east-1

# Use the cluster name (without the ARN prefix)
```

### Finding ECS Service Name

```bash
# List services in your cluster
aws ecs list-services \
  --cluster your-cluster-name \
  --region us-east-1

# Use the service name from the output
```

### Finding Task Definition Family

```bash
# List task definitions
aws ecs list-task-definitions --region us-east-1

# Look for your task definition, use the family name (without :revision)
```

### Finding Container Name

```bash
# Get task definition details
aws ecs describe-task-definition \
  --task-definition your-task-definition-family \
  --region us-east-1 \
  --query 'taskDefinition.containerDefinitions[*].name'

# The container name(s) will be shown
```

## Creating the IAM User and Keys

### Via AWS Console

1. Go to IAM > Users
2. Click "Create user"
3. Name it `github-actions-user`
4. Skip "Add permissions" (we'll add inline policy)
5. Click "Create user"
6. Select the new user
7. Go to "Security credentials" tab
8. Click "Create access key"
9. Select "Application running outside AWS"
10. Copy the Access Key ID and Secret Access Key
11. Create inline policy using the JSON from WORKFLOWS_SETUP.md

### Via AWS CLI

```bash
# Create user
aws iam create-user --user-name github-actions-user

# Add inline policy (replace ACCOUNT_ID, REGION, names)
aws iam put-user-policy \
  --user-name github-actions-user \
  --policy-name github-actions-policy \
  --policy-document file://policy.json

# Create access keys
aws iam create-access-key --user-name github-actions-user

# Output will show AccessKeyId and SecretAccessKey
```

## GitHub UI Navigation

### Adding Secrets Step-by-Step

1. Go to your repository on GitHub
2. Click "Settings" tab
3. In left sidebar, click "Secrets and variables"
4. Click "Actions"
5. Click "New repository secret"
6. Enter secret Name (e.g., AWS_ACCESS_KEY_ID)
7. Enter secret Value (e.g., AKIA...)
8. Click "Add secret"
9. Repeat for all 8 secrets

### Verifying Secrets Are Set

1. In Settings > Secrets and variables > Actions
2. You should see all 8 secrets listed
3. Click the secret name to update it (values are hidden for security)
4. You cannot view the value after creation, only update or delete

## Security Best Practices

1. **Don't share secrets**: Never paste secret values in chat/email
2. **Rotate keys regularly**: Replace AWS access keys every 90 days
3. **Use IAM policy**: Limit to only necessary permissions (least privilege)
4. **Delete old keys**: Remove keys for departed team members
5. **Audit access**: AWS CloudTrail logs API calls made with these credentials
6. **Environment separation**: Use different keys for staging/production if possible

## Troubleshooting

### Secret not found error in workflow

```
Error: Unable to locate credentials in the environment
```

**Solution**: Make sure the secret name exactly matches what's referenced in the workflow (case-sensitive)

### Authorization failed

```
Error: User: arn:aws:iam::xxx is not authorized to perform: ecr:...
```

**Solution**: The IAM user lacks required permissions. Add the policy from WORKFLOWS_SETUP.md

### Repository not found

```
Error: The repository with name xxx does not exist in the registry
```

**Solution**: Verify ECR_REPOSITORY secret matches the actual repository name in AWS

### Service not found

```
Error: The service cannot be updated because the service not found for Arn
```

**Solution**: Verify ECS_SERVICE and ECS_CLUSTER secrets are correct

## Common IAM Policy Permissions

If setting up IAM manually, ensure these actions are allowed:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRLogin",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:REGION:ACCOUNT_ID:repository/ECR_REPOSITORY"
    },
    {
      "Sid": "ECSAccess",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeServices"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::ACCOUNT_ID:role/*TaskRole*",
        "arn:aws:iam::ACCOUNT_ID:role/*TaskExecutionRole*"
      ]
    }
  ]
}
```

## Final Checklist

Before running your first workflow:

- [ ] Created AWS IAM user `github-actions-user`
- [ ] Generated and copied access keys from IAM
- [ ] Added IAM policy with ECS and ECR permissions
- [ ] All 8 secrets are set in GitHub
- [ ] Tested AWS credentials locally with CLI commands
- [ ] Verified ECR repository exists
- [ ] Verified ECS cluster exists
- [ ] Verified ECS service exists
- [ ] Verified task definition exists
- [ ] Verified container name in task definition

Once all items are checked, run the test workflow:
```bash
git checkout -b test/workflows
git push origin test/workflows
# Create pull request
# Watch CI workflow run
# Merge PR to main
# Watch CD workflow run
```

Good luck with your deployment pipeline!
