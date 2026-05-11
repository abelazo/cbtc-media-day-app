# CBTC Media Day

| Pipeline                        | Status                                                                                                                                                                                                                        |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Deploy Infra - Global           | [![Deploy - Global Infrastructure](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_global.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_global.yml)       |
| Deploy Lambda - Content Service | [![Deploy Lambda - Content](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_content.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_content.yml)          |
| Deploy Lambda - Authorizer      | [![Deploy Lambda - Authorizer](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_authorizer.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_authorizer.yml) |

A serverless AWS application built with Python 3.12 and Terraform, following Test-Driven Development (TDD) principles.

## Architecture

This is a **monorepo** containing all services, infrastructure, and documentation for the CBTC Media Day application.

### Directory Structure

```
/.github/workflows/   # CI/CD pipelines
/app/                 # Frontend application (React + Vite)
    src/              # Frontend source code
    public/           # Public assets
/docs/                # Documentation
    user_stories/     # User Story definitions
    architecture/     # Architecture documentation
/infra/               # Terraform infrastructure as code
    bootstrap/        # State bucket (run once)
    global/           # Global resources (S3, DynamoDB, IAM)
    services/         # API Gateway, Lambda, CloudWatch
/services/            # AWS Lambda functions
    authorizer/       # Token authorizer Lambda
    content_service/  # Content delivery Lambda
/tests/
    functional/       # End-to-end functional tests per User Story
```

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
- **Linting**: ruff + black
- **CI/CD**: GitHub Actions

## Getting Started

### Prerequisites

- Python 3.12
- [uv](https://docs.astral.sh/uv/)
- [Bun](https://bun.sh/)
- Terraform >= 1.13.1
- AWS CLI configured
- Docker + docker-compose (for LocalStack)

### Installation

```bash
just sync-all       # Install all Python dependencies
just app::install   # Install frontend dependencies
```

### Local Development with LocalStack

```bash
# 1. Start LocalStack
just infra::localstack-start

# 2. Bootstrap + provision infrastructure
just infra::bootstrap::init local && just infra::bootstrap::apply local
just infra::global::init local && just infra::global::apply local

# 3. Build and deploy Lambda services
just services::build-all
just infra::services::init local && just infra::services::apply local

# 4. Run functional tests
just e2e::run

# 5. Start frontend
just app::dev
```

### Running Tests

```bash
# Unit tests
just services::test-all
just services::authorizer::test
just services::content::test

# E2E tests (requires LocalStack running)
just e2e::run
just e2e::run-story us_004
```

### Code Quality

```bash
just services::lint-all     # ruff + black --check
just services::format-all   # black + ruff --fix
just app::lint
just infra::global::lint
just infra::services::lint
```

## CI/CD

GitHub Actions run on push to `main` or PR:

- **Deploy Infra - Global**: triggers on `infra/global/**` changes
- **Deploy Lambda - Authorizer**: triggers on `services/authorizer/**` changes, runs unit tests first
- **Deploy Lambda - Content**: triggers on `services/content_service/**` changes, runs unit tests first
- **E2E Tests**: spins up LocalStack, provisions full stack, runs functional tests

## Contributing

1. Create User Story in `/docs/user_stories/`
2. Write functional test in `/tests/functional/`
3. Write unit tests in `/services/<service>/tests/`
4. Implement to pass tests
5. Ensure linters pass
6. Submit PR
