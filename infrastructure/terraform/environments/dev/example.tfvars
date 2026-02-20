# Example Terraform variables file
# Copy this to dev.tfvars and fill in your actual values
# IMPORTANT: dev.tfvars is in .gitignore and should NEVER be committed

db_password                  = "your-secure-db-password"
openai_api_key               = "sk-your-openai-api-key"
mongodb_uri                  = "mongodb+srv://username:password@cluster.mongodb.net/magic-stream-movies?appName=Magic-Stream"
secret_key                   = "your-jwt-secret-min-32-chars-xxxxxxxx"
refresh_token_secret_key     = "your-jwt-refresh-secret-min-32-chars-xx"
allowed_origins              = "http://localhost:3000,http://localhost:8081"
