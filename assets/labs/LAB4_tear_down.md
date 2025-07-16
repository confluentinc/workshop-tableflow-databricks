# Workshop Clean Up

## 🗺️ Overview

Congratulations on completing your real-time AI-powered marketing pipeline! Now it's time to responsibly clean up your cloud resources to avoid unnecessary charges and maintain good cloud hygiene.

### What You'll Accomplish

This cleanup process involves two complementary approaches:

1. **Manual UI Cleanup**: Remove resources created through web interfaces (connectors, notebooks, integrations)
2. **Automated Terraform Cleanup**: Destroy infrastructure provisioned through Infrastructure as Code

### Cleanup Strategy

The hybrid approach ensures complete resource removal while handling the different ways resources were created throughout the workshop. Manual steps address UI-created resources that Terraform doesn't track, while automated steps efficiently remove the bulk infrastructure.

### Part 1: Manual Cloud Resource Removal

These resources were created through web interfaces and need to be manually removed before running Terraform destroy:

#### Confluent

##### Remove Oracle XStream Connector

1. Click on *Connectors* in the left sidebar
2. Find your Oracle XStream CDC Source connector
3. Click on the connector name
4. Click *Settings* → *Delete connector*
5. Type the connector name to confirm deletion

#### Databricks

##### Remove Workspace Resources

1. Navigate to your Databricks workspace
2. Delete any notebooks you created or imported
3. In the *SQL Editor*, drop the external Delta tables:

```sql
DROP TABLE IF EXISTS hotel_stats;
DROP TABLE IF EXISTS clickstream;
DROP TABLE IF EXISTS denormalized_hotel_bookings;
```

**Clean Up Service Principal (Optional):**

1. Go to Settings → Identity and access → Service principals
2. Find your workshop service principal
3. Remove it from the admins group
4. Delete the service principal

### Part 2: Automatic Cloud Resource Removal

Now that manual resources are cleaned up, use Terraform to efficiently destroy the remaining cloud infrastructure:

1. Open your preferred command-line interface
2. Navigate to the workshop's *terraform* directory
3. Remove the provider integration from Terraform state

```sh
terraform state rm confluent_provider_integration.s3_tableflow_integration
```

> [!NOTE]
> **State Removal Only**
>
> This removes the resource from Terraform's tracking but doesn't delete it from Confluent Cloud. It will be cleaned up when the environment is destroyed in the next step.

4. Destroy all remaining infrastructure:

```sh
terraform destroy -auto-approve
```

5. Verify cleanup completion by checking that resources are removed from:
   - AWS Console (EC2 instances, S3 buckets, IAM roles)
   - Confluent Cloud (environments, clusters)
   - Databricks (workspaces, storage credentials)

## 🏁 Conclusion

🎉 **Excellent work!** You've successfully completed this entire workshop and have responsibly cleaned up all cloud resources - go ahead and give yourself a pat on the back, you deserve it!

## ➡️ What's Next

Now that you've completed all of the labs that comprise this workshop, review [this recap](./recap.md) of what you've accomplished.
