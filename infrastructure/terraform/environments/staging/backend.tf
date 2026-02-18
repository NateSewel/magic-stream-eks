terraform {
  backend "s3" {
    bucket       = "magicstream-terraform-state-staging"
    key          = "staging/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
