# Guide: Managing Application Variables in Kubernetes with Terraform

This guide explains how to transition your environment variables from `docker-compose.yaml` to a production-grade Kubernetes setup using Terraform.

## 1. The Strategy: Source of Truth
In Kubernetes, variables are managed via **ConfigMaps** (for non-sensitive data) and **Secrets** (for sensitive data). Terraform will act as the orchestrator to create these resources.

---

## 2. Step-by-Step Implementation

### Step 1: Define Terraform Variables
In your `infrastructure/terraform/environments/dev/variables.tf`, add the variables you found in your `docker-compose.yaml`:

```hcl
variable "openai_api_key" {
  type      = string
  sensitive = true
}

variable "mongodb_uri" {
  type    = string
  default = "mongodb+srv://..."
}

variable "allowed_origins" {
  type    = string
  default = "*"
}
```

### Step 2: Configure the Kubernetes Provider
Ensure your `provider.tf` can communicate with the EKS cluster created by your module:

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
```

### Step 3: Create ConfigMaps and Secrets
Add these resources to your `infrastructure/terraform/environments/dev/main.tf`:

```hcl
resource "kubernetes_config_map" "api_config" {
  metadata {
    name      = "magic-stream-api-config"
    namespace = "default"
  }

  data = {
    PORT                   = "8080"
    DATABASE_NAME          = "magic-stream-movies"
    RECOMMENDED_MOVIE_LIMIT = "5"
    MONGODB_URI            = var.mongodb_uri
    ALLOWED_ORIGINS        = var.allowed_origins
  }
}

resource "kubernetes_secret" "api_secrets" {
  metadata {
    name      = "magic-stream-api-secrets"
    namespace = "default"
  }

  data = {
    OPENAI_API_KEY           = var.openai_api_key
    SECRET_KEY               = "your-secret-key"
    REFRESH_TOKEN_SECRET_KEY = "your-refresh-token-key"
  }
}
```

### Step 4: Map Variables to Kubernetes Pods
Update your `infrastructure/kubernetes/base/server.yaml` to consume these resources. Using `envFrom` is the most efficient way to inject all keys at once.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: server
spec:
  template:
    spec:
      containers:
      - name: server
        image: nate247/magic-stream-api-prod:latest
        envFrom:
        - configMapRef:
            name: magic-stream-api-config
        - secretRef:
            name: magic-stream-api-secrets
```

### Step 5: Handling the Frontend (React/Vite)
Frontend variables (like `API_URL`) are often injected into a global `window` object in containerized environments. Map the variable in `infrastructure/kubernetes/base/client.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
spec:
  template:
    spec:
      containers:
      - name: client
        image: nate247/magic-stream-web-prod:latest
        env:
        - name: API_URL
          value: "http://server:80" # K8s Service Name
```

---

## 3. How to Deploy

1.  **Initialize and Plan**:
    ```bash
    terraform init
    terraform plan -var="openai_api_key=sk-..."
    ```
2.  **Apply**:
    ```bash
    terraform apply -var="openai_api_key=sk-..."
    ```
3.  **Verify**:
    ```bash
    kubectl get configmaps,secrets
    kubectl describe pod <server-pod-name> # Check 'Environment' section
    ```

## 4. Why this is better than Docker Compose
- **Security**: Secrets are encrypted at rest in ETCD and not stored in your Git repository.
- **Dynamic Updates**: Changing a ConfigMap in Terraform and re-deploying is faster and more reliable than manual `.env` file management.
- **Scaling**: All replicas in your EKS cluster will automatically share the same environment configuration.
