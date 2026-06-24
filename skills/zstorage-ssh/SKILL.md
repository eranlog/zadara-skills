---
name: zstorage-ssh
description: Use when SSH-ing into any Zadara infrastructure node — CCMaster, CCVM, Storage Node, or VPSA VC. Covers WSL/sshpass (preferred), plink.exe (Windows fallback), multi-hop patterns, base64 quoting for complex commands, and SCP file transfer.
---

# zstorage-ssh

SSH into any Zadara infrastructure node: CCMaster, CCVM, SN, or VPSA VC.

**Confluence reference:** https://zadara.atlassian.net/wiki/x/P4AY5w

## Platform setup

| Platform | Method | Setup |
|----------|--------|-------|
| **WSL (Windows)** | `sshpass` + `ssh` | `wsl -d Ubuntu-24.04` — already installed |
| **macOS / Linux** | `sshpass` + `ssh` | `brew install sshpass` (Mac) or `apt install sshpass` (Linux) |
| **Windows (no WSL)** | plink.exe | `C:\Program Files\PuTTY\plink.exe` — fallback only |

**Prefer WSL or macOS** — native SSH handles PTY correctly, no quoting escapes, works non-interactively.  
**Use plink.exe only** when WSL is unavailable.

## Credentials quick reference

| Target | User | Password | Port |
|--------|------|----------|------|
| CCMaster | `zadara` | `zadara` | 22 |
| SN (from CCMaster) | `zadara` | `zadara` | 22 |
| CCVM | `zadministrator` | `Z@darA2o11` | 2022 |
| VPSA VC | `zadara` | `Z@darA2o11` | 2022 |

**CCMaster float IP:** `172.16.7.121` (floats between sn1/sn2)

---

## 1. SSH to CCMaster

### WSL / macOS / Linux (preferred)
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 "<command>"
```

**Elevate to root:**
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 "echo zadara | sudo -S -i bash -c '<command>'"
```

**From Claude tools (Bash tool → WSL):**
```bash
wsl -d Ubuntu-24.04 -u root -- sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 "<command>"
```

### Windows fallback (plink.exe)
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 "<command>"
```
> Hostkey changes when CCMaster floats to the other SN — sn1: `SHA256:pAD98VJ8GVQv8h2lW0VEWoBPOIboYI8sDB/A1gy9QkU` / sn2: `SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E`

### If "Connection refused" on 172.16.7.121
Ubuntu Noble sshd socket-activation issue. Fix via JViewer/console on the active SN:
```bash
systemctl disable ssh.socket
systemctl enable ssh.service
systemctl start ssh.service     # CRITICAL — enable alone does NOT start it
ss -tlnp | grep :22             # verify 0.0.0.0:22 listening
```
Must be applied on **both sn1 and sn2**.

---

## 2. SSH to SN (from CCMaster)

SNs are only reachable from CCMaster by hostname (qa8-sn1, qa8-sn2, qa8-sn3, qa8-sn4).

### WSL / macOS / Linux (preferred)
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 \
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no <sn-hostname> '<command>'"
```

**As root on SN:**
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 \
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no <sn-hostname> \
   'echo zadara | sudo -S -i bash -c \"<command>\"'"
```

**Find active CCMaster SN:**
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 "hostname"
```

### Windows fallback (plink.exe)
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 `
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no <sn-hostname> '<command>'"
```

---

## 3. SSH to CCVM

CCVM runs at `172.16.7.120`, reached via CCMaster.

### WSL / macOS / Linux (preferred)
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no \
   zadministrator@172.16.7.120 '<command>'"
```

### Windows fallback (plink.exe)
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadministrator@172.16.7.120 '<command>'"
```

---

## 4. SSH to VPSA VC (active VC)

VPSA VCs are on the isolated management network `10.0.8.x`. Must go through CCMaster.

### Step 1 — Find active VC IP

```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 "nova-manage vsa list --inst <vsa-id>"
```

**Parse active VC:** find the line with role `A`. Extract the first `10.0.8.X` IP from `fixed_IPs`.

