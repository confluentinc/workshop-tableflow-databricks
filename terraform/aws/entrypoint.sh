#!/bin/bash
# Entrypoint script for Terraform Workshop container
#
# AWS Credentials Priority:
#   1. Environment variables (AWS_ACCESS_KEY_ID, etc.) - highest priority
#   2. Host machine's ~/.aws directory (mounted at /root/.aws-host)
#   3. Local ./aws-config directory (mounted at /root/.aws-local)

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

setup_aws_credentials() {
    # Priority 1: Environment variables
    if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" ]]; then
        echo -e "${GREEN}✓ Using AWS credentials from environment variables${NC}"
        return 0
    fi

    # Priority 2: Host machine's ~/.aws (mounted at /root/.aws-host)
    if [[ -f "/root/.aws-host/credentials" ]] || [[ -f "/root/.aws-host/config" ]]; then
        echo -e "${GREEN}✓ Using AWS credentials from host machine (~/.aws)${NC}"
        # Create symlink so AWS CLI/Terraform can find credentials
        rm -rf /root/.aws 2>/dev/null || true
        ln -sf /root/.aws-host /root/.aws
        return 0
    fi

    # Priority 3: Local ./aws-config (mounted at /root/.aws-local)
    if [[ -f "/root/.aws-local/credentials" ]] || [[ -f "/root/.aws-local/config" ]]; then
        echo -e "${GREEN}✓ Using AWS credentials from local ./aws-config directory${NC}"
        rm -rf /root/.aws 2>/dev/null || true
        ln -sf /root/.aws-local /root/.aws
        return 0
    fi

    # No credentials found - set up local directory for 'aws configure'
    echo -e "${YELLOW}⚠ No AWS credentials found${NC}"
    echo ""
    echo "To configure AWS credentials, choose one option:"
    echo ""
    echo "  Option 1: Use host machine credentials"
    echo "    Run 'aws configure' on your HOST machine, then restart the container"
    echo ""
    echo "  Option 2: Configure inside container (persistent)"
    echo "    Run 'aws configure' now - credentials saved to ./aws-config/"
    echo ""
    echo "  Option 3: Set environment variables"
    echo "    export AWS_ACCESS_KEY_ID=your-key"
    echo "    export AWS_SECRET_ACCESS_KEY=your-secret"
    echo "    export AWS_DEFAULT_REGION=us-east-2"
    echo ""

    # Set up local directory for 'aws configure' to use
    mkdir -p /root/.aws-local
    rm -rf /root/.aws 2>/dev/null || true
    ln -sf /root/.aws-local /root/.aws
    return 1
}

# Set up AWS credentials
setup_aws_credentials
AWS_SETUP_RESULT=$?

# If running interactive shell or no arguments, just start bash
if [[ $# -eq 0 ]]; then
    exec /bin/bash
fi

# If running a command (e.g., -c "terraform init"), execute it
exec /bin/bash "$@"
