# LAB 2: Deploy and Observe

## Overview

This is where demo mode shines. A single `terraform apply` provisions the entire real-time AI marketing pipeline -- from cloud infrastructure to Confluent Cloud data streaming, Flink stream processing, Tableflow Delta Lake synchronization, and Databricks Unity Catalog integration.

### What Terraform Creates

By the end of this lab, `terraform apply` will have provisioned:

| Layer | AWS (`aws-demo`) | Azure (`azure-demo`) |
|-------|------------------|----------------------|
| **Cloud infra** | VPC, EC2 (PostgreSQL + data generator), S3, IAM | Resource Group, ADLS Gen2, PostgreSQL Flexible Server, data generator |
| **Confluent Cloud** | Environment, Standard Kafka cluster, Schema Registry, Flink compute pool, service account, API keys | Same |
| **CDC Pipeline** | PostgreSQL CDC → `riverhotel.cdc.customer` / `riverhotel.cdc.hotel` | Same |
| **Data Generator** | `clickstream`, `bookings`, `reviews` (Avro) | Same |
| **Flink** | Materialized Tables: `denormalized_hotel_bookings` **and** `reviews_with_sentiment` | `denormalized_hotel_bookings` only (`AI_SENTIMENT` is AWS-only) |
| **Data Contracts** | Clickstream CEL rule + DLQ | Same |
| **Tableflow** | S3 + UC integration; topics: clickstream, denormalized bookings, **reviews_with_sentiment** | ADLS Gen2 + UC; topics: clickstream, denormalized bookings |
| **Databricks** | Storage credential, external location, catalog, marketing notebook | Same |

> [!NOTE]
> **Azure and AI sentiment**
>
> Azure demo does not create `reviews_with_sentiment` or the Databricks `hotel_performance` view. See the [Confluent Cloud release notes](https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2026).

### Prerequisites

Complete **[LAB 1: Account Setup](../LAB1_account_setup/LAB1.md)** with all credentials configured in `terraform.tfvars`.

## Steps

### Step 1: Initialize and Apply Terraform

1. Open your terminal in the demo directory from LAB 0 (`terraform/aws-demo` or `terraform/azure-demo`)
2. Initialize Terraform:

   ```sh
   docker-compose run --rm terraform -c "terraform init"
   ```

3. Apply the full configuration:

   ```sh
   docker-compose run --rm terraform -c "terraform apply -auto-approve"
   ```

> [!NOTE]
> **Expected Duration**
>
> The full apply takes approximately 15-25 minutes. The longest steps are typically:
> - Cloud database / data generator startup (~5 min; EC2 on AWS, Flexible Server on Azure)
> - CDC connector creation and initial snapshot (~3 min)
> - Cloud IAM / RBAC propagation sleeps
> - Flink Materialized Table creation (~2 min)
> - Wait for Materialized Table topic creation (120s sleep)
> - Tableflow topic enablement (~1 min)

### Step 2: Review Terraform Outputs

After `terraform apply` completes, review the outputs:

```sh
docker-compose run --rm terraform -c "terraform output demo_status"
```

This shows:
- **Catalog integration** name
- **Flink Materialized Table** names
- **Tableflow** topic IDs
- **Notebook** path in Databricks
- **Direct links** to Confluent Cloud Tableflow, Flink workspace, and Databricks catalog

Also check the workshop summary:

```sh
docker-compose run --rm terraform -c "terraform output workshop_summary"
```

### Step 3: Observe the Pipeline in Confluent Cloud

Now explore what Terraform created in the Confluent Cloud UI:

#### Topics

