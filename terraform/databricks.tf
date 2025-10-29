
# ===============================
# Storage Credential
# ===============================
#
# Creates a Unity Catalog storage credential that allows Databricks to securely
# access AWS S3 buckets using IAM roles instead of access keys.
#
# Key Properties:
# - name: Unique identifier for the credential within the workspace
# - aws_iam_role.role_arn: IAM role that Databricks assumes to access S3
#   This role must have permissions to read/write to the S3 bucket and
#   trust policy allowing Databricks to assume it
# - comment: Human-readable description for documentation
#
# Why needed: Unity Catalog requires explicit storage credentials to access
# external S3 locations. This provides secure, role-based access without
# embedding AWS access keys in Databricks configurations.
#
# References:
# - Storage Credentials: https://docs.databricks.com/en/sql/language-manual/sql-ref-storage-credentials.html
# - Unity Catalog Security: https://docs.databricks.com/en/data-governance/unity-catalog/manage-external-locations-and-credentials.html
# - Terraform Provider: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/storage_credential

resource "databricks_storage_credential" "external_credential" {
  provider = databricks.workspace

  name    = "${local.prefix}-storage-credential-${local.resource_suffix}"
  comment = "Storage credential for Unity Catalog S3 access - ${local.resource_suffix}"

  aws_iam_role {
    role_arn = aws_iam_role.s3_access_role.arn
  }

  depends_on = [
    aws_iam_role.s3_access_role,
    aws_iam_role_policy.s3_access_policy
  ]
}

# ===============================
# External Location
# ===============================
#
# Defines an external storage location that Unity Catalog can access for
# external tables. This links a specific S3 path with a storage credential.
#
# Key Properties:
# - name: Unique identifier for this location within the workspace
# - url: S3 path that this location represents (must end with /)
# - credential_name: Storage credential to use for accessing this location
#   Links to the storage credential created above
# - force_destroy: Allows Terraform to delete location even if tables exist
#   Important for workshop cleanup - in production, consider setting to false
# - comment: Documentation describing the purpose of this location
#
# Why needed: External locations define WHERE external tables can be created
# and WHICH credentials to use. This enables Tableflow to create Delta Lake
# tables in our S3 bucket with proper Unity Catalog governance.
#
# References:
# - External Locations: https://docs.databricks.com/en/sql/language-manual/sql-ref-external-locations.html
# - Delta Lake External Tables: https://docs.databricks.com/en/delta/external-tables.html
# - Terraform Provider: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/external_location

resource "databricks_external_location" "s3_bucket" {
  provider = databricks.workspace

  name            = "${local.prefix}-external-location-${local.resource_suffix}"
  url             = "s3://${aws_s3_bucket.tableflow_bucket.bucket}/"
  credential_name = databricks_storage_credential.external_credential.name
  comment         = "External location for Unity Catalog S3 access - ${local.resource_suffix}"
  force_destroy   = true

  depends_on = [
    null_resource.wait_for_final_trust_policy_propagation
  ]
}

# ===============================
# Storage Credential Grants
# ===============================
#
# Grants permissions on the storage credential to users and service principals.
# These permissions control who can use the credential to access S3.
#
# Key Privileges Explained:
# - ALL_PRIVILEGES: Administrative control over the credential
# - CREATE_EXTERNAL_LOCATION: Can create new external locations using this credential
# - CREATE_EXTERNAL_TABLE: Can create external tables using this credential
# - READ_FILES: Can read files from S3 locations using this credential
# - WRITE_FILES: Can write files to S3 locations using this credential
#
# Why both user and service principal need these:
# - User: For interactive development and testing in Databricks workspace
# - Service Principal: For Tableflow automation to create external tables
#   The service principal acts on behalf of the Tableflow service
#
# References:
# - Unity Catalog Privileges: https://docs.databricks.com/en/data-governance/unity-catalog/manage-privileges/privileges.html
# - Service Principals: https://docs.databricks.com/en/administration-guide/users-groups/service-principals.html
# - Terraform Grants: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grants

resource "databricks_grants" "storage_credential_grants" {
  provider = databricks.workspace

  storage_credential = databricks_storage_credential.external_credential.name

  grant {
    principal = var.databricks_user_email
    privileges = [
      "ALL_PRIVILEGES",
      "CREATE_EXTERNAL_LOCATION",
      "CREATE_EXTERNAL_TABLE",
      "READ_FILES",
      "WRITE_FILES"
    ]
  }

  grant {
    principal = var.databricks_service_principal_client_id
    privileges = [
      "ALL_PRIVILEGES",
      "CREATE_EXTERNAL_LOCATION",
      "CREATE_EXTERNAL_TABLE",
      "READ_FILES",
      "WRITE_FILES"
    ]
  }
}

