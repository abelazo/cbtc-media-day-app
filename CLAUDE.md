# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. Audience: the agent — terse, operational, non-obvious gotchas. Human-facing docs (tutorials, how-tos, explanations) live in [`/docs`](docs/README.md); this file doesn't duplicate those.

## Project Overview

CBTC Media Day is a serverless AWS application for managing and distributing media day photos. It's a monorepo containing Lambda services, Terraform infrastructure, and a React frontend.

**Follow the [Development Methodology](#development-methodology) (TDD) below for any feature or bugfix**: spec → functional test → unit tests → implement.

## Build & Development Commands

All commands use `just` (a command runner). Run `just --list` to see all available recipes.

### Setup & Dependencies

```bash
just sync-all                     # Install all Python dependencies (uv workspaces)
just sync authorizer              # Install authorizer dependencies
just sync content                 # Install content service dependencies
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

# E2E tests (runs against the deployed `dev` API Gateway)
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
just services::lint-all           # ruff check + ruff format --check
just services::format-all         # ruff format + ruff check --fix
just app::lint
```

### Building & Deployment

```bash
just services::build-all                          # Build all Lambda packages
just deploy-all dev                               # Apply every stack to dev, in the required order
just infra::global::apply dev                     # Apply the global stack only
just services::authorizer::infra::apply dev       # Apply the authorizer stack only
just services::content::infra::apply dev          # Apply the content stack only
just 'infra::api-gateway::apply' dev              # Apply the API Gateway stack only
```

Deploy order: `global` → (`authorizer` ∥ `content`) → `api-gateway`. The `deploy-all` recipe runs them sequentially; the lambda step can be parallelised by editing the recipe to run the two `services::*::infra::apply` lines with `&` + `wait`.

## Architecture

### Directory Structure

```
/.github/workflows/   # CI/CD pipelines (one per stack, see CI/CD Pipelines below)
/app/                 # React 19 + Vite + Bun frontend (single-page, one form component)
/docs/                # Human-facing docs (Diataxis: tutorials/how-to-guides/reference/explanation) + architecture/
/infra/               # Shared Terraform stacks: bootstrap, global, api-gateway
/services/            # Lambda functions, each a separate uv workspace with pyproject.toml, justfile, infra/
    authorizer/       # API Gateway custom authorizer Lambda (infra/ = authorizer stack)
    content/          # Content Service Lambda (infra/ = content stack)
/tests/functional/    # E2E tests organized by user story (us_002_test.py, etc.)
```

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

Five-stack Terraform layout. Each stack has its own `justfile` supporting `init`, `plan`, `apply`, `fmt`, `validate`, `lint` recipes:

1. **bootstrap** (`infra/bootstrap/`) — Creates the S3 bucket for Terraform state per account (`cbtc-terraform-state-<env>-<account_id>`). Run once per account.
2. **global** (`infra/global/`) — Shared, long-lived resources: lambda sources S3 bucket, content S3 bucket, DynamoDB `users` table, code signing profile + config.
3. **authorizer** (`services/authorizer/infra/`) — Authorizer Lambda function, its IAM role/policies, and CloudWatch log group. Reads `global` via `terraform_remote_state`.
4. **content** (`services/content/infra/`) — Content Lambda function, its IAM role/policies, and CloudWatch log group. Reads `global` via `terraform_remote_state`.
5. **api-gateway** (`infra/api-gateway/`) — REST API, `/content` resource, lambda authorizer attachment, AWS_PROXY integration, CORS, deployment, and `v1` stage. Reads `authorizer` and `content` via remote state.

Recipe namespaces:

- `just infra::<stack>::<action> <env>` for `bootstrap`, `global`, `api-gateway`.
- `just services::<svc>::infra::<action> <env>` for `authorizer` and `content`.
- `just deploy-all <env>` applies every stack in the required order: `global` → (`authorizer` ∥ `content`) → `api-gateway`.

Deploy order matters: downstream stacks read upstream outputs via `terraform_remote_state`, so a fresh apply must run upstream first. Each stack also publishes a `<stack>-deployed-<env>` Git tag and appends to the audit log on successful apply.

Each Terraform root has an `account_guard.tf` precondition asserting the AWS account currently authenticated matches the expected per-env account (dev `454591548336`, prod `788070448579`).

Lambda packages are built by `services/*/build.sh`: copies `src/`, installs dependencies into `dist/`, zips, uploads to the S3 lambda-sources bucket, signs the artifact via AWS Signer, then updates the Lambda code.

### Frontend

Single form component (`app/src/components/DocumentIdForm.jsx`) takes DNI + Name, encodes to `base64(DNI:Name)`, sends `GET /content` with `Authorization: Basic <encoded>`, and handles the presigned URL response for download.

### E2E Test Fixtures

`tests/functional/conftest.py` provides:

- `api_gateway_url` — reads from env `API_GATEWAY_URL` or `terraform output` in `infra/api-gateway/`.
- `users_table` — boto3 DynamoDB resource.
- `seeded_users` — pre-seeds DynamoDB with test data.

E2E tests target the deployed `dev` environment (real AWS).

## Code Style

- Python: 120 char line length, formatted and linted with `ruff` (no Black)
- Tests: `*_test.py` or `test_*.py` (pytest discovers both); `pythonpath = [".", "libs", "services"]` in root `pyproject.toml`
- Each service is an independent uv workspace package

## CI/CD Pipelines

Four independent pipelines, one per stack, each with its own semantic-release versioned artifact and `dev` → `prod` flow:

| Pipeline               | Workflow                                         | Path filter              | Tag format            |
| ---------------------- | ------------------------------------------------ | ------------------------ | --------------------- |
| `Deploy - Global`      | `.github/workflows/deploy-infra_global.yml`      | `infra/global/**`        | `infra-global-vX.Y.Z` |
| `λ - Authorizer`       | `.github/workflows/deploy-lambda_authorizer.yml` | `services/authorizer/**` | `authorizer-vX.Y.Z`   |
| `λ - Content`          | `.github/workflows/deploy-lambda_content.yml`    | `services/content/**`    | `content-vX.Y.Z`      |
| `Deploy - API Gateway` | `.github/workflows/deploy-infra_api-gateway.yml` | `infra/api-gateway/**`   | `api-gateway-vX.Y.Z`  |

Per-pipeline flow: lint → plan-on-PR → semantic-release on merge to `main` → apply against `dev` → manual-approval gate → apply against `prod`.

Each deploy job:

- Passes `-var="release_version=<stack>-vX.Y.Z"` so every taggable AWS resource carries a `DeployedVersion` tag matching the release, and lambdas have their `Description` set to the version.
- Force-updates a moving Git tag `<stack>-deployed-<env>` to the deployed commit.
- Appends a JSONL record to `deployments.jsonl` in the audit bucket: `{ts, stack, version, env, commit, actor}`.

Commit-scope filtering: each stack's `.releaserc.yaml` only releases on Conventional Commits with a matching scope (`infra-global`, `auth`, `content`, `api-gw`). A commit touching multiple stacks must use multiple scoped commits or one combined commit that matches each scope rule.

Commit-order coupling: pipelines do NOT orchestrate each other. If a downstream stack needs a new upstream output, merge and deploy the upstream change first.

## GitHub Actions

Always use the latest available version of any third-party action.

**Trusted orgs** (`actions`, `astral-sh`, `hashicorp`, `aws-actions`) — use a plain version tag, no SHA pin:

```yaml
uses: actions/checkout@v7
```

**Everyone else** — pinned SHA hash with a version comment (the tag itself must never appear after the `@`, only the full commit SHA; the version is a trailing comment for humans):

```yaml
uses: owner/action@<full-commit-sha> # vX.Y.Z
```

Example: `uses: terraform-linters/setup-tflint@6e1e0642c0289bd619021bf6b34e3c08ed1e005a # v6.3.0`

To get the SHA for a tag:

```bash
# Fetch tag SHA (dereference annotated tags if type == "tag")
curl -s "https://api.github.com/repos/<owner>/<action>/git/ref/tags/<tag>" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['object']['sha'], d['object']['type'])"
# If type == "tag", dereference:
curl -s "https://api.github.com/repos/<owner>/<action>/git/tags/<sha>" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['object']['sha'])"
```

## Development Methodology

**Mandatory for every feature/bugfix — do not skip steps or write implementation before tests.**

1. Write functional test in `tests/functional/us_xxx_test.py`
2. Write unit tests in `services/<service>/tests/`
3. Implement to pass tests

Rationale/background: [docs/explanation/tdd-methodology.md](docs/explanation/tdd-methodology.md).
