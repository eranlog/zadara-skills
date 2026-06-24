---
name: zstorage-sncfg
description: Use when managing SN-level storage configuration via zadara_sncfg — QoS group inspection, partition creation/deletion/shred, iSCSI export management, drive LED/fault control, or performance threshold queries and updates.
---

# zstorage-sncfg

Run `zadara_sncfg` on a Storage Node — the tool that manages SN-level storage configuration: partitions, QoS groups, drives, exports, LED, and performance thresholds.

## Connection

Run with sudo on any SN. Hop via CCMaster → SN — see [[zstorage-ssh]] for patterns and IP discovery.

```bash
# On the SN (as root):
zadara_sncfg <subcommand> [args]
```

Use `--targetaddr <IP>` to run against a remote SN without hopping.

## Subcommands

### Read / Inspect
```bash
zadara_sncfg get_config                           # Full drive/partition/QoS tree for this SN
zadara_sncfg get_qosgroups                        # List QoS groups (text)
zadara_sncfg get_qosgroups_xml [--full_info]      # List QoS groups (XML)
zadara_sncfg get_partstatus --vsaid <vsa-id>      # All partitions for a VPSA
zadara_sncfg get_partinfo --pname <partition-name>
zadara_sncfg get_partinfo_byid --partid <hex>
zadara_sncfg get_partdev --pname <partition-name>
zadara_sncfg get_offline_drives
zadara_sncfg get_drive_perf --diskid <uuid> --perf_count <n> --perf_interval <sec>
zadara_sncfg get_part_perf  --pname <name>  --perf_count <n> --perf_interval <sec>
zadara_sncfg get_sys_perf   --perf_count <n> --perf_interval <sec>
zadara_sncfg get_blockdev_perf --devpath <dev> --perf_count <n> --perf_interval <sec>
zadara_sncfg get_cc_perf    --pname <name>  --perf_count <n> --perf_interval <sec>
zadara_sncfg get_ldpdmap    # (no-op wrapper; use zadara_sndrvcfg get_ldpd_map for RAID map)
zadara_sncfg version
```

### Partition Management
```bash
zadara_sncfg create_diskpart  --diskid <uuid> --pname <name> --psize <GB> [--vsaid <id>] [--is_zios] [--is_afa] [--is_metadata] [--is_cache] [--is_setup]
zadara_sncfg create_qgrppart  --qgrpname <name> --pname <name> --psize <GB> [--vsaid <id>] [--is_zios] ...
zadara_sncfg create_qospart   --qos <name> --pname <name> --psize <GB> [--vsaid <id>] ...
zadara_sncfg expand_partition  --pname <name> --psize <GB>
zadara_sncfg delete_partition  --pname <name>
zadara_sncfg shred_partition   --pname <name> --vsaid <id> [--cancel]
zadara_sncfg start_part_rep_timeout --pname <name> --timeout <secs>
zadara_sncfg get_part_rep_timeout_status --pname <name>
```

### Export Management (iSCSI/SCST)
```bash
zadara_sncfg create_export --pname <name> --tid <target-id>
zadara_sncfg remove_export --pname <name> --tid <target-id>
zadara_sncfg start_exports
zadara_sncfg end_exports
zadara_sncfg set_uid_on_export --pname <name> {--on | --off}
zadara_sncfg scst_reinit_notify
zadara_sncfg check_scst_reinit_readiness
```

### Drive Control
```bash
zadara_sncfg set_drive_led    --devpath <dev> {--on | --off}   # Blink drive LED
zadara_sncfg set_drive_faulty --devpath <dev> {--on | --off}   # Mark drive faulty
zadara_sncfg set_drive_offline --devpath <dev>
zadara_sncfg purge_trash_drive --devpath <dev> [--force]
zadara_sncfg dump_disk_logs   [--devpath <dev>]
zadara_sncfg change_disk_qosgrp --devpath <dev> [--qgrpname <name>]
zadara_sncfg change_drive_license_state --devpath <dev> {--on | --off}
zadara_sncfg notify_license_change
zadara_sncfg add_blockdev_meter  --devpath <dev>
zadara_sncfg del_blockdev_meter  --devpath <dev>
```

### Performance Thresholds
```bash
zadara_sncfg set_drive_perf_threshold  --diskid <uuid> [--perf_threshold read_iops=<n>,write_iops=<n>,read_mbps=<n>,write_mbps=<n>,read_latency=<n>,write_latency=<n>]
zadara_sncfg set_part_perf_threshold   --pname <name> [--perf_threshold ...]
zadara_sncfg set_sys_perf_threshold    [--perf_threshold cpu_usage=<pct>]
zadara_sncfg set_blockdev_perf_threshold --devpath <dev> [--perf_threshold ...]
zadara_sncfg set_cc_perf_threshold     --pname <name> [--perf_threshold ...]
zadara_sncfg set_sn_role               --role <sn|ccmaster|ccslave>
```

### Testing
```bash
zadara_sncfg test_sn_action [--stall_api_server] [--resume_api_server]
```

## Example: get_config output (qa8-sn1)

```
NUM QoS Groups: 6

qosgrp_ssd_cache  -  2 drive(s) (Total:2144GB Available:2074GB)
   |-- /dev/sdi (TOSHIBA THNSNJ80 - VG:zadara_500080D91033A8AC) WT NORA  Free:674GB Partitions:4
   |      |--- volume-0000007e (20GB vsaid:9 UID cache)
   ...

qosgrp_ssd_1489GB  -  5 drive(s) (Total:7445GB Available:7445GB)
   |-- /dev/sdc (INTEL SSDSC2BB01 ...) WT NORA  Free:1489GB Partitions:0
   ...
```

## Example: get_sys_perf output

```xml
<?xml version="1.0" encoding="UTF-8"?>
<get_sys_perf-response>
  <status type="integer">0</status>
  <usages-count type="integer">1</usages-count>
  <usages type="array">
    <usage>
      <cpu-user type="float">1.959799</cpu-user>
      <cpu-system type="float">0.175879</cpu-system>
      <cpu-iowait type="float">0.000000</cpu-iowait>
      <cpu-idle type="float">97.864322</cpu-idle>
      <mem-alloc type="float">9.000000</mem-alloc>
      <nr-open-files type="integer">5321</nr-open-files>
      <gb-wrt type="float">0.000000</gb-wrt>
      <gb-rd type="float">0.000000</gb-rd>
      <wrt-bandwidth type="float">0.000000</wrt-bandwidth>
      <rd-bandwidth type="float">0.000000</rd-bandwidth>
      <zcache-data-dirty type="float">0.000000</zcache-data-dirty>
      <zcache-meta-dirty type="float">0.000000</zcache-meta-dirty>
      <time>...</time>
    </usage>
  </usages>
</get_sys_perf-response>
```

## Example: get_partstatus output (plain text)

```
4 partitions (zone:)
    Partition name volume-0000007e, status normal
    Partition name volume-00000080, status normal
    Partition name volume-00000082, status normal
    Partition name volume-00000084, status normal
```

## Notes

- Always run with `sudo`. From remote: `echo zadara | sudo -S zadara_sncfg ...`
- Destructive operations (create/delete/shred partition, purge_trash_drive) will immediately affect running VPSAs. Confirm vsaid and pname before running.
- Use `--targetaddr <SN-IP>` to reach a different SN without SSH hopping.
- `get_partstatus` returns plain text; `get_qosgroups_xml` and `get_sys_perf` return XML.
- Check version: `zadara_sncfg version` (e.g., `SNCFG Version:26.06-137`)
