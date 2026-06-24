---
name: zstorage-cc-api
description: Use when querying the Zadara Command Center REST API — listing VPSAs, hibernating, restoring, or inspecting cloud capacity. Base URL is port 8888; auth via X-Token header. Run curl via CCMaster SSH or directly from WSL if the network reaches port 8888.
argument-hint: <cloud-id>
---

# zstorage-cc-api

Query the Zadara Command Center (CC) REST API to list, inspect, or act on VPSAs.

## Endpoint & Auth

```
Base URL : https://<cc-hostname>:8888
Cloud    : <cloud-id>   (e.g. zadaraqa8)
Auth     : X-Token: <token>
```

Get the token — see **How to retrieve the X-Token** below. See [[zstorage-environments]] for the CC hostname per environment.

Connection: run `curl` from CCMaster or from WSL if port 8888 is reachable. See [[zstorage-ssh]] for SSH patterns.

## Common commands

### List all VPSAs
```bash
curl -sk -X GET \
  "https://<cc-hostname>:8888/api/clouds/<cloud-id>/vpsas.json?per_page=30" \
  -H "X-Token: <token>"
```

### Get single VPSA (by CC numeric id)
```bash
curl -sk -X GET \
  "https://<cc-hostname>:8888/api/clouds/<cloud-id>/vpsas/<id>.json" \
  -H "X-Token: <token>"
```

### Hibernate VPSA
```bash
curl -sk -X POST \
  "https://<cc-hostname>:8888/api/clouds/<cloud-id>/vpsas/<id>/hibernate.json" \
  -H "X-Token: <token>"
```

### Restore (un-hibernate) VPSA
```bash
curl -sk -X POST \
  "https://<cc-hostname>:8888/api/clouds/<cloud-id>/vpsas/<id>/restore.json" \
  -H "X-Token: <token>"
```

### Get cloud info (resources, inventory, networking)
```bash
curl -sk -X GET \
  "https://<cc-hostname>:8888/api/clouds/<cloud-id>.json" \
  -H "X-Token: <token>"
```
Returns: cloud capabilities, flavors, total/used vCPUs, memory, drives, capacity, drive inventory breakdown.

## Swagger UI

Full interactive API docs:
```
https://s3.eu-central-1.amazonaws.com/api-doc-staging.zadara.com/index.html?urls.primaryName=Command%20Center
```
Fill in the cloud name and token in the Authorize dialog. Note: Swagger "Execute" fails with CORS — use curl instead.

## How to retrieve or rotate the X-Token

### Method 1 — CC Web UI (quickest)
1. Open `https://<cc-hostname>:8888` and log in as admin
2. Click your email in the **top-right** corner → Settings
3. Scroll to **API key** section — the token is shown in the input field
4. Click **Regenerate** to create a new token (old token immediately invalidated)

### Method 2 — CCVM database

SSH to CCVM (see [[zstorage-ssh]]), then query the CC database directly.
CC uses PostgreSQL on newer builds — check which is running:
```bash
# On CCVM (try psql first, fall back to mysql):
sudo -u postgres psql "command-center" -c "SELECT email, authentication_token FROM users LIMIT 5;" 2>/dev/null \
  || mysql -u root "command-center" -e "SELECT email, authentication_token FROM users;" 2>/dev/null
```

## Notes

- `-k` flag needed — CC uses a self-signed TLS cert.
- The REST API (`/api/users/<id>.json`) does **not** return the token — use Method 1 or 2 above.
- Internal API (from CCVM via localhost:3000) uses `?access_key=` query param — different format and separate key.
- See [[zstorage-environments]] for QA environment CC hostnames and default credentials.
