bucket         = "pricing-agent-tf-state-tsynode"
key            = "${get_terraform_workspace()}/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-lock"  # Optional: If you're using DynamoDB for state locking
