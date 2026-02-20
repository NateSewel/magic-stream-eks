# Build and Push Docker Images

This directory contains scripts for building and pushing Docker images for the MagicStreamMastery project to Docker Hub.

## Overview

Two versions are provided for cross-platform compatibility:

| Script               | Platform           | Usage                               |
| -------------------- | ------------------ | ----------------------------------- |
| `build-and-push.sh`  | Linux/macOS/WSL    | `./build-and-push.sh [tag]`         |
| `build-and-push.ps1` | Windows PowerShell | `.\build-and-push.ps1 -Tag "[tag]"` |

## Prerequisites

### System Requirements

- **Docker**: Installed and running
  ```bash
  # Check Docker
  docker --version
  docker ps
  ```

### Docker Hub Credentials

Two credential methods are supported:

#### Method 1: Environment Variables (Recommended for CI/CD)

```bash
# Linux/macOS/WSL
export DOCKER_USERNAME="your-docker-username"
export DOCKER_PASSWORD="your-docker-password"
./build-and-push.sh v1.0.0

# PowerShell
$env:DOCKER_USERNAME = "your-docker-username"
$env:DOCKER_PASSWORD = "your-docker-password"
.\build-and-push.ps1 -Tag "v1.0.0"
```

#### Method 2: Existing Docker Login (Local Development)

If you've already logged in to Docker, credentials are reused:

```bash
docker login  # One-time setup

# Then run script without env vars
./build-and-push.sh v1.0.0
```

## Usage

### Bash (Linux/macOS/WSL)

```bash
# Make script executable (first time only)
chmod +x scripts/build-and-push.sh

# Build and push with default tag (latest)
./scripts/build-and-push.sh

# Build and push with specific version tag
./scripts/build-and-push.sh v1.0.0

# Build and push with semantic versioning
./scripts/build-and-push.sh v2.5.3-alpha

# Build and push with commit hash
./scripts/build-and-push.sh $(git rev-parse --short HEAD)
```

### PowerShell (Windows)

```powershell
# Build and push with default tag (latest)
.\scripts\build-and-push.ps1

# Build and push with specific version tag
.\scripts\build-and-push.ps1 -Tag "v1.0.0"

# Build and push with semantic versioning
.\scripts\build-and-push.ps1 -Tag "v2.5.3-alpha"

# Build and push with commit hash
.\scripts\build-and-push.ps1 -Tag (git rev-parse --short HEAD)
```

## What the Scripts Do

### Build Process

1. ✓ Verifies Docker daemon is running
2. ✓ Authenticates with Docker Hub (if credentials provided)
3. ✓ Builds client image from `Client/magic-stream-client/Dockerfile.prod`
4. ✓ Builds server image from `Server/MagicStreamServer/Dockerfile.prod`
5. ✓ Pushes both images to Docker Hub
6. ✓ Tags images as "latest" (if tagged with version)

### Output Images

```
docker.io/nate247/magic-stream-web-prod:TAG
docker.io/nate247/magic-stream-api-prod:TAG
```

### Success Indicators

- ✓ All green checkmarks in output
- ✓ Images appear in Docker Hub account
- ✓ No error messages

## Examples

### Local Development Build

```bash
# Build with branch name tag
./scripts/build-and-push.sh dev-feature-x

# Images created:
# - docker.io/nate247/magic-stream-web-prod:dev-feature-x
# - docker.io/nate247/magic-stream-api-prod:dev-feature-x
```

### Production Release Build

```bash
# Build with semantic version
./scripts/build-and-push.sh v1.5.0

# Images created:
# - docker.io/nate247/magic-stream-web-prod:v1.5.0
# - docker.io/nate247/magic-stream-api-prod:v1.5.0
# - docker.io/nate247/magic-stream-web-prod:latest  (auto-tagged)
# - docker.io/nate247/magic-stream-api-prod:latest   (auto-tagged)
```

### CI/CD Build with Environment Variables

```bash
# GitHub Actions or other CI systems
export DOCKER_USERNAME=${{ secrets.DOCKER_USERNAME }}
export DOCKER_PASSWORD=${{ secrets.DOCKER_PASSWORD }}
export TAG=$(git rev-parse --short HEAD)

./scripts/build-and-push.sh $TAG
```

## Troubleshooting

### Docker daemon not running

```
Error: Docker daemon is not running
```

**Solution**: Start Docker

```bash
# Linux
sudo systemctl start docker

# macOS
open /Applications/Docker.app

# Windows
# Start Docker Desktop from Start menu
```

### Docker login failed

```
Error: Docker login failed
```

**Solutions**:

1. Verify credentials are correct

   ```bash
   docker login -u your-username
   ```

2. Check if credentials file exists

   ```bash
   # Linux/macOS
   cat ~/.docker/config.json

   # Windows
   type $env:USERPROFILE\.docker\config.json
   ```

3. Generate Personal Access Token on Docker Hub
   - Go to: https://hub.docker.com/settings/security
   - Create "New Access Token"
   - Use token instead of password

