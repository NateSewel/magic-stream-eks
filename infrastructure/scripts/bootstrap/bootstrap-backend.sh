#!/bin/bash
# AWS CLI bootstrap for Terraform backend S3 buckets
ENVIRONMENTS=("dev" "staging" "prod")
REGION="us-east-1"

for env in "${ENVIRONMENTS[@]}"; do
    BUCKET_NAME="magicstream-terraform-state-$env"
    echo "Creating bucket $BUCKET_NAME in $REGION..."
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    
    # Enable server-side encryption
    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'
    
    # Block public access
    aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'
done
