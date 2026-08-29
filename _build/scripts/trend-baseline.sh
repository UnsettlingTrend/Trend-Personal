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
mkdir -p config/baseline
lando drush sql:drop -y >/dev/null 2>&1

echo "=== site:install (bare base, full module list, no recipe config) ==="
lando drush site:install /app/recipes/trend_personal -y \
  --account-name=admin --account-pass=admin --site-name="Trend Test" 2>&1 \
  | grep -viE "^ \[notice\] Performed install task|Do you want to continue|DROP all tables|^\s*$" | tail -60
echo "=== install exit: $? ==="

echo
echo "=== config:export -> config/baseline ==="
lando drush config:export --destination=/app/config/baseline -y 2>&1 | tail -5
echo "baseline file count:"; ls config/baseline/*.yml 2>/dev/null | wc -l

echo
echo "--- front page ---"; lando drush php:eval "print \Drupal::httpClient()->get('http://localhost/')->getStatusCode();" 2>&1 | tail -2
echo "--- watchdog errors ---"; lando drush watchdog:show --count=20 --severity=Error 2>&1 | tail -25
