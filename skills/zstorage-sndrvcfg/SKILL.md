---
name: zstorage-sndrvcfg
description: Use when managing physical drive and RAID controller configuration on a Storage Node — MegaCLI/StorCLI drive import, cache policy check, RAID LD-to-PD mapping, or diagnosing missing drives via check_config. Wraps MegaCLI, StorCLI, and HPSA tools automatically.
---

# zstorage-sndrvcfg

Manages physical drive/RAID controller configuration on a Storage Node. Wraps **MegaCLI** (legacy HBAs) or **StorCLI** (LSI/AERO cards — PCI ID 1000:10e). Auto-selects which CLI to use at startup via `lspci`. Also handles **HP Smart Array (HPSA)** controllers via `hpacucli`.

Internally calls `zadara_sncfg get_config` and `zadara_sncfg get_offline_drives` to reconcile drive lists.

**Binary:** `/var/lib/zadara/scripts/sn/zadara_sndrvcfg`  
**Lock file:** `/tmp/drvcfg.lock` — most actions serialize on this lock.

## Connection

Run with sudo on any SN. Hop via CCMaster → SN:

```bash
# WSL / macOS / Linux (preferred)
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no <sn-hostname> \
   'echo zadara | sudo -S zadara_sndrvcfg <action> [options]'"
```

```powershell
# Windows fallback (plink.exe)
$plink = "C:\Program Files\PuTTY\plink.exe"
& $plink -batch -pw zadara -hostkey "SHA256:pAD98VJ8GVQv8h2lW0VEWoBPOIboYI8sDB/A1gy9QkU" zadara@172.16.7.121 `
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no <sn-hostname> 'echo zadara | sudo -S zadara_sndrvcfg <action> [options]'"
```

## Actions — Read / Inspect (safe)

```bash
zadara_sndrvcfg check_config
# Full sanity check: MR controller config, HPSA config, snmonitor running, drive count match.
# Outputs: "MR is configured properly!" + "SN is configured properly and sees N drives of M drives"
# Reports: spin-down settings, 1:1 drive mapping, unconfigured VDs, foreign config, cache policy errors.

zadara_sndrvcfg get_sn_drive_count
# Counts drives that the SN should see (excludes USB, fstab, non-disk udev entries).

zadara_sndrvcfg get_ldpd_map
# Prints LD→PD mapping: Adapter / LD id / PD id / Enclosure / Slot / State / FW version / devpath.

zadara_sndrvcfg get_ld_cache_status
# Prints cache policy for every virtual disk (all adapters).
# Output: "Adapter N-VD M(target id: M): Cache Policy:WriteThrough/WriteBack, ReadAheadNone/ReadAhead, Direct, ..."

zadara_sndrvcfg check_op_in_progress
# Returns 0 if no op holds the lock; 254 if another operation is in progress.

zadara_sndrvcfg MR_cache_battery_state_report
# Reports current MegaRAID battery (BBU) status per adapter.

zadara_sndrvcfg HP_dump_config
# Dumps HP Smart Array drive config (slot/ld/status/type/rpm/devpath).
```

## Actions — Operational

```bash
zadara_sndrvcfg import_all
# Full import sequence:
#   1. Fix bad drives (Unconfigured(bad) / JBOD → make good / online)
#   2. Import foreign configurations
#   3. Fix drive spindown settings
#   4. Check preserved cache (throws if dirty cache needs discarding first)
#   5. Configure each unconfigured PD as RAID-0 (R0)
#   6. Fix cache policy for all VDs
# Use after: SN replacement, drive swap, fresh install.

zadara_sndrvcfg renew_drive --path <dev>
# Re-hotplug a specific drive via udev/SCSI layer.
# For NVMe: udevadm trigger remove+add. For SCSI: delete from sysfs + re-add.
# Drive must NOT already be in sncfg config.

zadara_sndrvcfg clean_signature_and_import --path <dev>
# DESTRUCTIVE. Wipes partition table/signatures (dd zeros) then calls renew_drive.
# Use when check_config reports "valid gpt/dos partition" on a drive that should be SN storage.
# INTERACTIVE: prompts user to re-type the drive path to confirm. Cannot be scripted non-interactively.
# Pre-checks: refuses if drive is in /etc/fstab.

