# zadara-skills

Claude Code skills for Zadara infrastructure. Environment-agnostic — no hardcoded IPs or credentials. Discover IPs at runtime via `[[zstorage-environments]]`.

## Skills

### SSH & Access

| Skill | Description |
|-------|-------------|
| [zstorage-ssh](skills/zstorage-ssh) | SSH into any Zadara node — CCMaster, SN, CCVM, or VPSA VC. WSL/sshpass preferred; plink.exe fallback. IP discovery via `[[zstorage-environments]]`. |
| [zstorage-environments](skills/zstorage-environments) | IP reference for all Zadara environments — CCMaster, CCVM, SNs, CC hostnames, credentials. |

### VPSA Operations

| Skill | Description |
|-------|-------------|
| [zstorage-vpsa](skills/zstorage-vpsa) | Manage VPSA lifecycle via `nova-manage vsa` — hibernate, restore, recover from failed state, race condition testing. |
| [zstorage-vpsa-api](skills/zstorage-vpsa-api) | Query the VPSA REST API — volumes, pools, servers, drives. Requires active VC IP + access key. |
| [zstorage-vpsa-logs](skills/zstorage-vpsa-logs) | Tail VPSA logs (rails, nginx, vac, vam, vcc), check identity providers, query VPSA DB. |
| [zstorage-vpsa-storage](skills/zstorage-vpsa-storage) | Create RAID groups, pools, volumes. Gen2 vs Gen3 H100 flow differences. iSCSI connect. |
| [zstorage-cc-api](skills/zstorage-cc-api) | Query the Command Center REST API — list VPSAs, hibernate, restore, retrieve X-Token. |
| [zstorage-pp-api](skills/zstorage-pp-api) | Query the eCommerce/portal API — organizations, users, subscriptions. |
| [zstorage-ngos-api](skills/zstorage-ngos-api) | Query the NAS/object storage API on a VPSA. |
| [zstorage-ipsec](skills/zstorage-ipsec) | Configure and troubleshoot IPsec between a VPSA and an iSCSI client (strongSwan IKEv1 PSK). |
| [zstorage-containers](skills/zstorage-containers) | Manage VPSA container service — enable, configure networks, deploy workloads. |

### Storage Nodes

| Skill | Description |
|-------|-------------|
| [zstorage-snreq](skills/zstorage-snreq) | Storage Node requirements — hardware checks, network validation, pre-install verification. |
| [zstorage-sncfg](skills/zstorage-sncfg) | Storage Node configuration — zadara_sncfg subcommands, drive layout, QoS groups. |
| [zstorage-sndrvcfg](skills/zstorage-sndrvcfg) | Storage Node drive configuration — import, renew, clean, check. |
| [zstorage-drives](skills/zstorage-drives) | Fix drives invisible in CC — stale `cloud_uuid` LVM VG tags, non-destructive fix. |
| [zstorage-drbd](skills/zstorage-drbd) | DRBD status, sync, split-brain recovery for HA SN pairs. |

### Installation & Diagnostics

| Skill | Description |
|-------|-------------|
| [zinstall](skills/zinstall) | Zadara cloud installer — actions, flags, upgrade phases, common recipes. |
| [logs](skills/logs) | Tail Zadara logs on a VPSA VC, SN, or CCMaster. |
| [zsnap](skills/zsnap) | Collect a Zadara diagnostic snapshot, upload to S3, add path to Jira. |

## Scripts

Runnable scripts live in [`scripts/`](scripts/) — skills reference these by path instead of embedding code.

| Script | Purpose |
|--------|---------|
| `get-active-vc-ip.sh <vsa-id>` | Get active VC management IP from CCMaster |
| `tail-vpsa-logs.sh` | Tail all standard VPSA log files |
| `cc-db-query.sh "<SQL>"` | Query CC database (PostgreSQL/MySQL fallback) |
| `ssh-base64-cmd.sh <ccmaster> <vc> "<cmd>"` | Run complex commands across SSH hops via base64 |
| `fix-ccmaster-sshd.sh` | Fix "Connection refused" on CCMaster (Noble socket-activation bug) |
| `fix-drive-cloud-uuid.sh <stale> <correct>` | Fix stale cloud_uuid LVM tags on SN |
| `vpsa-recover-failed.sh <id> <tenant_id>` | Recover VPSA stuck in failed state |
| `vpsa-double-restore-race.sh <id> <tenant_id>` | Reproduce double-restore race condition |
| `ipsec-client-setup.sh <client_ip> <vpsa_bebond> <name> <psk>` | Configure strongSwan on iSCSI client |
| `iscsi-connect-and-test.sh <vpsa_bebond_ip>` | Discover, connect, and test iSCSI volume |

## Installation

```bash
cd ~/.claude/plugins
git clone https://github.com/eranlog/zadara-skills
```

Restart Claude Code — skills load automatically.

## Contributors

Built by [eranlog](https://github.com/eranlog) and Claude.
