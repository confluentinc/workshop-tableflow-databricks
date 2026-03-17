variable "cloud_region" {
  description = "AWS region for shared infrastructure"
  type        = string
  default     = "us-west-2"
}

variable "owner_email" {
  description = "Email address for resource tagging (set via TF_VAR_owner_email from wsa.env)"
  type        = string
  default     = ""
}

variable "prefix" {
  description = "Prefix for shared resource names"
  type        = string
  default     = "wsa-shared"
}

variable "run_id" {
  description = "WSA run ID for resource tagging (enables orphan detection across runs)"
  type        = string
  default     = ""
}

# ---------------------
# Data generation
# ---------------------

variable "data_dir" {
  description = "Absolute path to the data directory containing ShadowTraffic configs (injected by wsa via TF_VAR_data_dir)"
  type        = string
}

# ---------------------
# PostgreSQL
# ---------------------

variable "postgres_instance_type" {
  description = "EC2 instance type for shared PostgreSQL (m5.2xlarge recommended for 95 CDC connectors)"
  type        = string
  default     = "m5.2xlarge"
}

variable "postgres_volume_size" {
  description = "Root volume size in GB (50+ recommended for WAL headroom with 95 replication slots)"
  type        = number
  default     = 50
}

variable "postgres_db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "workshop"
}

variable "postgres_db_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "postgres"
}

variable "postgres_db_password" {
  description = "PostgreSQL admin password (auto-generated if empty)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "postgres_debezium_password" {
  description = "PostgreSQL Debezium CDC user password (auto-generated if empty)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "postgres_max_replication_slots" {
  description = "max_replication_slots (one per CDC connector, need 95+ for full workshop)"
  type        = number
  default     = 100
}

variable "postgres_max_wal_senders" {
  description = "max_wal_senders (one per CDC connector, need 95+ for full workshop)"
  type        = number
  default     = 100
}

variable "postgres_max_connections" {
  description = "max_connections (300 accommodates 95 CDC connectors + admin connections)"
  type        = number
  default     = 300
}

# ---------------------
# Networking
# ---------------------

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access PostgreSQL and SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------
# S3
# ---------------------

variable "s3_expiration_days" {
  description = "Number of days before S3 objects expire"
  type        = number
  default     = 30
}

# ---------------------
# Monitoring
# ---------------------

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications via SNS (defaults to owner_email)"
  type        = string
  default     = ""
}

variable "alarm_cpu_threshold" {
  description = "CPU utilization percentage threshold for alarm"
  type        = number
  default     = 80
}

variable "alarm_memory_threshold" {
  description = "Memory used percentage threshold for alarm"
  type        = number
  default     = 90
}

variable "alarm_disk_threshold" {
  description = "Disk used percentage threshold for alarm"
  type        = number
  default     = 90
}

variable "alarm_replication_lag_bytes" {
  description = "PostgreSQL replication lag threshold in bytes for alarm"
  type        = number
  default     = 104857600 # 100MB
}

variable "alarm_max_connections" {
  description = "Active PostgreSQL connection count threshold for alarm"
  type        = number
  default     = 250
}

# ---------------------
# AWS credentials (passed via TF_VAR_ env vars or .tfvars)
# ---------------------

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

# ---------------------
# Databricks (bridged from TF_VAR_databricks_aws_* by wsa)
# ---------------------

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
  default     = ""
}

variable "databricks_host" {
  description = "Databricks workspace URL (e.g., https://dbc-12345678-abcd.cloud.databricks.com)"
  type        = string
  default     = ""
}

variable "databricks_service_principal_client_id" {
  description = "Databricks service principal Application (Client) ID"
  type        = string
  default     = ""
}

variable "databricks_service_principal_client_secret" {
  description = "Databricks service principal OAuth secret (used to authenticate the provider, not shared with attendees)"
  type        = string
  sensitive   = true
  default     = ""
}
