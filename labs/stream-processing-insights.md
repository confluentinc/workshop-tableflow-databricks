# Flink Streaming Joins with CDC Sources

## 🎯 Overview

This document provides guidance on joining streaming data with CDC (Change Data Capture) dimension tables in Confluent Cloud Flink, using **temporal joins** for point-in-time lookups.

## ✅ Recommended Approach: Temporal Joins

Temporal joins allow you to join a streaming fact table (e.g., bookings) with versioned dimension tables (e.g., customers, hotels) using point-in-time lookups.

### Creating Versioned Tables for Temporal Joins

To use temporal joins with CDC sources, create versioned tables with:

1. **Primary Key** - Identifies the dimension record
2. **Watermark** - Enables event-time semantics
3. **Upsert changelog mode** - Maintains current state per key

```sql
-- Create versioned customer table with watermark for temporal joins
CREATE TABLE customer_with_watermark (
  PRIMARY KEY (`email`) NOT ENFORCED,
  WATERMARK FOR `updated_at` AS `updated_at` - INTERVAL '5' SECOND
) DISTRIBUTED BY HASH(`email`) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'kafka.cleanup-policy' = 'compact'
) AS
SELECT
  `email`,
  `customer_id`,
  `first_name`,
  `last_name`,
  `birth_date`,
  TO_TIMESTAMP(`created_at`, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''') AS `created_at`,
  TO_TIMESTAMP(`updated_at`, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''') AS `updated_at`
FROM `riverhotel.cdc.customer`;
```

> **Note**: Use `TO_TIMESTAMP(column, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''')` to convert ISO 8601 VARCHAR timestamps from CDC sources to proper TIMESTAMP types for watermark operations.

### Using Temporal Joins

```sql
SELECT
  b.*,
  c.first_name,
  c.last_name
FROM bookings_with_watermark b
  JOIN customer_with_watermark FOR SYSTEM_TIME AS OF b.event_time AS c
    ON c.email = b.customer_email
```

The `FOR SYSTEM_TIME AS OF` clause retrieves the dimension record as it existed at the specified event time.

---

## 🔧 Appendix: Advanced Techniques

### A1: Changelog Modes for Different Join Types

| Join Type | Required Changelog Mode | Why |
|-----------|------------------------|-----|
| **Temporal Join** | `upsert` | Needs versioned state per primary key |
| **Interval Join** | `append` | Needs all events for time-range matching |

#### Why Upsert Mode for Temporal Joins?

For a **versioned table** used in temporal joins, you need `upsert` mode:

| Requirement | Upsert | Append |
|-------------|--------|--------|
| **Maintains current state per key** | ✅ Yes - replaces old with new | ❌ No - keeps all versions as separate rows |
| **Temporal join compatibility** | ✅ Flink can track versions by PK | ❌ Multiple rows per key breaks lookups |
| **Compacted Kafka topic** | ✅ Works with `kafka.cleanup-policy = 'compact'` | ❌ Incompatible |
| **Point-in-time lookups** | ✅ "What was customer X at time T?" | ❌ Would return multiple records |

#### How Temporal Joins Work

When you write:

```sql
JOIN customer_with_watermark FOR SYSTEM_TIME AS OF b.event_time AS c
  ON c.email = b.customer_email
```

Flink needs to:
1. Look up the customer by `email` (primary key)
2. Find the version that was **valid at** `b.event_time`
3. Return **one** matching record

This requires the versioned table to maintain **state per primary key** - which is exactly what upsert mode does.

#### Changelog Modes for Fact Tables and Result Tables

Beyond versioned dimension tables, you also need to consider changelog modes for:

1. **Fact tables** (probe side of temporal joins, e.g., `bookings_with_watermark`)
2. **Result tables** (output of joins, e.g., `denormalized_hotel_bookings`)

| Table Type | Recommended Mode | Why |
|------------|------------------|-----|
| **Versioned Dimension** (e.g., `customer_with_watermark`) | `upsert` | Maintains current state per key for temporal lookups |
| **Fact Stream** (e.g., `bookings_with_watermark`) | `append` | Each booking is a new immutable event |
| **Denormalized Result** (e.g., `denormalized_hotel_bookings`) | `upsert` | Allows enrichment when late data arrives |

#### Why Append for Fact Tables?

