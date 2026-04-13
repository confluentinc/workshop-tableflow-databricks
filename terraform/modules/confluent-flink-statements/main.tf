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

  statement     = "ALTER TABLE `${var.clickstream_topic}` SET ('changelog.mode' = 'append');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

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

  statement     = "ALTER TABLE `${var.customer_topic}` SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact', 'kafka.compaction.time' = '7 d');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

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

  statement     = "ALTER TABLE `${var.customer_topic}` MODIFY WATERMARK FOR `updated_at` AS `updated_at` - INTERVAL '30' SECOND;"
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

  statement     = "ALTER TABLE `${var.hotel_topic}` SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact', 'kafka.compaction.time' = '7 d');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

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

  statement     = "ALTER TABLE `${var.hotel_topic}` MODIFY WATERMARK FOR `updated_at` AS `updated_at` - INTERVAL '30' SECOND;"
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

  statement     = "ALTER TABLE `${var.bookings_topic}` MODIFY WATERMARK FOR `created_at` AS `created_at` - INTERVAL '30' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

}

# ===============================
# Bookings: set 2-week retention
# ===============================

resource "confluent_flink_statement" "bookings_set_retention" {
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

  statement     = "ALTER TABLE `${var.bookings_topic}` SET ('kafka.retention.time' = '14 d');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [confluent_flink_statement.bookings_add_watermark]
}

# ===============================
# Clickstream: set 2-week retention
# ===============================

resource "confluent_flink_statement" "clickstream_set_retention" {
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

  statement     = "ALTER TABLE `${var.clickstream_topic}` SET ('kafka.retention.time' = '14 d');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [confluent_flink_statement.clickstream_set_append]
}

# ===============================
# Reviews: watermark + 2-week retention
# ===============================
# Watermark required for reviews_with_sentiment CTAS.

resource "confluent_flink_statement" "reviews_add_watermark" {
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

  statement     = "ALTER TABLE `${var.reviews_topic}` MODIFY WATERMARK FOR `created_at` AS `created_at` - INTERVAL '30' SECOND;"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

}

resource "confluent_flink_statement" "reviews_set_retention" {
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

  statement     = "ALTER TABLE `${var.reviews_topic}` SET ('kafka.retention.time' = '14 d');"
  properties    = local.flink_properties
  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  depends_on = [confluent_flink_statement.reviews_add_watermark]
}
