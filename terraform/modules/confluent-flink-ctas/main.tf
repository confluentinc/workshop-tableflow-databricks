# ===============================
# Confluent Flink Materialized Tables Module
# ===============================
# Creates persistent Flink Materialized Tables that produce enriched
# data products for Tableflow. Materialized Tables combine a table
# definition with a continuous query in a single evolvable object.
# See: https://docs.confluent.io/cloud/current/flink/concepts/materialized-tables.html
#
# Tables created:
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
# Denormalized Hotel Bookings (temporal joins)
# ===============================
# Joins bookings with customer and hotel dimension tables using
# temporal joins. Produces a denormalized fact table ready for
# Tableflow and analytics.

resource "confluent_flink_materialized_table" "denormalized_hotel_bookings" {
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

  display_name = "denormalized_hotel_bookings"
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  query = <<-SQL
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
        ON h.`hotel_id` = b.`hotel_id`
  SQL

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

resource "confluent_flink_materialized_table" "reviews_with_sentiment" {
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

  display_name = "reviews_with_sentiment"
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  query = <<-SQL
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
    )
  SQL

  rest_endpoint = var.flink_rest_endpoint

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
