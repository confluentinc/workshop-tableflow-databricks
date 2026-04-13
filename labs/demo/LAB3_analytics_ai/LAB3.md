# LAB 3: Analytics and AI-Powered Marketing Automation

## Overview

Your streaming pipeline is fully operational -- data is flowing from PostgreSQL through Kafka, being enriched by Flink, and landing as Delta Lake tables in Databricks via Tableflow. Now you will use Databricks to analyze this data and deploy an AI marketing agent.

### What You'll Accomplish

By the end of this lab, you will have:

1. **Explored Hotel Performance Analytics**: Verified Tableflow tables in Unity Catalog and queried the `hotel_performance` view for sentiment-ranked hotel insights
2. **AI-Powered Business Intelligence**: Used Databricks Genie to generate natural language insights about sentiment and performance
3. **Intelligent Marketing Automation**: Configured and ran a pre-imported AI agent notebook that identifies underperforming hotels and generates targeted marketing campaigns

### Prerequisites

Completed **[LAB 2: Deploy and Observe](../LAB2_deploy_and_observe/LAB2.md)** with Tableflow sync complete (tables visible in Unity Catalog).

## Steps

### Step 1: Explore Hotel Performance Analytics

1. Login and navigate to your Databricks workspace
2. Click on **Catalog** in the left menu
3. Expand your Tableflow catalog (name from `terraform output databricks_integration`)
4. Expand the Confluent cluster schema (matches your Kafka cluster ID)
5. Verify you see three Tableflow tables: `clickstream`, `denormalized_hotel_bookings`, and `reviews_with_sentiment`

> [!IMPORTANT]
> **Tableflow Sync Time**
>
> If you do not see all three tables, Tableflow may still be syncing. Check the Tableflow status in Confluent Cloud. The `clickstream` table typically appears first (high throughput), followed by the CTAS-created tables.

The `hotel_performance` SQL view was pre-created by Terraform. It aggregates booking metrics and sentiment analysis scores from `denormalized_hotel_bookings` and `reviews_with_sentiment`.

6. Click the **Create** dropdown and select **Query**
7. Select your catalog and schema from the dropdowns
8. Query the top hotels by positive amenities sentiment:

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

Databricks Genie provides a chat interface where you ask questions about your data in natural language.

#### Set Up Genie Workspace

1. Click on **Genie** under the *SQL* section in the left sidebar
2. Click **+ New** to create a new Genie space
3. Click **All** and navigate to your workshop catalog and database
4. Select the `clickstream`, `denormalized_hotel_bookings`, `reviews_with_sentiment`, and `hotel_performance` tables
5. Click **Create**
6. Rename your space to something like *River Hotel BI*

#### Generate Business Insights

Toggle the **Agent** mode and try prompts like:

> Show me customer satisfaction metrics by country

> Which hotels have the highest positive sentiment across cleanliness, amenities, and service?

> Which category of hotel had the lowest interest from customers?

Try to remember the result of hotel category with lowest interest, as you will use that in the next section.

### Step 3: Run the Marketing Campaign Agent Notebook

The marketing agent notebook has been **pre-imported** by Terraform at `/Shared/workshop/river_hotel_marketing_agent`.

1. Click on **Workspace** in the left sidebar
2. Navigate to **Shared** > **workshop**
3. Open the `river_hotel_marketing_agent` notebook

The AI agent combines three intelligent functions:

1. **Hotel Selection**: Identifies the lowest-performing hotel in a given category with above-average customer satisfaction
2. **Content Generation**: Uses AI to analyze customer reviews and create social media posts
3. **Customer Targeting**: Finds customers who showed high interest but made few bookings

4. Follow the instructions in the notebook to configure the widgets (catalog, schema, warehouse ID, hotel category) and run the agent

> [!TIP]
> **Widget Values**
>
> You can find the catalog name and schema from `terraform output databricks_integration`. The warehouse ID is also available in that output.

## Conclusion

You have explored the streaming data landing in Databricks via Tableflow, created analytics views, used Genie for natural language insights, and deployed an AI marketing agent -- all powered by the real-time pipeline that Terraform provisioned automatically.

## What's Next

When you are done exploring, proceed to **[LAB 4: Cleanup](../LAB4_cleanup/LAB4.md)** to tear down all resources.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
