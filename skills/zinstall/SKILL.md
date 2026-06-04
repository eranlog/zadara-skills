Use when running cloud upgrades, SN installs, package management, or troubleshooting version mismatches on Zadara QA clouds. Also use when a cloud_upgrade or sn_upgrade fails with version errors.

## Full reference

Confluence: https://zadara.atlassian.net/wiki/x/CYDZ5w

## All actions (quick ref)

| Action | Purpose |
|--------|---------|
| `list_sns` | Show all SNs: NOVA/SN/Installer versions, role, OS, OFED |
| `list_pkgs [--remote_repo]` | List downloaded/available packages |
| `download_pkg --pkg <ver>` | Download package to `/mnt/nova/pkgs/` |
| `sn_upgrade --pkg <ver> --sn_uname <sn>` | Upgrade single SN |
| `cloud_upgrade --pkg <ver> [component]` | Upgrade entire cloud or component |
| `sn_install --pkg <ver> --sn_uname <sn>` | Fresh install an SN |
| `cc_install --pkg <ver>` | Fresh install CCMaster+CCSlave |
| `snutils_upgrade --pkg <ver> --sn_uname <sn>` | Upgrade SNUtils only |
| `fw_upgrade --sn_uname <sn> --upgrade_mr_fw\|--upgrade_drive_fw` | Upgrade MR or drive firmware |
| `check_networking [--sn_uname <sn>]` | Verify network connectivity |
| `check_all_vsa_status [--vpsas\|--zios]` | Check VPSA/ZIOS health |
| `register_images --pkg <ver> [--vpsa\|--ccvm\|--zios] [--set_as_default]` | Register images in Glance |
| `reconfigure_drbd` | Reconfigure DRBD to match settings |
| `show_config` | Show installer config |
| `set_config --param <key> [--value <val>]` | Set installer config |

## cloud_upgrade component flags

```bash
--all      # SNs + VPSAs + CCVM + ZIOS
--sns      # Storage Nodes only
--vpsas    # VPSA VCs only
--ccvm     # CCVM only
--zios     # ZIOS/NGOS only
--snutils  # SNUtils package only
```

## Key flags

| Flag | Effect |
|------|--------|
| `--force` | Skip nova/SN version mismatch + skip "very old version" check |
| `--skip_vsa_checks` | Skip VPSA health checks (use when VPSAs hibernated) |
| `--skip_zios_health_checks` | Skip ZIOS health checks |
| `--force_ofed_4_4` | Force OFED 4.4 (legacy hardware) |
| `--sn_uname <sn1,sn2>` | Target specific SNs |
| `--remote_repo <url>` | Specify remote package source |

## Common errors and fixes

### "different versions for nova[X] and SN[Y]. Cant continue"

Cause: nova and zadara-sn-noble package versions don't match on an SN (partial upgrade).

```bash
zinstall --action sn_upgrade --pkg <ver> --sn_uname <sn> --force --skip_vsa_checks --skip_zios_health_checks
```

### SN Version shows "not-installed"

Cause: `zadara-sn-noble` is in `iF` (failed install) state — package installed but postinst failed.

```bash
# SSH to the affected SN and run:
dpkg --configure zadara-sn-noble
# Then verify:
zinstall --action list_sns
```

> Note: SN Version = `zadara-sn-noble` package (NOT `zadara-sn` which is always `un`)

### SNs not connected / "not installed"

Check: `zinstall --action list_sns` — all SNs must show `connected`.
If an SN shows `down`: fix HA/heartbeat first (see `zadara-ha-recovery` skill).

## Common recipes

```bash
# Standard cloud upgrade (VPSAs hibernated)
zinstall --action cloud_upgrade --pkg 26.06-90 --skip_vsa_checks --skip_zios_health_checks

# Upgrade SNs only, all at once
zinstall --action cloud_upgrade --pkg 26.06-90 --skip_vsa_checks --skip_zios_health_checks --sns

# Upgrade single SN (controlled, one at a time)
zinstall --action sn_upgrade --pkg 26.06-90 --sn_uname qa8-sn2 --skip_vsa_checks --skip_zios_health_checks

# Force-upgrade a partially upgraded SN
zinstall --action sn_upgrade --pkg 26.06-90 --sn_uname qa8-sn2 --force --skip_vsa_checks --skip_zios_health_checks

# Upgrade CCVM only
zinstall --action cloud_upgrade --pkg 26.06-90 --ccvm

# Download package first (from build share)
zinstall --action download_pkg --pkg 26.06-90 --remote_repo /mnt/share/builds/

# Check networking before upgrade
zinstall --action check_networking
```

## Package location

```
/mnt/nova/pkgs/<version>/
  zadara-installer_*.deb   ← installed first on all SNs
  zadara-snutils_*.deb
  sn-*.noble.iso           ← for fresh SN installs
  ccvm-*.img.tgz           ← CCVM image
  build.mf                 ← build manifest
```

`zadara-sn-noble` and nova packages come from apt repos, not from `.deb` files here.
