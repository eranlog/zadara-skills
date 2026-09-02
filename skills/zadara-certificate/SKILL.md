---
name: zadara-certificate
description: Use when Command Center's "Default Cloud Certificates" dashboard widget is empty, or when diagnosing why CCVM/VPSA/ZIOS/nova_client SSL certs aren't auto-updating from the license server. Covers the full auto-update procedure, where it lives, and how to pinpoint which stage is actually broken.
---

# Zadara Command Center certificate auto-update

Command Center periodically pulls fresh SSL certificates (types: `ccvm`, `vpsa`, `zios`, `nova_client`) from the cloud's configured license server and pushes them out to CCVM/SN/VPSA/ZIOS. The "Default Cloud Certificates" widget on the cloud dashboard (`clouds/show.html.haml`, gated by `ENV['INTERNET_ACCESS'] == "1"`) just displays whatever is currently sitting in the **local** cert cache — it does not itself talk to the license server.

## The full procedure

1. **Cron** runs the `certificates:update` rake task (`lib/tasks/certificates.rake`) periodically. Gated by `ENV["INTERNET_ACCESS"] == "1"`. Each run schedules a `CertificatesUpdaterWorker` Sidekiq job to fire after a random 1–1000s delay (`CERTIFICATES_UPDATER_WORKER_WAIT_MAX`, default 1000).
2. **Worker fires** (`app/workers/certificates_updater_worker.rb`, `sidekiq_options retry: false`) → calls `CertificateService::Updater.update`.
3. `Updater.update` (`app/services/certificate_service/updater.rb`) first checks `Zconfig.get("cloud.internet_access") == "1"` — bails out silently (no log line at all) if not.
4. Reads **local** certs from `/mnt/drbd/default_certificates/{ccvm,vpsa,zios,nova_client}.crt` via `CertificateService::LocalCertificates.get_all_crts(false)`.
5. Calls **remote** `GET certificate/info.json` via `CertificateService::LicenseServerApi` — base URL resolved as `ENV['LICENSE_SERVER_ACTIVATE_URL']` → `Zconfig.get("sn.license.url")` → hardcoded fallback `https://licensing.zadarastorage.com/license/activate.json` (path is stripped and rejoined with `certificate/info.json`). Auth via `X-User-Email`/`X-User-Token` headers, resolved the same fallback-chain way (env → Zconfig `sn.license.user_mail`/`user_token` → hardcoded defaults).
6. Compares local vs remote per type (missing locally / remote newer / different crt or key MD5) → builds a list of types to replace.
7. Calls **remote** `GET certificate/download.json` with the list of types → expects `{type => {"crt" => ..., "key" => ...}}` back.
8. For each type to replace: builds a `CertificateDetails`, validates it, pushes it out via the relevant `*Customization.upload_files` call (CCVM/VPSA/ZIOS/nova_client — same mechanism as ZSTRG-28550), and mirrors it into the local cache dir.

## Key files (on CCVM, under `/var/lib/zadara/command-center/`)

- `app/services/certificate_service/updater.rb` — orchestrates steps 3-8, logs everything with `[CERTIFICATE_UPDATER]` tag
- `app/services/certificate_service/license_server_api.rb` — the actual HTTP client (URL resolution, auth headers, `api_request`)
- `app/services/certificate_service/remote_certificates.rb` — thin wrapper (`.info` = step 5, `.download` = step 7)
- `app/services/certificate_service/local_certificates.rb` — local cache read/write + push-out to CCVM/VPSA/ZIOS/nova_client
- `app/workers/certificates_updater_worker.rb` — the Sidekiq job
- `lib/tasks/certificates.rake` — the cron entry point
- `app/views/clouds/show.html.haml` + `_certificates.html.haml` — the dashboard widget (pure display, KO-bound)

## Diagnostic steps (fastest path to root cause)

All commands run on CCVM (`172.16.7.120:2022`, `zadministrator`/`Z@darA2o11`, via CCMaster jump `172.16.7.121`, `zadara`/`zadara` — see the `zstorage-ssh` skill for the exact connection pattern; use WSL/sshpass with `-o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no`, not plink, if CCMaster recently failed over).

1. **Check the local cache** — if empty, nothing has ever successfully downloaded:
   ```
   ls -la /mnt/drbd/default_certificates
   ```
