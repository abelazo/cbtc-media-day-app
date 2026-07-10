# TDD Methodology

Test-first development, no spec-first step.

## Workflow

1. Write functional test in `/tests/functional/<us_id>_test.py`
2. Write unit tests in `/services/<service>/tests/`
3. Implement to pass tests

The functional test encodes acceptance criteria so "done" is checkable, not judged. See [CONTRIBUTING.md](../../.github/CONTRIBUTING.md) for the PR-level version of this flow.
