## Context

The repository deploys via three Terraform roots: `infra/bootstrap/` (state bucket), `infra/global/` (lambda sources S3 bucket only), and `infra/services/` (everything else — code signing, DynamoDB users table, content S3 bucket, both lambdas, API Gateway, CORS). All stacks share the same backend pattern (`s3` backend with per-env `.config.<env>.tfbackend`, state keys like `services.tfstate`), use `terraform workspace` per environment, and import shared recipes from `infra/infra.recipes.just`.

Consequences of the current layout:
- A lambda code config change re-plans the API Gateway and data resources.
- The users DynamoDB table and content S3 bucket are entangled with compute resources, so destroying or rebuilding "services" risks data loss.
- The authorizer and content lambdas cannot be deployed independently.
- Build scripts (`services/*/build.sh`) and frontend env wiring already assume the lambda-sources bucket lives in `global`; the rest of "globally shared" data was never moved.

Stakeholders: solo developer maintaining the project. Existing per-stack `.releaserc.yaml` (semantic-release) is in place for `bootstrap` and `global`; `services` predates a unified pipeline. Deploy targets: `dev` and `prod` only.

## Goals / Non-Goals

**Goals:**
- Four independent Terraform roots with clear ownership and a deterministic deploy order: `global` → (`authorizer` ∥ `content`) → `api-gateway`.
- Long-lived data resources (content bucket, users table) and shared compute primitives (lambda sources bucket, code signing profile + config) live in `global`.
- Cross-stack wiring via Terraform remote state outputs only (no SSM, no parameter store) to stay consistent with the existing single-account, single-region setup.
- Four independent CI pipelines (one per stack), each with semantic-release versioning, deploying to `dev` then `prod`, with per-environment release tracking.
- Existing build scripts (`services/*/build.sh`) keep working; the lambda-sources bucket name format stays identical.
- Fresh provision into empty `dev` and `prod` AWS accounts — no state migration, no resource imports.

**Non-Goals:**
- Introducing Terragrunt, CDK, or a different IaC tool.
- Multi-region or multi-account topology.
- Changing the runtime auth model, ZIP caching strategy, or DNI normalization.
- Refactoring lambda Python code or the frontend.
- Replacing the `s3` Terraform backend.
- Local cloud emulation — all environments target real AWS.
- Adding new environments beyond `dev` and `prod`.

## Decisions

### 1. Four roots: `global`, `authorizer`, `content`, `api-gateway`

Place each new root at `infra/<name>/` rather than nesting authorizer/content infra inside `services/authorizer/` and `services/content_service/`. Reasons:
- Keeps all Terraform under one tree (`infra/`) — easier to lint, `tflint --recursive`, and `terraform fmt --recursive` from one place.
- Matches the existing pattern (`infra/bootstrap`, `infra/global`).
- The user's request ("within authorizer folder") is satisfied by either layout; the `services/authorizer/infra/` location is still per-service while avoiding mixing Python and HCL trees.
- Alternative considered: `services/authorizer/infra/`. Rejected — would scatter HCL across `services/` and `infra/`, complicating tflint/checkov sweeps and `.releaserc.yaml` placement.

### 2. Cross-stack wiring via `terraform_remote_state`

Each downstream stack reads upstream outputs through `data "terraform_remote_state"` against the same S3 backend with the upstream's state key.

- `authorizer` and `content` read `global` for: `lambda_sources_bucket_name`, `users_table_name`, `users_table_arn`, `content_bucket_name` (content only), `content_bucket_arn` (content only), `signing_config_arn`, `signing_profile_name`.
- `api-gateway` reads `authorizer` (function ARN, invoke ARN, function name) and `content` (function ARN, invoke ARN, function name).

Alternative considered: SSM Parameter Store. Rejected — adds a new runtime dependency and a second source of truth; remote state is the standard Terraform-native answer and already works with the existing S3 backend.

### 3. Code signing profile + config in `global`

