# Terraform Workflow - Test Checklist

Use this checklist to verify your Terraform CI workflow is working correctly.

## Pre-Testing Setup

- [x] Workflow file created: `.github/workflows/terraform.yml`
- [x] Documentation files created
- [x] Local test script created: `scripts/test-terraform-locally.sh`
- [ ] All files committed to git
- [ ] Files pushed to `terraform-scripts` branch

## Phase 1: Local Testing

### Test 1: Run Local Validation Script
```bash
cd /workspaces/demo-web-claude-devops
./scripts/test-terraform-locally.sh
```

**Expected Results**:
- [ ] Script runs without errors
- [ ] Terraform installation check: ✓ PASSED
- [ ] Format check: ✓ PASSED
- [ ] Terraform init: ✓ PASSED
- [ ] Terraform validate: ✓ PASSED
- [ ] Terraform plan: ✓ PASSED (Skipped if no AWS creds)
- [ ] "All checks passed!" message displayed

**If any check fails**: Fix the issue before proceeding to GitHub testing.

---

## Phase 2: GitHub Actions Testing

### Test 2: Push to terraform-scripts Branch
```bash
# Add all new files
git add .github/workflows/terraform.yml
git add .github/TERRAFORM*.md
git add scripts/test-terraform-locally.sh
git add scripts/README.md

# Commit
git commit -m "feat: add terraform ci workflow with documentation"

# Push (this triggers the workflow)
git push origin terraform-scripts
```

**Expected Results**:
- [ ] Push succeeds without errors
- [ ] GitHub Actions workflow triggers automatically

### Test 3: Verify Workflow Execution
Go to: `https://github.com/<your-username>/demo-web-claude-devops/actions`

**Check**:
- [ ] "Terraform CI" workflow appears in the list
- [ ] Workflow run is triggered (shows as running or completed)
- [ ] Click on the workflow run to see details

### Test 4: Review Workflow Steps
In the workflow run details, verify each step:

- [ ] **Checkout code**: ✅ Green checkmark
- [ ] **Setup Terraform**: ✅ Green checkmark
- [ ] **Terraform Format Check**: ✅ Green checkmark (or yellow warning)
- [ ] **Terraform Init**: ✅ Green checkmark
- [ ] **Terraform Validate**: ✅ Green checkmark
- [ ] **Configure AWS Credentials**: ⚠️ May skip (if no AWS secrets)
- [ ] **Terraform Plan**: ✅ Green checkmark (or skipped)
- [ ] **Check Results**: ✅ Green checkmark
- [ ] **Validation Success**: ✅ Green checkmark

**If any required step fails**: Click on it to see error details, fix the issue, and push again.

---

## Phase 3: Pull Request Testing (Optional)

### Test 5: Create a Test PR
```bash
# Create a test branch
git checkout -b test-terraform-workflow

# Make a small change
echo "# Terraform CI Test" >> terraform/README.md
git add terraform/README.md
git commit -m "test: verify terraform ci on pull request"
git push origin test-terraform-workflow
```

Then on GitHub:
1. Go to Pull Requests
2. Click "New pull request"
3. Base: `main`, Compare: `test-terraform-workflow`
4. Create the PR

**Expected Results**:
- [ ] Workflow runs automatically on PR creation
- [ ] Workflow status appears in PR checks section
- [ ] Workflow posts a comment with plan results (if AWS configured)

### Test 6: Review PR Workflow Output
In the PR page, check:

- [ ] Status check shows "Terraform CI" workflow
- [ ] Click "Details" to see workflow logs
- [ ] All steps complete successfully
- [ ] (If AWS configured) Comment appears with:
  - Format check status
  - Init status
  - Validate status
  - Plan output (in collapsible section)

---

## Phase 4: Manual Trigger Testing (Optional)

### Test 7: Manual Workflow Dispatch
1. Go to Actions tab on GitHub
2. Click "Terraform CI" in the left sidebar
3. Click "Run workflow" button
4. Select branch: `terraform-scripts`
5. Select action: `plan` (default)
6. Click "Run workflow"

