Use when the QA8 CCMaster floating IP is unreachable after an SN reboot or cloud upgrade, and crm_mon fails with "Transport endpoint is not connected" or get-ha-state returns "Cluster Resource Manager is not running".

## Important: This is expected behavior

After an SN boots, HA takes several minutes to come up — this is by design, not a bug. The SN runs a lengthy VF setup (mlx5 unbind, ~2–5 min) before heartbeat starts. **Just wait.** Only intervene if it hasn't recovered after ~10 minutes.

## Key facts

- QA8 uses **heartbeat** (not Pacemaker) on qa8-sn1 + qa8-sn2
- Floating IP **172.16.7.121** only works when heartbeat is running
- When floating IP is down, connect directly: **sn1=172.16.7.122**, **sn2=172.16.7.123**
- sn1 hostkey: `SHA256:QxSKc0tS011PpXeRIyDaNlRD95anxNSVNQMTx5ijF9o`
- sn2 hostkey: `SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ`

## Step 1 — Connect directly to SNs and diagnose

```powershell
# Windows — bypass floating IP
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:QxSKc0tS011PpXeRIyDaNlRD95anxNSVNQMTx5ijF9o" `
  zadara@172.16.7.122 "sudo crm_mon -1 2>&1 | head -15"

"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ" `
  zadara@172.16.7.123 "sudo crm_mon -1 2>&1 | head -15"
```

**Read the output:**
- `Online: [ qa8-sn1 qa8-sn2 ]` → cluster healthy, problem is elsewhere
- `Node qa8-sn2: standby` + `OFFLINE: [ qa8-sn1 ]` → sn1 heartbeat not running, sn2 in standby
- `Connection to cluster failed` on both → heartbeat not running on either SN

## Step 2 — Find which SN has heartbeat running

```bash
sudo ps aux | grep "heartbeat: master" | grep -v grep
# If output → heartbeat is running on this node
# If empty  → heartbeat NOT running here
```

## Step 3 — If heartbeat not running: check why

```bash
sudo systemctl status zadara-sn --no-pager | tail -5
```

**Common post-upgrade cause:** `zadara-sn.service` is in `activating (start-pre)` running
`sn-networks.py setup` — unbinds 64+ mlx5 VFs at ~1 sec/VF (takes 2–5 min).
`initha.service` (which starts heartbeat) waits for this to finish.

**→ Just wait.** Check progress: VF number in the log should increase every second.

If `zadara-sn.service` is `active: running` but heartbeat still not running:

```bash
sudo /var/lib/zadara/scripts/sn/ha/sn-ha --start
```

Or reboot the SN:

```bash
echo b > /proc/sysrq-trigger    # hard reboot via sysrq
```

## Step 4 — Bring standby node online

From whichever SN has heartbeat running:

```bash
sudo crm node online qa8-sn2    # adjust node name as needed
# → INFO: online node qa8-sn2
```

## Step 5 — Verify cluster is healthy

```bash
sudo crm_mon -1
# Expected:
# Online: [ qa8-sn1 qa8-sn2 ]
# Master/Slave Set: DRBD_MS [DRBD]
#     Masters: [ qa8-sn1 ]
#     Slaves:  [ qa8-sn2 ]
# ...resources running...
```

Floating IP 172.16.7.121 should now be reachable.

## Cheat sheet

| Symptom | Action |
|---------|--------|
| Both SNs: `Connection failed` | Check `systemctl status zadara-sn` — wait for VF setup or start `sn-ha --start` |
| One SN: standby, other offline | Reboot offline SN, then `crm node online <standby-sn>` |
| DRBD stuck as slave | Wait for peer to connect; if peer is offline use `crm resource promote DRBD_MS` |
| Floating IP down but cluster healthy | Check `crm_mon` for unstarted resources; may need manual `crm resource start <name>` |

## Reference

- Confluence RCA: https://zadara.atlassian.net/wiki/x/FYCn5w
- Confluence Recovery Guide: https://zadara.atlassian.net/wiki/x/D4Cs5w
