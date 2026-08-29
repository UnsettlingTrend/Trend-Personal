#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
REPO=/home/chris/projects/com.chrisferagotti.unsettlingtrend
TEST=/home/chris/projects/trend-test
cd "$TEST"

wait_db() {
  for i in $(seq 1 30); do
    if lando drush sqlq "SELECT 1" >/dev/null 2>&1; then return 0; fi
    echo "  waiting for db ($i)…"; sleep 5
  done
  return 1
}

# regenerate config
rm -rf "$REPO"/recipes/trend_personal/config "$REPO"/recipes/trend_personal/trend_*/config
rsync -a --delete --exclude='*/config/' "$REPO/recipes/trend_personal/" "$TEST/recipes/trend_personal/"
rsync -a --delete "$REPO/web/themes/custom/ut_base/" "$TEST/web/themes/custom/ut_base/"
rsync -a --delete "$REPO/web/modules/custom/ut_recipe/" "$TEST/web/modules/custom/ut_recipe/"
rsync -a --delete "$REPO/web/modules/custom/ut_utilities/" "$TEST/web/modules/custom/ut_utilities/"

wait_db || { echo "DB NEVER CAME UP — docker unstable"; exit 3; }
lando drush php:script /app/recipes/trend_personal/_build/strip_bucket.php 2>&1 | tail -13
rsync -a --delete "$TEST/recipes/trend_personal/config/" "$REPO/recipes/trend_personal/config/"
for a in trend_recipe trend_place trend_event trend_issue trend_journal trend_quote; do
  mkdir -p "$REPO/recipes/trend_personal/$a/config"
  rsync -a --delete "$TEST/recipes/trend_personal/$a/config/" "$REPO/recipes/trend_personal/$a/config/"
done
cp "$TEST/recipes/trend_personal/_build"/report.* "$REPO/recipes/trend_personal/_build/" 2>/dev/null

echo "=== base install ==="
wait_db || exit 3
lando drush sql:drop -y >/dev/null 2>&1
lando drush site:install /app/recipes/trend_personal -y \
  --account-name=admin --account-pass=admin \
  trend_personal.site_name="Trend Test" trend_personal.site_mail="test@example.com" 2>&1 \
  | grep -iE "\[success\]|\[error\]|Error:|Failed to connect|line [0-9]+ of" | tail -6
echo "base exit: ${PIPESTATUS[0]}"

for a in trend_place trend_recipe trend_event trend_issue trend_journal trend_quote; do
  echo "=== apply $a ==="
  wait_db || exit 3
  lando drush recipe /app/recipes/trend_personal/$a -y 2>&1 \
    | grep -iE "applied successfully|\[error\]|Error:|not found|does not exist" | tail -4
  echo "$a exit: ${PIPESTATUS[0]}"
done

echo "=== final diag ==="
wait_db || exit 3
lando drush php:script /app/recipes/trend_personal/_build/diag.php 2>&1 | grep -vE "^\s*$" | head -50
echo "DONE"
