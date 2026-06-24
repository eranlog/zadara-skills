#!/bin/bash
# Fix "Connection refused" on CCMaster floating IP — Ubuntu Noble sshd socket-activation bug.
# Run as root directly on the SN (not via the floating IP — if sshd is down, you need console/JViewer).
# Must be applied on BOTH SNs in the HA pair.

echo "==> Disabling ssh.socket (socket-activated sshd — broken on Noble)"
systemctl disable ssh.socket

echo "==> Enabling and starting ssh.service"
systemctl enable ssh.service
systemctl start ssh.service   # enable alone does NOT start it

echo "==> Verifying"
ss -tlnp | grep :22
