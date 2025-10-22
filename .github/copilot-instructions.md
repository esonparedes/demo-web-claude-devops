## Purpose

Short, specific guidance for AI coding agents working in this repository. Focus on what to edit, how to run and test, and where infra/workflows live.

## Big picture (quick)
- App: minimal Express.js app (server.js) that serves an EJS UI (`views/index.ejs`) and a tiny JSON API at `/api/search`.
- Container & CI: app is containerized (Dockerfile) and validated in CI (Jest tests + SonarQube quality gate).
- Infra: Terraform under `terraform/` deploys the app to AWS ECS Fargate (ECR, ALB, CloudWatch, IAM). See `terraform/main.tf` and `terraform/README.md` for details.

## Files you should know first (sources of truth)
- `server.js` — main Express app; exports `app` for tests. Edit routes and API here.
- `views/index.ejs`, `public/styles.css` — frontend template + styles.
- `tests/server.test.js` — Jest + Supertest tests that run in CI.
- `package.json` — scripts: `npm start`, `npm run dev`, `npm test` (Jest runs with `--runInBand --detectOpenHandles`).
- `Dockerfile` — production image (Node 20 Alpine), exposes port `3000`.
- `terraform/` — all infra: `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, and `deploy.sh` (build/push to ECR).
- `CLAUDE.md`, `README.md`, `terraform/README.md` — higher-level project notes used by humans and agents.

## How to run & test locally (examples agents can use)
- Install: `npm install`
- Start (prod-mode): `npm start` (default port 3000)
- Start (dev): `npm run dev`
- Run tests: `npm test` (Jest already configured; tests import `app` from `server.js`)
- Docker build: `docker build -t demo-web-claude-devops .` (Dockerfile exposes 3000)

Notes: tests use the exported `app` so you should avoid launching a separate server in tests. Use `supertest` against the exported app.

## Terraform & deploy (examples)
- Edit `terraform/terraform.tfvars` or copy `terraform/terraform.tfvars.example` and set AWS values (region, project_name, environment, app_port).
- Typical flow:
  - cd `terraform/`
  - `terraform init`
  - `terraform plan` / `terraform apply`
  - Use `terraform/deploy.sh` to build/push Docker images into ECR before applying if you want the latest image pushed.
- To override image without changing tfvars: `terraform apply -var='container_image=<ACCOUNT_ID>.dkr.ecr.<region>.amazonaws.com/<repo>:tag'`

## Common patterns & conventions (project-specific)
- Resource naming in Terraform consistently uses `var.project_name` + `var.environment` (look at `main.tf`).
- App port is controlled in two places: Node app reads `process.env.PORT || 3000`; Terraform uses `app_port` variable — keep them in sync when changing port.
- Logging: CloudWatch log group is enabled by `enable_logging` variable in Terraform; task definitions reference `/ecs/${var.project_name}-${var.environment}`.
- Tests expect deterministic, fast responses — keep `/api/search` behavior predictable for test changes.

## CI / Quality gates to respect
- GitHub Actions runs Jest and SonarQube scans. The repo enforces a SonarQube quality gate that can block Docker pushes and releases. Don't push or open release PRs if tests or Sonar checks fail.

## Typical edit workflows for agents
- Small change to server/API: update `server.js`, run `npm test`. If changing responses used by the UI, update `views/index.ejs` or client script if needed.
- Build + release image: update code, run `terraform/deploy.sh` (in `terraform/`) to build and push image to ECR, then `terraform apply` to deploy.
- Infra changes: modify files under `terraform/` and run `terraform fmt`, `terraform validate`, `terraform plan` before `apply`.

## Safety & boundaries
- Do NOT commit secrets or real credentials. Terraform variable files with secrets should not be committed — follow `terraform/README.md` guidance.
- Prefer non-breaking changes to public APIs (routes under `/api/`) because CI and downstream infra expect stable contract.

## Where to look for more context
- `CLAUDE.md` — an agent-focused high-level overview already present in the repo.
- `terraform/README.md` and `DEPLOYMENT.md` — detailed infra and deployment steps.

If anything above is unclear or a section is missing examples you need, tell me which part you want expanded and I will iterate.
