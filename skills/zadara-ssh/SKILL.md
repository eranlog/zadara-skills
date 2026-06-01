---
name: zadara-ssh
description: Use when SSH-ing into any Zadara QA infrastructure node — CCMaster, SN, CCVM, or VPSA VC. All nodes are on isolated management networks. On Windows, OpenSSH fails non-interactively; plink.exe is required. Includes jump-host patterns and base64 trick for complex commands.
---

# zadara-ssh Skill

SSH into any Zadara infrastructure node: CCMaster, CCVM, SN, or VPSA VC.

**Confluence reference:** https://zadara.atlassian.net/wiki/x/P4AY5w

## Quick Reference

| Target | Tool | Credentials | Port |
|---|---|---|---|
| CCMaster | plink.exe | zadara / zadara | 22 |
| CCVM | plink.exe → hop | zadministrator / Z@darA2o11 | 2022 |
| SN (from CCMaster) | plink.exe → ssh | zadara / zadara | 22 |
| VPSA VC (from CCMaster) | plink.exe → sshpass+ssh | zadara / Z@darA2o11 | 2022 |

**Always use plink.exe on Windows** (`C:\Program Files\PuTTY\plink.exe`) — OpenSSH fails non-interactively.

---

## 1. CCMaster

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "<hostkey>" `
  zadara@172.16.7.121 `
  "echo zadara | sudo -S -i bash -c '<command>'"
```

**QA8 hostkey (qa8-sn2):** `SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ`

If "Connection refused": floating IP moved after failover. Fix on active SN console:
```bash
systemctl disable ssh.socket && systemctl enable ssh.service && systemctl start ssh.service
```

---

## 2. SN (from CCMaster)

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara -hostkey "<hostkey>" `
  zadara@172.16.7.121 `
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@<sn-hostname> 'echo zadara | sudo -S -i bash -c \"<command>\"'"
```

SN hostnames: `qa8-sn1`, `qa8-sn2`, `qa8-sn3`, `qa8-sn4`

---

## 3. CCVM

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara -hostkey "<hostkey>" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadministrator@172.16.7.120 '<command>'"
```

**CCVM IP:** 172.16.7.120 | **Port:** 2022 | **User:** zadministrator | **Pass:** Z@darA2o11

---

## 4. VPSA VC

**Step 1 — Find active VC IP:**
```powershell
"C:\Program Files\PuTTY\plink.exe" ... zadara@172.16.7.121 `
  "echo zadara | sudo -S nova-manage vsa list --inst <vsa-id> 2>/dev/null"
# Find line with "A " → extract 10.0.8.X IP
```

**Step 2 — Connect:**
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara -hostkey "<hostkey>" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@<VC_IP> 'echo Z@darA2o11 | sudo -S -i bash -c \"<command>\"'"
```

**VC credentials:** zadara / Z@darA2o11 | **Port:** 2022

---

## 5. Complex Commands (base64 trick)

When a command contains `$`, quotes, or special chars that break across SSH hops:

```powershell
$script = 'your complex command here'
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
# Then on remote:
# echo $b64 | base64 -d | bash
```

---

## Common Issues

| Issue | Fix |
|---|---|
| "Connection refused" on 172.16.7.121 | Floating IP moved — get new hostkey from active SN |
| Host key mismatch | `plink -batch -pw zadara zadara@172.16.7.121 "hostname"` to get new fingerprint |
| "Too many auth failures" | Use plink.exe, not OpenSSH (OpenSSH tries all keys from agent) |
| sudo needs password | Always pipe: `echo zadara \| sudo -S -i` |
