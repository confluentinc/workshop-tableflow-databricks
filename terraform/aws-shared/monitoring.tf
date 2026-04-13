# ===============================
# Shared Infrastructure Monitoring
# ===============================
# CloudWatch-based observability for the shared EC2 instance running
# PostgreSQL and the data generator. Always enabled — shared infra should
# always be monitored, especially during production workshops.
#
# Components:
#   - IAM role + instance profile for CloudWatch agent on EC2
#   - CloudWatch agent (system metrics + log streaming)
#   - Custom metrics cron script (PostgreSQL stats, Docker health, data generator Prometheus)
#   - CloudWatch alarms with configurable thresholds
#   - SNS topic for email alerts
#   - CloudWatch dashboard

locals {
  monitoring_namespace  = "WSA/SharedInfra"
  effective_alert_email = coalesce(var.alert_email, var.owner_email)
  dashboard_name        = "wsa-shared-infra-${local.resource_suffix}"

  instance_dimension = {
    InstanceId = module.postgres.instance_id
  }
}

# ===============================
# IAM Role for CloudWatch Agent
# ===============================

resource "aws_iam_role" "monitoring" {
  name = "${var.prefix}-monitoring-${local.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "${var.prefix}-monitoring-${local.resource_suffix}"
  role = aws_iam_role.monitoring.name

  tags = local.common_tags
}

# ===============================
# SNS Topic for Alarm Notifications
# ===============================

resource "aws_sns_topic" "alerts" {
  name = "${var.prefix}-alerts-${local.resource_suffix}"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  count = local.effective_alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = local.effective_alert_email
}

# ===============================
# CloudWatch Agent + Custom Metrics Setup
# ===============================

resource "null_resource" "monitoring_setup" {
  triggers = {
    instance_id = module.postgres.instance_id
  }

  depends_on = [
    module.postgres,
    null_resource.datagen_setup,
  ]

  connection {
    type        = "ssh"
    host        = module.postgres.public_dns
    user        = var.datagen_ssh_username
    private_key = file(module.keypair.private_key_path)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/monitoring",
      "sudo chmod 777 /opt/monitoring",
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/cloudwatch-agent-config.json.tpl", {
      instance_id = module.postgres.instance_id
    })
    destination = "/opt/monitoring/cloudwatch-agent-config.json"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/collect-metrics.sh.tpl", {
      region      = var.cloud_region
      namespace   = local.monitoring_namespace
      instance_id = module.postgres.instance_id
      db_name     = var.postgres_db_name
      db_username = var.postgres_db_username
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

      # Install CloudWatch agent
      echo 'Installing CloudWatch agent...'
      sudo dnf install -y amazon-cloudwatch-agent 2>/dev/null || \
        sudo yum install -y amazon-cloudwatch-agent 2>/dev/null || \
        echo 'CloudWatch agent package not found, trying RPM...'

      if ! command -v /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl &>/dev/null; then
        echo 'Installing CloudWatch agent from RPM...'
        sudo rpm -U https://amazoncloudwatch-agent.s3.amazonaws.com/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
      fi

      # Start CloudWatch agent with config
      echo 'Starting CloudWatch agent...'
      sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config \
        -m ec2 \
        -c file:/opt/monitoring/cloudwatch-agent-config.json \
        -s

      # Verify agent is running
      sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status

      # Install custom metrics cron script
      echo 'Setting up custom metrics cron job...'
      sudo chmod +x /opt/monitoring/collect-metrics.sh

      # Install awscli if not present (needed for put-metric-data)
      if ! command -v aws &>/dev/null; then
        echo 'Installing AWS CLI...'
        sudo dnf install -y awscli 2>/dev/null || sudo yum install -y awscli 2>/dev/null || true
      fi

      # Install jq for Prometheus metrics parsing
      if ! command -v jq &>/dev/null; then
        echo 'Installing jq...'
        sudo dnf install -y jq 2>/dev/null || sudo yum install -y jq 2>/dev/null || true
      fi

      # Install cronie (crontab) — not included by default on AL2023
      if ! command -v crontab &>/dev/null; then
        echo 'Installing cronie...'
        sudo dnf install -y cronie 2>/dev/null || sudo yum install -y cronie 2>/dev/null || true
        sudo systemctl enable crond && sudo systemctl start crond
      fi

      # Set up cron job to run every minute.
      # The `|| true` after grep prevents set -e from aborting the subshell
      # when crontab is empty (grep -v returns exit 1 with no input).
      CRON_LINE="* * * * * /opt/monitoring/collect-metrics.sh >> /var/log/monitoring-metrics.log 2>&1"
      (sudo crontab -l 2>/dev/null | grep -v collect-metrics || true; echo "$CRON_LINE") | sudo crontab -

      # Run once immediately to verify
      echo 'Running initial metrics collection...'
      sudo /opt/monitoring/collect-metrics.sh || echo 'Initial metrics collection had errors (may be transient)'

      echo ''
      echo '================================================'
      echo 'Monitoring setup complete!'
      echo '================================================'
      SCRIPT
    ]
  }
}

