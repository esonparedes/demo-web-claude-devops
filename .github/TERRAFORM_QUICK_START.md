# Terraform Workflow - Quick Start

## 🚀 Test the Workflow in 3 Steps

### Step 1: Test Locally (Optional but Recommended)

```bash
# Run the local test script to validate before pushing
./scripts/test-terraform-locally.sh
```

This simulates what the GitHub Actions workflow will do.

### Step 2: Trigger the Workflow

Choose one method:

#### Method A: Push to terraform-scripts (Easiest)
```bash
# You're already on terraform-scripts branch
git add .github/workflows/terraform.yml
git commit -m "feat: add terraform ci workflow"
git push origin terraform-scripts
```

#### Method B: Manual Trigger
1. Go to: `https://github.com/<your-username>/demo-web-claude-devops/actions`
2. Click "Terraform CI" workflow
3. Click "Run workflow"
4. Select branch and click "Run workflow"

#### Method C: Create a Test PR
```bash
git checkout -b test-terraform-ci
echo "# Test" >> terraform/README.md
git add terraform/README.md
git commit -m "test: verify terraform ci"
git push origin test-terraform-ci
# Then create PR on GitHub targeting 'main'
```

### Step 3: Verify Results

1. Go to GitHub Actions: `https://github.com/<your-username>/demo-web-claude-devops/actions`
2. Click on the latest "Terraform CI" workflow run
3. Verify all steps are green ✅

Expected results:
- ✅ Terraform Format Check
- ✅ Terraform Init
- ✅ Terraform Validate
- ⚠️  Terraform Plan (will skip if AWS credentials not configured)

## 📋 What the Workflow Does

| Step | Command | Purpose | Fails Workflow? |
|------|---------|---------|-----------------|
| Format Check | `terraform fmt -check` | Ensures consistent formatting | No (warning only) |
| Init | `terraform init -backend=false` | Downloads providers | Yes |
| Validate | `terraform validate` | Checks syntax & config | Yes |
| Plan | `terraform plan` | Shows proposed changes | No (skipped if no AWS creds) |

**Important**: The workflow **NEVER runs `terraform apply`** - it only validates and plans.

## 🔧 Configure AWS Credentials (Optional)

To enable the plan step, add AWS credentials to GitHub:

1. Go to repository Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Add:
   - Name: `AWS_ACCESS_KEY_ID`, Value: `your-access-key-id`
   - Name: `AWS_SECRET_ACCESS_KEY`, Value: `your-secret-access-key`

Without these, the workflow still runs but skips the plan step.

## 🐛 Troubleshooting

### Format Check Fails?
```bash
cd terraform
terraform fmt -recursive
git add .
git commit -m "fix: apply terraform formatting"
git push
```

### Validate Fails?
```bash
cd terraform
terraform validate
# Fix any errors shown
```

### Workflow Not Triggering?
- Ensure you're pushing to `terraform-scripts` branch or creating PR to `main`
- Check that terraform files were modified
- Verify `.github/workflows/terraform.yml` exists

## 📚 Full Documentation

For detailed information, see:
- **Full Guide**: `.github/TERRAFORM_WORKFLOW.md`
- **Workflow File**: `.github/workflows/terraform.yml`
- **Local Test Script**: `./scripts/test-terraform-locally.sh`

## 🎯 Quick Commands

```bash
# Test locally before pushing
./scripts/test-terraform-locally.sh

# Format terraform files
cd terraform && terraform fmt -recursive

# Validate configuration
cd terraform && terraform validate

# Check workflow status (replace with your repo URL)
open https://github.com/<username>/demo-web-claude-devops/actions
```

## ✅ Success Checklist

- [ ] Workflow file created at `.github/workflows/terraform.yml`
- [ ] Tested locally with `./scripts/test-terraform-locally.sh`
- [ ] Pushed changes to trigger workflow
- [ ] Verified workflow runs successfully on GitHub Actions
- [ ] (Optional) Configured AWS credentials in GitHub Secrets
- [ ] (Optional) Created a test PR and verified plan comments

## 🎓 What's Next?

1. **For testing**: Keep pushing to `terraform-scripts` branch
2. **For production**: Create PRs to `main` branch
3. **For security**: Consider AWS OIDC instead of access keys
4. **For enhancement**: Add additional checks (tfsec, tflint, etc.)

---

**Need help?** Check the full guide in `.github/TERRAFORM_WORKFLOW.md`
