# ===============================
# Shared Infrastructure Monitoring (Azure Monitor)
# ===============================
# Azure Monitor-based observability for the shared VM running PostgreSQL
# and ShadowTraffic. Always enabled — shared infra should always be
# monitored, especially during production workshops.
#
# Components:
#   - System-assigned managed identity on VM (for Azure Monitor auth)
#   - Monitoring Metrics Publisher RBAC role
#   - Action group for email alerts
#   - Platform metric alerts (CPU, VM availability)
#   - Custom metrics cron script (disk, PostgreSQL stats, Docker health, ShadowTraffic)
#   - Custom metric alerts (disk, replication lag, connections, container health, write errors)
#   - Azure Portal dashboard

locals {
  effective_alert_email  = coalesce(var.alert_email, var.owner_email)
  dashboard_name         = "wsa-shared-infra-${local.resource_suffix}"
  custom_metric_namespace = "WSA/SharedInfra"
}

# ===============================
# Monitoring RBAC (VM → Azure Monitor custom metrics)
# ===============================

resource "azurerm_role_assignment" "monitoring_metrics_publisher" {
  scope                = azurerm_resource_group.shared.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_linux_virtual_machine.postgres.identity[0].principal_id
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
# Platform Metric Alerts
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
# Custom Metric Alerts
# ===============================
# These fire on metrics pushed by the collect-metrics.sh cron job
# via the Azure Monitor custom metrics API.

resource "azurerm_monitor_metric_alert" "memory_high" {
  name                = "${var.prefix}-memory-high-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  scopes              = [azurerm_linux_virtual_machine.postgres.id]
  description         = "Memory usage above ${var.alarm_memory_threshold}% for 5 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = local.custom_metric_namespace
    metric_name      = "MemoryUsedPercent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.alarm_memory_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.shared.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "disk_high" {
  name                = "${var.prefix}-disk-high-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  scopes              = [azurerm_linux_virtual_machine.postgres.id]
  description         = "Disk usage above ${var.alarm_disk_threshold}% for 5 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = local.custom_metric_namespace
    metric_name      = "DiskUsedPercent"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = var.alarm_disk_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.shared.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "replication_lag" {
  name                = "${var.prefix}-replication-lag-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  scopes              = [azurerm_linux_virtual_machine.postgres.id]
  description         = "PostgreSQL max replication lag above ${var.alarm_replication_lag_bytes} bytes for 5 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  auto_mitigate       = true

  criteria {
    metric_namespace = local.custom_metric_namespace
    metric_name      = "ReplicationLagBytes"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = var.alarm_replication_lag_bytes
  }

  action {
    action_group_id = azurerm_monitor_action_group.shared.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "connections_high" {
  name                = "${var.prefix}-connections-high-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  scopes              = [azurerm_linux_virtual_machine.postgres.id]
  description         = "PostgreSQL active connections above ${var.alarm_max_connections} for 5 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  auto_mitigate       = true

  criteria {
    metric_namespace = local.custom_metric_namespace
    metric_name      = "ActiveConnections"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = var.alarm_max_connections
  }

  action {
    action_group_id = azurerm_monitor_action_group.shared.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "shadowtraffic_unhealthy" {
  name                = "${var.prefix}-shadowtraffic-unhealthy-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  scopes              = [azurerm_linux_virtual_machine.postgres.id]
  description         = "ShadowTraffic container is unhealthy or stopped for 2+ minutes"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = local.custom_metric_namespace
    metric_name      = "ContainerHealthy_shadowtraffic"
    aggregation      = "Minimum"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.shared.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "postgres_down" {
  name                = "${var.prefix}-postgres-down-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  scopes              = [azurerm_linux_virtual_machine.postgres.id]
  description         = "PostgreSQL container is stopped for 2+ minutes"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = local.custom_metric_namespace
    metric_name      = "ContainerRunning_postgres"
    aggregation      = "Minimum"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.shared.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "shadowtraffic_errors" {
  name                = "${var.prefix}-shadowtraffic-errors-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  scopes              = [azurerm_linux_virtual_machine.postgres.id]
  description         = "ShadowTraffic write errors detected in the last 5 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  auto_mitigate       = true

  criteria {
    metric_namespace = local.custom_metric_namespace
    metric_name      = "ShadowTrafficWriteErrors"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.shared.id
  }

  tags = local.common_tags
}

# ===============================
# Custom Metrics Script (deployed via SSH)
# ===============================
# Installs a cron job on the VM that collects PostgreSQL stats, Docker
# container health, disk usage, and ShadowTraffic Prometheus metrics,
# then pushes them to Azure Monitor via the custom metrics REST API.
# The VM authenticates using its system-assigned managed identity (IMDS).

resource "null_resource" "monitoring_setup" {
  triggers = {
    vm_id = azurerm_linux_virtual_machine.postgres.id
  }

  depends_on = [
    azurerm_linux_virtual_machine.postgres,
    azurerm_role_assignment.monitoring_metrics_publisher,
  ]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.postgres.ip_address
    user        = var.vm_admin_username
    private_key = tls_private_key.shared.private_key_pem
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/monitoring",
      "sudo chmod 777 /opt/monitoring",
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/collect-metrics.sh.tpl", {
      region       = var.cloud_region
      resource_uri = azurerm_linux_virtual_machine.postgres.id
      db_name      = var.postgres_db_name
      db_username  = var.postgres_db_username
    })
    destination = "/opt/monitoring/collect-metrics.sh"
  }

  provisioner "remote-exec" {
    inline = [
      <<-SCRIPT
      set -e
      echo '================================================'
      echo 'Monitoring Setup'
      echo '================================================'

      # Install dependencies
      echo 'Installing monitoring dependencies...'
      sudo apt-get update -qq
      sudo apt-get install -y -qq curl jq 2>/dev/null || true

      # Install cronie (crontab) if not present
      if ! command -v crontab &>/dev/null; then
        echo 'Installing cron...'
        sudo apt-get install -y -qq cron 2>/dev/null || true
        sudo systemctl enable cron && sudo systemctl start cron
      fi

      sudo chmod +x /opt/monitoring/collect-metrics.sh

      # Set up cron job to run every minute
      CRON_LINE="* * * * * /opt/monitoring/collect-metrics.sh >> /var/log/monitoring-metrics.log 2>&1"
      (sudo crontab -l 2>/dev/null | grep -v collect-metrics || true; echo "$CRON_LINE") | sudo crontab -

      # Run once immediately to verify
      echo 'Running initial metrics collection...'
      sudo /opt/monitoring/collect-metrics.sh || echo 'Initial metrics collection had errors (may be transient — identity propagation can take a few minutes)'

      echo ''
      echo '================================================'
      echo 'Monitoring setup complete!'
      echo '================================================'
      SCRIPT
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
