# CBTC Media Day - Architecture Overview

**Last Updated**: 2025-12-03

## System Overview

CBTC Media Day is a serverless application built on AWS using Lambda functions for compute, with infrastructure managed through Terraform.

## Architecture Principles

1. **Serverless-First**: Use AWS Lambda for all compute workloads
2. **Infrastructure as Code**: All infrastructure defined in Terraform
3. **Event-Driven**: Services communicate via AWS EventBridge/SNS/SQS where appropriate
4. **Test-Driven**: All features developed using TDD methodology
5. **Single Responsibility**: Each Lambda service has a clear, focused purpose

## High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                   API Gateway                        │
│            (RESTful API / WebSocket)                 │
└──────────────────┬──────────────────────────────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
    ┌────▼────┐         ┌────▼────┐
    │ Lambda  │         │ Lambda  │
    │ Service │         │ Service │
    │   A     │         │   B     │
    └────┬────┘         └────┬────┘
         │                   │
         └─────────┬─────────┘
                   │
         ┌─────────▼─────────┐
         │                   │
    ┌────▼────┐         ┌────▼────┐
    │DynamoDB │         │   S3    │
    │         │         │         │
    └─────────┘         └─────────┘
```

## Technology Stack

- **Compute**: AWS Lambda (Python 3.12)
- **API Layer**: AWS API Gateway
- **Database**: AWS DynamoDB
- **Storage**: AWS S3
- **Messaging**: AWS SNS/SQS/EventBridge
- **Infrastructure**: Terraform
- **CI/CD**: GitHub Actions

## Service Organization

Services are organized as independent Lambda functions, each with:
- Isolated source code in `/services/<service_name>/src/`
- Unit tests in `/services/<service_name>/tests/`
- Dedicated `requirements.txt` for dependencies
- Service-local Terraform stack in `/services/<service_name>/infra/`

Shared infrastructure (lambda sources bucket, content bucket, users table, code signing) lives in `/infra/global/`. The API Gateway REST API + integrations live in `/infra/api-gateway/`.

## Data Flow

[To be documented as services are developed]

## Security Considerations

- Lambda functions use least-privilege IAM roles
- API Gateway endpoints protected with authorization
- Secrets managed via AWS Secrets Manager
- All data encrypted at rest and in transit

## Deployment Strategy

1. **Development**: Deployed on every merge to `main` branch
2. **Production**: Deployed with manual approval after successful dev deployment

## Monitoring & Observability

- CloudWatch Logs for all Lambda functions
- CloudWatch Metrics for performance monitoring
- X-Ray for distributed tracing (where applicable)

## Future Considerations

[To be updated as architecture evolves]
