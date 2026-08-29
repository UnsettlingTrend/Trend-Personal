#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
cd /home/chris/projects/trend-test
echo "=== ls config/baseline count + sample ==="
ls /home/chris/projects/trend-test/config/baseline/ | wc -l
ls /home/chris/projects/trend-test/config/baseline/ | head -40
echo
echo "=== active config listAll count ==="
lando drush php:eval 'print count(\Drupal::configFactory()->listAll());'
echo
echo "=== field.storage.* active ==="
lando drush php:eval 'print implode("\n", \Drupal::configFactory()->listAll("field.storage"));'
echo
echo "=== node types active ==="
lando drush php:eval 'print implode(",", array_keys(\Drupal::entityTypeManager()->getStorage("node_type")->loadMultiple()));'
echo
echo "=== was there an install error? re-run tail of install log ==="
lando drush watchdog:show --count=40 2>&1 | tail -45
