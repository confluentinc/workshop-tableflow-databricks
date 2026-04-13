# Optional Lab: Data Governance & Data Quality Rules

## Overview

In this lab, you'll explore how **data governance and data quality rules** work with Confluent Cloud. Your workshop environment has been pre-configured with a CEL-based data quality rule on the clickstream topic, and your instructor will demonstrate live DQR enforcement.

### What You'll Explore

- **Data Quality Rules (DQR)**: Observe a live CEL validation rule and its Dead Letter Queue
- **Live DQR Demo**: Watch your instructor trigger rule enforcement in real-time
- **Governance Tags & Business Metadata**: Explore classification and ownership tools

### Prerequisites

- Completed [LAB 2](../LAB2_explore_environment/LAB2.md)

## Steps

### Step 1: Observe Pre-deployed Data Quality Rules

Your workshop environment was provisioned with a data contract on the `clickstream` topic. Let's examine it.

#### Navigate to Schema Registry

1. In your Confluent Cloud environment, click **Schema Registry** in the left menu
2. Find the `clickstream-value` subject and click on it

You'll see the Avro schema for clickstream events. This schema was registered by Terraform with a CEL data quality rule attached.

#### Examine the Data Quality Rule

1. Click on the **Rules** tab
2. You'll see a rule named **`validateClickstreamAction`**

   This rule enforces that the `action` field must be one of the valid values:

   ```
   message.action.matches('^(page-view|page-click|booking-click)$')
   ```

3. Note the **On failure** action is set to `DLQ`, routing invalid events to the `invalid_clickstream_events` topic

**How This Works:** The CEL (Common Expression Language) rule is evaluated at produce time by the `KafkaAvroSerializer`. The data generator produces directly to Kafka, and the serializer checks the rule before the message reaches the broker.

> **Note:** The data generator intentionally produces ~5% invalid `action` values (`admin-access`, `page-scroll`) in its streaming output. These are caught by the DQR and routed to the DLQ. The `/test-dqr` endpoint lets you trigger a controlled test with one valid and one invalid event.

### Step 2: Live DQR Demo

Your instructor will demonstrate data quality rule enforcement by triggering the `/test-dqr` endpoint on the data generator.

#### What Happens

The instructor SSHs to the EC2 instance running the data generator and runs:

```bash
curl localhost:9400/test-dqr
```

This produces two events directly to the `clickstream` topic:
1. **Valid event** (`action: "page-view"`) — passes the CEL rule, written to the main topic
2. **Invalid event** (`action: "admin-access"`) — fails the CEL rule, routed to `invalid_clickstream_events`

#### Observe the Results

1. Navigate to your workshop cluster > **Topics**
2. Click on `invalid_clickstream_events` > **Messages**
3. You should see the DLQ-routed event with `action: "admin-access"` and an `activity_id` starting with `DQR-TEST-`

**Key Insight:** The invalid event was never written to the main clickstream topic — it was intercepted by the serializer and redirected to the DLQ. In production, this prevents bad data from entering your analytics pipeline.

### Step 3: Explore Governance Tags

Let's look at additional governance capabilities.

#### Navigate to Catalog Management

1. Click on **Catalog Management** in the left menu

#### Create Governance Tags

Tags classify data streams so that policies can be applied consistently.

1. Click on the **Tags** tab
2. Click **Create tags**
3. Select these recommended tags:
   - *PII* - Personally Identifiable Information
   - *Private* - Internal business data
   - *Public* - Data safe for external sharing
4. Click **Yes, create recommended tags**

5. **Create a Custom Tag**:
   1. Click **+ Add Tag**
   2. Enter `KPI` as the tag name
   3. Description: `A designation for fields that River Hotel leadership have identified as drivers for Key Performance Indicator metrics`
   4. Click **Create**

#### Add Business Metadata

1. Click the **Business Metadata** tab
2. Click **Create business metadata**
3. Configure:
   - *Name:* `Stewardship`
   - *Description:* `Contact information for the steward of the corresponding data`
   - Add attributes: `First_Name`, `Last_Name`, `Email`
4. Click **Create**

**Why This Matters:** Tags and metadata connect technical schemas to business context. When combined with data quality rules, you get a complete governance framework: rules enforce quality, tags classify sensitivity, and metadata tracks ownership.

## Reflection

### What You Observed

**Schema-level Enforcement:** Data quality rules are embedded in the schema itself, not as a separate layer. This means any producer using the schema automatically gets validation — there's no way to bypass it.

**DLQ Pattern:** Invalid data isn't lost — it's redirected. Teams can monitor the `invalid_clickstream_events` topic to identify upstream data quality issues, fix the source, and optionally replay corrected events.

**Governance as Code:** The rules and schemas were deployed by Terraform alongside the rest of your infrastructure. This means governance travels with the data platform — it's version-controlled, reviewable, and reproducible.

## What's Next

Return to the main workshop flow:

- [LAB 2: Explore Environment](../LAB2_explore_environment/LAB2.md)
- [LAB 3: Stream Processing](../LAB3_stream_processing/LAB3.md)
