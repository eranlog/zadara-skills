---
name: ssh-ccvm
description: Use when needing to SSH into the CCVM on any Zadara QA storage cloud (QA8, QA11, QA14, QA27, etc.). CCVM is isolated on the management network and hosts two applications — Command Center (cloud management UI) and eCommerce/Provisioning Portal (tenant self-service). Unreachable without going through the CCMaster jump host first.
---

# SSH to CCVM

## Overview

CCVM is a virtual machine on the isolated management network of any QA storage cloud. It hosts:
- **Command Center** — cloud/VPSA management UI
- **eCommerce (Provisioning Portal)** — tenant self-service portal

**CCVM is never reachable directly.** Always SSH through the cloud's CCMaster first.

## Connection Chain

```
Windows
  └─► CCMaster (<ccmaster-ip>, port 22, zadara/zadara)
        └─► CCVM (<ccvm-ip>, port 2022, zadministrator/Z@darA2o11)
```

**Convention:** CCMaster always ends in `1`, CCVM always ends in `0` — same subnet, adjacent IPs.
- CCMaster = `172.16.x.y**1**` → CCVM = `172.16.x.y**0**`
- Example: CCMaster=`172.16.7.121` → CCVM=`172.16.7.120`

So given any CCMaster IP, the CCVM IP is always `CCMaster IP - 1`.

## Known QA Clouds

| Cloud  | CCMaster IP   | CCVM IP       | CCMaster Hostkey |
|--------|---------------|---------------|------------------|
| QA8    | 172.16.7.121  | 172.16.7.120  | `SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ` |
| QA11   | 172.16.7.151  | 172.16.7.150  | (look up on first connect) |
| QA14   | 172.16.7.191  | 172.16.7.190  | (look up on first connect) |
| QA27   | 172.16.7.221  | 172.16.7.220  | (look up on first connect) |

> If the hostkey is unknown, run: `"C:\Program Files\PuTTY\plink.exe" -pw zadara zadara@<ccmaster-ip> "hostname"` — plink will print the fingerprint.

## SSH Commands (Windows — plink.exe required)

> OpenSSH fails non-interactively on Windows. Always use `C:\Program Files\PuTTY\plink.exe`.

### Run a command on CCVM

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<ccmaster-hostkey>" `
  zadara@<ccmaster-ip> `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadministrator@<ccvm-ip> '<command>'"
```

### Get root shell on CCVM

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<ccmaster-hostkey>" `
  zadara@<ccmaster-ip> `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadministrator@<ccvm-ip> 'echo Z@darA2o11 | sudo -S -i'"
```

## CCVM Credentials (all clouds)

| Item     | Value            |
|----------|------------------|
| Port     | `2022`           |
| User     | `zadministrator` |
| Password | `Z@darA2o11`     |

## Applications

### Command Center
- URL: `http://<ccvm-ip>:8888` (use IP — hostname fails in headless browsers)
- Login: `qa@zadarastorage.com` / `1q2w3e4r`
- Rails app: `/var/lib/zadara/command-center`
- Sync: `rake sync` (run from `/var/lib/zadara/command-center`)

### eCommerce (Provisioning Portal)
- URL: `https://<ccvm-ip>`
- Login: `admin` / `1q2w3e4r`
- Rails app: `/var/lib/zadara/ecommerce-rails`

## Database Access

```bash
# On CCVM as root:
psql command-center zadara
psql ecommerce-rails zadara
```

## Common Issues

| Issue | Fix |
|---|---|
| "Connection refused" on CCMaster | Floating IP moved after failover — get new hostkey from active SN |
| Host key mismatch | Run plink without `-hostkey` to see new fingerprint, then retry with it |
| Can't reach CCVM directly | Expected — CCVM is on isolated mgmt network, must go via CCMaster |
| OpenSSH fails | Use plink.exe — OpenSSH has key negotiation issues with older SSH on QA hosts |
| sudo prompt | Always pipe password: `echo Z@darA2o11 \| sudo -S -i` |
