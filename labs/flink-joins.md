# Flink Streaming Joins with CDC Sources: A Journey of Discovery

## 🎯 Overview

This document chronicles our journey in solving complex streaming join challenges when working with PostgreSQL CDC sources in Confluent Cloud Flink. What started as a straightforward temporal join implementation evolved into a comprehensive exploration of streaming join patterns, revealing important insights about CDC compatibility and optimal strategies for real-time data processing.

## 📖 The Journey: From Problem to Solution

### 🚨 **Chapter 1: The Initial Challenge**

**The Goal**: Create a denormalized view by joining streaming bookings with customer and hotel dimension data from PostgreSQL CDC sources.

**The Expectation**: Use temporal joins (`FOR SYSTEM_TIME AS OF`) for proper versioned table semantics.

**The Reality**: Immediate failure with primary key detection errors.

**Error Encountered**:
```text
Temporal Table Join requires primary key in versioned table, but no primary key can be found.
```

### 🔍 **Chapter 2: The Investigation**

Our systematic investigation revealed all the "usual suspects" were correctly configured:

#### ✅ **Infrastructure Validation**

**PostgreSQL Database Primary Keys**: Perfect
- **customer table**: Primary key on `email` column ✅
- **hotel table**: Primary key on `hotel_id` column ✅

```sql
-- Confirmed proper primary key constraints
\d public.customer;  -- email: NOT NULL VARCHAR(255)
\d public.hotel;     -- hotel_id: NOT NULL VARCHAR(50)
```

**Kafka Topic Configuration**: Perfect
- **`riverhotel.CDC.customer`**: `cleanup.policy=compact` ✅
- **`riverhotel.CDC.hotel`**: `cleanup.policy=compact` ✅

**PostgreSQL CDC Connector (Debezium)**: Working Correctly
- Primary key metadata successfully captured (evidenced by `DISTRIBUTED BY HASH`)
- CDC operations flowing properly to Kafka topics

### 🧪 **Chapter 3: The Experimentation Phase**

With infrastructure confirmed correct, we embarked on extensive testing to understand the fundamental compatibility issues.

#### 🧪 **Experiment 1: Temporal Joins with Primary Key Declaration**

**Hypothesis**: Maybe Flink needs explicit primary key declaration even when connector captures metadata.

```sql
-- Attempt: Declare primary keys explicitly
ALTER TABLE `riverhotel.CDC.customer` ADD PRIMARY KEY (`email`) NOT ENFORCED;
ALTER TABLE `riverhotel.CDC.hotel` ADD PRIMARY KEY (`hotel_id`) NOT ENFORCED;

-- Test temporal join
SELECT ... FROM `bookings` b
JOIN `riverhotel.CDC.customer` FOR SYSTEM_TIME AS OF b.`$rowtime` AS c
  ON c.`email` = b.`customer_email`
LIMIT 5;
```

**Result**: Query executed successfully but returned **ZERO rows** 🚫

**Learning**: Temporal joins accept the syntax but fail to return expected results with CDC sources.

#### 🧪 **Experiment 2: Temporal Joins with Time Buffers**

**Hypothesis**: CDC timing issues might require time buffers to account for processing delays.

```sql
-- Attempt: Add time buffer for CDC processing
SELECT ... FROM `bookings` b
JOIN `riverhotel.CDC.customer` FOR SYSTEM_TIME AS OF (b.`$rowtime` + INTERVAL '5' MINUTE) AS c
  ON c.`email` = b.`customer_email`
```

**Result**: **Syntax Error** 🚫
```text
Error: "Temporal table join currently only supports 'FOR SYSTEM_TIME AS OF' left table's time attribute field"
```

**Learning**: Flink temporal joins are rigid - no expressions allowed in time specification.

#### 🧪 **Experiment 3: Current Timestamp Fallback**

**Hypothesis**: Use current timestamp to get latest CDC state.

```sql
-- Attempt: Use current data state
SELECT ... FROM `bookings` b
JOIN `riverhotel.CDC.customer` FOR SYSTEM_TIME AS OF CURRENT_TIMESTAMP AS c
  ON c.`email` = b.`customer_email`
```

**Result**: **Internal Error** 🚫
```text
Error: "Internal error occurred"
```

**Learning**: Even fallback approaches cause system failures in this environment.

#### ✅ **Experiment 4: Regular Join Sanity Check**

**Hypothesis**: Verify the data actually exists and can be joined.

