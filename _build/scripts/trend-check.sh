#!/usr/bin/env bash
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
cd /home/chris/projects/trend-test
echo "=== enabled module count ==="
lando drush pm:list --type=module --status=enabled --format=list 2>&1 | grep -vE "^$|cannot set" | wc -l
echo "=== enabled modules ==="
lando drush pm:list --type=module --status=enabled --format=list 2>&1 | grep -vE "^$|cannot set" | sort | tr '\n' ' '
echo
echo "=== NOT enabled from recipe install list ==="
lando drush pm:list --type=module --format=list --status=disabled 2>&1 | grep -vE "^$" | sort | tr '\n' ' '
echo
echo "=== active config count ==="
lando drush config:status 2>&1 | grep -c .
lando drush php:eval 'print count(\Drupal::configFactory()->listAll());' 2>&1 | tail -1
