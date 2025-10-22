# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the demo-web-claude-devops project.

## Available Workflows

### 1. Terraform CI (`terraform.yml`)
**Purpose**: Validates Terraform infrastructure code automatically

**Triggers**:
- Pull requests to `main` branch
- Pushes to `terraform-scripts` branch
- Manual dispatch via GitHub Actions UI

**What it does**:
```
Checkout → Setup Terraform → Format Check → Init → Validate → Plan → Post Results
```

**Documentation**:
- Quick Start: `../.github/TERRAFORM_QUICK_START.md`
- Full Guide: `../.github/TERRAFORM_WORKFLOW.md`
- Setup Summary: `../.github/TERRAFORM_SETUP_COMPLETE.md`

**Key Features**:
- ✅ Never runs `terraform apply` (safety first)
- ✅ Posts plan results as PR comments
- ✅ Runs without AWS credentials (skips plan step)
- ✅ Validates formatting, syntax, and configuration

---

### 2. CI Pipeline (`ci.yml`)
**Purpose**: Tests the Express.js application

**Triggers**: [Details based on existing workflow]

---

### 3. CD Pipeline (`cd.yml`)
**Purpose**: Deploys the application

**Triggers**: [Details based on existing workflow]

---

### 4. Security Scanning (`security.yml`)
**Purpose**: Performs security checks

**Triggers**: [Details based on existing workflow]

---

## Workflow Status

You can view the status of all workflows at:
`https://github.com/<your-username>/demo-web-claude-devops/actions`

## Adding New Workflows

1. Create a new `.yml` file in this directory
2. Define triggers, jobs, and steps
3. Test with `workflow_dispatch` trigger first
4. Document in this README
5. Follow existing patterns for consistency

## Best Practices

- Pin action versions for security and stability
- Use minimal permissions for GITHUB_TOKEN
- Add path filters to prevent unnecessary runs
- Include clear step names and descriptions
- Test locally before pushing (when possible)
- Document required secrets and setup steps
