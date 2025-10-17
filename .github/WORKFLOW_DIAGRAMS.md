# GitHub Actions Workflow Diagrams and Flow Charts

This document provides visual representations of the CI/CD pipeline workflows.

## Overall Pipeline Architecture

```
Developer
    |
    v
[Push Code to Branch]
    |
    v
[Create Pull Request to Main]
    |
    +---> CI Workflow (Automatic)
    |     ├─ Lint Code
    |     ├─ Run Tests (Node 18 & 20)
    |     └─ Build Docker Image
    |
    v
[Code Review & Approval]
    |
    v
[Merge PR to Main]
    |
    +---> CI Workflow (Again)
    |     ├─ Lint Code
    |     ├─ Run Tests
    |     └─ Build Docker Image
    |
    +---> CD Workflow (Automatic)
    |     ├─ Build Docker Image
    |     ├─ Push to AWS ECR
    |     └─ Update ECS Service
    |
    v
[Application Live with New Version]
```

## CI Workflow (Continuous Integration)

```
┌─────────────────────────────────────────────────────────┐
│                    CI Workflow Triggered                 │
│         (PR to main / Push to main / Manual dispatch)    │
└──────────────────────┬──────────────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         v                           v
    ┌─────────┐                 ┌──────────┐
    │ Node    │                 │ Node     │
    │ 18.x    │                 │ 20.x     │
    │ Matrix  │                 │ Matrix   │
    └────┬────┘                 └────┬─────┘
         │                           │
         v                           v
    ┌─────────────────────────┐  ┌─────────────────────────┐
    │ lint-and-test Job       │  │ lint-and-test Job       │
    ├─────────────────────────┤  ├─────────────────────────┤
    │ • Checkout code         │  │ • Checkout code         │
    │ • Setup Node 18.x       │  │ • Setup Node 20.x       │
    │ • npm ci                │  │ • npm ci (cached)       │
    │ • npm test              │  │ • npm test              │
    │ • Upload coverage       │  │ • Upload coverage       │
    └────┬────────────────────┘  └────┬───────────────────┘
         │                           │
         └─────────────┬─────────────┘
                       │
                       v
                  ┌──────────────┐
                  │ build-image  │
                  │ Job (Depends)│
                  └──────┬───────┘
                         │
                         v
                  ┌──────────────────────────┐
                  │ • Setup Docker Buildx    │
                  │ • Build image (cached)   │
                  │ • No push (PR only test) │
                  └──────┬───────────────────┘
                         │
                         v
              ┌───────────────────────┐
              │  ✓ CI Checks Passed   │
              │  (or ✗ Failed)        │
              └───────────────────────┘
```

**Duration**: 2-5 minutes
**Concurrent Runs**: Limited (cancel-in-progress: true)

## CD Workflow (Continuous Deployment)

```
┌─────────────────────────────────────────────────────────┐
│                   CD Workflow Triggered                  │
│          (Push to main / Manual dispatch only)           │
└──────────────────────┬──────────────────────────────────┘
                       │
                       v
        ┌──────────────────────────┐
        │  build-and-push Job      │
        ├──────────────────────────┤
        │ • Checkout code          │
        │ • Configure AWS creds    │
        │ • Login to ECR           │
        │ • Build Docker image     │
        │ • Tag: <SHA> + latest    │
        │ • Push to ECR            │
        │ • Output image URI       │
        └────────┬─────────────────┘
                 │
    Output: image-uri (for deploy job)
                 │
                 v
        ┌──────────────────────────┐
        │ deploy-to-ecs Job        │
        │ (Depends on build-and... )│
        │ (Environment gated)      │
        ├──────────────────────────┤
        │ • Checkout code          │
        │ • Configure AWS creds    │
        │ • Download task def      │
        │ • Update image in task   │
        │ • Register new revision  │
        │ • Update ECS service     │
        │ • Wait for stability     │
        └────────┬─────────────────┘
                 │
                 v
        ┌──────────────────────────┐
        │  ECS Service Updates     │
        │  • Create new task       │
        │  • Route traffic         │
        │  • Stop old tasks        │
        │  (5-10 min wait)         │
        └────────┬─────────────────┘
                 │
                 v
        ┌──────────────────────────┐
        │  ✓ Deployment Success    │
        │  App now live!           │
        └──────────────────────────┘
```

**Duration**: 5-15 minutes (mostly ECS stabilization)
**Concurrent Runs**: Sequential (cancel-in-progress: false)

## Pull Request Workflow

