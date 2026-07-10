# Architecture

Monorepo containing all services, infrastructure, and documentation for the CBTC Media Day application — Python 3.12 Lambdas + Terraform, TDD.

Deploy order: `global` → (`authorizer` ∥ `content`) → `api-gateway`. Downstream stacks read upstream outputs via `terraform_remote_state`, so upstream must apply first. See `just deploy-all <env>`.

See [architecture/overview.md](../architecture/overview.md) for the deeper system design. File-layout tree lives in [CLAUDE.md](../../CLAUDE.md#directory-structure) (agent-facing reference, kept next to the commands that operate on those dirs).