2. **Check the effective license server URL/creds**:
   ```
   /var/lib/zadara/scripts/utils/zconfig.py --get sn.license.url
   /var/lib/zadara/scripts/utils/zconfig.py --get sn.license.user_mail
   /var/lib/zadara/scripts/utils/zconfig.py --get sn.license.user_token
   /var/lib/zadara/scripts/utils/zconfig.py --get cloud.internet_access
   ```
3. **Check the Sidekiq log directly** — this is the ground truth, more reliable than `production.log` (Sidekiq jobs log to their own file):
   ```
   grep -i 'CertificatesUpdaterWorker\|CERTIFICATE_UPDATER' /var/log/zadara/command-center/sidekiq.log | tail -60
   ```
   A healthy run logs, in order: `start` → `Starting certificate updater` → `Remote certificate server - Found...` → `Local - Found...` → `Replacing certificate...` (per type) → `Certificates to replace [...]` → (silence = success, nothing more to log) or an explicit Ruby exception + `fail`.
4. **Test each license-server endpoint directly**, bypassing the app entirely, to isolate exactly which call is broken (`info.json` succeeding while `download.json` 500s is a real, confirmed failure mode — see incident below):
   ```
   curl -sk -X GET '<url-from-step-2-with-path-replaced>/certificate/info.json' \
     -H 'Content-Type: application/json' -H 'X-User-Email: <email>' -H 'X-User-Token: <token>' \
     -w '\nHTTP_STATUS:%{http_code}\n'

   curl -sk -X GET '<same-base>/certificate/download.json' \
     -H 'Content-Type: application/json' -H 'X-User-Email: <email>' -H 'X-User-Token: <token>' \
     -d '{"types":["ccvm","vpsa","zios","nova_client"]}' -w '\nHTTP_STATUS:%{http_code}\n'
   ```
5. **Force an immediate run** instead of waiting for cron/the random delay:
   ```
   /var/lib/zadara/scripts/ccvm/command-center-rake.sh certificates:update
   ```
   (This just re-schedules the worker with a new random 1-1000s delay — it does not run synchronously. Watch `sidekiq.log` afterward.)
6. **Manual reset/retry**: delete the local cache and re-trigger, to force a full re-fetch of every type:
   ```
   rm -f /mnt/drbd/default_certificates/*
   /var/lib/zadara/scripts/ccvm/command-center-rake.sh certificates:update
   # wait for the random delay + job runtime, then re-check sidekiq.log and the dashboard
   ```

## Known code-level gotchas (confirmed 2026-09-02, unchanged since the feature's 2021 origin)

`LicenseServerApi#api_request` has always had weak error handling — this is not a regression, it just happens to surface now:

```ruby
begin
  response = http.request(request)
rescue OpenSSL::SSL::SSLError => e
  Rails.logger.error("connection error: #{e.message}")
end
response = JSON.parse(response.body)   # <- runs even after the rescue fires (response is nil -> crashes here instead)
response                                # <- HTTP status is NEVER checked; a 500 with a valid-JSON error body
                                         #    is silently treated as if it were real certificate data
```

- Only `OpenSSL::SSL::SSLError` is rescued. Connection-refused, DNS failure (`SocketError`), and timeouts (`Net::OpenTimeout`/`Net::ReadTimeout`) are **not** rescued — they raise unhandled.
- Even the one rescue path is broken: if it fires, `response` is left `nil`, and the very next line calls `response.body` → `NoMethodError` anyway. The rescue doesn't prevent a crash, it just logs a misleading "connection error" message first.
- HTTP status code is never inspected. If `download.json` returns `500 {"status":500,"error":"..."}`, that error body parses fine as JSON, so the code proceeds as if it were real cert data — then crashes downstream (`undefined method '[]' for nil`) trying to index a cert-type key that isn't in the error hash.
- `CertificatesUpdaterWorker` has `sidekiq_options retry: false` — any of the above failures kill the job once, silently, with zero retry and zero user-visible symptom beyond an exception line buried in `sidekiq.log`. The dashboard just stays empty forever.

## Reference incident (2026-09-02, QA8)

QA8's license server was migrated to a new container-based instance (`https://test.licensing.zadara.dev/...`, replacing an older Heroku-hosted one). `certificate/info.json` worked correctly (real data, all types). `certificate/download.json` returned `500 Internal Server Error` on the new server. Because of the gotchas above, this produced a silent `NoMethodError` crash in the Sidekiq worker, an empty local cert cache, and a permanently-empty "Default Cloud Certificates" dashboard widget - with no error visible anywhere except `sidekiq.log`. Root cause was isolated by curling both endpoints directly and comparing against the live worker's own log output for the exact same failure signature.
