# LAB 1: Account Setup

## Overview

In this lab you will configure all cloud platform accounts and credentials needed to deploy the full River Hotels pipeline in demo mode. This is identical to the self-service account setup.

### What You'll Accomplish

By the end of this lab, you will have:

1. **Configured Confluent Cloud**: Created API keys for cloud resource management
2. **Setup Databricks Account**: Configured account access, created service principals, and enabled external data access
3. **Authenticated with AWS**: Set up AWS credentials for Terraform

### Prerequisites

Complete **[LAB 0: Prerequisites](../LAB0_prerequisites/LAB0.md)** before starting this lab.

## Steps

### Step 1: Create Terraform Variables File

1. Ensure you are in the `terraform/aws-demo` directory
2. Copy the sample variables file:

```sh
cp sample-tfvars terraform.tfvars
```

3. Open `terraform.tfvars` in your preferred editor

### Step 2: Configure Cloud Prefix and Region

Pick a short, memorable prefix (like your initials) and set your AWS region:

```hcl
confluent_cloud_email = "you@example.com"
prefix                = "neo"
cloud_region          = "us-east-1"
```

### Step 3: Configure Confluent Cloud Account

Follow the same steps as the [self-service LAB1 Step 3](../self-service/LAB1_account_setup/LAB1.md#step-3-configure-confluent-cloud-account) to create a **Cloud resource management** API key.

Add the key and secret to your `terraform.tfvars`:

```hcl
confluent_cloud_api_key    = "YOUR_KEY"
confluent_cloud_api_secret = "YOUR_SECRET"
```

### Step 4: Configure Databricks Account

Follow the same steps as the [self-service LAB1 Step 4](../self-service/LAB1_account_setup/LAB1.md#step-4-configure-databricks-account) to:

1. Get your **Databricks workspace URL** and **user email**
2. Create a **Service Principal** with an OAuth secret
3. Add the Service Principal to the **admins** group
4. Enable **External data access** on your metastore

Add all values to your `terraform.tfvars`:

```hcl
databricks_host                            = "https://dbc-xxxxx.cloud.databricks.com"
databricks_account_id                      = "YOUR_ACCOUNT_ID"
databricks_user_email                      = "you@example.com"
databricks_service_principal_client_id     = "YOUR_SP_CLIENT_ID"
databricks_service_principal_client_secret = "YOUR_SP_SECRET"
```

### Step 5: Configure AWS Account

Follow the same steps as the [self-service LAB1 Step 4 (AWS)](../self-service/LAB1_account_setup/LAB1.md#step-4-configure-aws-account) to configure AWS credentials.

Verify AWS credentials work inside the Docker container:

```sh
docker-compose run --rm terraform -c "aws configure list"
```

## Conclusion

You have configured all cloud platform credentials. Your `terraform.tfvars` file should have all required values populated.

## What's Next

Your journey continues in **[LAB 2: Deploy and Observe](../LAB2_deploy_and_observe/LAB2.md)** where a single `terraform apply` provisions the entire pipeline.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
