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

# Documentation
[group('docs')]
mod docs

# Default recipe - show available commands
help:
    @just --list

# TO BE REMOVED ###############################################################
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
