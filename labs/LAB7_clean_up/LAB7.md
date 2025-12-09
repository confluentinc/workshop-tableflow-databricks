# LAB 7: Resource Cleanup

## 🗺️ Overview

Congratulations on completing your real-time AI-powered marketing pipeline! Now it's time to responsibly clean up your cloud resources to avoid unnecessary charges and maintain good cloud hygiene.

### What You'll Accomplish

By the end of this lab, you will have:

1. **Manual UI Cleanup**: Removed resources created through web interfaces (connectors, notebooks, integrations)
2. **Automated Terraform Cleanup**: Destroyed infrastructure provisioned through Infrastructure as Code
3. **Complete Resource Removal**: Verified all cloud resources are properly cleaned up to avoid ongoing charges

### Cleanup Strategy

The hybrid approach ensures complete resource removal while handling the different ways resources were created throughout the workshop. Manual steps address UI-created resources that Terraform doesn't track, while automated steps efficiently remove the bulk infrastructure.

> [!WARNING]
> **Complete Removal**
>
> Ensure you are done working with this workshop before you proceed, as everything you have set up will be removed once you complete these steps and there is no way to restore it.

## Part 1: Manual Cloud Resource Removal

These resources and connections were created through web interfaces and need to be manually removed first:

### Confluent

#### Disable Tableflow on Topics

1. Navigate to your topics
2. Click on the `denormalized_hotel_bookings` topic
3. Click on the **Configuration** tab
4. Click the **Disable Tableflow** link

   ![Topic configuration page](./images/tableflow_disable_topic.png)

5. Copy and paste the topic name into the field and click **Confirm**
6. Repeat steps 1-5 for the `clickstream` and `hotel_stats` topics

#### Databricks

##### Remove Workspace Resources

1. Navigate to your Databricks workspace
2. Delete any *Notebooks* you created or imported
3. Delete any *Models* you created
4. Delete any *Serving Endpoints* you created

## Part 2: Automatic Cloud Resource Removal

Now that manual resources are cleaned up, use Terraform to efficiently destroy the remaining cloud infrastructure:

1. Open your preferred command-line interface
2. Navigate to the workshop's *terraform* directory
3. Remove all remaining infrastructure using the Docker container:

   ```sh
   docker-compose run --rm terraform -c "terraform destroy -auto-approve"
   ```

4. Verify cleanup completion by checking that resources are removed from:
   - AWS Console (EC2 instances, S3 buckets, IAM roles)
   - Confluent Cloud (environments, clusters, compute pools)
   - Databricks (external location, storage credentials)

## 🏁 Conclusion

🎉 **Excellent work!** You've successfully completed this entire workshop and have responsibly cleaned up all cloud resources - go ahead and give yourself a pat on the back, you deserve it!

## ➡️ What's Next

Now that you've completed all of the labs that comprise this workshop, review [this recap](../recap.md) of what you've accomplished.

## 🔧 Troubleshooting

You can find potentially common issues and solutions or workarounds in the [Troubleshooting](../troubleshooting.md) guide.
