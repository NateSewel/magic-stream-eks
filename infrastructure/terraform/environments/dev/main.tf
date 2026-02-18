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
