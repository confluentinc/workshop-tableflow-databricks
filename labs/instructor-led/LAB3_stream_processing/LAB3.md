# LAB 3: Stream Processing

## Overview

This lab transforms your streaming data into enriched data products using Confluent Cloud's Flink SQL. You will build real-time processing pipelines that create denormalized datasets and analytical aggregations.

### What You'll Accomplish

By the end of this lab you will have:

1. **Explored Streaming Data**: Queried real-time topics with Flink SQL
2. **Created Enriched Data Products**: Built denormalized bookings combining customer and hotel data using temporal joins
3. **Created AI-Enriched Reviews**: Used `AI_SENTIMENT` to analyze hotel reviews by cleanliness, amenities, and service

![Architecture diagram for stream processing](../../shared/images/arch_diagram_stream_processing.jpg)

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

### Explore Streaming Data

Your workshop has two data sources: **PostgreSQL CDC** for dimension tables (`riverhotel.cdc.customer`, `riverhotel.cdc.hotel`) and the **Java data generator** which produces `bookings`, `clickstream`, and `reviews` directly to Kafka. All use flat Avro records that you can query directly in Flink.

> **Tip**: Click the *+* button in the narrow side panel at the top left of the cell to create new cells. Create ~6 new cells as you will need them throughout this lab. Delete the current cell by clicking the trash icon below the *+*.
>
> ![Trash icon to delete cell](../../shared/images/confluent_flink_delete_cell.png)

Start by reviewing data from the CDC dimension tables:

```sql
-- View customer data from CDC
SELECT * FROM `riverhotel.cdc.customer` LIMIT 10;
```

Click the *Run* button and review the results. You should see customer records with fields like `email`, `first_name`, `last_name`, `birth_date`, `created_at`, and `updated_at`.

![A table with CDC results](../../shared/images/confluent_flink_bookings.png)

Now explore booking data (produced directly to Kafka by the data generator):

```sql
-- View bookings data
SELECT * FROM `bookings` LIMIT 10;
```

Some observations about this data:

- The `hotel_id` field references hotels but does not include hotel details like name or location
- There is no review information joined to the booking

### Run Streaming Data Queries

Execute this query to see the live count of booking data:

```sql
-- See streaming count of bookings data
SELECT COUNT(*) AS `TOTAL_BOOKINGS` FROM `bookings`;
```

Watch the count increase gradually as new booking data is produced.

## Step 2: Understand the Pre-configured CDC Dimension Topics

Your workshop infrastructure has already configured the CDC dimension topics (`riverhotel.cdc.customer`, `riverhotel.cdc.hotel`) for use with Flink temporal joins. The connector uses `after.state.only = true` to produce flat Avro records (no Debezium envelope).

