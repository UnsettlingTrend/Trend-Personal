#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
REPO=/home/chris/projects/com.chrisferagotti.unsettlingtrend
TEST=/home/chris/projects/trend-test

# wipe any previously-generated recipe config, keep recipe.yml + _build
rm -rf "$REPO"/recipes/trend_personal/config "$REPO"/recipes/trend_personal/trend_*/config
rsync -a --delete "$REPO/recipes/trend_personal/" "$TEST/recipes/trend_personal/"

cd "$TEST"
lando drush php:script /app/recipes/trend_personal/_build/strip_bucket.php 2>&1 | tail -40
echo
echo "=== generated file counts ==="
for d in config trend_recipe/config trend_place/config trend_event/config trend_issue/config trend_journal/config trend_quote/config; do
  n=$(ls "$TEST/recipes/trend_personal/$d"/*.yml 2>/dev/null | wc -l)
  echo "  $d : $n"
done
echo
echo "=== overrides (in baseline but differ) ==="
cat "$TEST/recipes/trend_personal/_build/report.overrides.txt"
echo
echo "=== missing_dep ==="
cat "$TEST/recipes/trend_personal/_build/report.missing_dep.txt"

# copy generated config back to the main repo
rsync -a "$TEST/recipes/trend_personal/config/"          "$REPO/recipes/trend_personal/config/" 2>/dev/null
for a in trend_recipe trend_place trend_event trend_issue trend_journal trend_quote; do
  rsync -a "$TEST/recipes/trend_personal/$a/config/" "$REPO/recipes/trend_personal/$a/config/" 2>/dev/null
done
cp "$TEST/recipes/trend_personal/_build"/report.* "$REPO/recipes/trend_personal/_build/" 2>/dev/null
echo "synced back to main repo"
