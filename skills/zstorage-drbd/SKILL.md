---
name: zstorage-drbd
description: Use when diagnosing or fixing DRBD replication on QA8 SNs — WFConnection peer unreachable, outdated peer after reconnect, split-brain (StandAlone on both nodes), or emergency force-primary recovery. Resource r0 replicates CCVM data disk between sn1 and sn2.
---

# zstorage-drbd

Diagnose and fix DRBD issues on QA8 SNs (CCMaster pair: sn1 ↔ sn2).

DRBD resource `r0` replicates the CCVM data disk between sn1 and sn2. The Primary holds all CC services (CCVM, MySQL, Nova, etc.).

---

## Read DRBD state

```bash
cat /proc/drbd           # quick snapshot
drbdadm status r0        # verbose (DRBD 9+); on QA8 use /proc/drbd (8.4.x)
```

### Field reference

| Field | Meaning |
|---|---|
| `cs:Connected` | Both nodes talking, in sync |
| `cs:SyncSource` | This node is sending data to peer |
| `cs:SyncTarget` | This node is receiving data from peer |
| `cs:WFConnection` | Waiting for peer — peer unreachable |
| `cs:StandAlone` | Completely disconnected (split-brain risk) |
| `ro:Primary/Secondary` | This node Primary, peer Secondary (healthy) |
| `ro:Primary/Unknown` | Peer unreachable |
| `ds:UpToDate/UpToDate` | Both disks consistent — healthy |
| `ds:UpToDate/Outdated` | Peer disk is behind (needs sync when it reconnects) |
| `ds:UpToDate/Inconsistent` | Sync in progress |
| `oos:0` | Nothing out of sync — done |
| `oos:NNNN` | KB out of sync |

Sync progress line:
```
[====>...............] sync'ed: 29.3% (3020/4264)M
finish: 0:00:36 speed: 84,808 (84,808) K/sec
```

---

## Common issues and fixes

### WFConnection (peer unreachable)

Most common cause: **peer SN is in CRM standby**.

```bash
# Check from sn2 (or whichever is Primary):
crm_mon -1
# Look for: "Node qa8-sn1: standby"

# Fix: bring the standby node back online
crm node online qa8-sn1
# DRBD will auto-reconnect and start syncing within seconds
```

Other causes:
- Peer SN is rebooting (wait for it to come back)
- Network issue on novabridge/bebond (check heartbeat connectivity)
- Peer DRBD service not running: `ssh qa8-sn1 'systemctl status drbd'`

If peer is up but DRBD won't connect:
```bash
drbdadm connect r0       # manually trigger reconnect
```

### Outdated peer after reconnect

After peer comes online, DRBD starts syncing automatically. Monitor progress:
```bash
watch cat /proc/drbd
# Wait for: cs:Connected ds:UpToDate/UpToDate oos:0
```

Estimate time before sync starts (once `cs:SyncSource`):
```
oos KB ÷ speed KB/sec = seconds remaining
```
Typical QA8 sync speed: 80–150 MB/s → 4 GB syncs in ~30–50 sec.

### Split-brain (cs:StandAlone on both nodes)

**Dangerous — data diverged.** Identify which node has the authoritative data, then:
```bash
# On the node to DISCARD (secondary):
drbdadm secondary r0
drbdadm -- --discard-my-data connect r0

# On the node to KEEP (primary):
drbdadm connect r0
```

### Force primary (emergency, peer gone)

```bash
drbdadm primary --force r0
```

---

## Check DRBD status remotely

```bash
# WSL / macOS / Linux (preferred) — StrictHostKeyChecking=no avoids float-IP key changes
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 "cat /proc/drbd"
# From sn1 directly:
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.122 "cat /proc/drbd"
# From sn2 directly:
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.123 "cat /proc/drbd"
```

```powershell
# Windows fallback (plink.exe) — hostkey changes when CCMaster floats
$plink = "C:\Program Files\PuTTY\plink.exe"
& $plink -batch -pw zadara -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 "cat /proc/drbd"
& $plink -batch -pw zadara -hostkey "SHA256:pAD98VJ8GVQv8h2lW0VEWoBPOIboYI8sDB/A1gy9QkU" `
  zadara@172.16.7.122 "cat /proc/drbd"
& $plink -batch -pw zadara -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.123 "cat /proc/drbd"
```

**Note:** Float IP `172.16.7.121` moves between sn1/sn2. With WSL/sshpass, `StrictHostKeyChecking=no` handles this automatically. With plink, swap hostkey if "host key not in list":
- sn1: `SHA256:pAD98VJ8GVQv8h2lW0VEWoBPOIboYI8sDB/A1gy9QkU`
- sn2: `SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E`

---

## CRM node commands (used alongside DRBD fixes)

```bash
crm_mon -1                   # full cluster status
crm node online qa8-sn1      # bring sn1 out of standby
crm node standby qa8-sn1     # put sn1 into standby (safe for upgrades)
get-ha-state                 # condensed HA summary
```

---

## Healthy state reference (QA8, post-upgrade)

```
version: 8.4.11 (api:1/proto:86-101)
 0: cs:Connected ro:Primary/Secondary ds:UpToDate/UpToDate C r-----
    ns:4390252 nr:0 dw:535920 dr:7717277 al:120 bm:0 lo:0 pe:0 ua:0 ap:0 ep:1 wo:f oos:0
```

- `cs:Connected` — peer connected
- `ro:Primary/Secondary` — sn2 Primary, sn1 Secondary (or vice versa after failover)
- `ds:UpToDate/UpToDate` — both disks in sync
- `oos:0` — nothing out of sync
