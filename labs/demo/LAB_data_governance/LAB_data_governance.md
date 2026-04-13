# Optional Lab: Data Governance & Data Quality Rules

## Overview

Your demo environment (`aws-demo`) was deployed with a pre-configured data quality rule on the clickstream topic. This lab walks through observing the rule, demonstrating live enforcement via the `/test-dqr` endpoint, and exploring governance features.

Since demo mode is fully automated by Terraform, all rules and the DLQ topic are already deployed — this lab is observation and demonstration only.

### What You'll Explore

- **Pre-deployed DQR**: A CEL rule validating the `action` field on the clickstream schema
- **Live DQR Demo**: Trigger rule enforcement via the data generator's `/test-dqr` HTTP endpoint
- **DLQ Observation**: See invalid events routed to the `invalid_clickstream_events` topic

### Prerequisites

- Completed **[LAB 2: Deploy and Observe](../LAB2_deploy_and_observe/LAB2.md)** with infrastructure running

## Steps

### Step 1: Observe the Data Quality Rule

1. In Confluent Cloud, navigate to your workshop environment
2. Click **Schema Registry** in the left menu
3. Find the `clickstream-value` subject and click on it
4. Click on the **Rules** tab

You should see a rule named **`validateClickstreamAction`** with the expression:

```
message.action.matches('^(page-view|page-click|booking-click)$')
```

The **On failure** action is `DLQ`, routing invalid events to `invalid_clickstream_events`.

**What Terraform Deployed:** The `data_contracts` module registered this schema with the CEL rule and created the DLQ topic. This happened automatically during `terraform apply`, before the CDC connector and data generator started.

### Step 2: Demonstrate Live DQR Enforcement

SSH to the EC2 instance running the data generator and trigger the test endpoint:

```bash
curl localhost:9400/test-dqr
```

The response shows the outcome of two test events:

```json
{
  "test": "data-quality-rules",
  "topic": "clickstream",
  "events": [
    {"action":"page-view","label":"valid","destination":"clickstream","offset":12345},
    {"action":"admin-access","label":"invalid","destination":"DLQ","reason":"..."}
  ]
}
```

- The **valid** event (`page-view`) passes the CEL rule and is written to the main topic
- The **invalid** event (`admin-access`) fails the rule and is redirected to the DLQ

### Step 3: Verify in the Confluent Cloud UI

#### Check the DLQ Topic

1. Navigate to your workshop cluster > **Topics**
2. Click on `invalid_clickstream_events` > **Messages**
3. Find the DLQ-routed event with `activity_id` starting with `DQR-TEST-`

#### Check the Main Topic

1. Go back to **Topics** > `clickstream` > **Messages**
2. Find the valid test event (also with `DQR-TEST-` prefix and `action: "page-view"`)

> **Note:** The data generator intentionally produces ~5% invalid `action` values (`admin-access`, `page-scroll`) in its streaming output. These are caught by the DQR and routed to the DLQ. The `/test-dqr` endpoint lets you trigger a controlled test with one valid and one invalid event.

## Talking Points

When presenting this to an audience, emphasize:

1. **Governance as Code**: The data quality rule was deployed alongside the infrastructure — no manual UI steps required. It's version-controlled and reproducible.

2. **Producer-side Enforcement**: Rules are evaluated inside the `KafkaAvroSerializer` before the message reaches the broker. Bad data never enters the main topic.

3. **DLQ Pattern**: Invalid data isn't silently dropped — it's captured in a separate topic for investigation. Teams can fix the source and optionally replay corrected events.

4. **Controlled Testing**: The `/test-dqr` endpoint demonstrates enforcement with a single valid and invalid event pair, making it easy to show the DLQ routing behavior.

## What's Next

Return to the main demo flow:

- [LAB 2: Deploy and Observe](../LAB2_deploy_and_observe/LAB2.md)
- [LAB 3: Analytics and AI](../LAB3_analytics_ai/LAB3.md)
