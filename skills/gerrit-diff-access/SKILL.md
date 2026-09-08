---
name: gerrit-diff-access
description: Use when you need to read an actual commit diff/message from Gerrit (gerrit.zadara-qa.com) to verify what a fix really changed — e.g. checking whether a fix is generation/engine-specific, confirming a root cause, or reading a commit message a Jira ticket references only by short hash.
argument-hint: <commit-hash-or-change-number>
---

# gerrit-diff-access

Read real commit diffs from Gerrit via its REST API, authenticated with a per-user
HTTP password. Anonymous access is blocked, so this always needs a live password —
there's no shared/service credential to reuse.

## Connectivity facts

- Host: `gerrit.zadara-qa.com`, **port 8080** (plain HTTP, not 8443/443).
- Port 443 is refused. Port 29418 (Gerrit SSH/git) is **blocked network-wide** —
  don't bother generating an SSH key for it, it will never connect.
- **WebFetch will fail** against `http://gerrit...:8080/...` — it auto-upgrades
  http→https, and this port has no TLS, so you get `WRONG_VERSION_NUMBER`. Use
  `curl` (or `git` for cloning) directly instead, never WebFetch.
- Anonymous REST calls return `[]` even though the PolyGerrit UI shell loads
  without login — the API itself requires auth regardless of what the UI shows.

## Getting a password (do this every session — passwords aren't reusable/shared)

Has to come from the user; you can't self-serve this one:

1. Ask the user to open `http://gerrit.zadara-qa.com:8080/settings/#HTTPCredentials`
   in their own logged-in browser (SSO login — you can't do this step yourself).
2. They click **GENERATE NEW PASSWORD**. A modal shows it once — "This password
   will not be displayed again."
3. They paste you the username (their Gerrit username, e.g. `eranlog` — not their
   email) and the password.
4. **Watch for 0/O and 1/l/I transcription errors** when they paste it back — a
   copy-pasted password is usually fine, but if they retype it by hand a single
   wrong character silently produces `401 thorized` (truncated "Unauthorized")
   with no other clue. If auth fails on the first try, ask them to re-check for
   exactly those characters before assuming the password itself is wrong.

Per the no-credentials-in-shared-docs convention, get a fresh password each
session rather than reusing one pasted in an old relay message or memory file.

## Using it — REST API (fastest for reading one commit)

```bash
curl -s -u "USERNAME:PASSWORD" \
  "http://gerrit.zadara-qa.com:8080/a/changes/?q=commit:<hash>&o=CURRENT_COMMIT&o=CURRENT_REVISION"
```

Gerrit prefixes every JSON response with `)]}'\n` as an XSSI guard — strip the
first 5 bytes (`tail -c +5`) before parsing, or the JSON parse will fail.

Response gives you `project`, `_number` (the change number), `current_revision`
(full commit hash), and the full commit message under
`revisions.<hash>.commit.message` — often enough on its own to answer "what did
this fix actually do."

**List changed files:**
```bash
curl -s -u "USERNAME:PASSWORD" \
  "http://gerrit.zadara-qa.com:8080/a/changes/<change_number>/revisions/<hash>/files/" \
  | tail -c +5
```

**Get the full unified diff** (base64-encoded in the response body):
```bash
curl -s -u "USERNAME:PASSWORD" \
  "http://gerrit.zadara-qa.com:8080/a/changes/<change_number>/revisions/<hash>/patch?zip=false" \
  | tail -c +5 | base64 -d
```
This is a real `git format-patch`-style diff — read it directly for the actual
before/after code, not just the commit message summary.

## Using it — git clone (when you need more than one commit / full file history)

```bash
git clone http://<username>@gerrit.zadara-qa.com:8080/<project-path>.git
# prompts for the HTTP password
```
`<project-path>` comes from the REST response's `project` field, e.g.
`zadarastorage/Zadara-VC`.

## Worked example (2026-09-08)

Verified ZSTRG-38882's fix (`65c5d1c57d`, "protobuf - restore 25.07 wire
compatibility of required strings") wasn't Gen2/Gen3-specific, after already
confirming the behavior live on both generations. The diff showed the fix
touches only `.proto` schema files (`common.proto`, `vac_wire.proto`,
`vam.proto`, `vam_wire.proto`, `zom_wire.proto`, `zpart.proto`, `sn_api.proto`)
— reverting fields from `optional string X` back to `required string X =
N [default = ""]` — plus two matching C/C++ caller-side tweaks. No engine-type
or generation branching anywhere in the diff, confirming it's a pure
wire-protocol schema fix applied uniformly, which is exactly why the live
behavior matched identically on both Gen2 and Gen3 VPSAs.
