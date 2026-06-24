#!/bin/bash
# Configure strongSwan IPsec on an iSCSI client server.
# Usage: ipsec-client-setup.sh <client_storage_ip> <vpsa_bebond_ip> <vpsa_name> <psk>
# Run as root on the iSCSI client server (not on the VPSA).
# Get PSK from VC: cat /sys/kernel/zadara-utils/safe/ipsecsecret

CLIENT_IP="$1"
VPSA_BEBOND="$2"
VPSA_NAME="$3"
PSK="$4"

if [ -z "$CLIENT_IP" ] || [ -z "$VPSA_BEBOND" ] || [ -z "$VPSA_NAME" ] || [ -z "$PSK" ]; then
    echo "Usage: $0 <client_storage_ip> <vpsa_bebond_ip> <vpsa_name> <psk>"
    echo "  Example: $0 10.2.8.223 10.2.8.25 myvpsa 'mysecretpsk'"
    exit 1
fi

echo "==> Installing strongSwan"
apt-get install -y strongswan

echo "==> Writing /etc/ipsec.conf"
cat > /etc/ipsec.conf <<EOF
config setup
    strictcrlpolicy=no
    uniqueids=yes

conn %default
    ike=aes128-sha1-modp1024!
    esp=aes128-sha1!
    ikelifetime=3h
    lifetime=1h
    margintime=9m
    keyexchange=ikev1
    keyingtries=1
    rekey=no
    reauth=yes
    dpdaction=clear
    dpddelay=30s
    dpdtimeout=150s
    type=transport
    leftauth=psk
    rightauth=psk
    aggressive=no

conn vpsa-${VPSA_NAME}
    left=${CLIENT_IP}
    leftprotoport=tcp
    right=${VPSA_BEBOND}
    rightprotoport=tcp/3260
    auto=start
EOF

echo "==> Writing /etc/ipsec.secrets"
echo ": PSK \"${PSK}\"" > /etc/ipsec.secrets
chmod 600 /etc/ipsec.secrets

echo "==> Starting strongSwan"
systemctl restart strongswan-starter

echo "==> Verifying SA (wait a few seconds for IKE negotiation)"
sleep 5
ipsec status
