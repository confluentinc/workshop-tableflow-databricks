# ===============================
# Confluent Flink CTAS Module
# ===============================
# Creates persistent Flink CTAS statements that produce enriched
# data products for Tableflow. Used by demo mode to automate what
# self-service users run manually in LAB4.
#
# Statements created:
#   1. denormalized_hotel_bookings — temporal joins of bookings + customer + hotel
#   2. reviews_with_sentiment     — AI_SENTIMENT enrichment on raw reviews

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.64.0"
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
# Denormalized Hotel Bookings (temporal joins)
# ===============================
# Joins bookings with customer and hotel dimension tables using
# temporal joins. Produces a denormalized fact table ready for
# Tableflow and analytics.

resource "confluent_flink_statement" "denormalized_hotel_bookings" {
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

  statement = <<-SQL
    CREATE TABLE denormalized_hotel_bookings (
      PRIMARY KEY (`booking_id`) NOT ENFORCED,
      WATERMARK FOR `booking_date` AS `booking_date` - INTERVAL '30' SECOND
    ) WITH (
      'changelog.mode' = 'upsert',
      'kafka.cleanup-policy' = 'compact'
    ) AS
    SELECT
      b.`booking_id`,
      h.`hotel_id`,
      h.`name` AS `hotel_name`,
      h.`description` AS `hotel_description`,
      h.`category` AS `hotel_category`,
      h.`city` AS `hotel_city`,
      h.`country` AS `hotel_country`,
      b.`price` AS `booking_amount`,
      b.`occupants` AS `guest_count`,
      b.`created_at` AS `booking_date`,
      CAST(TO_TIMESTAMP_LTZ(b.`check_in`, 3) AS DATE) AS `check_in`,
      CAST(TO_TIMESTAMP_LTZ(b.`check_out`, 3) AS DATE) AS `check_out`,
      c.`email` AS `customer_email`,
      c.`first_name` AS `customer_first_name`,
      c.`rewards_points` AS `customer_rewards_points`
    FROM `${var.bookings_topic}` b
      JOIN `${var.customer_topic}` FOR SYSTEM_TIME AS OF b.`created_at` AS c
        ON c.`email` = b.`customer_email`
      JOIN `${var.hotel_topic}` FOR SYSTEM_TIME AS OF b.`created_at` AS h
        ON h.`hotel_id` = b.`hotel_id`;
  SQL

  properties = merge(local.flink_properties, {
    "client.statement-name" = "denormalized-hotel-bookings"
  })

  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# ===============================
# Reviews with AI Sentiment Analysis
# ===============================
# Enriches hotel reviews with aspect-based sentiment analysis using
# the AI_SENTIMENT built-in function. Pure enrichment — no join.

resource "confluent_flink_statement" "reviews_with_sentiment" {
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

  statement = <<-SQL
    CREATE TABLE reviews_with_sentiment (
      PRIMARY KEY (`review_id`) NOT ENFORCED,
      WATERMARK FOR `created_at` AS `created_at` - INTERVAL '30' SECOND
    ) WITH (
      'changelog.mode' = 'upsert',
      'kafka.cleanup-policy' = 'compact'
    ) AS
    SELECT
      review_id,
      hotel_id,
      review_rating,
      review_text,
      created_at,
      sentiment_result.sentiment[1].label AS cleanliness_label,
      sentiment_result.sentiment[1].score AS cleanliness_score,
      sentiment_result.sentiment[2].label AS amenities_label,
      sentiment_result.sentiment[2].score AS amenities_score,
      sentiment_result.sentiment[3].label AS service_label,
      sentiment_result.sentiment[3].score AS service_score
    FROM (
      SELECT
        `review_id`,
        `hotel_id`,
        `review_rating`,
        `review_text`,
        `created_at`,
        AI_SENTIMENT(
          `review_text`,
          ARRAY['cleanliness', 'amenities', 'service']
        ) AS sentiment_result
      FROM `${var.reviews_topic}`
    );
  SQL

  properties = merge(local.flink_properties, {
    "client.statement-name" = "hotel-reviews-with-sentiment"
  })

  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