The `bookings_with_watermark` table uses `append` mode because:

- **Bookings are immutable events** - Each booking is created once and represents a point-in-time transaction
- **Temporal join semantics** - The probe side (fact stream) emits events that trigger lookups against versioned tables
- **No updates expected** - A booking doesn't get "updated" after creation; it's a historical record

```sql
-- Fact table: append mode (each booking is a new event)
CREATE TABLE bookings_with_watermark (
  WATERMARK FOR `event_time` AS `event_time` - INTERVAL '30' SECOND
) AS
SELECT
  *,
  `created_at` AS `event_time`
FROM `riverhotel.kafka.bookings`;
```

#### Why Upsert for Denormalized Result Tables?

The `denormalized_hotel_bookings` table uses `upsert` mode because:

- **Late-arriving data** - Reviews may arrive after the initial booking, and we want to enrich the existing record rather than create duplicates
- **One row per booking** - Using `booking_id` as primary key ensures a clean data model with exactly one row per booking
- **Downstream simplicity** - Consumers querying by `booking_id` get the latest complete state without needing to deduplicate

```sql
-- Result table: upsert mode (enriched when reviews arrive)
CREATE TABLE denormalized_hotel_bookings (
  PRIMARY KEY (`booking_id`) NOT ENFORCED
) WITH (
  'changelog.mode' = 'upsert',
  'kafka.cleanup-policy' = 'compact'
) AS
SELECT
  b.`booking_id`,
  -- ... booking, customer, hotel fields ...
  hr.`review_rating`,  -- May be NULL initially, enriched later
  hr.`review_text`
FROM `bookings_with_watermark` b
  JOIN `customer_with_watermark` FOR SYSTEM_TIME AS OF b.`event_time` AS c
    ON c.`email` = b.`customer_email`
  JOIN `hotel_with_watermark` FOR SYSTEM_TIME AS OF b.`event_time` AS h
    ON h.`hotel_id` = b.`hotel_id`
  LEFT JOIN `hotel_reviews` hr
    ON hr.`booking_id` = b.`booking_id`;
```

---

### A2: Handling Nullable Columns in Aggregations

When creating aggregate tables in Flink SQL, you may encounter primary key errors due to nullable columns:

> Invalid primary key 'PK_hotel_id_hotel_name...'. Column 'hotel_name' is nullable.

This occurs because Flink auto-infers primary keys from `GROUP BY` columns, but cannot create primary keys from nullable columns.

#### Solution: Use COALESCE

```sql
CREATE TABLE hotel_stats AS (
SELECT
  COALESCE(hotel_id, 'UNKNOWN_HOTEL') AS hotel_id,
  COALESCE(hotel_name, 'UNKNOWN_HOTEL_NAME') AS hotel_name,
  COUNT(*) AS total_bookings_count,
  SUM(booking_amount) AS total_booking_amount
FROM denormalized_hotel_bookings
WHERE hotel_id IS NOT NULL
GROUP BY
  COALESCE(hotel_id, 'UNKNOWN_HOTEL'),
  COALESCE(hotel_name, 'UNKNOWN_HOTEL_NAME')
);
```

---

### A3: Converting CDC Timestamps

CDC sources from PostgreSQL often deliver timestamps as VARCHAR strings. Convert them for watermark operations:

```sql
-- Convert ISO 8601 VARCHAR timestamp to TIMESTAMP type
TO_TIMESTAMP(`updated_at`, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''') AS `updated_at`

-- For epoch milliseconds, use:
TO_TIMESTAMP_LTZ(`created_at`, 3) AS `created_at`
```

---

### A4: Windowed Aggregations

For time-based analytics, use tumbling windows:

```sql
CREATE TABLE hotel_stats AS (
SELECT
  window_start,
  window_end,
  hotel_id,
  hotel_name,
  COUNT(*) AS total_bookings_count,
  SUM(booking_amount) AS total_booking_amount
FROM TABLE(
  TUMBLE(TABLE denormalized_hotel_bookings, DESCRIPTOR(booking_date), INTERVAL '15' MINUTE)
)
WHERE hotel_id IS NOT NULL
GROUP BY
  window_start,
  window_end,
  hotel_id,
  hotel_name
);
```