# ===============================
# External Location Grants
# ===============================
#
# Grants permissions on the external location to control who can create
# external tables and access files at this S3 location.
#
# User Privileges:
# - ALL_PRIVILEGES: Full administrative control over this location
# - MANAGE: Can modify location settings and permissions
# - CREATE_EXTERNAL_TABLE: Can create external tables at this location
# - CREATE_EXTERNAL_VOLUME: Can create external volumes for file access
# - READ_FILES: Can read files from the S3 location
# - WRITE_FILES: Can write files to the S3 location
# - CREATE_MANAGED_STORAGE: Can create managed storage at this location
#
# Service Principal Privileges:
# - ALL_PRIVILEGES: Full access for Tableflow automation
# - EXTERNAL_USE_LOCATION: Specific permission for external services
#   to use this location (required for Tableflow integration)
#
# References:
# - External Location Privileges: https://docs.databricks.com/en/data-governance/unity-catalog/manage-privileges/external-location-privileges.html
# - Unity Catalog External Data: https://docs.databricks.com/en/connect/unity-catalog/external-data.html

resource "databricks_grants" "external_location_grants" {
  provider = databricks.workspace

  external_location = databricks_external_location.s3_bucket.name

  grant {
    principal = var.databricks_user_email
    privileges = [
      "ALL_PRIVILEGES",
      "MANAGE",
      "CREATE_EXTERNAL_TABLE",
      "CREATE_EXTERNAL_VOLUME",
      "READ_FILES",
      "WRITE_FILES",
      "CREATE_MANAGED_STORAGE"
    ]
  }

  grant {
    principal = var.databricks_service_principal_client_id
    privileges = [
      "ALL_PRIVILEGES",
      "EXTERNAL_USE_LOCATION"
    ]
  }
}

# ===============================
# Tableflow Catalog
# ===============================
#
# Creates a dedicated Unity Catalog for Confluent Tableflow integration.
# This catalog will contain schemas and tables created by Tableflow.
#
# Key Properties:
# - name: Unique catalog name using workshop prefix and random suffix
#   Dynamic naming prevents conflicts in shared Databricks workspaces
# - comment: Documentation describing the catalog's purpose
# - storage_root: **CRITICAL** S3 path for managed tables in this catalog
#
#   WHY storage_root IS REQUIRED:
#   When creating catalogs via Terraform/API (vs Databricks UI), you MUST
#   specify where managed tables will be stored. Even though your account
#   has "Default Storage" enabled, programmatic creation requires explicit
#   storage location specification.
#
#   - UI creation: Automatically uses account's default storage
#   - API/Terraform: Requires explicit storage_root parameter
#
#   We use a dedicated "/catalog/" subfolder to separate managed table
#   storage from external table storage (which uses the bucket root)
#
# - force_destroy: Allows Terraform to delete catalog even with tables
#   Essential for workshop cleanup - production should consider false
# - depends_on: Ensures storage infrastructure exists before catalog creation
#
# References:
# - Unity Catalog Creation: https://docs.databricks.com/en/sql/language-manual/sql-ref-catalog.html
# - Catalog Storage Requirements: https://docs.databricks.com/en/data-governance/unity-catalog/create-catalogs.html
# - Managed vs External Tables: https://docs.databricks.com/en/lakehouse/data-objects.html#managed-and-external-tables
# - Default Storage: https://docs.databricks.com/en/administration-guide/account-settings/default-storage.html
# - Terraform Provider: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/catalog

resource "databricks_catalog" "tableflow_catalog" {
  provider = databricks.workspace

  name          = "${local.prefix}-${random_id.env_display_id.hex}" # Removed "-catalog-" to shorten name for 64-char limit
  comment       = "Dedicated catalog for Confluent Tableflow integration"
  storage_root  = "s3://${aws_s3_bucket.tableflow_bucket.bucket}/catalog/"
  force_destroy = true # Allows terraform destroy to remove catalog

  depends_on = [
    databricks_storage_credential.external_credential,
    databricks_external_location.s3_bucket
  ]
}

