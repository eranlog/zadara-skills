---
name: logs
description: Use when needing to tail Zadara logs on a VPSA VC, SN, or CCMaster. Provides verified log file paths per node type and SSH commands to run them remotely.
---

# logs Skill

Tail all relevant Zadara logs on a target node.

## Usage

```
/logs [target] [vsa-id]
```

Examples:
- `/logs vc vsa-00000035` — tail logs on active VC of a VPSA
- `/logs sn qa8-sn1` — tail logs on a specific SN
- `/logs ccmaster` — tail logs on CCMaster

## Log paths by node type

### VPSA VC
```bash
tail -f \
  /var/log/zadara/zadara_vam.log \
  /var/log/zadara/zadara_vac.log \
  /var/log/zadara/zadara_cfg.py.log \
  /var/log/zadara/zadara_flc.log \
  /var/log/zadara/zadara_vccfg.log \
  /var/log/pacemaker.log \
  /var/log/syslog \
  /var/log/kern.log
```

| Log | What it covers |
|---|---|
| `zadara_vam.log` | VAM decisions: health state, VC_HEALTH_MUST_REBOOT, failover triggers |
| `zadara_vac.log` | VAC: iSCSI target/initiator management |
| `zadara_cfg.py.log` | zadara_cfg calls (e.g. scst_reinit_notify) |
| `zadara_flc.log` | Failover/liveness controller |
| `zadara_vccfg.log` | VC config changes |
| `pacemaker.log` | HA: Pacemaker/Corosync, VC reboot/failover decisions |
| `syslog` | systemd service events, ExecStopPost firings, kernel messages |
| `kern.log` | Kernel-level events |

Note: no separate `ha.log` — HA events are in `pacemaker.log`. cfg log is `zadara_cfg.py.log` (not `zadara_cfg.log`). syslog has no `.log` extension.

### SN (Storage Node)
```bash
tail -f \
  /var/log/syslog \
  /var/log/kern.log \
  /var/log/nova/nova-backup.log \
  /var/log/nova/nova-manage.log \
  /var/log/pacemaker.log
```

### CCMaster
```bash
tail -f \
  /var/log/syslog \
  /var/log/kern.log \
  /var/log/pacemaker.log
```

## Forward to file

```bash
tail -f <logs...> | tee /tmp/claude.log
```

## Run remotely (Windows via plink)

### On active VC
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<ccmaster-hostkey>" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@<VC_IP> 'echo Z@darA2o11 | sudo -S -i bash -c ""tail -f /var/log/zadara/zadara_vam.log /var/log/zadara/zadara_cfg.py.log /var/log/pacemaker.log /var/log/syslog""'"
```

### On SN
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<ccmaster-hostkey>" `
  zadara@172.16.7.121 `
  "ssh -o StrictHostKeyChecking=no <sn-hostname> 'echo zadara | sudo -S tail -f /var/log/syslog /var/log/kern.log /var/log/pacemaker.log'"
```
