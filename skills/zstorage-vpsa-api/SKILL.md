---
name: zstorage-vpsa-api
description: Use when querying or operating the Zadara VPSA REST API — listing volumes, pools, servers, attachments, snapshots, or checking VC health. Always run curl via CCMaster (internal IP 10.0.8.x) since external VPSA URLs time out from WSL. Auth via X-Access-Key header.
---

# zstorage-vpsa-api

Query and operate the Zadara VPSA (Virtual Private Storage Array) REST API — volumes, pools, servers, attachments, snapshots, and VPSA health.

**Swagger UI:** https://s3.eu-central-1.amazonaws.com/api-doc-staging.zadara.com/index.html?urls.primaryName=VPSA%20Storage%20Array

---

## Endpoint & Auth

```
Base URL : https://vsa-<id>-<cloud-host>.zadaravpsa.com/api
Auth     : X-Access-Key: <api_key>   (header)
        OR ?api_key=<api_key>         (query param)
Format   : JSON — all responses under a top-level key matching the resource
```

**QA8 FARM1 VPSA (vsa-00000011):**
```
URL     : https://vsa-00000011-zadara-qa8.zadaravpsa.com
User    : admin / 1q2w3e4r
```

Get the API key — use skill `/vpsa-api-key`, or via VPSA UI: Settings → User → API key.

**Run curl via CCMaster (external VPSA URL times out from WSL):**
```bash
# From WSL — double-hop to CCMaster, then curl to internal VC IP
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 \
  "curl -sk -X GET 'https://10.0.8.24/api/<path>.json' -H 'X-Access-Key: <api_key>'"
```

Internal VC IP for QA8 FARM1: `10.0.8.24` (active VC-0).  
Use `/vpsa-api-key` skill to get the access key first.

---

## VPSA Status & Health

### Get VPSA status
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/vpsaversion.json'
```

### Get controllers (VC status, active/standby)
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/vcontrollers.json'
```
Active VC has `"state": "active"`.

---

## Pools

### List pools
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/pools.json'
```

### Create pool
```bash
curl -sk -X POST \
  -H 'X-Access-Key: <key>' \
  -H 'Content-Type: application/json' \
  -d '{"name":"pool1","capacity":100,"raid_groups":"1"}' \
  'https://10.0.8.24/api/pools.json'
```

---

## Volumes

### List all volumes
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/volumes.json'
```

### Get single volume
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/volumes/<volume_name>.json'
```

### Create volume (block iSCSI)
```bash
curl -sk -X POST \
  -H 'X-Access-Key: <key>' \
  -H 'Content-Type: application/json' \
  -d '{"name":"vol1","pool":"pool1","size":10,"block_size":512}' \
  'https://10.0.8.24/api/volumes.json'
```

### Delete volume
```bash
curl -sk -X DELETE \
  -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/volumes/<volume_name>.json'
```

---

## Servers

### List servers
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/servers.json'
```

### Create server (iSCSI initiator)
```bash
curl -sk -X POST \
  -H 'X-Access-Key: <key>' \
  -H 'Content-Type: application/json' \
  -d '{"display_name":"my-server","iqn":"iqn.2004-10.com.ubuntu:01:abc123"}' \
  'https://10.0.8.24/api/servers.json'
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
  -H 'X-Access-Key: <key>' \
  -H 'Content-Type: application/json' \
  -d '{"volume_name":"vol1","server_name":"my-server","access_type":"rw"}' \
  'https://10.0.8.24/api/volumes/vol1/attach.json'
```

### Detach volume from server
```bash
curl -sk -X POST \
  -H 'X-Access-Key: <key>' \
  -H 'Content-Type: application/json' \
  -d '{"server_name":"my-server","force":"NO"}' \
  'https://10.0.8.24/api/volumes/vol1/detach.json'
```

### List volume attachments
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/volumes/vol1/servers.json'
```

---

## Snapshots

### List snapshots for a volume
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/volumes/<vol>/snapshots.json'
```

### Create snapshot
```bash
curl -sk -X POST \
  -H 'X-Access-Key: <key>' \
  -H 'Content-Type: application/json' \
  -d '{"display_name":"snap1"}' \
  'https://10.0.8.24/api/volumes/<vol>/snapshots.json'
```

---

## Event Log

> **Note:** Logs endpoint path not confirmed — `/api/logs.json` returned 404 in live testing. Check Swagger UI for the correct path.

```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://10.0.8.24/api/logs.json?per_page=20' \
  | jq '.response.logs[] | {severity, description}'
```

---

## Notes

- All endpoints return `{"response": {...}, "status": 0}` on success. `status != 0` means error — check `"message"` field.
- `-k` flag required (self-signed cert).
- **WSL cannot reach `vsa-*.zadaravpsa.com` external URLs** — always run curl via CCMaster to internal VC IP (`10.0.8.24` for QA8 FARM1 vc-0).
- Use `/vpsa-api-key` skill to retrieve or rotate the API key. The access_key POST also uses internal IP via CCMaster.
- For SSO-enabled VPSAs, local admin credentials bypass SSO — use `admin/1q2w3e4r` for QA8 FARM1.
