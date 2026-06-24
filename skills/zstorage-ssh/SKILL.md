---
name: zstorage-ssh
description: Use when SSH-ing into any Zadara infrastructure node — CCMaster, CCVM, Storage Node, or VPSA VC. Covers WSL/sshpass (preferred), plink.exe (Windows fallback), multi-hop patterns, base64 quoting for complex commands, and SCP file transfer.
---

# zstorage-ssh

SSH into any Zadara infrastructure node: CCMaster, CCVM, SN, or VPSA VC.

**Confluence reference:** https://zadara.atlassian.net/wiki/x/P4AY5w

---

## Platform setup

| Platform | Method | Setup |
|----------|--------|-------|
| **WSL (Windows)** | `sshpass` + `ssh` | `wsl -d Ubuntu-24.04` — already installed |
| **macOS / Linux** | `sshpass` + `ssh` | `brew install sshpass` (Mac) or `apt install sshpass` (Linux) |
| **Windows (no WSL)** | plink.exe | `C:\Program Files\PuTTY\plink.exe` — fallback only |

**Prefer WSL or macOS** — native SSH handles PTY correctly, no quoting escapes, works non-interactively.  
**Use plink.exe only** when WSL is unavailable.

---

## Credentials

| Target | User | Password | Port |
|--------|------|----------|------|
| CCMaster | `zadara` | `zadara` | 22 |
| SN (from CCMaster) | `zadara` | `zadara` | 22 |
| CCVM | `zadministrator` | `Z@darA2o11` | 2022 |
| VPSA VC | `zadara` | `Z@darA2o11` | 2022 |

---

## Finding IPs

Look up environment IPs in [[zstorage-environments]], then set variables:

```bash
CCMASTER_IP="<look up in zstorage-environments>"   # e.g. CCMaster float for your environment
CCVM_IP="<CCMASTER_IP minus 1>"                    # CCVM is always CCMaster IP - 1
SN_HOSTNAME="<sn-hostname>"                        # from zstorage-environments SN table
```

**Active VC IP** — run on CCMaster:
```bash
nova-manage vsa list --inst <vsa-id>
# Find row with role "A" → first 10.0.x.x in fixed_IPs = VC_IP
```
Or use `scripts/get-active-vc-ip.sh <vsa-id>` (run on CCMaster).

**plink.exe hostkey** — look up per-environment in [[zstorage-environments]], or discover it:
```bash
ssh-keyscan -p 22 $CCMASTER_IP 2>/dev/null | ssh-keygen -lf - | awk '{print $2}'
```

---

## 1. SSH to CCMaster

### WSL / macOS / Linux (preferred)

> Add `-o UserKnownHostsFile=/dev/null` so that CCMaster floating to a different SN (and changing its hostkey) never blocks the connection.

```bash
sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP "<command>"
```

**Elevate to root:**
```bash
sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP "echo zadara | sudo -S -i bash -c '<command>'"
```

**From Claude Bash tool (via WSL):**
```bash
wsl -d Ubuntu-24.04 -u root -- sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP "<command>"
```

### Windows fallback (plink.exe)
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "$CCMASTER_HOSTKEY" `
  zadara@$CCMASTER_IP "<command>"
```
> `$CCMASTER_HOSTKEY` — look up in [[zstorage-environments]] or discover with ssh-keyscan (see Finding IPs above).  
> Hostkey changes when CCMaster floats to the other SN. With WSL/sshpass, `StrictHostKeyChecking=no` handles this automatically.

### If "Connection refused" on CCMaster
Ubuntu Noble sshd socket-activation issue. Run `scripts/fix-ccmaster-sshd.sh` as root on each SN directly (console/JViewer — you can't SSH to the floating IP if it's down). Must be applied on **both SNs** in the HA pair.

---

## 2. SSH to SN (from CCMaster)

SNs are reachable from CCMaster by hostname only — no direct external SSH.

### WSL / macOS / Linux (preferred)
```bash
sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP \
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no $SN_HOSTNAME '<command>'"
```

**As root on SN:**
```bash
sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP \
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no $SN_HOSTNAME \
   'echo zadara | sudo -S -i bash -c \"<command>\"'"
```

**Find which SN is active CCMaster:**
```bash
sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP "hostname"
```

