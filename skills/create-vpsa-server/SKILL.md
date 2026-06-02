Create a server record on a VPSA and establish iSCSI connectivity from a Linux client.

## What it does

Registers a Linux server with a VPSA via the REST API (not vpsa_linux.sh), then sets up iSCSI login on the client so volumes can be attached and used for I/O.

## Arguments

- `vpsa_frontend_ip` — e.g. `10.2.8.22`
- `server_ip` — client management IP, e.g. `172.16.0.223`
- `server_frontend_ip` — client frontend (10.2.8.x) IP, e.g. `10.2.8.223`
- `server_name` — display name, e.g. `server223`

## Prerequisites

- Client must have `open-iscsi` installed and reachable on `10.2.8.x`
- Active VC accessible via CCMaster → `10.0.8.x:2022`

## Step 1 — Get client IQN

```bash
# On client server:
sudo cat /etc/iscsi/initiatorname.iscsi
# → InitiatorName=iqn.1993-08.org.debian:01:468e4ac46d41
```

Via plink from Windows:
```powershell
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@<server_ip> "sudo cat /etc/iscsi/initiatorname.iscsi"
```

## Step 2 — Get API key (run from active VC)

⚠️ API key must be obtained **and used from the same host** — the VC is the reliable source.

```bash
# On active VC (10.0.8.x):
curl -sk -X POST https://<vpsa_frontend_ip>/api/users/admin/access_key.json \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "1q2w3e4r"}'
# → {"response": {"status": 0, "key": "N5QYTYN1GWIGL0OAFCGI-4", ...}}
```

Via plink from Windows:
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@<vc_mgmt_ip> `
   'curl -sk -X POST https://<vpsa_frontend_ip>/api/users/admin/access_key.json -H \"Content-Type: application/json\" -d \"{\\\"username\\\":\\\"admin\\\",\\\"password\\\":\\\"1q2w3e4r\\\"}\"'"
```

## Step 3 — Create server (run from active VC)

```bash
# On active VC:
curl -sk -X POST https://<vpsa_frontend_ip>/api/servers.json \
  -H "Content-Type: application/json" \
  -H "X-Access-Key: <key>" \
  -d '{
    "display_name": "<server_name>",
    "os": "Linux",
    "iscsi": "<server_frontend_ip>",
    "iqn": "<iqn>"
  }'
# → {"response": {"server_name": "srv-00000001", "status": 0}}
```

Via plink from Windows (replace values):
```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@<vc_mgmt_ip> `
   'curl -sk -X POST https://<vpsa_frontend_ip>/api/servers.json -H \"Content-Type: application/json\" -H \"X-Access-Key: <key>\" -d \"{\\\"display_name\\\":\\\"<name>\\\",\\\"os\\\":\\\"Linux\\\",\\\"iscsi\\\":\\\"<server_frontend_ip>\\\",\\\"iqn\\\":\\\"<iqn>\\\"}\"'"
```

## Step 4 — Connect iSCSI on client

After server is created, set up iSCSI login on the client:

```bash
# On client server:
sudo iscsiadm -m discovery -t sendtargets -p <vpsa_frontend_ip>
sudo iscsiadm -m node --targetname <target_iqn> --portal <vpsa_frontend_ip> -I default --login
```

The target IQN is returned by the discovery command and follows the pattern:
`iqn.2011-04.com.zadara:vsa-XXXXXXXX:<hash>:1`

## Known QA8 values

| Item | Value |
|------|-------|
| CCMaster hostkey | SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ |
| VPSA admin user | admin / 1q2w3e4r |
| QA8 VC SSH | zadara / Z@darA2o11, port 2022 |

## Notes

- The API key call **resets** the admin access key — a new key is issued each time
- The API key is **IP-session bound** — obtain and use it from the same host (VC)
- `srv-00000001` numbering restarts per VPSA — each VPSA has its own server namespace
- After creating the server, attach volumes via `zadara_cfg attach_volume` or the VPSA GUI
