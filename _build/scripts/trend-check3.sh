#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
cd /home/chris/projects/trend-test
echo "=== config.storage (active) listAll count ==="
lando drush php:eval 'print count(\Drupal::service("config.storage")->listAll());'
echo
echo "=== sync storage listAll count ==="
lando drush php:eval 'print count(\Drupal::service("config.storage.sync")->listAll());'
echo
echo "=== paragraphs.* in active ==="
lando drush php:eval 'print implode("\n", \Drupal::service("config.storage")->listAll("paragraphs"));'
echo
echo "=== count rows in config table directly ==="
lando drush sqlq "SELECT COUNT(*) FROM config;"
echo "=== sample config names from db (field/paragraph/webform) ==="
lando drush sqlq "SELECT name FROM config WHERE name LIKE 'field.storage%' OR name LIKE 'paragraphs.%' OR name LIKE 'webform.webform.%' LIMIT 20;"
echo
echo "=== config:status summary ==="
lando drush config:status 2>&1 | tail -6
