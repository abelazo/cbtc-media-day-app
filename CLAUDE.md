# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CBTC Media Day is a serverless AWS application for managing and distributing media day photos. It's a monorepo containing Lambda services, Terraform infrastructure, and a React frontend.

## Build & Development Commands

All commands use `just` (a command runner). Run `just --list` to see all available recipes.

### Setup & Dependencies
```bash
just sync-all                     # Install all Python dependencies (uv workspaces)
just sync authorizer              # Install authorizer dependencies
just sync content_service         # Install content_service dependencies
just app::install                 # Install frontend dependencies (bun)
```

### Testing
```bash
# Backend unit tests
just services::test-all
just services::content::test
just services::authorizer::test

# Single test file or function (navigate to package first)
cd services/authorizer && uv run pytest tests/test_authorizer.py::TestClass::test_fn -v

# E2E tests (requires LocalStack running)
just e2e::run
just e2e::run-story us_004        # Single user story
```

### Run
```bash
just services::authorizer::run              # Run authorizer locally
just app::dev                               # Start frontend dev server
```

### Code Quality
```bash
just services::lint-all           # ruff + black --check
just services::format-all         # black + ruff --fix
just app::lint
```

### Building & Deployment
```bash
just services::build-all          # Build all Lambda packages
just infra::global::apply local   # Deploy global infra to LocalStack
just infra::services::apply local # Deploy services to LocalStack
```

### Local Development with LocalStack
```bash
just infra::localstack-start
just infra::bootstrap::init local && just infra::bootstrap::apply local
just infra::global::init local && just infra::global::apply local
just services::build-all
just infra::services::init local && just infra::services::apply local
just app::dev
```

## Architecture

### Directory Structure
- `services/` — Lambda functions (authorizer, content_service), each a separate uv workspace with own `pyproject.toml` + `justfile`
- `infra/` — Terraform IaC split into three stacks: bootstrap, global, services
- `app/` — React 19 + Vite + Bun frontend (single-page, one form component)
- `tests/functional/` — E2E tests organized by user story (`us_002_test.py`, etc.)
- `docs/user_stories/` — Feature specs (US-001 through US-005)

### Request Flow

```
Frontend -> API Gateway -> Lambda Authorizer -> Content Service Lambda
                                  |                      |
                            DynamoDB users         S3 content bucket
```

### Authentication Design (Non-Obvious)

Authorization header carries `base64(DNI:Name)` — **not a JWT or token**, just a raw credential pair. This is decoded **twice**: once in the authorizer lambda and once in the content service (no token forwarding between lambdas).

**DNI normalization is critical**: leading zeros are stripped and converted to uppercase before comparison against DynamoDB. A DNI stored as `00012345678A` in source data must be normalized to `12345678A`. The authorizer performs this normalization on both the incoming header and the DynamoDB stored values.

The authorizer returns an IAM Allow/Deny policy plus a context dict `{username, dni}` that passes to downstream services. It uses TOKEN type (not REQUEST type) — only the `Authorization` header is available.

### Content Service Design (Non-Obvious)

**ZIP caching**: When a user first downloads photos, a ZIP is built from S3 and stored at `downloads/{username}.zip`. Subsequent requests return a presigned URL to the cached ZIP immediately without rebuilding. No cache invalidation is implemented — stale ZIPs persist until manually deleted.

**DynamoDB `users` table schema**:
- Key: `username` (string, the "Name" part from auth header)
- `dnis`: list of strings (normalized: no leading zeros, uppercase)
- `photos`: list of S3 keys in the content bucket

Photos are stored as S3 keys, not filenames. Missing keys are skipped with a warning; the ZIP succeeds if at least one photo is retrieved.

### Terraform Stack Organization

Three-tier Terraform structure, each with its own `justfile` supporting `init`, `plan`, `apply`, `fmt`, `validate`, `lint` recipes:

1. **bootstrap** — Creates S3 bucket for Terraform state (`cbtc-tfstate-{env}`). Run once.
2. **global** — Lambda sources S3 bucket, DynamoDB users table, content S3 bucket, IAM roles.
3. **services** — API Gateway REST API, Lambda authorizer + content service, CloudWatch log groups.

Infra recipes follow the pattern `just infra::<stack>::<action> <env>` (e.g., `just infra::services::apply local`).

Lambda packages are built by `services/*/build.sh`: copies `src/`, installs dependencies into `dist/`, zips, uploads to S3 lambda-sources bucket. In non-LocalStack environments, the script also signs the artifact before updating Lambda code.

### Frontend

Single form component (`app/src/components/DocumentIdForm.jsx`) takes DNI + Name, encodes to `base64(DNI:Name)`, sends `GET /content` with `Authorization: Basic <encoded>`, and handles the presigned URL response for download.

### E2E Test Fixtures

`tests/functional/conftest.py` provides:
- `api_gateway_url` — reads from env or Terraform output
- `users_table` — boto3 DynamoDB resource
- `seeded_users` — pre-seeds DynamoDB with test data; auto-teardown after test

Tests detect LocalStack via `AWS_ENDPOINT_URL` env var. Resource names follow the pattern `cbtc-media-day-local-*`.

## Code Style

- Python: 120 char line length, ruff + black
- Tests: `*_test.py` or `test_*.py` (pytest discovers both); `pythonpath = [".", "libs", "services"]` in root `pyproject.toml`
- Each service is an independent uv workspace package

## Development Methodology

TDD organized around user stories:
1. Create spec in `docs/user_stories/US-XXX.md`
2. Write functional test in `tests/functional/us_xxx_test.py`
3. Write unit tests in `services/<service>/tests/`
4. Implement to pass tests
