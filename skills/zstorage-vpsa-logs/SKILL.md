---
name: zstorage-vpsa-logs
description: Use when reading live logs on a VPSA VC — tailing Rails production log, nginx access/error logs, Zadara daemon logs (VAC/VAM/VCC), or investigating SSO authentication failures. Includes log path table, SSO DB queries for identity_provider config, and process info.
---

# zstorage-vpsa-logs

Tail all relevant logs on a VPSA VC to observe live behavior during testing.

## Log locations on VPSA VC

| Log | Path | What it covers |
|---|---|---|
| Rails production log | `/var/log/vsa-gui/production.log` | All HTTP requests, SSO auth, errors, SQL |
| Puma stderr | `/var/log/vsa-gui/puma.stderr.log` | Puma/Rails startup errors, exceptions |
| Puma stdout | `/var/log/vsa-gui/puma.stdout.log` | Puma startup info |
| Nginx access | `/var/log/nginx/access.log` | All HTTP hits to the VPSA |
| Nginx error | `/var/log/nginx/error.log` | Nginx-level errors (5xx, upstream failures) |
| VAC | `/var/log/zadara/zadara_vac.log` | Virtual Application Controller |
| VAM | `/var/log/zadara/zadara_vam.log` | Virtual Application Manager |
| VCC | `/var/log/zadara/zadara_vccfg.log` | VC config daemon |
| CFG | `/var/log/zadara/zadara_cfg.py.log` | Configuration layer |
| FLC | `/var/log/zadara/zadara_flc.log` | Failover/life-cycle controller |

## How to find the VC IP

```bash
# WSL / macOS / Linux (preferred) — replace vsa-00000011 with target VPSA ID
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "echo zadara | sudo -S nova-manage vsa list --inst vsa-00000011 2>/dev/null"
# Look for "A " (active) line → first 10.0.8.x IP
```

```powershell
# Windows fallback (plink.exe)
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 `
  "echo zadara | sudo -S nova-manage vsa list --inst vsa-00000011 2>/dev/null"
# Look for "A " (active) line → first 10.0.8.x IP
```

## Tail all logs at once (background)

```bash
# WSL / macOS / Linux (preferred) — replace 10.0.8.24 with active VC IP
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@10.0.8.24 \
   'echo Z@darA2o11 | sudo -S tail -n0 -f /var/log/vsa-gui/production.log /var/log/vsa-gui/puma.stderr.log /var/log/nginx/error.log /var/log/nginx/access.log /var/log/zadara/zadara_vac.log /var/log/zadara/zadara_vam.log 2>/dev/null'"
```

```powershell
# Windows fallback (plink.exe) — replace 10.0.8.24 with active VC IP
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@10.0.8.24 'echo Z@darA2o11 | sudo -S tail -n0 -f /var/log/vsa-gui/production.log /var/log/vsa-gui/puma.stderr.log /var/log/nginx/error.log /var/log/nginx/access.log /var/log/zadara/zadara_vac.log /var/log/zadara/zadara_vam.log 2>/dev/null'"
```

## Tail only the Rails log (SSO focus)

```bash
# WSL / macOS / Linux (preferred)
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@10.0.8.24 \
   'echo Z@darA2o11 | sudo -S tail -n0 -f /var/log/vsa-gui/production.log 2>/dev/null'"
```

```powershell
# Windows fallback (plink.exe)
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:vbaYTe2w9iIfJVoSwzdtZprjY7NJfovKCCYGIUcvc4E" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@10.0.8.24 'echo Z@darA2o11 | sudo -S tail -n0 -f /var/log/vsa-gui/production.log 2>/dev/null'"
```

## Rails SSO-related code locations

App root: `/var/lib/zadara/www/Zadara-VSA-GUI/`

| Path | Contents |
|---|---|
| `app/controllers/` | Request handlers incl. OIDC callback controller |
| `app/services/` | SSO/auth services |
| `app/models/` | identity_provider model |
| `app/errors/sso_authentication_error.rb` | SSO error class |

## Database (identity providers)

DB: `vsa_gui_17` (for vsa-00000011, internal ID 17)  
Table: `identity_providers`  
Credentials: `mysql -u debian-sys-maint -plHAF2kggBK8Elna5 vsa_gui_17`

```sql
-- Read current IdP config
SELECT id, name, issuer, authorization_endpoint, config FROM identity_providers\G

-- Restore real CyberArk endpoints (TC-SSO-004 restore)
UPDATE identity_providers SET
  issuer='https://acg4189.id.cyberark.cloud/QA_VPSA_SSO/',
  authorization_endpoint='https://acg4189.id.cyberark.cloud/OAuth2/Authorize/QA_VPSA_SSO',
  config='{"scopes": "openid email profile", "jwks_uri": "https://acg4189.id.cyberark.cloud/OAuth2/Keys/QA_VPSA_SSO", "client_id": "65f62933-3f89-4116-9be4-bbe876242195", "token_endpoint": "https://acg4189.id.cyberark.cloud/OAuth2/Token/QA_VPSA_SSO", "userinfo_endpoint": "https://acg4189.id.cyberark.cloud/OAuth2/UserInfo/QA_VPSA_SSO"}',
  updated_at=NOW()
WHERE id='1a07908f-f580-41b4-aa9e-2e7480e75da9';
```

## Process info

Web server: **Puma** (cluster, 2 workers — check `ps aux | grep puma` for current PID)  
Socket: `unix:///var/lib/zadara/www/Zadara-VSA-GUI/tmp/sockets/vpsa-puma.sock`  
Background jobs: **Sidekiq** (`sidekiq.service`)  
Web proxy: **Nginx** (`nginx.service`)  
Service unit: `vc-gui.service`

## Notes

- CCMaster host key can change on failover — if plink says "FATAL ERROR: Host key not in manually configured list", do a connectionless test first to see the current key: `plink -batch -pw zadara zadara@172.16.7.121 "hostname" 2>&1 | head` (will print the new fingerprint)
- The vsa_gui DB name includes the internal VPSA ID (e.g. `vsa_gui_17` for vsa-00000011). Run `nova-manage vsa list` to find the internal ID.
- Rails does NOT cache DB queries across requests — DB changes take effect immediately without restart.
