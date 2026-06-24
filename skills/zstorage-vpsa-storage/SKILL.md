---
name: zstorage-vpsa-storage
description: Use when creating VPSA storage resources — RAID groups, pools, volumes, server attachments, or iSCSI connections. Commands differ by generation: Gen2 uses create_raid_group then create_pool; Gen3 H100 uses create_pool_v3 directly. Includes iSCSI discovery and IO test.
---

# zstorage-vpsa-storage

Create and manage VPSA storage resources: RAID groups, pools, and volumes. Commands differ by VPSA generation.

## When to use

- Creating storage pools on a VPSA
- Adding volumes for iSCSI/NFS
- Attaching volumes to servers
- Checking VPSA storage capacity

## VPSA generation detection

| VPSA type | Generation | Pool creation method |
|-----------|-----------|----------------------|
| `vsa.V2.blast.vf` | Gen2 | `create_raid_group` → `create_pool` |
| `vsa.V3.H100.vf` | Gen3 H100 | `create_pool_v3` (skips RAID group step) |
| `premium_gen2` | ZIOS | Different — NAS focused |

Check type: `nova-manage vsa list --id=<ID>` shows `vc_type` column.

---

## API access

All API calls require `access_key`. Get it from VPSA GUI: **admin → RESET ACCESS KEY**.

```bash
BASE="https://<vpsa_nova_ip>"   # novabridge, e.g. 10.0.8.33
KEY="<access_key>"
```

---

## Gen2 VPSA (vsa.V2.blast.vf) — standard flow

### 1. Create RAID group

```bash
# RAID5 (min 3 drives) — good default for Gen2
curl -sk "$BASE/api/raid_groups.json?access_key=$KEY" -X POST \
  -d "display_name=rg-01&protection=RAID5&protection_width=3"

# RAID6 (min 4 drives) — more fault tolerant
curl -sk "$BASE/api/raid_groups.json?access_key=$KEY" -X POST \
  -d "display_name=rg-01&protection=RAID6&protection_width=4"

# Returns: {"response":{"raid_group_name":"rg-00000001","status":0}}
```

Via `zadara_cfg.py` on VC:
```bash
zadara_cfg.py create_raid_group --displayname rg-01 --protection RAID5 \
  --numdrives 3 --drive <vol1> --drive <vol2> --drive <vol3> --outformat json
```

### 2. Create pool from RAID group

```bash
curl -sk "$BASE/api/pools.json?access_key=$KEY" -X POST \
  -d "display_name=pool-01&capacity=1000&raid_groups=rg-00000001"
```

Via `zadara_cfg.py`:
```bash
zadara_cfg.py create_pool --displayname pool-01 --capacity 1000 \
  --numraidgroups 1 --groupname rg-00000001 --outformat json
```

---

## Gen3 H100 VPSA (vsa.V3.H100.vf) — direct pool creation

Gen3 does NOT use standard RAID5/RAID1 commands — those return "illegal raid level".
Use `create_pool_v3` directly.

Available pool types (from `zadara_cfg.py show_vsa_config`):
- `IOPs-Optimized` — NVMe-optimized, high IOPS
- `Balanced` — default general-purpose
- `Throughput-Optimized` — sequential IO focused

```bash
# First check available drives
curl -sk "$BASE/api/drives.json?access_key=$KEY" | python3 -m json.tool

# Create Gen3 pool (--groupname is a RAID group or allocation group name)
zadara_cfg.py create_pool_v3 --displayname pool-01 \
  --pooltype Balanced --groupname <group_name> --outformat json
```

> **Note (QA8 Gen3 H100):** Gen3 RAID group creation via `create_raid_group` fails with
> "illegal raid level" for RAID5/RAID1 and "illegal protectionWidth" for RAID6 with 4 drives.
> The correct Gen3 pool setup path requires more drives or a different group allocation —
> needs further investigation. May require provisioning via CC before pool creation is possible.

---

## Create a volume (both Gen2 and Gen3)

```bash
# Block volume (iSCSI)
curl -sk "$BASE/api/volumes.json?access_key=$KEY" -X POST \
  -d "display_name=vol-01&pool_name=pool-00000001&capacity=100&block=YES"

# Via zadara_cfg.py
zadara_cfg.py create_volume --displayname vol-01 --poolname pool-00000001 \
  --provisionedcapacity 100 --block YES --thin YES --outformat json
```

---

## Attach volume to server

```bash
# Attach (make server the LUN owner)
curl -sk "$BASE/api/volumes/vol-00000001/attach_servers.json?access_key=$KEY" \
  -X POST -d "servers_name[]=srv-00000001"

# Detach
curl -sk "$BASE/api/volumes/vol-00000001/detach_server.json?access_key=$KEY" \
  -X POST -d "server_name=srv-00000001"
```

---

## List / inspect resources

```bash
# Drives
curl -sk "$BASE/api/drives.json?access_key=$KEY"

# RAID groups
curl -sk "$BASE/api/raid_groups.json?access_key=$KEY"

# Pools
curl -sk "$BASE/api/pools.json?access_key=$KEY"

# Volumes
curl -sk "$BASE/api/volumes.json?access_key=$KEY"

# Servers
curl -sk "$BASE/api/servers.json?access_key=$KEY"
```

---

## Connect iSCSI volume from Linux client

After attaching volume to a server and iSCSI is configured:

```bash
# Discover targets
iscsiadm -m discovery -t sendtargets -p <vpsa_bebond_ip>

# Login to all discovered targets
iscsiadm -m node --loginall=all

# Check connected block device
lsblk | grep sd

# Run IO test
dd if=/dev/urandom of=/dev/<device> bs=1M count=100 oflag=direct
```

---

## QA8 reference values

| VPSA | Nova IP | Bebond IP | Access Key | Type |
|------|---------|-----------|------------|------|
| 4 (H101) | 10.0.8.33 | 10.2.8.33 | TMY1JQLYRMSJJO5JI78E-3 | Gen3 H100 |
| 5 (IAM801) | 10.0.8.35 | 10.2.8.35 | (reset via GUI) | Gen2 blast |
