---
name: jenkins-disk-cleanup
description: Use when a Jenkins job fails with "No space left on device" / "Unable to produce a script file" / similar IOException, even if the job's own workspace mount looks fine. Diagnoses which filesystem is actually full on the Jenkins host (172.16.10.200) and safely reclaims space.
---

# Jenkins Disk Cleanup

Jenkins job fails with an `IOException: No space left on device` while trying to create a temp script file under its workspace (e.g. `/mnt/sources/ci/<job>`) — but that workspace's own mount often has plenty of room. The real culprit is usually the **root filesystem (`/`)**, which is a separate mount from the workspace and from all the NFS mounts (`/mnt/jenkins`, `/mnt/builds`, `/mnt/sources`, etc.).

## Access

Host: `172.16.10.200` (hostname `jenkins-server`). User: `zadara`, password `zadara` — same password for `sudo`.

**Use `plink.exe`, not `sshpass`/OpenSSH** — `sshpass ssh zadara@172.16.10.200` reliably fails with "Permission denied" against this host even with the correct password (root cause unconfirmed — likely an sshpass/OpenSSH client quirk, not a real auth problem). `plink.exe` succeeds immediately:

```powershell
& "C:\Program Files\PuTTY\plink.exe" -ssh -batch -pw zadara -hostkey "SHA256:f72R6XSShrzpnfJUP1Nk4DYGZWGUYbzi3InHA4szbyg" zadara@172.16.10.200 "<command>"
```

The host key fingerprint above may go stale after a reinstall — if plink refuses it, re-fetch with `ssh-keyscan -t ed25519 172.16.10.200 | ssh-keygen -lf -` and update.

For anything needing root, pipe the sudo password: `echo zadara | sudo -S <command> 2>&1`.

## Step 1 — find which filesystem is actually full

```bash
df -h
```

Don't assume it's the mount the failing job complained about — check every line. On this host specifically:
- `/dev/sda2` mounted at `/` — the local root disk, most likely to fill up (nothing here auto-rotates)
- `/dev/sdb1` mounted at `/mnt/sources` — Jenkins job workspaces, usually fine
- Several `172.16.10.21:/export/*` NFS mounts (`/mnt/jenkins`, `/mnt/builds`, `/mnt/images`, `/mnt/releases`, etc.) — the *real* Jenkins home lives on `/mnt/jenkins`, not on local disk

Also check inodes (`df -i /`) in case it's an inode exhaustion rather than a block-space one — different fix (usually huge counts of tiny files, e.g. an old `pip`/`npm` cache or per-build workspace dirs never cleaned).

## Step 2 — find what's actually using the space

```bash
echo zadara | sudo -S du -xh --max-depth=1 /var/* 2>/dev/null | sort -rh | head -15
echo zadara | sudo -S du -xsh /* 2>/dev/null | sort -rh | head -20
```

**Known recurring space consumers on this host** (as of 2026-08-26):

1. **`/root/*.img`** (~447G total) — compile-environment disk images: `ubuntu-noble-compile.img` (196G), `ubuntu-noble-spdk-compile.img` (100G), `ubuntu-bionic-master-compile-100g.img` (100G), `ubuntu-bionic-go-k8s-compile.img` (38G), `rhel-8.1-docker-go-and-compile.img` (7.7G), `web-team-utils.img` (5.6G). These get touched/regenerated periodically and were **not currently loop-mounted** when found — but treat as potentially live build infra. **Do not delete without explicit confirmation from Eran** — no reliable way to tell from the file alone whether a scheduled job still needs it.

2. **`/var/lib/jenkins-backup`** (can reach 250G+) — a **local backup copy** of the Jenkins home; the live Jenkins home is safely on the NFS mount `/mnt/jenkins`, so this is redundant, not live data. Contains:
   - Legacy `BACKUPSET_<date>_23-00_.zip` files (~6G each) — an older weekly-zip backup format
   - Newer `FULL-<date>_23-00/` directories (~100G each, uncompressed) — the current backup format
   - **No automatic rotation was observed** — this grows unbounded and is the most likely long-term repeat offender. Safe to prune the *oldest* entries; always leave at least the single most recent `FULL-*` directory as a live disaster-recovery copy. Confirm exact scope with Eran before deleting — he has asked for conservative, incremental cleanup here (e.g. "delete just the 2 oldest zips") rather than one large sweep, even when a bigger sweep was offered.

3. **`/var/log/journal`** — systemd journal, safe to vacuum:
   ```bash
   echo zadara | sudo -S journalctl --vacuum-time=3d
   ```

4. **`/var/cache/apt`** — safe to clear:
   ```bash
   echo zadara | sudo -S apt-get clean
   ```

## A `du` total that doesn't match its listed children usually means a large file, not a hidden process

If `du --max-depth=1 <dir>` reports a large total but the individual entries it lists don't add up anywhere close to that total, don't assume it's a deleted-but-still-open file held by a process (check that too, with `lsof +L1`, but it's often a dead end for this specific symptom). Instead just search directly for the large file(s) `du`'s depth-limited listing missed:

```bash
echo zadara | sudo -S find <dir> -xdev -size +500M -exec ls -lh {} \;
```

Confirm a found file is actually consuming real disk (not sparse) before treating it as the cause:

```bash
echo zadara | sudo -S stat --format='%n : apparent=%s bytes, actual=%b blocks (x512)' <file>
```

If `%b * 512` is close to `%s`, the file is fully allocated and really is using that much real disk.

## Cleanup priority (safest first)

1. `journalctl --vacuum-time=3d` + `apt-get clean` — always safe, low yield (low single-digit GB)
2. Oldest entries in `/var/lib/jenkins-backup` (zips before full dirs, oldest first) — safe, but confirm scope with Eran before running; he prefers incremental/conservative deletes over one big sweep
3. `/root/*.img` compile images — **do not touch without explicit confirmation** — these may be live build infrastructure, not backups

## After freeing space

Re-check `df -h /` to confirm real free space, then re-trigger the originally-failing Jenkins job (or let Eran do it) — the build itself needed no other fix, it was purely blocked on disk space.
