# LAB 2: Cloud Infrastructure Deployment

## 🗺️ Overview

Now that you've configured your cloud platform accounts, it's time to deploy the infrastructure foundation for River Hotels' real-time AI marketing pipeline! In this lab, you'll use Terraform to automatically provision and validate resources across multiple cloud platforms.

### What You'll Accomplish

By the end of this lab, you will have:

1. **Multi-Cloud Infrastructure Deployment**: Use Terraform to automatically provision 40+ cloud resources across AWS, Confluent Cloud, and Databricks with proper security, networking, and integration
2. **Infrastructure Validation**: Verify that all deployed resources are running correctly and accessible
3. **Platform Integration**: Confirm that AWS, Confluent Cloud, and Databricks are properly connected and ready for data streaming

### Prerequisites

- Completed the [README prerequisites](../../README.md#-prerequisites)
- Completed **[LAB 1: Account Setup](../LAB1_account_setup/LAB1.md)** with all cloud platform credentials configured in your `terraform.tfvars` file

## 👣 Steps

### Step 1: Deploy Cloud Infrastructure with Terraform

Now it's time for you to perform some deployment magic! 🪄🎩

The following commands will initialize, validate, and apply the Terraform configuration to create your cloud resources.

#### Initialize Terraform

Run Terraform init inside the container:

```sh
docker-compose run --rm terraform -c "terraform init"
```

You should see this success message:

```sh
Terraform has been successfully initialized!
```

#### Validate Configuration

Verify that your Terraform configuration is valid:

```sh
docker-compose run --rm terraform -c "terraform validate"
```

You should see this success message:

```sh
Success! The configuration is valid.
```

#### Deploy Infrastructure

Initiate cloud resource creation:

```sh
docker-compose run --rm terraform -c "./terraform-apply-wrapper-with-retry.sh"
```

> [!NOTE]
> **Duration: 7-10 Minutes**
>
> It should take between 7-10 minutes for Terraform to completely generate all of the needed cloud resources.
>
> You should see an extensive log output in your shell showing the progress of generating the cloud resources. When finished, you should see a message like this:
>
> *Apply complete! Resources: XX added, 0 changed, 0 destroyed.*
>
> You may continue on with this lab while Terraform provisions.
>
> Alternatively, you may also spend *~10 minutes* going through this [optional data contracts and governance lab](../LAB_data_governance/LAB_data_governance.md) while you wait.

Expand the section below for a summary of the main cloud resources created through Terraform:

<details>
<summary>Cloud Resources Created</summary>

**AWS Resources:**

- VPC with proper networking components
- Security groups with minimal required access
- EC2 instance running PostgreSQL database with logical replication enabled
- S3 general-purpose bucket to store Delta table data
- IAM roles and policies for secure access

**Confluent Cloud Resources:**

- Environment for workshop isolation
- *Standard* Kafka cluster for data streaming
- Flink compute pool
- Provider Integration with AWS for Tableflow

**Databricks Resources:**

- External Location to access S3 bucket
- Storage Credential for secure access

</details>

#### Terraform Output

When the deployment completes, Terraform outputs helpful cloud resource values. You can view these values at any time by running:

```sh
docker-compose run --rm terraform -c "terraform output"
```

> [!TIP]
> **Interactive Shell**
>
> If you prefer to work in an interactive shell inside the container, run `docker-compose run --rm terraform` to drop into a bash shell where you can run `terraform` commands directly without the `-c` wrapper.

> [!IMPORTANT]
> **Troubleshoot Terraform Issues**
>
> If your terraform execution fails, you can [review these common issues](../troubleshooting.md#terraform).
>
> If you encounter a `500 Internal Server Error` when creating the Databricks external location, this is a transient error due to IAM propagation delays. The `terraform-apply-wrapper-with-retry.sh` script will automatically retry until successful.
>
> See [this section](../troubleshooting.md#transient-500-error-during-external-location-creation) of the Troubleshooting Guide for more details.

### Step 3: Verify Infrastructure Deployment (Optional)

You can verify that the cloud resources we created via Terraform are accessible and working as expected by expanding the section below and following the steps:

<details>
<summary>Review Cloud Resources</summary>

#### Verify AWS Resources

1. If logged out, log into the AWS console with the same account you used in Terraform
2. Select the same *cloud region* as you have in Terraform
3. **Ensure EC2 Instance is running**
   1. Navigate to the EC2 home page
   2. Click on *Instances* in the left navigation
   3. Search for the name of your instance (it should contain your call sign)
   4. Click on the link for it
   5. Check that it is running

   ![AWS EC2 status is Running](images/aws_ec2_running.png)

4. **Ensure S3 Bucket is available**
   1. Navigate to the S3 home page
   2. Search for your bucket under the *General purpose buckets* section
   3. Verify that the bucket exists and is empty

   ![AWS S3 status is Available](images/aws_s3_available.png)

#### Verify Databricks Resources

Follow these steps in a separate browser tab to verify that your Databricks cloud resources work:

##### Test External Location

1. Click on the *Catalog* link in the left navigation panel
2. Click on the gear icon in the top right of the Catalog panel

   ![Gear icon in the Catalog panel](images/databricks_catalog_manage.png)

3. Click on *External Locations*
4. Click on the *Name* link of the External Location created by Terraform
5. Click on the *Test connection* button in the top right of the screen
6. You should see a message like this

   ![A list of permissions that have check marks next to it](images/databricks_test_external_location.png)

##### Validate Storage Credential

1. Click on the *Credential* link
2. Click on the *Validate Configuration* button
3. You should see a success message like this:

   ![A list of permissions that have check marks next to it](images/databricks_test_storage_credential.png)

> [!NOTE]
> **Databricks Browser Tab**
>
> Keep this browser tab open as you will be returning to Databricks towards the end of this workshop.

#### Verify Confluent Resources

1. Navigate to your Confluent Cloud account
2. Find and Click on your workshop environment
3. Click on the *Integrations* link in the left menu
4. Notice there is a row under the *Provider* tab that contains the name **tableflow-databricks**. This is the AWS integration that will enable Tableflow to push streams as Delta Lake tables to S3

   ![AWS integration details](images/confluent_integrations_provider.png)

5. Click on *Overview* in the left sidebar menu
6. Click on your workshop Cluster
7. Click on the *Topics* link in the left sidebar menu
8. Notice that there no Topics being produced yet

   ![Topic tiles and quickstart links ](images/confluent_cluster_topics_empty.png)

</details>

## 🏁 Conclusion

🎉 **Congratulations!** You've successfully deployed the complete infrastructure foundation for River Hotels' AI-powered marketing pipeline!

### What You've Achieved

In this lab, you have:

- ✅ **Deployed Production-Scale Infrastructure**: Provisioned 40+ cloud resources across AWS, Confluent Cloud, and Databricks using Terraform
- ✅ **Validated Multi-Cloud Integration**: Confirmed that all platforms are properly connected, secured, and ready for data streaming

## ➡️ What's Next

Resume your journey in **[LAB 3: Data Generation](../LAB3_data_generation/LAB3.md)**.

## 🔧 Troubleshooting

You can find potentially common issues and solutions or workarounds in the [Troubleshooting](../troubleshooting.md) guide.
