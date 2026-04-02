# LAB 3: Stream Processing

## Overview

This lab transforms your raw CDC data streams into enriched data products using Confluent Cloud's Flink SQL. You will build real-time processing pipelines that create denormalized datasets and analytical aggregations.

### What You'll Accomplish

By the end of this lab you will have:

1. **Explored Streaming CDC Data**: Queried real-time CDC topics with Flink SQL
2. **Created Enriched Data Products**: Built denormalized bookings combining customer and hotel data using temporal joins
3. **Created AI-Enriched Reviews**: Used `AI_SENTIMENT` to analyze hotel reviews by cleanliness, amenities, and service

![Architecture diagram for stream processing](./images/arch_diagram_flink.jpg)

### Prerequisites

- Completed **[LAB 2: Explore Your Environment](../LAB2_explore_environment/LAB2.md)** with data flowing to Kafka topics

## Step 1: Explore Streaming Data with Flink SQL

### Navigate to Flink Compute Pool

1. Navigate to your [workshop Flink compute pool](https://confluent.cloud/go/flink)

> [!WARNING]
> **ERROR: You don't have the required permission**
>
> If you see an error like the one below, then close the workspace by clicking on the "x" icon in the top right of the tab.
>
> Then navigate back to Flink and open a new SQL workspace.
>
> ![Red error](./images/stale_flink_workspace.png)

2. Select your workshop environment
3. Click **Continue**

   ![Environment dropdown in flink navigation modal](../../shared/images/navigate_to_flink.png)

4. Click on the **SQL Workspace** button in your workshop Flink compute pool

   ![Flink Compute Pools](../../shared/images/flink_compute_pool.png)

5. Ensure your workspace environment and cluster are both selected in the `Use catalog` and `Use database` dropdowns at the top of your compute pool screen

6. Drill down in the left navigation to see the tables in your environment and cluster

### Explore CDC Data

All of your data comes through PostgreSQL CDC connectors and uses the `riverhotel.cdc.` topic prefix. The connector is configured with `after.state.only = true`, which produces flat Avro records that you can query directly in Flink.

> **Tip**: Click the *+* button in the narrow side panel at the top left of the cell to create new cells. Create ~6 new cells as you will need them throughout this lab. Delete the current cell by clicking the trash icon below the *+*.
>
> ![Trash icon to delete cell](../../shared/images/confluent_flink_delete_cell.png)

Start by reviewing data from the CDC topics:

```sql
-- View customer data from CDC
SELECT * FROM `riverhotel.cdc.customer` LIMIT 10;
```

Click the *Run* button and review the results. You should see customer records with fields like `email`, `first_name`, `last_name`, `birth_date`, `created_at`, and `updated_at`.

![A table with CDC results](../../shared/images/confluent_flink_bookings.png)

Now explore booking data:

```sql
-- View bookings data from CDC
SELECT * FROM `riverhotel.cdc.bookings` LIMIT 10;
```

Some observations about this data:

- The `hotel_id` field references hotels but does not include hotel details like name or location
- There is no review information joined to the booking

### Run Streaming Data Queries

Execute this query to see the live count of booking data:

```sql
-- See streaming count of bookings data
SELECT COUNT(*) AS `TOTAL_BOOKINGS` FROM `riverhotel.cdc.bookings`;
```

Watch the count increase gradually as new booking data is produced.

## Step 2: Understand the Pre-configured CDC Topics

Your workshop infrastructure has already configured the CDC topics for use with Flink temporal joins and Tableflow. The connector uses `after.state.only = true` to produce flat Avro records (no Debezium envelope).

Primary keys are automatically derived from the Kafka message key (which maps to the source table's primary key).

Verify the customer table configuration:

```sql
SHOW CREATE TABLE `riverhotel.cdc.customer`;
```

You should see a primary key on `email` (from the Kafka key), a watermark on `updated_at`, and `changelog.mode = 'upsert'` in the `WITH` clause. This enables the CDC topic to serve directly as a dimension table for [temporal joins](https://docs.confluent.io/cloud/current/flink/concepts/joins.html#temporal-joins) without creating a separate snapshot table.

## Step 3: Enrich and Denormalize Hotel Bookings

Your CDC topics are already configured with primary keys, watermarks, and changelog modes. You will now process them into denormalized datasets useful for analytics.

### Create Denormalized Table

This query creates a denormalized table combining booking data with customer information and hotel details using [temporal joins](https://docs.confluent.io/cloud/current/flink/concepts/joins.html#temporal-joins). Because the CDC topics are pre-configured with primary keys and watermarks, you can join them directly without creating separate snapshot tables:

```sql
SET 'client.statement-name' = 'denormalized-hotel-bookings';

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
  b.`check_in`,
  b.`check_out`,
  c.`email` AS `customer_email`,
  c.`first_name` AS `customer_first_name`
FROM `riverhotel.cdc.bookings` b
  JOIN `riverhotel.cdc.customer` FOR SYSTEM_TIME AS OF b.`created_at` AS c
    ON c.`email` = b.`customer_email`
  JOIN `riverhotel.cdc.hotel` FOR SYSTEM_TIME AS OF b.`created_at` AS h
    ON h.`hotel_id` = b.`hotel_id`;
```

<details>
<summary>Expand for details on this Flink statement</summary>

This **[CREATE TABLE AS SELECT (CTAS)](https://docs.confluent.io/cloud/current/flink/reference/statements/create-table-as.html)** statement creates a real-time **denormalized fact table** by joining streaming tables using [temporal joins](https://docs.confluent.io/cloud/current/flink/concepts/joins.html#temporal-joins).

**Understanding Temporal Joins**

Temporal joins allow you to join a streaming fact table (bookings) with dimension tables (customer, hotel) using point-in-time lookups. The `FOR SYSTEM_TIME AS OF` clause retrieves the dimension record as it existed at the time specified by the booking's event timestamp.

| Component | Purpose |
|-----------|---------|
| **CDC dimension tables** | `riverhotel.cdc.customer` and `riverhotel.cdc.hotel` with primary keys, upsert mode, and watermarks (pre-configured by Terraform) |
| **Watermarks** | Define event-time progression for temporal semantics |
| **`FOR SYSTEM_TIME AS OF`** | Looks up dimension state at the exact time of each booking event |

**Key Requirements for Temporal Joins**

1. **Primary Key**: The dimension table must have a declared primary key
2. **Watermark**: Both the probe side (bookings) and dimension side (customer, hotel) need watermarks
3. **Upsert Mode**: Dimension tables use `changelog.mode = 'upsert'` to maintain current state
4. **Historical Versions**: The dimension topic must retain historical record versions — compaction cannot remove them before the temporal join reads them. This workshop uses `min.compaction.lag.ms = 7 days` to preserve versions during the workshop window.

</details>

### Verify Denormalization Results

Run this query to return 20 records from the denormalized table:

```sql
SELECT *
  FROM `denormalized_hotel_bookings`
LIMIT 20;
```

Some observations:

- Each booking is enriched with **customer** and **hotel** details via temporal joins
- The `booking_date` watermark enables downstream analytics and time-based filtering

You can also verify the table in the left navigation panel:

![List of tables](../../shared/images/confluent_flink_table_explorer.png)

> **Tip**: Hover over the *Tables* left menu item to reveal a sync icon. Click it to refresh any new tables into the UI.
>
> ![Menu item with a refresh](../../shared/images/confluent_flink_tables_refresh.png)

Click on `denormalized_hotel_bookings` to see its schema:

![Table schema](../../shared/images/confluent_flink_table_schema.png)

### Enrich Hotel Reviews with AI Sentiment Analysis

Now create a table that enriches hotel reviews with AI-powered sentiment analysis. This table joins reviews with `denormalized_hotel_bookings` to add hotel context, then uses the [`AI_SENTIMENT`](https://docs.confluent.io/cloud/current/ai/builtin-functions/sentiment.html) function to analyze each review across three aspects: cleanliness, amenities, and service.

```sql
SET 'sql.state-ttl' = '7 d';
SET 'client.statement-name' = 'hotel-reviews-with-sentiment';

CREATE TABLE hotel_reviews_with_sentiment (
  PRIMARY KEY (`review_id`) NOT ENFORCED,
  WATERMARK FOR `created_at` AS `created_at` - INTERVAL '30' SECOND
) WITH (
  'changelog.mode' = 'upsert',
  'kafka.cleanup-policy' = 'compact'
) AS
SELECT
  review_id,
  booking_id,
  hotel_id,
  hotel_name,
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
    hr.`review_id`,
    hr.`booking_id`,
    dhb.`hotel_id`,
    dhb.`hotel_name`,
    hr.`review_rating`,
    hr.`review_text`,
    hr.`created_at`,
    AI_SENTIMENT(
      hr.`review_text`,
      ARRAY['cleanliness', 'amenities', 'service']
    ) AS sentiment_result
  FROM `riverhotel.cdc.hotel_reviews` hr
  JOIN `denormalized_hotel_bookings` dhb
    ON dhb.`booking_id` = hr.`booking_id`
);
```

<details>
<summary>Expand for details on AI_SENTIMENT</summary>

**[`AI_SENTIMENT`](https://docs.confluent.io/cloud/current/ai/builtin-functions/sentiment.html)** is a built-in Confluent Cloud for Apache Flink function that performs **aspect-based sentiment analysis** using a fine-tuned DeBERTa model. Unlike general sentiment analysis, it evaluates sentiment for each specified aspect independently.

**How it works:**

- Takes a text input and an array of aspects to evaluate
- Returns a structured result with `sentiment` and `confidence` for each aspect
- Each aspect gets a `label` (`positive`, `negative`, or `neutral`) and a `score` (0.0 to 1.0)

**Why flatten?** `AI_SENTIMENT` returns a nested `ROW` type with an array of aspect results. The subquery calls `AI_SENTIMENT` once, and the outer query extracts the individual aspect labels and scores into flat columns (`cleanliness_label`, `amenities_label`, `service_label`, etc.). This produces a clean, flat schema in the Kafka topic that maps directly to simple Delta Lake columns via Tableflow — no nested struct navigation needed in Databricks.

**State TTL**: The `SET 'sql.state-ttl' = '7 d'` ensures the join state for matching reviews to bookings is retained for 7 days. This gives reviews time to arrive and match with their corresponding booking records.

</details>

Verify the sentiment-enriched reviews:

```sql
SELECT
  `review_id`,
  `hotel_name`,
  `review_rating`,
  SUBSTRING(`review_text`, 1, 50) AS `review_preview`,
  `cleanliness_label`,
  `amenities_label`,
  `service_label`,
  `service_score`
FROM `hotel_reviews_with_sentiment`
LIMIT 10;
```

## Conclusion

You have built a real-time streaming pipeline that transforms CDC data into enriched data products ready for Tableflow materialization and analytics. Your CDC topics were pre-configured by Terraform with primary keys, watermarks, and changelog modes, enabling direct temporal joins without intermediate snapshot tables.

You created two Flink tables: `denormalized_hotel_bookings` (enriched bookings with customer and hotel details) and `hotel_reviews_with_sentiment` (AI-enriched reviews with aspect-based sentiment analysis). The `riverhotel.cdc.clickstream` topic is also ready for Tableflow in append mode.

## What's Next

Continue to **[LAB 4: Tableflow](../LAB4_tableflow/LAB4.md)**.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
