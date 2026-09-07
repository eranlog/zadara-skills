---
name: openotp-block-release
description: Use when you need to simulate "openOTP server unreachable" for Command Center or a VC (e.g. testing behavior during VC creation, login, or auth with OTP down) — how to actually block and release connectivity to the openOTP server, and the gotchas that make a naive block silently not work.
argument-hint: <ccvm-ip-or-vc-ip>
---

# openotp-block-release

Simulate openOTP server unreachability for SOC2/security regression testing (e.g. "No
connectivity with openOTP server during VC creation" test cases).

## Where the block must go

The openOTP calls are made by whichever process actually authenticates against it —
**not necessarily the node you're SSH'd into by default**. For Command Center login
testing, that's the **CCVM itself** (e.g. `172.16.7.120` on QA8), not the CCMaster/SN
host (`172.16.7.121`) — those are two different nodes reachable via the same jump
pattern but with different IPs/ports. Blocking on the wrong node does nothing (the
real process still resolves fine).

Confirm you're on the right node by checking the hostname first (`ccvm-zadaraqa8` for
the CCVM, vs. `qa8-sn1` for CCMaster/SN1).

## The block — and the gotcha that makes a naive one silently fail

Add a hosts-file override for the openOTP domain (e.g. `openotp-test.zadarastorage.com`):

```bash
sudo sh -c 'echo "192.0.2.1 openotp-test.zadarastorage.com" >> /etc/hosts'
```

**Use `192.0.2.1` (RFC 5737 TEST-NET-1) — not `127.0.0.1` or `0.0.0.0`.** Both of the
latter get treated as loopback by the Linux network stack, and if the target node runs
its own local web server (nginx, common on a CCVM), the "blocked" request will actually
hit that local service and return a real HTTP response (we saw a `301` — looking like a
working connection, not a failure) instead of failing. `192.0.2.1` is a documentation/
non-routable address guaranteed to have nothing listening — connections to it genuinely
time out, which is what a real "server unreachable" looks like.

## Verify the block actually works

```bash
getent hosts openotp-test.zadarastorage.com   # should show the override IP
timeout 6 curl -sk -o /dev/null -w "HTTP:%{http_code} ERR:%{errormsg}\n" https://openotp-test.zadarastorage.com
```

A working block: `curl` prints **nothing** (killed by `timeout` before getting any
response — genuine timeout). If you see any `HTTP:` code at all, the block isn't real
(re-check you're on the right node and used a non-routable IP).

## Confirmed effect (Command Center login, 2026-09-07)

With the block active on the CCVM, a login attempt against an openOTP-backed account
produced:
```
OpenOTP error: Failed to open TCP connection to openotp-test.zadarastorage.com:8443 (execution expired)
[500] POST /users/sign_in
NoMethodError (undefined method 'body' for nil): lib/remote_authentication_utils/open_otp.rb:55 in execute_request
```
This is a real bug, not expected behavior: the code assumes `execute_request` always
returns a response object to call `.body` on, but a TCP timeout returns `nil` and this
isn't checked — surfaces as a raw 500 to the user instead of a graceful "auth service
unavailable" message.

## Release (restore connectivity)

```bash
sudo sed -i '/openotp-test.zadarastorage.com/d' /etc/hosts
```

Verify:
```bash
getent hosts openotp-test.zadarastorage.com   # should show the real public IP again
```

## Notes

- The override persists across app-level restarts (Command Center, VC services) since
  it's OS-level — no service restart needed to apply/release it.
- Same technique applies to blocking openOTP reachability directly on a VC (not just
  the CCVM) for VC-side login testing (opsadmin/zadmin/elevated-zadmin/openOTP-user
  behavior during an outage) — just target the VC's own `/etc/hosts` instead.
