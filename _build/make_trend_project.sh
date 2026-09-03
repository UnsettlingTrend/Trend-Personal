#!/usr/bin/env bash
#
# Phase E: build the `unsettlingtrend/trend_project` create-project template
# from this repo. Produces a clean tree at $DEST ready to `git init`.
#
#   bash recipes/trend_personal/_build/make_trend_project.sh [DEST]
#
set -euo pipefail
SRC="$(cd "$(dirname "$0")/../../.." && pwd)"          # repo root
DEST="${1:-$SRC/../trend_project}"
BUILD="$SRC/recipes/trend_personal/_build"

rm -rf "$DEST"
mkdir -p "$DEST"

# --- copy the parts a fresh project needs, nothing else -------------------
rsync -a \
  --exclude='.git/' --exclude='vendor/' --exclude='node_modules/' \
  --exclude='web/core/' --exclude='web/modules/contrib/' --exclude='web/modules/custom/' \
  --exclude='web/themes/contrib/' --exclude='web/themes/custom/' --exclude='web/profiles/' \
  --exclude='web/libraries/' --exclude='drush/contrib/' \
  --exclude='web/sites/default/files/' --exclude='web/sites/default/settings.local.php' \
  --exclude='web/sites/*/files/' --exclude='private/' --exclude='tmp/' \
  --exclude='storage/' --exclude='.idea/' --exclude='.claude/' --exclude='*.sql' --exclude='*.sql.gz' \
  --exclude='recipes/' --exclude='config/sync/' --exclude='config/scripts/' \
  --exclude='check_group_outsider.php' --exclude='com.chrisferagotti.unsettlingtrend/' \
  --exclude='misc/' --exclude='.gitlab-ci.yml' \
  "$SRC/" "$DEST/"

# The template ships NO custom code — ut_base / ut_utilities / ut_recipe /
# trend_personal all come from Composer (vcs repos, or _local_packages/ path
# repos in LOCAL_PATHS mode), installed into web/{modules,themes}/contrib and
# recipes/ where they are git-ignored like any other Composer-managed code.
rm -rf "$DEST/web/modules/custom" "$DEST/web/themes/custom" "$DEST/recipes/trend_personal"
mkdir -p "$DEST/recipes"
printf '/contrib\n/trend_personal\n' > "$DEST/recipes/.gitignore"

# --- composer.json + README --------------------------------------------
cp "$BUILD/trend_project.composer.json" "$DEST/composer.json"
cp "$BUILD/trend_project.README.md"     "$DEST/README.md"
rm -f "$DEST/composer.lock"

# LOCAL_PATHS=1 : vendor the four unsettlingtrend packages into ./_local_packages/
# and point path repos there, so `composer install` works before anything is
# published. Self-contained: survives a git clone of the template.
if [ "${LOCAL_PATHS:-0}" = "1" ]; then
  mkdir -p "$DEST/_local_packages"
  rsync -a --exclude='_build/' "$SRC/recipes/trend_personal/"      "$DEST/_local_packages/trend_personal/"
  rsync -a "$SRC/web/themes/custom/ut_base/"                       "$DEST/_local_packages/ut_base/"
  rsync -a "$SRC/web/modules/custom/ut_utilities/"                 "$DEST/_local_packages/ut_utilities/"
  rsync -a "$SRC/web/modules/custom/ut_recipe/"                    "$DEST/_local_packages/ut_recipe/"
  python3 - "$DEST/composer.json" <<'PY'
import sys, json
p = sys.argv[1]
d = json.load(open(p))
d['repositories'] = [r for r in d['repositories']
                     if not (r.get('type') == 'vcs' and 'unsettlingtrend' in r.get('url', ''))]
for name in ('trend_personal', 'ut_base', 'ut_utilities', 'ut_recipe'):
    d['repositories'].append({'type': 'path', 'url': f'_local_packages/{name}',
                              'options': {'symlink': False}})
for pkg in ('unsettlingtrend/trend_personal', 'unsettlingtrend/ut_base',
            'unsettlingtrend/ut_utilities', 'unsettlingtrend/ut_recipe'):
    d['require'][pkg] = '@dev'
json.dump(d, open(p, 'w'), indent=4)
PY
  echo "composer.json patched for LOCAL_PATHS; packages vendored to _local_packages/"
fi

# --- empty config sync tree -------------------------------------------
mkdir -p "$DEST"/config/sync/{default,dev,local,non_production,prod}
touch "$DEST"/config/sync/default/.gitkeep

# --- lando/settings.lando.php : correct DB creds for the drupal11 Lando recipe
sed -i "s/'\(database\|username\|password\)' => 'drupal10',/'\1' => 'drupal11',/" "$DEST/lando/settings.lando.php"

# --- .lando.yml : de-personalise ------------------------------------
python3 - "$DEST/.lando.yml" <<'PY'
import sys, re
p = sys.argv[1]
lines = open(p).read().splitlines()
DROP_KEYS = {'pull-prod', 'sync-with-prod', 'pip', 'gulp'}
out, skip = [], False
for ln in lines:
    m = re.match(r'^  ([\w-]+):\s*$', ln)
    if m:
        skip = m.group(1) in DROP_KEYS
        if skip:
            continue
    if skip:
        if ln.startswith('    ') or ln.strip() == '':
            continue
        skip = False
    out.append(ln)