### Permission denied (Linux/macOS)

```
Error: Permission denied: ./build-and-push.sh
```

**Solution**: Make script executable

```bash
chmod +x scripts/build-and-push.sh
```

### Image already exists error

The script overwrites existing tags. This is expected behavior. To keep old versions:

```bash
# Use different tags
./scripts/build-and-push.sh v1.0.0
./scripts/build-and-push.sh v2.0.0
```

### Insufficient disk space

```
Error: No space left on device
```

**Solution**: Clean up Docker images

```bash
# Remove unused images
docker image prune -a

# Remove build cache
docker builder prune
```

## Integration with Kubernetes

After successfully pushing images, update Kubernetes deployments:

```bash
# Update deployment to use new image tag
kubectl set image deployment/server \
  server=docker.io/nate247/magic-stream-api-prod:v1.0.0

kubectl set image deployment/client \
  client=docker.io/nate247/magic-stream-web-prod:v1.0.0

# Verify rollout
kubectl rollout status deployment/server
kubectl rollout status deployment/client
```

Or use GitOps for automated updates:

```bash
# Update Kubernetes manifests in git
# Let ArgoCD or FluxCD auto-deploy
cd infrastructure/kubernetes/base
# Edit server.yaml, client.yaml with new image tags
git add server.yaml client.yaml
git commit -m "chore: update images to v1.0.0"
git push
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Push to Docker Hub

on:
  push:
    branches: [main, develop]
    paths:
      - "Client/**"
      - "Server/**"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker
        uses: docker/setup-buildx-action@v2

      - name: Build and Push Images
        env:
          DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
          DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
        run: |
          chmod +x scripts/build-and-push.sh
          ./scripts/build-and-push.sh ${{ github.sha }}
```

### GitLab CI Example

```yaml
build-and-push:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - chmod +x scripts/build-and-push.sh
    - ./scripts/build-and-push.sh $CI_COMMIT_SHA
  only:
    - main
    - develop
```

## Security Best Practices

### 1. Don't Commit Credentials

```bash
# ❌ WRONG - Never do this
export DOCKER_PASSWORD="hunter2"
./build-and-push.sh

# ✓ RIGHT - Use GitHub Secrets or similar
```

### 2. Use Personal Access Tokens

```bash
# On Docker Hub: Settings → Security → New Access Token
# Create token with limited scope (read/write)
export DOCKER_PASSWORD="dckr_pat_abcd1234..."
./build-and-push.sh
```

### 3. Rotate Credentials Regularly

- Change Docker Hub password monthly
- Regenerate PATs quarterly
- Monitor Docker Hub activity logs

### 4. Use Separate Credentials per Environment

```bash
# Development
export DOCKER_USERNAME="dev-bot"

# Production
export DOCKER_USERNAME="prod-bot"
```

## Monitoring

### Check Image Status

```bash
# List all images built
docker image ls | grep magic-stream

# Inspect specific image
docker image inspect docker.io/nate247/magic-stream-api-prod:latest

# Check image size
docker image ls docker.io/nate247/magic-stream-api-prod
```

### View Build History

```bash
# On Docker Hub
# https://hub.docker.com/repository/docker/nate247/magic-stream-api-prod/builds
```

## Performance Optimization

### Speed Up Builds

**1. Use BuildKit** (Docker 18.09+)

```bash
export DOCKER_BUILDKIT=1
./scripts/build-and-push.sh v1.0.0
```

**2. Multi-Stage Builds**
Already configured in `Dockerfile.prod` files to reduce layer size.

**3. Parallel Builds** (Bash only)

```bash
# Modify script to build concurrently
docker build ... &
docker build ... &
wait
```

### Reduce Image Size

```bash
# Check layer sizes
docker history docker.io/nate247/magic-stream-api-prod:latest

# Optimize Dockerfile to minimize layers
# - Combine RUN commands
# - Remove unnecessary dependencies
# - Use specific base image versions
```

## Advanced Usage

### Build Specific Component Only

```bash
# Modify scripts or run Docker directly
docker build -f Client/magic-stream-client/Dockerfile.prod \
  -t docker.io/nate247/magic-stream-web-prod:dev \
  Client/magic-stream-client
```

### Custom Registry

Edit script to change:

```bash
# Before
REGISTRY="docker.io"

# After - for Amazon ECR
REGISTRY="123456789.dkr.ecr.us-east-1.amazonaws.com"
```

### Build with Build Arguments

```bash
# Modify Dockerfile and script to support build args
ARG BUILD_DATE
ARG VCS_REF
```

## Support

For issues or questions:

1. Check troubleshooting section above
2. Review Dockerfile configurations
3. Check Docker daemon logs: `docker info`
4. Consult Docker documentation: https://docs.docker.com/

## References

- [Docker Build Documentation](https://docs.docker.com/engine/reference/commandline/build/)
- [Docker Push Documentation](https://docs.docker.com/engine/reference/commandline/push/)
- [Docker Hub Repository](https://hub.docker.com/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/dockerfile_best-practices/)
