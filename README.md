# zadara-skills

Claude Code skills for Zadara QA infrastructure.

## Skills

### SSH & Access

| Skill | Description |
|-------|-------------|
| [zadara-ssh](skills/zadara-ssh) | SSH into any Zadara node — CCMaster, SN, CCVM, or VPSA VC. Includes plink.exe patterns for Windows. |
| [ssh-ccvm](skills/ssh-ccvm) | SSH into CCVM on any QA cloud (QA8, QA11, QA14, QA27). Hosts Command Center and eCommerce portal. |
| [qa8-ssh-active-vc](skills/qa8-ssh-active-vc) | SSH into the active VC of a QA8 VPSA via CCMaster. Identifies active VC automatically. |

### VPSA Management

| Skill | Description |
|-------|-------------|
| [qa8-vpsa-list](skills/qa8-vpsa-list) | List all VPSAs on QA8 with status, active VC, and creation time. |
| [vpsa-api-key](skills/vpsa-api-key) | Get a VPSA admin API token. Use when API calls fail with status 1793 or access denied. |
| [create-vpsa-server](skills/create-vpsa-server) | Register a Linux server on a VPSA via REST API. |
| [create-block-volume](skills/create-block-volume) | Create block volumes via REST API. Handles "data reduction bundle disabled" errors. |
| [qa8-vpsa-attach-server](skills/qa8-vpsa-attach-server) | Connect an IO server to a QA8 VPSA volume end-to-end. |
| [vpsa-iscsi-connect](skills/vpsa-iscsi-connect) | Full iSCSI setup — iface, CHAP, login, verify device. Use when login fails with error 24. |

### Infrastructure & Diagnostics

| Skill | Description |
|-------|-------------|
| [qa8-list-sns](skills/qa8-list-sns) | List all QA8 SNs with build versions, roles, OS codename. Use before testing a fix. |
| [cc-db-query](skills/cc-db-query) | Run SQL against CC database on CCVM — cloud ages, VPSA history, SN records. |
| [logs](skills/logs) | Tail Zadara logs on a VPSA VC, SN, or CCMaster. |
| [zsnap](skills/zsnap) | Collect a Zadara diagnostic snapshot, upload to S3, add path to Jira. |

## Installation

```bash
cd ~/.claude/plugins
git clone https://github.com/eranlog/zadara-skills
```

Restart Claude Code — skills load automatically.

## Contributors

Built by [eranlog](https://github.com/eranlog) and Claude.
