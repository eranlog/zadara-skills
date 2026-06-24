---
name: zstorage-vpsa-logs
description: Use when reading live logs on a VPSA VC — tailing Rails production log, nginx access/error logs, Zadara daemon logs (VAC/VAM/VCC), or investigating SSO authentication failures. Includes log path table, SSO DB queries for identity_provider config, and process info.
argument-hint: <vsa-id>
---

# zstorage-vpsa-logs

Tail all relevant logs on a VPSA VC to observe live behavior during testing.

## Connection

Get the active VC IP first — see [[zstorage-ssh]] → Finding IPs section. Then double-hop via CCMaster to the VC.

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

## Tail all logs at once

Run `scripts/tail-vpsa-logs.sh` on the active VC via CCMaster double-hop (see [[zstorage-ssh]]).

Or manually:
```bash
# On the VC (as root):
tail -n0 -f /var/log/vsa-gui/production.log \
            /var/log/vsa-gui/puma.stderr.log \
            /var/log/nginx/error.log \
            /var/log/nginx/access.log \
            /var/log/zadara/zadara_vac.log \
            /var/log/zadara/zadara_vam.log
```

## Tail only the Rails log (SSO focus)

```bash
# On the VC (as root):
tail -n0 -f /var/log/vsa-gui/production.log
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

DB name: `vsa_gui_<internal_id>` — find internal ID from `nova-manage vsa list`.  
Table: `identity_providers`  
Credentials: `mysql -u debian-sys-maint -p<password> vsa_gui_<id>` — get password from `/etc/mysql/debian.cnf` on VC.

```sql
-- Read current IdP config
SELECT id, name, issuer, authorization_endpoint, config FROM identity_providers\G

-- Restore real CyberArk endpoints (TC-SSO-004 restore)
UPDATE identity_providers SET
  issuer='<issuer_url>',
  authorization_endpoint='<auth_endpoint>',
  config='<json_config>',
  updated_at=NOW()
WHERE id='<provider_id>';
```

## Process info

Web server: **Puma** (cluster, 2 workers — check `ps aux | grep puma` for current PID)  
Socket: `unix:///var/lib/zadara/www/Zadara-VSA-GUI/tmp/sockets/vpsa-puma.sock`  
Background jobs: **Sidekiq** (`sidekiq.service`)  
Web proxy: **Nginx** (`nginx.service`)  
Service unit: `vc-gui.service`

## Notes

- The vsa_gui DB name includes the internal VPSA ID (e.g. `vsa_gui_17` for internal ID 17). Run `nova-manage vsa list` to find the internal ID.
- Rails does NOT cache DB queries across requests — DB changes take effect immediately without restart.
