---
name: zstorage-drives
description: Use when Storage Node drives are invisible in Command Center — specifically drives stuck in qosgrp_foreign due to stale cloud_uuid LVM VG tags from a previous cloud installation. Fix is non-destructive: update VG tags and restart zadara-sn service.
---

# zstorage-drives

Fix Storage Node drives not appearing in CC — specifically drives stuck in `qosgrp_foreign` due to stale LVM VG tags from a previous cloud installation.

**Confluence reference:** https://zadara.atlassian.net/wiki/x/drives-fix (see page created alongside this skill)

## When to use

- An SN shows 0 drives (or fewer than expected) in CC Storage Nodes view
- `zadara_sncfg get_config` shows drives in `qosgrp_foreign`
- `get_qosgroups_xml` returns no drives (or fewer than `get_config` shows)
- After a fresh SN install, drives were previously used in a different cloud instance

## Root cause

Zadara drives store metadata in LVM VG tags (`cloud_uuid+<uuid>`, `qosgrp+<group>`, etc.). After a cloud re-install or SN fresh install, the `cloud_uuid` in the VG tags no longer matches the current cloud UUID. `zadara_sncfg` detects this mismatch and moves the drives to `qosgrp_foreign`, which is excluded from `get_qosgroups_xml` — so nova-compute never reports these drives to CC.

## Diagnostic commands

Run on the affected **SN** (SSH via CCMaster — see [[zstorage-ssh]] for IP discovery and patterns):

```bash
# Check which drives are foreign
python3 /var/lib/zadara/scripts/sn/zadara_sncfg get_config 2>&1 | grep -A5 qosgrp_foreign

# Check drives visible to nova (should match get_config minus foreign)
python3 /var/lib/zadara/scripts/sn/zadara_sncfg get_qosgroups_xml 2>&1 | grep -c "<drive>"

# Check cloud_uuid on all VGs — compare against zconfig
vgs -o tags 2>/dev/null | grep cloud_uuid

# Get correct current cloud UUID
zconfig.py --get cloud.uuid
```

## Fix procedure

Run all commands on the **affected SN** as root.

### Step 1 — Identify the stale cloud UUID
```bash
vgs --noheadings -o vg_name,vg_tags 2>/dev/null | grep zadara
# Note the cloud_uuid+<value> — should be same on all drives
# If multiple UUIDs exist, note ALL of them
```

### Step 2 — Get the correct current cloud UUID
```bash
zconfig.py --get cloud.uuid
# Example output: 41b17d81-3088-418b-acbb-5af38ceb46f5
```

### Step 3 — Delete old cloud_uuid tag(s) from all VGs
```bash
# Run once per stale UUID found in step 1
vgchange --deltag cloud_uuid+<stale_uuid>
# Example: vgchange --deltag cloud_uuid+c43f3667-fd7a-4673-9caa-76582f5bc7c4
# This safely no-ops on VGs that don't have the tag
```

### Step 4 — Add the correct cloud UUID to all zadara VGs
```bash
# List zadara VG names, then add tag to each
vgchange --addtag cloud_uuid+<correct_uuid> \
  zadara_<wwn1> zadara_<wwn2> ...
# Or loop:
# for vg in $(vgs --noheadings -o vg_name | tr -d ' ' | grep zadara); do
#   vgchange --addtag cloud_uuid+<correct_uuid> "$vg"
# done
```

### Step 5 — Restart zadara-sn service
```bash
service zadara-sn restart
# Verify:
service zadara-sn status --no-pager | head -5
```

### Step 6 — Verify drives appear in CC
Check the CC Storage Nodes page — the SN should now show the correct drive count (14 Free / 0 Absent).

## Key files / commands on SNs

| Item | Location |
|------|----------|
| sncfg script | `/var/lib/zadara/scripts/sn/zadara_sncfg` |
| drive config script | `/var/lib/zadara/scripts/sn/zadara_sndrvcfg` — actions: `check_config`, `import_all`, `get_sn_drive_count`, `renew_drive --path`, `clean_signature_and_import --path` (DESTRUCTIVE), `check_op_in_progress`, `invoke_periodic_tasks`, `set_bios_device_exposure --num_devs` |
| cloud UUID config | `zconfig.py --get cloud.uuid` |
| LVM VG backup | `/etc/lvm/backup/zadara_<wwn>` |

## LVM VG tag structure

Each Zadara drive VG has these tags:
```
cloud_uuid+<cloud-uuid>     ← must match current cloud; fix target
sn_uname+<sn-hostname>      ← which SN owns this drive
qosgrp+<group-name>         ← which QoS group (e.g. qosgrp_sas_557GB_10500rpm)
uuid+<wwn>                  ← drive WWN
disk_type+<sas|sata|ssd>
disk_interface+sas
rotation_speed+<rpm|1>      ← 1 = SSD
serial_num+<serial>
difcapable+<0|1>
sedcapable+<0|1>
```

## Notes

- `clean_signature_and_import` (in `zadara_sndrvcfg`) is a **different** and more destructive fix — it zeros the drive sectors. Only use if the drive has corrupt/unreadable LVM data. For a cloud UUID mismatch, the tag fix above is sufficient and non-destructive.
- `qosgrp_foreign` drives are NOT reported via `get_qosgroups_xml` to nova-compute — this is why they are invisible in CC.
- `zadara_snmonitor` logs `snmon_poll_disks: io_setup, error 22` every 30s for foreign drives — this is a symptom, not the cause.
- After a fresh cloud re-install, check all SNs' VG cloud_uuid tags — multiple SNs may have the same stale UUID problem.
