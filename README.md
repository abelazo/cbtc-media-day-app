# CBTC Media Day

| Pipeline                        | Status                                                                                                                                                                                                                                              |
|---------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Deploy - Global                 | [![Deploy - Global](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_global.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_global.yml)                                            |
| λ - Authorizer                  | [![λ - Authorizer](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_authorizer.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_authorizer.yml)                                   |
| λ - Content                     | [![λ - Content](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_content.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_content.yml)                                            |
| Deploy - API Gateway            | [![Deploy - API Gateway](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_api-gateway.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_api-gateway.yml)                             |

A serverless AWS application built with Python 3.12 and Terraform, following Test-Driven Development (TDD) principles.

## Architecture

This is a **monorepo** containing all services, infrastructure, and documentation for the CBTC Media Day application.

### Directory Structure

```
/.github/workflows/   # CI/CD pipelines (one per stack)
/app/                 # Frontend application (React + Vite)
    src/              # Frontend source code
    public/           # Public assets
/docs/                # Documentation
    user_stories/     # User Story definitions
    architecture/     # Architecture documentation
/infra/               # Shared Terraform stacks
    bootstrap/        # State bucket (run once per account)
    global/           # Shared resources: lambda sources bucket, content bucket,
                      # users table, code signing profile + config
    api-gateway/      # REST API + lambda authorizer attachment + integrations
/services/            # AWS Lambda functions, each with its own infra stack
    authorizer/       # Token authorizer Lambda
        infra/        # Authorizer Terraform stack
    content/          # Content delivery Lambda
        infra/        # Content Terraform stack
/tests/
    functional/       # End-to-end functional tests per User Story
```

Deploy order: `global` → (`authorizer` ∥ `content`) → `api-gateway`. See `just deploy-all <env>`.

## Development Methodology

TDD organized around User Stories.

### Workflow

1. Create spec in `/docs/user_stories/<us_id>.md`
2. Write functional test in `/tests/functional/<us_id>_test.py`
3. Write unit tests in `/services/<service>/tests/`
4. Implement to pass tests

## Technology Stack

- **Runtime**: Python 3.12 (AWS Lambda)
- **Infrastructure**: Terraform
- **Frontend**: React 19 + Vite
- **Frontend Runtime**: Bun
- **Package Manager**: uv (Python) / bun (JS)
- **Testing**: pytest + playwright
- **Linting + Formatting**: ruff (linter + formatter — no Black)
- **CI/CD**: GitHub Actions

## Getting Started

### Prerequisites

- Python 3.12
- [uv](https://docs.astral.sh/uv/)
- [Bun](https://bun.sh/)
- Terraform >= 1.13.1
- AWS CLI configured against the `dev` or `prod` AWS account

### Installation

```bash
just sync-all       # Install all Python dependencies
just app::install   # Install frontend dependencies
```

### First-time deploy to `dev`

```bash
# 1. Bootstrap the TF state bucket in the dev account
just infra::bootstrap::init dev && just infra::bootstrap::apply dev

# 2. Build the lambda artifacts
just services::build-all

# 3. Apply every stack in the required order
just deploy-all dev

# 4. Run functional tests against the deployed dev environment
just e2e::run
```

### Running Tests

```bash
# Unit tests
just services::test-all
just services::authorizer::test
just services::content::test

# E2E tests (runs against the deployed dev API Gateway)
just e2e::run
just e2e::run-story us_004
```

### Code Quality

```bash
just services::lint-all                          # ruff check + ruff format --check
just services::format-all                        # ruff format + ruff check --fix
just app::lint
just infra::global::lint
just services::authorizer::infra::lint
just services::content::infra::lint
just 'infra::api-gateway::lint'
```

## CI/CD

Four independent pipelines, one per stack, each with its own semantic-release versioned artifact and `dev` → `prod` flow with a manual approval between environments:

- **Deploy - Global** (`infra/global/**`) — tag `infra-global-vX.Y.Z`.
- **λ - Authorizer** (`services/authorizer/**`) — tag `authorizer-vX.Y.Z`, builds + signs + uploads lambda artifact.
- **λ - Content** (`services/content/**`) — tag `content-vX.Y.Z`, builds + signs + uploads lambda artifact.
- **Deploy - API Gateway** (`infra/api-gateway/**`) — tag `api-gateway-vX.Y.Z`.

Per-environment deploy tracking:
- Moving Git tag `<stack>-deployed-<env>` force-updated to the deployed commit.
- `DeployedVersion = <stack>-vX.Y.Z` tag on every taggable AWS resource.
- Lambda `Description` set to the release version.
- One JSONL line per deploy appended to `deployments.jsonl` in the audit bucket (`{ts, stack, version, env, commit, actor}`).

## Contributing

1. Create User Story in `/docs/user_stories/`
2. Write functional test in `/tests/functional/`
3. Write unit tests in `/services/<service>/tests/`
4. Implement to pass tests
5. Ensure linters pass
6. Submit PR
