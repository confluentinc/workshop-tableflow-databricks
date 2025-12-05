# Terraform Workshop Container
# Provides consistent environment across macOS, Linux, and Windows
#
# This container includes all tools needed for the workshop:
# - Terraform for infrastructure provisioning
# - AWS CLI for IAM policy updates
# - SSH client for EC2 health checks
# - Bash for reliable script execution
#
# AWS Credentials Priority:
#   1. Environment variables (AWS_ACCESS_KEY_ID, etc.)
#   2. Host machine's ~/.aws directory
#   3. Local ./aws-config directory

FROM hashicorp/terraform:1.14

# Install additional tools needed for provisioners
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    openssh-client \
    aws-cli \
    python3 \
    py3-pip \
    groff \
    less \
    netcat-openbsd

# Set bash as default shell for reliable script execution
SHELL ["/bin/bash", "-c"]

# Create working directory
WORKDIR /workspace

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use entrypoint script to set up AWS credentials
ENTRYPOINT ["/entrypoint.sh"]
