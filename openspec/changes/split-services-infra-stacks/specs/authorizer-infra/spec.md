## ADDED Requirements

### Requirement: Independent Terraform root

The `authorizer-infra` capability SHALL be managed by a standalone Terraform root at `services/authorizer/infra/` with its own `backend.tf`, `providers.tf`, `versions.tf`, `variables.tf`, `outputs.tf`, and `justfile` importing `infra/infra.recipes.just`. Its Terraform state SHALL be stored under the state key `lambda.authorizer.tfstate`.

#### Scenario: Stack initialises independently of API Gateway

- **WHEN** an operator runs `just infra::authorizer::init <env>` and `just infra::authorizer::plan <env>` in an account where `global` has been applied but `api-gateway` has not
- **THEN** init and plan succeed without referencing the `api-gateway` stack

### Requirement: Reads global remote state

The capability SHALL consume the `lambda_sources_bucket_name`, `users_table_name`, `users_table_arn`, `signing_config_arn`, and `signing_profile_name` outputs from `global` via `data "terraform_remote_state" "global"`. It SHALL NOT redefine any of those resources locally.

#### Scenario: Remote-state lookup succeeds

- **WHEN** the `authorizer` stack is planned in an environment where `global` is applied
- **THEN** the plan resolves each consumed output and produces no diff for those upstream resources

#### Scenario: Plan fails fast when global is missing

- **WHEN** the `authorizer` stack is planned in an environment where `global` has not been applied
- **THEN** the plan fails with a clear remote-state error before attempting to create any resource

### Requirement: Authorizer Lambda function

The capability SHALL provision a Lambda function named `<project_name>-<env>-authorizer` with runtime `python3.12`, handler `handler.lambda_handler`, timeout 30 seconds, memory 128 MB, signed via the `global` signing config, and sourced from S3 key `authorizer/authorizer.zip` (or a versioned key per Decision 10) in the lambda sources bucket. The function SHALL receive environment variables `ENVIRONMENT` and `USERS_TABLE_NAME`.

#### Scenario: Function deployed and signed

- **WHEN** the stack is applied
- **THEN** the function exists with the specified runtime, handler, timeout, memory, signing config, and environment variables

#### Scenario: Unsigned ZIP rejected

- **WHEN** an unsigned ZIP is uploaded to the configured S3 key and the function attempts to update its code
- **THEN** AWS Lambda rejects the deployment due to the signing config

### Requirement: IAM role with minimum privileges

The capability SHALL create an IAM role assumable by `lambda.amazonaws.com` and attach (a) the AWS managed policy `AWSLambdaBasicExecutionRole` for CloudWatch logging and (b) an inline policy granting `dynamodb:GetItem` against the users table ARN read from `global`. No other DynamoDB action and no S3 action SHALL be granted.

#### Scenario: Authorizer cannot write to DynamoDB

- **WHEN** the authorizer lambda attempts `dynamodb:PutItem` against the users table
- **THEN** the call is denied by IAM

### Requirement: CloudWatch log group

The capability SHALL provision a CloudWatch log group named `/aws/lambda/<project_name>-<env>-authorizer` with retention 30 days. The Lambda function SHALL depend on the log group existing before creation.

#### Scenario: Log group created with retention

- **WHEN** the stack is applied
- **THEN** the log group exists with `retention_in_days = 30`

### Requirement: Outputs published for API Gateway stack

The capability SHALL expose outputs `authorizer_function_arn`, `authorizer_invoke_arn`, and `authorizer_function_name` for consumption by `api-gateway` via remote state.

#### Scenario: Outputs resolvable from API Gateway stack

- **WHEN** the `api-gateway` stack declares `data "terraform_remote_state" "authorizer"`
- **THEN** all three output names return non-empty values

### Requirement: Release artifact and deploy tracking

The capability SHALL be released via a dedicated semantic-release pipeline named `λ - Authorizer` that publishes Git tags `authorizer-vX.Y.Z`, publishes both a versioned (`authorizer/<version>/authorizer.zip`) and a rolling (`authorizer/authorizer.zip`) lambda artifact to the lambda sources bucket, force-updates the Git tag `authorizer-deployed-<env>` on successful apply, and appends a record to `deployments.jsonl`.

#### Scenario: Path filter scopes triggers

- **WHEN** a commit modifies only files under `services/content/**`
- **THEN** the authorizer pipeline does not trigger a release or deploy

#### Scenario: Python or HCL change triggers pipeline

- **WHEN** a commit modifies files under `services/authorizer/**` or `infra/authorizer/**`
- **THEN** the authorizer pipeline runs lint, plan, release, and dev deploy

### Requirement: Resource-level version tagging

Every taggable AWS resource owned by this capability SHALL carry a `DeployedVersion` tag matching the release artifact version, and the Lambda function `Description` SHALL be set to the same version string.

#### Scenario: Function description reflects version

- **WHEN** an operator runs `aws lambda get-function-configuration --function-name <project>-<env>-authorizer`
- **THEN** the `Description` field equals `authorizer-vX.Y.Z` of the latest release applied to that environment

### Requirement: Account-environment guard

The capability SHALL enforce that the AWS account targeted by an apply matches the selected Terraform workspace via the same precondition pattern used by `global`.

#### Scenario: Wrong-account apply blocked

- **WHEN** an operator runs `just infra::authorizer::apply prod` while authenticated to the `dev` AWS account
- **THEN** the apply fails at the precondition before any resource is created or modified
