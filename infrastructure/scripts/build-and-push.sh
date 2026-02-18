#!/bin/bash

# Exit on any error
set -e

# Configuration
DOCKER_USERNAME="nate247"
API_REPO="magic-stream-api-prod"
WEB_REPO="magic-stream-web-prod"
GIT_SHA=$(git rev-parse --short HEAD || echo "unknown")
TAG=${1:-latest} # Default to latest if no argument provided

echo "Starting Build & Push process (Tag: $TAG, SHA: $GIT_SHA)"

# 1. Verify Docker Hub authentication
if ! docker system info | grep -q "Username: $DOCKER_USERNAME"; then
    echo "Error: Not logged in to Docker Hub as $DOCKER_USERNAME."
    echo "Please run: docker login"
    exit 1
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
