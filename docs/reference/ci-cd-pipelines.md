# CI/CD Pipelines

Four independent pipelines, one per stack, each with its own semantic-release versioned artifact and `dev` → `prod` flow with a manual approval between environments:

- **Deploy - Global** (`infra/global/**`) — tag `infra-global-vX.Y.Z`.
- **λ - Authorizer** (`services/authorizer/**`) — tag `authorizer-vX.Y.Z`, builds + signs + uploads lambda artifact.
- **λ - Content** (`services/content/**`) — tag `content-vX.Y.Z`, builds + signs + uploads lambda artifact.
- **Deploy - API Gateway** (`infra/api-gateway/**`) — tag `api-gateway-vX.Y.Z`.

Pipeline status badges: see [README](../../README.md).

## Per-environment deploy tracking

- Moving Git tag `<stack>-deployed-<env>` force-updated to the deployed commit.
- `DeployedVersion = <stack>-vX.Y.Z` tag on every taggable AWS resource.
- Lambda `Description` set to the release version.
- One JSONL line per deploy appended to `deployments.jsonl` in the audit bucket (`{ts, stack, version, env, commit, actor}`).
