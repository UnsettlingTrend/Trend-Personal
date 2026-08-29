#!/usr/bin/env bash
set -euo pipefail
export HOME=/home/chris
SRC=/home/chris/projects/com.chrisferagotti.unsettlingtrend
DST=/home/chris/projects/trend-test

mkdir -p "$DST"
rsync -a --delete \
  --exclude='.git/' \
  --exclude='node_modules/' \
  --exclude='web/themes/contrib/material_base/node_modules/' \
  --exclude='web/themes/custom/ut_material/node_modules/' \
  --exclude='*.sql' \
  --exclude='*.sql.gz' \
  --exclude='web/sites/default/files/' \
  --exclude='private/' \
  --exclude='tmp/' \
  --exclude='storage/' \
  --exclude='.idea/' \
  --exclude='web/sites/default/settings.local.php' \
  --exclude='com.chrisferagotti.unsettlingtrend/' \
  "$SRC/" "$DST/"

echo "RSYNC_DONE"
du -sh "$DST"
ls "$DST"