### Windows fallback (plink.exe)
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "$CCMASTER_HOSTKEY" `
  zadara@$CCMASTER_IP `
  "sshpass -p zadara ssh -o StrictHostKeyChecking=no $SN_HOSTNAME '<command>'"
```

---

## 3. SSH to CCVM

CCVM is reached via CCMaster. IP = CCMaster IP minus 1. Port 2022.

### WSL / macOS / Linux (preferred)
```bash
sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no \
   zadministrator@$CCVM_IP '<command>'"
```

### Windows fallback (plink.exe)
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "$CCMASTER_HOSTKEY" `
  zadara@$CCMASTER_IP `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadministrator@$CCVM_IP '<command>'"
```

---

## 4. SSH to VPSA VC

VPSA VCs are on the isolated management network. Must go through CCMaster.

### Step 1 — Get active VC IP (see Finding IPs above)
```bash
nova-manage vsa list --inst <vsa-id>
```
Find role `A` row → extract `VC_IP` from `fixed_IPs`.

### Step 2 — Connect

#### WSL / macOS / Linux (preferred)

**Single command:**
```bash
sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no \
   zadara@$VC_IP '<command>'"
```

**Interactive shell (add -t / -tt):**
```bash
sshpass -p zadara ssh -t \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP \
  "sshpass -p 'Z@darA2o11' ssh -tt -p 2022 -o StrictHostKeyChecking=no zadara@$VC_IP"
```

**Root shell:**
```bash
sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no \
   zadara@$VC_IP 'echo Z@darA2o11 | sudo -S -i bash -c \"<command>\"'"
```

> **Note:** ProxyJump (`-W`) is blocked on CCMaster (`AllowTcpForwarding` is disabled). Always use the double-hop pattern above.

#### Windows fallback (plink.exe)
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "$CCMASTER_HOSTKEY" `
  zadara@$CCMASTER_IP `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@$VC_IP '<command>'"
```

---

## 5. Complex quoting — base64 trick

When a command contains `$`, quotes, or special chars that break across SSH hops, use `scripts/ssh-base64-cmd.sh`:

```bash
scripts/ssh-base64-cmd.sh $CCMASTER_IP $VC_IP "<command>"
```

The script base64-encodes the command locally so no quoting survives the hops. For Windows/plink, apply the same pattern manually: encode with `[Convert]::ToBase64String(...)` in PowerShell, then decode with `base64 -d | bash` on the remote end.

---

## 6. File transfer

### WSL / macOS / Linux
```bash
# Download from CCMaster to local
sshpass -p zadara scp \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  zadara@$CCMASTER_IP:/path/to/file.tar.gz ./file.tar.gz

# Download from VC (stage via CCMaster first)
sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@$CCMASTER_IP \
  "sshpass -p 'Z@darA2o11' scp -P 2022 -o StrictHostKeyChecking=no \
   zadara@$VC_IP:/path/file /tmp/file"
sshpass -p zadara scp \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  zadara@$CCMASTER_IP:/tmp/file ./file
```

### Windows fallback (pscp)
```powershell
& "C:\Program Files\PuTTY\pscp.exe" -batch -pw zadara `
  -hostkey "$CCMASTER_HOSTKEY" `
  zadara@$CCMASTER_IP:/path/to/file.tar.gz "$env:TEMP\file.tar.gz"
```

---

## Notes

- **WSL works out of the box** — `ping $CCMASTER_IP` reaches CCMaster via NAT. No extra networking config needed.
- **`UserKnownHostsFile=/dev/null`** — always add this on the outer hop. `StrictHostKeyChecking=no` alone won't override a *changed* key in `~/.ssh/known_hosts`; when CCMaster floats between SNs its hostkey changes. This flag bypasses the known_hosts file entirely.
- **macOS**: same commands as WSL. Install sshpass via `brew install hudochenkov/sshpass/sshpass`.
- **plink.exe hostkey**: changes when CCMaster floats between SNs. With WSL/sshpass, `StrictHostKeyChecking=no` handles this transparently.
- **sudo -S**: always needed when piping password to sudo (no terminal).
- **sshpass** is installed on CCMaster itself for password-based hops to SNs/VCs.
- **Too many auth failures** (plink only): add `-PubkeyAuthentication=no` or switch to WSL/sshpass.
