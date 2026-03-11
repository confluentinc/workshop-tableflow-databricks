# ===============================
# Confluent Tableflow Module Outputs
# ===============================

output "integration_id" {
  description = "Provider integration ID"
  value = var.cloud_provider == "aws" ? confluent_provider_integration.aws[0].id : (
    var.cloud_provider == "azure" ? confluent_provider_integration_setup.azure[0].id : null
  )
}

# AWS-specific outputs
output "iam_role_arn" {
  description = "Confluent IAM role ARN (AWS only)"
  value       = var.cloud_provider == "aws" ? confluent_provider_integration.aws[0].aws[0].iam_role_arn : null
}

output "external_id" {
  description = "External ID for IAM trust policy (AWS only)"
  value       = var.cloud_provider == "aws" ? confluent_provider_integration.aws[0].aws[0].external_id : null
}

# Azure-specific outputs
output "azure_confluent_multi_tenant_app_id" {
  description = "Confluent multi-tenant application ID for Azure service principal (Azure only)"
  value       = var.cloud_provider == "azure" ? confluent_provider_integration_authorization.azure[0].azure[0].confluent_multi_tenant_app_id : null
}
