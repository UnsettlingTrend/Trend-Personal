#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
REPO=/home/chris/projects/com.chrisferagotti.unsettlingtrend
TEST=/home/chris/projects/trend-test

# sync recipe.yml/scripts (not config), regenerate config, sync config back to repo
rm -rf "$REPO"/recipes/trend_personal/config "$REPO"/recipes/trend_personal/trend_*/config
rsync -a --delete --exclude='*/config/' "$REPO/recipes/trend_personal/" "$TEST/recipes/trend_personal/"
rsync -a --delete "$REPO/web/themes/custom/ut_base/" "$TEST/web/themes/custom/ut_base/"
rsync -a --delete "$REPO/web/modules/custom/ut_recipe/" "$TEST/web/modules/custom/ut_recipe/"
rsync -a --delete "$REPO/web/modules/custom/ut_utilities/" "$TEST/web/modules/custom/ut_utilities/"
cd "$TEST"
lando drush php:script /app/recipes/trend_personal/_build/strip_bucket.php 2>&1 | tail -14

rsync -a --delete "$TEST/recipes/trend_personal/config/" "$REPO/recipes/trend_personal/config/"
for a in trend_recipe trend_place trend_event trend_issue trend_journal trend_quote; do
  mkdir -p "$REPO/recipes/trend_personal/$a/config"
  rsync -a --delete "$TEST/recipes/trend_personal/$a/config/" "$REPO/recipes/trend_personal/$a/config/"
done
cp "$TEST/recipes/trend_personal/_build"/report.* "$REPO/recipes/trend_personal/_build/" 2>/dev/null

echo
echo "=== base install ==="
lando drush sql:drop -y >/dev/null 2>&1
lando drush site:install /app/recipes/trend_personal -y \
  --account-name=admin --account-pass=admin \
  trend_personal.site_name="Trend Test" trend_personal.site_mail="test@example.com" 2>&1 \
  | grep -iE "\[success\]|\[error\]|Error:|line [0-9]+ of" | tail -8
echo "base exit: ${PIPESTATUS[0]}"

for a in trend_place trend_recipe trend_event trend_issue trend_journal trend_quote; do
  echo
  echo "=== apply $a ==="
  lando drush recipe /app/recipes/trend_personal/$a -y 2>&1 \
    | grep -iE "Applied|\[error\]|Error:|not found|does not exist|line [0-9]+ of|Recipe|created" | tail -10
  echo "$a exit: ${PIPESTATUS[0]}"
done

echo
echo "=== final state ==="
lando drush php:script /app/recipes/trend_personal/_build/diag.php 2>&1 | grep -vE "^\s*$" | head -45
echo
echo "=== config:status count ==="
lando drush config:status 2>&1 | grep -c "Only in\|Different"
