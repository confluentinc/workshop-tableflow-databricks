# ===============================
# Confluent Tableflow Module
# ===============================
# Creates Provider Integration for Tableflow storage access (AWS S3 or Azure ADLS Gen2)

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.32.0"
    }
  }
}

# ===============================
# AWS Provider Integration (single resource)
# ===============================

resource "confluent_provider_integration" "aws" {
  count = var.cloud_provider == "aws" ? 1 : 0

  display_name = "${var.prefix}-s3-integration-${var.resource_suffix}"

  environment {
    id = var.environment_id
  }

  aws {
    customer_role_arn = var.customer_iam_role_arn
  }
}

# ===============================
# Azure Provider Integration (two-step)
# ===============================

resource "confluent_provider_integration_setup" "azure" {
  count = var.cloud_provider == "azure" ? 1 : 0

  display_name = "${var.prefix}-adls-integration-${var.resource_suffix}"

  environment {
    id = var.environment_id
  }

  cloud = "AZURE"
}

resource "confluent_provider_integration_authorization" "azure" {
  count = var.cloud_provider == "azure" ? 1 : 0

  provider_integration_id = confluent_provider_integration_setup.azure[0].id

  environment {
    id = var.environment_id
  }

  azure {
    customer_azure_tenant_id = var.azure_tenant_id
  }
}
