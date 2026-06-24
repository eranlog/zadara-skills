---
name: zstorage-cc-api
description: Use when querying the Zadara Command Center REST API on QA8 — listing VPSAs, hibernating, restoring, or inspecting cloud capacity. Base URL is port 8888; auth via X-Token header. Run curl via CCMaster SSH or directly from WSL if the network reaches port 8888.
---

# zstorage-cc-api

Query the Zadara Command Center (CC) REST API on QA8 to list, inspect, or act on VPSAs.

## Endpoint

```
Base URL : https://yokneam-qa8.zadarastorage.com:8888
Cloud    : zadaraqa8
Auth     : -H 'X-Token: _LvPX5LiWPvjx73h18jK'
```

Run `curl` from **WSL (preferred)** or CCMaster:

```bash
# From WSL — via CCMaster SSH
sshpass -p zadara ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no \
  zadara@172.16.7.121 \
  "curl -sk -X GET '<URL>' -H 'X-Token: _LvPX5LiWPvjx73h18jK'"
```

```powershell
# Windows fallback — plink.exe
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 `
  "curl -sk -X GET '<URL>' -H 'X-Token: _LvPX5LiWPvjx73h18jK'"
```

## Common commands

### List all VPSAs
```bash
curl -sk -X GET \
  'https://yokneam-qa8.zadarastorage.com:8888/api/clouds/zadaraqa8/vpsas.json?per_page=30' \
  -H 'X-Token: _LvPX5LiWPvjx73h18jK'
```

### Get single VPSA (by CC numeric id)
```bash
curl -sk -X GET \
  'https://yokneam-qa8.zadarastorage.com:8888/api/clouds/zadaraqa8/vpsas/<id>.json' \
  -H 'X-Token: _LvPX5LiWPvjx73h18jK'
```

### Hibernate VPSA
```bash
curl -sk -X POST \
  'https://yokneam-qa8.zadarastorage.com:8888/api/clouds/zadaraqa8/vpsas/<id>/hibernate.json' \
  -H 'X-Token: _LvPX5LiWPvjx73h18jK'
```

### Restore (un-hibernate) VPSA
```bash
curl -sk -X POST \
  'https://yokneam-qa8.zadarastorage.com:8888/api/clouds/zadaraqa8/vpsas/<id>/restore.json' \
  -H 'X-Token: _LvPX5LiWPvjx73h18jK'
```

### Get cloud info (resources, inventory, networking)
```bash
curl -sk -X GET \
  'https://yokneam-qa8.zadarastorage.com:8888/api/clouds/zadaraqa8.json' \
  -H 'X-Token: _LvPX5LiWPvjx73h18jK'
```
Returns: cloud capabilities, flavors, total/used vCPUs, memory, drives, capacity, drive inventory breakdown.

## QA8 VPSA quick reference (snapshot — verify before use)

| CC id | internal_name | name  | type                     | status  | mgmt IP    |
|-------|---------------|-------|--------------------------|---------|------------|
| 9     | vsa-00000009  | BIM01 | Storage Array (Gen2 800) | created | 10.2.8.26  |

Active VC index: 1 → active VC HB IP = `10.0.8.27`

## Swagger UI

Full interactive API docs (open in browser, then fill in `zadaraqa8` as cloud_name and `_LvPX5LiWPvjx73h18jK` as token in the Authorize dialog):

```
https://s3.eu-central-1.amazonaws.com/api-doc-staging.zadara.com/index.html?urls.primaryName=Command%20Center
```

Note: Swagger "Execute" fails with CORS — use curl from the SN instead.

## How to retrieve or rotate the X-Token

The token is **not** returned by the REST API (`/api/users/1.json` omits it). Two ways to get it:

### Method 1 — CC Web UI (quickest)
1. Open `https://yokneam-qa8.zadarastorage.com:8888` and log in as admin
2. Click your email in the **top-right** corner
3. Go to Settings → URL becomes `/users/<id>/edit`
4. Scroll to **API key** section — the token is shown in the input field
5. Click **Regenerate** to create a new token (old token immediately invalidated)

### Method 2 — CCVM MySQL
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:pAD98VJ8GVQv8h2lW0VEWoBPOIboYI8sDB/A1gy9QkU" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadministrator@172.16.7.120 `
   'echo Z@darA2o11 | sudo -S mysql -u root command-center -e ""SELECT email, authentication_token FROM users;""'"
```

## Notes

- The token `_LvPX5LiWPvjx73h18jK` is the admin user (`qa@zadarastorage.com`) API token for QA8 CC. If you get 401 (token may have been rotated), retrieve the current token via web UI or CCVM DB.
- `-k` flag needed because the CC uses a self-signed TLS cert.
- The REST API (`/api/users/<id>.json`) does **not** return the token — it must be obtained via UI or DB.
- Internal API (from CCVM itself via localhost:3000) uses `?access_key=` query param — that format is different and the key is separate.