```sql
-- Sanity check: Regular join without temporal semantics
SELECT ... FROM `bookings` b
JOIN `riverhotel.CDC.customer` c ON c.`email` = b.`customer_email`
LIMIT 10;
```

**Result**: **Multiple rows returned successfully** ✅

**Learning**: Data exists, keys match, regular joins work perfectly - the issue is specifically with temporal join mechanics.

### 💡 **Chapter 4: The Breakthrough Discovery**

After extensive experimentation, we discovered the fundamental issue wasn't configuration but **stream semantics compatibility**.

#### 🔍 **The Core Insight: CDC Stream Types vs Join Requirements**

**The Revelation**: Different Flink join types have different stream compatibility requirements:

| Join Type | Input Stream Support | Primary Key Requirement | Time Window Support |
|-----------|---------------------|------------------------|-------------------|
| **Temporal Joins** | ✅ CDC Changelog | ✅ Explicit declaration required | ❌ Fixed point-in-time |
| **Interval Joins** | ❌ Append-only ONLY | ❌ Not required | ✅ Flexible time windows |
| **Regular Joins** | ✅ CDC Changelog | ❌ Not required | ❌ Unbounded state |

**The Problem**: CDC sources produce **changelog streams** (`INSERT`, `UPDATE_BEFORE`, `UPDATE_AFTER`, `DELETE`), but:
- **Temporal joins** in this environment have versioned table state issues
- **Interval joins** explicitly reject changelog streams
- **Regular joins** create unbounded state (not suitable for production)

**Error Proof**:
```text
StreamPhysicalIntervalJoin doesn't support consuming update and delete changes
```

#### 🧪 **Experiment 5: Interval Joins with CDC (The Failure)**

**Attempt**: Try interval joins directly with CDC sources for time-windowed joining.

```sql
-- This FAILS with CDC sources
SELECT ... FROM `bookings` b
JOIN `riverhotel.CDC.customer` c
  ON c.`email` = b.`customer_email`
  AND c.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '1' DAY AND b.`$rowtime` + INTERVAL '1' DAY
```

**Result**: **Error** 🚫
```text
StreamPhysicalIntervalJoin doesn't support consuming update and delete changes
```

**Learning**: Interval joins provide time windows we need but reject CDC changelog streams.

### 🚀 **Chapter 5: The Solution Evolution**

#### **Breakthrough Idea**: Convert CDC Changelog → Append-Only Snapshots

**The Strategy**: Create snapshot tables that capture the current state from CDC sources in append-only format, then use interval joins on those snapshots.

**Why This Works**:
- ✅ **Converts changelog → append-only** for interval join compatibility
- ✅ **Captures current state** sufficient for most analytical use cases
- ✅ **Enables time windows** through interval joins
- ✅ **Bounded state management** prevents memory issues
- ✅ **Handles CDC timing** gracefully with configurable time windows

#### 🧪 **Experiment 6: Snapshot Tables + Interval Joins (The Success)**

**Implementation**: Create append-only snapshots from CDC sources, then use interval joins.

**Step 1**: Create snapshot tables
```sql
-- Create append-only customer snapshot
CREATE TABLE CUSTOMER_SNAPSHOT AS (
SELECT customer_id, email, first_name, last_name, birth_date, created_at
FROM `riverhotel.CDC.customer`
);

-- Force append-only mode (overrides inherited CDC changelog mode)
ALTER TABLE CUSTOMER_SNAPSHOT SET ('changelog.mode' = 'append');
```

**Step 2**: Test interval joins with snapshots
```sql
-- This WORKS: Snapshots are append-only compatible
SELECT ... FROM `bookings` b
JOIN `CUSTOMER_SNAPSHOT` c
  ON c.`email` = b.`customer_email`
  AND c.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
LIMIT 10;
```

**Result**: **Success! Multiple rows returned** ✅

**Key Discovery**: The `ALTER TABLE ... SET ('changelog.mode' = 'append')` was crucial because snapshot tables inherit changelog semantics from CDC sources.

## 🎯 **Chapter 6: The Final Solution**

Our journey led to a sophisticated **hybrid timestamp strategy** that combines the best of both processing-time and business-time semantics:

### **The Hybrid Approach**: Different Timestamps for Different Join Types

