---
name: zstorage-vpsa-api
description: Use when querying or operating the Zadara VPSA REST API — listing volumes, pools, servers, attachments, snapshots, or checking VC health. Run curl from CCMaster to the internal VC IP since external VPSA URLs time out from WSL. Auth via X-Access-Key header.
argument-hint: <vsa-id>
---

# zstorage-vpsa-api

Query and operate the Zadara VPSA (Virtual Private Storage Array) REST API — volumes, pools, servers, attachments, snapshots, and VPSA health.

**Swagger UI:** https://s3.eu-central-1.amazonaws.com/api-doc-staging.zadara.com/index.html?urls.primaryName=VPSA%20Storage%20Array

---

## Setup

```
Base URL : https://$VC_IP/api      (internal VC management IP)
Auth     : X-Access-Key: <api_key>   (header)
        OR ?api_key=<api_key>         (query param)
Format   : JSON — all responses under a top-level key matching the resource
```

**Step 1 — Get active VC IP** (see [[zstorage-ssh]] → Finding IPs):
```bash
# On CCMaster:
nova-manage vsa list --inst <vsa-id>
# Find the row with role "A" → first 10.0.x.x in fixed_IPs = $VC_IP
```

**Step 2 — Get API key** — use [[vpsa-api-key]] skill, or: VPSA UI → Settings → User → API key.

**Step 3 — Run curl via CCMaster** (external VPSA URL times out from WSL):
```bash
# Double-hop to CCMaster, then curl internal VC IP — see [[zstorage-ssh]] for full pattern
VC_IP="<active-vc-ip>"
KEY="<api_key>"
# On CCMaster:
curl -sk -H "X-Access-Key: $KEY" "https://$VC_IP/api/<path>.json"
```

---

## VPSA Status & Health

### Get VPSA status
```bash
curl -sk -H "X-Access-Key: $KEY" "https://$VC_IP/api/vpsaversion.json"
```

### Get controllers (VC status, active/standby)
```bash
curl -sk -H "X-Access-Key: $KEY" "https://$VC_IP/api/vcontrollers.json"
```
Active VC has `"state": "active"`.

---

## Pools

### List pools
```bash
curl -sk -H "X-Access-Key: $KEY" "https://$VC_IP/api/pools.json"
```

### Create pool
```bash
curl -sk -X POST \
  -H "X-Access-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"pool1","capacity":100,"raid_groups":"1"}' \
  "https://$VC_IP/api/pools.json"
```

---

## Volumes

### List all volumes
```bash
curl -sk -H "X-Access-Key: $KEY" "https://$VC_IP/api/volumes.json"
```

### Get single volume
```bash
curl -sk -H "X-Access-Key: $KEY" "https://$VC_IP/api/volumes/<volume_name>.json"
```

### Create volume (block iSCSI)
```bash
curl -sk -X POST \
  -H "X-Access-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"vol1","pool":"pool1","size":10,"block_size":512}' \
  "https://$VC_IP/api/volumes.json"
```

### Delete volume
```bash
curl -sk -X DELETE \
  -H "X-Access-Key: $KEY" \
  "https://$VC_IP/api/volumes/<volume_name>.json"
```

---

## Servers

### List servers
```bash
curl -sk -H "X-Access-Key: $KEY" "https://$VC_IP/api/servers.json"
```

### Create server (iSCSI initiator)
```bash
curl -sk -X POST \
  -H "X-Access-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"display_name":"my-server","iqn":"iqn.2004-10.com.ubuntu:01:abc123"}' \
  "https://$VC_IP/api/servers.json"
```

### Get local iSCSI IQN (run on the client host)
```bash
cat /etc/iscsi/initiatorname.iscsi
```

---

## Attachments

### Attach volume to server
```bash
curl -sk -X POST \
  -H "X-Access-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"volume_name":"vol1","server_name":"my-server","access_type":"rw"}' \
  "https://$VC_IP/api/volumes/vol1/attach.json"
```

### Detach volume from server
```bash
curl -sk -X POST \
  -H "X-Access-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"server_name":"my-server","force":"NO"}' \
  "https://$VC_IP/api/volumes/vol1/detach.json"
```

### List volume attachments
```bash
curl -sk -H "X-Access-Key: $KEY" "https://$VC_IP/api/volumes/vol1/servers.json"
```

---

## Snapshots

### List snapshots for a volume
```bash
curl -sk -H "X-Access-Key: $KEY" "https://$VC_IP/api/volumes/<vol>/snapshots.json"
```

### Create snapshot
```bash
curl -sk -X POST \
  -H "X-Access-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"display_name":"snap1"}' \
  "https://$VC_IP/api/volumes/<vol>/snapshots.json"
```

---

## Event Log

> **Note:** Logs endpoint path not confirmed — `/api/logs.json` returned 404 in live testing. Check Swagger UI for the correct path.

```bash
curl -sk -H "X-Access-Key: $KEY" \
  "https://$VC_IP/api/logs.json?per_page=20" \
  | jq '.response.logs[] | {severity, description}'
```

---

## Notes

- All endpoints return `{"response": {...}, "status": 0}` on success. `status != 0` means error — check `"message"` field.
- `-k` flag required (self-signed cert).
- External VPSA URLs (`vsa-*.zadaravpsa.com`) time out from WSL — always curl the internal VC IP via CCMaster.
- The VPSA management IP (novabridge, `10.0.x.x`) is for API access. The bebond IP (`10.2.x.x`) is for storage traffic only.
- For SSO-enabled VPSAs, local `admin` credentials bypass SSO — use for QA lab testing.
