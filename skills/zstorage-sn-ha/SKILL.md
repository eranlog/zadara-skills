---
name: zstorage-sn-ha
description: Use when activating, deactivating, or checking HA status on a Storage Node via sn-ha-control — the SN-level HA role tool, distinct from zstorage-drbd's disk-replication layer. Covers activate/deactivate (with --force), status check, and node auth key retrieval.
argument-hint: <sn-hostname>
---

# zstorage-sn-ha

Control Storage Node HA role via `sn-ha-control`. This is SN-level cluster HA (role/failover control) — distinct from [[zstorage-drbd]], which covers the disk-replication layer underneath it.

## When to use

- Forcing an SN into or out of HA standby for maintenance or failover testing
- Checking an SN's current HA status/role
- Retrieving a node's HA auth key (pairing/re-pairing two SNs into an HA set)

## Location

```
/var/lib/zadara/scripts/sn/ha/sn-ha-control
```

Run on the target SN itself (SSH via CCMaster — see [[zstorage-ssh]]).

## Commands

```bash
# Activate SN HA
sn-ha-control --activate
sn-ha-control --activate --force   # bypass normal pre-checks

# Deactivate SN HA
sn-ha-control --deactivate
sn-ha-control --deactivate --force

# Check this node's HA status
sn-ha-control --status

# Get this node's HA auth key (needed when pairing/re-pairing an HA set)
sn-ha-control --get_node_auth_key
```

## Notes

- `--force` skips the normal pre-checks — use only for stuck states, same caution as any other `--force` flag in Zadara tooling.
- For DRBD sync status / split-brain recovery (the replication layer underneath SN HA), see [[zstorage-drbd]] instead.
- Older notes also reference raw CRM/Pacemaker commands (`crm node standby`, `crm node online`, `crm resource <name> stop|start`) — verify these still apply to the current cluster stack before relying on them; `sn-ha-control` is the supported wrapper.
