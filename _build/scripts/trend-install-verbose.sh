#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
cd /home/chris/projects/trend-test
lando drush sql:drop -y >/dev/null 2>&1
lando drush site:install /app/recipes/trend_personal -y \
  --account-name=admin --account-pass=admin --site-name="Trend Test" -vvv 2>&1 \
  | grep -iE "error|warning|fail|exception|skip|unmet|schema|could not|missing|\[notice\] Install|module installed|Applying" \
  | grep -viE "phpunit|assert|deprecat" \
  | tail -120
echo "=== exit ${PIPESTATUS[0]} ==="
echo "config rows: $(lando drush sqlq 'SELECT COUNT(*) FROM config;' 2>/dev/null)"
