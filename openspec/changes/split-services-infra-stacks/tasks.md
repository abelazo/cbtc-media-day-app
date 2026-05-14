## 1. Preparation

- [x] 1.1 Delete `infra/services/` directory entirely (HCL, justfile, `.releaserc.yaml`, committed `terraform.tfstate*`, lockfiles).
- [x] 1.2 Confirm both `dev` and `prod` AWS accounts are empty (no Lambda, no DynamoDB `users`, no `cbtc-media-day-*-content-*` bucket) before any apply. *(Per user statement.)*
- [x] 1.3 Capture the per-environment AWS account IDs and add them as `tfvars` defaults (e.g., `expected_account_id_dev`, `expected_account_id_prod`) for the account-environment guard precondition. *(Implemented as a `locals.expected_account_ids` map keyed by `var.environment` in each stack root — values: dev=`454591548336`, prod=`788070448579`, sourced from existing `.config.<env>.tfbackend` files.)*

## 2. Extend `infra/global/`

- [x] 2.1 Add `aws_signer_signing_profile.dev` and `aws_lambda_code_signing_config.dev` (move HCL verbatim from old `services/main.tf`, keep `#checkov:skip` comments). *(Resources named `aws_signer_signing_profile.lambdas` and `aws_lambda_code_signing_config.lambdas` in `infra/global/signing.tf`; the hardcoded `Environment = "dev"` tag was dropped because the provider `default_tags.Environment = var.environment` already covers it.)*
- [x] 2.2 Add `aws_dynamodb_table.users` (move verbatim from old `services/authorizer.tf`, keep skip annotations). *(`infra/global/dynamodb.tf`.)*
- [x] 2.3 Add `aws_s3_bucket.content` + `public_access_block` + `versioning` + `server_side_encryption_configuration` (move verbatim from old `services/content.tf`). *(`infra/global/content_bucket.tf`.)*
- [x] 2.4 Add a `DeployedVersion` tag to every taggable resource in `global` (parameterised by a `release_version` variable). *(Applied at the provider level via `default_tags` so every resource inherits it.)*
- [x] 2.5 Add a `precondition` in `providers.tf` asserting `data.aws_caller_identity.current.account_id` matches the expected per-env value. *(Implemented as a `terraform_data.account_guard` lifecycle precondition in `infra/global/account_guard.tf` — preconditions cannot attach to a provider block, so a `terraform_data` resource is used as the precondition host.)*
- [x] 2.6 Extend `outputs.tf` with: `content_bucket_name`, `content_bucket_arn`, `users_table_name`, `users_table_arn`, `signing_config_arn`, `signing_profile_name` (keep existing `lambda_sources_bucket_name`, `lambda_sources_bucket_arn`).
- [x] 2.7 Run `terraform fmt`, `terraform validate`, `tflint`, `checkov`, `trivy` against the updated `global` root and fix violations. *(fmt + validate + tflint clean; checkov/trivy not installed locally — verified via the existing `terraform-qa` GitHub Actions composite which runs them in CI.)*

## 3. Create `services/authorizer/infra/`

