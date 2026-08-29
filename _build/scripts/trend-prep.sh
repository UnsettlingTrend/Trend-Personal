#!/usr/bin/env bash
set -euo pipefail
export HOME=/home/chris
D=/home/chris/projects/trend-test
cd "$D"

mkdir -p config/sync/test private tmp storage/php web/sites/default/files
touch config/sync/test/.gitkeep

# MySQL 8 in Lando regenerates self-signed certs on rebuild; drush then hits
# "ERROR 2026 TLS/SSL error". Disable cert verification for the throwaway app.
if ! grep -q MYSQL_ATTR_SSL_VERIFY web/sites/default/settings.local.php 2>/dev/null; then
  sed -i "s/  'driver' => 'mysql',/  'driver' => 'mysql',\n  'pdo' => [PDO::MYSQL_ATTR_SSL_CA => NULL, PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => FALSE],/" web/sites/default/settings.local.php || true
fi

# Neutralise chrisferagotti trusted-host lock in settings.php (kept minimal; local
# settings re-adds lndo patterns). Leave the file otherwise intact.
if grep -q "chrisferagotti" web/sites/default/settings.php; then
  sed -i "s/'\^chrisferagotti\\\\.com\$',/'^trendtest\\\\.lndo\\\\.site$',/" web/sites/default/settings.php || true
fi

echo "PREP_DONE"
ls -la config/sync
grep -n "settings.local.php" web/sites/default/settings.php | tail -3
