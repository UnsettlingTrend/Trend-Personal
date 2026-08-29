#!/usr/bin/env bash
set -uo pipefail
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
REPO=/home/chris/projects/com.chrisferagotti.unsettlingtrend
TEST=/home/chris/projects/trend-test

# --- sync in-progress artifacts from the main repo into the test app ---
rsync -a --delete "$REPO/recipes/trend_personal/"            "$TEST/recipes/trend_personal/"
rsync -a --delete "$REPO/web/themes/custom/ut_base/"         "$TEST/web/themes/custom/ut_base/"
rsync -a --delete "$REPO/web/modules/custom/ut_recipe/"      "$TEST/web/modules/custom/ut_recipe/"
rsync -a --delete "$REPO/web/modules/custom/ut_utilities/"   "$TEST/web/modules/custom/ut_utilities/"

cd "$TEST"
echo "=== drush status ==="
lando drush status --fields=drupal-version,db-status,uri 2>&1 | tail -20

echo
echo "=== site:install from recipe ==="
lando drush site:install /app/recipes/trend_personal -y \
  --account-name=admin --account-pass=admin \
  --site-name="Trend Test" 2>&1 | tail -80
echo "=== install exit: $? ==="
