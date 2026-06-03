SSH into the active VC of a QA8 VPSA. Connects via CCMaster jump host, identifies the active VC (marked "A"), and opens a shell.

## Connection chain
1. CCMaster: `zadara@172.16.7.121:22` / pass: `zadara`
2. From CCMaster → VC: `zadara@<10.0.8.X>:2022` / pass: `Z@darA2o11`
3. Then: `echo Z@darA2o11 | sudo -S -i`

## Usage
- No arg: list all VPSAs, then prompt for vsa_id
- With arg (e.g. `vsa-00000027`): go straight to that VPSA's active VC

## Steps

**Step 1 — list VPSAs (if no arg given):**
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "nova-manage vsa list"
```

**Step 2 — get instances for the chosen VPSA:**
```bash
VSAID=vsa-00000027   # replace as needed
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "nova-manage vsa list --inst $VSAID"
```

Parse the active VC: find the instance line with `A` before the host column. Extract its first `10.0.8.X` IP from `fixed_IPs`.

**Step 3 — connect to active VC:**
```bash
VC_IP=10.0.8.29   # extracted from active VC line
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@$VC_IP \
   'echo Z@darA2o11 | sudo -S -i'"
```

## Parsing rules
- Active VC line: contains `A ` before the host name (e.g. `active     A qa8-sn4`)
- 10.0.8.X IP: first IP in the `fixed_IPs` column (always the 10.0.8.x range)
- Hostname on VC: `vsa-<id>-vc-<N>`

## Example — verified working
```
VPSA: vsa-00000027 (HOPE)
Active VC: vc-1 on qa8-sn4
VC IP: 10.0.8.29
Result: logged into vsa-00000027-vc-1 as zadara
```
