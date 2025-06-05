data "databricks_current_user" "current_principal_from_workspace_provider" {
  # Explicitly link this data source to the provider instance with alias "workspace"
  provider = databricks.workspace
}


resource "databricks_storage_credential" "external_credential" {
  provider = databricks.workspace
  name     = "${local.prefix}-storage-credential-${local.resource_suffix}"

  aws_iam_role {
    role_arn = aws_iam_role.s3_access_role.arn
  }
  comment = "Storage credential for Unity Catalog S3 access - ${local.resource_suffix}"

  depends_on = [
    aws_iam_role.s3_access_role,
    aws_iam_role_policy.s3_access_policy
  ]
}

resource "databricks_external_location" "s3_bucket" {
  provider = databricks.workspace

  name            = "${local.prefix}-external-location-${local.resource_suffix}"
  url             = "s3://${aws_s3_bucket.tableflow_bucket.bucket}/"
  credential_name = databricks_storage_credential.external_credential.name
  comment         = "External location for Unity Catalog S3 access - ${local.resource_suffix}"

  depends_on = [
    null_resource.wait_for_final_trust_policy_propagation,
    aws_s3_bucket_policy.tableflow_bucket_policy
  ]
}

# resource "databricks_external_location" "s3_bucket" {
#   provider        = databricks.workspace
#   name            = "${local.prefix}-external-location"
#   url             = "s3://${aws_s3_bucket.tableflow_bucket.bucket}"
#   credential_name = databricks_storage_credential.external_credential[0].id
#   #   metastore_id    = var.databricks_metastore_id
#   comment = "Managed by TF"

#   depends_on = [databricks_grants.metastore_grants]
# }

# ===============================
# Grant User Permissions to External Location
# ===============================

resource "databricks_grants" "external_location_grants" {
  provider = databricks.workspace

  external_location = databricks_external_location.s3_bucket.id

  grant {
    principal = var.databricks_user_email
    # privileges = ["READ_FILES"]
    privileges = ["ALL_PRIVILEGES"]
  }

  depends_on = [
    databricks_external_location.s3_bucket
  ]
}


output "databricks_storage_credential" {
  description = "Databricks storage credential details"
  value = {
    name        = databricks_storage_credential.external_credential.name
    id          = databricks_storage_credential.external_credential.id
    external_id = databricks_storage_credential.external_credential.id
  }
}

output "databricks_external_location" {
  description = "Databricks external location details"
  value = {
    name = databricks_external_location.s3_bucket.name
    url  = databricks_external_location.s3_bucket.url
  }
}
