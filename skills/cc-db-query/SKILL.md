Run a SQL query against the Command Center database (command-center or ecommerce-rails) on CCVM.

## Connection chain

CCMaster (172.16.7.121) → CCVM (172.16.7.120:2022) → psql

## Usage

- No args: opens an interactive psql shell on command-center DB
- With arg: `<sql-query>` — runs the query and returns results
- With arg: `ecommerce <sql-query>` — runs against ecommerce-rails DB instead

## Run a query

```powershell
"C:\Program Files\PuTTY\plink.exe" -batch -pw zadara `
  -hostkey "SHA256:qBClZBxyfq7XhyY53j1rxN+CV2FNchRk0oQsJ3oqswQ" `
  zadara@172.16.7.121 `
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadministrator@172.16.7.120 `
   'echo Z@darA2o11 | sudo -S psql -U zadara command-center -c \"<SQL>\"'"
```

For ecommerce-rails:
```powershell
# Replace command-center with ecommerce-rails in the command above
```

## Useful queries

### Cloud creation date (age of the QA environment)
```sql
SELECT name, created_at FROM clouds ORDER BY created_at;
```
> QA8 result: `zadara-qa8 | 2026-02-23 16:33:39` (created 2026-02-23)

### All VPSAs with creation date
```sql
SELECT display_name, vsa_id, status, created_at FROM vsas ORDER BY created_at;
```

### VPSA by name
```sql
SELECT display_name, vsa_id, status, created_at FROM vsas WHERE display_name ILIKE '%<name>%';
```

### SN nodes
```sql
SELECT hostname, ip, status, created_at FROM compute_nodes ORDER BY created_at;
```

### Recent events / messages
```sql
SELECT created_at, severity, message FROM messages ORDER BY created_at DESC LIMIT 20;
```

## Notes

- Both `command-center` and `ecommerce-rails` use PostgreSQL, user `zadara`, no password needed from CCVM
- CCMaster OS install date is unreliable for cloud age — it reflects reinstalls. Use the DB `clouds.created_at` instead.
- The CCVM itself is at 172.16.7.120, port 2022, user zadministrator / Z@darA2o11
