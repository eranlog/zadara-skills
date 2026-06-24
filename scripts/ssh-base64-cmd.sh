#!/bin/bash
# Run a complex command (containing $, quotes, special chars) on a VPSA VC via CCMaster.
# Base64-encodes the command to survive multi-hop SSH quoting.
# Usage: ssh-base64-cmd.sh <ccmaster_ip> <vc_ip> "<command>"
# Example: ssh-base64-cmd.sh 172.16.7.121 10.0.8.25 'python3 -c "import bcrypt; print(bcrypt.hashpw(b\"pass\", bcrypt.gensalt()).decode())"'

CMD="$3"
B64=$(echo "$CMD" | base64 -w0)

sshpass -p zadara ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
  zadara@"$1" \
  "sshpass -p 'Z@darA2o11' ssh -p 2022 -o StrictHostKeyChecking=no zadara@$2 \
   'echo Z@darA2o11 | sudo -S -i bash -c \"echo $B64 | base64 -d | bash\"'"
