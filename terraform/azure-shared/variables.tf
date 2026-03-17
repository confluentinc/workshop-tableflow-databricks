variable "cloud_region" {
  description = "Azure region for shared infrastructure"
  type        = string
  default     = "eastus2"
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

variable "resource_group_name" {
  description = "Name of the Azure resource group for shared infrastructure"
  type        = string
  default     = "wsa-shared-infra-rg"
}

# ---------------------
# Data generation
# ---------------------

variable "data_dir" {
  description = "Absolute path to the data directory containing ShadowTraffic configs (injected by wsa via TF_VAR_data_dir)"
  type        = string
}

# ---------------------
# Virtual Machine (PostgreSQL + ShadowTraffic)
# ---------------------

variable "vm_size" {
  description = "Azure VM size for shared PostgreSQL (Standard_D4s_v5 ≈ 4 vCPU, 16 GB)"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "vm_disk_size_gb" {
  description = "OS disk size in GB (50+ recommended for WAL headroom with 95 replication slots)"
  type        = number
  default     = 50
}

variable "vm_admin_username" {
  description = "Admin username for the Azure VM"
  type        = string
  default     = "azureuser"
}

# ---------------------
# PostgreSQL
# ---------------------

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
  description = "CIDR blocks allowed to access PostgreSQL and SSH (NSG rules)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vnet_address_space" {
  description = "Address space for the shared VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefix" {
  description = "Address prefix for the shared subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# ---------------------
# Storage (ADLS Gen2)
# ---------------------

variable "storage_account_prefix" {
  description = "Prefix for the storage account name (3-10 lowercase alphanumeric chars; random suffix appended)"
  type        = string
  default     = "wsashared"
}

variable "storage_container_name" {
  description = "Name of the ADLS Gen2 container"
  type        = string
  default     = "workshop"
}

# ---------------------
# Monitoring
# ---------------------

variable "alert_email" {
  description = "Email address for Azure Monitor alert notifications (defaults to owner_email)"
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
# Databricks (bridged from TF_VAR_databricks_azure_* by wsa)
# ---------------------

variable "databricks_host" {
  description = "Databricks workspace URL (e.g., https://adb-1234567890.12.azuredatabricks.net)"
  type        = string
  default     = ""
}

variable "databricks_service_principal_client_id" {
  description = "Databricks service principal Application (Client) ID"
  type        = string
  default     = ""
}

variable "databricks_service_principal_client_secret" {
  description = "Databricks service principal OAuth secret"
  type        = string
  sensitive   = true
  default     = ""
}
