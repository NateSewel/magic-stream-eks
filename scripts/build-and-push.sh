#!/bin/bash
# Build and Push Docker Images for MagicStreamMastery
# Usage: ./build-and-push.sh [tag]
# Default tag: latest

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="docker.io"
NAMESPACE="nate247"
CLIENT_IMAGE="magic-stream-web-prod"
SERVER_IMAGE="magic-stream-api-prod"
TAG="${1:-latest}"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE} MagicStreamMastery Docker Build & Push${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if Docker is running
echo -e "${BLUE}Checking Docker daemon...${NC}"
if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker daemon is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon is running${NC}"

# Check if Docker Hub credentials are available
echo ""
echo -e "${BLUE}Checking Docker Hub authentication...${NC}"
if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
    echo -e "${YELLOW}Docker credentials not found in environment${NC}"
    echo -e "${YELLOW}Attempting to use existing Docker credentials...${NC}"
    if ! docker info | grep -q "Username"; then
        echo -e "${YELLOW}Please log in to Docker Hub:${NC}"
        docker login
    fi
else
    echo -e "${BLUE}Logging in to Docker Hub...${NC}"
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
fi
echo -e "${GREEN}✓ Docker Hub authentication successful${NC}"

# Build Client
echo ""
echo -e "${BLUE}Building Client Image...${NC}"
echo -e "${YELLOW}Context: Client/magic-stream-client${NC}"
echo -e "${YELLOW}Dockerfile: Client/magic-stream-client/Dockerfile.prod${NC}"
echo -e "${YELLOW}Tag: $REGISTRY/$NAMESPACE/$CLIENT_IMAGE:$TAG${NC}"

if docker build \
    -f Client/magic-stream-client/Dockerfile.prod \
    -t "$REGISTRY/$NAMESPACE/$CLIENT_IMAGE:$TAG" \
    Client/magic-stream-client; then
    echo -e "${GREEN}✓ Client image built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build client image${NC}"
    exit 1
fi

# Build Server
echo ""
echo -e "${BLUE}Building Server Image...${NC}"
echo -e "${YELLOW}Context: Server/MagicStreamServer${NC}"
echo -e "${YELLOW}Dockerfile: Server/MagicStreamServer/Dockerfile.prod${NC}"
echo -e "${YELLOW}Tag: $REGISTRY/$NAMESPACE/$SERVER_IMAGE:$TAG${NC}"

if docker build \
    -f Server/MagicStreamServer/Dockerfile.prod \
    -t "$REGISTRY/$NAMESPACE/$SERVER_IMAGE:$TAG" \
    Server/MagicStreamServer; then
    echo -e "${GREEN}✓ Server image built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build server image${NC}"
    exit 1
fi

# Push images
echo ""
echo -e "${BLUE}Pushing images to Docker Hub...${NC}"

echo ""
echo -e "${BLUE}Pushing client image...${NC}"
if docker push "$REGISTRY/$NAMESPACE/$CLIENT_IMAGE:$TAG"; then
    echo -e "${GREEN}✓ Client image pushed successfully${NC}"
    echo -e "${GREEN}  Location: $REGISTRY/$NAMESPACE/$CLIENT_IMAGE:$TAG${NC}"
else
    echo -e "${RED}✗ Failed to push client image${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Pushing server image...${NC}"
if docker push "$REGISTRY/$NAMESPACE/$SERVER_IMAGE:$TAG"; then
    echo -e "${GREEN}✓ Server image pushed successfully${NC}"
    echo -e "${GREEN}  Location: $REGISTRY/$NAMESPACE/$SERVER_IMAGE:$TAG${NC}"
else
    echo -e "${RED}✗ Failed to push server image${NC}"
    exit 1
fi

# Tag as latest if not already
if [ "$TAG" != "latest" ]; then
    echo ""
    echo -e "${BLUE}Tagging images as latest...${NC}"
    
    docker tag "$REGISTRY/$NAMESPACE/$CLIENT_IMAGE:$TAG" "$REGISTRY/$NAMESPACE/$CLIENT_IMAGE:latest"
    docker tag "$REGISTRY/$NAMESPACE/$SERVER_IMAGE:$TAG" "$REGISTRY/$NAMESPACE/$SERVER_IMAGE:latest"
    
    docker push "$REGISTRY/$NAMESPACE/$CLIENT_IMAGE:latest"
    docker push "$REGISTRY/$NAMESPACE/$SERVER_IMAGE:latest"
    
    echo -e "${GREEN}✓ Images tagged and pushed as latest${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}       Build and Push Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  Client: $REGISTRY/$NAMESPACE/$CLIENT_IMAGE:$TAG"
echo "  Server: $REGISTRY/$NAMESPACE/$SERVER_IMAGE:$TAG"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Update Kubernetes manifests if needed"
echo "  2. Deploy to Kubernetes:"
echo "     kubectl apply -k infrastructure/kubernetes/base"
echo "  3. Verify deployment:"
echo "     kubectl get pods"
echo "     kubectl logs -l app=server"
echo ""
