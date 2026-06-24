---
name: zstorage-vpsa
description: Use when managing VPSA lifecycle via nova-manage vsa on CCMaster — hibernating, restoring, recovering from failed state, force-deleting stuck VCs, or reproducing double-restore race conditions. Includes state machine reference and recovery procedures.
argument-hint: <vsa-id>
---

# zstorage-vpsa

Manage Zadara VPSAs using `nova-manage vsa` on the CCMaster SN. Covers lifecycle operations (hibernate/restore), state recovery, and race condition testing.

**Confluence reference:** https://zadara.atlassian.net/wiki/x/DoBu6

## Connection

Run on CCMaster as root. See [[zstorage-ssh]] for connection patterns and IP discovery.

## When to use

- Hibernating or restoring a VPSA for maintenance or upgrade
- VPSA is in `failed` state and needs recovery
- Testing double-restore or double-hibernate race conditions
- Investigating why a VPSA has too many or too few VC instances
- Force-resetting VPSA state when normal hibernate/restore is blocked

## Key commands (run as root on CCMaster)

```bash
# List all VPSAs
nova-manage vsa list --all

# List specific VPSA with instances and drives
nova-manage vsa list --id=<ID> --all

# Hibernate
nova-manage vsa hibernate --id=<ID>

# Restore (IMPORTANT: always include --tenant_id and --user, else VPSA goes to failed state)
nova-manage vsa restore --id=<ID> --tenant_id <tenant_id> --user admin
# Find tenant_id: visible in nova-manage vsa list drive output as "user/tenant_id"

# Force-set VPSA status (USE WITH CARE — bypasses normal state machine)
nova-manage vsa update --id=<ID> --status=<status>
# Valid statuses: created, hibernated, failed, restoring, launching, ...

# Add a VC to a VPSA
nova-manage vsa add_vc --id=<vsa-id> --token=ZadaraServiceToken2011 --user=<tenant_admin> --tenant_id=<tenant_id>

# Delete a specific VC by ec2 instance ID
nova-manage vsa del_vc --id=<vsa-id> --ec2_id=<i-XXXXXXXX>
# Force delete (requires compute service to be DOWN on the instance's host SN)
nova-manage vsa del_vc --id=<vsa-id> --ec2_id=<i-XXXXXXXX> --force

# List orphaned instances
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

```bash
# 1. Force status to 'created' so hibernate can proceed
nova-manage vsa update --id=<ID> --status=created

# 2. Hibernate normally
nova-manage vsa hibernate --id=<ID>

# 3. If hibernate gets stuck in 'hibernate_offlining':
nova-manage vsa update --id=<ID> --status=hibernated

# 4. Restore to clean state
nova-manage vsa restore --id=<ID> --tenant_id <tenant_id> --user admin
```

**Why del_vc --force often fails:** Requires compute service to be DOWN on the instance's host SN. Use the status-forcing approach above instead.

## Recovery: VCs stuck in `restoring` state

Nova-vsa only auto-destroys stuck VCs when VPSA is in `LAUNCHING` or `BOOTING`. If stuck in `RESTORING`, force to `launching`:

```bash
nova-manage vsa update --id=<ID> --status=launching
# Wait ~30s — watch nova-vsa.log for "recreated: <new_instance_id>"
tail -f /var/log/nova/nova-vsa.log | grep "VSA ID <ID>"
```

**Note:** If the VPSA has zombie duplicate VCs from a race condition, nova-vsa will create one replacement per zombie. Let the VPSA reach `failed` (cleans up all instances), then: `update --status=hibernated` → `restore`.

## Testing the double-restore race condition

Reproduces the bug where two simultaneous restore requests spawn duplicate vc-0 instances.

```bash
# 1. Hibernate first
nova-manage vsa hibernate --id=<ID>
# Wait for 'hibernated' status:
watch -n5 "nova-manage vsa list --id=<ID> 2>/dev/null"

# 2. Fire two simultaneous restores (simulates UI double-click)
nova-manage vsa restore --id=<ID> --tenant_id <tenant_id> --user admin &
nova-manage vsa restore --id=<ID> --tenant_id <tenant_id> --user admin &
wait

# 3. Check 30s later — look for duplicate vc-0
nova-manage vsa list --id=<ID> --all 2>/dev/null
```

**Bug result (unfixed):** VPSA → `failed`, two `vc-0` instances on different SNs, both created at same timestamp.  
**Fixed result:** VPSA → `created`, exactly 2 instances (vc-0 + vc-1).

## Log evidence (nova-vsa.log)

When the race occurs, `/var/log/nova/nova-vsa.log` shows two different request UUIDs both setting `launching` in the same second:

```
INFO  [uuid-1] VSA ID <N>: Update VSA status to launching   ← worker 1
INFO  [uuid-2] VSA ID <N>: Update VSA status to launching   ← worker 2 (RACE!)
INFO  [uuid-1] VSA ID <N>: Update VSA status to failed
INFO  [uuid-2] VSA ID <N>: Update VSA status to failed
```

## Retrieving the VPSA initial admin password

Fresh VPSAs have a one-time temporary password set during provisioning. Retrieve from the CC portal:

```
<cc_url>/admin/vpsas/<id>/access_and_network
```

The **Password Key** field is the initial admin password for first VPSA login.

Once retrieved, log in to the VPSA API:
```bash
# Login — use the tenant user shown in provisioning portal
curl -s -X POST "https://$VC_IP/api/users/login.json" \
  -d "user[email]=<admin_email>&user[password]=<password_key>"
# Returns: {"response": {"status": 0, "user": {"access_key": "..."}}}
```

**Note:** The VPSA management IP for API access is the novabridge IP (`10.0.x.x`), accessible from SNs/CCMaster. The bebond IP (`10.2.x.x`) is for storage traffic only. See [[zstorage-environments]] for VPSA type mapping per environment.
