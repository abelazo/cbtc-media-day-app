# How to Run Tests

```bash
# Unit tests
just services::test-all
just services::authorizer::test
just services::content::test

# E2E tests (runs against the deployed dev API Gateway)
just e2e::run
just e2e::run-story us_004
```
