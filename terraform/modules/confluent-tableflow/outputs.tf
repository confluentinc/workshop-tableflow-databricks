# ===============================
# Confluent Tableflow Module Outputs
# ===============================

output "integration_id" {
  description = "Provider integration ID"
  value       = confluent_provider_integration.main.id
}

output "iam_role_arn" {
  description = "Confluent IAM role ARN"
  value       = confluent_provider_integration.main.aws[0].iam_role_arn
}

output "external_id" {
  description = "External ID for IAM trust policy"
  value       = confluent_provider_integration.main.aws[0].external_id
}
