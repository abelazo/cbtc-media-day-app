## ADDED Requirements

### Requirement: Independent Terraform root

The `content-infra` capability SHALL be managed by a standalone Terraform root at `services/content/infra/` with its own `backend.tf`, `providers.tf`, `versions.tf`, `variables.tf`, `outputs.tf`, and `justfile` importing `infra/infra.recipes.just`. Its Terraform state SHALL be stored under the state key `lambda.content.tfstate`.

#### Scenario: Stack initialises independently of authorizer and API Gateway

- **WHEN** an operator runs `just infra::content::init <env>` and `just infra::content::plan <env>` in an account where `global` is applied but `authorizer` and `api-gateway` are not
- **THEN** init and plan succeed without referencing those stacks

### Requirement: Reads global remote state

The capability SHALL consume the `lambda_sources_bucket_name`, `content_bucket_name`, `content_bucket_arn`, `users_table_name`, `users_table_arn`, `signing_config_arn`, and `signing_profile_name` outputs from `global` via `data "terraform_remote_state" "global"`. It SHALL NOT redefine any of those resources locally.

#### Scenario: Remote-state lookup succeeds

- **WHEN** the `content` stack is planned in an environment where `global` is applied
- **THEN** the plan resolves each consumed output and produces no diff for those upstream resources

### Requirement: Content Lambda function

The capability SHALL provision a Lambda function named `<project_name>-<env>-content` with runtime `python3.12`, handler `handler.lambda_handler`, timeout 30 seconds, memory 512 MB, signed via the `global` signing config, and sourced from S3 key `content/content.zip` (or a versioned key per Decision 10) in the lambda sources bucket. The function SHALL receive environment variables `ENVIRONMENT`, `USERS_TABLE_NAME`, `CONTENT_BUCKET_NAME`, and `CBTC_APP_URL`.

#### Scenario: Function deployed and signed

- **WHEN** the stack is applied
- **THEN** the function exists with the specified runtime, handler, timeout, memory, signing config, and environment variables

### Requirement: IAM role with content and user privileges

The capability SHALL create an IAM role assumable by `lambda.amazonaws.com` and attach (a) the AWS managed policy `AWSLambdaBasicExecutionRole`, (b) an inline policy granting `s3:GetObject`, `s3:PutObject`, and `s3:ListBucket` against the content bucket ARN and its objects, and (c) an inline policy granting `dynamodb:GetItem`, `dynamodb:Scan`, and `dynamodb:PutItem` against the users table ARN.

#### Scenario: Content lambda cannot access other buckets

- **WHEN** the content lambda attempts `s3:GetObject` against a bucket other than the content bucket
- **THEN** the call is denied by IAM

#### Scenario: Content lambda can write the ZIP cache

- **WHEN** the content lambda performs `s3:PutObject` to `downloads/<username>.zip` in the content bucket
- **THEN** the call succeeds under the attached policy

### Requirement: CloudWatch log group

The capability SHALL provision a CloudWatch log group named `/aws/lambda/<project_name>-<env>-content` with retention 30 days. The Lambda function SHALL depend on the log group existing before creation.

#### Scenario: Log group created with retention

- **WHEN** the stack is applied
- **THEN** the log group exists with `retention_in_days = 30`

### Requirement: Outputs published for API Gateway stack

The capability SHALL expose outputs `content_function_arn`, `content_invoke_arn`, and `content_function_name` for consumption by `api-gateway` via remote state.

#### Scenario: Outputs resolvable from API Gateway stack

- **WHEN** the `api-gateway` stack declares `data "terraform_remote_state" "content"`
- **THEN** all three output names return non-empty values

### Requirement: Release artifact and deploy tracking

The capability SHALL be released via a dedicated semantic-release pipeline named `λ - Content` that publishes Git tags `content-vX.Y.Z`, publishes both a versioned (`content/<version>/content.zip`) and a rolling (`content/content.zip`) lambda artifact to the lambda sources bucket, force-updates the Git tag `content-deployed-<env>` on successful apply, and appends a record to `deployments.jsonl`.

#### Scenario: Path filter scopes triggers

- **WHEN** a commit modifies only files under `services/authorizer/**`
- **THEN** the content pipeline does not trigger a release or deploy

#### Scenario: Python or HCL change triggers pipeline

- **WHEN** a commit modifies files under `services/content/**` or `infra/content/**`
- **THEN** the content pipeline runs lint, plan, release, and dev deploy

### Requirement: Resource-level version tagging

Every taggable AWS resource owned by this capability SHALL carry a `DeployedVersion` tag matching the release artifact version, and the Lambda function `Description` SHALL be set to the same version string.

#### Scenario: Function description reflects version

- **WHEN** an operator runs `aws lambda get-function-configuration --function-name <project>-<env>-content`
- **THEN** the `Description` field equals `content-vX.Y.Z` of the latest release applied to that environment

### Requirement: Account-environment guard

The capability SHALL enforce that the AWS account targeted by an apply matches the selected Terraform workspace via the same precondition pattern used by `global`.

#### Scenario: Wrong-account apply blocked

- **WHEN** an operator runs `just infra::content::apply prod` while authenticated to the `dev` AWS account
- **THEN** the apply fails at the precondition before any resource is created or modified
