# ===============================
# Confluent Tableflow Module
# ===============================
# Creates Provider Integration for Tableflow S3 access

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.32.0"
    }
  }
}

# ===============================
# Provider Integration
# ===============================

resource "confluent_provider_integration" "main" {
  display_name = "${var.prefix}-s3-integration-${var.resource_suffix}"

  environment {
    id = var.environment_id
  }

  aws {
    customer_role_arn = var.customer_iam_role_arn
  }
}
