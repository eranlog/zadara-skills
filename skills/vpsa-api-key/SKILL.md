Use when VPSA REST API calls fail with "session expired" (status 1793) or "access denied", or when a fresh API token is needed to automate VPSA operations.

## Background

The VPSA has its own user management, **separate from Command Center**.
- `zadara_cloud_admin` is a CC proxy user — it cannot make VPSA API calls
- Use the VPSA-local `admin` user (password `1q2w3e4r` on QA)
- The key is persistent (not session-based) but calling this endpoint **resets** it — a new key is issued each time

## Usage

- With args: `<vpsa_frontend_ip> <username> <password>`

Example: `vpsa-api-key 10.2.8.22 admin 1q2w3e4r`

## Get the access key

```bash
VPSA_IP="10.2.8.22"

curl -sk -X POST "https://$VPSA_IP/api/users/admin/access_key.json" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "1q2w3e4r"}'
```

Successful response:
```json
{"response": {"status": 0, "key": "KFY29E5BT3KLENKT47TS-3", "message": "Access key changed."}}
```

Extract the key directly:
```bash
KEY=$(curl -sk -X POST "https://$VPSA_IP/api/users/admin/access_key.json" \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "1q2w3e4r"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response']['key'])")
echo "Key: $KEY"
```

## Use the key in API calls

```bash
# As query param
curl -sk "https://$VPSA_IP/api/servers.xml?access_key=$KEY"

# As header
curl -sk "https://$VPSA_IP/api/servers.xml" -H "X-Access-Key: $KEY"
```

## From Windows (via active VC with plink)

```powershell
$VPSA_IP = "10.2.8.22"
$VC_IP   = "10.0.8.22"

"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@$VC_IP 'curl -sk -X POST https://$VPSA_IP/api/users/admin/access_key.json -H Content-Type:application/json -d {\"username\":\"admin\",\"password\":\"1q2w3e4r\"}'"
```

## Alternative: extract from vpsa_linux.sh

If `vpsa_linux.sh` was already downloaded on a server, the key is baked in:

```bash
grep ACCESSKEY ~/vpsa_linux.sh | head -1
# ACCESSKEY="KFY29E5BT3KLENKT47TS-3"
```

## Notes

- **⚠ Resets the key** — calling this endpoint issues a new key and invalidates the old one
- `otp_attempt` field is optional — omit it for QA environments
- Wrong credentials return: `{"status": 5, "message": "Invalid credentials."}`
- The CC wizard (Servers → ADD → Automatic) uses this same endpoint internally to bake the key into `vpsa_linux.sh`
