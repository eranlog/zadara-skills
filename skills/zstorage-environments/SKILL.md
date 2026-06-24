---
name: zstorage-environments
description: Use when looking up QA lab environment specs — CCMaster/CCVM IPs for QA8/QA10/QA14, OpenStack API port mappings, cloud network CIDRs, hardware inventory, or default credentials across all QA environments.
---

# zstorage-environments

Reference for Zadara QA lab environments: cloud specs, API ports, CCMaster IPs, network CIDRs, and access patterns.

**Master reference (Google Sheet):** https://docs.google.com/spreadsheets/d/1S8jKSesAvo1BR9kBp88_KzUeJVHBfzmkLa05iUOVXdE/edit
**Confluence reference:** https://zadara.atlassian.net/wiki/x/F4DC6

## What is a QA Environment

Each QA environment is a full Zadara cloud instance with:
- 1–8 Storage Nodes (SNs) running nova-compute + zadara-sn services
- 1 CCVM (Command Center VM) running PostgreSQL + Rails CC
- 1 CCMaster floating IP across sn1/sn2 (HA pair)
- Isolated management network (10.0.x.y) + external MGMT IPs

## Access Pattern

All QA environments follow the same topology:
```
WSL/sshpass → CCMaster floating IP → CCVM (port 2022) / SNs
(Windows without WSL: plink.exe as fallback)
```

See [[zstorage-ssh]] skill for full connection recipes with hostkeys, credentials, and quoting tricks.

---

## Known CCMaster / CCVM IPs

| Cloud | CCMaster Float | CCVM | SN1 | SN2 | SN3 | SN4 |
|---|---|---|---|---|---|---|
| QA8  | 172.16.7.121 | 172.16.7.120 | 172.16.7.122 | 172.16.7.123 | 172.16.7.124 | 172.16.7.125 |
| QA10 | 172.16.7.141 | 172.16.7.140 | — | — | — | — |

---

## OpenStack API Port Forwarding

Public IP for most QA environments: **199.203.140.122**
Exceptions: QA13 → **62.90.65.7** | QA26 → **62.90.65.1**

All destination (internal) ports are standard: Nova→8775, Glance→9292, Keystone→35357, Auth→5000.

| Cloud | Nova (src) | Glance (src) | Keystone (src) | Auth (src) |
|---|---|---|---|---|
| QA1  | 8776 (HTTPS) | —    | —     | —    |
| QA3  | 8775         | 9293 | 35358 | 5001 |
| QA8  | 8788         | —    | 35371 | 5014 |
| QA13 | 8801         | —    | —     | —    |
| QA14 | 8787         | 9302 | 35370 | 5013 |
| QA26 | 8797         | —    | —     | —    |

**Full port table for all QA1–QA33:** see Google Sheet above.

### URL Templates
```
Nova:     https://<public_ip>:<nova_src>/v1.1/
Auth:     http://<public_ip>:<auth_src>/v2.0/
Keystone: http://<public_ip>:<keystone_src>/v2.0/
```

### QA8 URLs
```
Nova:     https://199.203.140.122:8788/v1.1/
Auth:     http://199.203.140.122:5014/v2.0/
Keystone: http://199.203.140.122:35371/v2.0/
API key:  j9PdqWwPYAi4P8pDcq8Y  (admin user)
```

### QA14 URLs
```
Nova:     https://199.203.140.122:8787/v1.1/
Auth:     http://199.203.140.122:5013/v2.0/
Keystone: http://199.203.140.122:35370/v1.1/
API key:  86ed30ea-d371-44c2-86ea-092ff8cfcfbe  (admin user)
```

---

## CC REST API (on CCMaster)

Every environment exposes the CC REST API locally on the CCMaster SN:
```
http://127.0.0.1:3000/api/clouds/<cloud_id>/vpsas.json?access_key=<key>
```

| Cloud | cloud_id   | API key |
|---|---|---|
| QA8 | zadaraqa8 | j9PdqWwPYAi4P8pDcq8Y |

---

## Cloud Network / VLAN

All clouds: **VLAN 51**, `10.10.0.0/16` — per-cloud /24 = `10.10.<QA#>.x`

| Cloud | Subnet      |
|---|---|
| QA1  | 10.10.1.x  |
| QA8  | 10.10.8.x  |
| QA10 | 10.10.10.x |
| QA14 | 10.10.14.x |
| QA<N> | 10.10.<N>.x |

---

## Cloud Hardware Summary

| Cloud | Vendor | SNs | Capacity | Cache | vCPU/SN | RAM/SN | Notes |
|---|---|---|---|---|---|---|---|
| QA4  | Dell 730XD + Intel    | 6 | 272 TB   | 8472 GB | 16–40 | 64–96 GB  | 20.12 ZAT |
| QA8  | Intel S2600WTTR       | 4 | —        | —       | 40    | 128 GB    | QA / testing |
| QA14 | SuperMicro (old+new)  | 8 | 2146 TB  | 2836 GB | 40    | 192 GB    | 20.1 Rakuten/ZIOS |
| QA17 | SuperMicro (new)      | 3 | 1955 TB  | 4800 GB | 80    | 512 GB    | 20.12 Rakuten/ZIOS/Veeam |

---

## Lab IP Addressing Scheme

| Range | Purpose |
|---|---|
| 172.16.0.x  | Server MGMT (older) |
| 172.16.1.x  | iDRAC/BMC (older) |
| 172.16.4.x  | VM IPs |
| 172.16.7.x  | QA8 SN/CCMaster/CCVM |
| 172.16.10.x | Server MGMT (newer) |
| 172.16.11.x | BMC (newer) |
| 172.16.13.x | Switch MGMT |
| 172.16.99.x | LCS servers |
| 10.10.0.0/16 | Cloud VLAN space |
| 10.0.x.y    | Per-cloud nova/VC internal management |

---

## Default Credentials

| System | User | Password |
|---|---|---|
| CCMaster / SN | zadara | zadara |
| CCVM | zadministrator | Z@darA2o11 |
| VPSA VC | zadara | Z@darA2o11 |
| eCommerce portal | admin | 1q2w3e4r5t6y |
| CC portal | qa@zadarastorage.com | 1q2w3e4r |
| Dell iDRAC | dell | dell |
| Intel iDRAC | intel | intel |
| Most switches | admin | admin |

Full credential table: see the Lab Credentials memory entry (check MEMORY.md index).
