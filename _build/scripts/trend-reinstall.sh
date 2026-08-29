#!/usr/bin/env bash
set -uo pipefail
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
REPO=/home/chris/projects/com.chrisferagotti.unsettlingtrend
TEST=/home/chris/projects/trend-test

rsync -a --delete "$REPO/recipes/trend_personal/"          "$TEST/recipes/trend_personal/"
rsync -a --delete "$REPO/web/themes/custom/ut_base/"       "$TEST/web/themes/custom/ut_base/"
rsync -a --delete "$REPO/web/modules/custom/ut_recipe/"    "$TEST/web/modules/custom/ut_recipe/"
rsync -a --delete "$REPO/web/modules/custom/ut_utilities/" "$TEST/web/modules/custom/ut_utilities/"

cd "$TEST"
lando drush sql:drop -y >/dev/null 2>&1
echo "=== site:install ==="
lando drush site:install /app/recipes/trend_personal -y \
  --account-name=admin --account-pass=admin --site-name="Trend Test" 2>&1 | tail -60
echo "=== exit: $? ==="
echo
echo "--- theme default ---"; lando drush cget system.theme default 2>&1 | tail -2
echo "--- ut_* modules ---"; lando drush pm:list --type=module --status=enabled --format=list 2>&1 | grep -E "ut_|social_auth" | sort
echo "--- front page ---"; lando drush php:eval "print \Drupal::httpClient()->get('http://localhost/')->getStatusCode();" 2>&1 | tail -2
echo "--- errors ---"; lando drush watchdog:show --count=15 --severity=Error 2>&1 | tail -20
