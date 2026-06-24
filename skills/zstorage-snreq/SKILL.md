---
name: zstorage-snreq
description: Use when running remote SN operations via zadara_snreq.py — hardware info, networking config, drive import check, service status, license management, or system/drive performance thresholds. Tool handles SSH internally; add --target to run against a different SN.
---

# zstorage-snreq

Run operations on Storage Nodes via `zadara_snreq.py` — the preferred tool for remote SN ops (handles SSH internally, no manual hop needed).

**Confluence reference:** https://zadara.atlassian.net/wiki/spaces/ZO/pages/3905716239  
**Binary:** `/var/lib/zadara/scripts/utils/zadara_snreq.py`

## Connection

Run on any SN with sudo. Hop via CCMaster → SN:

```bash
# WSL / macOS / Linux (preferred)
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no <sn-hostname> \
   'echo zadara | sudo -S zadara_snreq.py <subcommand> [--target <IP>]'"
```

```powershell
# Windows fallback (plink.exe)
$plink = "C:\Program Files\PuTTY\plink.exe"
& $plink -batch -pw zadara -hostkey "SHA256:pAD98VJ8GVQv8h2lW0VEWoBPOIboYI8sDB/A1gy9QkU" zadara@172.16.7.121 `
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no <sn-hostname> 'echo zadara | sudo -S zadara_snreq.py <subcommand> [--target <IP>]'"
```

Add `--target <IP>` to run against a remote SN. Default is localhost.

## Global options
```
--target <IP>     Remote SN IP (default: localhost)
--timeout <sec>   Command timeout (default varies)
--dry_run / -n    Show what would run without executing
--pretty / -p     Pretty-print JSON output (does NOT work with XML-outputting commands)
```

## Subcommands

### sn_info — SN hardware/system info
```bash
zadara_snreq.py sn_info
# Returns XML: BIOS version, CPU model, uptime, OS/kernel, OFED version, drive FW info, RAID adapter info
```
Output includes: system manufacturer/serial, CPU topology, uptime, OS info (Ubuntu 24.04.4 Noble, Kernel 6.6.141+zadara1), OFED version, reboot pending status.

### get_networking_info — Network interfaces
```bash
zadara_snreq.py get_networking_info
# Returns XML: PCI address, card model, interfaces, roles (BE/FE), firmware, speed, product name
```

### get_cpu_topology — Save CPU topology to file
```bash
zadara_snreq.py get_cpu_topology --path <file-path-on-ccvm>
# Saves CPU topology to the specified path on CCVM. Used by CC during setup.
# NOT an interactive display command — --path is required.
```

### services — Service status and perf thresholds
```bash
zadara_snreq.py services get
# Returns XML list of all services: name, version, status
# Services reported: radiusd, zadara-sn, drbd, mysql, rabbitmq, glance_api, glance_reg,
#   keystone, ccvm, nova-compute, nova-volume, nova-api, nova-scheduler, nova-network, nova-vsa

zadara_snreq.py services get_perf_threshold
zadara_snreq.py services set_perf_threshold ...
```

### check_config — MR/HP/RAID drive config check
```bash
zadara_snreq.py check_config
# Wrapper around zadara_sndrvcfg check_config. Returns XML response with pass/fail message.
# Example: "MR is configured properly! SN is configured properly and sees 14 drives of 16 drives"
```

### drive — Drive perf thresholds
```bash
zadara_snreq.py drive get_perf_threshold --disk_id <uuid>
# --disk_id is required
zadara_snreq.py drive set_perf_threshold --disk_id <uuid> ...
```

### blockdev — Block device management
```bash
zadara_snreq.py blockdev list
# Lists block devices: root device, DRBD device paths

zadara_snreq.py blockdev get_perf_threshold ...
zadara_snreq.py blockdev set_perf_threshold ...
```

### drive_cfg — Drive import and config check
```bash
zadara_snreq.py drive_cfg check
# Check MR/HP/non-RAIDED drive config (safe, read-only)

zadara_snreq.py drive_cfg import
# Import all drive config on target (operational — use after drive replacement)

zadara_snreq.py drive_cfg chk_completion
# Check if import_cfg completed

zadara_snreq.py drive_cfg get_results
# Get previous import cfg results
```

### partition — Partition perf thresholds
```bash
zadara_snreq.py partition get_perf_threshold ...
zadara_snreq.py partition set_perf_threshold ...
```

### system — System perf thresholds
```bash
zadara_snreq.py system get_perf_threshold
zadara_snreq.py system set_perf_threshold ...
```

### license — License management
```bash
zadara_snreq.py license show
# Show license details: key, active, drives licensed, expiry

zadara_snreq.py license activate
zadara_snreq.py license update
```

### clog — Central log (rsyslog) management
```bash
zadara_snreq.py clog get_remote_addresses
# Get configured rsyslog server addresses

zadara_snreq.py clog fetch
# Fetch clogs

zadara_snreq.py clog set_remote_addresses ...
zadara_snreq.py clog restore_remote_addresses
```

### Destructive / operational (use with caution)
```bash
zadara_snreq.py reboot                         # Reboot SN
zadara_snreq.py shutdown                       # Shutdown SN
zadara_snreq.py import_all                     # Import all drives
zadara_snreq.py set_sn_role                    # Set SN role
zadara_snreq.py cc_failover                    # Trigger CC failover
zadara_snreq.py nova_params                    # Set nova params in zadara-cc.conf
zadara_snreq.py load_perf_thresholds           # Load perf thresholds to sn-monitor
```

### CC-internal ops (rarely used manually)
```bash
zadara_snreq.py smart                          # SMART test on drives
zadara_snreq.py zsnap                          # Take and upload zsnap
zadara_snreq.py sync_dirs_for_vc_injectn       # Sync dirs CCVM→CCMaster for VC injection
zadara_snreq.py sync_dirs_for_cc_nodes_injectn # Sync dirs CCVM→CCMaster for CC node injection
```

## Example outputs

### sn_info (qa8-sn1)
```xml
<sn_info>
  <bios-version>SE5C610.86B.01.01.3029.022420221031</bios-version>
  <system-manufacturer>Intel Corporation</system-manufacturer>
  <system-product-name>S2600WTTR</system-product-name>
  <sn_status>Normal</sn_status>
  <os_info>Ubuntu 24.04.4 LTS(noble), Kernel 6.6.141+zadara1</os_info>
  <ofed_version>25.10.OFED.25.10.1.7.1-1+zadara4</ofed_version>
  <uptime><uptime_since>...</uptime_since></uptime>
  <reboot_status><pending>no</pending></reboot_status>
</sn_info>
```

### check_config (qa8-sn1)
```xml
<response><status>0</status>
<message>MR is configured properly!
SN is configured properly and sees 14 drives of 16 drives that linux sees!</message>
</response>
```

### blockdev list (qa8-sn1)
```xml
<response><status>0</status><message>Command completed successfully!</message>
  <root>/dev/sda3</root>
  <drbd>/dev/disk/by-id/wwn-0x600605b00d6015802f10de5909e16798-part6</drbd>
</response>
```

## Notes

- Always run with `sudo`. From remote: `echo zadara | sudo -S zadara_snreq.py ...`
- Binary is at `/var/lib/zadara/scripts/utils/zadara_snreq.py` and is in PATH on SNs.
- `--pretty` only works for JSON output; XML-outputting commands (sn_info, check_config, etc.) ignore it.
- `get_cpu_topology` is a CC-internal command — requires `--path` to save output to CCVM filesystem.
- `drive get_perf_threshold` requires `--disk_id <uuid>`.
- Check version: `zadara_snreq.py version`
