#!/bin/bash
# Entrypoint script for Terraform Workshop container (Azure)
#
# Azure Credentials Priority:
#   1. Service principal env vars (ARM_CLIENT_ID, etc.) - highest priority
#   2. Host machine's ~/.azure directory (mounted at /root/.azure-host)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

setup_azure_credentials() {
    # Priority 1: Service principal environment variables
    if [[ -n "$ARM_CLIENT_ID" && -n "$ARM_CLIENT_SECRET" && -n "$ARM_TENANT_ID" ]]; then
        echo -e "${GREEN}✓ Using Azure credentials from service principal environment variables${NC}"
        return 0
    fi

    # Priority 2: Host machine's ~/.azure (mounted at /root/.azure-host)
    if [[ -d "/root/.azure-host" ]] && [[ -f "/root/.azure-host/azureProfile.json" ]]; then
        echo -e "${GREEN}✓ Using Azure credentials from host machine (~/.azure)${NC}"
        rm -rf /root/.azure 2>/dev/null || true
        ln -sf /root/.azure-host /root/.azure
        return 0
    fi

    # No credentials found
    echo -e "${YELLOW}⚠ No Azure credentials found${NC}"
    echo ""
    echo "To configure Azure credentials, choose one option:"
    echo "  Option 1: Run 'az login' on your HOST machine before starting the container"
    echo "  Option 2: Set service principal env vars: ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID"
    echo ""
    return 1
}

setup_azure_credentials
AZURE_SETUP_RESULT=$?

if [[ $# -eq 0 ]]; then
    exec /bin/bash
fi

exec /bin/bash "$@"
