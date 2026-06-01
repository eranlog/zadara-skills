Get an API access token from a VPSA using a VPSA-local user account.

## Background

The VPSA has its own user management, **separate from Command Center**.
- `zadara_cloud_admin` is a CC proxy user — it cannot make VPSA API calls
- You need a **VPSA-local user** (created inside the VPSA itself)
- The token is session-based; pass it as `?access_key=<token>` or `X-Access-Key: <token>` header

## Usage

- No args: prompts for VPSA frontend IP, username, password
- With args: `<vpsa_frontend_ip> <username> <password>`

Example: `vpsa-api-key 10.2.8.22 admin <vpsa-admin-pass>`

## Step 1 — Ensure a VPSA-local user exists

If no user exists yet, create one via the VPSA GUI:
```
https://<vpsa-frontend-ip>   →  Settings → Users → Add User
```
Or check existing users (if you already have a token):
```bash
curl -sk "https://<vpsa-frontend-ip>/api/users.xml?access_key=<existing-token>"
```

## Step 2 — Get the token

```bash
VPSA_IP="10.2.8.22"
USER="admin"
PASS="<vpsa-admin-pass>"

TOKEN=$(curl -sk "https://$VPSA_IP/api/token?user=$USER&password=$PASS" \
  | grep -oE "<auth-token>[^<]+" | grep -oE "[^>]+$")

echo "Token: $TOKEN"
```

Response when successful:
```xml
<hash>
  <status type="integer">0</status>
  <user-key><your-api-token></user-key>
  <auth-token><your-api-token></auth-token>
</hash>
```

## Step 3 — Use the token

```bash
# As query param
curl -sk "https://$VPSA_IP/api/servers.xml?access_key=$TOKEN"

# As header (preferred for vpsa_linux.sh and POST requests)
curl -sk "https://$VPSA_IP/api/servers.xml" -H "X-Access-Key: $TOKEN"
```

## From Windows (via VC)

Run the curl through the active VC using plink:

```powershell
$VPSA_IP = "10.2.8.22"
$VC_IP   = "10.0.8.22"    # active VC mgmt IP

"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@$VC_IP `
   'curl -sk https://$VPSA_IP/api/token?user=admin\&password=<vpsa-admin-pass> | grep -oE \"<auth-token>[^<]+\" | grep -oE \"[^>]+$\"'"
```

## Known working tokens (QA8)

| VPSA | Frontend IP | Token (session) | Retrieved |
|------|-------------|-----------------|-----------|
| H101 (vsa-0000002e) | 10.2.8.22 | <your-api-token> | 2026-06-01 |

> Tokens are session-scoped and expire. Re-run Step 2 to get a fresh one.

## Notes

- Status `1793 - Your session expired` usually means wrong username, not expired token
- The CC wizard (Servers → ADD → Automatic) bakes a token into `vpsa_linux.sh` at download time — extract with: `grep ACCESSKEY ~/vpsa_linux.sh | head -1`
- For scripts, prefer generating a fresh token at runtime rather than hardcoding