1. Navigate to [your workshop topics](https://confluent.cloud/go/topics)
2. Select your workshop environment and cluster
3. Verify you see these topics:
   - `riverhotel.cdc.customer` and `riverhotel.cdc.hotel` (CDC from PostgreSQL)
   - `clickstream`, `bookings`, `reviews` (direct from data generator)
   - `denormalized_hotel_bookings` (created by Flink Materialized Table)
   - `reviews_with_sentiment` (AWS only — Flink Materialized Table with `AI_SENTIMENT`)

#### CDC Connector

1. Click on **Connectors** in the left menu
2. Verify the PostgreSQL CDC connector is **Running**

#### Flink Statements

1. Navigate to [your Flink compute pool](https://confluent.cloud/go/flink)
2. Select your workshop environment and click **Continue**
3. Look at the **Statements** tab to see the running ALTER TABLE statements and Materialized Tables

#### Tableflow

1. Click on **Tableflow** in the left menu
2. Verify Tableflow-enabled topics:
   - `clickstream` (syncing)
   - `denormalized_hotel_bookings` (syncing)
   - `reviews_with_sentiment` (syncing — **AWS only**)
3. Under **External Catalog Integrations**, verify the Unity Catalog integration shows **Connected** (or **Pending** if sync hasn't completed yet)

> [!IMPORTANT]
> **Tableflow Sync Startup Time**
>
> It takes 10-15 minutes for Tableflow to fully sync data to object storage (S3 or ADLS Gen2) and register tables in Unity Catalog. The `clickstream` topic (high throughput) typically syncs first. The Materialized Table topics may take a few extra minutes since they need data from the continuous Flink queries.
>
> You can proceed to explore Confluent Cloud while waiting, but you will need the sync to complete before LAB 3.

### Step 4: Understand What Was Automated

Here is a summary of what demo mode automated compared to self-service:

| Component | Self-Service | Demo Mode |
|-----------|-------------|-----------|
| **Unity Catalog Integration** | Manual wizard in CC UI (LAB3) | `confluent_catalog_integration` Terraform resource |
| **Tableflow on clickstream** | Manual enable in CC UI (LAB3) | `confluent_tableflow_topic` Terraform resource |
| **denormalized_hotel_bookings** | Manual Flink Materialized Table SQL (LAB4) | `confluent_flink_materialized_table` Terraform resource |
| **reviews_with_sentiment** | Manual Flink Materialized Table SQL (LAB4) | Automated on **AWS**; skipped on **Azure** (`AI_SENTIMENT` AWS-only) |
| **Tableflow on Materialized Table topics** | Manual enable in CC UI (LAB4) | `confluent_tableflow_topic` Terraform resource |
| **Notebook import** | Manual import from URL (LAB5) | `databricks_notebook` Terraform resource |

<details>
<summary>How the Flink Materialized Tables work</summary>

**`denormalized_hotel_bookings`** uses temporal joins to combine streaming bookings with point-in-time lookups against customer and hotel dimension tables. The `FOR SYSTEM_TIME AS OF` clause retrieves the dimension record as it existed at the time of each booking event.

**`reviews_with_sentiment`** (AWS only) enriches hotel reviews with aspect-based sentiment analysis using Confluent's built-in `AI_SENTIMENT` function. It evaluates each review across three aspects (cleanliness, amenities, service) and flattens the scores into individual columns for clean downstream analytics.

Materialized tables run continuous queries as persistent Flink jobs.

</details>

<details>
<summary>How Tableflow works</summary>

When Tableflow is enabled on a topic, Confluent starts two jobs:

1. **Materializer Job**: Reads from Kafka (via tiered storage for performance), converts data to Parquet format, and writes to your object store (S3 or ADLS Gen2)
2. **Committer Job**: Commits snapshots to Delta Lake with exactly-once semantics and syncs metadata to Unity Catalog

The result is that Kafka topics appear as queryable Delta Lake tables in Databricks.

</details>

## Conclusion

Your entire real-time AI marketing pipeline is now running. Data flows from PostgreSQL through CDC to Kafka, gets enriched by Flink (temporal joins, and on AWS AI sentiment analysis), and is materialized as Delta Lake tables via Tableflow.

> **Data Quality Rules**: Terraform also deployed a CEL-based data quality rule on the clickstream schema with a Dead Letter Queue. To explore this, see the optional **[Data Governance Lab](../LAB_data_governance/LAB_data_governance.md)**. On **AWS**, you can demonstrate live DQR enforcement via `curl localhost:9400/test-dqr` on the EC2 instance.

## What's Next

Continue to **[LAB 3: Analytics and AI](../LAB3_analytics_ai/LAB3.md)** to explore the data in Databricks and deploy a marketing AI agent.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