zadara_sndrvcfg blacklist_drive --serial_num <serial>
# Permanently adds drive serial to /etc/zadara/disk_blacklist.
# Blacklisted drives are excluded from unconfigured-drive detection and import_all.

zadara_sndrvcfg set_bios_device_exposure --num_devs <n>
# Sets StorCLI BIOS DeviceExposure on all controllers.

zadara_sndrvcfg invoke_periodic_tasks
# Runs periodic maintenance: MR battery state management + cache config change detection.
# Called by cron/snmonitor; can be run manually to force a cycle.

zadara_sndrvcfg alert_if_non_optane_drives_in_afa_meta_group
# Checks qosgrp_afa_meta QoS group — sends event if non-Optane/KIOXIA/MICRON drives found.
```

## Deprecated actions (still callable)

```bash
zadara_sndrvcfg MR_check_config    # deprecated → use check_config
zadara_sndrvcfg MR_import_all      # deprecated → use import_all
zadara_sndrvcfg MR_fix_cachepolicy # fix cache policy for all VDs (silently)
zadara_sndrvcfg MR_disable_PR      # disable patrol reads on all MR controllers
zadara_sndrvcfg MR_disable_CC      # disable consistency checks on all MR controllers
zadara_sndrvcfg MR_cache_battery_state_manage  # manage battery state (silent, periodic)
```

## Global options

```
--path <dev>              Drive path (e.g. /dev/sdb)
--serial_num <serial>     Drive serial number
--adp_id <id>             Adapter ID
--num_devs <n>            Number of BIOS-exposed devices
--skipconfig              Dry-run: print steps without executing (only affects renew_drive / clean_signature)
--ccvm                    Suppress debug output (used when CCVM calls this remotely)
--save_result_in_file <path>  Write result string to file
```

## Example outputs

### check_config (qa8-sn1 — clean state)
```
MR is configured properly!
INFO: /dev/sda has a valid gpt partition on it. Hence not considered by SN.
      (Use clean_signature_and_import if this drive is for SN use)
INFO: /dev/sdk has a valid dos partition on it. Hence not considered by SN.
SN is configured properly and sees 14 drives of 16 drives that linux sees!
```

### get_sn_drive_count
```
SN Drive count: 14
```

### get_ldpd_map
On qa8-sn1 (Intel RMS3AC160 / MegaCLI): produces **no output** (RC:0). May show output on other HBA types.

### get_ld_cache_status (qa8-sn1 — 16 VDs)
```
Adapter 0-VD 0(target id: 0): Cache Policy:WriteThrough, ReadAheadNone, Direct, No Write Cache if bad BBU
Adapter 0-VD 1(target id: 1): Cache Policy:WriteThrough, ReadAheadNone, Direct, No Write Cache if bad BBU
Adapter 0-VD 3(target id: 3): Cache Policy:WriteBack, ReadAhead, Direct, No Write Cache if bad BBU
Adapter 0-VD 5(target id: 5): Cache Policy:WriteBack, ReadAhead, Direct, No Write Cache if bad BBU
... (16 VDs total, mix of WriteThrough and WriteBack)
```

### MR_cache_battery_state_report (qa8-sn1)
```
INFO: Num adapters:1
adp[0] file stat:  bat_low=No, replace=No
```

### HP_dump_config
Empty output on non-HP hardware (expected). Only produces output when HP Smart Array controller is present.

## Diagnostic flow for missing drives

1. `check_config` → identifies missing drives and why
2. If "valid gpt/dos partition": → `clean_signature_and_import --path <dev>` (interactive!)
3. If "foreign configuration": → `import_all`
4. If "udev ID_TYPE not set": → `renew_drive --path <dev>`
5. If cache policy errors: → `import_all` or `MR_fix_cachepolicy`

## Notes

- Always run with `sudo`. From remote: `echo zadara | sudo -S zadara_sndrvcfg ...`
- `clean_signature_and_import` is interactive and **cannot be piped/automated** — it calls `input()` to confirm the path.
- `import_all` is safe to run on a healthy SN — it's a no-op if everything is already configured correctly.
- Lock contention: if `check_op_in_progress` returns 254, another operation holds `/tmp/drvcfg.lock` — wait for it.
- `sndrvcfg` depends on `sncfg` being functional: it reads `sncfg get_config` and `sncfg get_offline_drives` internally.
