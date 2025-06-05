# # -------------------------------
# # User
# # -------------------------------

# data "aws_caller_identity" "current" {}

# # -------------------------------
# # Networking
# # -------------------------------

# # -------------------------------
# #  VPC and Subnets
# # -------------------------------

# # VPC
# resource "aws_vpc" "vpc" {
#   cidr_block           = "10.0.0.0/16"
#   enable_dns_hostnames = true
# }

# # Public Subnet
# resource "aws_subnet" "public_subnet" {
#   vpc_id                  = aws_vpc.vpc.id
#   cidr_block              = "10.0.1.0/24"
#   map_public_ip_on_launch = true
# }

# # -------------------------------
# # Internet Gateway
# # -------------------------------

# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.vpc.id
# }


# # -------------------------------
# # Public Route Table
# # -------------------------------

# resource "aws_route_table" "public_route_table" {
#   vpc_id = aws_vpc.vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"                 # This route allows all outbound traffic
#     gateway_id = aws_internet_gateway.igw.id # Route to the Internet Gateway
#   }
# }

# # -------------------------------
# # Associate Public Route Table with Public Subnet
# # -------------------------------

# resource "aws_route_table_association" "public_route_table_association" {
#   subnet_id      = aws_subnet.public_subnet.id
#   route_table_id = aws_route_table.public_route_table.id
# }


# # -------------------------------
# # Security Group for EC2
# # -------------------------------

# resource "aws_security_group" "sg" {
#   vpc_id = aws_vpc.vpc.id

#   ingress {
#     from_port   = 1521
#     to_port     = 1521
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# # -------------------------------
# # Oracle DB AMI and Key
# # -------------------------------


# # Get AMI based on region
# data "aws_ami" "oracle_ami" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["al2023-ami-2023*"]
#   }

#   filter {
#     name   = "architecture"
#     values = ["x86_64"]
#   }
# }


# # -------------------------------
# # S3 Bucket for Tableflow
# # -------------------------------

# resource "aws_s3_bucket" "tableflow_bucket" {
#   bucket = "${local.prefix}-tableflow-${random_id.env_display_id.hex}"

#   tags = {
#     Name = "${local.prefix}-tableflow-${random_id.env_display_id.hex}"
#   }

#   force_destroy = true
# }

# # Add S3 lifecycle policy
# resource "aws_s3_bucket_lifecycle_configuration" "tableflow_bucket_lifecycle" {
#   bucket = aws_s3_bucket.tableflow_bucket.id

#   rule {
#     id     = "cleanup-old-data"
#     status = "Enabled"

#     filter {
#       prefix = "" # Empty prefix means apply to all objects
#     }

#     expiration {
#       days = 30
#     }
#   }
# }

# # Explicitly configure public access settings to allow bucket policies
# resource "aws_s3_bucket_public_access_block" "tableflow_bucket_access" {
#   bucket = aws_s3_bucket.tableflow_bucket.id

#   # Block public ACLs but allow public policies for Unity Catalog
#   block_public_acls       = true
#   block_public_policy     = false # Allow public policies
#   ignore_public_acls      = true
#   restrict_public_buckets = false # Allow public access via bucket policies
# }

# # -------------------------------
# # IAM Role for both S3 Access (Tableflow) and Databricks
# # -------------------------------

# # Local variable for the IAM role name
# locals {
#   iam_role_name = "${local.prefix}-unified-role-${random_id.env_display_id.hex}"
# }


