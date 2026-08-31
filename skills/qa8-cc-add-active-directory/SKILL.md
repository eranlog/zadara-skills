Add an Active Directory / LDAP remote authentication server to Zadara Command Center on QA8, and troubleshoot the common "Connection reset by peer" LDAP bind failure.

## Prerequisite: a real AD domain on QA8

QA8 already has a live, usable AD domain for this purpose — no need to stand up a new one:

- **Domain:** `ZADARA2.LAB`
- **Domain Controller:** `ZADARA2DC.ZADARA2.LAB` — `172.16.0.111` (also resolves to `193.168.52.20`)
- **Domain admin:** `dima` (password known to Eran, not stored here)
- Full details / exploration notes: Confluence [Zadara Active Directory Framework — Learning Notes (Eran)](https://zadara.atlassian.net/wiki/spaces/WEBTEAM/pages/3940614218)

This is the same domain ~80+ VPSA machine accounts are already joined to (NAS/SMB AD join), but Command Center's own Remote Authentication feature is a **separate** integration (LDAP-based GUI auth, not the SMB domain join).

## Add the server (Command Center)

1. Command Center → gear icon (top right) → **Remote Authentication**.
2. **Add Authentication Server**, type **Active Directory**.
3. Fill in:
   - **Domain / Host:** `ZADARA2.LAB`
   - **Domain Alias:** `ZADARA2`
   - **Base DN:** `dc=ZADARA2,dc=LAB`
   - **DNS:** `172.16.0.111`
   - **Port:** `389` to start (no SSL) — simplest first pass, no cert needed
   - **SSL:** leave unchecked for the first attempt
4. Save.

Reference procedure (older, generic Zadara doc, same flow): Confluence [Import Active Directory or AD Users to Command Center](https://zadara.atlassian.net/wiki/spaces/ZO/pages/102006798).

## Import directory users

Users → **Import directory users** → select domain (`ZADARA2`) → enter `dima` + password → **Step 2: select users**.

### Known failure mode: "Connection reset by peer @ io_fillbuf"

If `/var/log/zadara/command-center/production.log` on CCVM shows:
```
Active Directory connection error: Connection reset by peer @ io_fillbuf - fd:NN
```
...on the `get_users` request, this is **not** a network routing/firewall problem — confirm first with a plain connectivity check (both usually succeed fine even when this error happens):
```bash
ping -c 3 172.16.0.111
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/172.16.0.111/389'   # usually opens fine
```
The TCP connection opens, then the domain controller resets it **during the LDAP bind itself** — the classic signature of a DC enforcing **LDAP signing / channel binding**, which rejects plain unsigned binds on port 389.

**Fix:** re-edit the auth server entry, switch to:
- **Port:** `636`
- **SSL:** checked
- Upload the DC's certificate if the form requires one for validation

Per the SOC2 test plan, port 389 **with SSL checked** is expected to fail outright (SSL requires 636) — that's a distinct, deliberate negative test case, not this bug.

## Where this fits in SOC2 regression testing

This whole flow maps to Command Center's SOC2 branch: `AD (as LDAP server) > configuration > Add auth server` and `> Import users`. See the "26.06 Regression — SOC2 Security Test Plan" (Confluence 4082270237) and the live results tracker "SOC2 Regression — Execution Results (26.06)" (Confluence 4096786464) for the current state of that testing effort.
