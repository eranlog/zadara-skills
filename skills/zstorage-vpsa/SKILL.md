---
name: zstorage-vpsa
description: Use when managing VPSA lifecycle via nova-manage vsa on CCMaster — hibernating, restoring, recovering from failed state, force-deleting stuck VCs, or reproducing double-restore race conditions. Includes state machine reference and recovery procedures.
---

# zstorage-vpsa

Manage Zadara VPSAs using `nova-manage vsa` on the CCMaster SN. Covers lifecycle operations (hibernate/restore), state recovery, and race condition testing.

**Confluence reference:** https://zadara.atlassian.net/wiki/x/DoBu6

## When to use

- Hibernating or restoring a VPSA for maintenance or upgrade
- VPSA is in `failed` state and needs recovery
- Testing double-restore or double-hibernate race conditions (ZSTRG-37843)
- Investigating why a VPSA has too many or too few VC instances
- Force-resetting VPSA state when normal hibernate/restore is blocked

## Key commands (run as root on sn1/CCMaster)

```bash
# List all VPSAs
nova-manage vsa list --all

# List specific VPSA with instances and drives
nova-manage vsa list --id=<ID> --all

# Hibernate
nova-manage vsa hibernate --id=<ID>

# Restore (IMPORTANT: always include --tenant_id and --user, else VPSA goes to failed state)
nova-manage vsa restore --id=<ID> --tenant_id 2 --user admin
# On QA8: tenant_id=2, user=admin (visible in nova-manage vsa list drive output as "user/tenant_id")

# Force-set VPSA status (USE WITH CARE — bypasses normal state machine)
nova-manage vsa update --id=<ID> --status=<status>
# Valid statuses: created, hibernated, failed, restoring, launching, ...

# Add a VC to a VPSA (use vsa_id format, not numeric ID)
nova-manage vsa add_vc --id=vsa-00000035 --token=ZadaraServiceToken2011 --user=tenant_admin_k21lt --tenant_id=2

# Delete a specific VC by ec2 instance ID (normal path — no --force needed if compute is down)
nova-manage vsa del_vc --id=vsa-0000000c --ec2_id=i-0000008d
# Force delete (requires compute service to be DOWN on the instance's host SN)
nova-manage vsa del_vc --id=<ID> --ec2_id=<i-XXXXXXXX> --force

# List orphaned instances (instances with no VPSA)
nova-manage vsa orphan --action=list --objects=instances

# Clean orphaned instances
nova-manage vsa orphan --action=clean --objects=instances --force
```

## VPSA state machine (key states)

| State | Meaning |
|-------|---------|
| `created` | Healthy, VCs running |
| `hibernated` | VCs terminated, drives detached |
| `restoring` | Restore in progress (should be transient) |
| `launching` | VCs spawning |
| `hibernate_offlining` | VCs shutting down (should be transient) |
| `failed` | Error state — requires intervention |

## Recovery: VPSA stuck in `failed` state

When hibernate is blocked because VPSA is in `failed`:

```bash
# Run on sn1 as root

# 1. Force status to 'created' so hibernate can proceed
nova-manage vsa update --id=<ID> --status=created

# 2. Hibernate normally
nova-manage vsa hibernate --id=<ID>

# 3. If hibernate gets stuck in 'hibernate_offlining'
#    (an orphaned instance in 'networking' state never boots):
nova-manage vsa update --id=<ID> --status=hibernated

# 4. Do a single restore to recover to clean state
nova-manage vsa restore --id=<ID> --tenant_id 2 --user admin
```

**Why del_vc --force often fails:** It requires the compute service to be DOWN on the instance's host SN. While the SN is alive, it refuses to force-delete. Use the status-forcing approach above instead.

## Recovery: VCs stuck in `restoring` state (never auto-recovered)

Nova-vsa only auto-destroys and recreates stuck VCs when the VPSA is in `LAUNCHING` or `BOOTING` state. If the VPSA is in `RESTORING`, stuck VCs are counted as stuck forever — nova-vsa never cleans them up.

**Fix:** Force VPSA to `launching` — nova-vsa will immediately trigger `_destroy_vc_and_recreate_it` on stuck VCs (since their counters are already high):

