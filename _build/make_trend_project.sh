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

# --- the custom code the recipes need travels with the template ----------
mkdir -p "$DEST/web/modules/custom" "$DEST/web/themes/custom"
# (During Phase F these become Composer deps and these copies are removed.)
rsync -a "$SRC/web/modules/custom/ut_utilities/" "$DEST/web/modules/custom/ut_utilities/"
rsync -a "$SRC/web/modules/custom/ut_recipe/"    "$DEST/web/modules/custom/ut_recipe/"
rsync -a "$SRC/web/themes/custom/ut_base/"       "$DEST/web/themes/custom/ut_base/"

# --- the recipe package --------------------------------------------------
mkdir -p "$DEST/recipes/trend_personal"
rsync -a --exclude='_build/' "$SRC/recipes/trend_personal/" "$DEST/recipes/trend_personal/"
printf '/contrib\n' > "$DEST/recipes/.gitignore"

# --- composer.json + README --------------------------------------------
cp "$BUILD/trend_project.composer.json" "$DEST/composer.json"
cp "$BUILD/trend_project.README.md"     "$DEST/README.md"
rm -f "$DEST/composer.lock"

# --- empty config sync tree -------------------------------------------
mkdir -p "$DEST"/config/sync/{default,dev,local,non_production,prod}
touch "$DEST"/config/sync/default/.gitkeep

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

# --- build_theme.sh : retarget ut_material -> ut_base ------------------
sed -i 's#web/themes/custom/ut_material#web/themes/custom/ut_base#g; s#themes/custom/ut_material#themes/custom/ut_base#g' "$DEST/lando/build_theme.sh" || true

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
