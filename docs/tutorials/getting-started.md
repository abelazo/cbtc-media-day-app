# Getting Started

Walkthrough: install deps, bootstrap a `dev` account, deploy every stack, run tests.

## Prerequisites

- Python 3.12
- [uv](https://docs.astral.sh/uv/)
- [Bun](https://bun.sh/)
- Terraform >= 1.13.1
- AWS CLI configured against the `dev` or `prod` AWS account

## 1. Install dependencies

```bash
just sync-all       # Install all Python dependencies
just app::install   # Install frontend dependencies
```

## 2. First-time deploy to `dev`

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

Next: [how to run tests](../how-to-guides/running-tests.md), [how to check code quality](../how-to-guides/code-quality.md).