```
┌─────────────────────────────────────────────────────────┐
│                   Developer Creates PR                   │
│              (from feature branch to main)               │
└──────────────────────┬──────────────────────────────────┘
                       │
                       v
           ┌────────────────────────┐
           │  GitHub Actions Start  │
           │  CI Workflow           │
           └────────┬───────────────┘
                    │
         ┌──────────┴──────────┐
         │                     │
         v                     v
    ┌─────────┐           ┌─────────┐
    │ Tests   │           │ Linting │
    │ Running │           │ Running │
    └────┬────┘           └────┬────┘
         │                     │
         └──────────┬──────────┘
                    │
                    v
            ┌──────────────┐
            │ All Checks   │
            │ Passed?      │
            └──┬────────┬──┘
         Yes  │        │ No
             v         v
        ┌─────────┐ ┌──────────────┐
        │ Approve │ │ Reject/       │
        │ Button  │ │ Request       │
        │ Enabled │ │ Changes       │
        └────┬────┘ └──────┬───────┘
             │             │
             │             v
             │        ┌──────────────┐
             │        │ Developer    │
             │        │ Fixes Code   │
             │        └──────┬───────┘
             │               │
             └─────── Loop ──┘
                    if needed
             │
             v
        ┌─────────────────┐
        │ Merge to Main   │
        │ (If approved)   │
        └────────┬────────┘
                 │
                 v
        ┌─────────────────┐
        │ CD Workflow     │
        │ Starts          │
        │ (see above)     │
        └─────────────────┘
```

## Security Workflow

```
┌─────────────────────────────────────────────────────────┐
│              Security Workflow Triggered                 │
│  (Push to main / PR / Daily schedule / Manual dispatch) │
└──────────────────────┬──────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
         v             v             v
    ┌─────────┐   ┌──────────┐   ┌──────────┐
    │ npm     │   │ Trivy    │   │ CodeQL   │
    │ audit   │   │ scan     │   │ Analysis │
    │ Job     │   │ Job      │   │ Job      │
    └────┬────┘   └────┬─────┘   └────┬─────┘
         │             │             │
         v             v             v
    ┌─────────────────────────────────────┐
    │ Findings reported to GitHub         │
    │ Security tab                        │
    │ • Fail on high/critical vulns       │
    │ • Create issues if needed           │
    │ • PR checks can be blocked          │
    └─────────────────────────────────────┘
```

**Duration**: 3-10 minutes
**Runs**: Daily at 2 AM UTC + on PR/push

## Job Dependencies Graph

```
CI Workflow Job Dependencies:

  lint-and-test[node18]  →  ┐
                             ├→ build-image
  lint-and-test[node20]  →  ┘
                             │
                             v
                        (All passed, can merge to main)


CD Workflow Job Dependencies:

  build-and-push ────→ deploy-to-ecs
     (Outputs image URI for deployment job)
```

## Environment Gating (After Configuration)

```
┌─────────────────────────────────────────────────────────┐
│        CD Workflow with Environment Protection          │
└──────────────────────┬──────────────────────────────────┘
                       │
                       v
           ┌────────────────────────┐
           │  Build and Push Job    │
           │  (No approval needed)  │
           └────────┬───────────────┘
                    │
                    v
        ┌───────────────────────────┐
        │   Deploy-to-ECS Job       │
        │   Environment: production │
        └─────────┬─────────────────┘
                  │
         ┌────────v────────┐
         │ Check Required  │
         │ Reviewers       │
         └────────┬────────┘
                  │
    ┌─────────────┴─────────────┐
    │                           │
    v                           v
┌────────────┐            ┌──────────────┐
│ Reviewer 1 │            │ Reviewer 2   │
│ Approves?  │            │ Approves?    │
└────┬───────┘            └────┬─────────┘
     │                         │
     └──────────┬──────────────┘
                │
    Both must approve
                │
                v
        ┌────────────────┐
        │ Proceed with   │
        │ Deployment     │
        └────────────────┘
```

## Secret Data Flow

```
┌──────────────────────────────────────────────────────────┐
│              GitHub Repository Settings                  │
│            Secrets and variables section                 │
│  (AWS credentials stored encrypted at rest)              │
└────────────────┬─────────────────────────────────────────┘
                 │
                 │ Referenced in workflow
                 │ (as ${{ secrets.SECRET_NAME }})
                 v
        ┌────────────────────┐
        │ GitHub Actions     │
        │ Runner             │
        └────────┬───────────┘
                 │
     ┌───────────┼───────────┐
     │           │           │
     v           v           v
┌─────────┐ ┌─────────┐ ┌──────────┐
│ AWS CLI │ │ Docker  │ │ Configure│
│         │ │ Login   │ │ Creds    │
└────┬────┘ └────┬────┘ └────┬─────┘
     │           │           │
     └─────┬─────┴─────┬─────┘
           │           │
           v           v
     ┌──────────────────────┐
     │ AWS Services         │
     │ • ECR (Push images)  │
     │ • ECS (Deploy)       │
     └──────────────────────┘
```

