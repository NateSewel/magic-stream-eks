#!/bin/bash

# Exit on any error
set -e

# Configuration
DOCKER_USERNAME="nate247"
API_REPO="magic-stream-api-prod"
WEB_REPO="magic-stream-web-prod"
TAG=${1:-latest} # Default to latest

# Switch to project root
cd "$(dirname "$0")/../.."
GIT_SHA=$(git rev-parse --short HEAD || echo "unknown")

echo "tarting Build & Push process (Tag: $TAG, SHA: $GIT_SHA)"

# 1. Verify Docker Hub authentication
# Try to get the username from 'docker info'
CURRENT_DOCKER_USER=$(docker info 2>/dev/null | grep -i "Username:" | awk '{print $2}')

if [ -z "$CURRENT_DOCKER_USER" ]; then
    echo "Could not detect Docker username automatically. Checking if logged in..."
    if ! docker system info >/dev/null 2>&1; then
        echo "Error: Not logged in to Docker Hub. Please run: docker login"
        exit 1
    fi
    echo "Docker is logged in. Proceeding as $DOCKER_USERNAME..."
else
    echo "Logged in as: $CURRENT_DOCKER_USER"
    DOCKER_USERNAME=$CURRENT_DOCKER_USER
fi

# 2. Build & Push API Image
echo "Building API image..."
docker build -t $DOCKER_USERNAME/$API_REPO:$TAG \
             -t $DOCKER_USERNAME/$API_REPO:$GIT_SHA \
             -f Server/MagicStreamServer/Dockerfile.prod \
             Server/MagicStreamServer

echo "Pushing API image..."
docker push $DOCKER_USERNAME/$API_REPO:$TAG
docker push $DOCKER_USERNAME/$API_REPO:$GIT_SHA

# 3. Build & Push Web Image
echo "Building Web image..."
docker build -t $DOCKER_USERNAME/$WEB_REPO:$TAG \
             -t $DOCKER_USERNAME/$WEB_REPO:$GIT_SHA \
             -f Client/magic-stream-client/Dockerfile.prod \
             Client/magic-stream-client

echo "Pushing Web image..."
docker push $DOCKER_USERNAME/$WEB_REPO:$TAG
docker push $DOCKER_USERNAME/$WEB_REPO:$GIT_SHA

echo "Successfully built and pushed all images!"
echo "API: $DOCKER_USERNAME/$API_REPO:$TAG"
echo "WEB: $DOCKER_USERNAME/$WEB_REPO:$TAG"