s = '\n'.join(out) + '\n'
s = s.replace('name: cf', 'name: trend')
s = re.sub(r'\n *build_as_root:\n(?: {6}.*\n)+', '\n', s)   # python / pip / platform CLI
s = re.sub(r'\n *gulp-cli: latest\n', '\n', s)
s = s.replace('cf.lndo.site', 'trend.lndo.site').replace('serverName=cf', 'serverName=trend')
# register an explicit appserver proxy route (some Lando/Traefik states miss the
# implicit <appname>.lndo.site route and 404)
if re.search(r'^proxy:\s*$', s, re.M) and 'appserver:\n    - trend.lndo.site' not in s:
    s = re.sub(r'^proxy:\s*\n', 'proxy:\n  appserver:\n    - trend.lndo.site\n', s, count=1, flags=re.M)
# auto-create settings.local.php on first start; add a `lando si` shortcut
if 'settings.local.php' not in s:
    s = s.replace(
        'events:\n',
        "events:\n"
        "  pre-start:\n"
        "    - appserver: test -f web/sites/default/settings.local.php || cp lando/settings.lando.php web/sites/default/settings.local.php\n",
        1)
if '\n  si:\n' not in s:
    s = s.rstrip() + (
        "\n  si:\n"
        "    service: appserver\n"
        "    description: Install the site from the trend_personal recipe.\n"
        "    cmd: drush site:install /app/recipes/trend_personal -y --account-name=admin --account-pass=admin\n")
s = re.sub(r'\n{3,}', '\n\n', s).rstrip() + '\n'
open(p, 'w').write(s)
PY

# --- settings.php : drop the committed hash_salt, generic trusted hosts --
python3 - "$DEST/web/sites/default/settings.php" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"^\$settings\['hash_salt'\][^\n]*\n", "", s, flags=re.M)
# the real (uncommented) trusted_host_patterns block, chrisferagotti-specific
s = re.sub(r"^\$settings\['trusted_host_patterns'\] = \[\n(?:  '[^\n]*\n)+\];",
           "$settings['trusted_host_patterns'] = [\n  // '^example\\\\.com$',\n  // '^www\\\\.example\\\\.com$',\n  '^.+\\\\.platformsh\\\\.site$',\n];",
           s, flags=re.M)
open(p, 'w').write(s)
PY

# --- settings.platformsh.php : drop 2nd hash_salt + swiftmailer + robinhood/strava
python3 - "$DEST/web/sites/default/settings.platformsh.php" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\$settings\['hash_salt'\] = '[^']+';\n", "", s)                       # 2nd hard-coded salt
s = re.sub(r"//\$config\['smtp\.settings'\].*\n", "", s)
s = re.sub(r"\$config\['swiftmailer\.transport'\] = \[.*?\];\n", "", s, flags=re.S) # stale swiftmailer block
for pat in (r".*CREDS_ROBINHOOD.*\n", r".*CREDS_STRAVA.*\n",
            r".*ut_robinhood_python_bin.*\n", r".*ut_robinhood_pickle_dir.*\n",
            r"// Authentication for Robinhood\n", r"// UT Robinhood module credentials\.\n",
            r"// Authentication for Strava\n", r"// Strava API module credentials\.\n"):
    s = re.sub(pat, "", s)
s = re.sub(r"\n{3,}", "\n\n", s)
open(p, 'w').write(s)
PY

# --- regenerate the mangled my.cnf --------------------------------------
cat > "$DEST/lando/config/my.cnf" <<'CNF'
[mysqld]
sql_mode = "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
innodb_buffer_pool_size = 512M
max_allowed_packet = 64M
CNF

# --- build_theme.sh : build the Composer-installed themes ------------
cat > "$DEST/lando/build_theme.sh" <<'SH'
#!/usr/bin/env bash
set -e
# Base theme first, then the ut_base subtheme (both Composer-installed).
for dir in web/themes/contrib/material_base web/themes/contrib/ut_base; do
  echo "== building $dir =="
  ( cd "/app/$dir"
    if [ -f package-lock.json ]; then npm ci --no-audit --no-fund; else npm install --no-audit --no-fund; fi
    npm run build --if-present
  )
done
SH

# --- drop prod-sync scripts -------------------------------------------
rm -f "$DEST"/lando/pull_prod.sh "$DEST"/lando/sync_with_prod*.sh "$DEST"/lando/sync_media.sh

# --- .platform.app.yaml: strip project id, python, ut_material -------
rm -f "$DEST/.platform/local/project.yaml"
python3 - "$DEST/.platform.app.yaml" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
s = s.replace('name: cf', 'name: trend').replace('"cf:http"', '"trend:http"')
s = re.sub(r"\n  python3:\n    pip: '\*'\n", "\n", s)
s = re.sub(r"\n *# Install the robin_stocks.*\n *pip install robin_stocks pyotp\n", "\n", s)
s = s.replace('web/themes/custom/ut_material', 'web/themes/custom/ut_base')
s = s.replace('Compiling ut_material', 'Compiling ut_base')
open(p, 'w').write(s)
PY
sed -i 's/"cf:http"/"trend:http"/; s/upstream: "cf/upstream: "trend/' "$DEST/.platform/routes.yaml" || true

# --- .gitignore : no profile line, ignore /recipes/contrib ------------
sed -i '\#/web/profiles/contrib/#d' "$DEST/.gitignore" || true

echo "trend_project built at: $DEST"
echo "review, then: cd $DEST && git init && lando start && lando composer install"
