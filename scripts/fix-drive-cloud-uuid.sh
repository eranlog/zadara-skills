#!/bin/bash
# Fix stale cloud_uuid LVM VG tags on a Storage Node so drives become visible in CC.
# Usage: fix-drive-cloud-uuid.sh <stale_uuid> <correct_uuid>
# Run as root on the affected SN.
# Get stale_uuid from: vgs --noheadings -o vg_name,vg_tags | grep zadara
# Get correct_uuid from: zconfig.py --get cloud.uuid

STALE_UUID="$1"
CORRECT_UUID="$2"

if [ -z "$STALE_UUID" ] || [ -z "$CORRECT_UUID" ]; then
    echo "Usage: $0 <stale_uuid> <correct_uuid>"
    echo "  stale_uuid:   from 'vgs -o tags | grep cloud_uuid'"
    echo "  correct_uuid: from 'zconfig.py --get cloud.uuid'"
    exit 1
fi

echo "==> Removing stale cloud_uuid tag: $STALE_UUID"
vgchange --deltag "cloud_uuid+${STALE_UUID}"

echo "==> Adding correct cloud_uuid tag: $CORRECT_UUID"
for vg in $(vgs --noheadings -o vg_name 2>/dev/null | tr -d ' ' | grep zadara); do
    vgchange --addtag "cloud_uuid+${CORRECT_UUID}" "$vg"
done

echo "==> Restarting zadara-sn service"
service zadara-sn restart

echo "==> Verifying"
service zadara-sn status --no-pager | head -5
zadara_sncfg get_qosgroups_xml 2>&1 | grep -c "<drive>" && echo "drives visible to nova"