| Window Type | Use Case |
|-------------|----------|
| **TUMBLE** | Fixed periods (daily/hourly stats) |
| **HOP** | Overlapping windows (smoothing) |
| **CUMULATE** | Running totals within period |

#### Alternative: Continuous (Non-Windowed) Aggregation

If you want **one row per key** with running totals instead of per-window snapshots, use a non-windowed aggregation with `upsert` mode:

```sql
-- Continuous Aggregation (one row per hotel, updated in real-time)
SET 'sql.state-ttl' = '1 day';

SET 'client.statement-name' = 'hotel-stats';

CREATE TABLE hotel_stats (
  PRIMARY KEY (hotel_id) NOT ENFORCED
) WITH (
  'changelog.mode' = 'upsert',
  'kafka.cleanup-policy' = 'compact'
) AS
SELECT
  COALESCE(hotel_id, 'UNKNOWN_HOTEL') AS hotel_id,
  COALESCE(hotel_name, 'UNKNOWN_HOTEL_NAME') AS hotel_name,
  COALESCE(hotel_category, 'UNKNOWN_HOTEL_CATEGORY') AS hotel_category,
  COUNT(*) AS total_bookings_count,
  SUM(guest_count) AS total_guest_count,
  SUM(booking_amount) AS total_booking_amount,
  CAST(AVG(review_rating) AS DECIMAL(10, 2)) AS average_review_rating,
  SUM(CASE WHEN review_rating IS NOT NULL THEN 1 ELSE 0 END) AS review_count
FROM `denormalized_hotel_bookings`
WHERE hotel_id IS NOT NULL
GROUP BY
  COALESCE(hotel_id, 'UNKNOWN_HOTEL'),
  COALESCE(hotel_name, 'UNKNOWN_HOTEL_NAME'),
  COALESCE(hotel_category, 'UNKNOWN_HOTEL_CATEGORY');
```

| Approach | Rows Per Key | Changelog Mode | State | Use Case |
|----------|--------------|----------------|-------|----------|
| **Windowed (TUMBLE)** | One per window | `append` | Bounded (window closes) | Historical time-series analysis |
| **Non-windowed** | One total | `upsert` | Requires TTL | Real-time dashboards, current totals |

