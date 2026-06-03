Use when an IO server needs to be connected to a QA8 VPSA volume for the first time and vpsa_linux.sh is not available or not desired.

## Overview

Two phases:
1. **Server registration** — run `vpsa_linux.sh` on the client to register it with the VPSA and establish iSCSI
2. **Volume attachment** — attach an existing VPSA volume to the registered server via `zadara_cfg`

## Arguments

- `vsa_id` — VPSA to connect to (e.g. `vsa-0000002e`)
- `server_ip` — client server management IP (e.g. `172.16.4.81`)
- `vol_name` — volume to attach (e.g. `volume-00000007`) — optional

## Phase 1 — Register server with VPSA

### Step 1 — Get VPSA frontend IP and API token

Get the frontend IP from the active VC:

```bash
# On the active VC:
ip addr show febond | grep "inet " | awk '{print $2}' | cut -d/ -f1
# → e.g. 10.2.8.22
```

Get an API token using the **`vpsa-api-key`** skill (needs a VPSA-local user — NOT `zadara_cloud_admin`):

```bash
TOKEN=$(curl -sk "https://10.2.8.22/api/token?user=admin&password=1q2w3e4r" \
  | grep -oE "<auth-token>[^<]+" | grep -oE "[^>]+$")
```

Or extract from a previously downloaded `vpsa_linux.sh`:

```bash
grep ACCESSKEY ~/vpsa_linux.sh | head -1
# ACCESSKEY="E39GIPFB9HQ5OZ5PH8J1-209"
```

### Step 2 — Run vpsa_linux.sh on the client server

SSH to the server (`zadara/zadara` via plink) and run:

```powershell
# Replace VPSA_IP and API_KEY with values from Step 1
$VPSA_IP = "10.2.8.22"
$API_KEY  = "0X6O6PZI7L0O7SFP1ISN-769"

"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<server-hostkey>" `
  zadara@<server_ip> `
  "sudo wget -O ~/vpsa_linux.sh 'https://$VPSA_IP/api/servers/vpsa_linux.sh?iscsi=yes&fc=no&nvme=no&connection_ip=$VPSA_IP' --header='X-Access-Key:$API_KEY' --no-check-certificate && sudo chmod u+x ~/vpsa_linux.sh"
```

### Step 3 — Run the script (interactive IP selection)

The script lists all IPs on the server and prompts for a selection:

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<server-hostkey>" `
  zadara@<server_ip> `
  "echo <frontend-ip-index> | sudo ~/vpsa_linux.sh"
```

**Select the `10.2.8.x` frontend IP index** (not 172.16.x or other management IPs).

Expected output confirms success:
```
create server (<hostname>, IQN iqn.xxx, IP 10.2.8.x): status 0
register server (...): status 0
New interface zadara_10.2.8.22 added
Login to [iface: zadara_10.2.8.22, target: iqn.2011-04.com.zadara:...] successful.
```

### Step 4 — Get the new server name from the VPSA

```bash
# On the active VC:
/var/lib/zadara/bin/zadara_cfg list_servers 2>&1
# → returns srv-00000XXX — use the last one (highest ID = newest)
```

## Phase 2 — Attach volume to the server

### Step 5 — Attach

```bash
# On the active VC:
/var/lib/zadara/bin/zadara_cfg attach_volume \
  --servername <srv-name> \
  --volname <vol-name> \
  --accesstype ISCSI 2>&1
# → <attach-volume-response><status type="integer">0</status>
```

### Step 6 — Verify on the server

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<server-hostkey>" `
  zadara@<server_ip> `
  "lsblk -d -o NAME,SIZE,TYPE,VENDOR,MODEL | grep -v loop"
```

Expected: a new disk with `VENDOR=Zadara` and `MODEL=VPSA`.

## Known QA8 IO servers

| Server | Mgmt IP | Frontend IP | plink hostkey |
|--------|---------|-------------|---------------|
| ubuntu1804temp (VM81) | 172.16.4.81 | 10.2.8.81 | SHA256:f2sHQLeyv335gIApbgXqcciM/BFiBFHiGHY59wBaicI |
| bm217 (srv217) | 172.16.0.217 | 10.2.8.217 | SHA256:LUKNQ0AVReEzR2UuU5aHZf6H7emopdgTcih88UmcNbI |

## Known VPSAs on QA8

| VPSA | vsa_id | Active VC mgmt IP | Frontend IP | Type |
|------|--------|-------------------|-------------|------|
| H101 | vsa-0000002e | 10.0.8.22 | 10.2.8.22 | V3.H100 |
| YAMBA6 | vsa-00000035 | 10.0.8.35 | 10.2.8.35 | V2.medium |

## Notes

- **Never use manual iscsiadm** — VPSA iSCSI requires specific CHAP/ACL config that only `vpsa_linux.sh` sets up correctly. Manual attempts always fail with error 24 (authorization failure).
- **Block volumes only** need `--accesstype ISCSI`; NAS volumes use `--accesstype NFS`.
- If `create_volume` fails with "Data reduction bundle is disabled", add `--compress NO --dedupe NO`.
- The `vpsa_linux.sh` script is idempotent — running it again on an already-registered server updates the existing record.
