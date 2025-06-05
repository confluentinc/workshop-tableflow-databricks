# -------------------------------
# IAM Role for both S3 Access (Tableflow) and Databricks
# -------------------------------

# Local variable for the IAM role name
locals {
  iam_role_name = "${local.prefix}-unified-role-${random_id.env_display_id.hex}"
}

# --- IAM Role Definition ---
# https://docs.confluent.io/cloud/current/connectors/provider-integration/index.html
resource "aws_iam_role" "s3_access_role" {
  name        = local.iam_role_name
  description = "IAM role for accessing S3 with trust policies for Confluent Tableflow and Databricks Unity Catalog"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Statement 1 (Confluent): Allow Confluent Provider Integration Role to Assume this role
      {
        Effect = "Allow"
        Principal = {
          AWS = confluent_provider_integration.s3_tableflow_integration.aws[0].iam_role_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = confluent_provider_integration.s3_tableflow_integration.aws[0].external_id
          }
        }
      },
      # Statement 2 (Confluent): Allow Confluent Provider Integration Role to Tag Session
      {
        Effect = "Allow"
        Principal = {
          AWS = confluent_provider_integration.s3_tableflow_integration.aws[0].iam_role_arn
        }
        Action = "sts:TagSession"
      },
      # Statement 3 (Databricks): Trust relationship for Databricks Root Account (from working example)
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      }
      # {
      #   Effect = "Allow",
      #   Action = "sts:AssumeRole",
      #   Principal = {
      #     # Trust the Root user of the Databricks account
      #     AWS = "arn:aws:iam::414351767826:root"
      #   },
      #   Condition = {
      #     StringEquals = {
      #       "sts:ExternalId" = var.databricks_account_id
      #     }
      #   }
      # },
      # Statement 4 (Databricks): Trust relationship for UC Master Role and root
      # IMPORTANT: The role's OWN ARN is NOT included in the Principal here
      # 1b08899a-1eae-4260-9eeb-0e59201be354
      # {
      #   Effect = "Allow",
      #   Action = "sts:AssumeRole",
      #   Principal = {
      #     AWS = [
      #       # Trust the Databricks Unity Catalog Master Role ARN
      #       "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
      #       "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.iam_role_name}"
      #     ]
      #   },
      #   Condition = {
      #     StringEquals = {
      #       # FROM JEREMY's EXAMPLE - NOT WORKING
      #       # "sts:ExternalId" = var.databricks_account_id

      #       # FROM DOCS - https://docs.databricks.com/aws/en/connect/unity-catalog/cloud-storage/storage-credentials#step-3-update-the-iam-role-trust-relationship-policy
      #       "sts:ExternalId" = databricks_external_location.s3_bucket.id
      #     },
      #     # Keep the ArnEquals condition from the trust policy
      #     # ArnEquals = {
      #     #   "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.iam_role_name}"
      #     # }
      #   }
      # }
    ]
  })

  # LESSON LEARNED: Use lifecycle to ignore changes to trust policy
  # This prevents Terraform from reverting our programmatic updates
  lifecycle {
    ignore_changes = [assume_role_policy]
  }

  tags = merge(local.common_tags, {
    Name = local.iam_role_name
  })
}


# resource "aws_iam_role_policy" "s3_access_role_self_assume_policy" {
#   name = "${local.iam_role_name}-self-assume" # Policy name
#   role = aws_iam_role.s3_access_role.id       # Attach this policy to the S3 Access Role

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = "sts:AssumeRole",
#         # The Resource here is the ARN of the role itself.
#         # This grants the role the *permission* to assume its own identity.
#         Resource = aws_iam_role.s3_access_role.arn
#       }
#     ]
#   })
#   depends_on = [aws_iam_role.s3_access_role]
# }