# # --- IAM Role Definition ---
# # https://docs.confluent.io/cloud/current/connectors/provider-integration/index.html
# resource "aws_iam_role" "s3_access_role" {
#   name        = local.iam_role_name
#   description = "IAM role for accessing S3 with trust policies for Confluent Tableflow and Databricks Unity Catalog"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       # Statement 1 (Confluent): Allow Confluent Provider Integration Role to Assume this role
#       {
#         Effect = "Allow"
#         Principal = {
#           AWS = confluent_provider_integration.s3_tableflow_integration.aws[0].iam_role_arn
#         }
#         Action = "sts:AssumeRole"
#         Condition = {
#           StringEquals = {
#             "sts:ExternalId" = confluent_provider_integration.s3_tableflow_integration.aws[0].external_id
#           }
#         }
#       },
#       # Statement 2 (Confluent): Allow Confluent Provider Integration Role to Tag Session
#       {
#         Effect = "Allow"
#         Principal = {
#           AWS = confluent_provider_integration.s3_tableflow_integration.aws[0].iam_role_arn
#         }
#         Action = "sts:TagSession"
#       },
#       # Statement 3 (Databricks): Trust relationship for Databricks Root Account (from working example)
#       {
#         Effect = "Allow",
#         Action = "sts:AssumeRole",
#         Principal = {
#           # Trust the Root user of the Databricks account
#           AWS = "arn:aws:iam::414351767826:root"
#         },
#         Condition = {
#           StringEquals = {
#             "sts:ExternalId" = var.databricks_account_id
#           }
#         }
#       },
#       # Statement 4 (Databricks): Trust relationship for UC Master Role and root
#       # IMPORTANT: The role's OWN ARN is NOT included in the Principal here
#       {
#         Effect = "Allow",
#         Action = "sts:AssumeRole",
#         Principal = {
#           AWS = [
#             # Trust the Databricks Unity Catalog Master Role ARN
#             "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
#             "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
#           ]
#         },
#         Condition = {
#           StringEquals = {
#             "sts:ExternalId" = var.databricks_account_id
#           },
#           # Keep the ArnEquals condition from the trust policy
#           ArnEquals = {
#             "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.iam_role_name}"
#           }
#         }
#       }
#     ]
#   })
# }

# # --- NEW RESOURCE: Identity-based policy to grant the role permission to assume itself ---
# # This policy is attached *to* the role (via the 'role' attribute)
# # It defines what actions the role *can perform*, including assuming itself.
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

# # S3 bucket access policy for the unified role
# resource "aws_iam_role_policy" "s3_access_policy" {
#   name = "${local.iam_role_name}-s3-policy"
#   role = aws_iam_role.s3_access_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "s3:*" # Full S3 access for the demo
#         ],
#         Resource = [
#           "arn:aws:s3:::${aws_s3_bucket.tableflow_bucket.bucket}",
#           "arn:aws:s3:::${aws_s3_bucket.tableflow_bucket.bucket}/*"
#         ]
#       }
#     ]
#   })
# }

# # Attaching the AWS managed S3 full access policy for the demo
# resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
#   role       = aws_iam_role.s3_access_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
# }

# # -------------------------------
# # Remove the separate Databricks role as it's now consolidated
# # -------------------------------

# # resource "aws_iam_role" "databricks_role" {
# #   name = "${var.databricks_workspace_name}-dbx-role-${random_id.env_display_id.hex}"
# #
# #   assume_role_policy = jsonencode({
# #     Version = "2012-10-17",
# #     Statement = [
# #       {
# #         Effect = "Allow",
# #         Action = "sts:AssumeRole",
# #         Principal = {
# #           AWS = "arn:aws:iam::414351767826:root"
# #         },
# #         Condition = {
# #           StringEquals = {
# #             "sts:ExternalId" = var.databricks_account_id
# #           }
# #         }
# #       },
# #       {
# #         Effect = "Allow",
# #         Action = "sts:AssumeRole",
# #         Principal = {
# #           # AWS = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
# #           AWS = [
# #             "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
# #             "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
# #           ]
# #         },
# #         Condition = {
# #           StringEquals = {
# #             "sts:ExternalId" = var.databricks_account_id
# #           },
# #           ArnEquals = {
# #             "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.databricks_workspace_name}-dbx-role-${random_id.env_display_id.hex}"
# #           }
# #         }
# #       }
# #     ]
# #   })
# # }
# #
# # # Add a proper Unity Catalog policy with precise permissions
# # resource "aws_iam_role_policy" "databricks_unity_catalog_policy" {
# #   name = "${var.databricks_workspace_name}-unity-catalog-policy"
# #   role = aws_iam_role.databricks_role.id
# #
# #   policy = jsonencode({
# #     Version = "2012-10-17",
# #     Statement = [
# #       {
# #         Effect = "Allow",
# #         Action = [
# #           "s3:*" # Full S3 access for the demo
# #         ],
# #         Resource = "*"
# #       }
# #     ]
# #   })
# # }

