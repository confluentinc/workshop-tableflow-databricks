#!/bin/bash
# ===============================
# Terraform Apply with Retry Logic
# ===============================
# This wrapper script handles transient errors that can occur during
# Terraform apply, particularly with Databricks external location creation.
#
# The Databricks API may return 500 Internal Server errors during external
# location creation due to IAM trust policy propagation delays. This script
# automatically retries the apply to handle these transient failures.
#
# Usage:
#   ./terraform-apply-wrapper-with-retry.sh
#
# Configuration:
#   MAX_RETRIES=6    - Maximum number of apply attempts
#   RETRY_DELAY=30   - Seconds between retry attempts

set -o pipefail

# ===============================
# Configuration
# ===============================
MAX_RETRIES=6
RETRY_DELAY=30  # seconds between retries

# ===============================
# Colors for output
# ===============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ===============================
# Helper Functions
# ===============================
print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_separator() {
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────────${NC}"
}

countdown() {
    local seconds=$1
    for ((i=seconds; i>0; i--)); do
        printf "\r   ⏳ Retrying in %3d seconds... " $i
        sleep 1
    done
    echo ""
}

# ===============================
# Main Script
# ===============================
print_header "🚀 Terraform Apply with Retry Logic"

echo ""
echo -e "   ${BLUE}Configuration:${NC}"
echo -e "   • Max Retries:  ${YELLOW}$MAX_RETRIES${NC}"
echo -e "   • Retry Delay:  ${YELLOW}${RETRY_DELAY}s${NC}"
echo ""
echo -e "   ${BLUE}Why this script exists:${NC}"
echo -e "   Databricks external location creation may fail with a transient"
echo -e "   500 Internal Server error due to IAM trust policy propagation"
echo -e "   delays. This script automatically retries to handle these failures."
echo ""

for attempt in $(seq 1 $MAX_RETRIES); do
    print_separator
    echo -e "${YELLOW}🔄 Attempt $attempt of $MAX_RETRIES${NC}"
    print_separator
    echo ""

    # Run terraform apply
    if terraform apply -auto-approve; then
        echo ""
        print_header "✅ Terraform apply succeeded on attempt $attempt!"
        echo ""
        echo -e "${GREEN}All resources have been created successfully.${NC}"
        echo ""
        exit 0
    fi

    # Capture exit code
    exit_code=$?

    # Check if we should retry
    if [ $attempt -lt $MAX_RETRIES ]; then
        echo ""
        print_separator
        echo -e "${YELLOW}⚠️  Apply failed (exit code: $exit_code)${NC}"
        echo ""
        echo -e "   ${BLUE}Waiting before retry to allow for:${NC}"
        echo -e "   • IAM trust policy propagation"
        echo -e "   • Databricks internal state synchronization"
        echo -e "   • Transient API errors to resolve"
        echo ""
        countdown $RETRY_DELAY
    fi
done

# All retries exhausted
echo ""
print_header "❌ Terraform apply failed after $MAX_RETRIES attempts"
echo ""
echo -e "${RED}The apply operation did not succeed after maximum retries.${NC}"
echo ""
echo -e "${YELLOW}Troubleshooting steps:${NC}"
echo ""
echo "  1. Review the error messages above for specific issues"
echo ""
echo "  2. Check IAM role trust policy in AWS Console:"
echo "     - Verify the Databricks external ID is correct"
echo "     - Ensure the role allows sts:AssumeRole from Databricks"
echo ""
echo "  3. Verify Databricks storage credential status:"
echo "     - Go to Databricks → Catalog → External Data → Storage Credentials"
echo "     - Check if the credential shows any errors"
echo ""
echo "  4. Wait a few minutes and try again manually:"
echo "     terraform apply -auto-approve"
echo ""
echo "  5. Check the troubleshooting guide:"
echo "     ../labs/troubleshooting.md"
echo ""
exit 1
