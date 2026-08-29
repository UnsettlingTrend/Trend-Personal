#!/usr/bin/env bash
set -uo pipefail
export HOME=/home/chris
export PATH="/home/chris/.lando/bin:$PATH"
cd /home/chris/projects/trend-test

echo "=== installed profile / theme ==="
lando drush cget core.extension profile 2>&1 | tail -3
lando drush cget system.theme default 2>&1 | tail -3
lando drush cget system.theme admin 2>&1 | tail -3
echo
echo "=== themes ==="
lando drush pm:list --type=theme --status=enabled --format=list 2>&1 | tail -10
echo
echo "=== key modules enabled? ==="
lando drush pm:list --type=module --status=enabled --format=list 2>&1 | grep -E "^(ut_base|paragraphs|layout_paragraphs|content_moderation|pathauto|admin_toolbar|gin_toolbar|node|views)$" | sort
echo
echo "=== config:status ==="
lando drush config:status 2>&1 | tail -20
echo
echo "=== front page HTTP ==="
lando drush php:eval "print \Drupal::httpClient()->get('http://localhost/')->getStatusCode();" 2>&1 | tail -5
echo
echo "=== recent watchdog errors ==="
lando drush watchdog:show --count=25 --severity=Error 2>&1 | tail -30
