# How to Check Code Quality

```bash
just services::lint-all                          # ruff check + ruff format --check
just services::format-all                        # ruff format + ruff check --fix
just app::lint
just infra::global::lint
just services::authorizer::infra::lint
just services::content::infra::lint
just 'infra::api-gateway::lint'
```
