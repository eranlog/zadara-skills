#!/bin/bash
# Reproduce the double-restore race condition (ZSTRG-37843).
# Hibernates the VPSA then fires two simultaneous restore requests to simulate UI double-click.
# Usage: vpsa-double-restore-race.sh <vsa-numeric-id> <tenant_id>
# Run as root on CCMaster.

VSA_ID="$1"
TENANT_ID="$2"

if [ -z "$VSA_ID" ] || [ -z "$TENANT_ID" ]; then
    echo "Usage: $0 <vsa-numeric-id> <tenant_id>"
    exit 1
fi

echo "==> Step 1: Hibernating VPSA $VSA_ID"
nova-manage vsa hibernate --id="$VSA_ID"

echo "==> Waiting for hibernated status..."
for i in $(seq 1 30); do
    STATUS=$(nova-manage vsa list --id="$VSA_ID" 2>/dev/null | awk 'NR>1 && $1~/^[0-9]+$/ {print $10}')
    echo "  status: $STATUS"
    [ "$STATUS" = "hibernated" ] && break
    sleep 10
done

echo "==> Step 2: Firing two simultaneous restores"
nova-manage vsa restore --id="$VSA_ID" --tenant_id "$TENANT_ID" --user admin &
nova-manage vsa restore --id="$VSA_ID" --tenant_id "$TENANT_ID" --user admin &
wait

echo "==> Step 3: Checking result after 30s"
sleep 30
nova-manage vsa list --id="$VSA_ID" --all 2>/dev/null

echo ""
echo "Expected (FIXED): status=created, exactly 2 instances (vc-0 + vc-1)"
echo "Bug result (UNFIXED): status=failed, two vc-0 instances on different SNs"
