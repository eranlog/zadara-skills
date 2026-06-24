#!/bin/bash
# Usage: tail-vpsa-logs.sh
# Run on the active VPSA VC. Tails all standard VPSA log files simultaneously.
tail -f /var/log/zadara/rails/production.log \
        /var/log/nginx/access.log \
        /var/log/nginx/error.log \
        /var/log/zadara/vac.log \
        /var/log/zadara/vam.log \
        /var/log/zadara/vcc.log
