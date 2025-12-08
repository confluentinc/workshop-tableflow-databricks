# LAB 3: Data Generation

## 🗺️ Overview

Time to bring your data pipeline to life! With your infrastructure deployed and connectors configured, you'll now generate realistic customer behavior data that will flow through your entire pipeline. This lab focuses on creating authentic hospitality industry data patterns using Shadow Traffic and capturing real-time database changes with the PostgreSQL CDC connector.

### What You'll Accomplish

![Architecture diagram data generation](./images/architecture_data_generation.jpg)

By the end of this lab, you will have:

1. **Realistic Data Generation**: Deploy Shadow Traffic to create authentic customer behavior data including clickstreams, bookings, reviews, hotels, and customer profiles
2. **Topic Content Validation**: Verify that PostgreSQL CDC and Shadow Traffic are successfully streaming data to Kafka topics

### Prerequisites

Completed **[LAB 2: Cloud Infrastructure Deployment](../LAB2_cloud_deployment/LAB2.md)** with all infrastructure successfully deployed and validated.

## 👣 Steps

### Step 1: Generate Data

You will use a flexible data-generator tool called [Shadow Traffic](https://shadowtraffic.io/) to create *River Hotel* data streams using a three-stage approach that creates both historical and streaming data.

1. Open a new shell tab
2. Navigate to the workshop repository's root folder
3. Execute the appropriate command for your OS

   <details>
   <summary>Linux/Mac</summary>

   ```sh
   docker run --env-file ./data/shadow-traffic-license.env -v "$(pwd)/data/:/home/data" shadowtraffic/shadowtraffic:1.11.13 --config /home/data/shadow-traffic-configuration.json
   ```

   </details>

   <details>
   <summary>Windows cmd</summary>

   ```sh
   docker run --env-file ./data/shadow-traffic-license.env -v "%cd%/data/:/home/data" shadowtraffic/shadowtraffic:1.11.13 --config /home/data/shadow-traffic-configuration.json
   ```

   </details>

   <details>
   <summary>Windows Powershell</summary>

   ```sh
   docker run --env-file ./data/shadow-traffic-license.env -v "${PWD}/data/:/home/data" shadowtraffic/shadowtraffic:1.11.13 --config /home/data/shadow-traffic-configuration.json
   ```

   </details>

You should see an output like this showing successful connection to the data ingestion layer:

![Shadow Traffic running successfully](images/shadow_traffic_success.png)

### Step 2: Review Topics

After successfully starting the data generation process, follow these steps to see data streaming into Confluent Cloud:

1. Navigate to the [topics UI](https://confluent.cloud/go/topics) in Confluent Cloud
2. Select your environment and cluster

   ![environment and cluster dropdowns](./images/navigate_to_topics.png)

3. Verify that you see these topics:

   ![table of topics](images/confluent_cluster_topics_streaming.png)

### Step 3: Review PostgreSQL CDC Connector

In this section you will verify that the PostgreSQL CDC connector is capturing real-time changes from your PostgreSQL database.

1. Click on *Connectors* in the left sidebar menu
2. You should see a tile like this

   ![PostgreSQL CC connector tile](./images/postgres_connector_tile.png)

3. Click the tile
4. Verify that the connector is running successfully

   ![PostgreSQL running successfully](./images/postgres_connector_success.png)

> [!TIP]
> **CDC Events**
>
> This change data capture connector will automatically record all *INSERT*, *UPDATE*, and *DELETE* events on the `customer` and `hotel` database tables to the corresponding Kafka topics `riverhotel.cdc.customer` and `riverhotel.cdc.hotel`.

## 🏁 Conclusion

🎉 **Congratulations!** You've successfully generated realistic data and streamed it into Confluent Cloud!

<details>
<summary>More details about your data pipeline</summary>

You now have a live, streaming data pipeline consisting of:

**Generated Data Streams:**

- **1,000 customer profiles** with realistic contact information and preferences
- **30 hotel properties** across 9 countries with detailed amenities and descriptions
- **3,000+ historical clickstream events** showing authentic customer browsing behavior
- **400+ booking transactions** with realistic customer-hotel relationships
- **200+ hotel reviews** with ratings and feedback that reflect actual guest experiences
- **Continuous streaming data** with realistic throttling patterns that simulate real-world usage

</details>

## ➡️ What's Next

Resume your journey in **[LAB 4: Tableflow and Unity Catalog](../LAB4_tableflow/LAB4.md)**.

## 🔧 Troubleshooting

You can find potentially common issues and solutions or workarounds in the [Troubleshooting](../troubleshooting.md) guide.
