---
name: zstorage-ngos-api
description: Use when querying the Zadara NGOS NAS Gateway REST API — NFS exports, SMB shares, object storage containers, NAS users, or NAS pools. Shares the same base URL and auth key as the VPSA block API; NAS resources live under /api/v2/nas/ paths.
---

# zstorage-ngos-api

Query and operate the Zadara NGOS (NAS Gateway) REST API — NAS pools, NFS exports, SMB shares, object storage containers, users, and quotas.

**Swagger UI:** https://s3.eu-central-1.amazonaws.com/api-doc-staging.zadara.com/index.html?urls.primaryName=NGOS

---

## Endpoint & Auth

```
Base URL : https://vsa-<id>-<cloud-host>.zadaravpsa.com/api/v2
Auth     : X-Access-Key: <api_key>   (same key as VPSA block API)
```

NGOS API shares the same base URL and auth as the VPSA Storage Array API. NAS-specific resources live under `/nas/` paths.

**QA8 FARM1 (vsa-00000011):**
```
URL : https://vsa-00000011-zadara-qa8.zadaravpsa.com
```

---

## NAS Pools

### List NAS pools
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://vsa-00000011-zadara-qa8.zadaravpsa.com/api/v2/pools.json' \
  | jq '.response.pools[] | {name, capacity, used, type}'
```

---

## NFS Exports

### List NFS exports
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://vsa-00000011-zadara-qa8.zadaravpsa.com/api/v2/nas/nfs_exports.json'
```

### Get single NFS export
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://vsa-00000011-zadara-qa8.zadaravpsa.com/api/v2/nas/nfs_exports/<name>.json'
```

### Create NFS export
```bash
curl -sk -X POST \
  -H 'X-Access-Key: <key>' \
  -H 'Content-Type: application/json' \
  -d '{"display_name":"nfs-share1","pool":"pool1","size":50}' \
  'https://vsa-00000011-zadara-qa8.zadaravpsa.com/api/v2/nas/nfs_exports.json'
```

---

## SMB (CIFS) Shares

### List SMB shares
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://vsa-00000011-zadara-qa8.zadaravpsa.com/api/v2/nas/smb_shares.json'
```

### Create SMB share
```bash
curl -sk -X POST \
  -H 'X-Access-Key: <key>' \
  -H 'Content-Type: application/json' \
  -d '{"display_name":"smb-share1","pool":"pool1","size":50}' \
  'https://vsa-00000011-zadara-qa8.zadaravpsa.com/api/v2/nas/smb_shares.json'
```

---

## Object Storage (S3-compatible)

### List object storage containers
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://vsa-00000011-zadara-qa8.zadaravpsa.com/api/v2/nas/object_storage_containers.json'
```

---

## NAS Users & Groups

### List NAS users
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://vsa-00000011-zadara-qa8.zadaravpsa.com/api/v2/nas/users.json'
```

### List NAS groups
```bash
curl -sk -H 'X-Access-Key: <key>' \
  'https://vsa-00000011-zadara-qa8.zadaravpsa.com/api/v2/nas/groups.json'
```

---

## Notes

- NGOS API shares the same auth key as the block (VPSA Storage Array) API.
- `-k` flag required (self-signed cert).
- Use `/vpsa-api-key` skill to retrieve or rotate the API key.
- Not all VPSAs have NAS enabled — verify NGOS is licensed/enabled before calling NAS endpoints.
