# LAB 5: Stream Lineage

## Overview

You have built stream processing with Flink SQL and enabled Tableflow on key topics. **Stream Lineage** in Confluent Cloud visualizes how data moves through your cluster—from sources and topics through Flink jobs to consumers—so you can trust what you built and reason about impact when something changes.

### What You'll Accomplish

By the end of this lab, you will have:

1. **Understood Stream Lineage**: Learned what the graph shows, how it relates to governance and observability, and why it matters for River Hotels’ customer and booking data
2. **Navigated the UI**: Opened Stream Lineage from your cluster and used the graph, time window, and search
3. **Mapped the workshop pipeline**: Identified CDC dimension topics, direct-to-Kafka event topics, Flink query nodes, derived topics, and Tableflow-related flows
4. **Practiced dependency thinking**: Traced upstream sources for a data product, considered blast radius if a source fails, and exported the diagram for documentation

### Prerequisites

- Completed **[LAB 4: Tableflow](../LAB4_tableflow/LAB4.md)** with Tableflow enabled on `clickstream`, `denormalized_hotel_bookings`, and `reviews_with_sentiment`

## Steps

### Step 1: What is Stream Lineage?

[Stream Lineage](https://docs.confluent.io/cloud/current/stream-governance/stream-lineage.html) is a graphical view of **data in motion** on your Kafka cluster. It shows:

- **Where data came from** (for example, your PostgreSQL CDC source connector)
- **Where it goes** (downstream topics, Flink processing, consumers such as Tableflow materialization)
- **What sits in between** (topics, Flink SQL statements named with `client.statement-name`)

The graph reflects **recent activity** (by default, roughly the last 10 minutes). That makes it a live operations and discovery tool, not a static architecture diagram.

For **River Hotels**, the pipeline spans sensitive operational data (bookings, customers, reviews). Teams need to answer:

- Which topics hold PII or review text, and what processes touch them?
- If we change a source or pause a connector, what Flink jobs or analytics tables are affected?
- How do we document the flow for compliance or onboarding?

Stream Lineage supports those questions with an explorable graph plus per-node metadata and throughput hints.

> [!NOTE]
> **Permissions**
>
> If you do not see **Stream Lineage** in the cluster menu, your account may lack the required role. Developer-only roles do not include Stream Lineage; an Operator (or broader) role at cluster scope is typically needed. See [Access control (RBAC) for Stream Lineage](https://docs.confluent.io/cloud/current/stream-governance/stream-lineage.html#access-control-rbac-for-stream-lineage) in the Confluent documentation.

### Step 2: Navigate to Stream Lineage

1. Open [your Confluent Cloud cluster](https://confluent.cloud/go/cluster)
2. Select your workshop environment and cluster
3. In the left menu, click **Stream Lineage**

Familiarize yourself with the canvas:

- **Nodes** represent topics, connectors, Flink queries, grouped producers/consumers, and other entities
- **Edges** show flow between nodes; thickness often reflects relative throughput in the selected time window
- **Hover** a node or edge for a quick summary (bytes, messages, or job/topic details)
- **Click** a node to open a drill-down panel (tabs such as Overview, Schema, or Query where applicable)
- Use the **time window** control if your UI offers extended windows (governance package dependent)—the default view is the last 10 minutes
- Use **Search** to jump to a topic or connector by name

You can also open lineage from a **topic** page (**See in Stream Lineage**) or a **connector** page—the global cluster view lists everything in one graph.

### Step 3: Explore the workshop pipeline

Work through the following in your lineage graph (names may include your environment prefix on the connector).

**Ingestion**

- Find the **PostgreSQL CDC** source connector (name pattern `*-postgres-cdc-source`). It produces to the `riverhotel.cdc.*` dimension topics.
- Confirm CDC dimension topics:
  - `riverhotel.cdc.customer`
  - `riverhotel.cdc.hotel`
- Confirm direct-to-Kafka event topics (produced by the Java data generator):
  - `bookings`
  - `clickstream`
  - `reviews`

**Stream processing (Flink)**

Your Flink statements used these `client.statement-name` values (they appear as query nodes when active):

| Statement name | Role |
|----------------|------|
| `denormalized-hotel-bookings` | Temporal joins from bookings + customer + hotel CDC topics into `denormalized_hotel_bookings` |
| `hotel-reviews-with-sentiment` | `AI_SENTIMENT` enrichment of reviews into `reviews_with_sentiment` |

Locate the **downstream Kafka topics** `denormalized_hotel_bookings` and `reviews_with_sentiment` and how they connect to those queries.

**Tableflow**

On topics where you enabled Tableflow (`clickstream`, `denormalized_hotel_bookings`, `reviews_with_sentiment`), look for **consumer** activity representing Tableflow materialization toward your object store and Unity Catalog. Exact labels can vary by UI version; the important exercise is tying **topic → Tableflow path** to what you configured in LAB 4.

**Try this**

1. Click `bookings` and review schema/partitions and throughput on the **Overview** (or equivalent) tab
2. Click the **denormalized-hotel-bookings** Flink node and confirm inputs and outputs
3. Hover several **edges** and read bytes/messages for the selected time window

### Step 4: Hands-on exercises

**Exercise 1 — Trace a data product**

Starting from the **`reviews_with_sentiment`** topic, trace **backward** through the graph. List the sequence of topics and Flink jobs from `reviews_with_sentiment` all the way to the CDC connector (and PostgreSQL as the ultimate source).

<details>
<summary>Click to reveal one possible answer</summary>

`reviews_with_sentiment` ← Flink `hotel-reviews-with-sentiment` ← `reviews` ← Java data generator

</details>

**Exercise 2 — Impact analysis**

Suppose the PostgreSQL CDC connector stops or errors. Using Stream Lineage, which **topics** and **Flink-related nodes** would lose fresh inputs or become stale first? Which **Tableflow-enabled topics** in this workshop ultimately depend on that connector (directly or through Flink)?

<details>
<summary>Click to reveal discussion points</summary>

- CDC dimension topics (`riverhotel.cdc.customer`, `riverhotel.cdc.hotel`) stop updating.
- The `denormalized-hotel-bookings` Flink job depends on these dimension tables for temporal joins — new bookings would fail to enrich with stale customer/hotel data.
- Direct-to-Kafka topics (`bookings`, `clickstream`, `reviews`) are unaffected since they come from the Java data generator, not CDC.
- Tableflow on `clickstream` and `reviews_with_sentiment` continues; `denormalized_hotel_bookings` degrades due to stale dimension data.

</details>

**Exercise 3 — Export the diagram**

Use the **Export** control on the lineage toolbar (lower-right area in the default layout) to save an image of the current graph. This is useful for runbooks, security reviews, or stakeholder decks.

## Conclusion

Stream Lineage gives you a **live map** of how River Hotels’ streaming data moves through Confluent Cloud—connectors, topics, Flink SQL, and consumers—so you can troubleshoot faster, communicate architecture clearly, and support governance questions about sensitive data. For feature details and RBAC, see the [Confluent documentation for Stream Lineage](https://docs.confluent.io/cloud/current/stream-governance/stream-lineage.html).

## What's Next

Continue to **[LAB 6: Analytics and AI-Powered Marketing](../LAB6_analytics_ai/LAB6.md)**.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