Example output:
```
instance_name  state   role  host      fixed_IPs
vsa-011-vc-0   active  A     qa8-sn1   10.0.8.24,10.2.8.24
vsa-011-vc-1   standby S     qa8-sn2   10.0.8.25,10.2.8.25
```
→ Active VC IP = `10.0.8.24`

### Step 2 — Connect to active VC

#### WSL / macOS / Linux (preferred)

**Run a single command (non-interactive):**
```bash
VC_IP="10.0.8.24"   # from step 1

sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no \
   zadara@${VC_IP} '<command>'"
```

**Interactive shell on VC (add -t / -tt):**
```bash
sshpass -p zadara ssh -t -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 \
  "sshpass -p 'Z@darA2o11' ssh -tt -p 2022 -o StrictHostKeyChecking=no zadara@${VC_IP}"
```
> `-t` on the outer hop requests PTY from CCMaster; `-tt` on the inner hop forces PTY on the VC.  
> You land directly at the VC prompt: `zadara@vsa-00000011-vc-0:~$`

**Root shell on VC:**
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no \
   zadara@${VC_IP} 'echo Z@darA2o11 | sudo -S -i bash -c \"<command>\"'"
```

> **Note:** `AllowTcpForwarding` is disabled on CCMaster — ProxyJump with `-W` is blocked with "administratively prohibited". Use the double-hop pattern above instead.

#### Windows fallback (plink.exe)
```powershell
$VC_IP = "10.0.8.24"

"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@$VC_IP '<command>'"
```

---

## 5. Complex quoting — base64 trick

When a command contains `$`, quotes, or special chars that break across SSH hops:

### WSL / macOS / Linux
```bash
CMD='python3 -c "import bcrypt; print(bcrypt.hashpw(b\"pass\", bcrypt.gensalt()).decode())"'
B64=$(echo "$CMD" | base64 -w0)

sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@10.0.8.24 \
   'echo Z@darA2o11 | sudo -S -i bash -c \"echo ${B64} | base64 -d | bash\"'"
```

### Windows fallback (PowerShell + plink)
```powershell
$script = 'python3 -c "import bcrypt; print(bcrypt.hashpw(b\"pass\", bcrypt.gensalt()).decode())"'
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))

"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@10.0.8.24 `
   'echo Z@darA2o11 | sudo -S -i bash -c \"echo $b64 | base64 -d | bash\"'"
```

---

## 6. File transfer

### WSL / macOS / Linux
```bash
# Download from CCMaster to local
sshpass -p zadara scp -o StrictHostKeyChecking=no \
  zadara@172.16.7.121:/path/to/file.tar.gz ./file.tar.gz

# Download from VC (stage via CCMaster)
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "sshpass -p 'Z@darA2o11' scp -P 2022 -o StrictHostKeyChecking=no \
   zadara@10.0.8.24:/path/file /tmp/file"
sshpass -p zadara scp -o StrictHostKeyChecking=no \
  zadara@172.16.7.121:/tmp/file ./file
```

### Windows fallback (pscp)
```powershell
& "C:\Program Files\PuTTY\pscp.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121:/path/to/file.tar.gz "$env:TEMP\file.tar.gz"
```

---

## Notes

- **WSL works out of the box** (WSL2 Ubuntu-24.04): `ping 172.16.7.121` reaches CCMaster via NAT — no mirrored networking config needed.
- **macOS**: same commands as WSL. Install sshpass via `brew install hudochenkov/sshpass/sshpass`.
- **plink.exe hostkey**: changes when CCMaster floats between sn1 and sn2. With sshpass+ssh, `StrictHostKeyChecking=no` avoids this issue entirely.
- **sudo -S**: always needed when piping password to sudo (no terminal).
- **sshpass** is installed on CCMaster itself for password-based hops to SNs/VCs.
- **Too many auth failures** (plink only): add `-PubkeyAuthentication=no` or use WSL/sshpass which doesn't probe the agent.
