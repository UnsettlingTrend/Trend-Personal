#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
cd /home/chris/projects/trend-test
lando drush sql:drop -y 2>&1 | tail -2
echo "=== install (full output) ==="
lando drush site:install /app/recipes/trend_personal -y \
  --account-name=admin --account-pass=admin \
  trend_personal.site_name="Trend Test" trend_personal.site_mail="test@example.com" 2>&1 \
  | grep -vE "Performed install task" | tail -40
echo "EXIT ${PIPESTATUS[0]}"
