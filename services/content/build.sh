#!/usr/bin/env bash

set -eo pipefail

echo "🔨 Building content service λ deployment package..."

# Configuration
SERVICE_NAME="content"
DIST_DIR="dist"
ZIP_FILE="${SERVICE_NAME}.zip"
S3_KEY="${SERVICE_NAME}/${ZIP_FILE}"
SIGNED_S3_PREFIX="${SERVICE_NAME}/signed/"

# Get S3 bucket name and signing profile from global Terraform output
pushd ../../infra/global >& /dev/null
BUCKET_NAME=$(terraform output -raw lambda_sources_bucket_name 2>/dev/null || echo "")
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
    echo "   Make sure global infrastructure is deployed first."
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

    # Upload to S3
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
        echo "✅ Signed artifact: s3://${BUCKET_NAME}/${SIGNED_S3_KEY}"

        # Resolve function name from service-local Terraform output
        FUNCTION_NAME=""
        if [ -d "infra" ]; then
            pushd infra >& /dev/null
            FUNCTION_NAME=$(terraform output -raw content_function_name 2>/dev/null || echo "")
            popd >& /dev/null
        fi

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
        echo "⏭️  Skipping code signing (signing profile unavailable)"
    fi
else
    echo "⏭️  Skipping upload"
fi

echo "🎉 Done! Package available at: $DIST_DIR/$ZIP_FILE"
