# LAB 4: Resource Cleanup

## Overview

Time to clean up all cloud resources. Because demo mode provisioned everything through Terraform -- including Tableflow topics and Flink statements -- cleanup is significantly simpler than the self-service path.

### What You'll Accomplish

By the end of this lab, you will have:

1. **Manual Cleanup**: Removed Databricks resources created through the UI (notebooks, models, serving endpoints)
2. **Automated Cleanup**: Destroyed all Terraform-managed infrastructure with a single command
3. **Complete Removal**: Verified all cloud resources are properly cleaned up

> [!WARNING]
> **Complete Removal**
>
> Ensure you are done working with this workshop before you proceed. Everything will be removed and there is no way to restore it.

## Steps

### Step 1: Remove Databricks UI Resources

These resources were created through the Databricks UI and are not managed by Terraform:

1. Navigate to your Databricks workspace
2. Delete any **Notebooks** you created or imported (the pre-imported one at `/Shared/workshop/` will be removed by Terraform)
3. Delete any **Models** you created
4. Delete any **Serving Endpoints** you created
5. Delete the **Genie space** you created

### Step 2: Destroy All Infrastructure

Run `terraform destroy` to remove everything else:

```sh
docker-compose run --rm terraform -c "terraform destroy -auto-approve"
```

Terraform will destroy resources in the correct order:
1. Tableflow topic enablement (disables Tableflow on all three topics)
2. Flink CTAS statements (stops the running Flink jobs)
3. Unity Catalog integration
4. Databricks notebook, catalog, external location, storage credential
5. CDC connector, Flink statements, Flink compute pool
6. Confluent environment and cluster
7. AWS resources (EC2, S3, VPC, IAM)

> [!NOTE]
> **Expected Duration**
>
> Destroy typically takes 5-10 minutes. The longest steps are CDC connector deletion and Confluent environment teardown.

### Step 3: Verify Cleanup

Verify resources are removed from:

- **AWS Console**: EC2 instances, S3 buckets, IAM roles
- **Confluent Cloud**: Environments, clusters, compute pools
- **Databricks**: External locations, storage credentials, catalogs

## Conclusion

You have successfully completed the demo workshop and cleaned up all cloud resources.

## What's Next

Review the [recap](../../shared/recap.md) of what you accomplished in this workshop.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