# ===============================
# IAM Role Policy for S3 Access
# ===============================

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "${local.prefix}-s3-access-policy-${local.resource_suffix}"
  role = aws_iam_role.s3_access_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:*" # Full S3 access for the demo
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.tableflow_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.tableflow_bucket.bucket}/*",
          # TODO: consider the ones below
          # aws_s3_bucket.tableflow_bucket.arn,
          # "${aws_s3_bucket.tableflow_bucket.arn}/*"
        ]
      }
    ]
  })
}

# ===============================
# S3 Bucket Policy for Additional Security
# TODO IS THIS NECESSARY?
# ===============================

resource "aws_s3_bucket_policy" "tableflow_bucket_policy" {
  bucket = aws_s3_bucket.tableflow_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.s3_access_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.tableflow_bucket.arn,
          "${aws_s3_bucket.tableflow_bucket.arn}/*"
        ]
      }
    ]
  })
}

# ===============================
# Update IAM Role Trust Policy with Real External ID
# ===============================

resource "null_resource" "update_iam_role_trust_policy" {
  # LESSON LEARNED: Update trust policy with actual external ID from storage credential
  # This is the key to making Unity Catalog work properly
  # CRITICAL: Unity Catalog requires BOTH Databricks access AND self-assumption capability

  provisioner "local-exec" {
    command = <<-EOT
      aws iam update-assume-role-policy \
        --role-name ${aws_iam_role.s3_access_role.name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": {
                "AWS": "arn:aws:iam::414351767826:root"
              },
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${databricks_storage_credential.external_credential.aws_iam_role[0].external_id}"
                }
              }
            },
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": {
                "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
              }
            }
          ]
        }'
    EOT
  }

  depends_on = [
    databricks_storage_credential.external_credential
  ]

  triggers = {
    storage_credential_id = databricks_storage_credential.external_credential.id
    role_arn              = aws_iam_role.s3_access_role.arn
  }
}

# ===============================
# Wait for Trust Policy Propagation
# ===============================

resource "null_resource" "wait_for_trust_policy_propagation" {
  # LESSON LEARNED: AWS IAM changes need time to propagate
  # Extended delay to ensure role is fully available before self-reference
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [
    null_resource.update_iam_role_trust_policy
  ]
}

# ===============================
# Update IAM Role Trust Policy with Specific Role ARN for Self-Assumption
# ===============================

resource "null_resource" "update_iam_role_trust_policy_final" {
  # LESSON LEARNED: Unity Catalog requires specific role ARN for self-assumption
  # This second update replaces account root with specific role ARN
  # CRITICAL: Must wait for role to be fully propagated before self-reference

  provisioner "local-exec" {
    command = <<-EOT
      aws iam update-assume-role-policy \
        --role-name ${aws_iam_role.s3_access_role.name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": {
                "AWS": "arn:aws:iam::414351767826:root"
              },
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${databricks_storage_credential.external_credential.aws_iam_role[0].external_id}"
                }
              }
            },
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": {
                "AWS": "${aws_iam_role.s3_access_role.arn}"
              }
            }
          ]
        }'
    EOT
  }

  depends_on = [
    null_resource.wait_for_trust_policy_propagation
  ]

  triggers = {
    storage_credential_id = databricks_storage_credential.external_credential.id
    role_arn              = aws_iam_role.s3_access_role.arn
    step                  = "final_specific_role_arn"
  }
}

# ===============================
# Wait for Final Trust Policy Propagation
# ===============================

resource "null_resource" "wait_for_final_trust_policy_propagation" {
  # LESSON LEARNED: AWS IAM changes need time to propagate
  provisioner "local-exec" {
    command = "sleep 30"
  }

  depends_on = [
    null_resource.update_iam_role_trust_policy_final
  ]
}

# Attaching the AWS managed S3 full access policy for the demo
# resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
#   role       = aws_iam_role.s3_access_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
# }

output "aws_iam" {
  value = {
    role_arn  = aws_iam_role.s3_access_role.arn
    role_name = aws_iam_role.s3_access_role.name
    role_id   = aws_iam_role.s3_access_role.id
    # role_policy_arn  = aws_iam_role_policy.s3_access_policy.arn
    role_policy_name = aws_iam_role_policy.s3_access_policy.name
    role_policy_id   = aws_iam_role_policy.s3_access_policy.id
    # role_policy_attachment_arn = aws_iam_role_policy_attachment.s3_policy_attachment.arn
    # role_policy_attachment_id   = aws_iam_role_policy_attachment.s3_policy_attachment.id
    # role_policy_attachment_role = aws_iam_role_policy_attachment.s3_policy_attachment.role
  }
}