```sql
-- ✅ SOLUTION: Use $rowtime for dimensions, created_at for events
FROM `bookings` b
   -- Use $rowtime for dimension joins (data availability)
   JOIN `CUSTOMER_SNAPSHOT` c
     ON c.`email` = b.`customer_email`
     AND c.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
   JOIN `HOTEL_SNAPSHOT` h
     ON h.`hotel_id` = b.`hotel_id`
     AND h.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
   -- Use created_at for business logic joins (realistic timing)
   LEFT JOIN `hotel_reviews` hr
     ON hr.`booking_id` = b.`booking_id`
     AND to_timestamp_ltz(hr.`created_at`, 3) BETWEEN
         to_timestamp_ltz(b.`created_at`, 3) AND
         to_timestamp_ltz(b.`created_at`, 3) + INTERVAL '90' DAY
```

### **Why This Hybrid Strategy Works**

#### **`$rowtime` for Dimensions** (Customer/Hotel Data)
- **Purpose**: Ensures dimension data was available when booking was processed
- **Window**: Short (7 days) - dimensions change infrequently
- **Semantics**: "Find customer/hotel data as it existed around processing time"
- **Handles**: CDC processing delays and ordering issues

#### **`created_at` for Events** (Reviews)
- **Purpose**: Reflects realistic business timing relationships
- **Window**: Longer (90 days) - events can happen over extended periods
- **Semantics**: "Find reviews created within 90 days after booking was made"
- **Handles**: Business logic requirements and user behavior patterns

### **Results Comparison**

| Approach | Records Returned | Why |
|----------|------------------|-----|
| **All `$rowtime`** | 100 records | Artificial filtering based on processing order |
| **All `CREATED_AT`** | Varies | May miss dimension data due to processing delays |
| **Hybrid Strategy** | **420 records** | ✅ All bookings with proper review timing |

```sql
-- Step 1: Create snapshot tables from CDC sources
CREATE TABLE CUSTOMER_SNAPSHOT AS (
SELECT customer_id, email, first_name, last_name, birth_date, created_at
FROM `riverhotel.CDC.customer`
);
ALTER TABLE CUSTOMER_SNAPSHOT SET ('changelog.mode' = 'append');

CREATE TABLE HOTEL_SNAPSHOT AS (
SELECT hotel_id, name, category, description, city, country, room_capacity, created_at
FROM `riverhotel.CDC.hotel`
);
ALTER TABLE HOTEL_SNAPSHOT SET ('changelog.mode' = 'append');

-- Step 2: Create denormalized view with hybrid timestamp strategy
SET 'client.statement-name' = 'denormalized-hotel-bookings';
CREATE TABLE DENORMALIZED_HOTEL_BOOKINGS AS (
SELECT
  h.`name` AS `HOTEL_NAME`,
  h.`description` AS `HOTEL_DESCRIPTION`,
  h.`category` AS `HOTEL_CATEGORY`,
  h.`city` AS `HOTEL_CITY`,
  h.`country` AS `HOTEL_COUNTRY`,
  b.`price` AS `BOOKING_AMOUNT`,
  b.`occupants` AS `GUEST_COUNT`,
  to_timestamp_ltz(b.`created_at`, 3) AS `BOOKING_DATE`,
  to_timestamp_ltz(b.`check_in`, 3) AS `CHECK_IN`,
  to_timestamp_ltz(b.`check_out`, 3) AS `CHECK_OUT`,
  c.`email` AS `CUSTOMER_EMAIL`,
  c.`first_name` AS `CUSTOMER_FIRST_NAME`,
  hr.`review_rating` AS `REVIEW_RATING`,
  hr.`review_text` AS `REVIEW_TEXT`,
  to_timestamp_ltz(hr.`created_at`, 3) AS `REVIEW_DATE`,
  b.`booking_id` AS `BOOKING_ID`,
  h.`hotel_id` AS `HOTEL_ID`
FROM `bookings` b
   -- $rowtime for dimension joins (data availability)
   JOIN `CUSTOMER_SNAPSHOT` c
     ON c.`email` = b.`customer_email`
     AND c.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
   JOIN `HOTEL_SNAPSHOT` h
     ON h.`hotel_id` = b.`hotel_id`
     AND h.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
   -- created_at for business logic joins (realistic timing)
   LEFT JOIN `hotel_reviews` hr
     ON hr.`booking_id` = b.`booking_id`
     AND to_timestamp_ltz(hr.`created_at`, 3) BETWEEN
         to_timestamp_ltz(b.`created_at`, 3) AND
         to_timestamp_ltz(b.`created_at`, 3) + INTERVAL '90' DAY
);
```

