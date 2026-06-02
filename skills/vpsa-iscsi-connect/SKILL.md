Use when iSCSI login fails with error 24 (authorization failure), or when setting up a fresh Linux server to access Zadara VPSA block storage for the first time.
Covers: server registration → iSCSI connect → volume attach → IO verify.

## Prerequisites

- Server has `open-iscsi` installed (`apt-get install -y open-iscsi`)
- Server has a NIC on `10.2.8.x` subnet (same as VPSA frontend)
- Active VC reachable via CCMaster → `10.0.8.x:2022`

## Inputs needed

| Item | How to get |
|------|-----------|
| VPSA frontend IP | `ip addr show febond \| grep inet` on active VC |
| Server mgmt IP | e.g. `172.16.0.223` |
| Server frontend IP | `ip addr show \| grep 10.2.8` on server |
| Server frontend NIC | same command, e.g. `vlan50` |

---

## Phase 1 — Register server on VPSA

### 1a — Get server IQN

```bash
sudo cat /etc/iscsi/initiatorname.iscsi
# → InitiatorName=iqn.1993-08.org.debian:01:468e4ac46d41
```

### 1b — Get API key ⚠️ MUST run from active VC

> **Critical:** The VPSA API key is IP-session bound. It must be obtained AND used from the same host.
> Calling from an external server returns `status 1793 - Your session expired`.
> Always run API calls from the active VC (10.0.8.x) via plink/SSH.

```bash
# On active VC:
curl -sk -X POST https://<vpsa_ip>/api/users/admin/access_key.json \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "1q2w3e4r"}'
# → {"response": {"status": 0, "key": "XXXXX-N", ...}}
```

> ⚠️ This call **resets** the key — a new key is issued each time. Save it for the session.

Via plink from Windows:
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@<vc_ip> `
   'curl -sk -X POST https://<vpsa_ip>/api/users/admin/access_key.json -H \"Content-Type: application/json\" -d \"{\\\"username\\\":\\\"admin\\\",\\\"password\\\":\\\"1q2w3e4r\\\"}\"'"
```

### 1c — Create server record (from active VC)

```bash
curl -sk -X POST https://<vpsa_ip>/api/servers.json \
  -H "Content-Type: application/json" \
  -H "X-Access-Key: <key>" \
  -d '{
    "display_name": "<server_name>",
    "os": "Linux",
    "iscsi": "<server_frontend_ip>",
    "iqn": "<iqn_from_1a>"
  }'
# → {"response": {"server_name": "srv-00000001", "status": 0}}
```

### 1d — Get CHAP credentials

```bash
curl -sk "https://<vpsa_ip>/api/servers/<srv_name>.json?access_key=<key>"
# → look for: "vpsa_chap_user": "911", "vpsa_chap_secret": "N3TvpoIHd2mV"
```

> The `vpsa_chap_user` is the VPSA display name (e.g. `911`).
> Despite `host_chap_user` being null, CHAP IS required — see Phase 2.

---

## Phase 2 — Connect iSCSI on the server

### 2a — Create dedicated iface

Required to route iSCSI traffic via the frontend NIC (10.2.8.x), not the management NIC.

```bash
IFACE="zadara_10.2.8.22"    # convention: zadara_<vpsa_frontend_ip>
NIC="vlan50"                  # NIC with 10.2.8.x IP — verify with: ip addr show | grep 10.2.8

sudo iscsiadm -m iface -I $IFACE --op=new
sudo iscsiadm -m iface -I $IFACE --op=update -n iface.net_ifacename -v $NIC
```

> ⚠️ Wrong NIC = traffic goes via management network = can't reach VPSA frontend = login fails

### 2b — Discover target

```bash
sudo iscsiadm -m discovery -t sendtargets -p <vpsa_frontend_ip> -I $IFACE
# → 10.2.8.22:3260,1 iqn.2011-04.com.zadara:vsa-00000036:FFF6162E...:1
```

Save the full target IQN.

### 2c — Configure CHAP ⚠️ Required even if host_chap is null

> **Critical:** VPSA always requires CHAP. Skipping this causes error 24.
> Use the `vpsa_chap_user` / `vpsa_chap_secret` from Phase 1d as the initiator credentials.