Primary keys are automatically derived from the Kafka message key (which maps to the source table's primary key).

Verify the customer table configuration:

```sql
SHOW CREATE TABLE `riverhotel.cdc.customer`;
```

You should see a primary key on `email` (from the Kafka key), a watermark on `updated_at`, and `changelog.mode = 'upsert'` in the `WITH` clause. This enables the CDC topic to serve directly as a dimension table for [temporal joins](https://docs.confluent.io/cloud/current/flink/concepts/joins.html#temporal-joins) without creating a separate snapshot table.

## Step 3: Enrich and Denormalize Hotel Bookings

Your CDC topics are already configured with primary keys, watermarks, and changelog modes. You will now process them into denormalized datasets useful for analytics.

> **What are Materialized Tables?**
>
> In this lab you will use [Materialized Tables](https://docs.confluent.io/cloud/current/flink/concepts/materialized-tables.html), a Confluent Cloud feature that combines a table definition with a continuous query in a single persistent, evolvable object. Unlike a traditional `CREATE TABLE ... AS SELECT` (CTAS), a Materialized Table can be updated in place using `CREATE OR ALTER MATERIALIZED TABLE` — Flink stops the old query and starts the new one on the same output topic, so downstream consumers (Tableflow, Databricks) are unaffected. Each Materialized Table is backed by a Kafka topic and a Schema Registry subject, and the `START_MODE` clause controls how much historical data is reprocessed on creation or evolution.

### Create Denormalized Table

This query creates a materialized table combining booking data with customer information and hotel details using [temporal joins](https://docs.confluent.io/cloud/current/flink/concepts/joins.html#temporal-joins). Because the CDC topics are pre-configured with primary keys and watermarks, you can join them directly without creating separate snapshot tables:

```sql
CREATE MATERIALIZED TABLE denormalized_hotel_bookings
AS
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
FROM `bookings` b
  JOIN `riverhotel.cdc.customer` FOR SYSTEM_TIME AS OF b.`created_at` AS c
    ON c.`email` = b.`customer_email`
  JOIN `riverhotel.cdc.hotel` FOR SYSTEM_TIME AS OF b.`created_at` AS h
    ON h.`hotel_id` = b.`hotel_id`;
```

<details>
<summary>Expand for details on this Flink statement</summary>

This **[CREATE MATERIALIZED TABLE](https://docs.confluent.io/cloud/current/flink/reference/statements/create-materialized-table.html)** statement creates a persistent **denormalized fact table** by joining streaming tables using [temporal joins](https://docs.confluent.io/cloud/current/flink/concepts/joins.html#temporal-joins). The materialized table automatically creates a backing Kafka topic, registers the schema in Schema Registry, and starts a continuous query that keeps the table populated.

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

**Why Materialized Tables?**

Unlike a CTAS, a materialized table is a first-class object that you can evolve in place. If you need to add a column or change the query logic, run `CREATE OR ALTER MATERIALIZED TABLE` and Flink handles the migration — no need to drop the table, lose the output topic, or reconfigure downstream consumers. See the [Materialized Tables documentation](https://docs.confluent.io/cloud/current/flink/concepts/materialized-tables.html) for details.

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

You can also verify the table in the left navigation panel.

> **Tip**: Hover over the *Tables* left menu item to reveal a sync icon. Click it to refresh any new tables into the UI.
>
> ![Menu item with a refresh](../../shared/images/confluent_flink_tables_refresh.png)

Click on `denormalized_hotel_bookings` to see its schema:

![Table schema](../../shared/images/confluent_flink_table_schema.png)

### Enrich Hotel Reviews with AI Sentiment Analysis

Now create a table that enriches hotel reviews with AI-powered sentiment analysis. This uses the [`AI_SENTIMENT`](https://docs.confluent.io/cloud/current/ai/builtin-functions/sentiment.html) function to analyze each review across three aspects: cleanliness, amenities, and service. The sentiment scores are flattened into individual columns for clean downstream analytics.

```sql
CREATE MATERIALIZED TABLE reviews_with_sentiment
AS
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
  FROM `reviews`
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

**No join needed**: This is a pure enrichment — each review is independently scored by `AI_SENTIMENT` without requiring any lookup against other tables. The `hotel_id` is carried through from the source topic so that reviews can be joined to hotel data later in Databricks.

</details>

Verify the sentiment-enriched reviews:

```sql
SELECT
  *
FROM `reviews_with_sentiment`
LIMIT 10;
```

## Conclusion

You have built a real-time streaming pipeline that transforms streaming data into enriched data products ready for Tableflow materialization and analytics. Your CDC dimension topics were pre-configured by Terraform with primary keys, watermarks, and changelog modes, enabling direct temporal joins without intermediate snapshot tables.

You created two [Materialized Tables](https://docs.confluent.io/cloud/current/flink/concepts/materialized-tables.html): `denormalized_hotel_bookings` (enriched bookings with customer and hotel details) and `reviews_with_sentiment` (AI-enriched reviews with aspect-based sentiment analysis). These are persistent, evolvable objects that can be updated in place using `CREATE OR ALTER MATERIALIZED TABLE`. The `clickstream` topic is also ready for Tableflow in append mode.

## What's Next

Continue to **[LAB 4: Tableflow](../LAB4_tableflow/LAB4.md)**.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
