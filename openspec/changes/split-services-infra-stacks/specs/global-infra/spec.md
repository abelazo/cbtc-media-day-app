## ADDED Requirements

### Requirement: Independent Terraform root

The `global` capability SHALL be managed by a standalone Terraform root at `infra/global/` with its own `backend.tf`, `providers.tf`, `versions.tf`, `variables.tf`, `outputs.tf`, and `justfile` importing `infra/infra.recipes.just`.

#### Scenario: Stack initialises and validates independently

- **WHEN** an operator runs `just infra::global::init <env>` followed by `just infra::global::validate` in a clean checkout
- **THEN** Terraform initialises with the per-environment backend config and validation passes without referencing any other Terraform root

### Requirement: Lambda sources S3 bucket

The capability SHALL provision an S3 bucket named `lambda-sources-<env>-<account_id>` with public access fully blocked, versioning enabled, AES256 server-side encryption, a lifecycle rule expiring noncurrent versions after 7 days, and a lifecycle rule aborting incomplete multipart uploads after 7 days.

#### Scenario: Bucket created with required controls

- **WHEN** the `global` stack is applied against a fresh account
- **THEN** the bucket exists with all four `block_public_*` settings true, versioning `Enabled`, default encryption `AES256`, and both lifecycle rules active

### Requirement: Content S3 bucket

The capability SHALL provision an S3 bucket named `<project_name>-<env>-content-<account_id>` with public access fully blocked and AES256 server-side encryption. The bucket SHALL NOT be destroyed by `terraform destroy` unless `force_destroy` is explicitly enabled.

#### Scenario: Content bucket protected from accidental destroy

- **WHEN** the `global` stack is applied
- **THEN** `force_destroy` on the content bucket is `false`

#### Scenario: Public access blocked

- **WHEN** the bucket is queried via `aws s3api get-public-access-block`
- **THEN** all four block flags return `true`

### Requirement: DynamoDB users table

The capability SHALL provision a DynamoDB table named `users` with billing mode `PAY_PER_REQUEST`, hash key `username` of type `S`, and no sort key.

#### Scenario: Users table provisioned

- **WHEN** the `global` stack is applied
- **THEN** the table exists with the schema above and is queryable via `GetItem` by `username`

### Requirement: Lambda code signing profile and config

The capability SHALL provision an AWS Signer signing profile on platform `AWSLambda-SHA384-ECDSA` and a Lambda code signing config that references that profile with `untrusted_artifact_on_deployment = "Enforce"`.

#### Scenario: Unsigned artifacts blocked

- **WHEN** a Lambda function configured with this signing config attempts to deploy code that is not signed by the profile
- **THEN** the deployment is rejected by AWS Lambda

### Requirement: Outputs published for downstream stacks

The capability SHALL expose the following outputs for consumption by downstream Terraform stacks via `terraform_remote_state`: `lambda_sources_bucket_name`, `lambda_sources_bucket_arn`, `content_bucket_name`, `content_bucket_arn`, `users_table_name`, `users_table_arn`, `signing_config_arn`, `signing_profile_name`.

#### Scenario: Outputs resolvable from downstream stack

- **WHEN** a downstream stack declares `data "terraform_remote_state" "global"` against the `global` state key
- **THEN** each of the listed output names returns a non-empty value

### Requirement: Account-environment guard

The capability SHALL enforce that the AWS account targeted by an apply matches the selected Terraform workspace via a precondition asserting `data.aws_caller_identity.current.account_id` equals a value derived from the per-env config.

#### Scenario: Wrong-account apply blocked

- **WHEN** an operator runs `just infra::global::apply prod` while authenticated to the `dev` AWS account
- **THEN** the apply fails at the precondition before any resource is created or modified

### Requirement: Release artifact and deploy tracking

The capability SHALL be released via a dedicated semantic-release pipeline named `Deploy - Global` that publishes Git tags of the form `infra-global-vX.Y.Z` and, on each successful environment apply, force-updates the Git tag `infra-global-deployed-<env>` and appends one JSON line to the deployments audit log in S3.

#### Scenario: Deployment tag updated after apply

- **WHEN** the pipeline successfully applies `global` to `prod`
- **THEN** Git tag `infra-global-deployed-prod` points at the deployed commit and `deployments.jsonl` contains a record with `stack="infra-global"`, `env="prod"`, the deployed version, and the commit SHA

### Requirement: Resource-level version tagging

Every taggable AWS resource owned by this capability SHALL carry a `DeployedVersion` tag whose value equals the release artifact version that produced it (e.g., `infra-global-v1.4.0`).

#### Scenario: Version visible from AWS

- **WHEN** an operator runs `aws s3api get-bucket-tagging` or `aws dynamodb list-tags-of-resource` against a resource owned by `global`
- **THEN** a `DeployedVersion` tag is present and matches the latest release version applied to that environment
