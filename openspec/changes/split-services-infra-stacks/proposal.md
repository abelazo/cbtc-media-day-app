## Why

Current `infra/services/` stack bundles authorizer lambda, content lambda, API Gateway, the content S3 bucket, the DynamoDB users table, and code signing into a single Terraform root. This couples unrelated lifecycles: lambda code updates re-plan API Gateway and data stores, the content bucket and users table live in a "services" stack despite being shared data resources, and the authorizer and content services cannot be deployed independently. Splitting along ownership boundaries lets each service evolve and deploy on its own and keeps long-lived data resources in the global tier.

## What Changes

- **BREAKING** Split `infra/services/` into three independent Terraform roots: `services/authorizer/infra/`, `services/content/infra/`, `infra/api-gateway/`.
- **BREAKING** Move `aws_s3_bucket.content` (content bucket) and `aws_dynamodb_table.users` from the services stack into `infra/global/`.
- **BREAKING** Move `aws_lambda_code_signing_config.dev` and `aws_signer_signing_profile.dev` from the services stack into `infra/global/` (shared by both lambdas).
- Move authorizer lambda + IAM role/policies + CloudWatch log group into `services/authorizer/infra/`.
- Move content lambda + IAM role/policies + CloudWatch log group into `services/content/infra/`.
- Move API Gateway REST API, resources, methods, integrations, authorizer attachment, lambda permissions, deployment, stage, and CORS config into `infra/api-gateway/`.
- Establish cross-stack references via Terraform remote state data sources (each downstream stack reads upstream outputs).
- Update `infra/justfile` aggregate recipes and per-stack `justfile`s for the new deploy order: `global` → (`authorizer` ∥ `content`) → `api-gateway`.
- Update root `CLAUDE.md` architecture section and any infra references.
- Delete `infra/services/` as part of the same change; no migration needed since both accounts are empty.

## Capabilities

### New Capabilities
- `global-infra`: shared, long-lived AWS resources — lambda sources S3 bucket, content S3 bucket, DynamoDB users table, code signing profile + config. Deployed first; no upstream dependencies.
- `authorizer-infra`: authorizer Lambda function, its IAM role + DynamoDB read policy, and CloudWatch log group. Depends on `global-infra` for the lambda sources bucket, users table, and signing config.
- `content-infra`: content Lambda function, its IAM role + S3/DynamoDB policies, and CloudWatch log group. Depends on `global-infra` for the lambda sources bucket, content bucket, users table, and signing config.
- `api-gateway-infra`: API Gateway REST API, `/content` resource, GET method, OPTIONS/CORS, Lambda authorizer attachment, AWS_PROXY integration to content lambda, deployment, and stage. Depends on `authorizer-infra` and `content-infra` for lambda ARNs/invoke ARNs.

### Modified Capabilities
- None (no existing specs in `openspec/specs/`).

## Impact

- **Code**: `infra/services/` removed; new `services/authorizer/infra/`, `services/content/infra/`, `infra/api-gateway/` roots; `infra/global/` gains content bucket, users table, and signing resources.
- **State**: No migration. Both `dev` and `prod` AWS accounts are empty; the new layout is provisioned from scratch. Committed `infra/services/terraform.tfstate*` files are deleted with the rest of the directory.
- **Justfiles**: `infra/justfile` aggregate targets and `infra.recipes.just` consumers updated; new per-stack recipes follow existing `init/plan/apply/fmt/validate/lint` pattern.
- **CI/CD**: 4 independent release pipelines (`global`, `authorizer`, `content`, `api-gateway`), each with its own semantic-release versioned artifact deployed to `dev` then `prod`, with per-environment deployment tracking via Git tags, AWS resource tags, and an append-only audit log.
- **Build scripts**: `services/*/build.sh` references the lambda-sources bucket name format; verify the bucket name format is unchanged.
- **Docs**: `CLAUDE.md` deploy sequence and infra section updated.
- **Outputs**: `api_gateway_url`, `users_table_name`, `signing_profile_name`, `content_lambda_arn` move to whichever stack now owns each resource.