```bash
# Run on sn1 as root
nova-manage vsa update --id=<ID> --status=launching
# Wait ~30s — watch nova-vsa.log for "add VC X to the list for monitoring"
# and "recreated: <new_instance_id>" entries
tail -f /var/log/nova/nova-vsa.log | grep "VSA ID <ID>"
```

**When to use:** VPSA is stuck in `restoring` for more than a few minutes, instances show `vc_internal_state: stuck` with `delete_attempts: 0` in the log.

**Note:** If the VPSA has zombie duplicate VCs (e.g., 2x vc-0 from ZSTRG-37843 race), nova-vsa will create one replacement per zombie, resulting in duplicate new VCs. In that case, let the VPSA reach `failed` (it will clean up all instances), then do: `update --status=hibernated` → `restore` for a clean restart.

## Testing the double-restore race condition

Reproduces the bug where two simultaneous restore requests spawn duplicate vc-0 instances.

```bash
# Run on sn1 as root

# 1. Hibernate first
nova-manage vsa hibernate --id=<ID>
# Wait ~2 min for 'hibernated' status:
watch -n5 "nova-manage vsa list --id=<ID> 2>/dev/null"

# 2. Fire two simultaneous restores (simulates UI double-click)
nova-manage vsa restore --id=<ID> --tenant_id 2 --user admin &
nova-manage vsa restore --id=<ID> --tenant_id 2 --user admin &
wait

# 3. Check 30s later — look for duplicate vc-0
nova-manage vsa list --id=<ID> --all 2>/dev/null
```

**Bug result (unfixed):** VPSA → `failed`, two `vc-0` instances on different SNs, both created at same timestamp.

**Fixed result:** VPSA → `created`, exactly 2 instances (vc-0 + vc-1).

## Log evidence (nova-vsa.log on sn1)

When the race occurs, `/var/log/nova/nova-vsa.log` shows two different request UUIDs both setting `launching` in the same second:

```
07:45:11  INFO  [06b413d8-...] VSA ID 2: Update VSA status to launching   ← worker 1
07:45:11  INFO  [86e70573-...] VSA ID 2: Update VSA status to launching   ← worker 2 (RACE!)
07:45:11  INFO  [06b413d8-...] VSA ID 2: Update VSA status to failed
07:45:11  INFO  [86e70573-...] VSA ID 2: Update VSA status to failed
```

## Retrieving the VPSA initial admin password

Fresh VPSAs have a one-time temporary password set during provisioning. Retrieve it from the CC provisioning portal (eCommerce portal):

```
{cc_url}/admin/vpsas/{id}/access_and_network
```

Example (QA8): `yokneam-qa8.zadarastorage.com/admin/vpsas/4/access_and_network`

The **Password Key** field on that page is the initial admin password for first login to the VPSA web UI and API.

Once retrieved, log in to the VPSA API:
```bash
# Login — use tenant user shown in provisioning portal (e.g. admin_a4Qj2)
curl -s -X POST http://<VPSA_NOVA_IP>/api/users/login.json \
  -d "user[email]=<admin_email>&user[password]=<password_key>"
# Returns: {"response": {"status": 0, "user": {"access_key": "..."}}}
# Use the access_key for all subsequent API calls:
curl -s "http://<VPSA_NOVA_IP>/api/servers.json?access_key=<access_key>"
```

**Note:** The VPSA management IP for API access is the **novabridge IP** (10.0.8.x), accessible from SNs/CCMaster. The bebond IP (10.2.8.x) is for storage traffic.

## VPSA types on QA8

| VPSA | vsa_id | Name | Type | VCs |
|------|--------|------|------|-----|
| ID 1 | vsa-00000001 | 101 | Gen3 (vsa.V3.H100.vf) | 2 |
| ID 2 | vsa-00000002 | 801 | Gen2 (vsa.V2.blast.vf) | 2 |
| ID 3 | vsa-00000003 | NGZ | ZIOS (premium_gen2) | 6 |

**Note:** ZIOS (NGZ) does NOT support hibernate/restore — do not test on VPSA 3.

