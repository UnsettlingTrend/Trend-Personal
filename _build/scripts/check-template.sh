#!/usr/bin/env bash
cd /home/chris/projects/trend_project
echo "=== .lando.yml chrisferagotti leftovers ==="
grep -nE 'python|robin|pull-prod|sync-with-prod|build_as_root|gulp|serverName=cf|cf\.lndo' .lando.yml || echo "  none"
echo
echo "=== .lando.yml tooling keys ==="
grep -E '^  [a-z]' .lando.yml
echo
echo "=== settings.platformsh.php leftovers ==="
grep -nE 'robinhood|strava|swiftmailer|SXGNp9' web/sites/default/settings.platformsh.php || echo "  none"
echo
echo "=== settings.php ==="
grep -nE 'hash_salt|chrisferagotti|trusted_host' web/sites/default/settings.php
echo
echo "=== .platform.app.yaml ==="
grep -nE '^name:|python|robin|ut_material|Compiling' .platform.app.yaml
echo
echo "=== files present ==="
ls
echo "recipes/trend_personal: $(ls recipes/trend_personal | tr '\n' ' ')"
echo "web/modules/custom: $(ls web/modules/custom | tr '\n' ' ')"
echo "web/themes/custom: $(ls web/themes/custom | tr '\n' ' ')"
echo "config/sync: $(ls config/sync | tr '\n' ' ')"
