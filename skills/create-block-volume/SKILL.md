Create one or more block volumes on a VPSA via the REST API, then verify with zadara_cfg.

## Arguments

- `vpsa_frontend_ip` — e.g. `10.2.8.22`
- `pool_name` — e.g. `pool-00010003` (get from `zadara_cfg list_pools`)
- `vol_name` — display name, e.g. `vol-10g`
- `capacity_gb` — integer GB, e.g. `10`

## Step 1 — Find pool name

```bash
# On active VC:
/var/lib/zadara/bin/zadara_cfg list_pools 2>&1
# → <name>pool-00010003</name>
```

## Step 2 — Get API key (from active VC)

```bash
KEY=$(curl -sk -X POST https://<vpsa_frontend_ip>/api/users/admin/access_key.json \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "1q2w3e4r"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response']['key'])")
echo $KEY
```

## Step 3 — Create block volume

```bash
curl -sk -X POST https://<vpsa_frontend_ip>/api/volumes.json \
  -H "Content-Type: application/json" \
  -H "X-Access-Key: $KEY" \
  -d '{
    "name": "<vol_name>",
    "capacity": "<capacity_gb>",
    "block": "YES",
    "pool": "<pool_name>",
    "dedupe": "NO",
    "compress": "NO"
  }'
# → {"response": {"vol_name": "volume-00000001", "status": 0}}
```

## Step 4 — Verify

```bash
# On active VC:
/var/lib/zadara/bin/zadara_cfg show_volumes 2>&1 | python3 -c "
import sys, re
data = sys.stdin.read()
for v in re.findall(r'<volume>.*?</volume>', data, re.DOTALL):
    name = re.search(r'<name>(.*?)</name>', v).group(1)
    disp = re.search(r'<display-name>(.*?)</display-name>', v).group(1)
    cap  = re.search(r'<provisioned-capacity[^>]*>(.*?)</provisioned-capacity>', v).group(1)
    typ  = re.search(r'<data-type>(.*?)</data-type>', v).group(1)
    stat = re.search(r'<status>(.*?)</status>', v).group(1)
    print(name, disp, cap+'GB', typ, stat)
"
```

## Create multiple volumes in one shot (via VC)

```bash
# On active VC — get key once, create N volumes:
KEY=$(curl -sk -X POST https://10.2.8.22/api/users/admin/access_key.json \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"1q2w3e4r"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['response']['key'])")

for VOL in "vol-10g:10" "vol-11g:11"; do
  NAME=${VOL%%:*}; CAP=${VOL##*:}
  curl -sk -X POST https://10.2.8.22/api/volumes.json \
    -H "Content-Type: application/json" -H "X-Access-Key: $KEY" \
    -d "{\"name\":\"$NAME\",\"capacity\":\"$CAP\",\"block\":\"YES\",\"pool\":\"pool-00010003\",\"dedupe\":\"NO\",\"compress\":\"NO\"}"
  echo
done
```

## Notes

- `capacity` is in GB as an integer string (e.g. `"10"` not `"10G"`)
- `dedupe: NO` and `compress: NO` required — data reduction bundle disabled on QA VPSAs
- API key is reset each time `access_key.json` is called — obtain and use from the same VC session
- Use size difference (e.g. 10GB vs 11GB) to distinguish volumes on the IO client via `lsblk`
- After creation, attach via `zadara_cfg attach_volume` or `POST /api/volumes/<vol_name>/servers.json`
