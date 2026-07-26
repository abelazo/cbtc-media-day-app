# Lambda service recipes

# Run the service locally
[group('run')]
run:
  @echo "Running service..."
  uv run python -m src.handler
  @echo "✓ Service running"

# Run service tests
[group('test')]
test:
  @echo "Running service tests..."
  uv run pytest tests/ -v
  @echo "✓ Service tests passed"

# Run tests with coverage
[group('test')]
test-coverage:
  @echo "Running service tests with coverage..."
  uv run pytest tests/ --cov=src --cov-report=term-missing
  @echo "✓ Coverage report complete"

# Lint service
[group('lint')]
lint:
  @echo "Linting service..."
  uv run ruff check .
  uv run ruff format --check .
  @echo "✓ Service linted"

# Format service
[group('lint')]
format:
  @echo "Formatting service..."
  uv run ruff format .
  uv run ruff check --fix .
  @echo "✓ Service formatted"

# Build Lambda deployment package into dist/
[group('build')]
build:
  #!/usr/bin/env bash
  set -eo pipefail

  SERVICE_NAME="$(basename "$PWD")"
  echo "🔨 Building ${SERVICE_NAME} service λ deployment package..."

  DIST_DIR="dist"
  ZIP_FILE="${SERVICE_NAME}.zip"

  echo "🧹 Cleaning up previous build..."
  rm -rf "$DIST_DIR"

  echo "📦 Creating dist directory..."
  mkdir -p "$DIST_DIR"

  echo "📋 Copying source code..."
  cp -r src/* "$DIST_DIR/"

  echo "🗜️  Creating zip file..."
  cd "$DIST_DIR"
  zip -r "$ZIP_FILE" . -q
  cd ..

  echo "✅ Build complete: $DIST_DIR/$ZIP_FILE"

# Remove dist/ and all intermediate build/test/lint artifacts
[group('build')]
clean:
  #!/usr/bin/env bash
  set -eo pipefail

  echo "🧹 Cleaning artifacts..."
  rm -rf dist .pytest_cache .ruff_cache .coverage htmlcov
  find . -type d -name '__pycache__' -exec rm -rf {} +
  echo "✅ Clean complete"

# Upload the built package from dist/ to S3 as <service>-<version>.zip and sign it (requires global infra deployed)
[group('build')]
upload version="v0.0.0-dev":
  #!/usr/bin/env bash
  set -eo pipefail

  SERVICE_NAME="$(basename "$PWD")"
  DIST_DIR="dist"
  ZIP_FILE="${SERVICE_NAME}.zip"
  RELEASE_NAME="${SERVICE_NAME}-{{version}}"
  S3_KEY="${SERVICE_NAME}/${RELEASE_NAME}.zip"
  SIGNED_S3_PREFIX="${SERVICE_NAME}/signed/"

  # Bucket comes from env; signing profile still from global Terraform output
  BUCKET_NAME="${TF_LAMBDA_SOURCES_BUCKET:-}"
  pushd ../../infra/global >& /dev/null
  SIGNING_PROFILE=$(terraform output -raw signing_profile_name 2>/dev/null || echo "")
  popd >& /dev/null

  if [ -z "$BUCKET_NAME" ]; then
      echo "❌ TF_LAMBDA_SOURCES_BUCKET env var not set." >&2
      exit 1
  fi

  SKIP_SIGNING=false
  if [ -z "$SIGNING_PROFILE" ]; then
      echo "⚠️  Warning: Could not get signing profile from Terraform. Skipping signing."
      echo "   Make sure global infrastructure is deployed first."
      SKIP_SIGNING=true
  fi

  echo "☁️  Uploading to S3..."
  aws s3 cp "$DIST_DIR/$ZIP_FILE" "s3://${BUCKET_NAME}/${S3_KEY}"
  echo "✅ Uploaded to s3://${BUCKET_NAME}/${S3_KEY}"

  # Sign the artifact if signing profile is available
  if [ "$SKIP_SIGNING" != "true" ]; then
      echo "🔏 Signing the artifact..."

      # Get the S3 object version ID (required by Signer)
      VERSION_ID=$(aws s3api head-object \
          --bucket "$BUCKET_NAME" \
          --key "$S3_KEY" \
          --query 'VersionId' \
          --output text)

      echo "   S3 object version: $VERSION_ID"

      # Start signing job
      JOB_ID=$(aws signer start-signing-job \
          --source "s3={bucketName=${BUCKET_NAME},key=${S3_KEY},version=${VERSION_ID}}" \
          --destination "s3={bucketName=${BUCKET_NAME},prefix=${SIGNED_S3_PREFIX}}" \
          --profile-name "$SIGNING_PROFILE" \
          --query 'jobId' \
          --output text)

      echo "   Signing job started: $JOB_ID"

      # Wait for the signing job to complete
      echo "   Waiting for signing job to complete..."
      aws signer wait successful-signing-job --job-id "$JOB_ID"

      SIGNED_S3_KEY="${SIGNED_S3_PREFIX}${JOB_ID}.zip"
      STABLE_SIGNED_KEY="${SIGNED_S3_PREFIX}${RELEASE_NAME}.zip"

      # Signer names objects by job-id, not by version. Move to a stable,
      # version-named key so callers can find it without tracking job-ids.
      aws s3 mv "s3://${BUCKET_NAME}/${SIGNED_S3_KEY}" "s3://${BUCKET_NAME}/${STABLE_SIGNED_KEY}"
      echo "✅ Signed artifact: s3://${BUCKET_NAME}/${STABLE_SIGNED_KEY}"
      echo "   Run 'just update-lambda-code {{version}}' to deploy it."
  else
      echo "⏭️  Skipping code signing (signing profile unavailable)"
  fi

# Point the service's Lambda function at the signed package for a given version (as produced by `upload`)
[group('build')]
update-lambda-code version="v0.0.0-dev":
  #!/usr/bin/env bash
  set -eo pipefail

  SERVICE_NAME="$(basename "$PWD")"
  BUCKET_NAME="${TF_LAMBDA_SOURCES_BUCKET:-}"
  RELEASE_NAME="${SERVICE_NAME}-{{version}}"
  SIGNED_S3_KEY="${SERVICE_NAME}/signed/${RELEASE_NAME}.zip"

  if [ -z "$BUCKET_NAME" ]; then
      echo "❌ TF_LAMBDA_SOURCES_BUCKET env var not set." >&2
      exit 1
  fi

  # Resolve function name from service-local Terraform output
  FUNCTION_NAME=""
  if [ -d "infra" ]; then
      pushd infra >& /dev/null
      FUNCTION_NAME=$(terraform output -raw "${SERVICE_NAME}_function_name" 2>/dev/null || echo "")
      popd >& /dev/null
  fi

  if [ -z "$FUNCTION_NAME" ] || [ "$FUNCTION_NAME" = "None" ]; then
      echo "❌ Could not resolve Lambda function name from Terraform output. Make sure the service infra is applied." >&2
      exit 1
  fi

  echo "🚀 Updating Lambda function: $FUNCTION_NAME..."
  aws lambda update-function-code \
      --function-name "$FUNCTION_NAME" \
      --s3-bucket "$BUCKET_NAME" \
      --s3-key "$SIGNED_S3_KEY"
  echo "✅ Lambda function updated with s3://${BUCKET_NAME}/${SIGNED_S3_KEY}"
