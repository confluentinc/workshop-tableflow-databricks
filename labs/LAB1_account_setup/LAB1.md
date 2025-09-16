# LAB 1: Account Setup

## 🗺️ Overview

Welcome to the first step of building your real-time AI marketing pipeline! In this lab, you'll configure all the cloud platform accounts and credentials needed to deploy River Hotels' intelligent customer engagement system.

### What You'll Accomplish

```mermaid
graph LR
   A[1\. Clone Repository] --> B[2\. Configure Confluent Cloud]
   B --> C[3\. Configure Databricks]
   C --> D[4\. Configure AWS CLI]
   D --> E[5\. Ready for Deployment]
```

By the end of this lab, you will have:

1. **Repository Setup**: Clone the workshop repository and prepare Terraform configuration files
2. **Confluent Cloud Configuration**: Create API keys and set up cloud resource management access
3. **Databricks Account Setup**: Configure account access, create service principals, and enable external data access
4. **AWS CLI Authentication**: Set up AWS credentials for Terraform to deploy infrastructure

### Key Technologies You'll Configure

- **Git**: Version control system for cloning the workshop repository
- **Terraform**: Infrastructure as Code tool that requires cloud platform credentials for automated deployment
- **Confluent Cloud**: Fully managed Apache Kafka platform - you'll create API keys for cloud resource management
- **Databricks**: Unified analytics platform - you'll configure service principals and enable external data access
- **AWS CLI**: Command-line interface for Amazon Web Services - you'll authenticate with your AWS account

### Prerequisites

