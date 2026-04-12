#!/usr/bin/env bash

set -eo pipefail

echo "🔨 Building authorizer Lambda deployment package..."

# Configuration
SERVICE_NAME="authorizer"
DIST_DIR="dist"
ZIP_FILE="${SERVICE_NAME}.zip"
S3_KEY="${SERVICE_NAME}/${ZIP_FILE}"
SIGNED_S3_PREFIX="${SERVICE_NAME}/signed/"

# Get S3 bucket name from Terraform output
pushd ../../infra/global >& /dev/null
BUCKET_NAME=$(terraform output -raw lambda_sources_bucket_name 2>/dev/null || echo "")
popd >& /dev/null

# Get signing profile name from Terraform output
pushd ../../infra/services >& /dev/null
SIGNING_PROFILE=$(terraform output -raw signing_profile_name 2>/dev/null || echo "")
popd >& /dev/null

SKIP_UPLOAD=false
if [ -z "$BUCKET_NAME" ]; then
    echo "⚠️  Warning: Could not get bucket name from Terraform. Skipping upload."
    echo "   Make sure global infrastructure is deployed first."
    SKIP_UPLOAD=true
fi

SKIP_SIGNING=false
if [ -z "$SIGNING_PROFILE" ]; then
    echo "⚠️  Warning: Could not get signing profile from Terraform. Skipping signing."
    echo "   Make sure services infrastructure is deployed first."
    SKIP_SIGNING=true
fi

# Clean up previous build
echo "🧹 Cleaning up previous build..."
rm -rf "$DIST_DIR"

# Create dist directory
echo "📦 Creating dist directory..."
mkdir -p "$DIST_DIR"

# Copy source code
echo "📋 Copying source code..."
cp -r src/* "$DIST_DIR/"

# Install dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    echo "📥 Installing dependencies..."
    pip install -r requirements.txt -t "$DIST_DIR/" --quiet
else
    echo "ℹ️  No requirements.txt found, skipping dependency installation"
fi

# Create zip file in dist directory
echo "🗜️  Creating zip file..."
cd "$DIST_DIR"
zip -r "$ZIP_FILE" . -q
cd ..

echo "✅ Build complete: $DIST_DIR/$ZIP_FILE"

# Upload to S3 if bucket name is available
if [ "$SKIP_UPLOAD" != "true" ]; then
    echo "☁️  Uploading to S3..."

    # Check if AWS profile is set
    if [ -z "$AWS_PROFILE" ]; then
        echo "⚠️  AWS profile not set. Setting LocalStack defaults..."
        export AWS_ACCESS_KEY_ID=test
        export AWS_SECRET_ACCESS_KEY=test
        export AWS_DEFAULT_REGION=eu-west-1
        export AWS_ENDPOINT_URL=http://localhost:4566
    fi

    # Upload to S3
    aws s3 cp "$DIST_DIR/$ZIP_FILE" "s3://${BUCKET_NAME}/${S3_KEY}" ${AWS_ENDPOINT_URL:+--endpoint-url=$AWS_ENDPOINT_URL}

    echo "✅ Uploaded to s3://${BUCKET_NAME}/${S3_KEY}"

    # Sign the artifact if signing profile is available and not using LocalStack
    if [ "$SKIP_SIGNING" != "true" ] && [ -n "$AWS_PROFILE" ]; then
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
        echo "✅ Signed artifact: s3://${BUCKET_NAME}/${SIGNED_S3_KEY}"

        # Update the Lambda function code with the signed artifact
        FUNCTION_NAME=$(aws lambda list-functions \
            --query "Functions[?ends_with(FunctionName, '-authorizer')].FunctionName | [0]" \
            --output text)

        if [ -n "$FUNCTION_NAME" ] && [ "$FUNCTION_NAME" != "None" ]; then
            echo "🚀 Updating Lambda function: $FUNCTION_NAME..."
            aws lambda update-function-code \
                --function-name "$FUNCTION_NAME" \
                --s3-bucket "$BUCKET_NAME" \
                --s3-key "$SIGNED_S3_KEY"
            echo "✅ Lambda function updated with signed code"
        else
            echo "⚠️  Could not find Lambda function. Update it manually:"
            echo "   aws lambda update-function-code --function-name <FUNCTION_NAME> --s3-bucket $BUCKET_NAME --s3-key $SIGNED_S3_KEY"
        fi
    else
        echo "⏭️  Skipping code signing (LocalStack or signing profile unavailable)"
    fi
else
    echo "⏭️  Skipping upload"
fi

echo "🎉 Done! Package available at: $DIST_DIR/$ZIP_FILE"
