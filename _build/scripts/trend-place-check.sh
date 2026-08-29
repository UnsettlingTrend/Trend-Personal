#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
REPO=/home/chris/projects/com.chrisferagotti.unsettlingtrend
TEST=/home/chris/projects/trend-test
cd "$TEST"

rm -rf "$REPO"/recipes/trend_personal/config "$REPO"/recipes/trend_personal/trend_*/config
rsync -a --delete --exclude='*/config/' "$REPO/recipes/trend_personal/" "$TEST/recipes/trend_personal/"
lando drush php:script /app/recipes/trend_personal/_build/strip_bucket.php 2>&1 | tail -3
rsync -a --delete "$TEST/recipes/trend_personal/config/" "$REPO/recipes/trend_personal/config/"
for a in trend_recipe trend_place trend_event trend_issue trend_journal trend_quote; do
  mkdir -p "$REPO/recipes/trend_personal/$a/config"
  rsync -a --delete "$TEST/recipes/trend_personal/$a/config/" "$REPO/recipes/trend_personal/$a/config/"
done
cp "$TEST/recipes/trend_personal/_build"/report.* "$REPO/recipes/trend_personal/_build/" 2>/dev/null

echo "geocoder config in trend_place: $(ls recipes/trend_personal/trend_place/config/ | grep -c geocoder.geocoder_provider)"

lando drush sql:drop -y >/dev/null 2>&1
lando drush site:install /app/recipes/trend_personal -y --account-name=admin --account-pass=admin \
  trend_personal.site_name="TT" trend_personal.site_mail="t@example.com" 2>&1 | grep -iE "\[success\]|\[error\]" | tail -3
echo
echo "=== apply trend_place ==="
lando drush recipe /app/recipes/trend_personal/trend_place -y 2>&1 | grep -iE "applied successfully|\[error\]|does not exist|Error:" | tail -6
echo "trend_place exit: ${PIPESTATUS[0]}"
lando drush php:eval 'print "place type: ".(\Drupal::entityTypeManager()->getStorage("node_type")->load("place") ? "yes" : "no");' 2>&1 | tail -1
lando drush cget geocoder.geocoder_provider.googlemaps configuration.apiKey 2>&1 | tail -1
echo DONE
