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

# Clean build artifacts and caches
[group('setup')]
clean:
    @echo "Cleaning build artifacts..."
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete
    @echo "✓ Cleanup complete"
