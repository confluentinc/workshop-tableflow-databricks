# LAB 0: Prerequisites

## Overview

This is your first step in the **demo** lab path, where you will clone this workshop repository, set up cloud accounts, and install required tools.

If you want to learn more about why or when you would want to use **demo** mode, then [read more here](../../../README.md#-demo).

## Required Accounts

- **Confluent Cloud account** with admin privileges - [sign up for a free trial](https://www.confluent.io/confluent-cloud/tryfree?utm_campaign=tm.fm-ams_cd.Build-an-AI-Pipeline-Workshop-2025-Q2&utm_term=workshop&campaign_id=701Uz00000fEQeEIAW&utm_source=zoom&utm_medium=workshop)
- **Databricks account** and existing workspace - paid or [free edition account](https://login.databricks.com/?intent=SIGN_UP&provider=DB_FREE_TIER) are strongly recommended. [Free trial account](https://docs.databricks.com/aws/en/getting-started/express-setup) sometimes experience data syncing issues with this workshop, so we recommend that you use **paid** or **free edition** accounts instead.
- **Cloud account** for the demo you choose:
  - **AWS**: permissions to create EC2, S3, VPC, and IAM resources (`terraform/aws-demo`)
  - **Azure**: permissions to create Resource Groups, Storage (ADLS Gen2), PostgreSQL Flexible Server, and related RBAC (`terraform/azure-demo`)

> [!IMPORTANT]
> **Payment Method or Promo Code Required for Confluent Cloud**
>
> You must either add a [payment method](https://docs.confluent.io/cloud/current/billing/overview.html#manage-your-payment-method) or [redeem a coupon code](https://docs.confluent.io/cloud/current/billing/overview.html#redeem-a-promo-code-or-view-balance) to be able to run this workshop.

## Required Tools

You only need to have these two tools installed on your local machine:

1. **[Git](https://git-scm.com/downloads)**
2. **[Docker Desktop](https://docs.docker.com/get-started/get-docker/)** installed and running

<details>
<summary>Install on macOS</summary>

Using [Homebrew](https://brew.sh/):

```sh
# Install Git
brew install git

# Install Docker Desktop
brew install --cask docker
```

After installation, launch Docker Desktop from Applications and ensure it's running (look for the whale icon in the menu bar).

</details>

<details>
<summary>Install on Windows</summary>

Using [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (Windows Package Manager):

```powershell
# Install Git
winget install --id Git.Git -e --source winget

# Install Docker Desktop
winget install --id Docker.DockerDesktop -e --source winget
```

After installation:

1. Restart your terminal
2. Launch Docker Desktop from the Start menu
3. Ensure Docker is running (look for the whale icon in the system tray)

</details>

<details>
<summary>Install on Linux (Ubuntu/Debian)</summary>

```sh
# Install Git
sudo apt update && sudo apt install -y git

# Install Docker Engine
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group (logout/login required)
sudo usermod -aG docker $USER
```

> **Note**: Log out and back in for the group change to take effect.

</details>

<details>
<summary>Install on Linux (Fedora/RHEL)</summary>

```sh
# Install Git
sudo dnf install -y git

# Install Docker Engine
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to the docker group (logout/login required)
sudo usermod -aG docker $USER
```

> **Note**: Log out and back in for the group change to take effect.

</details>

## Initial Setup Steps

### Windows Users

> [!IMPORTANT]
> **Instructions for Windows Users: Use WSL 2 with Ubuntu for Best Results**
>
> We strongly recommend running this workshop from within **WSL 2** (Windows Subsystem for Linux) with **Ubuntu** rather than PowerShell or Command Prompt. See the [self-service LAB0](../self-service/LAB0_prerequisites/LAB0.md#windows-users) for detailed Windows setup instructions.

## Step 1: Clone this Repository

1. Open your preferred command-line interface
2. Clone this repository with git:

   ```sh
   git clone https://github.com/confluentinc/workshop-tableflow-databricks.git
   ```

## Step 2: Build Terraform Docker Image

Choose your cloud demo directory, then build the container:

**AWS:**

```sh
cd workshop-tableflow-databricks/terraform/aws-demo
docker-compose build
```

**Azure:**

```sh
cd workshop-tableflow-databricks/terraform/azure-demo
docker-compose build
```

Use the same directory for the rest of the demo labs (`LAB 1`–`LAB 4`).

You should see output showing the container being built:

```sh
[+] Building 45.2s (7/7) FINISHED
 => [terraform internal] load build definition from Dockerfile
 => ...
 => => naming to docker.io/library/workshop-terraform:latest
```

> [!NOTE]
> **First-Time Build**
>
> The initial build may take a few minutes. Subsequent uses leverage cached layers and should complete in seconds.

> [!NOTE]
> **Azure and AI sentiment**
>
> Azure demo skips `reviews_with_sentiment` and the `hotel_performance` view because `AI_SENTIMENT` is currently AWS-only. See the [Confluent Cloud release notes](https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2026).

## What's Next

Continue to **[LAB 1: Account Setup](../LAB1_account_setup/LAB1.md)**.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
