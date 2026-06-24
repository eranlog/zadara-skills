---
name: zstorage-ipsec
description: Use when configuring or troubleshooting IPsec between a VPSA and an iSCSI client — strongSwan transport mode IKEv1 PSK setup, SA verification, tcpdump traffic confirmation, or Phase 2 failure debugging. Includes QA8 H101 reference values (PSK, IPs, server name).
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
  bebond: 10.2.8.33                          storage NIC: 10.2.8.223
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

Log into the VPSA GUI at `https://<bebond_ip>` with admin credentials. Go to **admin → RESET ACCESS KEY**.

Or retrieve it from the DB on the VC:
```bash
mysql -u activeGui -p4zV5lCBTbp vsa_gui_4 -e "SELECT authentication_token FROM users WHERE username='admin';"
```

---

## Step 2 — Get the VPSA PSK

**Run on VPSA VC (from CCMaster via sshpass, port 2022):**

```bash
cat /sys/kernel/zadara-utils/safe/ipsecsecret
# Output: : PSK "B9A052CE851F4185AF255A02514F3612"
```

The PSK is used for both sides.

---

## Step 3 — Add server to VPSA with IPsec enabled

**Run from any SN with curl access to VPSA novabridge IP (10.0.8.x):**

```bash
# Add server with iSCSI IP and IPsec enabled
curl -sk "https://<vpsa_nova_ip>/api/servers.json?access_key=<key>" \
  -X POST \
  -d "display_name=<name>&iqn=<iqn>&iscsi=<server_storage_ip>&ipsec_iscsi=YES"
# Returns: {"response":{"server_name":"srv-00000001","status":0}}

# Verify IPsec is enabled and IP is set
curl -sk "https://<vpsa_nova_ip>/api/servers/srv-00000001.json?access_key=<key>"
# Check: "iscsi_ip":"10.2.8.223","ipsec_iscsi":"1"
```

VPSA automatically creates `/sys/kernel/zadara-utils/safe/ipsecconf_<server_name>`:
```
conn <server_name>__iscsi
    leftprotoport=tcp/3260
    right=<server_storage_ip>
```

This is included by `/etc/ipsec.conf` via `include /sys/kernel/zadara-utils/safe/ipsecconf_*`.

---

## Step 4 — Configure strongSwan on client server

**Install (on client server — NOT on QA8 SNs):**
```bash
apt-get install -y strongswan
```

**Write `/etc/ipsec.conf`:**
```
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

conn vpsa-<name>
    left=<server_storage_ip>      # e.g. 10.2.8.223
    leftprotoport=tcp
    right=<vpsa_bebond_ip>        # e.g. 10.2.8.33
    rightprotoport=tcp/3260
    auto=start
```

**Write `/etc/ipsec.secrets` (chmod 600):**
```
: PSK "<psk_from_step_2>"
```

**Start:**
```bash
systemctl restart strongswan-starter
```

---

## Step 5 — Verify SA establishment

**On client server:**
```bash
ipsec status
# Expected:
# Security Associations (1 up, 0 connecting):
#    vpsa-h101[1]: ESTABLISHED 3 seconds ago, 10.2.8.223[10.2.8.223]...10.2.8.33[10.2.8.33]
#    vpsa-h101{1}:  INSTALLED, TRANSPORT, reqid 1, ESP SPIs: cb36f153_i ce686fdf_o
#    vpsa-h101{1}:   10.2.8.223/32[tcp] === 10.2.8.33/32[tcp/iscsi-target]
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
tcpdump -i vlan50 -nn host <vpsa_bebond_ip>
# Should show: ESP packets (proto 50), NOT plaintext iSCSI (port 3260 in clear)
```

For Wireshark capture:
```bash
tcpdump -i vlan50 -w /tmp/ipsec_capture.pcap host <vpsa_bebond_ip> -c 100
# Copy pcap to Windows and open in Wireshark
# Filter: esp    → all packets should be ESP
# Filter: iscsi  → should show NOTHING (traffic is encrypted)
```

---

## QA8 reference values (VPSA 4 / H101)

| Item | Value |
|------|-------|
| VPSA novabridge | 10.0.8.33 |
| VPSA bebond (storage) | 10.2.8.33 |
| server223 storage IP | 10.2.8.223 |
| PSK | B9A052CE851F4185AF255A02514F3612 |
| Admin access key | TMY1JQLYRMSJJO5JI78E-3 |
| Server name | srv-00000002 |

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
