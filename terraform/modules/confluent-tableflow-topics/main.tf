# ===============================
# Confluent Tableflow Topics Module
# ===============================
# Enables Tableflow on workshop topics to stream them as Delta Lake
# tables to S3 via the provider integration. Used by demo mode to
# automate what self-service users do manually in the CC UI.
#
# Topics:
#   1. clickstream                 — raw append-mode data (8-week retention)
#   2. denormalized_hotel_bookings — enriched bookings (2-week retention)
#   3. reviews_with_sentiment      — AI-enriched reviews (2-week retention)

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

# ===============================
# Wait for CTAS topics to be created
# ===============================
# The denormalized_hotel_bookings and reviews_with_sentiment Kafka
# topics are created asynchronously by Flink CTAS statements. This
# sleep ensures they exist before Tableflow tries to enable on them.

resource "time_sleep" "wait_for_ctas_topics" {
  create_duration = "120s"
}

# ===============================
# Clickstream — Tableflow
# ===============================
# Exists immediately (created by data generator). No wait needed.

resource "confluent_tableflow_topic" "clickstream" {
  environment {
    id = var.environment_id
  }
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  display_name  = var.clickstream_topic
  table_formats = ["DELTA"]

  byob_aws {
    bucket_name             = var.s3_bucket_name
    provider_integration_id = var.provider_integration_id
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

  byob_aws {
    bucket_name             = var.s3_bucket_name
    provider_integration_id = var.provider_integration_id
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

resource "confluent_tableflow_topic" "reviews_with_sentiment" {
  environment {
    id = var.environment_id
  }
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  display_name  = "reviews_with_sentiment"
  table_formats = ["DELTA"]

  byob_aws {
    bucket_name             = var.s3_bucket_name
    provider_integration_id = var.provider_integration_id
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
