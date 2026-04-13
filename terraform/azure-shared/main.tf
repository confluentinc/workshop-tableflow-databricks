# ===============================
# Shared Workshop Infrastructure (Azure)
# ===============================
# Runs ONCE before `wsa build`. Provisions resources shared across all
# 95 workshop accounts: Resource Group, VNet, Storage Account, SSH key,
# and an Azure VM running PostgreSQL + the data generator via Docker.
#
# Per-account Terraform (terraform/azure/) receives these outputs as
# input variables (shared_resource_group_name, shared_storage_account_name, etc.).
#
# Usage (via wsa):
#   wsa build -w wsa-spec-azure.yaml ...
#
# Usage (manual):
#   cd terraform/azure-shared
#   terraform init && terraform apply

resource "random_id" "suffix" {
  byte_length = 4
}

resource "random_password" "postgres_db" {
  length  = 24
  special = false
}

resource "random_password" "postgres_debezium" {
  length  = 24
  special = false
}

locals {
  resource_suffix = random_id.suffix.hex

  effective_postgres_db_password       = coalesce(var.postgres_db_password, random_password.postgres_db.result)
  effective_postgres_debezium_password = coalesce(var.postgres_debezium_password, random_password.postgres_debezium.result)

  # Auto-size VM based on account_count when vm_size is empty.
  # v7 AMD SKUs are used — available in eastus2 zone 1.
  # TODO: After upgrading to a paid Azure subscription and increasing the
  # eastus2 vCPU quota to 8+, restore D8 as the top tier to match AWS m5.2xlarge:
  #   var.account_count > 60 ? "Standard_D8as_v7"   # 8 vCPU / 32 GB
  auto_vm_size = (
    var.account_count <= 30 ? "Standard_D2as_v7" : # 2 vCPU /  8 GB
                              "Standard_D4as_v7"   # 4 vCPU / 16 GB (capped by free-tier 4 vCPU quota)
  )
  effective_vm_size = var.vm_size != "" ? var.vm_size : local.auto_vm_size

  common_tags = merge(
    {
      Project     = "Workshop Shared Infrastructure"
      Environment = "workshop"
      Created_by  = "Terraform"
      owner_email = var.owner_email
    },
    var.run_id != "" ? { wsa_run_id = var.run_id } : {}
  )
}

# ===============================
# Resource Group
# ===============================

resource "azurerm_resource_group" "shared" {
  name     = "${var.resource_group_name}-${local.resource_suffix}"
  location = var.cloud_region
  tags     = local.common_tags
}

# ===============================
# Networking (1 VNet for all accounts)
# ===============================

resource "azurerm_virtual_network" "shared" {
  name                = "${var.prefix}-vnet-${local.resource_suffix}"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "shared" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [var.subnet_address_prefix]
}

resource "azurerm_network_security_group" "shared" {
  name                = "${var.prefix}-nsg-${local.resource_suffix}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_cidr_blocks
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowPostgreSQL"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefixes    = var.allowed_cidr_blocks
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "shared" {
  subnet_id                 = azurerm_subnet.shared.id
  network_security_group_id = azurerm_network_security_group.shared.id
}

# ===============================
# SSH Key
# ===============================

resource "tls_private_key" "shared" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.shared.private_key_pem
  filename        = "${path.module}/sshkey-${local.resource_suffix}.pem"
  file_permission = "0600"
}

# ===============================
# Storage Account (ADLS Gen2 — shared for Tableflow + Databricks)
# ===============================

resource "azurerm_storage_account" "shared" {
  name                     = "${var.storage_account_prefix}${local.resource_suffix}"
  resource_group_name      = azurerm_resource_group.shared.name
  location                 = azurerm_resource_group.shared.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true # ADLS Gen2 (hierarchical namespace)
  tags                     = local.common_tags
}

resource "azurerm_storage_container" "shared" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.shared.id
  container_access_type = "private"
}

# ===============================
# Public IP for VM
# ===============================

