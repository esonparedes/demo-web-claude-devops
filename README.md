# Demo: Google-like search UI

Minimal Express app that renders a Google-like homepage and serves a tiny JSON search API for demo/testing.

Quick start

1. Install dependencies

```bash
npm install
```

2. Run app

```bash
npm start
# then open http://localhost:3000
```

Run tests

```bash
npm test
```

Docker

Build image:

```bash
docker build -t demo-web-claude-devops .
```

Run:

```bash
docker run -p 3000:3000 demo-web-claude-devops
```

Security & vulnerabilities

This project uses a minimal set of dependencies and pins versions in package.json. For production use, run `npm audit` and keep dependencies updated.