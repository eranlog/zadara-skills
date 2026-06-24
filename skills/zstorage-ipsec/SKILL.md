---
name: zstorage-ipsec
description: Use when configuring or troubleshooting IPsec between a VPSA and an iSCSI client — strongSwan transport mode IKEv1 PSK setup, SA verification, tcpdump traffic confirmation, or Phase 2 failure debugging.
argument-hint: <vsa-id>
---

# zstorage-ipsec

Configure IPsec between a Zadara VPSA and an iSCSI client server. Uses strongSwan transport mode with IKEv1/AES128/PSK.

## When to use

- Enabling encrypted iSCSI between a VPSA and a storage client server
- Verifying IPsec SA establishment after configuration
- Troubleshooting IPsec connectivity issues

## Architecture

```
VPSA VC (strongSwan responder)          iSCSI Client (strongSwan initiator)
  bebond: <vpsa_bebond_ip>                   storage NIC: <client_storage_ip>
  leftprotoport=tcp/3260                     leftprotoport=tcp
         <======= IKEv1 transport mode ESP =======>
```

- Transport mode (not tunnel): only TCP payload is encrypted, IPs visible
- IKEv1 with PSK authentication
- ESP cipher: AES-128-CBC + HMAC-SHA1
- VPSA PSK stored in `/sys/kernel/zadara-utils/safe/ipsecsecret`
- Per-server config in `/sys/kernel/zadara-utils/safe/ipsecconf_<server_name>`

---

## Step 1 — Get VPSA API access key

Use [[vpsa-api-key]] skill to retrieve or rotate the API key. Or: VPSA GUI → admin → RESET ACCESS KEY.

---

## Step 2 — Get the VPSA PSK

**Run on VPSA VC (via CCMaster double-hop — see [[zstorage-ssh]]):**

```bash
# On the VC:
cat /sys/kernel/zadara-utils/safe/ipsecsecret
# Output: : PSK "<psk_value>"
```

The PSK is used for both sides.

---

## Step 3 — Add server to VPSA with IPsec enabled

**Run from any SN with curl access to the VPSA novabridge IP:**

```bash
# Add server with iSCSI IP and IPsec enabled
curl -sk "https://<vpsa_nova_ip>/api/servers.json?access_key=<key>" \
  -X POST \
  -d "display_name=<name>&iqn=<iqn>&iscsi=<client_storage_ip>&ipsec_iscsi=YES"
# Returns: {"response":{"server_name":"srv-00000001","status":0}}

# Verify IPsec is enabled and IP is set
curl -sk "https://<vpsa_nova_ip>/api/servers/srv-00000001.json?access_key=<key>"
# Check: "iscsi_ip":"<client_storage_ip>","ipsec_iscsi":"1"
```

VPSA automatically creates `/sys/kernel/zadara-utils/safe/ipsecconf_<server_name>`:
```
conn <server_name>__iscsi
    leftprotoport=tcp/3260
    right=<client_storage_ip>
```

This is included by `/etc/ipsec.conf` via `include /sys/kernel/zadara-utils/safe/ipsecconf_*`.

---

## Step 4 — Configure strongSwan on client server

Run `scripts/ipsec-client-setup.sh <client_storage_ip> <vpsa_bebond_ip> <vpsa_name> <psk>` as root on the client server.

The script installs strongSwan, writes `/etc/ipsec.conf` and `/etc/ipsec.secrets` with IKEv1/AES128/PSK transport mode config, starts the service, and runs `ipsec status`.

---

## Step 5 — Verify SA establishment

**On client server:**
```bash
ipsec status
# Expected: Security Associations (1 up, 0 connecting)
#   vpsa-<name>[1]: ESTABLISHED ... <client_storage_ip>...<vpsa_bebond_ip>
```

**On VPSA VC:**
```bash
ipsec status
ip xfrm state list    # shows active ESP SAs with AES keys
```

---

## Verify traffic is encrypted (tcpdump)

On the client server, while doing iSCSI IO or discovery:
```bash
tcpdump -i <storage_iface> -nn host <vpsa_bebond_ip>
# Should show: ESP packets (proto 50), NOT plaintext iSCSI (port 3260 in clear)
```

For Wireshark capture:
```bash
tcpdump -i <storage_iface> -w /tmp/ipsec_capture.pcap host <vpsa_bebond_ip> -c 100
# Copy pcap to Windows and open in Wireshark
# Filter: esp    → all packets should be ESP
# Filter: iscsi  → should show NOTHING (traffic is encrypted)
```

---

## Troubleshooting

**SA not establishing:**
- Check both sides can ping each other on the storage IPs
- Verify PSK matches exactly (case-sensitive)
- Check `journalctl -u strongswan-starter` on client
- On VPSA VC: `ipsec statusall` for IKE negotiation details
- `ip xfrm policy` to see if XFRM policies are in place

**SA established but traffic not encrypted:**
- Check `ip xfrm state` — should show active ESP SAs
- Verify iSCSI initiator uses the storage IP (not mgmt IP) to connect

**VPSA does not generate ipsecconf file:**
- Confirm server was added with `ipsec_iscsi=1` (not 0) and `iscsi_ip` is set
- The file is `/sys/kernel/zadara-utils/safe/ipsecconf_<server_name>` (by server name, not IP)