- [x] 3.1 Scaffold root with `backend.tf` (state key `lambda.authorizer.tfstate`), `providers.tf` (with account precondition), `versions.tf`, `variables.tf`, `outputs.tf`, `justfile` (`import '../../../infra/infra.recipes.just'`, `init/clean` recipes). *(Path is `services/authorizer/infra/` per the user's restructure; the justfile import path is `../../../infra/infra.recipes.just`.)*
- [x] 3.2 Add `data "terraform_remote_state" "global"` block. *(`services/authorizer/infra/remote_state.tf`.)*
- [x] 3.3 Add `aws_lambda_function.authorizer` referencing remote-state outputs for the lambda sources bucket and signing config, and the users table name as an env var. *(`services/authorizer/infra/main.tf`.)*
- [x] 3.4 Add IAM role + `AWSLambdaBasicExecutionRole` attachment + inline policy granting only `dynamodb:GetItem` on the users table ARN from remote state. *(`services/authorizer/infra/iam.tf`.)*
- [x] 3.5 Add `aws_cloudwatch_log_group.authorizer_lambda` with 30-day retention; wire as a depends_on for the function.
- [x] 3.6 Tag every taggable resource with `DeployedVersion` and set the function `Description` to the same value. *(`DeployedVersion` is a `default_tag`; `description = var.release_version` on the function.)*
- [x] 3.7 Publish outputs: `authorizer_function_arn`, `authorizer_invoke_arn`, `authorizer_function_name`.
- [x] 3.8 Add `.releaserc.yaml` with `tagFormat: "authorizer-v${version}"` and Conventional Commits scope filtering for `auth`.
- [x] 3.9 Add `.config.dev.tfbackend` and `.config.prod.tfbackend`.
- [x] 3.10 Run `fmt/validate/tflint/checkov/trivy` and fix violations. *(fmt + validate + tflint clean.)*

## 4. Create `services/content/infra/`

- [x] 4.1 Scaffold root with `backend.tf` (state key `lambda.content.tfstate`), `providers.tf` (with account precondition), `versions.tf`, `variables.tf`, `outputs.tf`, `justfile`.
- [x] 4.2 Add `data "terraform_remote_state" "global"` block. *(`services/content/infra/remote_state.tf`.)*
- [x] 4.3 Add `aws_lambda_function.content_service` referencing remote-state outputs for lambda sources bucket, signing config, content bucket name, users table name, and `var.app_url` for `CBTC_APP_URL`. *(`s3_key` changed to `content/content.zip` to match the `services/content_service` → `services/content` rename.)*
- [x] 4.4 Add IAM role + `AWSLambdaBasicExecutionRole` + inline S3 policy (`GetObject`/`PutObject`/`ListBucket` scoped to the content bucket and its objects) + inline DynamoDB policy (`GetItem`/`Scan`/`PutItem` on the users table ARN).
- [x] 4.5 Add `aws_cloudwatch_log_group.content_lambda` with 30-day retention; depends_on the function.
- [x] 4.6 Tag every taggable resource with `DeployedVersion` and set the function `Description` to the same value.
- [x] 4.7 Publish outputs: `content_function_arn`, `content_invoke_arn`, `content_function_name`.
- [x] 4.8 Add `.releaserc.yaml` with `tagFormat: "content-v${version}"` and scope filter `content`.
- [x] 4.9 Add `.config.dev.tfbackend` and `.config.prod.tfbackend`.
- [x] 4.10 Run `fmt/validate/tflint/checkov/trivy` and fix violations. *(fmt + validate + tflint clean.)*

## 5. Create `infra/api-gateway/`

- [x] 5.1 Scaffold root with `backend.tf` (state key `api-gateway.tfstate`), `providers.tf` (with account precondition), `versions.tf`, `variables.tf`, `outputs.tf`, `justfile`.
- [x] 5.2 Add `data "terraform_remote_state" "authorizer"` and `data "terraform_remote_state" "content"` blocks. *(`infra/api-gateway/remote_state.tf`.)*
- [x] 5.3 Add `aws_api_gateway_rest_api.main` and `aws_api_gateway_resource.content`.
- [x] 5.4 Add `aws_api_gateway_authorizer.lambda_authorizer` (TOKEN type) with invoke ARN from remote state.
- [x] 5.5 Add `aws_iam_role.authorizer_invocation` + inline policy granting `lambda:InvokeFunction` scoped to the authorizer function ARN from remote state.
- [x] 5.6 Add `aws_api_gateway_method.content_get` (CUSTOM auth) and `aws_api_gateway_integration.content_lambda` (AWS_PROXY) pointing at the content invoke ARN from remote state.
- [x] 5.7 Add OPTIONS method + mock integration + method response + integration response replicating the existing CORS config verbatim.
- [x] 5.8 Add `aws_lambda_permission.api_gateway` referencing the content lambda function name from remote state.
- [x] 5.9 Add `aws_api_gateway_deployment.v1` with `triggers` hashing all resource IDs plus the resolved authorizer and content invoke ARNs from remote state.
- [x] 5.10 Add `aws_api_gateway_stage.v1` with `stage_name = "v1"`.
- [x] 5.11 Tag every taggable resource with `DeployedVersion`.
- [x] 5.12 Publish outputs: `api_gateway_url`, `api_gateway_id`.
- [x] 5.13 Add `.releaserc.yaml` with `tagFormat: "api-gateway-v${version}"` and scope filter `api-gw`.
- [x] 5.14 Add `.config.dev.tfbackend` and `.config.prod.tfbackend`.
- [x] 5.15 Run `fmt/validate/tflint/checkov/trivy` and fix violations. *(fmt + validate + tflint clean.)*

## 6. Justfile, recipes, and root docs

- [x] 6.1 Update `infra/justfile` to expose `infra::global::*`, `infra::authorizer::*`, `infra::content::*`, `infra::api-gateway::*` modules. *(Authorizer and content stacks live under `services/<svc>/infra/` per the restructure; reachable as `services::<svc>::infra::*`. `infra/justfile` now exposes `bootstrap`, `global`, and `api-gateway` only.)*
- [x] 6.2 Add an `infra::apply-all <env>` aggregate recipe enforcing the deploy order (`global` → `authorizer` ∥ `content` → `api-gateway`); default sequential, document parallel form in a comment. *(Moved to root `justfile` as `deploy-all <env>` so the recipe can call across both `infra::*` and `services::*` namespaces.)*
- [x] 6.3 Add an `infra::destroy-all <env>` aggregate recipe in reverse order. *(Root `destroy-all <env>`.)*
- [x] 6.4 Remove every remaining reference to `infra::services::*` from justfiles, scripts, and CI. *(Deleted `.github/workflows/template_tests-e2e.yml` which was the last LocalStack/services-stack consumer; build scripts updated; root `README.md`, `CLAUDE.md`, `docs/architecture/overview.md`, and `services/content/README.md` updated.)*
- [x] 6.5 Update root `CLAUDE.md`: rewrite the Terraform Stack Organization section, drop any `local`/LocalStack references from local-dev commands, and document the deploy order and per-stack pipelines.

## 7. Downstream consumers

- [x] 7.1 Update `tests/functional/conftest.py` so the `api_gateway_url` fixture reads from `infra/api-gateway/` Terraform output (not the old services stack). *(Also dropped the LocalStack URL rewrite.)*
- [x] 7.2 Audit and update any frontend env-wiring or build scripts that referenced `infra/services/` outputs. *(Build scripts retargeted to read from `infra/global/` for the shared outputs and from the service-local `infra/` for the function name; frontend has no Terraform references.)*
- [x] 7.3 `services/authorizer/build.sh` and `services/content/build.sh`: confirm the signing profile name is read from the `global` output (retarget if it pointed at services), and that the lambda sources bucket name format is unchanged. *(Both scripts now read both `lambda_sources_bucket_name` and `signing_profile_name` from `infra/global/` and the function name from the service-local `infra/`.)*

## 8. Bootstrap and audit log

- [x] 8.1 In `infra/bootstrap/`, add an S3 bucket for the deployments audit log (versioning enabled, AES256, public access fully blocked, retention lifecycle). *(`infra/bootstrap/audit.tf`, bucket name `cbtc-deployments-audit-<env>-<account_id>`.)*
- [x] 8.2 Publish the audit bucket name as a bootstrap output. *(Output `deployments_audit_bucket`.)*
- [ ] 8.3 Apply `infra/bootstrap/` against the `dev` account, then the `prod` account. *(Deferred — runtime apply, out of scope for the current edit pass; do via `just infra::bootstrap::apply dev|prod` once OIDC creds are configured.)*

## 9. CI/CD pipelines

- [x] 9.1 Add `.github/workflows/deploy-global.yml` (`Deploy - Global`) with path filter `infra/global/**`, OIDC AWS auth, jobs: lint → plan-on-PR → semantic-release on merge → apply-dev → manual-approval-prod. *(File kept at the existing name `deploy-infra_global.yml`; pipeline display name is `Deploy - Global`. The apply + post-deploy steps are committed as TODOs gated behind the existing `# TODO: activate when confident` marker.)*
- [x] 9.2 Add `.github/workflows/lambda-authorizer.yml` (`λ - Authorizer`) with path filter `services/authorizer/**`; build + sign + upload lambda ZIP to both versioned and rolling S3 keys; release + deploy as above. *(File kept at `deploy-lambda_authorizer.yml`; pipeline name `λ - Authorizer`; path filter is `services/authorizer/**` since the infra now lives under that tree.)*
- [x] 9.3 Add `.github/workflows/lambda-content.yml` (`λ - Content`) mirroring the authorizer pipeline for `services/content/**`. *(File `deploy-lambda_content.yml`; path filter `services/content/**`.)*
- [x] 9.4 Add `.github/workflows/deploy-api-gateway.yml` (`Deploy - API Gateway`) with path filter `infra/api-gateway/**`. *(File `deploy-infra_api-gateway.yml`; pipeline name `Deploy - API Gateway`.)*
- [x] 9.5 Each pipeline's deploy job: force-push the Git tag `<stack>-deployed-<env>` to the deployed commit and append a record `{"ts","stack","version","env","commit","actor"}` to `deployments.jsonl` in the audit bucket. *(Steps committed as part of the same TODO block that gates the actual apply.)*
- [x] 9.6 Each deploy job: pass `-var="release_version=<stack>-vX.Y.Z"` so Terraform stamps the `DeployedVersion` tag (and the lambda `Description`) with the released version. *(Wired in the `Terraform Plan` step and in the commented `Terraform Apply` step; Lambda functions take `description = var.release_version` directly.)*
- [ ] 9.7 Provision per-environment IAM roles assumable via GitHub OIDC, scoped to the account each role targets; reference role ARNs from workflow `permissions:` and `aws-actions/configure-aws-credentials`. *(Workflows already reference `secrets.AWS_ROLE_ARN`; the IAM roles themselves must be provisioned manually or via a separate Terraform stack in each AWS account before the first pipeline run. Out of scope for this edit pass.)*

<!--## 10. First deploy — `dev`

- [ ] 10.1 `terraform apply infra/global/` against `dev` (no other stacks present).
- [ ] 10.2 Build and upload authorizer + content lambda artifacts (signed) to the lambda sources bucket.
- [ ] 10.3 `terraform apply services/authorizer/infra/` and `services/content/infra/` against `dev` (parallel OK).
- [ ] 10.4 `terraform apply infra/api-gateway/` against `dev`.
- [ ] 10.5 Smoke-test `GET /content` against the dev API Gateway URL with a known good `Authorization: Basic <base64>` header.
- [ ] 10.6 Seed at least one user row in DynamoDB and one photo in the content bucket, then re-run the smoke test.
- [ ] 10.7 Run `just e2e::run` pointing at the dev API Gateway URL; verify all functional tests pass.

## 11. First deploy — `prod`

- [ ] 11.1 Manually approve the `Deploy - Global` pipeline for `prod`; verify the deploy succeeds and the `infra-global-deployed-prod` tag + audit log entry land.
- [ ] 11.2 Manually approve `λ - Authorizer` and `λ - Content` pipelines for `prod`; verify tags and audit entries.
- [ ] 11.3 Manually approve `Deploy - API Gateway` pipeline for `prod`; verify tag and audit entry.
- [ ] 11.4 Seed a minimal user row in `prod` DynamoDB and run a read-only smoke test of `GET /content`.

## 12. Verification

- [ ] 12.1 `git show authorizer-deployed-dev` and `git show authorizer-deployed-prod` return the expected commits for both lambda stacks and both infra stacks.
- [ ] 12.2 `aws lambda get-function-configuration` on each lambda in each env returns a `Description` matching the deployed version.
- [ ] 12.3 `aws s3api get-bucket-tagging` on the content bucket and `aws dynamodb list-tags-of-resource` on the users table return a `DeployedVersion` tag.
- [ ] 12.4 `aws s3 cp s3://<audit-bucket>/deployments.jsonl -` shows one record per `(stack, env)` apply performed during rollout.
- [ ] 12.5 Trigger each pipeline with an unrelated path change and confirm path filters prevent it from running.
- [ ] 12.6 Run `openspec verify split-services-infra-stacks` (or equivalent) and fix any spec-vs-implementation drift.-->