# # Add a bucket policy to allow access from both services
# resource "aws_s3_bucket_policy" "unity_catalog_access" {
#   bucket = aws_s3_bucket.tableflow_bucket.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect    = "Allow",
#         Principal = "*", # Allow all principals for the demo
#         Action = [
#           "s3:GetObject",
#           "s3:GetObjectVersion",
#           "s3:PutObject",
#           "s3:DeleteObject",
#           "s3:ListBucket",
#           "s3:GetBucketLocation",
#           "s3:ListBucketMultipartUploads",
#           "s3:ListMultipartUploadParts",
#           "s3:AbortMultipartUpload"
#         ],
#         Resource = [
#           "arn:aws:s3:::${aws_s3_bucket.tableflow_bucket.bucket}",
#           "arn:aws:s3:::${aws_s3_bucket.tableflow_bucket.bucket}/*"
#         ]
#       },
#       {
#         # Additional statement specifically for the unified role
#         Effect = "Allow",
#         Principal = {
#           AWS = aws_iam_role.s3_access_role.arn
#         },
#         Action = "s3:*",
#         Resource = [
#           "arn:aws:s3:::${aws_s3_bucket.tableflow_bucket.bucket}",
#           "arn:aws:s3:::${aws_s3_bucket.tableflow_bucket.bucket}/*"
#         ]
#       }
#     ]
#   })

#   depends_on = [aws_s3_bucket_public_access_block.tableflow_bucket_access]
# }

# # Ensure the bucket has proper ACL settings
# # resource "aws_s3_bucket_public_access_block" "tableflow_bucket_access" {
# #   bucket = aws_s3_bucket.tableflow_bucket.id
# #   block_public_acls       = true
# #   block_public_policy     = true
# #   ignore_public_acls      = true
# #   restrict_public_buckets = true
# # }


# # -------------------------------
# # SSH Key Pair
# # -------------------------------

# resource "aws_key_pair" "tf_key" {
#   key_name   = "${local.prefix}-key-${random_id.env_display_id.hex}"
#   public_key = tls_private_key.rsa-4096-example.public_key_openssh
# }

# # RSA key of size 4096 bits
# resource "tls_private_key" "rsa-4096-example" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# # TODO - uncomment this once everything is working
# # Store SSH private key locally (Windows-friendly)
# resource "local_file" "tf_key" {
#   content  = tls_private_key.rsa-4096-example.private_key_pem
#   filename = join("/", [path.module, "sshkey-${aws_key_pair.tf_key.key_name}.pem"])
# }


# # -------------------------------
# # Oracle DB Instance
# # -------------------------------

# # EC2 instance for Oracle

# resource "aws_instance" "oracle_instance" {
#   ami             = data.aws_ami.oracle_ami.id
#   instance_type   = "t3.large"
#   key_name        = aws_key_pair.tf_key.key_name
#   security_groups = [aws_security_group.sg.id]
#   #security_groups = [aws_security_group.oracle_sg.id]
#   subnet_id = aws_subnet.public_subnet.id
#   root_block_device {
#     volume_size = 30 # Oracle XE needs at least 12GB, adding extra space
#     volume_type = "gp3"
#   }
#   user_data = <<-EOF
#     #!/bin/bash
#     # Update system
#     dnf update -y

#     # Install Docker
#     dnf install -y docker
#     systemctl enable docker
#     systemctl start docker

#     # Install Docker Compose
#     curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
#     chmod +x /usr/local/bin/docker-compose

#     # Create directory for Oracle data
#     mkdir -p /opt/oracle/oradata
#     chmod -R 777 /opt/oracle/oradata

#     # Create docker-compose.yml file
#     cat > /opt/oracle/docker-compose.yml <<'DOCKER_COMPOSE'
#     version: '3'
#     services:
#       oracle-xe:
#         image: container-registry.oracle.com/database/express:21.3.0-xe
#         platform: linux/amd64
#         container_name: oracle-xe
#         ports:
#           - "1521:1521"
#           - "5500:5500"
#         environment:
#           - ORACLE_PWD=${var.oracle_db_password}
#           - ORACLE_CHARACTERSET=AL32UTF8
#         volumes:
#           - /opt/oracle/oradata:/opt/oracle/oradata
#         restart: always
#     DOCKER_COMPOSE

#     # Pull Oracle XE image and start container
#     cd /opt/oracle
#     docker-compose up -d

#     # Set up a welcome message
#     echo "Oracle XE 21c setup complete. Connect using:"
#     echo "Hostname: $(curl -s http://169.254.169.254/latest/meta-data/public-hostname)"
#     echo "Port: 1521"
#     echo "SID: XE"
#     echo "PDB: XEPDB1"
#     echo "Username: ${var.oracle_db_username}"
#     echo "Password: ${var.oracle_db_password}"
#     echo "EM Express URL: https://$(curl -s http://169.254.169.254/latest/meta-data/public-hostname):5500/em"

