#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
REPO=/home/chris/projects/com.chrisferagotti.unsettlingtrend
TEST=/home/chris/projects/trend-test

rm -rf "$REPO"/recipes/trend_personal/config "$REPO"/recipes/trend_personal/trend_*/config
rsync -a --delete "$REPO/recipes/trend_personal/" "$TEST/recipes/trend_personal/"
rsync -a --delete "$REPO/web/themes/custom/ut_base/" "$TEST/web/themes/custom/ut_base/"
rsync -a --delete "$REPO/web/modules/custom/ut_recipe/" "$TEST/web/modules/custom/ut_recipe/"
rsync -a --delete "$REPO/web/modules/custom/ut_utilities/" "$TEST/web/modules/custom/ut_utilities/"
cd "$TEST"
lando drush php:script /app/recipes/trend_personal/_build/strip_bucket.php 2>&1 | tail -16

rsync -a --delete "$TEST/recipes/trend_personal/config/" "$REPO/recipes/trend_personal/config/"
for a in trend_recipe trend_place trend_event trend_issue trend_journal trend_quote; do
  mkdir -p "$REPO/recipes/trend_personal/$a/config"
  rsync -a --delete "$TEST/recipes/trend_personal/$a/config/" "$REPO/recipes/trend_personal/$a/config/"
done
cp "$TEST/recipes/trend_personal/_build"/report.* "$REPO/recipes/trend_personal/_build/" 2>/dev/null

echo
echo "=== site:install (base) ==="
lando drush sql:drop -y >/dev/null 2>&1
lando drush site:install /app/recipes/trend_personal -y \
  --account-name=admin --account-pass=admin \
  trend_personal.site_name="Trend Test" trend_personal.site_mail="test@example.com" 2>&1 \
  | grep -vE "Performed install task|Do you want to continue|DROP all tables|^\s*$" | tail -45
echo "install exit: ${PIPESTATUS[0]}"

echo
echo "config rows: $(lando drush sqlq 'SELECT COUNT(*) FROM config;' 2>/dev/null)"
lando drush php:script /app/recipes/trend_personal/_build/diag.php 2>&1 | tail -50
