# ===============================
# AWS IAM Module Outputs
# ===============================

output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.main.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.main.name
}

output "role_id" {
  description = "ID of the IAM role"
  value       = aws_iam_role.main.id
}

output "policy_name" {
  description = "Name of the IAM policy"
  value       = aws_iam_role_policy.s3_access.name
}

output "trust_policy_updated" {
  description = "Marker that trust policy was created (Databricks update happens in root module)"
  value       = true
}
