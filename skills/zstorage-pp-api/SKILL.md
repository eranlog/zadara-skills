---
name: zstorage-pp-api
description: Use when querying the Zadara Provisioning Portal REST API — clouds, VPSAs, users, or drive types via the eCommerce portal. Auth via X-Token header only (no email header). QA8 portal at yokneam-qa8.zadarastorage.com; API versions v2 and v3 both work.
---

# zstorage-pp-api

Query and operate the Zadara Provisioning Portal (PP) REST API — customer accounts, cloud management, VPSA provisioning, and billing.

The Provisioning Portal is the eCommerce/customer-facing layer that sits above Command Center.

---

## Endpoint & Auth

```
Base URL (QA8)  : https://yokneam-qa8.zadarastorage.com
Base URL (prod) : https://portal.zadara.com
Auth            : X-Token header (API token from user profile page)
```

**QA8 credentials:**
```
URL   : https://yokneam-qa8.zadarastorage.com
User  : admin (email: qa@zadarastorage.com)
Pass  : 1q2w3e4r
Token : 31BL1RwQTDMjytVteySL  (get current from Profile → API Token)
```

**Important: token auth uses `X-Token` header only — no email header needed:**
```bash
curl -sk -H "X-Token: <token>" "https://yokneam-qa8.zadarastorage.com/api/v3/clouds.json"
```

**Get your token:** Log in to the portal, go to Profile (top-right icon → Profile), the API Token field shows your current token. Click "Regenerate" if you need a new one.

**Get token via API (via Basic Auth):**
```bash
# Note: /api/v1/token endpoint has a known bug in QA8 — use profile page instead
B64=$(printf "qa@zadarastorage.com:1q2w3e4r" | base64 -w0)
curl -sk -X POST -H "Authorization: Basic $B64" \
  "https://yokneam-qa8.zadarastorage.com/api/v1/token"
```

---

## API Versions

The Grape API is mounted at `/api` and supports v1, v2, v3. Use v3 for latest schema:
```
/api/v3/clouds.json         ← full cloud objects (no app_engines)
/api/v2/clouds.json         ← same + app_engines/flavors
/api/v1/token               ← token login endpoint (buggy on QA8)
```

---

## Clouds

### List clouds
```bash
curl -sk \
  -H "X-Token: <token>" \
  "https://yokneam-qa8.zadarastorage.com/api/v3/clouds.json"
```

Response shape: `{"status":"success","data":[{"id":1,"name":"zadara-qa8","uuid":"41b17d81-...","enabled":true,...}]}`

### Get cloud details
```bash
curl -sk \
  -H "X-Token: <token>" \
  "https://yokneam-qa8.zadarastorage.com/api/v3/clouds/<cloud_id>.json"
```

---

## VPSAs

### List all VPSAs (across all clouds)
```bash
curl -sk \
  -H "X-Token: <token>" \
  "https://yokneam-qa8.zadarastorage.com/api/v3/vpsas.json"
```

Response shape: `{"status":"success","data":[{"id":N,"internal_name":"vsa-000000XX","name":"...","status":"active|deleted",...}]}`

### List VPSAs in a specific cloud
```bash
curl -sk \
  -H "X-Token: <token>" \
  "https://yokneam-qa8.zadarastorage.com/api/v3/clouds/<cloud_id>/vpsas.json"
```

### Create VPSA
```bash
curl -sk -X POST \
  -H "X-Token: <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "display_name": "my-vpsa",
    "cloud": "<cloud_id>",
    "engine_type": "vf",
    "drive_type": "SSD",
    "drive_quantity": 2,
    "allocation_zone": "zone_0"
  }' \
  "https://yokneam-qa8.zadarastorage.com/api/v3/clouds/<cloud_id>/vpsas.json"
```

### Hibernate VPSA
```bash
curl -sk -X POST \
  -H "X-Token: <token>" \
  "https://yokneam-qa8.zadarastorage.com/api/v3/clouds/<cloud_id>/vpsas/<vpsa_id>/hibernate.json"
```

### Restore VPSA
```bash
curl -sk -X POST \
  -H "X-Token: <token>" \
  "https://yokneam-qa8.zadarastorage.com/api/v3/clouds/<cloud_id>/vpsas/<vpsa_id>/restore.json"
```

---

## Users

### List users
```bash
curl -sk \
  -H "X-Token: <token>" \
  "https://yokneam-qa8.zadarastorage.com/api/v3/users.json"
```

Response shape: `{"status":"success","users":[{"id":1,"username":"admin","email":"qa@zadarastorage.com","admin":true,...}]}`

---

## Drive Types & Flavors

### List available drive types for a cloud
```bash
curl -sk \
  -H "X-Token: <token>" \
  "https://yokneam-qa8.zadarastorage.com/api/v2/clouds/<cloud_id>/drive_types.json"
```

---

## Access from WSL / CCMaster

The portal hostname resolves to the CCVM. From WSL, curl directly if lab DNS/routing is configured. From CCMaster, SSH to CCVM and curl localhost — see [[zstorage-ssh]] for CCVM double-hop patterns.

```bash
# On CCVM:
curl -sk -H "X-Token: <token>" "https://localhost/api/v3/clouds.json"
```

---

## Notes

- Auth: `X-Token: <token>` only — no `X-User-Email` needed (custom Grape auth, not Devise token_authenticatable)
- The portal uses a **Grape API** (not standard Rails controllers) mounted at `/api`
- `/api/v2/users/sign_in.json` endpoint does NOT exist on QA8 (skill was written for Heroku staging)
- The Heroku staging app (`zadara-provisioning-portal-stg-efb4f02108ec.herokuapp.com`) is a separate deployment — may be down or require different credentials
- `portal-staging.zadara.com` — DNS NXDOMAIN (Heroku staging app), do not use
- Accounts endpoint (`/api/v2/accounts.json`) returns 404 on QA8 — not implemented
