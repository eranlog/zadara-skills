---
name: ssh-ccvm
description: Use when needing to SSH into the CCVM on a Zadara QA cloud. CCVM is isolated on the management network and hosts two applications — Command Center (cloud management UI) and eCommerce/Provisioning Portal (tenant self-service). Unreachable without going through the CCMaster jump host first.
---

# SSH to CCVM

## Overview

CCVM is a virtual machine on the isolated management network (`172.16.7.x`). It hosts:
- **Command Center** — cloud/VPSA management UI
- **eCommerce (Provisioning Portal)** — tenant self-service portal

**CCVM is never reachable directly.** Always SSH through CCMaster first.

## Connection Chain

```
Windows
  └─► CCMaster (172.16.7.121, port 22, zadara/zadara)
        └─► CCVM (172.16.7.120, port 2022, zadministrator/Z@darA2o11)
```

## SSH Commands (Windows — plink.exe required)

> OpenSSH fails non-interactively on Windows. Always use `C:\Program Files\PuTTY\plink.exe`.

### Run a command on CCVM

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<ccmaster-hostkey>" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadministrator@172.16.7.120 '<command>'"
```

### Get root shell on CCVM

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<ccmaster-hostkey>" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadministrator@172.16.7.120 'echo Z@darA2o11 | sudo -S -i'"
```

## QA8 Reference

| Item | Value |
|---|---|
| CCMaster floating IP | `172.16.7.121` |
| CCMaster hostkey (qa8-sn2) | `SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ` |
| CCVM IP | `172.16.7.120` |
| CCVM port | `2022` |
| CCVM user | `zadministrator` |
| CCVM password | `Z@darA2o11` |

## Applications

### Command Center
- URL: `http://172.16.7.120:8888` (use IP — hostname fails in headless browsers)
- Login: `qa@zadarastorage.com` / `1q2w3e4r`
- Rails app: `/var/lib/zadara/command-center`
- Sync: `rake sync` (run from `/var/lib/zadara/command-center`)

### eCommerce (Provisioning Portal)
- URL: `https://172.16.7.120`
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
| "Connection refused" on 172.16.7.121 | CCMaster floating IP moved after failover — get new hostkey from active SN |
| Host key mismatch | Run `plink -batch -pw zadara zadara@172.16.7.121 "hostname"` to get new fingerprint |
| Can't reach CCVM directly | Expected — CCVM is on isolated mgmt network, must go via CCMaster |
| OpenSSH fails | Use plink.exe — OpenSSH has key negotiation issues with older SSH on QA hosts |
| sudo prompt | Always pipe password: `echo Z@darA2o11 \| sudo -S -i` |
