# Documentation

This directory contains all project documentation for the CBTC Media Day application.

## Structure

Docs organized per the [Diataxis](https://diataxis.fr/) framework — four modes, by what reader needs:

- [`/tutorials/`](tutorials/README.md) — learning-oriented, hand-holding walkthroughs.
- [`/how-to-guides/`](how-to-guides/README.md) — task-oriented, solve a specific problem.
- [`/reference/`](reference/README.md) — information-oriented, dry technical description.
- [`/explanation/`](explanation/README.md) — understanding-oriented, background and why.

Plus project-specific dirs (predate/sit alongside Diataxis):

### `/architecture/`
Architecture documentation including:
- System architecture diagrams
- Component interactions
- Data flow diagrams
- API documentation
- Deployment architecture

### `/adr/`
Architectural Decision Records (ADRs) documenting important technical decisions.

**Naming convention**: `<number>-<title>.md` (e.g., `001-use-dynamodb-for-state.md`)

## ADR Template

When creating an ADR, use this template:

```markdown
# [Number]. [Title]

**Date**: YYYY-MM-DD
**Status**: Proposed | Accepted | Deprecated | Superseded

## Context
[What is the issue that we're seeing that is motivating this decision?]

## Decision
[What is the change that we're proposing and/or doing?]

## Consequences
[What becomes easier or more difficult to do because of this change?]
```
