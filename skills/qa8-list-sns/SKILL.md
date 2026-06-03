Use when verifying which SN build a VPSA active VC sits on, checking for version mismatches before testing a fix, finding the active CCMaster, or auditing OS codenames across QA8 nodes.

## Command

Run on CCMaster (or any SN):

```bash
echo zadara | sudo -S zinstall --action list_sns
```

Via plink from Windows:
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ" `
  zadara@172.16.7.121 "echo zadara | sudo -S zinstall --action list_sns 2>&1"
```

## Output columns

| Column | Meaning |
|--------|---------|
| SN | Storage Node hostname (e.g. qa8-sn3) |
| Alloc_Zone_Name | Allocation zone (e.g. zone_0) |
| ROLE | `ccmaster` / `ccslave` / `sn` |
| Status | `connected` or disconnected |
| NOVA Version | OpenStack compute version on this SN |
| SN Version | SN software package version |
| Installer Version | zinstall installer version |
| Current CCMaster | Which SN holds the floating CCMaster IP (yes/no) |
| Distribution Codename | OS codename (`noble` = Ubuntu 24.04) |
| OFED Version | RDMA/InfiniBand driver version (for NVMe-oF / iSER) |

## Key use cases

- **Verify build before testing** — confirm the SN hosting the active VC has the expected build
- **Check VC vs SN version mismatch** — VC image can be ahead of SN (e.g. VC=26.06-83, SN=26.06-82 is normal; fix lives in VC)
- **Find active CCMaster** — `Current CCMaster: yes` identifies which SN holds the floating IP
- **OS audit** — confirm all SNs are on Noble before deploying Noble-specific fixes

## QA8 known state (2026-06-02)

| SN | Role | Version | CCMaster | OS |
|----|------|---------|----------|----|
| qa8-sn1 | ccmaster | 26.06-82 | no | noble |
| qa8-sn2 | ccslave | 26.06-82 | yes (active) | noble |
| qa8-sn3 | sn | 26.06-82 | no | noble |
| qa8-sn4 | sn | 26.06-82 | no | noble |
