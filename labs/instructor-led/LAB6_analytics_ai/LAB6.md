# LAB 6: Analytics and AI-Powered Marketing Automation

## Overview

Transform your streaming data products into actionable business insights and AI-generated marketing campaigns using Databricks' analytics and AI capabilities.

### What You'll Accomplish

By the end of this lab, you will have:

1. **AI-Powered Business Intelligence**: Used Databricks Genie to generate natural language insights about customer behavior, booking patterns, and hotel performance
2. **Intelligent Marketing Automation**: Deployed an AI agent that identifies underperforming hotels with good customer satisfaction, generates social media campaigns based on reviews, and creates targeted customer lists

![Architecture Diagram for Databricks](./images/arch_diagram_databricks.png)

### Prerequisites

- Completed **[LAB 5: Stream Lineage](../LAB5_stream_lineage/LAB5.md)** with the workshop pipeline explored in Stream Lineage

## Steps

### Step 1: Create Hotel Performance View and Explore Analytics

Verify that data is flowing from Confluent via Tableflow into Databricks Unity Catalog, then create an analytics view that aggregates sentiment and booking data.

1. Log in to your Databricks workspace using the credentials from your email
2. Click on **Catalog** in the left menu
3. Verify that you see your Tableflow catalog

   ![Databricks Catalog explorer](../../shared/images/databricks_catalog.png)

4. Expand your Tableflow catalog
5. Expand your Confluent cluster schema (its name should match the ID of your Confluent Cloud Kafka cluster)
6. Verify that you see three tables: *clickstream*, *denormalized_hotel_bookings*, and *reviews_with_sentiment*

   ![Expanded Catalog schema](../../shared/images/databricks_catalog_cluster_schema.png)

> **Tip**: If you see a modal prompting you to start a compute resource, select **Automatically launch and attach without prompting** and click **Start, attach and run**.
>
> ![Start compute resource modal](../../shared/images/databricks_compute_resource_modal.png)

> **Important**: It may take a few minutes for `SELECT` queries to return data for the `denormalized_hotel_bookings` and `reviews_with_sentiment` tables if you only recently enabled Tableflow on them.

#### Create the Hotel Performance View

7. Click the **Create** dropdown and select **Query**
8. Select your *catalog* and *schema* from the dropdowns

    ![Two dropdown selectors for catalog and schema](../../shared/images/databricks_query_dropdowns.png)

9. Run this statement to create an analytics view that aggregates booking metrics and sentiment scores:

```sql
CREATE OR REPLACE VIEW hotel_performance AS
WITH booking_metrics AS (
  SELECT
    hotel_id,
    MAX(hotel_name) AS hotel_name,
    MAX(hotel_city) AS hotel_city,
    MAX(hotel_country) AS hotel_country,
    MAX(hotel_category) AS hotel_category,
    MAX(hotel_description) AS hotel_description,
    COUNT(*) AS total_bookings_count,
    SUM(guest_count) AS total_guest_count,
    SUM(booking_amount) AS total_booking_amount
  FROM denormalized_hotel_bookings
  WHERE booking_date >= current_timestamp() - INTERVAL 7 DAYS
  GROUP BY hotel_id
),
review_metrics AS (
  SELECT
    hotel_id,
    CAST(AVG(review_rating) AS DECIMAL(10, 2)) AS average_review_rating,
    COUNT(*) AS review_count,
    SUM(CASE WHEN cleanliness_label = 'Positive' THEN 1 ELSE 0 END) AS positive_cleanliness_count,
    SUM(CASE WHEN amenities_label = 'Positive' THEN 1 ELSE 0 END) AS positive_amenities_count,
    SUM(CASE WHEN service_label = 'Positive' THEN 1 ELSE 0 END) AS positive_service_count
  FROM reviews_with_sentiment
  GROUP BY hotel_id
)
SELECT
  bm.*,
  rm.average_review_rating,
  rm.review_count,
  rm.positive_cleanliness_count,
  rm.positive_amenities_count,
  rm.positive_service_count
FROM booking_metrics bm
LEFT JOIN review_metrics rm ON rm.hotel_id = bm.hotel_id;
```

