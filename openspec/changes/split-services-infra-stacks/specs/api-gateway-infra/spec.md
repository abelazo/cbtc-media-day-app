## ADDED Requirements

### Requirement: Independent Terraform root

The `api-gateway-infra` capability SHALL be managed by a standalone Terraform root at `infra/api-gateway/` with its own `backend.tf`, `providers.tf`, `versions.tf`, `variables.tf`, `outputs.tf`, and `justfile` importing `infra/infra.recipes.just`. Its Terraform state SHALL be stored under the state key `api-gateway.tfstate`.

#### Scenario: Stack initialises after lambda stacks

- **WHEN** an operator runs `just infra::api-gateway::init <env>` and `just infra::api-gateway::plan <env>` in an account where `global`, `authorizer`, and `content` are applied
- **THEN** init and plan succeed and resolve all upstream remote-state outputs

#### Scenario: Plan fails when lambda stacks missing

- **WHEN** the `api-gateway` stack is planned in an environment where either `authorizer` or `content` has not been applied
- **THEN** the plan fails with a remote-state error before attempting to create resources

### Requirement: Reads authorizer and content remote state

The capability SHALL consume `authorizer_function_arn`, `authorizer_invoke_arn`, `authorizer_function_name` from the `authorizer` stack and `content_function_arn`, `content_invoke_arn`, `content_function_name` from the `content` stack via `terraform_remote_state`. It SHALL NOT redefine those lambda resources locally.

#### Scenario: Lambda ARNs sourced from remote state

- **WHEN** the stack is applied
- **THEN** the API Gateway authorizer and integration reference invoke ARNs read from remote state, not literals

### Requirement: REST API and content resource

The capability SHALL provision a REST API named `<project_name>-<env>-api` with a child resource at path `/content`.

#### Scenario: REST API exists with /content path

- **WHEN** the stack is applied
- **THEN** the REST API exposes `/content` as a child of the root resource

### Requirement: Lambda authorizer attachment

The capability SHALL provision an API Gateway authorizer of type `TOKEN` named `<project_name>-<env>-authorizer`, configured with the authorizer Lambda's invoke ARN, identity source `method.request.header.Authorization`, and an IAM invocation role that grants `lambda:InvokeFunction` on the authorizer function ARN.

#### Scenario: Authorizer invocation role scoped to authorizer function

- **WHEN** the IAM invocation role policy is inspected
- **THEN** its only `Resource` is the authorizer function ARN

### Requirement: GET /content method with custom authorization

The capability SHALL provision a `GET` method on `/content` with authorization type `CUSTOM` referencing the lambda authorizer and an `AWS_PROXY` integration to the content lambda's invoke ARN.

#### Scenario: GET /content invokes content lambda via authorizer

- **WHEN** a client calls `GET /content` with a valid `Authorization` header
- **THEN** API Gateway invokes the authorizer Lambda first, then proxies the request to the content Lambda

### Requirement: CORS preflight on /content

The capability SHALL provision an `OPTIONS` method on `/content` with authorization type `NONE`, a MOCK integration returning HTTP 200, and response headers `Access-Control-Allow-Headers: Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token`, `Access-Control-Allow-Methods: GET,OPTIONS,POST,PUT`, and `Access-Control-Allow-Origin: *`.

#### Scenario: CORS preflight returns 200 with headers

- **WHEN** a client sends `OPTIONS /content` without an Authorization header
- **THEN** the response is HTTP 200 with all three Access-Control-Allow-* headers set to the specified values

### Requirement: Lambda invoke permission

The capability SHALL grant API Gateway permission to invoke the content lambda via an `aws_lambda_permission` resource scoped to `${aws_api_gateway_rest_api.main.execution_arn}/*/*`.

#### Scenario: API Gateway can invoke content lambda

- **WHEN** API Gateway proxies a request to the content lambda
- **THEN** the invocation succeeds without an `AccessDeniedException`

### Requirement: Deployment redeploys when integrations change

The capability SHALL provision an `aws_api_gateway_deployment` whose `triggers` hash includes the IDs of the `/content` resource, the GET method, the OPTIONS method, the content integration, the OPTIONS integration, the authorizer, AND the authorizer and content invoke ARNs sourced from remote state. The stage SHALL be named `v1`.

#### Scenario: Lambda recreation forces new deployment

- **WHEN** a lambda function in `authorizer` or `content` is recreated and its invoke ARN changes
- **THEN** the next `api-gateway` apply produces a new `aws_api_gateway_deployment` revision and the `v1` stage points at it

### Requirement: Outputs published

The capability SHALL expose outputs `api_gateway_url` (the full invoke URL ending in `/content`) and `api_gateway_id`.

#### Scenario: Frontend and E2E resolve the API URL from outputs

- **WHEN** the frontend build or `tests/functional/conftest.py` reads `api_gateway_url` from this stack's state
- **THEN** the value is a non-empty URL pointing at the `v1` stage's `/content` path

### Requirement: Release artifact and deploy tracking

The capability SHALL be released via a dedicated semantic-release pipeline named `Deploy - API Gateway` that publishes Git tags `api-gateway-vX.Y.Z`, force-updates the Git tag `api-gateway-deployed-<env>` on successful apply, and appends a record to `deployments.jsonl`.

#### Scenario: Path filter scopes triggers

- **WHEN** a commit modifies only files under `services/**` or `infra/global/**`
- **THEN** the api-gateway pipeline does not trigger a release or deploy

### Requirement: Resource-level version tagging

Every taggable AWS resource owned by this capability SHALL carry a `DeployedVersion` tag matching the release artifact version (e.g., `api-gateway-v1.2.0`).

#### Scenario: Version visible from AWS

- **WHEN** an operator runs `aws apigateway get-tags --resource-arn <stage-arn>`
- **THEN** a `DeployedVersion` tag is present and matches the latest release version applied to that environment

### Requirement: Account-environment guard

The capability SHALL enforce that the AWS account targeted by an apply matches the selected Terraform workspace via the same precondition pattern used by `global`.

#### Scenario: Wrong-account apply blocked

- **WHEN** an operator runs `just infra::api-gateway::apply prod` while authenticated to the `dev` AWS account
- **THEN** the apply fails at the precondition before any resource is created or modified
