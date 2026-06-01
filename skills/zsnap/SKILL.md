---
name: zsnap
description: Use when collecting a Zadara diagnostic snapshot (zsnap) from a SN, VPSA VC, or CCMaster for bug reports or support tickets. Covers running zsnap, uploading to S3, and adding the S3 path to Jira. Never attach zsnap files directly to Jira.
---

# zsnap Skill

Collect a Zadara diagnostic snapshot from a target node and document it in Jira.

## Usage

```
/zsnap [target] [jira-issue]
```

Examples:
- `/zsnap ccmaster ZSTRG-37822` — zsnap on CCMaster, add S3 path to issue
- `/zsnap vc vsa-00000035 ZSTRG-37822` — zsnap on active VC, add S3 path
- `/zsnap sn qa8-sn3` — zsnap on specific SN

## Run zsnap + Upload to S3

**Never attach the .tar.gz to Jira.** Always upload to S3 and paste the S3 path.

```bash
# On CCMaster / SN
s3-zsnap.sh -m sn -w now -p <JIRA-KEY> -q

# On VPSA VC
s3-zsnap.sh -m vpsa -w now -p <JIRA-KEY> -q
```

Get S3 path from syslog after upload:
```bash
grep "ZSnap uploaded.*<JIRA-KEY>" /var/log/syslog | tail -3
```

## Jira Comment Format

```
## ZSnaps — <cloud> testing (<date>)

| Node | Role | S3 Path |
|---|---|---|
| qa8-sn2 | CCMaster | s3://zadarastorage-support/zadara-qa8/SNs/qa8-sn2-cc/<file>.tar.gz |
| qa8-sn3 | SN (test node) | s3://zadarastorage-support/zadara-qa8/SNs/qa8-sn3-sn/<file>.tar.gz |
```

## S3 Destination Patterns

| Node type | `-m` flag | S3 prefix |
|---|---|---|
| SN / CCMaster | `sn` | `SNs/<hostname>-cc/` or `SNs/<hostname>-sn/` |
| VPSA VC | `vpsa` | `VPSAs/<displayname>.<vsa-id>/` |
| Support ticket | `ticket -t <id>` | `Tickets/<ticket-id>/` |

## Lite Mode

```bash
zsnap.sh -p <prefix> -r -q      # runtime only (~5-20MB, fast)
zsnap.sh -p <prefix> -r -r -q   # runtime + syslog
zsnap.sh -p <prefix> -q          # full (~100-250MB)
```

## What Gets Collected

- All of `/var/log/`, `/etc/`, `/proc/`, `/sys/`
- System info: ps, top, systemctl, lsmod, dpkg
- HA/Pacemaker: crm_mon, crm configure, get-ha-state
- **VC only:** zadara_vam/vac/lsa/flc/mag internals, MySQL DB dump, capacity history
- **SN only:** nova/MySQL/rabbitmq logs, HPSA RAID controller