Review the [README](../../README.md) and complete its [prerequisites](../../README.md#-prerequisites)

## 👣 Steps

### Step 1: Clone this Repository

Get started by cloning the workshop repository and navigating to the Terraform configuration directory.

1. Open your preferred command-line interface, like *zsh* or *Powershell*
2. Clone this repository with git:

   **HTTP:**

   ```sh
   git clone https://github.com/confluentinc/workshop-tableflow-databricks.git
   ```

   **SSH:**

   ```sh
   git clone git@github.com:confluentinc/workshop-tableflow-databricks.git
   ```

3. Navigate to the Terraform directory:

   ```sh
   cd workshop-tableflow-databricks/terraform
   ```

#### Create Terraform Variables File

1. Copy the sample configuration file:

   ```sh
   cp sample-tfvars terraform.tfvars
   ```

2. Open `terraform.tfvars` in your preferred editor

Now you can configure each cloud platform's credentials and settings. It should look like this

```hcl
# ===============================
# General Overrides
# ===============================
email        = ""
cloud_region = ""
call_sign    = ""

# ===============================
# Confluent Cloud Overrides
# ===============================
confluent_cloud_api_key    = ""
confluent_cloud_api_secret = ""

# ===============================
# Databricks Overrides
# ===============================
databricks_account_id                      = ""
databricks_service_principal_client_id     = ""
databricks_service_principal_client_secret = ""
databricks_host                            = ""
databricks_user_email                      = ""
```

> [!NOTE]
> **Call Sign**
>
>You are going to prefix all cloud resources you create through terraform with the `call_sign` variable, so enter a short value for it.
>
>For example, it could be something like `neo` or `maverick`.  Pick something memorable, short, and fun.

Terraform requires API keys and configuration values to create resources across multiple cloud platforms. You'll configure these values in a `terraform.tfvars` file in the following steps.

### Step 2: Configure Confluent Cloud Account

Follow this next section of steps to create a Confluent *Cloud resource management* API key and token.

#### Login and Create API Key and Secret

1. Open a web browser tab and login to your Confluent cloud account
   - If you don't yet have one, [sign up for a free trial](https://www.confluent.io/confluent-cloud/tryfree?utm_campaign=tm.fm-ams_cd.Build-an-A[…]ne_id.701Uz00000fEQeEIAW&utm_source=zoom&utm_medium=workshop)
2. Click on the menu icon in the top right of the screen
3. Click on *API keys*

   ![Menu for managing your account](images/confluent_api_key.png)

4. Click on the *+ Add API key* button
5. Select *My account*
6. Click *Next*
7. Select *Cloud resource management*

   ![Tiles for different API scopes](images/confluent_api_key_cloud_management.png)

8. Click *Next*
9. Enter a name like *Tableflow Databricks Workshop*
10. Add a useful description
11. Click the *Create API Key* button

#### Add API Key and Secret to Terraform

1. In your code editor of choice, open your `terraform.tfvars` file and enter in the `confluent_cloud_api_key` and `confluent_cloud_api_secret` values from your newly-created **Key** and **Secret**. Save the `terraform.tfvars` file.
2. Back in Confluent Cloud, click the *Complete* button

### Step 3: Configure Databricks Account

There are many values to add from Databricks, and these steps will guide you through it:

#### Sign up/Login

Navigate to [Databricks](https://login.databricks.com/) and login with your account.

> [!NOTE]
> **Create Databricks Account**
>
> If you don't have an existing databricks account, you can create a *recommended* [free edition account](https://login.databricks.com/?intent=SIGN_UP&provider=DB_FREE_TIER).

#### Databricks Account ID

##### Account ID For Paid or Free Trial Accounts

1. Open a separate browser tab to the [Databricks Admin Console](https://accounts.cloud.databricks.com/)
2. Click on the user icon in the top right

   ![Admin account console](images/databricks_admin_console_account_id.png)

3. Copy the **Account ID** value and paste it into your `terraform.tfvars` file for the `databricks_account_id` key

##### Account ID For Free Edition Accounts

1. Open a separate browser tab to the [Databricks Admin Console](https://accounts.cloud.databricks.com/)
2. Find the `account_id=` in the browser tab url and copy the value

   ![Databricks Free Account ID](images/databricks_free_account_id.png)

3. Paste it into your `terraform.tfvars` file for the `databricks_account_id` key

#### Additional Databricks IDs

1. Click on the workspace dropdown in the top right of the top menu bar

   ![Databricks Workspace cloud region](images/databricks_workspace_region.png)

2. Take note of the *cloud region* value (e.g. `us-west-2`, `us-east-2`, etc.) and enter it into your `terraform.tfvars` for the `cloud_region` variable override.
3. Click on the user profile circle in the top right of the databricks screen

   ![Databricks Account ID](images/databricks_user_profile.png)

4. Copy your account's email address and paste it into your `terraform.tfvars` for the `databricks_user_email` variable override
5. You can paste the same email address in the `email` variable override in `terraform.tfvars`, or you can paste a different one
6. Copy the *URL* from your browser address bar and paste it into your `terraform.tfvars` for the `databricks_host` variable override. Erase everything after the *databricks.com*. It should look similar to this: `https://dbc-12f34e56-123e.cloud.databricks.com`

#### Create Service Principal

In this step you will create a [Service Principal](https://docs.databricks.com/aws/en/admin/users-groups/service-principals) to authenticate automated tasks, like Terraform, in your Databricks account.

1. Click on your username in the top right bar and select *Settings*
2. Click on **Identity and access**
3. Click the **Manage** button next to *Service principals*

   ![Databricks manage service principal](images/databricks_manage_service_principals.png)

4. Click on the **Add service principal** button
5. Click on the **Add new** button
6. Enter a descriptive name in the textbox, something like *workshop-tableflow-databricks*

   ![Databricks add service principal](images/databricks_add_service_principal.png)

7. Click on the **Add** button

#### Create OAuth Secret for Service Principal

1. Click on your newly-created Service Principal
2. Click on the **Secrets** tab
3. Click on the **Generate secret** button
4. Enter a reasonable duration lifetime, something like `30` or above

   ![Form input for secret duration](images/databricks_generate_oauth_secret.png)

5. Click the **Generate** button
6. Copy and paste the `Secret` and `Client ID` into the corresponding databricks Terraform variables in your `terraform.tfvars` file

7. Click on the *Done* button

#### Add Service Principal to Admin Group

1. Click on the *Identity and access* link under the *Settings* heading
2. Click on the *Manage* button next to the *Groups* section
3. Click on the *admins* link

   ![Databricks groups admins](images/databricks_groups_admins.png)

4. Click on the *Add members* button
5. Search for the name of the Service Principal you just created and select it from the dropdown

   ![Databricks add service principal to admins](images/databricks_admins_service_principal.png)

6. Click on the *Add* button

#### Enable External Data Access

1. Click on *Catalog* in the left menu
2. Click on the gear icon to expand a dropdown
3. Click on the *Metastore* dropdown

   ![Databricks Catalog settings select metastore](images/databricks_catalog_metastore.png)

4. Toggle the *External data access* so that is enabled

   ![Databricks Metastore configurations](images/databricks_external_data_access.png)

#### Databricks Setup Complete

You have completed the Databricks set up and each of the Databricks entries in your `terraform.tfvars` file should be populated with values.

You are now ready to configure your AWS account!

### Step 4: Configure AWS Account

With the AWS CLI already installed, follow [these instructions](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html) to configure and authenticate it with your AWS account.

> [!IMPORTANT]
> **AWS Workshop Studio Accounts**
>
> If you are using an AWS Workshop Studio account, click on the **Get AWS CLI credentials** link on your event home screen and follow the instructions for your operating system.
>
> Ensure that you set/export the variables in the same shell window that you will be running your terraform commands in.
>
> ![Menu for AWS CLI](images/aws_cli_credentials.png)

Verify that you are authenticated with the AWS CLI by invoking this command

```sh
aws configure list
```

You should see an output like this:

```sh
 Name                    Value             Type    Location
      ----                    -----             ----    --------
   profile                <not set>             None    None
access_key              ************             env
secret_key              ************             env
    region                **********             env    ******
```

## 🏁 Conclusion

🎉 **Congratulations!** You've successfully configured all the cloud platform accounts and credentials needed for River Hotels' AI-powered marketing pipeline!

### What You've Achieved

In this lab, you have:

✅ **Repository Setup**: Cloned the workshop repository and prepared Terraform configuration files

✅ **Confluent Cloud Access**: Created cloud resource management API keys for automated infrastructure deployment

✅ **Databricks Configuration**: Set up service principals, enabled external data access, and configured account permissions

✅ **AWS CLI Authentication**: Established secure access for Terraform to deploy AWS resources

### Your Configuration Foundation

You now have all the necessary credentials and configurations:

- **`terraform.tfvars` file** with all required cloud platform credentials
- **Confluent Cloud API keys** for resource management and deployment
- **Databricks service principal** with proper permissions for automation
- **AWS CLI authentication** ready for infrastructure provisioning

## ➡️ What's Next

Your journey continues in **[LAB 2: Cloud Infrastructure Deployment](../LAB2_cloud_deployment/LAB2.md)** where you will:

1. **Deploy Multi-Cloud Infrastructure**: Use Terraform to automatically provision 40+ resources across AWS, Confluent Cloud, and Databricks
2. **Establish Data Integration**: Configure Oracle XStream CDC connector to stream database changes in real-time
3. **Generate Realistic Data**: Deploy Shadow Traffic to create authentic customer behavior data with realistic patterns

## 🔧 Troubleshooting

You can find potentially common issues and solutions or workarounds in the [Troubleshooting](./troubleshooting.md) guide.
