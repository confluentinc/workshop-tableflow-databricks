# LAB 0: Prerequisites

## Overview

This is your first step in the **self-service** lab, where you will clone this workshop repository, set up cloud accounts, and install required tools.

## Required Accounts

- **Confluent Cloud account** with admin privileges - [sign up for a free trial](https://www.confluent.io/confluent-cloud/tryfree?utm_campaign=tm.fm-ams_cd.Build-an-A[…]ne_id.701Uz00000fEQeEIAW&utm_source=zoom&utm_medium=workshop)
- **Databricks account** and existing workspace - paid or [free edition account](https://login.databricks.com/?intent=SIGN_UP&provider=DB_FREE_TIER) are strongly recommended. [Free trial account](https://docs.databricks.com/aws/en/getting-started/express-setup) sometimes experience data syncing issues with this workshop, so we recommend that you use **paid** or **free edition** accounts instead.
- **AWS account** with permissions to create cloud resources (EC2, S3, VPC, IAM)

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

Once you have the required tools installed and configured, then perform these steps:

### Windows Users

> [!IMPORTANT]
> **Instructions for Windows Users: Use WSL 2 with Ubuntu for Best Results**
>
> If you're on Windows, please expand the section below to learn what setup we recommend, common pitfalls to avoid, and tips and tricks.

<details>
<summary>Expand for Windows-specific instructions</summary>

We strongly recommend running this workshop from within **WSL 2** (Windows Subsystem for Linux) with **Ubuntu** rather than PowerShell or Command Prompt. This avoids Docker volume permission issues that can prevent Terraform from writing files.

**Setup Instructions:**

1. Install Ubuntu in WSL 2 (run in PowerShell as Admin):

   ```powershell
    wsl --install -d Ubuntu
    ```

2. Restart your computer if prompted, then open **Ubuntu** from the Start menu
3. Open Docker Desktop → **Settings** → **Resources** → **WSL Integration** → Enable **Ubuntu**
4. In the Ubuntu terminal, clone the repo and navigate to it:

   ```sh
   cd ~
   git clone https://github.com/confluentinc/workshop-tableflow-databricks.git
   cd workshop-tableflow-databricks/terraform
   ```

   ⚠️ **Important:** Verify you're in the **Linux filesystem**, not the mounted Windows drive:

   ```sh
   pwd
   ```

   - ✅ **Correct:** `/home/<username>/workshop-tableflow-databricks/terraform`
   - ❌ **Wrong:** `/mnt/c/Users/...` (this will cause permission errors!)

   If you see `/mnt/c/...`, run `cd ~` and clone the repo again.

5. Run all `docker compose` commands from this Ubuntu terminal (use `sudo -E` if you get permission errors):

   ```sh
   sudo -E docker compose build
   sudo -E docker compose run --rm terraform
   ```

   The `-E` flag preserves your environment variables (like AWS credentials) when using sudo.

**Tip:**

To avoid typing `sudo -E` every time, add your user to the docker group:

```sh
sudo usermod -aG docker $USER
```

Then close and reopen Ubuntu for the change to take effect.

**Why WSL?** Docker on Windows with WSL 2 has full write permissions to the Linux filesystem (`~/`) but limited permissions to Windows paths (`/mnt/c/...`). Running from within WSL can help avoid "permission denied" errors for some terraform commands, like `terraform init`.

</details>

## Step 1: Clone this Repository

Get started by cloning the workshop repository

1. Open your preferred command-line interface, like *zsh* or *Powershell*
2. Clone this repository with git:

   ```sh
   git clone https://github.com/confluentinc/workshop-tableflow-databricks.git
   ```

## Step 2: Pull and Build Docker Images

You will use a Docker container to run Terraform, ensuring consistent behavior across all operating systems (macOS, Linux, Windows). This container includes Terraform, AWS CLI, and SSH tools needed for infrastructure provisioning.

First, open your terminal and navigate into the workshop directory:

```sh
cd workshop-tableflow-databricks
```

Next, navigate into the *terraform* directory

```sh
cd terraform
```

Build the Terraform container (this is a one-time setup):

```sh
docker-compose build
```

You should see output showing the container being built:

```sh
[+] Building 45.2s (7/7) FINISHED
 => [terraform internal] load build definition from Dockerfile
 => ...
 => => naming to docker.io/library/workshop-terraform:latest
```

Next, you need to pull down the data generator (ShadowTraffic) docker image by following these steps:

1. Open a new shell window/tab in the workshop root directory
2. Pull down the ShadowTraffic docker image

   ```sh
   docker pull shadowtraffic/shadowtraffic:1.11.13
   ```

> [!NOTE]
> **First-Time Build**
>
> The initial pull and build may take a few minutes. Subsequent uses leverage cached layers and should complete in seconds.

**You can continue on with the workshop while the docker images are pulled down.**

## What's Next

Continue to **[LAB 1: Account Setup](../LAB1_account_setup/LAB1.md)**.

## Troubleshooting

See the [Troubleshooting](../../shared/troubleshooting.md) guide for common issues and solutions.
