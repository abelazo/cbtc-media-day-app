# Content Service

Lambda service that returns the user's photo bundle as a downloadable ZIP.

## Functionality

- Validates the request via the upstream API Gateway custom authorizer.
- Looks up the user's photo list and DNI(s) in the DynamoDB `users` table.
- Builds a ZIP from S3 objects in the content bucket (or returns a cached ZIP at `downloads/<username>.zip`).
- Returns a presigned URL pointing at the ZIP.

## Testing

```bash
# Run unit tests
pytest services/content/tests/

# Run with coverage
pytest services/content/tests/ --cov=services/content/src
```

## Deployment

This service is deployed as an AWS Lambda function via Terraform in `services/content/infra/`.