# ===============================
# CloudWatch Alarms
# ===============================

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.prefix}-cpu-high-${local.resource_suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold
  alarm_description   = "EC2 CPU utilization above ${var.alarm_cpu_threshold}% for 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = local.instance_dimension

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.prefix}-memory-high-${local.resource_suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_memory_threshold
  alarm_description   = "Memory usage above ${var.alarm_memory_threshold}% for 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = local.instance_dimension

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "${var.prefix}-disk-high-${local.resource_suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.alarm_disk_threshold
  alarm_description   = "Disk usage above ${var.alarm_disk_threshold}% for 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = module.postgres.instance_id
    path       = "/"
    device     = "nvme0n1p1"
    fstype     = "xfs"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "instance_status" {
  alarm_name          = "${var.prefix}-instance-status-${local.resource_suffix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "EC2 instance status check failed"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = local.instance_dimension

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "replication_lag" {
  alarm_name          = "${var.prefix}-replication-lag-${local.resource_suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ReplicationLagBytes"
  namespace           = local.monitoring_namespace
  period              = 300
  statistic           = "Maximum"
  threshold           = var.alarm_replication_lag_bytes
  alarm_description   = "PostgreSQL max replication lag above ${var.alarm_replication_lag_bytes} bytes for 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = { InstanceId = module.postgres.instance_id }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "connections_high" {
  alarm_name          = "${var.prefix}-connections-high-${local.resource_suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ActiveConnections"
  namespace           = local.monitoring_namespace
  period              = 300
  statistic           = "Maximum"
  threshold           = var.alarm_max_connections
  alarm_description   = "PostgreSQL active connections above ${var.alarm_max_connections} for 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = { InstanceId = module.postgres.instance_id }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "datagen_unhealthy" {
  alarm_name          = "${var.prefix}-datagen-unhealthy-${local.resource_suffix}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ContainerHealthy_datagen"
  namespace           = local.monitoring_namespace
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Data generator container is unhealthy or stopped for 2+ minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = { InstanceId = module.postgres.instance_id }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "postgres_down" {
  alarm_name          = "${var.prefix}-postgres-down-${local.resource_suffix}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ContainerRunning_postgres"
  namespace           = local.monitoring_namespace
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "PostgreSQL container is stopped for 2+ minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = { InstanceId = module.postgres.instance_id }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "datagen_errors" {
  alarm_name          = "${var.prefix}-datagen-errors-${local.resource_suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DatagenWriteErrors"
  namespace           = local.monitoring_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Data generator write errors detected in the last 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = { InstanceId = module.postgres.instance_id }

  tags = local.common_tags
}

# ===============================
# CloudWatch Dashboard
# ===============================

resource "aws_cloudwatch_dashboard" "shared_infra" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# WSA Shared Infrastructure — ${local.resource_suffix}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title   = "CPU Utilization"
          view    = "timeSeries"
          stacked = false
          region  = var.cloud_region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", module.postgres.instance_id, { stat = "Average" }]
          ]
          annotations = {
            horizontal = [{ value = var.alarm_cpu_threshold, label = "Alarm threshold" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title   = "Memory Utilization"
          view    = "timeSeries"
          stacked = false
          region  = var.cloud_region
          metrics = [
            ["CWAgent", "mem_used_percent", "InstanceId", module.postgres.instance_id, { stat = "Average" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title   = "Disk Usage"
          view    = "timeSeries"
          stacked = false
          region  = var.cloud_region
          metrics = [
            ["CWAgent", "disk_used_percent", "InstanceId", module.postgres.instance_id, "path", "/", "device", "nvme0n1p1", "fstype", "xfs", { stat = "Maximum" }]
          ]
          annotations = {
            horizontal = [{ value = var.alarm_disk_threshold, label = "Alarm threshold" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 8
        height = 6
        properties = {
          title   = "Network I/O"
          view    = "timeSeries"
          stacked = false
          region  = var.cloud_region
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", module.postgres.instance_id, { stat = "Sum" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", module.postgres.instance_id, { stat = "Sum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 7
        width  = 8
        height = 6
        properties = {
          title   = "PostgreSQL — Replication Lag (bytes)"
          view    = "timeSeries"
          stacked = false
          region  = var.cloud_region
          metrics = [
            [local.monitoring_namespace, "ReplicationLagBytes", "InstanceId", module.postgres.instance_id, { stat = "Maximum" }]
          ]
          annotations = {
            horizontal = [{ value = var.alarm_replication_lag_bytes, label = "Alarm threshold" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 7
        width  = 8
        height = 6
        properties = {
          title   = "PostgreSQL — Active Connections"
          view    = "timeSeries"
          stacked = false
          region  = var.cloud_region
          metrics = [
            [local.monitoring_namespace, "ActiveConnections", "InstanceId", module.postgres.instance_id, { stat = "Maximum" }]
          ]
          annotations = {
            horizontal = [{ value = var.alarm_max_connections, label = "Alarm threshold" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 8
        height = 6
        properties = {
          title   = "PostgreSQL — Replication Slots"
          view    = "timeSeries"
          stacked = false
          region  = var.cloud_region
          metrics = [
            [local.monitoring_namespace, "ReplicationSlotCount", "InstanceId", module.postgres.instance_id, { stat = "Maximum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 13
        width  = 8
        height = 6
        properties = {
          title   = "Container Health"
          view    = "timeSeries"
          stacked = false
          region  = var.cloud_region
          metrics = [
            [local.monitoring_namespace, "ContainerHealthy_datagen", "InstanceId", module.postgres.instance_id, { stat = "Minimum", label = "Data Generator" }],
            [local.monitoring_namespace, "ContainerRunning_postgres", "InstanceId", module.postgres.instance_id, { stat = "Minimum", label = "PostgreSQL" }]
          ]
          yAxis = { left = { min = 0, max = 1.5 } }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 13
        width  = 8
        height = 6
        properties = {
          title   = "Data Generator — Write Errors"
          view    = "timeSeries"
          stacked = false
          region  = var.cloud_region
          metrics = [
            [local.monitoring_namespace, "DatagenWriteErrors", "InstanceId", module.postgres.instance_id, { stat = "Sum" }]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 19
        width  = 24
        height = 3
        properties = {
          title = "Alarm Status"
          alarms = [
            aws_cloudwatch_metric_alarm.cpu_high.arn,
            aws_cloudwatch_metric_alarm.memory_high.arn,
            aws_cloudwatch_metric_alarm.disk_high.arn,
            aws_cloudwatch_metric_alarm.instance_status.arn,
            aws_cloudwatch_metric_alarm.replication_lag.arn,
            aws_cloudwatch_metric_alarm.connections_high.arn,
            aws_cloudwatch_metric_alarm.datagen_unhealthy.arn,
            aws_cloudwatch_metric_alarm.postgres_down.arn,
            aws_cloudwatch_metric_alarm.datagen_errors.arn,
          ]
        }
      }
    ]
  })
}
