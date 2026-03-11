# Terraform Workshop Container (Azure)
# Provides consistent environment across macOS, Linux, and Windows
#
# This container includes all tools needed for the workshop:
# - Terraform for infrastructure provisioning
# - Azure CLI for authentication and resource management
# - PostgreSQL client for database setup
# - Bash for reliable script execution
#
# Azure Credentials:
#   1. Host machine's ~/.azure directory (from `az login`)
#   2. Service principal env vars (ARM_CLIENT_ID, etc.)

FROM hashicorp/terraform:1.14

# Install additional tools needed for provisioners
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    openssh-client \
    python3 \
    py3-pip \
    netcat-openbsd \
    postgresql16-client

# Install Azure CLI
RUN pip3 install --break-system-packages azure-cli

# Set bash as default shell
SHELL ["/bin/bash", "-c"]

WORKDIR /workspace

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
