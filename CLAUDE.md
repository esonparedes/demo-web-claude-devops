# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A minimal Express.js application that renders a Google-like search UI and provides a demo JSON search API. The application uses EJS for templating and serves a single-page search interface with client-side result rendering.

## Architecture

**Server Structure (server.js:1)**
- Single-file Express server with two main routes
- Modular design: exports `app` for testing, but runs standalone when executed directly (server.js:32)
- No database or external services - returns hardcoded demo data

**Routing**
- `GET /`: Renders the search page (EJS template) with optional query parameter
- `GET /api/search?q=<query>`: Returns JSON with 5 fake search results
- Static files served from `/public` directory

**Frontend (views/index.ejs:1)**
- Server-side rendered EJS template
- Client-side fetch API call to `/api/search` when query exists (views/index.ejs:28)
- Results are rendered dynamically via JavaScript DOM manipulation

## Development Commands

```bash
# Install dependencies
npm install

# Start production server (port 3000)
npm start

# Start development server with NODE_ENV=development
npm run dev

# Run all tests with Jest
npm test

# Run tests in watch mode (not in package.json, but Jest supports it)
npx jest --watch

# Run a specific test file
npx jest tests/server.test.js
```

## Docker

```bash
# Build image
docker build -t demo-web-claude-devops .

# Run container
docker run -p 3000:3000 demo-web-claude-devops
```

The Dockerfile uses Node 20 Alpine, installs production dependencies only, and exposes port 3000.

## Testing

Tests use Jest + Supertest to validate:
1. Homepage returns 200 with "Google" text
2. Search API returns proper JSON structure with items
3. Empty query returns empty items array

Tests are located in `tests/server.test.js` and run with `--runInBand --detectOpenHandles` flags to prevent port conflicts and hanging processes.

## Port Configuration

Default port is 3000, configurable via `PORT` environment variable:
```bash
PORT=8080 npm start
```

## File Structure

```
server.js          # Main Express app and routes
views/index.ejs    # Search UI template
public/styles.css  # Google-like styling
tests/             # Jest test files
```
