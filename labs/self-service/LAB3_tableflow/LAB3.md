# LAB 3: Tableflow and Unity Catalog

## 🗺️ Overview

Now that your data is streaming, it's time to integrate with Databricks Unity Catalog and enable Tableflow on a topic!

### What You'll Accomplish

![Tableflow architecture diagram](./images/ss_architecture_tableflow.jpg)

By the end of this lab, you will have:

1. **Unity Catalog Integration**: Connect Confluent Cloud with Databricks Unity Catalog through Tableflow for automated Delta Lake synchronization
2. **Tableflow-enabled Topic**: Stream your `clickstream` topic as a Delta Lake table with Tableflow

### Prerequisites

Make sure to have completed [LAB 2: Cloud Infrastructure Deployment](../LAB2_cloud_deployment/LAB2.md) with data streaming to Kafka topics.

## 👣 Steps

### Step 1: Setup Tableflow Integration with Unity Catalog

#### Establish Unity Catalog Integration

Follow these steps to setup the Tableflow-to-Unity Catalog integration:

1. Navigate to your cluster in Confluent Cloud by clicking [this link](https://confluent.cloud/go/cluster)
2. Select your workshop environment and cluster in the dropdowns

   ![Environment and cluster dropdowns](../../shared/images/navigate_to_cluster.png)

3. Click on **Tableflow** in the left menu
4. Click on the **+ Add integration** button next to the *External Catalog Integrations* section

   ![Tableflow landing page](../../shared/images/tableflow_landing_page.png)

5. Select **Databricks Unity**
6. Enter a relevant and memorable title in the *Name* field, something like `tableflow-databricks-workshop`

   ![Form with multi-select and a name and supported format field](../../shared/images/tableflow_unity_catalog_integration1.png)

7. Click **Continue**
8. Copy and paste the value from the `databricks_host` variable in your *terraform.tfvars* file into the *Databricks workspace URL* field
9.  Copy and paste the value from the `databricks_service_principal_client_id` variable in your *terraform.tfvars* file into the *Client ID* field
10. Copy and paste the value from the `databricks_service_principal_client_secret` variable in your *terraform.tfvars* file into the *Client secret* field
11. Copy and paste the name of your databricks catalog into the *Unity catalog name* - look for the `catalog_name` attribute from the result of running this terraform command:

   ```sh
   docker-compose run --rm terraform -c "terraform output databricks_integration"
   ```

   ![Form with fields to input connection details for Unity Catalog](../../shared/images/tableflow_unity_catalog_integration2.png)

12. Click **Continue**
13. Launch your Unity Catalog integration, you should see something like this on your screen:

   ![Table with row showing tableflow + databricks unity catalog integration is pending](../../shared/images/tableflow_unity_catalog_integration_pending.png)

> [!IMPORTANT]
> **Pending Status**
>
> The status of your Tableflow integration with Unity Catalog will remain in *Pending* until you enable Tableflow for Delta Lake on your first topic, which you will do in a future step. Do not be concerned about its status at this point.

#### How Tableflow Works (Optional)

<details>
<summary>Expand to learn more about how Tableflow works</summary>

When you enable Tableflow on a topic, Confluent starts two critical jobs that work together to provide reliable, exactly-once data processing:

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

**🔧 Materializer Job:**

- **Data Ingestion**: Connects to your Kafka topic and fetches table metadata
- **Schema Integration**: Retrieves associated schema from Schema Registry to define table structure
- **Optimized Reading**: Fetches data segments directly from tiered object storage (bypassing Kafka consumer APIs for better performance)
- **Format Conversion**: Converts streaming data to Parquet format for efficient analytical queries
- **Storage Writing**: Writes converted data to your specified S3 location

**🔧 Committer Job:**

- **Transactional Commits**: Commits snapshots to catalogs with exactly-once semantics guaranteed
- **Catalog Sync**: Propagates changes to external catalogs like Unity Catalog and AWS Glue
- **Metadata Management**: Maintains table metadata and ensures data consistency

#### Schema Evolution and Versioning

**🔄 Dynamic Schema Handling:**

- **Automatic Detection**: When schema changes are detected in your Kafka topic, Tableflow automatically creates new snapshots
- **Version Tracking**: Iceberg tracks schema evolution in metadata files, with each snapshot pointing to its schema version
- **Backward Compatibility**: Ensures existing queries continue to work while supporting new schema versions

#### Performance Optimization: The 15-Minute Threshold

**⏱️ Tiered Storage Integration:**

- **Primary Path**: Tableflow reads from tiered object storage for optimal performance
- **Fallback Mechanism**: If data hasn't been tiered within 15 minutes, automatically falls back to Kafka consumer APIs
- **Low-Throughput Handling**: This fallback may introduce delays for low-throughput topics but ensures data availability

> [!NOTE]
> **Performance Consideration**
>
> The 15-minute threshold is designed to balance performance with data availability. For high-throughput topics like `clickstream`, data is typically tiered quickly and benefits from the optimized storage path. For lower-throughput topics, the fallback ensures no data is lost while maintaining exactly-once processing guarantees.

#### Exactly-Once Processing Guarantees

**🛡️ Data Integrity:**

- **Transactional Semantics**: All commits are transactional, preventing data duplication or loss
- **Idempotent Operations**: Retries and failures don't create duplicate records
- **Consistency Guarantees**: Delta Lake's ACID properties ensure consistent reads across all consumers

#### Monitoring Your Tableflow Pipeline

After enabling Tableflow, you can monitor the pipeline through:

1. **Confluent Cloud UI**: Check sync status and processing metrics
2. **S3 Storage**: Verify Parquet files are being created in your bucket
3. **Databricks Unity Catalog**: Confirm tables are appearing and updating

> [!TIP]
> **Tableflow Best Practices**
>
> - **Topic Naming**: Use descriptive topic names as they become your Delta Lake table names
> - **Schema Design**: Design schemas for evolution - add fields rather than changing existing ones when possible
> - **Monitoring**: Regularly check sync status, especially for critical business data
> - **Partitioning**: Consider your query patterns when designing topic key strategies

</details>

### Step 2: Enable Tableflow on `clickstream` topic

Follow these steps to switch on Tableflow for the `clickstream` topic:

1. Navigate to your cluster topics
2. Click on the `clickstream` topic
3. Click on the **Enable Tableflow** button in the top right of your screen

   ![Clickstream topic landing page](../../shared/images/tableflow_clickstream_enable_tableflow.png)

4. Deselect the **Iceberg** tile
5. Select the **Delta** tile

   ![Delta table format selection](../../shared/images/confluent_tableflow_format_selection.png)

6. Click on the **Configure custom storage** button
7. Ensure the **Store in your own bucket** tile is selected
8. Select the *tableflow-databricks* provider integration from the dropdown
9. Open your command-line interface in the *terraform/* directory
10. Run this command

   ```sh
   docker-compose run --rm terraform -c "terraform output databricks_integration"
   ```

11. Copy the value from the `s3_bucket_name` property and paste it into the *AWS S3 Bucket name* textbox; your selections should look like this:

   ![Tableflow configuration storage form](../../shared/images/confluent_tableflow_storage_configuration.png)

12. Click on the **Continue** button
13. Set the **Storage retention** to **8 weeks** to control how long historical clickstream data is kept in Delta Lake
14. Review the configuration details and click the **Launch** button
15. Verify Tableflow is successfully syncing data by checking the status in the UI.

   ![Tableflow Syncing](../../shared/images/confluent_tableflow_syncing.png)

> [!IMPORTANT]
> **Tableflow Sync Startup Time**
>
> It may take several minutes for Tableflow to connect to S3 and then 10-15 minutes for it to start streaming your topics as tables.

### Step 3: Configure Error Handling (Optional)

<details>
<summary>Expand to learn about configuring Dead Letter Queue (DLQ) error handling</summary>

Tableflow offers three modes for handling per-record materialization failures:

| Mode | Behavior |
|------|----------|
| **Suspend** (default) | Pauses Tableflow when a record can't be materialized |
| **Skip** | Skips records that fail to materialize |
| **Log** | Sends failed records to a Dead Letter Queue (DLQ) topic |

The **Log** mode is particularly useful for production environments where you want to capture and analyze problematic records without stopping the entire pipeline.

> [!NOTE]
> **Tableflow DLQ vs Data Contract DLQ**
>
> Tableflow DLQ catches errors during **materialization** (Kafka → Delta Lake), while Data Contract DLQ catches errors during **ingestion** (Producer → Kafka). They're complementary: Data Contracts act as a gatekeeper at the front door, while Tableflow DLQ is a safety net at the back door.

#### Enable DLQ Error Handling

1. Navigate to your `clickstream` topic in Confluent Cloud
2. Click on the **Tableflow** tab
3. Open the Tableflow configuration settings
4. Locate the **Error Handling Mode** setting
5. Select **Log** from the available options
6. Leave the log target as the default `error_log` topic
7. Save your configuration

> [!TIP]
> **Custom DLQ Topic**
>
> If you prefer to use a dedicated DLQ topic instead of the default `error_log`, you can specify a custom topic name in the **Error Handling Log Target** field. The topic must exist and your account must have write permissions on it.

When records fail to materialize, they are sent to the DLQ topic along with error details including:

- Error timestamp, code, and reason
- Original record data (topic, partition, offset, key, value)

You can monitor the number of skipped/failed records through the `rows_skipped` metric in the Tableflow dashboard.

For more details, see the [Tableflow Error Handling documentation](https://docs.confluent.io/cloud/current/topics/tableflow/operate/configure-tableflow.html#error-handling-mode).

> [!NOTE]
> **Schema Requirement**
>
> Currently **DLQ** log mode is only available for topics configured with **Avro** or **Protobuf** schemas. All topics in this workshop use Avro, so you can use this feature.

</details>

## 🏁 Conclusion

🎉 **Congratulations!** You've successfully configured the link between Tableflow and Unity Catalog, as well as initiate streaming your `clickstream` topic as a Delta Lake table with Tableflow.

## ➡️ What's Next

Move forward in your journey with **[LAB 4: Stream Processing](../LAB4_stream_processing/LAB4.md)**.

## 🔧 Troubleshooting

You can find potentially common issues and solutions or workarounds in the [Troubleshooting](../../shared/troubleshooting.md) guide.
