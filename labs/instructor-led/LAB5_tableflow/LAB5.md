# LAB 5: Tableflow

## Overview

Now that you have built your stream processing pipelines and created enriched data products, it is time to enable Tableflow to materialize your Kafka topics as Delta Lake tables in Databricks Unity Catalog.

### What You'll Accomplish

By the end of this lab, you will have:

1. **Tableflow-enabled Topics**: Streamed your `clickstream`, `denormalized_hotel_bookings`, and `hotel_stats` topics as Delta Lake tables
2. **Verified Unity Catalog Sync**: Confirmed that Tableflow is syncing data to your Databricks Unity Catalog

### Prerequisites

- Completed **[LAB 3: Unity Catalog Integration](../LAB3_catalog_integration/LAB3.md)** with Unity Catalog integration established
- Completed **[LAB 4: Stream Processing](../LAB4_stream_processing/LAB4.md)** with enriched data products created

## Steps

### How Tableflow Works (Optional)

<details>
<summary>Expand to learn more about how Tableflow works</summary>

When you enable Tableflow on a topic, Confluent starts two critical jobs:

```mermaid
graph LR
    A[Kafka Topic] --> B[Materializer Job]
    B --> C[Parquet Files]
    C --> D[S3 Storage]
    D --> E[Committer Job]
    E --> F[Delta Lake Table]
    F --> G[Databricks Unity Catalog]

    H[Schema Registry] --> B
    I[Tiered Storage] --> B
```

**Materializer Job:**

- Connects to your Kafka topic and fetches table metadata
- Retrieves associated schema from Schema Registry to define table structure
- Fetches data segments directly from tiered object storage for optimal performance
- Converts streaming data to Parquet format
- Writes converted data to your specified S3 location

**Committer Job:**

- Commits snapshots to catalogs with exactly-once semantics guaranteed
- Propagates changes to external catalogs like Unity Catalog
- Maintains table metadata and ensures data consistency

</details>

### Step 1: Enable Tableflow on `clickstream`

1. Navigate to [your workshop topics](https://confluent.cloud/go/topics)
2. Select your workshop environment and cluster
3. Click on the `clickstream` topic (the derived table you created in LAB 4, not the raw `riverhotel.cdc.clickstream` CDC topic)
4. Click on the **Enable Tableflow** button in the top right of your screen

   ![Clickstream topic landing page](../../shared/images/tableflow_clickstream_enable_tableflow.png)

5. Deselect the **Iceberg** tile
6. Select the **Delta** tile

   ![Delta table format selection](../../shared/images/confluent_tableflow_format_selection.png)

7. Click on the **Configure custom storage** button
8. Ensure the **Store in your own bucket** tile is selected
9. Select the *tableflow-databricks* provider integration from the dropdown
10. Enter the `S3 Bucket Name` from your credentials email into the *AWS S3 Bucket name* textbox

    ![Tableflow configuration storage form](../../shared/images/confluent_tableflow_storage_configuration.png)

11. Click on the **Continue** button
12. Review the configuration details and click the **Launch** button
13. Verify Tableflow is successfully syncing data by checking the status in the UI

    ![Tableflow Syncing](../../shared/images/confluent_tableflow_syncing.png)

### Step 2: Enable Tableflow on `denormalized_hotel_bookings` and `hotel_stats`

Repeat the steps you just completed for the `clickstream` topic above for the `hotel_stats` and `denormalized_hotel_booking` topics.

> **Important**: It may take a 3-4 minutes for Tableflow to begin syncing each topic. You can enable all three while waiting for the materialization to complete.

### Step 3: Review Unity Catalog Integration

1. Click on **Tableflow** in the left menu
2. Scroll down to the *External Catalog Integrations* section
3. Check for *Connected* status on the integration you set up in LAB 3

   ![Tableflow connected successfully](../../shared/images/tableflow_unity_catalog_connected.png)

### Configure Error Handling (Optional)

<details>
<summary>Expand to learn about configuring Dead Letter Queue (DLQ) error handling</summary>

Tableflow offers three modes for handling per-record materialization failures:

| Mode | Behavior |
|------|----------|
| **Suspend** (default) | Pauses Tableflow when a record cannot be materialized |
| **Skip** | Skips records that fail to materialize |
| **Log** | Sends failed records to a Dead Letter Queue (DLQ) topic |

The **Log** mode is useful for production environments where you want to capture problematic records without stopping the pipeline.

</details>

## Conclusion

You have enabled Tableflow on three topics — `clickstream`, `denormalized_hotel_bookings`, and `hotel_stats` — and verified that data is syncing to Databricks Unity Catalog as Delta Lake tables.

## What's Next

Continue to **[LAB 6: Analytics and AI-Powered Marketing](../LAB6_analytics_ai/LAB6.md)**.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
