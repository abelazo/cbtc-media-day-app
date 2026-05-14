# Load environment variables from .env file
set dotenv-load

# Infrastructure
[group('infra')]
mod infra

# Frontend Application
[group('frontend')]
mod app

# Lambda services
[group('backend')]
mod services

# Functional tests
[group('tests')]
mod e2e 'tests'


# Default recipe - show available commands
help:
    @just --list

# Setup development environment for all packages
[group('setup')]
sync-all:
    @echo "Syncing development environment..."
    uv sync --all-packages --all-extras

sync package:
    @echo "Syncing development environment for package..."
    uv sync --package cbtc-media-day --package {{package}} --all-extras

# Apply every Terraform stack to the given env, in the required order:
# global -> (authorizer || content) -> api-gateway.
# Default is sequential. To parallelise the lambda step, run the two
# `services::*::infra::apply` lines with `&` + `wait`.
[group('orchestration')]
deploy-all env +args="":
    just infra::global::apply {{env}} {{args}}
    just services::authorizer::infra::apply {{env}} {{args}}
    just services::content::infra::apply {{env}} {{args}}
    just 'infra::api-gateway::apply' {{env}} {{args}}

# Destroy every Terraform stack to the given env, in reverse order
[group('orchestration')]
destroy-all env:
    just 'infra::api-gateway::destroy' {{env}}
    just services::content::infra::destroy {{env}}
    just services::authorizer::infra::destroy {{env}}
    just infra::global::destroy {{env}}

# Clean build artifacts and caches
[group('setup')]
clean:
    @echo "Cleaning build artifacts..."
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete
    @echo "✓ Cleanup complete"
