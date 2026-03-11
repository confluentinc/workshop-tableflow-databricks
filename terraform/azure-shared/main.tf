# ===============================
# Shared Workshop Infrastructure (Azure)
# ===============================
# Runs ONCE before `wsa build`. Provisions resources shared across all
# 95 workshop accounts: Resource Group, VNet, Storage Account, SSH key,
# and an Azure VM running PostgreSQL + ShadowTraffic via Docker.
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
  size                = var.vm_size
  admin_username      = var.vm_admin_username

  network_interface_ids = [azurerm_network_interface.postgres.id]

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