Both lambdas share the signing config. Owning it in `global` avoids duplicate signing profiles and lets `services/*/build.sh` (which signs against the profile name) read it from a single output. The signing profile name (currently `signing_profile_name` output) moves from services to global.

### 4. Content S3 bucket and DynamoDB users table in `global`

Both are stateful and outlive any compute. The users table is already shared by both lambdas; the content bucket is shared by content lambda and external producers (photo uploads). Moving them into `global` aligns lifecycle: lambdas can be torn down and rebuilt without touching data.

### 5. Fresh provision, no state migration

Both `dev` and `prod` AWS accounts are empty. The new layout is provisioned from scratch — no `terraform state mv`, no `terraform import`, no parallel running of old + new stacks. The existing `infra/services/` HCL is deleted as part of the same change, before any apply, since nothing in either target account references it.

Implications:
- The change can be authored as a clean rewrite: delete `infra/services/`, add `services/authorizer/infra/`, `services/content/infra/`, `infra/api-gateway/`, extend `infra/global/`, all in one PR.
- No rollback complexity from in-place state surgery. Rollback if needed = `terraform destroy` per stack in reverse order.
- No risk of accidental resource replacement on data resources, because there is no existing data resource to replace.
- The `infra/services/*/terraform.tfstate*` files currently committed (artifacts of past local applies) get deleted; they refer to no live resources.

### 6. Deploy order enforced by `infra/justfile` aggregate recipes

A new top-level recipe (e.g., `apply-all <env>`) runs the stacks in order. The `authorizer` and `content` applies are independent and may run in parallel via shell `&` + `wait` if desired, but the default recipe stays sequential for predictable logs. Each stack keeps its own `init/plan/apply/fmt/validate/lint` recipes via `import '../infra.recipes.just'`.

### 7. API Gateway deployment trigger

The current `aws_api_gateway_deployment.v1` hashes resource IDs to force redeploys. After the split, those resource IDs all live in the `api-gateway` stack and the lambda integration ARN is read from remote state. When a lambda function's ARN changes (e.g., function recreated), `api-gateway` must re-apply. We add the resolved authorizer + content invoke ARNs to the deployment `triggers` so an ARN change forces a new API Gateway deployment.

### 8. `aws_lambda_permission` location

