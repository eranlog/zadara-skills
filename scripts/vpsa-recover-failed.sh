#!/bin/bash
# Recover a VPSA stuck in 'failed' state by forcing status through hibernate → restore cycle.
# Usage: vpsa-recover-failed.sh <vsa-id> <tenant_id>
# Run as root on CCMaster.
# Example: vpsa-recover-failed.sh 20 2

VSA_ID="$1"
TENANT_ID="$2"

if [ -z "$VSA_ID" ] || [ -z "$TENANT_ID" ]; then
    echo "Usage: $0 <vsa-numeric-id> <tenant_id>"
    echo "  vsa-numeric-id: the ID column from nova-manage vsa list"
    echo "  tenant_id:      from nova-manage vsa list drive output"
    exit 1
fi

echo "==> Forcing VPSA $VSA_ID to 'created'"
nova-manage vsa update --id="$VSA_ID" --status=created

echo "==> Hibernating"
nova-manage vsa hibernate --id="$VSA_ID"

echo "==> Waiting for hibernated (checking every 10s)..."
for i in $(seq 1 30); do
    STATUS=$(nova-manage vsa list --id="$VSA_ID" 2>/dev/null | awk 'NR>1 && $1~/^[0-9]+$/ {print $10}')
    echo "  status: $STATUS"
    [ "$STATUS" = "hibernated" ] && break
    # If stuck in hibernate_offlining, force it
    if [ "$STATUS" = "hibernate_offlining" ] && [ "$i" -gt 10 ]; then
        echo "  ==> Stuck in hibernate_offlining — forcing to hibernated"
        nova-manage vsa update --id="$VSA_ID" --status=hibernated
        break
    fi
    sleep 10
done

echo "==> Restoring"
nova-manage vsa restore --id="$VSA_ID" --tenant_id "$TENANT_ID" --user admin

echo "==> Done. Monitor with: nova-manage vsa list --id=$VSA_ID --all"