#     echo "Waiting for oracle-xe container to become healthy"
#     until [ "$(sudo docker inspect -f '{{.State.Health.Status}}' oracle-xe 2>/dev/null)" == "healthy" ]; do
#       echo -n "."
#       sleep 10
#     done

#     echo "Writing XStream setup script"
#     cat > /opt/oracle/setup-xstream.sh <<'SCRIPT_EOF'
#     #!/bin/bash
#     set -e
#     log() { echo "[XSTREAM] $1"; }

#     log "Enable Oracle XStream"
#     sudo docker exec -i oracle-xe bash -c "ORACLE_SID=XE; export ORACLE_SID; sqlplus /nolog" <<'SQL_EOF'
#     CONNECT sys/Welcome1 AS SYSDBA
#     ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
#     SHOW PARAMETER GOLDEN;
#     EXIT;
#     SQL_EOF

#     log "Configure ARCHIVELOG mode"
#     sudo docker exec -i oracle-xe bash -c "ORACLE_SID=XE; export ORACLE_SID; sqlplus /nolog" <<'SQL_EOF'
#     CONNECT sys/Welcome1 AS SYSDBA
#     SHUTDOWN IMMEDIATE;
#     STARTUP MOUNT;
#     ALTER DATABASE ARCHIVELOG;
#     ALTER DATABASE OPEN;
#     EXIT;
#     SQL_EOF

#     log "Configure supplemental logging"
#     sudo docker exec -i oracle-xe bash -c "ORACLE_SID=XE; export ORACLE_SID; sqlplus /nolog" <<'SQL_EOF'
#     CONNECT sys/Welcome1 AS SYSDBA
#     ALTER SESSION SET CONTAINER = CDB\$ROOT;
#     ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
#     SELECT SUPPLEMENTAL_LOG_DATA_MIN, SUPPLEMENTAL_LOG_DATA_ALL FROM V\\$DATABASE;
#     EXIT;
#     SQL_EOF

#     log "Create XStream tablespaces in CDB"
#     sudo docker exec -i oracle-xe bash -c "ORACLE_SID=XE; export ORACLE_SID; sqlplus /nolog" <<'SQL_EOF'
#     CONNECT sys/Welcome1 AS SYSDBA
#     CREATE TABLESPACE xstream_adm_tbs DATAFILE '/opt/oracle/oradata/XE/xstream_adm_tbs.dbf'
#     SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;

#     CREATE TABLESPACE xstream_tbs DATAFILE '/opt/oracle/oradata/XE/xstream_tbs.dbf'
#     SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
#     EXIT;
#     SQL_EOF

#     log "Create PDB objects and sample user"
#     sudo docker exec -i oracle-xe bash -c "ORACLE_SID=XE; export ORACLE_SID; sqlplus /nolog" <<'SQL_EOF'
#     CONNECT sys/Welcome1 AS SYSDBA
#     ALTER SESSION SET CONTAINER=XEPDB1;

#     CREATE USER sample IDENTIFIED BY password;
#     GRANT CONNECT, RESOURCE TO sample;
#     ALTER USER sample QUOTA UNLIMITED ON USERS;

#     CREATE TABLESPACE xstream_adm_tbs DATAFILE '/opt/oracle/oradata/XE/XEPDB1/xstream_adm_tbs.dbf'
#     SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;

#     CREATE TABLESPACE xstream_tbs DATAFILE '/opt/oracle/oradata/XE/XEPDB1/xstream_tbs.dbf'
#     SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
#     EXIT;
#     SQL_EOF

#     log "Create XStream admin user"
#     sudo docker exec -i oracle-xe bash -c "ORACLE_SID=XE; export ORACLE_SID; sqlplus /nolog" <<'SQL_EOF'
#     CONNECT sys/Welcome1 AS SYSDBA
#     CREATE USER c##cfltadmin IDENTIFIED BY password
#     DEFAULT TABLESPACE xstream_adm_tbs
#     QUOTA UNLIMITED ON xstream_adm_tbs
#     CONTAINER=ALL;

#     GRANT CREATE SESSION TO c##cfltadmin CONTAINER=ALL;
#     GRANT SET CONTAINER TO c##cfltadmin CONTAINER=ALL;

#     BEGIN
#       DBMS_XSTREAM_AUTH.GRANT_ADMIN_PRIVILEGE(
#         grantee                 => 'c##cfltadmin',
#         privilege_type          => 'CAPTURE',
#         grant_select_privileges => TRUE,
#         container               => 'ALL'
#       );
#     END;
#     /
#     EXIT;
#     SQL_EOF