10. Query the top hotels by positive amenities sentiment:

```sql
SELECT
  hotel_name,
  hotel_city,
  hotel_category,
  positive_amenities_count,
  positive_cleanliness_count,
  positive_service_count,
  average_review_rating,
  review_count
FROM hotel_performance
ORDER BY positive_amenities_count DESC
LIMIT 5;
```

The top 5 hotels ranked by positive amenities sentiment, with their cleanliness and service scores for comparison. These sentiment counts come from Flink's `AI_SENTIMENT` function, which analyzed each review for cleanliness, amenities, and service aspects.

### Step 2: Derive Data Product Insights with Genie

Databricks Genie provides a chat interface where you ask questions about your data in natural language and it generates SQL queries to answer them.

#### Set Up Genie Workspace

1. Click on the **Genie** link under the *SQL* section in the left sidebar
2. Click on the **+ New** button to create a new Genie space
3. Click on the **All** toggle
4. Navigate to your workshop *catalog* and *database*
5. Select the `clickstream`, `denormalized_hotel_bookings`, `reviews_with_sentiment`, and `hotel_performance` tables

   ![Databricks Genie connect to data sources](../../shared/images/databricks_genie_connect_data.png)

6. Click **Create**
7. Rename your space to something like *River Hotel BI*

   ![Databricks Genie space](../../shared/images/databricks_genie_space.png)

#### Generate Business Insights

Toggle the **Agent** mode and prompt Genie with natural language questions.

Here are some other prompts you can try:

> Show me customer satisfaction metrics by country

![Databricks Genie sample user prompt](../../shared/images/databricks_genie_prompt_satisfaction_by_country.png)

---

> Which hotels have the highest positive sentiment across cleanliness, amenities, and service?

---

> Which category of hotel had the lowest interest from customers?

![Result set showing hotel category and corresponding customer interest count](../../shared/images/databricks_genie_prompt_hotel_category.png)

Identify the *Hotel Category* with the lowest customer interest — you will use this in the next section to create a marketing agent.

---

<details>
<summary>Expand this section for more sample prompts</summary>

> Show me customers who viewed hotels in the most cities

![Table of customers](../../shared/images/databricks_genie_prompt_customers_hotels_viewed.png)

---

> Which cities had the most interest from customers?

![Table and chart of cities with the most interest](../../shared/images/databricks_genie_prompt_cities_customer_interest.png)

</details>

### Step 3: Create and Deploy Marketing Campaign Agent

Use a pre-built Jupyter Notebook to generate an AI agent that identifies hotels needing promotion and creates targeted marketing campaigns.

The AI agent combines three functions:

1. **Hotel Selection**: Identifies the lowest-performing hotel in a given category that has above-average customer satisfaction — perfect candidates for promotion
2. **Content Generation**: Analyzes customer reviews and creates positive social media posts
3. **Customer Targeting**: Finds customers with high browsing interest but few bookings — prime targets for conversion

#### Import and Configure Notebook

1. Click on the **+ New** button in the top left of the screen
2. Select **Notebook**
3. Click on **File** then **Import**

   ![File selection menu](../../shared/images/databricks_import_notebook_dropdown.png)

4. Select **URL**
5. Paste in this value:

```text
https://raw.githubusercontent.com/confluentinc/workshop-tableflow-databricks/refs/heads/main/labs/shared/river_hotel_marketing_agent.ipynb
```

6. Click **Import**

   ![Import dialog with Notebook selected](../../shared/images/databricks_import_notebook.png)

7. Follow the instructions in the Notebook to create and deploy the marketing campaign agent

## Conclusion

Your AI marketing agent is deployed and ready to help River Hotels create data-driven marketing campaigns in real-time.

## What's Next

Continue to **[LAB 7: Wrap Up](../LAB7_wrap_up/LAB7.md)**.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