resource "azurerm_public_ip" "postgres" {
  name                = "${var.prefix}-postgres-pip-${local.resource_suffix}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# ===============================
# Network Interface
# ===============================

resource "azurerm_network_interface" "postgres" {
  name                = "${var.prefix}-postgres-nic-${local.resource_suffix}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.shared.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.postgres.id
  }
}

# ===============================
# PostgreSQL VM (Ubuntu + Docker)
# ===============================

resource "azurerm_linux_virtual_machine" "postgres" {
  name                = "${var.prefix}-postgres-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  size                = local.effective_vm_size
  zone                = var.vm_zone
  admin_username      = var.vm_admin_username

  network_interface_ids = [azurerm_network_interface.postgres.id]

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = tls_private_key.shared.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.vm_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.sh.tpl", {
    db_password           = local.effective_postgres_db_password
    db_name               = var.postgres_db_name
    db_username           = var.postgres_db_username
    debezium_password     = local.effective_postgres_debezium_password
    max_replication_slots = var.postgres_max_replication_slots
    max_wal_senders       = var.postgres_max_wal_senders
    max_connections       = var.postgres_max_connections
  }))

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-postgres-workshop"
  })
}

# ===============================
# Shared Databricks External Location
# ===============================
# All workshop accounts share one Databricks workspace and ADLS Gen2
# storage account. Confluent Tableflow writes Delta files to internal
# path structures that can't be predicted at provisioning time.
# A container-root external location created here (once, before
# per-account runs) covers all paths — including Tableflow data and
# per-account catalog storage roots.
#
# Per-account Terraform skips external location creation in shared
# mode and relies on this shared location instead.

# --- Access Connector (managed identity → ADLS Gen2) ---

resource "azurerm_databricks_access_connector" "shared" {
  name                = "${var.prefix}-access-connector-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = azurerm_storage_account.shared.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.shared.identity[0].principal_id
}

resource "azurerm_role_assignment" "queue_data_contributor" {
  scope                = azurerm_storage_account.shared.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_databricks_access_connector.shared.identity[0].principal_id
}

resource "time_sleep" "wait_for_identity_propagation" {
  create_duration = "120s"

  triggers = {
    access_connector_id = azurerm_databricks_access_connector.shared.id
    blob_role           = azurerm_role_assignment.blob_data_contributor.id
    queue_role          = azurerm_role_assignment.queue_data_contributor.id
  }

  depends_on = [
    azurerm_role_assignment.blob_data_contributor,
    azurerm_role_assignment.queue_data_contributor
  ]
}

# --- Storage Credential ---

resource "databricks_storage_credential" "shared" {
  provider = databricks.workspace

  name    = "${var.prefix}-storage-credential-${local.resource_suffix}"
  comment = "Shared storage credential for Unity Catalog ADLS Gen2 access"

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.shared.id
  }

  depends_on = [time_sleep.wait_for_identity_propagation]
}

# --- External Location ---

resource "databricks_external_location" "shared" {
  provider = databricks.workspace

  name            = "${var.prefix}-external-location-${local.resource_suffix}"
  url             = "abfss://${azurerm_storage_container.shared.name}@${azurerm_storage_account.shared.name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.shared.name
  comment         = "Shared external location for Tableflow and Unity Catalog data"
  force_destroy   = true
  skip_validation = true

  depends_on = [databricks_storage_credential.shared]
}

# --- Grants on Shared External Location ---

resource "databricks_grants" "shared_external_location" {
  provider = databricks.workspace

  external_location = databricks_external_location.shared.name

  grant {
    principal = var.databricks_service_principal_client_id
    privileges = [
      "ALL_PRIVILEGES",
      "MANAGE",
      "CREATE_EXTERNAL_TABLE",
      "CREATE_EXTERNAL_VOLUME",
      "READ_FILES",
      "WRITE_FILES",
      "CREATE_MANAGED_STORAGE",
      "EXTERNAL_USE_LOCATION"
    ]
  }

  depends_on = [databricks_external_location.shared]
}
