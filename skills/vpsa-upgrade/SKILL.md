Use when a VPSA upgrade is stuck, a VC is in the wrong state during upgrade, or zsnap_status is not progressing — or to monitor an in-progress upgrade.

## Normal upgrade flow

```
Phase 1 (upgrade first_vc, e.g. vc-1):
  Step: offline     → take vc-1 offline (zsnap + crm standby)
  Step: add         → replace vc-1 instance with new image
  Step: online      → bring new vc-1 back online (standby → active)
  Step: upgrade_ha  → make new vc-1 active, passivate vc-0

Phase 2 (upgrade vc-0):
  Same steps for vc-0
  When done → both VCs on new image → VPSA Normal
```

## Monitor progress (from active VC)

```bash
tail -F /var/log/syslog | grep -i step
```

Key log lines:
- `zsnap response for action_XXXXX ... zsnap_status: started` → waiting for zsnap
- `wait_for_power_state_on_vc: PEER VC ... status failed` → VC in wrong state
- `change-vsa step start: step <name> state ok` → step completed ✓
- `do_zsnap p.poll() returned None in attempt N` → zsnap running (NORMAL, wait)

## Common stuck points and fixes

### 1. zsnap_status stuck at "started"

**Symptom:** Log repeats `zsnap response for action_XXXXX ... zsnap_status: started` for >15 min

**Cause:** The CC-triggered zsnap on the VC that went offline was interrupted before reporting completion.

**Fix — update extra_spec to set zsnap_status=done:**

```bash
# Step 1: GET current action value (run from CCMaster)
curl -sk -H 'X-Auth-Token: ZadaraServiceToken2011' \
  --cert /etc/nova/client.crt --key /etc/zadara/client.key \
  "https://127.0.0.1:8774/v1.1/<tenant_id>/zadr-vsa/<vsa_decimal_id>/extra_specs/action_XXXXX"

# Step 2: PUT with zsnap_status changed to "done"
curl -sk -X PUT \
  -H 'X-Auth-Token: ZadaraServiceToken2011' \
  -H 'Content-Type: application/json' \
  --cert /etc/nova/client.crt --key /etc/zadara/client.key \
  "https://127.0.0.1:8774/v1.1/<tenant_id>/zadr-vsa/<vsa_decimal_id>/extra_specs/action_XXXXX" \
  -d '{"action_XXXXX":"{\"initiator\":\"cc\",\"name\":\"upgrade_version\",\"target\":\"<img>\",\"status\":\"started\",\"start_time\":\"...\",\"status_time\":\"...\",\"message\":\"\",\"zsnap_status\":\"done\"}'
```

> ⚠️ Use PUT not POST — POST is blocked during upgrade ("operation in progress")

**Getting tenant_id and vsa decimal id:**
```bash
# From CCMaster:
nova-manage vsa list --all <vsa_id>
# → look for "user/tenant_id" in Drives section, e.g. "admin/2" → tenant_id=2
# → VPSA decimal id from vsa list output first column, e.g. 54 for vsa-00000036
```

### 2. VC stuck in wrong power state

**Symptom:** `wait_for_power_state_on_vc: PEER VC ... status failed (['offline', 'standby'] expected)`

**Cause:** VC was manually brought online (crm node online) when the upgrade needs it in standby/offline.

**Fix — put VC back into standby (from active VC):**
```bash
crm node standby vsa-XXXXXXXX-vc-N
```

### 3. CRM node online needed

If upgrade has been waiting for a VC to reach standby/online and it's stuck:
```bash
crm node online vsa-XXXXXXXX-vc-N   # from active VC
```

## Extra_specs API reference

All calls from CCMaster using certs:

```bash
# GET all extra_specs for a VPSA
curl -sk -H 'X-Auth-Token: ZadaraServiceToken2011' \
  --cert /etc/nova/client.crt --key /etc/zadara/client.key \
  "https://127.0.0.1:8774/v1.1/<tenant>/zadr-vsa/<id>/extra_specs"

# GET specific action
curl -sk -H 'X-Auth-Token: ZadaraServiceToken2011' \
  --cert /etc/nova/client.crt --key /etc/zadara/client.key \
  "https://127.0.0.1:8774/v1.1/<tenant>/zadr-vsa/<id>/extra_specs/action_XXXXX"

# PUT to update (works during upgrade, POST is blocked)
curl -sk -X PUT \
  -H 'X-Auth-Token: ZadaraServiceToken2011' \
  -H 'Content-Type: application/json' \
  --cert /etc/nova/client.crt --key /etc/zadara/client.key \
  "https://127.0.0.1:8774/v1.1/<tenant>/zadr-vsa/<id>/extra_specs/action_XXXXX" \
  -d '{"action_XXXXX": "<json_value_with_zsnap_status_done>"}'
```

## Trigger upgrade via CLI (from CCVM)

```bash
vpsa-requests.py --token ZadaraServiceToken2011 --tenant <tenant_id> \
  --vsa <vsa_id> --action upgrade_version \
  --target <new_image.img> --data <current_image.img>
```

## Known QA8 values

| VPSA | vsa_id | Decimal ID | Tenant ID |
|------|--------|------------|-----------|
| 911 | vsa-00000036 | 54 | 2 |
| BRAVO | vsa-00000037 | 55 | 2 |

## Do NOT

- Do not run `crm node online` on a VC that the upgrade is trying to keep offline
- Do not use POST for extra_specs during an upgrade (blocked) — use PUT
- Do not interrupt `do_zsnap p.poll() returned None` — this is normal, just wait
