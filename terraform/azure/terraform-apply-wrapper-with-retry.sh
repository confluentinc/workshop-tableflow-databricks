#!/bin/bash
# Terraform Apply Wrapper with Retry (Azure)
# Handles transient errors common in Azure deployments:
# - Azure RBAC propagation delays (role assignments take time to replicate)
# - Databricks API 500 errors during workspace initialization
# - Azure AD service principal propagation delays

set -e

MAX_RETRIES=6
RETRY_DELAY=15
ATTEMPT=1

echo "🚀 Starting Terraform apply with retry logic (max ${MAX_RETRIES} attempts)..."
echo ""

while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Attempt ${ATTEMPT} of ${MAX_RETRIES}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if terraform apply -auto-approve "$@"; then
        echo ""
        echo "✅ Terraform apply succeeded on attempt ${ATTEMPT}!"
        exit 0
    fi

    EXIT_CODE=$?
    echo ""
    echo "⚠️  Terraform apply failed on attempt ${ATTEMPT} (exit code: ${EXIT_CODE})"

    if [ $ATTEMPT -lt $MAX_RETRIES ]; then
        echo "⏳ Waiting ${RETRY_DELAY} seconds before retry..."
        echo "   (Azure RBAC and AAD propagation can take 60-120 seconds)"
        sleep $RETRY_DELAY
    fi

    ATTEMPT=$((ATTEMPT + 1))
done

echo ""
echo "❌ Terraform apply failed after ${MAX_RETRIES} attempts."
echo ""
echo "Common causes:"
echo "  1. Azure RBAC role assignments not yet propagated (wait a few minutes and retry)"
echo "  2. Databricks workspace still initializing (try again in 5 minutes)"
echo "  3. Azure AD service principal not yet visible (wait and retry)"
echo "  4. Confluent Cloud Enterprise cluster provisioning (can take 10-15 minutes)"
echo ""
echo "To retry: docker-compose run --rm terraform -c './terraform-apply-wrapper-with-retry.sh'"
exit 1