**Expected Results**:
- [ ] Workflow starts within a few seconds
- [ ] All steps execute successfully
- [ ] Can view logs and results

---

## Phase 5: AWS Integration Testing (Optional)

### Test 8: Configure AWS Credentials
Only if you want to test the plan step with real AWS:

1. Go to Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add `AWS_ACCESS_KEY_ID` with your AWS access key
4. Add `AWS_SECRET_ACCESS_KEY` with your AWS secret key

### Test 9: Test with AWS Credentials
```bash
# Make a small change to trigger workflow
echo "# Test with AWS" >> terraform/README.md
git add terraform/README.md
git commit -m "test: verify terraform plan with aws credentials"
git push origin terraform-scripts
```

**Expected Results**:
- [ ] Workflow runs automatically
- [ ] "Configure AWS Credentials" step succeeds
- [ ] "Terraform Plan" step succeeds (not skipped)
- [ ] Plan output shows actual AWS resources
- [ ] No errors about missing credentials

---

## Phase 6: Error Handling Testing (Optional)

### Test 10: Test Format Check Failure
```bash
# Create a file with bad formatting
cd terraform
echo 'variable "test"    {   type=string   }' >> test_bad_format.tf

git add test_bad_format.tf
git commit -m "test: intentional format error"
git push origin terraform-scripts
```

**Expected Results**:
- [ ] Workflow runs
- [ ] Format check shows warning (⚠️) but doesn't fail
- [ ] Other steps continue and succeed

**Cleanup**:
```bash
git rm test_bad_format.tf
git commit -m "test: cleanup format test"
git push origin terraform-scripts
```

### Test 11: Test Validation Failure
```bash
# Create a file with invalid Terraform syntax
cd terraform
echo 'invalid terraform syntax here' >> test_invalid.tf

git add test_invalid.tf
git commit -m "test: intentional validation error"
git push origin terraform-scripts
```

**Expected Results**:
- [ ] Workflow runs
- [ ] Format and init steps succeed
- [ ] Validate step fails (❌)
- [ ] Workflow overall status: Failed
- [ ] Clear error message explaining the validation error

**Cleanup**:
```bash
git rm test_invalid.tf
git commit -m "test: cleanup validation test"
git push origin terraform-scripts
```

---

## Success Criteria

Your Terraform CI workflow is fully operational when:

### Required Tests
- [x] Local validation script runs successfully
- [ ] Workflow triggers on push to terraform-scripts
- [ ] All workflow steps complete (format, init, validate)
- [ ] Workflow status shows success on GitHub
- [ ] Error handling works (format warnings don't fail build)

### Optional Tests
- [ ] PR comments work (if AWS configured)
- [ ] Manual workflow dispatch works
- [ ] AWS plan step works (if credentials configured)
- [ ] Format check catches issues
- [ ] Validate check catches syntax errors

---

## Troubleshooting

### Issue: Local script fails
**Solution**: Check terraform installation, fix any syntax errors in .tf files

### Issue: Workflow doesn't trigger on push
**Solution**:
- Verify you're on `terraform-scripts` branch
- Ensure `.github/workflows/terraform.yml` exists
- Check that terraform files were modified in the commit

### Issue: Workflow triggers but fails immediately
**Solution**:
- Check workflow syntax (YAML indentation)
- Review error in workflow logs
- Verify terraform files are valid

### Issue: Plan step always skipped
**Solution**: This is normal if AWS credentials aren't configured. To enable:
- Add AWS secrets to repository settings
- Or continue using workflow without plan step

### Issue: Workflow runs forever
**Solution**:
- Check if terraform init is hanging
- Verify no prompts are waiting for input
- Cancel workflow and check terraform configuration

---

## Final Verification

Once all required tests pass:

✅ Your Terraform CI workflow is ready for production use!

**Next Steps**:
1. Enable branch protection requiring workflow success
2. Configure AWS credentials for full plan functionality
3. Add workflow status badge to README
4. Consider adding additional checks (tfsec, tflint)
5. Set up notifications for workflow failures

---

**Questions?** See the full guide: `.github/TERRAFORM_WORKFLOW.md`