```bash
TARGET="iqn.2011-04.com.zadara:vsa-00000036:FFF6162ECABF4034BEC0A3F8D31F533F:1"
CHAP_USER="911"           # vpsa_chap_user
CHAP_PASS="N3TvpoIHd2mV"  # vpsa_chap_secret

sudo iscsiadm -m node -T $TARGET --op=update -n node.session.auth.authmethod -v CHAP
sudo iscsiadm -m node -T $TARGET --op=update -n node.session.auth.username -v $CHAP_USER
sudo iscsiadm -m node -T $TARGET --op=update -n node.session.auth.password -v $CHAP_PASS
```

### 2d — Login

```bash
sudo iscsiadm -m node -T $TARGET --portal <vpsa_frontend_ip> -I $IFACE --login
# → Login to [...] successful.
```

**If you get error 24 — authorization failure:**

| Cause | Fix |
|-------|-----|
| CHAP not configured | Run step 2c |
| Wrong CHAP credentials | Re-fetch from API: `GET /api/servers/<srv>.json` |
| Volume not attached to server | Attach first (Phase 3), then retry login |
| Wrong iface / NIC | Check NIC name with `ip addr show \| grep 10.2.8` |

---

## Phase 3 — Attach a volume

### 3a — Create block volume (if needed)

```bash
# From active VC:
curl -sk -X POST https://<vpsa_ip>/api/volumes.json \
  -H "Content-Type: application/json" \
  -H "X-Access-Key: <key>" \
  -d '{"name": "vol-10g", "capacity": "10", "block": "YES", "pool": "<pool_name>", "dedupe": "NO", "compress": "NO"}'
# → {"response": {"vol_name": "volume-00000001", "status": 0}}
```

> ⚠️ Use `"dedupe": "NO", "compress": "NO"` — data reduction bundle disabled on QA VPSAs

### 3b — Attach volume to server

```bash
curl -sk -X POST https://<vpsa_ip>/api/volumes/<vol_name>/servers.json \
  -H "Content-Type: application/json" \
  -H "X-Access-Key: <key>" \
  -d '{"server_name": "<srv_name>"}'
# → {"response": {"status": 0}}
```

### 3c — Verify block device on server

```bash
lsblk -d -o NAME,SIZE,VENDOR,MODEL | grep -v loop
# → sdX  10G  Zadara  VPSA
```

---

## Phase 4 — Run IO and verify both sides

### 4a — Write vdbench config

```bash
# Use size to distinguish volumes (e.g. 10G vs 11G readable in lsblk)
echo 'sd=sd1,lun=/dev/sdb,openflags=o_direct' > /tmp/vd_iscsi
echo 'wd=wd_mixed,sd=sd1,xfersize=(4k,50,8k,25,16k,15,32k,10),rdpct=70,seekpct=random' >> /tmp/vd_iscsi
echo 'rd=rd_mixed,wd=wd_mixed,iorate=max,elapsed=300,interval=10,threads=16,warmup=10' >> /tmp/vd_iscsi
```

> ⚠️ Use `echo >> file` not heredoc — parentheses in xfersize break heredoc over SSH

### 4b — Run vdbench

```bash
sudo /home/zadara/vdbench50406_patched/vdbench -f /tmp/vd_iscsi -o /tmp/vdbench_out &
sleep 20 && tail -5 /tmp/vdbench.log
# → interval 1   17454 i/o   163 MB/sec ...
```

### 4c — Verify IO on VPSA side (from active VC)

```bash
curl -sk "https://<vpsa_ip>/api/servers/<srv_name>/performance.json?access_key=<key>&interval=1&limit=3" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); [print(u) for u in d['response']['usages'][-3:]]"
# → rd_iops: ~10500, wrt_iops: ~4400, rd_bandwidth: ~98 MB/s
```

---

## Known QA8 values — server223 + VPSA 911

| Item | Value |
|------|-------|
| VPSA | `vsa-00000036` (911) |
| VPSA frontend IP | `10.2.8.22` |
| Active VC mgmt IP | `10.0.8.22` |
| Server | server223, `172.16.0.223` |
| Server frontend IP | `10.2.8.223` on `vlan50` |
| Server plink hostkey | `AAAAC3NzaC1lZDI1NTE5AAAAIIw9ZELI7Vgjel3uCy9WZIHOI9Q/hn4WTPWChIy85cwt` |
| Server IQN | `iqn.1993-08.org.debian:01:468e4ac46d41` |
| SCST target IQN | `iqn.2011-04.com.zadara:vsa-00000036:FFF6162ECABF4034BEC0A3F8D31F533F:1` |
| iSCSI iface | `zadara_10.2.8.22` |
| CHAP user | `911` |
| srv name | `srv-00000001` |
| vdbench path | `/home/zadara/vdbench50406_patched/vdbench` |