## 📚 **Chapter 7: Key Learnings and Insights**

Our journey revealed several crucial insights about streaming joins with CDC sources:

### **🔍 Technical Discoveries**

#### **1. Stream Semantics Matter More Than Configuration**
- ✅ **Infrastructure was perfect**: PostgreSQL PKs, Kafka compaction, connector metadata
- ❌ **Stream compatibility was the issue**: CDC changelog vs join requirements
- 💡 **Lesson**: Focus on stream semantics, not just configuration

#### **2. Join Type Selection is Critical**
```sql
-- ❌ Temporal joins: Theoretically correct but practically unreliable
FOR SYSTEM_TIME AS OF b.$rowtime

-- ❌ Regular joins: Unbounded state, memory issues
JOIN table ON condition

-- ✅ Interval joins + snapshots: Bounded state, reliable, flexible
JOIN snapshot ON condition AND time_window_condition
```

#### **3. Changelog Mode Inheritance**
- **Discovery**: `CREATE TABLE AS SELECT` from CDC sources inherits changelog semantics
- **Solution**: Explicit `ALTER TABLE ... SET ('changelog.mode' = 'append')`
- **Impact**: Critical for interval join compatibility

#### **4. Hybrid Timestamp Strategies**
- **Processing time** (`$rowtime`): Data availability guarantees
- **Business time** (`CREATED_AT`): Realistic business logic
- **Hybrid approach**: Combines both for optimal results

### **🎯 Practical Recommendations**

#### **For Workshop/Educational Contexts**
- ✅ **Use snapshot + interval joins**: Reliable, educational value high
- ✅ **Focus on business outcomes**: Don't get stuck on theoretical perfection
- ✅ **Document journey**: Troubleshooting becomes learning opportunity

#### **For Production Systems**
- ✅ **Start with snapshot approach**: Proven reliable with CDC sources
- 🟡 **Consider temporal joins**: Test thoroughly in your specific environment
- ✅ **Monitor performance**: Validate time window sizes for your data patterns

#### **For Complex Join Scenarios**
- ✅ **Use hybrid timestamp strategies**: Processing time + business time
- ✅ **Size windows appropriately**: Dimensions (hours/days), events (days/months)
- ✅ **Test with realistic data volumes**: Performance varies significantly

## 🎯 **Chapter 8: Final Recommendations by Use Case**

### **📚 Educational/Workshop Context**
```sql
-- RECOMMENDED: Snapshot + interval joins
CREATE TABLE SNAPSHOT AS (SELECT ... FROM CDC_SOURCE);
ALTER TABLE SNAPSHOT SET ('changelog.mode' = 'append');
-- Then use interval joins with appropriate time windows
```
**Why**: Reliable, teaches important streaming concepts, always works

### **🏭 Production Context**
```sql
-- OPTION 1: Snapshot approach (most reliable)
-- Same as above but with production-tuned time windows

-- OPTION 2: Temporal joins (test first)
ALTER TABLE CDC_SOURCE ADD PRIMARY KEY (...) NOT ENFORCED;
-- Then test thoroughly with your data patterns
```
**Why**: Balance reliability with real-time requirements

### **🔬 Research/Experimentation Context**
- Try temporal joins first
- Fall back to snapshots if issues arise
- Document compatibility findings for your environment

---

## 📊 **Summary: Our Journey in Numbers**

