data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../modules/vpc"

  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs             = var.azs
  tags            = var.tags
}

module "s3" {
  source = "../../modules/s3"

  environment = var.environment
  account_id  = data.aws_caller_identity.current.account_id
  tags        = var.tags
}

module "rds" {
  source = "../../modules/rds"

  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  db_password             = var.db_password
  allowed_security_groups = [module.asg.asg_sg_id]
  tags                    = var.tags
}

module "asg" {
  source = "../../modules/asg"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ami_id             = var.ami_id
  tags               = var.tags
}

module "eks" {
  source = "../../modules/eks"

  environment    = var.environment
  subnet_ids     = module.vpc.private_subnet_ids
  instance_types = ["t3.small"] # Better resource allocation for EKS
  tags           = var.tags
}

# Kubernetes ConfigMap for non-sensitive app config
resource "kubernetes_config_map" "magic_stream_config" {
  depends_on = [module.eks]

  metadata {
    name      = "magic-stream-api-config"
    namespace = "default"
  }

  data = {
    PORT                    = "8080"
    DATABASE_NAME           = "magic-stream-movies"
    RECOMMENDED_MOVIE_LIMIT = "5"
    ALLOWED_ORIGINS         = var.allowed_origins
  }
}

# Kubernetes Secret for sensitive app secrets
resource "kubernetes_secret" "magic_stream_secrets" {
  depends_on = [module.eks]

  metadata {
    name      = "magic-stream-api-secrets"
    namespace = "default"
  }

  type = "Opaque"

  data = {
    OPENAI_API_KEY           = var.openai_api_key
    MONGODB_URI              = var.mongodb_uri
    SECRET_KEY               = var.secret_key
    REFRESH_TOKEN_SECRET_KEY = var.refresh_token_secret_key
  }
}
