# Terraform Workflow - Testing & Usage Guide

## Overview

This document explains the Terraform CI workflow for the demo-web-claude-devops project. The workflow is designed to be **simple, safe, and easy to test**.

## Workflow File

**Location**: `.github/workflows/terraform.yml`

## What It Does

The Terraform workflow performs these operations automatically:

1. **Format Check** (`terraform fmt -check`) - Validates code formatting
2. **Initialization** (`terraform init`) - Downloads providers and modules
3. **Validation** (`terraform validate`) - Checks syntax and configuration
4. **Plan** (`terraform plan`) - Shows what changes would be made (requires AWS credentials)

**Important**: This workflow **NEVER runs `terraform apply`**. All changes must be applied manually for safety.

## When It Runs

The workflow triggers on:

- ✅ **Pull Requests** to `main` branch (when terraform files change)
- ✅ **Pushes** to `terraform-scripts` branch (for testing)
- ✅ **Manual trigger** via GitHub Actions UI (workflow_dispatch)

## Testing the Workflow

### Method 1: Test on Current Branch (Recommended for Quick Testing)

Since you're on the `terraform-scripts` branch, any push will trigger the workflow:

```bash
# Make a small change to trigger the workflow
cd /workspaces/demo-web-claude-devops
echo "# Test commit" >> terraform/.gitignore

# Commit and push
git add terraform/.gitignore
git commit -m "test: trigger terraform workflow"
git push origin terraform-scripts
```

Then check GitHub Actions: `https://github.com/<your-username>/demo-web-claude-devops/actions`

### Method 2: Manual Trigger

1. Go to your repository on GitHub
2. Navigate to **Actions** tab
3. Select **Terraform CI** workflow
4. Click **Run workflow** button
5. Choose branch and options
6. Click **Run workflow**

### Method 3: Create a Test Pull Request

```bash
# Create a new test branch from terraform-scripts
git checkout -b test-terraform-workflow

# Make a small change
echo "# Testing workflow" >> terraform/README.md
git add terraform/README.md
git commit -m "test: verify terraform workflow"
git push origin test-terraform-workflow

# Create a PR on GitHub targeting the 'main' branch
# The workflow will run automatically on the PR
```

### Method 4: Test Format Check Failure

To verify the workflow catches formatting issues:

```bash
# Mess up formatting in a .tf file
cd terraform
echo 'variable "test"    {   type=string   }' >> test.tf

git add test.tf
git commit -m "test: intentional formatting error"
git push origin terraform-scripts

# The workflow will run and report format check failure (but won't fail the build)
# Clean up after testing:
git rm test.tf
git commit -m "test: cleanup"
git push origin terraform-scripts
```

## Verifying Workflow Success

After triggering the workflow, verify it works correctly:

### 1. Check Workflow Status

- Go to GitHub Actions tab
- Look for the "Terraform CI" workflow run
- Check that all steps show green checkmarks

### 2. Review Step Outputs

Click on the workflow run to see details for each step:

- **Terraform Format Check**: Should pass (or show warning if formatting is off)
- **Terraform Init**: Should succeed
- **Terraform Validate**: Should succeed
- **Terraform Plan**: May skip if AWS credentials aren't configured

### 3. Check PR Comments (for PRs)

If triggered by a PR, the workflow will post a comment showing:
- Status of each check (format, init, validate, plan)
- Full terraform plan output (in a collapsible section)

### 4. Review Summary

Click on the workflow run, then check the **Summary** tab to see:
- Overall status
- Terraform plan summary (last 20 lines)

## AWS Credentials Configuration

The workflow can run without AWS credentials (it will skip the plan step), but to get full functionality:

### Option 1: GitHub Secrets (Current Configuration)

Add these secrets to your GitHub repository:

1. Go to Settings > Secrets and variables > Actions
2. Add these repository secrets:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

**Security Note**: Use a dedicated IAM user with minimal permissions for CI/CD.

### Option 2: OIDC Authentication (More Secure)

For production environments, consider using AWS OIDC (no long-lived credentials):

1. Configure AWS IAM OIDC provider for GitHub
2. Update the workflow to use `role-to-assume` instead of access keys
3. See: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

## Workflow Features

### 🔒 Safety Features

- **No Auto-Apply**: Workflow only validates and plans, never applies
- **Concurrency Control**: Only one terraform workflow runs at a time
- **Continue on Error**: Format checks don't fail the build
- **Backend-less Init**: Doesn't require remote state access for basic validation

### ⚡ Performance Features

- **Conditional Steps**: Skips plan if no AWS credentials
- **Path Filters**: Only runs when terraform files change
- **Targeted Working Directory**: All operations run in ./terraform

### 📊 Observability Features

- **PR Comments**: Automatic plan posting to pull requests
- **Step Summaries**: GitHub Actions summary with key info
- **Detailed Logs**: Each step provides clear output
- **Status Badges**: Can be added to README

## Common Issues & Solutions

### Issue: "Terraform init failed - backend configuration required"

**Solution**: The workflow uses `-backend=false` for basic validation. If you need full initialization:
1. Ensure AWS credentials are configured
2. Modify the init step to remove `-backend=false`

### Issue: "AWS credentials not configured"

**Solution**: This is expected if you haven't set up AWS secrets yet. The workflow will still run format/validate checks.

### Issue: "Terraform plan not showing in PR"

**Solution**: Check:
1. AWS credentials are configured in repository secrets
2. The PR is targeting the `main` branch
3. The workflow has `write` permissions for pull-requests

### Issue: "Format check fails but I didn't change formatting"

**Solution**: Run locally:
```bash
cd terraform
terraform fmt -recursive
git add .
git commit -m "fix: apply terraform formatting"
git push
```

## Workflow Customization

### Change Terraform Version

Edit `.github/workflows/terraform.yml`:
```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: 1.9.0  # Change this version
```

### Add Additional Checks

Add steps after the validate step:
```yaml
- name: TFLint
  run: |
    curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
    tflint --init
    tflint
```

### Enable Auto-Format

To automatically fix formatting (not recommended for PRs):
```yaml
- name: Terraform Format
  run: terraform fmt -recursive
```

## Next Steps

### For Testing
1. ✅ Push a change to `terraform-scripts` branch
2. ✅ Verify workflow runs successfully
3. ✅ Check all steps pass (except plan if no AWS creds)

### For Production Use
1. ✅ Configure AWS credentials in GitHub Secrets
2. ✅ Test with a PR to main
3. ✅ Verify plan output appears in PR comments
4. ✅ Manually apply changes after review

### For Enhanced Security
1. Set up AWS OIDC instead of access keys
2. Add tfsec for security scanning
3. Enable required status checks in branch protection
4. Add CODEOWNERS file for terraform/ directory

## Resources

- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [AWS GitHub Actions](https://github.com/aws-actions/configure-aws-credentials)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

## Support

If you encounter issues:
1. Check the workflow logs in GitHub Actions
2. Review this guide for common solutions
3. Ensure AWS credentials are properly configured (if needed)
4. Verify terraform files are valid locally: `cd terraform && terraform validate`