| Approach Tested | Success Rate | Records Returned | Learning Value |
|----------------|--------------|------------------|----------------|
| **Temporal Joins** | ❌ 0% | 0 records | High (what doesn't work) |
| **Direct CDC + Interval** | ❌ 0% | Error | High (stream compatibility) |
| **Snapshot + Interval** | ✅ 100% | 420 records | Very High (working solution) |
| **Hybrid Timestamps** | ✅ 100% | 420 records | Very High (production ready) |

**Final Status**: ✅ **Solved** via snapshot tables + interval joins with hybrid timestamp strategy
**Impact**: Workshop continues successfully with reliable, production-ready CDC integration
**Documentation**: Comprehensive troubleshooting guide created for future participants

---

## 🔧 **Appendix: Advanced Techniques**

### **A1: Changelog Mode Inheritance**

**Key Discovery**: Snapshot tables inherit CDC changelog semantics and must be explicitly converted:

```sql
-- ❌ This inherits changelog.mode = 'upsert' from CDC source
CREATE TABLE CUSTOMER_SNAPSHOT AS (SELECT ... FROM CDC_SOURCE);

-- ✅ Must explicitly set append mode for interval join compatibility
ALTER TABLE CUSTOMER_SNAPSHOT SET ('changelog.mode' = 'append');
```

### **A2: Alternative Approaches Tested**

| Approach | Result | Learning |
|----------|--------|----------|
| **Temporal + PK Declaration** | ❌ 0 rows | Syntax works, no results |
| **Temporal + Time Buffer** | ❌ Syntax Error | Expressions not supported |
| **Temporal + CURRENT_TIMESTAMP** | ❌ Internal Error | System incompatibility |
| **Regular Joins** | ✅ Works | Confirms data exists |
| **Snapshot + Interval** | ✅ 420 rows | Production solution |

### **A3: Schema Definition Approaches for Nullable Columns**

### Problem Context

When creating aggregate tables in Flink SQL, you may encounter primary key errors due to nullable columns:

> Invalid primary key 'PK_HOTEL_ID_HOTEL_NAME_HOTEL_CITY_HOTEL_COUNTRY_HOTEL_DESCRIPTION'.
> Column 'HOTEL_NAME' is nullable.

This occurs because Flink auto-infers primary keys from `GROUP BY` columns, but cannot create primary keys from nullable columns.

### Approach 1: COALESCE (Recommended for Workshops)

**Quick null handling in aggregation queries:**

```sql
CREATE TABLE AGGREGATE_HOTEL_REVIEWS AS (
   SELECT
      COALESCE(HOTEL_ID, 'UNKNOWN_HOTEL') AS HOTEL_ID,
      COALESCE(HOTEL_NAME, 'UNKNOWN_NAME') AS HOTEL_NAME,
      COALESCE(HOTEL_CITY, 'UNKNOWN_CITY') AS HOTEL_CITY,
      COALESCE(HOTEL_COUNTRY, 'UNKNOWN_COUNTRY') AS HOTEL_COUNTRY,
      COALESCE(HOTEL_DESCRIPTION, 'NO_DESCRIPTION') AS HOTEL_DESCRIPTION,
      AVG(REVIEW_RATING) AS AVERAGE_REVIEW_RATING,
      COUNT(REVIEW_RATING) AS REVIEW_COUNT,
      ARRAY_JOIN(ARRAY_AGG(REVIEW_TEXT), '||| ') AS HOTEL_REVIEWS
   FROM DENORMALIZED_HOTEL_BOOKINGS
   GROUP BY COALESCE(HOTEL_ID, 'UNKNOWN_HOTEL'),
      COALESCE(HOTEL_NAME, 'UNKNOWN_NAME'),
      COALESCE(HOTEL_CITY, 'UNKNOWN_CITY'),
      COALESCE(HOTEL_COUNTRY, 'UNKNOWN_COUNTRY'),
      COALESCE(HOTEL_DESCRIPTION, 'NO_DESCRIPTION')
);
```

✅ **Benefits**: Simple, works with any schema, immediate implementation
❌ **Drawbacks**: Verbose, runtime overhead

### Approach 2: Explicit Schema Definition (Production)

**Define table structure before inserting data:**

```sql
-- Step 1: Define exact schema with constraints
CREATE TABLE DENORMALIZED_HOTEL_BOOKINGS (
  HOTEL_NAME VARCHAR NOT NULL,           -- Explicitly non-nullable
  HOTEL_DESCRIPTION VARCHAR NOT NULL,    -- Explicitly non-nullable
  HOTEL_CLASS VARCHAR,                   -- Nullable (optional)
  HOTEL_CITY VARCHAR NOT NULL,           -- Explicitly non-nullable
  HOTEL_COUNTRY VARCHAR NOT NULL,        -- Explicitly non-nullable
  BOOKING_AMOUNT DECIMAL(10,2),
  GUEST_COUNT INT,
  BOOKING_DATE TIMESTAMP(3),
  CHECK_IN TIMESTAMP(3),
  CHECK_OUT TIMESTAMP(3),
  CUSTOMER_EMAIL VARCHAR,
  CUSTOMER_FIRST_NAME VARCHAR,
  REVIEW_RATING INT,
  REVIEW_TEXT STRING,
  REVIEW_DATE TIMESTAMP(3),
  BOOKING_ID VARCHAR NOT NULL,
  HOTEL_ID VARCHAR NOT NULL,
  PRIMARY KEY (BOOKING_ID, HOTEL_ID) NOT ENFORCED  -- Explicit PK
);

-- Step 2: Insert data with COALESCE to meet NOT NULL constraints
INSERT INTO DENORMALIZED_HOTEL_BOOKINGS
SELECT
  COALESCE(h.NAME, 'UNKNOWN_NAME') AS HOTEL_NAME,     -- Converts nulls to defaults
  COALESCE(h.DESCRIPTION, 'NO_DESCRIPTION') AS HOTEL_DESCRIPTION,
  h.CLASS AS HOTEL_CLASS,                             -- Allows nulls
  COALESCE(h.CITY, 'UNKNOWN_CITY') AS HOTEL_CITY,
  COALESCE(h.COUNTRY, 'UNKNOWN_COUNTRY') AS HOTEL_COUNTRY,
  b.PRICE AS BOOKING_AMOUNT,
  b.OCCUPANTS AS GUEST_COUNT,
  to_timestamp_ltz(b.CREATED_AT, 3) AS BOOKING_DATE,
  to_timestamp_ltz(b.CHECK_IN, 3) AS CHECK_IN,
  to_timestamp_ltz(b.CHECK_OUT, 3) AS CHECK_OUT,
  c.EMAIL AS CUSTOMER_EMAIL,
  c.FIRST_NAME AS CUSTOMER_FIRST_NAME,
  hr.REVIEW_RATING,
  hr.REVIEW_TEXT,
  to_timestamp_ltz(hr.CREATED_AT, 3) AS REVIEW_DATE,
  b.BOOKING_ID,
  h.HOTEL_ID
FROM bookings b
  JOIN CUSTOMER_SNAPSHOT c
    ON c.EMAIL = b.CUSTOMER_EMAIL
    AND c.$rowtime BETWEEN b.$rowtime - INTERVAL '1' DAY AND b.$rowtime + INTERVAL '1' DAY
  JOIN HOTEL_SNAPSHOT h
    ON h.HOTEL_ID = b.HOTEL_ID
    AND h.$rowtime BETWEEN b.$rowtime - INTERVAL '1' DAY AND b.$rowtime + INTERVAL '1' DAY
  LEFT JOIN hotel_reviews hr
    ON hr.BOOKING_ID = b.BOOKING_ID
    AND hr.$rowtime BETWEEN b.$rowtime AND b.$rowtime + INTERVAL '90' DAY;

-- Step 3: Subsequent aggregates work without COALESCE
CREATE TABLE AGGREGATE_HOTEL_REVIEWS AS (
   SELECT
      HOTEL_ID,                           -- No COALESCE needed!
      HOTEL_NAME,                         -- No COALESCE needed!
      HOTEL_CITY,                         -- No COALESCE needed!
      HOTEL_COUNTRY,                      -- No COALESCE needed!
      HOTEL_DESCRIPTION,                  -- No COALESCE needed!
      AVG(REVIEW_RATING) AS AVERAGE_REVIEW_RATING,
      COUNT(REVIEW_RATING) AS REVIEW_COUNT,
      ARRAY_JOIN(ARRAY_AGG(REVIEW_TEXT), '||| ') AS HOTEL_REVIEWS
   FROM DENORMALIZED_HOTEL_BOOKINGS
   GROUP BY HOTEL_ID, HOTEL_NAME, HOTEL_CITY, HOTEL_COUNTRY, HOTEL_DESCRIPTION
);
```

✅ **Benefits**:

- **Explicit schema control**: Full control over column types and nullability
- **No COALESCE needed in aggregates**: Subsequent GROUP BY queries work without null handling
- **Clear data contracts**: Schema explicitly documents expected data structure
- **Production ready**: Better for production environments with strict data governance

❌ **Drawbacks**: More initial setup required

### Approach 3: Source Table Constraints

**Modify source snapshot tables to enforce NOT NULL:**

```sql
-- After creating HOTEL_SNAPSHOT, add constraints
ALTER TABLE HOTEL_SNAPSHOT MODIFY (
  HOTEL_ID VARCHAR NOT NULL,
  NAME VARCHAR NOT NULL,
  CITY VARCHAR NOT NULL,
  COUNTRY VARCHAR NOT NULL,
  DESCRIPTION VARCHAR NOT NULL
);

-- After creating CUSTOMER_SNAPSHOT, add constraints
ALTER TABLE CUSTOMER_SNAPSHOT MODIFY (
  EMAIL VARCHAR NOT NULL,
  FIRST_NAME VARCHAR NOT NULL
);
```

This ensures that joined results inherit the NOT NULL constraints.

✅ **Benefits**: Upstream data quality enforcement
❌ **Drawbacks**: May fail if actual nulls exist in source data

### 📋 When to Use Each Approach

| Approach | Best For | Pros | Cons |
|----------|----------|------|------|
| **COALESCE** | Quick fixes, prototyping, workshops | Simple, works with any schema | Verbose, runtime overhead |
| **Explicit Schema** | Production, strict governance | Clean aggregates, clear contracts | More initial setup |
| **Source Constraints** | When you control source data | Upstream data quality | May fail if actual nulls exist |

### 🎯 How Flink Determines Nullability

Flink determines source field nullability through multiple mechanisms:

#### 1. Source Connector Metadata

```sql
-- PostgreSQL table definition
CREATE TABLE hotel (
  hotel_id VARCHAR(50) NOT NULL PRIMARY KEY,
  name VARCHAR(255),                     -- No NOT NULL constraint
  city VARCHAR(100) NOT NULL
);
```

Flink inherits:

- `hotel_id`: NOT NULL ✅
- `name`: **NULLABLE** ❌ (because PostgreSQL allows NULL)
- `city`: NOT NULL ✅

#### 2. CDC Stream Characteristics

Even if PostgreSQL column is NOT NULL, CDC can introduce nullability:

```sql
UPDATE hotel SET name = NULL WHERE hotel_id = 'H123';  -- Now name is null
```

CDC streams carry these operations, so Flink **conservatively assumes nullable** for CDC sources.

#### 3. Conservative Default

When in doubt, **Flink defaults to nullable** for safety:

- Better to allow nulls when not needed
- Than to reject valid null data

### 💡 Recommendation

- **For workshops/prototyping**: Use COALESCE approach for immediate results
- **For production environments**: Use explicit schema definition for clean, maintainable code
- **For source-controlled data**: Consider source table constraints

---

### **A4: Hybrid Timestamp Strategy for Complex Joins**

### Problem: When to Use `$rowtime` vs `CREATED_AT`

In complex joins involving both **dimension data** (customers, hotels) and **event data** (reviews), choosing the right timestamp strategy is crucial:

### ✅ **Recommended Hybrid Approach**

```sql
FROM `bookings` b
   -- Use $rowtime for dimension joins (data availability)
   JOIN `CUSTOMER_SNAPSHOT` c
     ON c.`email` = b.`customer_email`
     AND c.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
   JOIN `HOTEL_SNAPSHOT` h
     ON h.`hotel_id` = b.`hotel_id`
     AND h.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
   -- Use created_at for business logic joins (realistic timing)
   LEFT JOIN `hotel_reviews` hr
     ON hr.`booking_id` = b.`booking_id`
     AND to_timestamp_ltz(hr.`created_at`, 3) BETWEEN
         to_timestamp_ltz(b.`created_at`, 3) AND
         to_timestamp_ltz(b.`created_at`, 3) + INTERVAL '90' DAY
```

### 🔍 **Why This Works**

#### **`$rowtime` for Dimensions**

- **Purpose**: Ensures dimension data was available when booking was processed
- **Window**: Short (7 days) - dimensions change infrequently
- **Semantics**: "Find customer/hotel data as it existed around processing time"

#### **`created_at` for Events**

- **Purpose**: Reflects realistic business timing relationships
- **Window**: Longer (90 days) - events can happen over extended periods
- **Semantics**: "Find reviews created within 90 days after booking was made"

### 📊 **Results Comparison**

| Approach | Records Returned | Explanation |
|----------|------------------|-------------|
| **All `$rowtime`** | 100 records | Artificial filtering based on processing order |
| **All `CREATED_AT`** | Varies | May miss dimension data due to processing delays |
| **Hybrid Strategy** | **420 records** | ✅ All bookings with proper review timing |

### 💡 **Best Practice**

Use **hybrid timestamp strategies** when:

- ✅ Joining stable dimension data (customers, products, locations)
- ✅ Joining time-sensitive event data (reviews, transactions, clicks)
- ✅ You need both processing-time and business-time semantics
- ✅ Complex multi-table joins with different timing requirements
