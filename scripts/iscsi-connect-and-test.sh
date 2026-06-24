#!/bin/bash
# Discover, connect, and IO-test an iSCSI volume from a Linux client.
# Usage: iscsi-connect-and-test.sh <vpsa_bebond_ip>
# Run as root on the iSCSI client server (not on the VPSA).
# Assumes volume is already attached to the server in VPSA.

BEBOND_IP="$1"

if [ -z "$BEBOND_IP" ]; then
    echo "Usage: $0 <vpsa_bebond_ip>"
    exit 1
fi

echo "==> Discovering iSCSI targets at $BEBOND_IP"
iscsiadm -m discovery -t sendtargets -p "$BEBOND_IP"

echo "==> Logging in to all discovered targets"
iscsiadm -m node --loginall=all

echo "==> Connected block devices:"
lsblk | grep sd

echo ""
echo "To run IO test (replace /dev/sdX with the device above):"
echo "  dd if=/dev/urandom of=/dev/sdX bs=1M count=100 oflag=direct"