# ===============================
# Tableflow Catalog Grants
# ===============================
#
# Grants permissions on the Tableflow catalog to users and service principals.
# These permissions control access to the catalog and its schemas/tables.
#
# User Privileges:
# - ALL_PRIVILEGES: Full administrative control over the catalog
# - USE_CATALOG: Can access and browse the catalog
#   User needs these for interactive queries and exploration
#
# Service Principal Privileges (for Tableflow automation):
# - USE_CATALOG: Can access the catalog programmatically
# - CREATE_SCHEMA: Can create new schemas (Tableflow creates schema per cluster)
# - USE_SCHEMA: Can access existing schemas within the catalog
# - EXTERNAL_USE_SCHEMA: **CRITICAL** for external services like Tableflow
#   This permission allows external services to use schemas they didn't create
#   Without this, Tableflow gets "User does not have EXTERNAL USE SCHEMA" errors
# - ALL_PRIVILEGES: Provides comprehensive access including CREATE_EXTERNAL_TABLE
#
# Why service principal needs extensive permissions:
# Tableflow automatically creates a schema named after your Kafka cluster ID
# and then creates external Delta tables within that schema. It needs full
# catalog access to manage this entire lifecycle programmatically.
#
# References:
# - Catalog Privileges: https://docs.databricks.com/en/data-governance/unity-catalog/manage-privileges/catalog-privileges.html
# - Schema Privileges: https://docs.databricks.com/en/data-governance/unity-catalog/manage-privileges/schema-privileges.html
# - Tableflow Unity Catalog: https://docs.confluent.io/cloud/current/topics/tableflow/how-to-guides/catalog-integration/integrate-with-unity-catalog.html
# - External Service Access: https://docs.databricks.com/en/dev-tools/service-principals.html

resource "databricks_grants" "tableflow_catalog_grants" {
  provider = databricks.workspace

  catalog = databricks_catalog.tableflow_catalog.name

  grant {
    principal = var.databricks_user_email
    privileges = [
      "ALL_PRIVILEGES",
      "USE_CATALOG"
    ]
  }

  grant {
    principal = var.databricks_service_principal_client_id
    privileges = [
      "USE_CATALOG",
      "CREATE_SCHEMA",
      "USE_SCHEMA",
      "EXTERNAL_USE_SCHEMA", # This is the key permission you need
      "ALL_PRIVILEGES"       # Provides broad access including CREATE_EXTERNAL_TABLE
    ]
  }

  depends_on = [databricks_catalog.tableflow_catalog]
}


# ===============================
# Outputs
# ===============================

output "databricks_storage_credential" {
  description = "Databricks storage credential for Unity Catalog S3 access"
  value = {
    name        = databricks_storage_credential.external_credential.name
    id          = databricks_storage_credential.external_credential.id
    external_id = databricks_storage_credential.external_credential.id
    iam_role    = aws_iam_role.s3_access_role.arn
  }
}

output "databricks_external_location" {
  description = "Databricks external location for Unity Catalog external tables"
  value = {
    name = databricks_external_location.s3_bucket.name
    url  = databricks_external_location.s3_bucket.url
    id   = databricks_external_location.s3_bucket.id
  }
}

output "databricks_tableflow_catalog" {
  description = "Databricks catalog for Confluent Tableflow Unity Catalog integration"
  value = {
    name         = databricks_catalog.tableflow_catalog.name
    id           = databricks_catalog.tableflow_catalog.id
    storage_root = databricks_catalog.tableflow_catalog.storage_root
    comment      = databricks_catalog.tableflow_catalog.comment
  }
}

output "tableflow_unity_catalog_config" {
  description = "Configuration details for Confluent Tableflow Unity Catalog integration"
  value = {
    catalog_name                = databricks_catalog.tableflow_catalog.name
    service_principal_client_id = var.databricks_service_principal_client_id
    databricks_workspace_url    = "Use your Databricks workspace URL from console"
    expected_schema_name        = confluent_kafka_cluster.standard.id
    external_location_url       = databricks_external_location.s3_bucket.url
  }
  sensitive = true
}

output "databricks_permissions_summary" {
  description = "Summary of Databricks permissions configured"
  value = {
    user_email                   = var.databricks_user_email
    service_principal_client_id  = var.databricks_service_principal_client_id
    catalog_name                 = databricks_catalog.tableflow_catalog.name
    storage_credential_name      = databricks_storage_credential.external_credential.name
    external_location_name       = databricks_external_location.s3_bucket.name
    user_has_catalog_permissions = "ALL_PRIVILEGES, USE_CATALOG"
    sp_has_catalog_permissions   = "USE_CATALOG, CREATE_SCHEMA, USE_SCHEMA, EXTERNAL_USE_SCHEMA, ALL_PRIVILEGES"
    sp_has_storage_permissions   = "ALL_PRIVILEGES, CREATE_EXTERNAL_LOCATION, CREATE_EXTERNAL_TABLE, READ_FILES, WRITE_FILES"
    sp_has_location_permissions  = "ALL_PRIVILEGES, EXTERNAL_USE_LOCATION"
  }
  sensitive = true
}
