variable "confluent_multi_tenant_app_id" {
  description = "Confluent's multi-tenant application ID (from provider integration authorization)"
  type        = string
}

variable "storage_account_id" {
  description = "Full resource ID of the Azure Storage Account"
  type        = string
}

variable "resource_group_id" {
  description = "Full resource ID of the Azure Resource Group"
  type        = string
}
