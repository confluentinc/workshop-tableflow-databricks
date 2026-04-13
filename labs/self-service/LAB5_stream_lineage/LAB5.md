# LAB 5: Stream Lineage

## 🗺️ Overview

You finished Flink SQL and Tableflow setup in the previous lab. **Stream Lineage** in Confluent Cloud shows how data actually flows through your cluster—connectors, direct producers, topics, Flink jobs, and consumers—so you can validate the River Hotels pipeline and explain it to others.

### What You'll Accomplish

By the end of this lab, you will have:

1. **Understood Stream Lineage**: What the graph represents, how it supports governance and operations, and why it matters for booking and customer data
2. **Navigated the UI**: Opened Stream Lineage from your cluster and used search, time window, and drill-downs
3. **Mapped your workshop topology**: CDC to `riverhotel.cdc.*`, Java Datagen on `bookings` / `reviews` / `clickstream`, Flink snapshots and CTAS, and Tableflow-related flows
4. **Practiced exercises**: Traced `reviews_with_sentiment` upstream, reasoned about connector/producer failure impact, and exported the diagram

### Prerequisites

- Completed **[LAB 4: Stream Processing](../LAB4_stream_processing/LAB4.md)** with Flink tables created and Tableflow enabled on `clickstream`, `denormalized_hotel_bookings`, and `reviews_with_sentiment`

## 👣 Steps

### Step 1: What is Stream Lineage?

[Stream Lineage](https://docs.confluent.io/cloud/current/stream-governance/stream-lineage.html) is a **live, visual graph** of streaming data on your Kafka cluster. It helps answer:

- **Where did this data come from?** (CDC connector, Flink job, another topic)
- **Where is it going?** (Downstream topics, Flink, consumers like Tableflow)
- **What changed along the way?** (Inspect Flink query nodes and topic schemas)

The default view emphasizes **recent activity** (typically about the last 10 minutes), so it complements static architecture diagrams.

For **River Hotels**, you have both **database-sourced dimensions** (via PostgreSQL CDC) and **event streams** produced directly to Kafka (Java Datagen). Stream Lineage helps you see those paths side by side and trace **PII and reviews** through enrichment and into Tableflow/Databricks.

> [!NOTE]
> **Permissions**
>
> If **Stream Lineage** is missing from the cluster menu, your user may need a role with lineage access (for example Operator at cluster scope). Developer roles alone do not grant it. See [Access control (RBAC) for Stream Lineage](https://docs.confluent.io/cloud/current/stream-governance/stream-lineage.html#access-control-rbac-for-stream-lineage).

### Step 2: Navigate to Stream Lineage

1. Open [your Confluent Cloud cluster](https://confluent.cloud/go/cluster)
2. Select your workshop environment and cluster
3. Click **Stream Lineage** in the left sidebar

Explore the controls:

- **Nodes** — topics, connectors, Flink queries, grouped producers/consumers
- **Edges** — data flow; hover for throughput hints
- **Click** a node for tabs (Overview, Schema, Query, etc., depending on type)
- **Time window** — widen if your package supports it; search is scoped to the selected window
- **Search** — jump to a topic, connector, or query by partial name

You can also enter lineage from a **topic** (**See in Stream Lineage**) or **connector** page.

### Step 3: Explore the workshop pipeline

**Ingestion to look for**

- **PostgreSQL CDC** connector (name like `*-postgres-cdc-source`) → `riverhotel.cdc.*` topics
- **Producers** (or application nodes) feeding **`bookings`**, **`reviews`**, and **`clickstream`** — these are your direct Kafka event streams

**Flink**

You used statement names such as:

| `client.statement-name` | Output topic (typical) |
|-------------------------|-------------------------|
| `denormalized-hotel-bookings` | `denormalized_hotel_bookings` |
| `hotel-reviews-with-sentiment` | `reviews_with_sentiment` |


**Tableflow**

Confirm flows from:

- `clickstream` (enabled in LAB 4)
- `denormalized_hotel_bookings` and `reviews_with_sentiment` (enabled in LAB 4)

toward Tableflow materialization and your Unity Catalog integration.

**Try this**

1. Search for **`bookings`** in the lineage graph and trace how it enters from the Java data generator producer node
2. Open the **`denormalized-hotel-bookings`** node and list its inputs and outputs
3. Hover edges into **`reviews_with_sentiment`** and note throughput in the current window

### Step 4: Hands-on exercises

**Exercise 1 — Trace `reviews_with_sentiment`**

From the **`reviews_with_sentiment`** topic, walk **upstream** through the graph until you reach every **source** (CDC connector and/or direct Kafka producers).

<details>
<summary>Click to reveal one possible answer (default workshop layout)</summary>

`reviews_with_sentiment` ← Flink `hotel-reviews-with-sentiment` ← **`reviews`** (Kafka) ← **producers** on `reviews`

Your exact graph may show dimension topics feeding the join directly or through snapshot tables.

</details>

**Exercise 2 — Impact analysis**

What happens in Stream Lineage if:

1. The **PostgreSQL CDC** connector is paused?
2. Java Datagen stops producing to **`bookings`** but CDC still runs?

Which Flink outputs and Tableflow tables degrade in each case?

**Exercise 3 — Export**

Use the **Export** icon on the lineage toolbar to save an image of your graph for documentation.

## 🏁 Conclusion

Stream Lineage ties together **CDC**, **direct Kafka events**, **Flink SQL**, and **Tableflow** in one explorable view—exactly the story you built for River Hotels. Keep the [official Stream Lineage documentation](https://docs.confluent.io/cloud/current/stream-governance/stream-lineage.html) handy for RBAC, point-in-time lineage (where available), and UI updates.

## ➡️ What's Next

Continue to **[LAB 6: Analytics and AI-Powered Marketing Automation](../LAB6_databricks/LAB6.md)**.

## 🔧 Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