## Caching Strategy

```
First Run:
  1. Checkout code
  2. Download dependencies (npm ci) → SLOW ~30 seconds
  3. Cache created and stored
  4. Run tests

Subsequent Runs:
  1. Checkout code
  2. Restore cache → FAST ~2 seconds
  3. npm ci uses cached modules
  4. Run tests

Cache Key: hash of package-lock.json
Cache invalidated when: package-lock.json changes
```

## Common Workflow Scenarios

### Scenario 1: Simple Bug Fix

```
1. Create branch: git checkout -b fix/bug-123
2. Fix code, run tests locally
3. git push origin fix/bug-123
4. Create PR on GitHub
   → CI workflow runs automatically
   → Tests run, Docker builds
   → PR status shows: Checks pending
   → When done: Checks show ✓ All passed
5. Reviewer approves PR
6. Merge to main
   → CI runs again (automatic)
   → CD runs (automatic)
   → CD deploys to ECS
   → Your fix is live!
```

### Scenario 2: Production Hotfix with Manual Approval

```
1. Create branch: git checkout -b hotfix/critical
2. Implement fix
3. git push and create PR
   → CI runs, checks pass
4. Merge to main
   → CI runs
   → CD starts
   → Build and push succeeds
   → Deploy job pauses waiting for approval
5. Required reviewers notified via GitHub
6. Reviewer reviews and approves in GitHub Actions UI
   → Deployment continues
   → Fix is live in production
```

### Scenario 3: Dependency Update

```
1. Dependabot creates PR with update
2. CI workflow runs automatically
   → Tests pass or fail
3. If passing:
   → Review changes
   → Auto-approve and merge (optional)
   → CD deploys new version
4. If failing:
   → Review error
   → Fix compatibility issue
   → Push fix
   → CI runs again
   → Merge when passing
```

## Performance Timeline

### CI Workflow Timeline

```
0:00 - Start
0:15 - Checkout complete
0:20 - Setup Node.js (18 & 20 in parallel)
0:30 - Cache restored (dependencies)
0:45 - npm install (from cache)
1:00 - Tests start (both versions in parallel)
2:30 - Tests complete
2:45 - Docker build starts
3:45 - Docker build complete
4:00 - End
─────────────────────────────
Total: 4 minutes (typical)
```

### CD Workflow Timeline

```
0:00 - Start
0:15 - Checkout complete
0:20 - AWS credentials configured
0:30 - ECR login
0:35 - Docker build starts
1:30 - Docker build complete
2:00 - Push to ECR (both SHA and latest tags)
3:00 - Task definition download
3:15 - Task definition updated
3:30 - New revision registered
3:45 - Service update starts
4:00 - New tasks launching
8:00 - Old tasks draining
10:00 - Service stable, deployment complete
─────────────────────────────
Total: 10 minutes (typical with stabilization)
```

## Concurrency Control

```
┌─────────────────────────────────────────────────┐
│            CI Workflow Concurrency              │
│         (cancel-in-progress: true)              │
├─────────────────────────────────────────────────┤
│ Run 1: Started 10:00                            │
│ Run 2: Started 10:05 → CANCELS Run 1            │
│ Only Run 2 completes                            │
│ Use case: Fast feedback on latest push          │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│           CD Workflow Concurrency               │
│        (cancel-in-progress: false)              │
├─────────────────────────────────────────────────┤
│ Run 1: Deploy v1.0 started 10:00                │
│ Run 2: Deploy v1.1 started 10:05 → WAITS        │
│ Run 1 completes at 10:10                        │
│ Run 2 begins 10:10                              │
│ Run 2 completes at 10:20                        │
│ Use case: Prevent concurrent deployments       │
└─────────────────────────────────────────────────┘
```

## Error Recovery Paths

```
Test Failure:
  ├─ CI marks PR as failing
  ├─ PR blocks merge
  └─ Developer fixes code locally
     └─ Push fix to branch
        └─ CI runs again
           └─ If passing, PR can merge

Build Failure:
  ├─ CD stops at build-and-push
  ├─ PR already merged
  ├─ Notification appears
  └─ Developer investigates logs
     └─ Fix pushed to new branch
        └─ Normal PR process again

Deploy Failure:
  ├─ CD rolls back automatically
  │  (if configured in ECS service)
  ├─ Previous task definition still running
  ├─ Manual rollback option available
  └─ Investigation and fix
     └─ Re-deploy when ready
```

---

These diagrams provide visual reference for understanding how the workflows interact and flow.
