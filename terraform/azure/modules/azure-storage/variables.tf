variable "storage_account_prefix" {
  description = "Prefix for the storage account name (3-10 lowercase alphanumeric)"
  type        = string
}

variable "resource_suffix" {
  description = "Unique suffix for resource names"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "common_tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
