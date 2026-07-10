# CI/CD Pipelines

Four independent pipelines, one per stack, each with its own semantic-release versioned artifact and `dev` → `prod` flow with a manual approval between environments:

- **Deploy - Global** (`infra/global/**`) — tag `infra-global-vX.Y.Z`.
- **λ - Authorizer** (`services/authorizer/**`) — tag `authorizer-vX.Y.Z`, builds + signs + uploads lambda artifact.
- **λ - Content** (`services/content/**`) — tag `content-vX.Y.Z`, builds + signs + uploads lambda artifact.
- **Deploy - API Gateway** (`infra/api-gateway/**`) — tag `api-gateway-vX.Y.Z`.

## Pipeline Status

| Pipeline             | Status                                                                                                                                                                                                                  |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Deploy - Global      | [![Deploy - Global](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_global.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_global.yml)                |
| λ - Authorizer       | [![λ - Authorizer](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_authorizer.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_authorizer.yml)       |
| λ - Content          | [![λ - Content](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_content.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-lambda_content.yml)                |
| Deploy - API Gateway | [![Deploy - API Gateway](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_api-gateway.yml/badge.svg)](https://github.com/abelazo/cbtc-media-day/actions/workflows/deploy-infra_api-gateway.yml) |

## Per-environment deploy tracking

- Moving Git tag `<stack>-deployed-<env>` force-updated to the deployed commit.
- `DeployedVersion = <stack>-vX.Y.Z` tag on every taggable AWS resource.
- Lambda `Description` set to the release version.
- One JSONL line per deploy appended to `deployments.jsonl` in the audit bucket (`{ts, stack, version, env, commit, actor}`).
