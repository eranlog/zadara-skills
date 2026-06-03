List all VPSAs on QA8 via CCMaster SSH, with optional filter by vsa_id.

## Connection
- Host: 172.16.7.121:22
- User: zadara / Password: zadara
- Then: `sudo -i` (zadara/zadara)

## Usage
- No args: list all VPSAs
- With vsa_id arg (e.g. `vsa-00000027`): show VPSA detail including instances

## Steps

If no argument provided, run:
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "echo zadara | sudo -S nova-manage vsa list"
```

If a vsa_id argument is provided (e.g. `$ARGUMENTS`), run:
```bash
sshpass -p zadara ssh -o StrictHostKeyChecking=no zadara@172.16.7.121 \
  "echo zadara | sudo -S nova-manage vsa list --inst $ARGUMENTS"
```

Output columns:
- **ID / vsa_id / displayName** — identity
- **status** — `created` (running), `hibernated` (stopped)
- **active_VC** — `vc-N/host/[management-IP]` — the IP is the VPSA GUI address
- **VCs / drvs** — controller count / drive count

For detail view (`--inst`), the Instances section shows:
- **fixed_IPs** — includes the management IP (10.2.x.x range)
- **host** — which QA8 node the VC runs on
- **A** marker in status = active/primary VC
