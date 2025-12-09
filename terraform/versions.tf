# ===============================
# Terraform and Provider Version Constraints
# ===============================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.32.0"
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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
