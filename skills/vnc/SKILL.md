---
name: vnc
description: Use when connecting to a VPSA/ZIOS VC's console via VNC — finding the hosting SN, the VC's actual VNC port, and connecting a client. Also documents a confirmed access-control gap (ZSTRG-39049) — VNC console login is NOT restricted to zadmin as designed docs claim.
---

# VNC Skill

Connect to a VPSA/ZIOS VC's raw console (the QEMU/KVM guest's own tty, not an SSH session) via VNC.

## Usage

```
/vnc <vsa-id>
```

Example: `/vnc vsa-00000004`

## Step 1 — find the hosting SN + instance name

Run on the cloud's CCMaster:
```bash
nova-manage vsa list --inst <numeric-id-or-vsa-id>
```
Output's `=== Instances ===` table gives `host` (the hosting SN, e.g. `qa8-sn3`) and `name`
(e.g. `i-00000032`) for the VC you want — usually the row marked `A` (active) under `role`.

**Gotcha:** `i-00000032` is nova's own instance-name field, NOT the actual libvirt domain
name. Don't feed it straight to `virsh` — it'll fail with `error: failed to get domain`.

## Step 2 — find the real libvirt domain name + VNC port

SSH to the hosting SN, then:
```bash
virsh -c qemu:///system list --all
```
Match by the numeric suffix — nova's `i-00000032` corresponds to libvirt's
`instance-00000032` (same hex ID, different prefix). Then:
```bash
virsh -c qemu:///system vncdisplay instance-00000032
# => :2   (meaning VNC port = 5900 + 2 = 5902)

virsh -c qemu:///system dumpxml instance-00000032 | grep -A2 graphics
# => <graphics type='vnc' port='5902' autoport='yes' listen='0.0.0.0' ...>
```
`listen='0.0.0.0'` (the common case observed) means it's reachable on the SN's own
management IP, not just localhost — no extra tunnel needed.

## Step 3 — connect

Get the SN's own mgmt IP from its login banner (`IPv4 address for eth1000: ...`) or from
the lab's environment reference, then point a VNC client at:
```
<sn_mgmt_ip>::<port>
```
(double-colon = explicit TCP port, e.g. `172.16.7.124::5902`). Works identically on an
isolated/offline cloud — the SN's mgmt IP is on the same reachable 172.16.7.x range
regardless of the cloud's own internet-access setting; no additional VNC-specific tunnel
was needed in testing.

You land directly on the VC's console login prompt (Ubuntu getty, `tty1`).

## Confirmed finding — VNC access control gap (ZSTRG-39049)

Design docs state VNC console login should be possible **only for the zadmin access
user**. Confirmed live on two independent environments (QA8 online cloud, QA3 isolated
cloud) that this is **not enforced**:

- **No VNC-layer authentication at all** — connecting with a plain VNC client reaches the
  console straight away, no VNC password prompt, since the port is bound to `0.0.0.0`
  with no VNC auth configured.
- **The OS login prompt accepts any valid local account** — both `opsadmin` (the
  lowest-privilege role, meant to be non-sudo/limited) and `zadministrator` (the general
  break-glass admin) logged in successfully and got a full interactive shell
  (`zadministrator` confirmed `uid=0(root)` via `id`). No zadmin-specific gate exists
  anywhere in this path.
- Filed as **[ZSTRG-39049](https://zadara.atlassian.net/browse/ZSTRG-39049)**, High
  priority, component VPSA.

Don't assume the "zadmin-only" restriction holds when testing VNC elsewhere — treat it
as unenforced until this ticket is resolved.