The lambda permission allowing API Gateway to invoke the content lambda lives in `api-gateway` (it references both `aws_api_gateway_rest_api.main.execution_arn` and the content lambda's function name). The function name comes via remote state. Same applies for any authorizer-invocation IAM role — that role belongs in `api-gateway` since it is consumed by `aws_api_gateway_authorizer`.

### 9. Bootstrap unchanged

`infra/bootstrap/` continues to own only the TF-state S3 bucket. New stacks add new state keys (`lambda.authorizer.tfstate`, `lambda.content.tfstate`, `api-gateway.tfstate`) to the existing bucket.

### 10. Four independent CI/CD pipelines with semantic-release

Each of the four stacks (`global`, `authorizer`, `content`, `api-gateway`) gets its own pipeline and its own release artifact, versioned independently via semantic-release.

- `Deploy - Global`
- `λ - Authorizer`
- `λ - Content`
- `Deploy - API Gateway`

**Pipeline structure (per stack)**:
1. **Lint / validate**: `terraform fmt -check`, `tflint`, `checkov`, `trivy` (mirrors current `just infra::<stack>::check`).
2. **Plan on PR**: `terraform plan` against `dev` posted as a PR comment.
3. **Release on merge to `main`**: semantic-release computes the next version from Conventional Commits, tags `<stack>-vX.Y.Z`, generates a changelog, and publishes a GitHub Release. For lambda stacks (`authorizer`, `content`), the release also publishes the lambda ZIP to S3 under a versioned key (`<service>/<version>/<service>.zip`) in addition to the rolling `<service>/<service>.zip`.
4. **Deploy to `dev`**: automatic after release. Runs `terraform apply -var="environment=dev"` in the matching workspace.
5. **Deploy to `prod`**: manual approval gate. Same apply against the `prod` workspace.

**Path filters**: each pipeline triggers only on changes under its own directory:
- `global` → `infra/global/**`
- `λ - authorizer` → `infra/authorizer/**` + `services/authorizer/**` (Python triggers a lambda artifact rebuild)
- `λ - content` → `infra/content/**` + `services/content/**`
- `api-gateway` → `infra/api-gateway/**`

This decoupling is the whole point of the refactor: a content-lambda change does not redeploy global infra or API Gateway.

**Semantic-release scope per pipeline**: each stack's `.releaserc.yaml` filters commits by Conventional Commits `scope` (e.g., scope `infra-global`, `auth`, `content`, `api-gw`). A commit affecting multiple scopes triggers each matching pipeline independently.

**Tag conventions**:
- `infra-global-vX.Y.Z`
- `authorizer-vX.Y.Z`
- `content-vX.Y.Z`
- `api-gateway-vX.Y.Z`

Stack-prefixed tags let four pipelines coexist on the same repo without semantic-release version collisions.

**Commit order coupling**: pipelines are independent, but the deploy *order* (`global` first, then lambdas, then `api-gateway`) still matters at apply time. The pipelines do not orchestrate each other; commit hygiene is the contract — if a release requires e.g. a new `global` output consumed by `api-gateway`, the `global` change must merge and deploy first. Document this in `CLAUDE.md`.

Alternative considered: one monorepo pipeline with a deploy DAG. Rejected — re-couples lifecycles the refactor is trying to separate.

### 11. Per-environment release tracking

Required: at any moment, know which version of each artifact is live in `dev` and in `prod`.

**Mechanism — tag the deployment, not just the build**:
- Each pipeline's deploy job pushes a moving Git tag per environment: `<stack>-deployed-dev` and `<stack>-deployed-prod`, force-updated to the commit being applied. Lets `git show <stack>-deployed-prod` answer "what's in prod" instantly.
- Each Terraform stack tags every AWS resource it manages with `DeployedVersion = "<stack>-vX.Y.Z"` (passed in as a `-var`). Lets the AWS console / tag-based queries answer "what version is this resource on" for any stack.
- For lambda stacks, the lambda `Description` field is set to `"<stack>-vX.Y.Z"` (visible in console without tag inspection).
- The deploy job appends one line to a `deployments.jsonl` in a small S3 audit bucket (created in `bootstrap`): `{"ts": "...", "stack": "...", "version": "...", "env": "...", "commit": "...", "actor": "..."}`. Append-only history for audit.

Alternative considered: GitHub Environments + deployment API. Acceptable but GitHub-coupled and doesn't surface in AWS; keeping the resource-tag + S3 audit pair makes the truth visible from both GitHub *and* AWS.

## Risks / Trade-offs

- **API Gateway deployment goes stale after lambda recreate** → Include resolved lambda invoke ARNs in `aws_api_gateway_deployment.triggers` hash.
- **Circular reference risk** → None, since `api-gateway` depends on both lambda stacks but neither lambda stack depends on `api-gateway`. Authorizer and content do not reference each other.
- **CI/release config drift** → Existing `.releaserc.yaml` files in `infra/global/` and `infra/bootstrap/` set per-stack releases. Add equivalent `.releaserc.yaml` to each new root with stack-prefixed `tagFormat`.
- **Cross-pipeline ordering bugs** → A `global` output change merged after an `api-gateway` change consuming it will leave `api-gateway` failing in CI. Mitigation: PR template checkbox for "downstream stack updated" and a CI guard that runs `terraform plan` on all four stacks for any PR touching `infra/`.
- **Stale deployment tags** → Force-pushed `<stack>-deployed-<env>` tags lose history; the `deployments.jsonl` audit log is the durable record. Bucket has object versioning + lifecycle to retain history.
- **Build scripts hardcode bucket name format** → The lambda-sources bucket name template (`lambda-sources-${env}-${account_id}`) is unchanged; no script edits needed. Verify by grep before final cleanup.
- **Tflint/checkov skip annotations lost in copy** → Keep all `#checkov:skip` and `#trivy:ignore` comments verbatim when copying resources into the new roots.
- **Wrong-account apply** → Each AWS account holds exactly one env; gate every apply with an OIDC role scoped to its account. Workspace selection (`terraform workspace select <env>`) must match the AWS account; add a `precondition` in `providers.tf` asserting `data.aws_caller_identity.current.account_id` equals an expected per-env value.

## Rollout Plan

Both AWS accounts are empty. No migration — provision from zero.

1. **Author new layout (one PR)**:
   - Delete `infra/services/` (HCL + any committed local `terraform.tfstate*`).
   - Create `services/authorizer/infra/`, `services/content/infra/`, `infra/api-gateway/` with resource blocks adapted from the old `services` files. Add `terraform_remote_state` data sources and per-stack `backend.tf` with the new state keys.
   - Extend `infra/global/` with the users table, content bucket, signing profile, and signing config. Add outputs.
   - Add `.releaserc.yaml` to each new root with stack-prefixed `tagFormat`.
   - Update `infra/justfile`, `CLAUDE.md`, and `tests/functional/conftest.py` references.
2. **Bootstrap state buckets**: `terraform apply` `infra/bootstrap/` against `dev`, then `prod`, to create each account's TF-state S3 bucket and the new audit bucket.
3. **First apply — `dev`**: In order, `global` → `authorizer` ∥ `content` → `api-gateway`. Smoke-test `GET /content` after each stack.
4. **Seed data in `dev`**: Upload test photos to the content bucket and write a row to the users table (or run the existing seed script).
5. **Run E2E against `dev`**: `just e2e::run` pointing at the `dev` API Gateway URL.
6. **Wire pipelines**: Add four GitHub Actions workflows under `.github/workflows/`, one per stack, with path filters per Decision 10. Each workflow: lint → plan-on-PR → release-on-merge → deploy-dev → manual-approval-prod.
7. **First apply — `prod`**: Manual approval through the pipeline for each stack in order (`global` → `authorizer` ∥ `content` → `api-gateway`). Verify the `<stack>-deployed-prod` tag and the `deployments.jsonl` audit entry land for each.
8. **Seed data in `prod`** and run a single read-only smoke test.

**Rollback**: If `dev` apply fails, `terraform destroy` the partially-applied stack and fix forward. There is no production data at risk during the first apply because `prod` is empty until step 7.

## Open Questions

- Should `apply-all <env>` parallelize `authorizer` and `content` by default, or keep sequential for log readability? (Default sequential, document the parallel form in `infra/justfile` comments.)
- Does the `signing_profile_name` output need to remain stable for `services/*/build.sh` consumers? (Verify by grep; if the script reads from `infra/services` outputs, retarget to `infra/global`.)
- Are there any unstated consumers of `services` outputs (CI scripts, frontend env wiring, e2e fixtures via `tests/functional/conftest.py`) that need retargeting? (Audit during specs phase; `conftest.py` reads `api_gateway_url` — will move to `api-gateway` stack outputs.)
- Pipeline runner: GitHub Actions or self-hosted? (Assume GitHub Actions to match existing `.releaserc.yaml` setup; confirm before implementation.)
- AWS auth from CI: OIDC role per environment, or static keys in repo secrets? (Recommend OIDC + per-env IAM role with scoped permissions.)
- Lambda artifact versioning: keep the rolling `<service>/<service>.zip` key for backward compat, or only publish versioned keys and update the Terraform `s3_key` per release? (Recommend: publish both — versioned for audit, rolling for the default Terraform reference, with `s3_object_version` pinning if needed.)
- Audit bucket location: standalone bucket in `bootstrap`, or reuse the existing state bucket? (Recommend a dedicated bucket so retention/lifecycle is separable from state.)
