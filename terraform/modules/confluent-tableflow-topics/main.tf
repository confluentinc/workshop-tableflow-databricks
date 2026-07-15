# ===============================
# Confluent Tableflow Topics Module
# ===============================
# Enables Tableflow on workshop topics to stream them as Delta Lake
# tables via the provider integration (AWS S3 or Azure ADLS Gen2).
# Used by demo mode to automate what self-service users do manually
# in the CC UI.
#
# Topics:
#   1. clickstream                 — raw append-mode data
#   2. denormalized_hotel_bookings — enriched bookings
#   3. reviews_with_sentiment      — AI-enriched reviews (optional; AWS only today)

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.64.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}

locals {
  is_aws   = var.cloud_provider == "aws"
  is_azure = var.cloud_provider == "azure"
}

# ===============================
# Wait for Materialized Table topics to be created
# ===============================
# The denormalized_hotel_bookings and reviews_with_sentiment Kafka
# topics are created asynchronously by Flink Materialized Tables. This
# sleep ensures they exist before Tableflow tries to enable on them.

resource "time_sleep" "wait_for_ctas_topics" {
  create_duration = "120s"
}

# ===============================
# Clickstream — Tableflow
# ===============================
# Exists immediately (created by data generator / CDC). No wait needed.

resource "confluent_tableflow_topic" "clickstream" {
  environment {
    id = var.environment_id
  }
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  display_name  = var.clickstream_topic
  table_formats = ["DELTA"]

  dynamic "byob_aws" {
    for_each = local.is_aws ? [1] : []
    content {
      bucket_name             = var.s3_bucket_name
      provider_integration_id = var.provider_integration_id
    }
  }

  dynamic "azure_data_lake_storage_gen_2" {
    for_each = local.is_azure ? [1] : []
    content {
      provider_integration_id = var.provider_integration_id
      container_name          = var.container_name
      storage_account_name    = var.storage_account_name
    }
  }

  credentials {
    key    = var.api_key
    secret = var.api_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# ===============================
# Denormalized Hotel Bookings — Tableflow
# ===============================

resource "confluent_tableflow_topic" "denormalized_hotel_bookings" {
  environment {
    id = var.environment_id
  }
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  display_name  = "denormalized_hotel_bookings"
  table_formats = ["DELTA"]

  dynamic "byob_aws" {
    for_each = local.is_aws ? [1] : []
    content {
      bucket_name             = var.s3_bucket_name
      provider_integration_id = var.provider_integration_id
    }
  }

  dynamic "azure_data_lake_storage_gen_2" {
    for_each = local.is_azure ? [1] : []
    content {
      provider_integration_id = var.provider_integration_id
      container_name          = var.container_name
      storage_account_name    = var.storage_account_name
    }
  }

  credentials {
    key    = var.api_key
    secret = var.api_secret
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [time_sleep.wait_for_ctas_topics]
}

# ===============================
# Reviews with Sentiment — Tableflow
# ===============================
# Optional: requires AI_SENTIMENT (not available on Azure as of June 2026).

resource "confluent_tableflow_topic" "reviews_with_sentiment" {
  count = var.enable_reviews_with_sentiment ? 1 : 0

  environment {
    id = var.environment_id
  }
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  display_name  = "reviews_with_sentiment"
  table_formats = ["DELTA"]

  dynamic "byob_aws" {
    for_each = local.is_aws ? [1] : []
    content {
      bucket_name             = var.s3_bucket_name
      provider_integration_id = var.provider_integration_id
    }
  }

  dynamic "azure_data_lake_storage_gen_2" {
    for_each = local.is_azure ? [1] : []
    content {
      provider_integration_id = var.provider_integration_id
      container_name          = var.container_name
      storage_account_name    = var.storage_account_name
    }
  }

  credentials {
    key    = var.api_key
    secret = var.api_secret
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [time_sleep.wait_for_ctas_topics]
}
