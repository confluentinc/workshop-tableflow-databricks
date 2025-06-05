terraform {
  required_version = ">= 1.1.5"
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.29.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.79.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.98.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# AWS provider configuration
# This is required to manage AWS resources. The region is dynamically set via a variable.
provider "aws" {
  region = var.cloud_region
  # Default tags to apply to all resources
  default_tags {
    tags = {
      Created_by  = "River Hotels AI Agent Terraform script"
      Project     = "Hospitality AI Agent"
      owner_email = var.email
      Environment = var.environment
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

provider "databricks" {
  alias         = "workspace"
  host          = var.databricks_host
  client_id     = var.databricks_service_principal_client_id
  client_secret = var.databricks_service_principal_client_secret
}
