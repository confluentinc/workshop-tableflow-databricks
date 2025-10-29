variable "email" {
  description = "Your email to tag all AWS resources"
  type        = string
}

variable "call_sign" {
  description = "Call sign to use in prefix for resource names, it could be your initials or your first name"
  type        = string
  default     = "neo"
}

variable "project_name" {
  description = "Name of this project to use in prefix for resource names"
  type        = string
  default     = "tf-db" # Shortened to avoid Databricks 64-char function name limit
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cloud_region" {
  description = "AWS Cloud Region"
  type        = string
}

# ---------------------
# AWS variables
# ---------------------

variable "oracle_instance_type" {
  description = "Oracle DB instance type"
  type        = string
  default     = "t3.large"
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_session_token" {
  description = "AWS Session Token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_bedrock_anthropic_model_id" {
  description = "AWS Bedrock Anthropic Model ID for Claude 3.7 Sonnet"
  type        = string
  default     = ""
}

# ---------------------
# Confluent Cloud variables
# ---------------------

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

# ---------------------
# Oracle DB variables
# ---------------------

variable "oracle_db_name" {
  description = "Oracle DB Name"
  type        = string
  default     = "XE"
}

variable "oracle_db_username" {
  description = "Oracle DB username"
  type        = string
  default     = "system"
}

variable "oracle_db_password" {
  description = "Oracle DB password"
  type        = string
  default     = "Welcome1"
  sensitive   = true
}

variable "oracle_db_port" {
  description = "Oracle DB port"
  type        = number
  default     = 1521
}

variable "oracle_pdb_name" {
  description = "Oracle DB Name"
  type        = string
  default     = "XEPDB1"
}

variable "oracle_xstream_user_username" {
  description = "Oracle DB Username"
  type        = string
  default     = "c##cfltuser"
}

variable "oracle_xstream_user_password" {
  description = "Oracle DB Password"
  type        = string
  sensitive   = true
  default     = "password"
}

variable "oracle_db_table_include_list" {
  description = "Oracle tables include list for Oracle Xstream connector to stream"
  type        = string
  default     = "SAMPLE[.]"
}

variable "oracle_xtream_outbound_server_name" {
  description = "Oracle Xstream outbound server name"
  type        = string
  default     = "XOUT"
}


# ---------------------
# Databricks variables
# ---------------------


variable "databricks_workspace_name" {
  description = "Databricks workspace name"
  type        = string
  default     = "tableflow-databricks"
}

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
  sensitive   = true
}

variable "databricks_service_principal_client_id" {
  description = "Databricks service principal client ID"
  type        = string
  sensitive   = true
}

variable "databricks_service_principal_client_secret" {
  description = "Databricks service principal client secret"
  type        = string
  sensitive   = true
}

variable "databricks_host" {
  description = "The Databricks workspace URL (e.g., https://your-workspace.cloud.databricks.com)"
  type        = string
}

variable "databricks_user_email" {
  description = "Databricks user email to grant permissions to external location"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access Oracle DB and SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Default is open to all, but should be restricted in production
}
