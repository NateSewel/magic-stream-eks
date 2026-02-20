variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "ami_id" {
  type    = string
  default = "ami-0c7217cdde317cfec" # Amazon Linux 2023 (Example)
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "MagicStreamMastery"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

variable "openai_api_key" {
  type        = string
  sensitive   = true
  description = "OpenAI API key for movie review sentiment analysis"
  default     = ""
}

variable "mongodb_uri" {
  type        = string
  sensitive   = true
  description = "MongoDB connection URI"
  default     = ""
}

variable "secret_key" {
  type        = string
  sensitive   = true
  description = "JWT secret key"
  default     = "dev-secret-key-change-in-prod"
}

variable "refresh_token_secret_key" {
  type        = string
  sensitive   = true
  description = "JWT refresh token secret key"
  default     = "dev-refresh-secret-key-change-in-prod"
}

variable "allowed_origins" {
  type        = string
  description = "CORS allowed origins (comma-separated)"
  default     = "*"
}