> **Note:** Non-windowed aggregations require `sql.state-ttl` to prevent unbounded state growth. See [A5: State TTL and Kafka Compaction](#a5-state-ttl-and-kafka-compaction) for details.

#### Watermarks Don't Propagate Through CTAS

When you create a table via CTAS, watermark attributes from source columns **do not automatically propagate** to output columns. If you later try to use a windowed aggregation on the output table, you'll get this error:

> The window function requires the timecol is a time attribute type, but is TIMESTAMP(3).

**Solution:** Explicitly define a watermark on the output table:

```sql
-- ❌ Without watermark - booking_date is just TIMESTAMP(3)
CREATE TABLE denormalized_hotel_bookings (
  PRIMARY KEY (`booking_id`) NOT ENFORCED
) AS
SELECT
  b.`event_time` AS `booking_date`,  -- Loses watermark attribute!
  ...
FROM bookings_with_watermark b;

-- ✅ With watermark - booking_date is a time attribute
CREATE TABLE denormalized_hotel_bookings (
  PRIMARY KEY (`booking_id`) NOT ENFORCED,
  WATERMARK FOR `booking_date` AS `booking_date` - INTERVAL '30' SECOND
) AS
SELECT
  b.`event_time` AS `booking_date`,
  ...
FROM bookings_with_watermark b;
```

The watermark definition on the output table makes `booking_date` a valid "time attribute" that can be used in window functions like `TUMBLE`, `HOP`, or `CUMULATE`.

---

### A5: State TTL and Kafka Compaction

When building streaming aggregations, it's important to understand the relationship between **Flink state management** and **Kafka topic retention**.

#### Two Separate Retention Mechanisms

| Component | Setting | Controls |
|-----------|---------|----------|
| **Flink State TTL** | `sql.state-ttl` | How long Flink keeps aggregation state in memory/RocksDB |
| **Kafka Retention** | `kafka.cleanup-policy`, `retention.ms` | How long Kafka keeps messages in the output topic |

```
┌─────────────────────────────────────────────────────────────────┐
│                     FLINK STATE (internal)                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  hotel_id: H001 → {count: 15, sum: 3000, ...}            │   │
│  │  ↑ Expires after TTL with no new events                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                     │
│                           ▼ (emitted updates)                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              KAFKA TOPIC (output)                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  H001 → {count: 15, sum: 3000, ...}                      │   │
│  │  ↑ Stays until Kafka retention/compaction                │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

#### Configuring State TTL in Confluent Cloud

```sql
-- Set state TTL before creating the table
SET 'sql.state-ttl' = '1 day';

CREATE TABLE hotel_stats (
  PRIMARY KEY (hotel_id) NOT ENFORCED
) WITH (
  'changelog.mode' = 'upsert',
  'kafka.cleanup-policy' = 'compact'
) AS
SELECT
  hotel_id,
  COUNT(*) AS total_bookings
FROM denormalized_hotel_bookings
GROUP BY hotel_id;
```

#### What State TTL Actually Does

State TTL controls **Flink's internal aggregation state**, NOT the output Kafka topic.

| Event | With Active State | With Expired State |
|-------|------------------|-------------------|
| New booking for hotel X | COUNT goes 15 → 16 | COUNT **restarts** at 1 |
| Query output topic | Shows last emitted value | Shows last emitted value |

**Key insight:** When state expires, Flink "forgets" the previous aggregation. The next event for that key starts fresh, as if it's the first event ever seen for that key.

#### Why Flink Doesn't Read Back from Kafka

A common question: "If aggregation state (COUNT=15) is in Kafka, why doesn't Flink read it back when state expires?"

Flink treats output topics as **sinks**, not sources for state:

| Reason | Explanation |
|--------|-------------|
| **Performance** | Local state: ~microseconds. Kafka read: ~milliseconds. 1000x slower. |
| **Forward-only streaming** | Stream processing flows forward, not in loops |
| **Exactly-once semantics** | Checkpointing works with internal state, not external reads |

This is a fundamental architectural difference from Kafka Streams (which uses Kafka topics as state stores).

#### Upsert Tables and Message Count

With `changelog.mode = 'upsert'`, Flink emits a **new message every time the aggregation updates**:

```
Booking 1 for H001 → emit {count: 1}
Booking 2 for H001 → emit {count: 2}
Booking 3 for H001 → emit {count: 3}
...
```

This means the Kafka topic may contain more messages than unique keys until compaction runs.

#### Kafka Compaction Behavior

With `kafka.cleanup-policy = 'compact'`:

| Behavior | Reality |
|----------|---------|
| **Immediate?** | No - runs as background process |
| **Active segment?** | Not compacted until closed |
| **Result** | Eventually keeps only latest value per key |

**Before compaction:** 45 messages (30 hotels × multiple updates)
**After compaction:** 30 messages (one per hotel_id)

#### Recommended TTL Settings

| Scenario | Suggested TTL |
|----------|---------------|
| Workshop/demo (30 hotels, regular traffic) | `1 day` or `4 hour` |
| Production (keys update at least daily) | `1 day` to `2 day` |
| Production (keys may go quiet for days) | `7 day` |
| High-cardinality keys (millions) | As short as possible |

#### Windowed vs Non-Windowed Aggregations

| Type | State Behavior | Changelog Mode |
|------|----------------|----------------|
| **Windowed** (TUMBLE, HOP) | State discarded after window closes | `append` (default) |
| **Non-windowed** (GROUP BY) | State kept until TTL expires | `upsert` |

Windowed aggregations naturally have bounded state because each window is independent. Non-windowed aggregations require TTL to prevent unbounded state growth.

---

### A6: Temporal Join Pitfall - Dimension Updates Cause Join Failures

When using temporal joins with dimensions that receive streaming updates, you may encounter a scenario where many fact records fail to join—even though the data appears correct.

#### The Problem

Consider this setup:

- **Historical dimension data**: Hotels created with `updated_at = 70 days ago`
- **Streaming dimension updates**: Hotels updated with `updated_at = now`
- **Fact data**: Bookings with `event_time` ranging from 60 days ago to today

```sql
-- Temporal join looking up hotel at booking time
JOIN `hotel_with_watermark` FOR SYSTEM_TIME AS OF b.`event_time` AS h
  ON h.`hotel_id` = b.`hotel_id`
```

**Expected**: All 432 bookings match hotels
**Actual**: Only 149 bookings match hotels

#### Why This Happens

The temporal join looks for a dimension version where `updated_at <= event_time`:

```
Timeline:
├── Oct 6:  Hotel created (updated_at = Oct 6) ✓ Version 1
│
├── Oct 16: Booking created (event_time = Oct 16)
│           → Looking for hotel with updated_at <= Oct 16
│           → Version 1 qualifies (Oct 6 <= Oct 16) ✓
│
├── Dec 15: Hotel UPDATE via streaming (updated_at = Dec 15)
│           → Version 1 is REPLACED by Version 2
│           → Only Version 2 exists now (Dec 15)
│
└── Result: Booking (Oct 16) can't find hotel version
            Dec 15 > Oct 16 → NO MATCH! ❌
```

#### The Design Conflict

| Feature | Behavior | Requirement |
|---------|----------|-------------|
| **Temporal Join** | Looks up "dimension state at event time" | Needs historical versions |
| **Upsert + Compact** | Keeps only latest version per key | Destroys historical versions |
| **CDC Updates** | Changes `updated_at` on each update | Creates new versions that replace old ones |

These three features are fundamentally incompatible. When a dimension record is updated, the previous version is lost, making point-in-time lookups for older events impossible.

#### Debugging Temporal Join Failures

Use these queries to identify if dimension updates are causing join failures:

```sql
-- Step 1: Compare regular join vs temporal join
-- Regular join (ignores time)
SELECT COUNT(*)
FROM `bookings_with_watermark` b
JOIN `hotel_with_watermark` h ON h.`hotel_id` = b.`hotel_id`;
-- Result: 432 (all match)

-- Temporal join (respects time)
SELECT COUNT(*)
FROM `bookings_with_watermark` b
JOIN `hotel_with_watermark` FOR SYSTEM_TIME AS OF b.`event_time` AS h
  ON h.`hotel_id` = b.`hotel_id`;
-- Result: 149 (many fail)

-- Step 2: Check dimension timestamp range
SELECT MIN(`updated_at`), MAX(`updated_at`) FROM `hotel_with_watermark`;
-- If MAX is recent (from streaming updates), that's the issue

-- Step 3: Check how many facts fall outside dimension range
SELECT COUNT(*)
FROM `bookings_with_watermark`
WHERE `event_time` < (SELECT MIN(`updated_at`) FROM `hotel_with_watermark`);
```

#### Solutions

| Option | Pros | Cons | When to Use |
|--------|------|------|-------------|
| **1. Don't update the watermark field** | Preserves temporal join compatibility | Doesn't reflect true update time | When you need point-in-time lookups |
| **2. Use regular joins** | Simple, all records match | Not point-in-time accurate | When current dimension state is acceptable |
| **3. Separate temporal table** | Clean separation of concerns | More tables to manage | When you need both use cases |
| **4. Remove dimension compaction** | Preserves all versions | Unbounded Kafka storage | When storage isn't a concern |

#### Option 1: Streaming Updates Without Changing `updated_at`

If your streaming updates change operational fields (like `available_rooms`) but NOT the versioning field (`updated_at`), the temporal join continues to work:

```json
// hotel_generator_streaming.json
{
    "row": {
        // ❌ Don't include: "updated_at": { "_gen": "now" }
        // ✅ Only include operational fields:
        "available_rooms": {
            "_gen": "math",
            "expr": "room_capacity * low_occupancy_rate"
        }
    }
}
```

**Caveat**: This means `updated_at` doesn't truly reflect when the record was last modified.

#### Option 2: Use Regular Joins Instead of Temporal

If point-in-time accuracy isn't critical, use regular joins:

```sql
-- Before: Temporal join (point-in-time lookup)
JOIN `hotel_with_watermark` FOR SYSTEM_TIME AS OF b.`event_time` AS h
  ON h.`hotel_id` = b.`hotel_id`

-- After: Regular join (current state lookup)
JOIN `hotel_with_watermark` h
  ON h.`hotel_id` = b.`hotel_id`
```

This always returns the **current** hotel state, regardless of when the booking was made.

#### Key Takeaway

Temporal joins work best when dimensions are **immutable** or **rarely updated**. If your dimension tables receive frequent streaming updates that change the watermark field, consider whether temporal joins are the right pattern for your use case.