#     log "Create XStream connect user"
#     sudo docker exec -i oracle-xe bash -c "ORACLE_SID=XE; export ORACLE_SID; sqlplus /nolog" <<'SQL_EOF'
#     CONNECT sys/Welcome1 AS SYSDBA
#     CREATE USER c##cfltuser IDENTIFIED BY password
#     DEFAULT TABLESPACE xstream_tbs
#     QUOTA UNLIMITED ON xstream_tbs
#     CONTAINER=ALL;

#     GRANT CREATE SESSION TO c##cfltuser CONTAINER=ALL;
#     GRANT SET CONTAINER TO c##cfltuser CONTAINER=ALL;
#     GRANT SELECT_CATALOG_ROLE TO c##cfltuser CONTAINER=ALL;
#     GRANT CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER TO c##cfltuser CONTAINER=ALL;
#     GRANT FLASHBACK ANY TABLE, SELECT ANY TABLE, LOCK ANY TABLE TO c##cfltuser CONTAINER=ALL;
#     EXIT;
#     SQL_EOF

#     log "Create XStream Outbound Server"
#     sudo docker exec -i oracle-xe sqlplus c\#\#cfltadmin/password@//localhost:1521/XE <<'SQL_EOF'
#     DECLARE
#       tables  DBMS_UTILITY.UNCL_ARRAY;
#       schemas DBMS_UTILITY.UNCL_ARRAY;
#     BEGIN
#       tables(1) := NULL;
#       schemas(1) := 'sample';
#       DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
#         server_name => 'xout',
#         source_container_name => 'XEPDB1',
#         table_names => tables,
#         schema_names => schemas);
#     END;
#     /
#     EXIT;
#     SQL_EOF

#     sudo docker exec -i oracle-xe bash -c "ORACLE_SID=XE; export ORACLE_SID; sqlplus /nolog" <<'SQL_EOF'
#     CONNECT sys/Welcome1 AS SYSDBA
#     BEGIN
#       DBMS_XSTREAM_ADM.ALTER_OUTBOUND(
#         server_name  => 'xout',
#         connect_user => 'c##cfltuser');
#     END;
#     /
#     EXIT;
#     SQL_EOF

#     log "XStream configuration complete"

#     SCRIPT_EOF

#     chmod +x /opt/oracle/setup-xstream.sh
#     bash /opt/oracle/setup-xstream.sh >> /var/log/xstream-setup.log 2>&1

#     echo "Oracle XE with XStream configured." | tee -a /var/log/user-data.log

#   EOF
#   tags = {
#     Name = "${local.prefix}-oracle-xe"
#   }
# }

# resource "aws_security_group" "oracle_sg" {
#   vpc_id      = aws_vpc.vpc.id
#   name        = "${local.prefix}-oracle-security-group"
#   description = "Security group for Oracle database instance"

#   ingress {
#     from_port   = 1521
#     to_port     = 1521
#     protocol    = "tcp"
#     cidr_blocks = var.allowed_cidr_blocks
#     description = "Oracle DB port"
#   }

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = var.allowed_cidr_blocks
#     description = "SSH access"
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "Allow all outbound traffic"
#   }

#   tags = {
#     Name = "${local.prefix}-oracle-security-group"
#   }
# }



# # TODO - see if this is needed
# # Server-side encryption disabled for simplicity
# # resource "aws_kms_key" "tableflow_bucket_key" {
# #   description             = "KMS key for Tableflow S3 bucket encryption"
# #   deletion_window_in_days = 10
# #   enable_key_rotation     = true
# #
# #   tags = {
# #     Name = "${local.prefix}-tableflow-kms-${random_id.env_display_id.hex}"
# #   }
# # }
# #
# # resource "aws_kms_alias" "tableflow_bucket_key_alias" {
# #   name          = "alias/${local.prefix}-tableflow-key-${random_id.env_display_id.hex}"
# #   target_key_id = aws_kms_key.tableflow_bucket_key.key_id
# # }
# #
# # resource "aws_s3_bucket_server_side_encryption_configuration" "tableflow_bucket_encryption" {
# #   bucket = aws_s3_bucket.tableflow_bucket.bucket
# #
# #   rule {
# #     apply_server_side_encryption_by_default {
# #       kms_master_key_id = aws_kms_key.tableflow_bucket_key.arn
# #       sse_algorithm     = "aws:kms"
# #     }
# #   }
# # }
