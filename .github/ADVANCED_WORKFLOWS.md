# Advanced GitHub Actions Workflows

This document provides optional enhancements and advanced configurations for the CI/CD pipeline.

## Table of Contents

1. [Manual Approval Workflows](#manual-approval-workflows)
2. [Multi-Environment Deployments](#multi-environment-deployments)
3. [Automated Dependency Updates](#automated-dependency-updates)
4. [Performance Monitoring](#performance-monitoring)
5. [Cost Optimization](#cost-optimization)
6. [Advanced Docker Strategies](#advanced-docker-strategies)

## Manual Approval Workflows

For production deployments, implement manual approval gates using GitHub Environments.

### Setup

1. Create environments in Settings > Environments:
   - `staging`
   - `production`

2. For production environment:
   - Click "Add rule"
   - Select required reviewers
   - Restrict to main branch

3. Modified `cd.yml` with environment protection:

```yaml
deploy-to-ecs:
  name: Deploy to ECS
  runs-on: ubuntu-latest
  needs: build-and-push

  environment:
    name: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
    url: https://your-app-url.com

  steps:
    # ... deployment steps ...
```

### Workflow

1. Code is merged to main
2. Image is built and pushed
3. Workflow pauses waiting for approval
4. Assigned reviewers are notified
5. Reviewer approves in Actions tab or Actions API
6. Deployment proceeds

## Multi-Environment Deployments

Deploy to different environments based on branch or manual selection.

### Separate Workflow per Environment

Create `cd-production.yml` and `cd-staging.yml`:

```yaml
name: CD - Deploy to Production

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-and-push:
    # ... build job (same as cd.yml) ...

  deploy-to-production:
    name: Deploy to Production ECS
    needs: build-and-push
    environment:
      name: production
    runs-on: ubuntu-latest

    env:
      ECS_CLUSTER: production-cluster
      ECS_SERVICE: demo-web-production
      ECS_TASK_DEFINITION: demo-web-production

    steps:
      # ... deployment steps ...
```

### Matrix-Based Multi-Environment

Use a single workflow with matrix strategy:

```yaml
jobs:
  deploy:
    name: Deploy to ${{ matrix.environment }}
    needs: build-and-push

    strategy:
      matrix:
        include:
          - environment: staging
            cluster: staging-cluster
            service: demo-web-staging
            task-def: demo-web-staging
          - environment: production
            cluster: production-cluster
            service: demo-web-production
            task-def: demo-web-production

    environment:
      name: ${{ matrix.environment }}

    env:
      ECS_CLUSTER: ${{ matrix.cluster }}
      ECS_SERVICE: ${{ matrix.service }}
      ECS_TASK_DEFINITION: ${{ matrix.task-def }}
```

## Automated Dependency Updates

### Using Dependabot

Enable in Settings > Code security and analysis > Dependabot:

1. **Version updates** - Automatically update dependencies
2. **Security updates** - Automatically update security patches

Configure `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: npm
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "03:00"
    open-pull-requests-limit: 10
    reviewers:
      - your-github-handle

  - package-ecosystem: docker
    directory: "/"
    schedule:
      interval: "weekly"
    registries:
      - ecr

  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: "weekly"
```

### Example Dependabot PR Workflow

Auto-approve and merge Dependabot PRs (optional):

```yaml
name: Dependabot Auto-Merge

on: pull_request

permissions:
  pull-requests: write
  contents: write

jobs:
  dependabot:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'

    steps:
      - name: Approve PR
        run: gh pr review --approve "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Merge PR
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Performance Monitoring

### Add Performance Benchmarks

Track build and test performance over time:

```yaml
name: Performance Monitoring

on:
  push:
    branches: [main]

jobs:
  benchmark:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20.x'
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Measure test execution time
        id: test-time
        run: |
          start_time=$(date +%s)
          npm test
          end_time=$(date +%s)
          elapsed=$((end_time - start_time))
          echo "elapsed=$elapsed" >> $GITHUB_OUTPUT

      - name: Measure Docker build time
        id: build-time
        run: |
          start_time=$(date +%s)
          docker build -t test-build .
          end_time=$(date +%s)
          elapsed=$((end_time - start_time))
          echo "elapsed=$elapsed" >> $GITHUB_OUTPUT

      - name: Comment on commit
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.repos.createCommitComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              commit_sha: context.sha,
              body: `Performance Metrics:
              - Tests: ${{ steps.test-time.outputs.elapsed }}s
              - Docker Build: ${{ steps.build-time.outputs.elapsed }}s`
            })
```

## Cost Optimization

### 1. Use Self-Hosted Runners

For high-volume deployments, self-hosted runners reduce costs:

```yaml
runs-on: [self-hosted, linux, docker]
```

Setup: Settings > Actions > Runners > New self-hosted runner

### 2. Selective Workflow Triggers

Only run expensive workflows when needed:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'Dockerfile'
      - 'package*.json'
      - '.github/workflows/cd.yml'
```

### 3. Scheduled Cleanup

Remove old artifacts to save storage costs:

```yaml
name: Cleanup Old Artifacts

on:
  schedule:
    - cron: '0 0 * * *'

jobs:
  cleanup:
    runs-on: ubuntu-latest

    steps:
      - name: Remove artifacts older than 30 days
        uses: geekyeggo/delete-artifact@v2
        with:
          name: '*'
          minAgeInDays: 30
```

### 4. Optimize Docker Builds

Use buildx caching for faster subsequent builds:

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
  with:
    buildkitd-flags: --debug

- name: Build with optimal caching
  uses: docker/build-push-action@v5
  with:
    context: .
    cache-from: type=registry,ref=your-registry/demo-web:buildcache
    cache-to: type=registry,ref=your-registry/demo-web:buildcache,mode=max
    push: true
```

## Advanced Docker Strategies

### 1. Multi-Stage Build Optimization

Dockerfile with optimized layers:

```dockerfile
# Stage 1: Dependencies
FROM node:20-alpine as deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Builder
FROM node:20-alpine as builder
WORKDIR /app
COPY package*.json ./
RUN npm ci

# Stage 3: Production
FROM node:20-alpine
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"
CMD ["node", "server.js"]
```

### 2. Image Scanning with Trivy

Fail deployment on high-severity vulnerabilities:

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
    format: 'json'
    output: 'trivy-results.json'
    severity: 'HIGH,CRITICAL'

- name: Check Trivy results
  run: |
    if grep -q '"Severity":"CRITICAL"' trivy-results.json; then
      echo "Critical vulnerabilities found!"
      exit 1
    fi
```

### 3. Image Signing with Cosign

Sign images for supply chain security:

```yaml
- name: Install Cosign
  uses: sigstore/cosign-installer@v3

- name: Sign image
  env:
    COSIGN_EXPERIMENTAL: 1
  run: |
    cosign sign --yes ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
```

### 4. SBOM (Software Bill of Materials) Generation

Generate SBOM for vulnerability tracking:

```yaml
- name: Generate SBOM with Syft
  uses: anchore/sbom-action@v0
  with:
    image: ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
    format: cyclonedx-json
    output-file: sbom.json

- name: Upload SBOM
  uses: actions/upload-artifact@v3
  with:
    name: sbom
    path: sbom.json
```

## Deployment Status Dashboard

Track deployments with custom GitHub Actions output:

```yaml
- name: Create deployment
  uses: actions/github-script@v7
  with:
    script: |
      const deployment = await github.rest.repos.createDeployment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        ref: context.ref,
        environment: 'production',
        required_contexts: [],
        auto_merge: false,
      });

      await github.rest.repos.createDeploymentStatus({
        owner: context.repo.owner,
        repo: context.repo.repo,
        deployment_id: deployment.data.id,
        state: 'success',
        environment_url: 'https://your-app-url.com',
        description: 'Successfully deployed to production',
      });
```

## Slack/Teams Notifications

### Slack Integration

```yaml
- name: Notify Slack on success
  if: success()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Deployment Successful",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Deploy to ECS* succeeded\n*Commit:* <${{ github.event.head_commit.url }}|${{ github.event.head_commit.message }}>\n*Author:* ${{ github.event.head_commit.author.name }}"
            }
          }
        ]
      }

- name: Notify Slack on failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Deployment Failed",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Deploy to ECS* FAILED\n*Run:* <${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Logs>\n*Branch:* ${{ github.ref_name }}"
            }
          }
        ]
      }
```

### Microsoft Teams Integration

```yaml
- name: Notify Teams
  if: always()
  uses: jdcargile/ms-teams-notification@v1.3
  with:
    github-token: ${{ github.token }}
    ms-teams-webhook-uri: ${{ secrets.TEAMS_WEBHOOK_URI }}
    notification-color: ${{ job.status == 'success' && '28a745' || 'dc3545' }}
```

## Summary

These advanced strategies provide:

- **Higher reliability**: Approval gates prevent bad deployments
- **Better visibility**: Performance monitoring and notifications
- **Enhanced security**: Image signing, SBOM, vulnerability scanning
- **Cost efficiency**: Selective triggers, artifact cleanup, self-hosted runners
- **Scalability**: Multi-environment support for growth

Choose the enhancements most relevant to your deployment needs.
