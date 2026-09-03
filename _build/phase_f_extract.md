# Phase F — split the packages into their own repos & publish

Do this once the in-repo build is validated end to end. Everything is currently
developed in-tree under `feature/recipe-based-install`. Git host is
**github.com, org `UnsettlingTrend`** (same org as this repo,
`github.com/UnsettlingTrend/ChrisFeragotti.com`). Composer vendor stays
lowercase `unsettlingtrend/` regardless of the GitHub org casing.

### Base packages (the create-project template requires these)

| package | in-tree path | target repo | first tag |
|---|---|---|---|
| `unsettlingtrend/trend_personal` (drupal-recipe) | `recipes/trend_personal/` | `github.com/UnsettlingTrend/trend_personal` | `2.0.0` |
| `unsettlingtrend/ut_base` (drupal-theme) | `web/themes/custom/ut_base/` | `github.com/UnsettlingTrend/ut_base` | `1.0.0` |
| `unsettlingtrend/ut_utilities` (drupal-module) | `web/modules/custom/ut_utilities/` | `github.com/UnsettlingTrend/ut_utilities` | `1.0.0` |
| `unsettlingtrend/ut_recipe` (drupal-module) | `web/modules/custom/ut_recipe/` | `github.com/UnsettlingTrend/ut_recipe` | `1.0.0` |

`trend_personal` is `2.0.0` (not `1.x`) because the existing
`unsettlingtrend/trend_personal` package is a `drupal-profile` at `^1.0.2` —
changing `type` to `drupal-recipe` is a breaking change.

### Optional add-on modules (chrisferagotti.com-specific; a fork `composer require`s them individually)

| package | in-tree path | target repo | first tag |
|---|---|---|---|
| `unsettlingtrend/cove` | `web/modules/custom/cove/` | `github.com/UnsettlingTrend/cove` | `1.0.0` |
| `unsettlingtrend/strava_api` | `web/modules/custom/strava_api/` | `github.com/UnsettlingTrend/strava_api` | `1.0.0` |
| `unsettlingtrend/ut_tracking` | `web/modules/custom/ut_tracking/` | `github.com/UnsettlingTrend/ut_tracking` | `1.0.0` |
| `unsettlingtrend/race_day` | `web/modules/custom/race_day/` | `github.com/UnsettlingTrend/race_day` | `1.0.0` |
| `unsettlingtrend/ut_robinhood` | `web/modules/custom/ut_robinhood/` | `github.com/UnsettlingTrend/ut_robinhood` | `1.0.0` |

`race_day` requires `unsettlingtrend/strava_api` + `unsettlingtrend/ut_tracking`;
`ut_tracking` requires `unsettlingtrend/ut_utilities`. `ut_tracking` no longer
requires `race_day` (cycle broken — the race-team glue is in
`ut_tracking/config/optional/`).

## 1. Prep each package for extraction

- **`recipes/trend_personal/`**: `.gitattributes` (`/_build export-ignore`) and
  `composer.json` are already in place.
- **`ut_base/`**: confirm `.gitignore` ignores `dist/` and `node_modules/`.
- **all custom modules**: `composer.json` already written (commit `151d23f`).

## 2. subtree split (run from the repo root)

```bash
bash recipes/trend_personal/_build/phase_f_split.sh
```

Creates `split/<name>` branches for all 9 packages, full history preserved.

## 3. Create repos and push

```bash
for name in trend_personal ut_base ut_utilities ut_recipe \
            cove strava_api ut_tracking race_day ut_robinhood; do
  gh repo create "UnsettlingTrend/$name" --private
  git push "git@github.com:UnsettlingTrend/$name.git" "split/$name:main"
done
```

Then in a fresh clone of each, tag:

```bash
# trend_personal
git tag 2.0.0 && git push --tags
# every other package
git tag 1.0.0 && git push --tags
```

## 4. Point the template at the published packages

`recipes/trend_personal/_build/trend_project.composer.json` already has all 9
`vcs` entries pointing at `github.com/UnsettlingTrend/*`. Once the repos exist and
are tagged:

- rebuild `trend_project` **without** `LOCAL_PATHS` (drop the `_local_packages/`
  path repos)
- set the base `unsettlingtrend/*` constraints to `^2.0` (trend_personal) / `^1.0`
- for **private** repos, Composer needs a GitHub token:
  `composer config --global --auth github-oauth.github.com <token>`

## 5. End-to-end test

```bash
cd ~/projects
composer create-project unsettlingtrend/trend_project ttest
cd ttest && lando start && lando composer install && lando build
lando drush site:install recipes/trend_personal -y \
  --account-name=admin --account-pass=admin \
  trend_personal.site_name="TT" trend_personal.site_mail="t@example.com"
# opt into an add-on module:
lando composer require unsettlingtrend/race_day
lando drush en race_day -y
```

Expect the same green install as the in-repo `trend-test`, now from a
`composer create-project` skeleton with packages pulled by Composer.

## 6. Publish

- Register each repo on Packagist (or a private Satis) so
  `composer create-project unsettlingtrend/trend_project` works without the
  `repositories` overrides. With the `vcs` entries in `trend_project`'s
  `composer.json`, Packagist registration is optional for the create-project
  flow to resolve.
- Publish `unsettlingtrend/trend_project` itself to
  `github.com/UnsettlingTrend/trend_project`.
