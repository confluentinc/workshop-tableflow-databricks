# LAB 4: Tableflow

## Overview

Now that you have built your stream processing pipelines and created enriched data products, it is time to connect Confluent Cloud with Databricks Unity Catalog and enable Tableflow to materialize your Kafka topics as Delta Lake tables.

### What You'll Accomplish

By the end of this lab, you will have:

1. **Unity Catalog Integration**: Connected Confluent Cloud with Databricks Unity Catalog through Tableflow
2. **Tableflow-enabled Topics**: Streamed your `riverhotel.cdc.clickstream`, `denormalized_hotel_bookings`, and `hotel_stats` topics as Delta Lake tables
3. **Verified Unity Catalog Sync**: Confirmed that Tableflow is syncing data to your Databricks Unity Catalog

![Architecture diagram with focus on Tableflow and Delta Lake](./images/arch_diagram_tableflow.png)

### Prerequisites

- Completed **[LAB 3: Stream Processing](../LAB3_stream_processing/LAB3.md)** with enriched data products created

## Steps

### Step 1: Set Up Tableflow Integration with Unity Catalog

#### Establish Unity Catalog Integration

Follow these steps to connect Tableflow to your Databricks Unity Catalog:

1. Navigate to your cluster in Confluent Cloud by clicking [this link](https://confluent.cloud/go/cluster)
2. Select your workshop environment and cluster in the dropdowns

   ![Environment and cluster dropdowns](../../shared/images/navigate_to_cluster.png)

3. Click on **Tableflow** in the left menu
4. Click on the **+ Add integration** button next to the *External Catalog Integrations* section

   ![Tableflow landing page](../../shared/images/tableflow_landing_page.png)

5. Select **Databricks Unity**
6. Enter a relevant name in the *Name* field, something like `tableflow-databricks-workshop`

   ![Form with multi-select and a name and supported format field](../../shared/images/tableflow_unity_catalog_integration1.png)

7. Click **Continue**
8. Enter the connection details from your credentials email:

   | Field | Value Source |
   |---|---|
   | **Databricks workspace URL** | The Databricks `Workspace URL` from your credentials email |
   | **Client ID** | The Databricks `SP Client ID` from your credentials email |
   | **Client secret** | The Databricks `SP Client Secret` from your credentials email |
   | **Unity catalog name** | The Databricks `Unity Catalog Name` from your credentials email |

   ![Form with fields to input connection details for Unity Catalog](../../shared/images/tableflow_unity_catalog_integration2.png)

9. Click **Continue**
10. Launch your Unity Catalog integration

   ![Table with row showing tableflow + databricks unity catalog integration is pending](../../shared/images/tableflow_unity_catalog_integration_pending.png)

> **Important**: The status of your Tableflow integration with Unity Catalog will remain in *Pending* until you enable Tableflow for Delta Lake on your first topic, which you will do next.

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

### Step 2: Enable Tableflow on `riverhotel.cdc.clickstream`

1. Navigate to [your workshop topics](https://confluent.cloud/go/topics)
2. Select your workshop environment and cluster
3. Click on the `riverhotel.cdc.clickstream` topic
4. Click on the **Enable Tableflow** button in the top right of your screen
5. Deselect the **Iceberg** tile
6. Select the **Delta** tile

   ![Delta table format selection](../../shared/images/confluent_tableflow_format_selection.png)

7. Click on the **Configure custom storage** button
8. Ensure the **Store in your own bucket** tile is selected
9. Select the *tableflow-databricks* provider integration from the dropdown
10. Copy and paste the `S3 Bucket Name` from your credentials email into the *AWS S3 Bucket name* textbox

    ![Tableflow configuration storage form](../../shared/images/confluent_tableflow_storage_configuration.png)

11. Click on the **Continue** button
12. Review the configuration details and click the **Launch** button
13. Verify Tableflow is successfully syncing data by checking the status in the UI

    ![Tableflow Syncing](./images/clickstream_tableflow_enabled.png)

### Step 3: Enable Tableflow on `denormalized_hotel_bookings` and `hotel_stats`

Repeat the steps you just completed for the `riverhotel.cdc.clickstream` topic above for the `hotel_stats` and `denormalized_hotel_booking` topics.

> **Important**: It may take a 3-4 minutes for Tableflow to begin syncing each topic. You can enable all three while waiting for the materialization to complete.

### Step 4: Review Unity Catalog Integration

1. Click on **Tableflow** in the left menu
2. Scroll down to the *External Catalog Integrations* section
3. Check for *Connected* status on the integration you set up in Step 1

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

You have configured the integration between Confluent Cloud Tableflow and Databricks Unity Catalog, enabled Tableflow on three topics — `riverhotel.cdc.clickstream`, `denormalized_hotel_bookings`, and `hotel_stats` — and verified that data is syncing as Delta Lake tables.

## What's Next

Continue to **[LAB 5: Analytics and AI-Powered Marketing](../LAB5_analytics_ai/LAB5.md)**.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
