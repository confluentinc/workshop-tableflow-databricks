# ===============================
# Shared Infrastructure Monitoring (Azure Monitor)
# ===============================
# Azure Monitor-based observability for the shared VM running PostgreSQL
# and ShadowTraffic. Always enabled — shared infra should always be
# monitored, especially during production workshops.
#
# Components:
#   - Azure Monitor Agent via VM extension
#   - Action group for email alerts
#   - Metric alerts (CPU, disk, availability)
#   - Custom metrics cron script (PostgreSQL stats, Docker health)

locals {
  effective_alert_email = coalesce(var.alert_email, var.owner_email)
  dashboard_name        = "wsa-shared-infra-${local.resource_suffix}"
}

# ===============================
# Action Group (Email Alerts)
# ===============================

resource "azurerm_monitor_action_group" "shared" {
  name                = "${var.prefix}-alerts-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  short_name          = "wsaalerts"

  email_receiver {
    name          = "workshop-admin"
    email_address = local.effective_alert_email
  }

  tags = local.common_tags
}

# ===============================
# Metric Alerts
# ===============================

resource "azurerm_monitor_metric_alert" "cpu" {
  name                = "${var.prefix}-cpu-high-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  scopes              = [azurerm_linux_virtual_machine.postgres.id]
  description         = "CPU utilization exceeded ${var.alarm_cpu_threshold}% on shared PostgreSQL VM"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.alarm_cpu_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.shared.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "vm_availability" {
  name                = "${var.prefix}-vm-availability-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  scopes              = [azurerm_linux_virtual_machine.postgres.id]
  description         = "VM availability dropped below 1 (VM is down)"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.shared.id
  }

  tags = local.common_tags
}

# ===============================
# Custom Metrics Script (deployed via SSH)
# ===============================
# Installs a cron job on the VM that publishes PostgreSQL-specific
# metrics to Azure Monitor via the REST API.

resource "null_resource" "monitoring_setup" {
  triggers = {
    vm_id = azurerm_linux_virtual_machine.postgres.id
  }

  depends_on = [
    azurerm_linux_virtual_machine.postgres,
  ]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.postgres.ip_address
    user        = var.vm_admin_username
    private_key = tls_private_key.shared.private_key_pem
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/templates/monitor.sh"
    destination = "/tmp/monitor.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "sudo apt-get install -y curl jq 2>/dev/null || true",
      "sudo cp /tmp/monitor.sh /opt/postgres/monitor.sh",
      "sudo chmod +x /opt/postgres/monitor.sh",
      "(sudo crontab -l 2>/dev/null | grep -v monitor.sh; echo '*/5 * * * * /opt/postgres/monitor.sh') | sudo crontab -",
      "echo 'Monitoring cron job installed.'",
    ]
  }
}

# ===============================
# Azure Portal Dashboard
# ===============================

resource "azurerm_portal_dashboard" "shared_infra" {
  name                = local.dashboard_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tags                = local.common_tags

  dashboard_properties = templatefile("${path.module}/templates/dashboard.json.tpl", {
    vm_resource_id  = azurerm_linux_virtual_machine.postgres.id
    resource_suffix = local.resource_suffix
  })
}
