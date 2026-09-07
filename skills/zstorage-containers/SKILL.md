---
name: zstorage-containers
description: Use when creating or managing Docker containers on a VPSA App Engine — setting up Container Service, creating image repository, pulling Docker Hub images, creating containers, or running containerized storage workloads on a Gen3 H100 VPSA.
argument-hint: <vsa-id>
---

# zstorage-containers

Create and manage Docker containers on a VPSA with Container Service (App Engine). Containers run directly on the VPSA VC kernel using VPSA storage for the image repository and container memory pools.

## When to use

- Setting up Container Service on a VPSA with App Engine
- Pulling Docker images from Docker Hub or a NAS share
- Creating and running containers on a VPSA
- Testing VPSA container workloads (e.g., fio for IO benchmarking)

## Prerequisites

- VPSA must have **App Engine** enabled (visible in VPSA GUI → General Info as `APP ENGINE: 01`)
- At least one pool must exist (pool is required for the image repository)
- Gen3 H100 VPSAs (`vsa.V3.H100.vf`) support Container Service; check `APP ENGINE` field to confirm

---

## Setup flow

### 1. Verify App Engine is present

In VPSA GUI → Dashboard → General Information:
```
APP ENGINE: 01   ← means 1 app engine / container service is available
```
If `APP ENGINE: 00` or absent, the VPSA does not support containers.

---

### 2. Create a pool (if not already present)

Container image repository requires a pool. See [[zstorage-vpsa-storage]] for pool creation.

For Gen3 H100 — pool is created via `create_pool_v3`:
```bash
# Via VPSA GUI: Resources → Pools → CREATE
# Type: Balanced (general purpose), IOPs-Optimized, or Throughput-Optimized
```

---

### 3. Configure Container Service settings

VPSA GUI → Settings → Container Service tab:

| Setting | Default | Notes |
|---------|---------|-------|
| Container Network | 172.20.20.1/24 | Internal network for containers |
| Exposed Ports | 9216-10240 | Port range exposed to outside |
| Image Repository | (must create) | Backed by a VPSA pool |

---

### 4. Create the Image Repository

VPSA GUI → Container Service → Images → **CREATE** (if no images exist, GUI shows "Images repository not created"):

1. Click **Create** next to "Images repository not created"
2. Select pool (e.g., `pool1`)
3. Click **Submit** → "Operation successful"

The repository is now backed by the selected pool.

---

### 5. Add a Docker image

VPSA GUI → Container Service → Images → **CREATE**:

**Option A — Pull from Docker Hub:**
1. Image Display Name: e.g., `fio`
2. Select **Pull from a Docker Registry**
3. Next → Search Docker Hub Public Registry
4. Enter image name (e.g., `fio`) → results appear
5. Select image (e.g., `mayadata/fio`) → Select Tag: `latest`
6. Click **Create**

**Option B — Load from VPSA NAS share:**
1. Select **Load/Import a Docker Archive from a VPSA NAS share**
2. Browse to the `.tar` archive on a NAS share

Image status becomes `normal` when ready.

---

### 6. Create a container

VPSA GUI → Container Service → Containers → **CREATE CONTAINER**:

Select the image, configure resources (CPU, memory from Container Memory Pool), network ports, and environment variables.

**Port mapping field labels are reversed from what you'd expect** — this cost real
time to figure out (2026-09-07). In the "Add Port Range" dialog:
- **"User start port"** = the port **inside the container** (e.g. `22` for an sshd
  container) — despite the name, this is NOT the externally-facing port.
- **"Internal start port"** = the **host-facing/exposed** port (constrained to the
  cloud's configured Exposed Ports range, e.g. `9216-10240` — the field enforces a
  minimum matching that range, which is the tell that it's actually the external
  side). Confirmed via `docker ps` after creation: `PORTS` column showed
  `10.2.8.33:9216->22/tcp` — host port on the left, container port on the right, i.e.
  exactly (Internal start port)->(User start port).

So to expose a container's port 22 as 9216 externally: **User start port = 22**,
**Internal start port = 9216**. Leave both "end port" fields blank for a single port
(not a range).

---

## SSH-into-container testing (SOC2 "SSH into Docker Container should be possible")

For testing that a Container Service container is reachable via real network SSH (not
just `docker exec`), use the purpose-built image rather than building your own:

**Docker Hub: `zadara/ssh`** — "A ssh container to connect to your VPSA. You will have
access to mounted block and NAS shares." Default root password: `zadara` (change it).
Documented usage: `ssh -p 9222 root@<your-vpsa-frontend-ip>` (9222 is just their
example port — use whatever host port you mapped per the section above).

**Confirmed gotcha: you cannot SSH into the container from the VC itself.**
Connecting to the VC's own frontend IP + mapped port, *from a shell on that same VC*,
fails with `ssh: connect to host <ip> port <port>: No route to host`. This is a
"hairpin NAT" limitation — self-originated traffic to your own external IP doesn't
traverse the DNAT/PREROUTING chain that maps the port into the container, so it never
reaches it. This is NOT a bug — it's a standard Linux netfilter limitation, not
VPSA-specific. **Test from a genuinely external client** (any other host that can
reach the VPSA's frontend network) — from there it works exactly as documented:
```
ssh -p<host_port> root@<vpsa-frontend-ip> -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
```
Confirmed 2026-09-07 on VPSA SOC2H101 (vsa-00000004): landed a real shell inside the
container (hostname matched the container ID from `docker ps`).

---

## API — container operations

```bash
BASE="https://<vpsa_nova_ip>"
KEY="<access_key>"

# List images
curl -sk "$BASE/api/container_images.json?access_key=$KEY"

# List containers
curl -sk "$BASE/api/containers.json?access_key=$KEY"

# Create container
curl -sk "$BASE/api/containers.json?access_key=$KEY" -X POST \
  -d "display_name=fio-test&image_name=img-00000001&..."
```

---

## Container Service defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Container Network | 172.20.20.1/24 | Internal network for containers |
| Exposed Ports | 9216-10240 | Port range exposed externally |

For VPSA novabridge IP and VPSA IDs, see [[zstorage-environments]]. Get API access key via [[vpsa-api-key]].

---

## Security note

Containers run on the **VPSA VC kernel**. Arbitrary third-party Docker images pulled from Docker Hub execute on the same kernel that handles storage and IPsec SAs. Relevant to kernel vulnerability assessments (e.g., Dirty Frag — ZSTRG-37567): the container escape scenario applies to any VPSA with App Engine running untrusted images.
