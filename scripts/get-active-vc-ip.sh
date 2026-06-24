#!/bin/bash
# Usage: get-active-vc-ip.sh <vsa-id>
# Run on CCMaster. Prints the management IP of the active VC instance.
# Example: get-active-vc-ip.sh vsa-00000011
nova-manage vsa list --inst "$1" | awk '/[[:space:]]A[[:space:]]/{match($0,/10\.0\.[0-9]+\.[0-9]+/); print substr($0,RSTART,RLENGTH); exit}'
