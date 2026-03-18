# ===============================
# Confluent Flink Statements Module
# ===============================
# Runs ALTER TABLE statements on CDC topics to configure them for
# direct use with Tableflow and Flink temporal joins, eliminating
# the need for manual CTAS snapshot tables in LAB4.
#
# Requires the CDC connector to use after.state.only=true so topics
# contain flat Avro records (no Debezium envelope).

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.32.0"
    }
  }
}

# ===============================
# Common Flink SQL Properties
# ===============================

locals {
  flink_properties = {
    "sql.current-catalog"  = var.environment_name
    "sql.current-database" = var.kafka_cluster_display_name
  }
}

# ===============================
# Wait for CDC Topics
# ===============================
# The connector creates topics on startup, but Flink's catalog
# discovery may lag by a few seconds. A short wait avoids race
# conditions with the ALTER TABLE statements.

resource "null_resource" "wait_for_topics" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "⏳ Waiting 30 seconds for CDC topics and schema registration..."
      sleep 30
      echo "✅ CDC topics should be available in Flink catalog."
    EOT
  }
}

# ===============================
# Clickstream: append mode for Tableflow
# ===============================

resource "confluent_flink_statement" "clickstream_set_append" {
  organization {
    id = var.organization_id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.compute_pool_id
  }
  principal {
    id = var.service_account_id
  }

  statement     = "ALTER TABLE `riverhotel.cdc.clickstream` SET ('changelog.mode' = 'append');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [null_resource.wait_for_topics]
}

# ===============================
# Customer: upsert + watermark
# ===============================
# Primary key is auto-derived from the Kafka message key (source table PK).

resource "confluent_flink_statement" "customer_set_upsert" {
  organization {
    id = var.organization_id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.compute_pool_id
  }
  principal {
    id = var.service_account_id
  }

  statement     = "ALTER TABLE `riverhotel.cdc.customer` SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact', 'kafka.compaction.time' = '7 d');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [null_resource.wait_for_topics]
}

resource "confluent_flink_statement" "customer_add_watermark" {
  organization {
    id = var.organization_id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.compute_pool_id
  }
  principal {
    id = var.service_account_id
  }

  statement     = "ALTER TABLE `riverhotel.cdc.customer` MODIFY WATERMARK FOR `updated_at` AS `updated_at` - INTERVAL '30' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [confluent_flink_statement.customer_set_upsert]
}

# ===============================
# Hotel: upsert + watermark
# ===============================
# Primary key is auto-derived from the Kafka message key (source table PK).

resource "confluent_flink_statement" "hotel_set_upsert" {
  organization {
    id = var.organization_id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.compute_pool_id
  }
  principal {
    id = var.service_account_id
  }

  statement     = "ALTER TABLE `riverhotel.cdc.hotel` SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact', 'kafka.compaction.time' = '7 d');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [null_resource.wait_for_topics]
}

resource "confluent_flink_statement" "hotel_add_watermark" {
  organization {
    id = var.organization_id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.compute_pool_id
  }
  principal {
    id = var.service_account_id
  }

  statement     = "ALTER TABLE `riverhotel.cdc.hotel` MODIFY WATERMARK FOR `updated_at` AS `updated_at` - INTERVAL '30' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [confluent_flink_statement.hotel_set_upsert]
}

# ===============================
# Bookings: watermark for temporal join probe side
# ===============================

resource "confluent_flink_statement" "bookings_add_watermark" {
  organization {
    id = var.organization_id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.compute_pool_id
  }
  principal {
    id = var.service_account_id
  }

  statement     = "ALTER TABLE `riverhotel.cdc.bookings` MODIFY WATERMARK FOR `created_at` AS `created_at` - INTERVAL '30' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [null_resource.wait_for_topics]
}

# ===============================
# Hotel Reviews: watermark for LEFT JOIN in denormalized bookings
# ===============================
# Without a watermark, the hotel_reviews stream blocks the output
# watermark of any downstream join from advancing.

resource "confluent_flink_statement" "hotel_reviews_add_watermark" {
  organization {
    id = var.organization_id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.compute_pool_id
  }
  principal {
    id = var.service_account_id
  }

  statement     = "ALTER TABLE `riverhotel.cdc.hotel_reviews` MODIFY WATERMARK FOR `created_at` AS `created_at` - INTERVAL '30' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [null_resource.wait_for_topics]
}
