#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
cd /home/chris/projects/trend-test
lando drush sql:drop -y >/dev/null 2>&1
lando drush site:install /app/recipes/trend_personal -y \
  --account-name=admin --account-pass=admin --site-name="Trend Test" 2>&1 \
  | grep -vE "Performed install task|Do you want to continue|DROP all tables" \
  | tail -40
echo "EXIT: ${PIPESTATUS[0]}"
