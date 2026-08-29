#!/usr/bin/env bash
set -uo pipefail
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
cd /home/chris/projects/trend-test
echo "=== lando start $(date) ==="
lando start 2>&1
echo "=== exit: $? ==="
lando info 2>&1 | head -60
