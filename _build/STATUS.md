# trend_personal recipe conversion — status

Branch: `feature/recipe-based-install`. Plan: `~/.claude/plans/glimmering-launching-allen.md`.

## Done & validated

| Phase | What | Evidence |
|---|---|---|
| A | Recipe-as-install mechanism; spikes | `drush site:install recipes/trend_personal` completes; `email` input type + `add_moderation` config action both confirmed in core 11.4.5 |
| B | `ut_base` theme (de-branded `ut_material`), `ut_utilities` (+ composer.json, role config removed), `ut_recipe` (new: FractionFilter + SDC) | all three install; `system.theme:default = ut_base`; `ut_utilities` + `social_auth` enabled |
| C | Base config extraction — 446 bundled config objects + `config.actions` for the meaningful simple-config overrides | base install **green**, front page 200, **0 config validation problems**, no watchdog errors |
| D | 6 add-on recipes (`trend_recipe/place/event/issue/journal/quote`) | **all 6 apply clean** on top of base (runs `bllpwntf3` + `blupcnd5n`) → all 9 node types, 5 vocabs, 11 paragraph types, editorial workflow extended to recipe/event/issue, **0 config validation problems**, no watchdog errors. |
| E | `trend_project` create-project template | Builder: `_build/make_trend_project.sh` (`LOCAL_PATHS=1` vendors the 4 packages into `_local_packages/` + path repos for pre-publish testing; also fixes the lando MySQL-8 TLS issue, auto-creates settings.local.php, adds a `lando si` shortcut). **Validated**: `composer update` from its composer.json resolves and installs the right module set; `drush site:install recipes/trend_personal` from the create-project tree → green, **0 config validation problems**; **all 6 add-ons apply** (trend_place needed `drupal/migrate_plus`+`migrate_tools`, now added). `_build/check_deps.py` cross-checks every recipe `install:` module (+ transitive .info.yml deps) against the template `require` — **passes, 0 missing**. composer.json fixes over the first draft: `+captcha +crop +ctools +key +token +jquery_ui_autocomplete +jquery_ui_menu +migrate_plus +migrate_tools`, `symfony_mailer ^1.5→^2.0`. |

## Toolchain (`recipes/trend_personal/_build/`, not shipped to sites)

- `strip_bucket.php` — reads `config/sync/default` (chris's live config) + `config/baseline` (bare-base defaults), strips uuid/_core/dropped-module-deps/stale-schema-keys, buckets into base vs add-on `config/` dirs, runs a dependency-closure pass. **Regenerates the recipe `config/` dirs each run.**
- `diag.php` — post-install verification sweep (node types, theme, roles, front page, config validation, watchdog).
- `make_trend_project.sh` — builds the template.
- `trend_project.composer.json`, `trend_project.README.md` — template's composer.json + README.
- `report.*` — last strip_bucket run's classification (base/addon/skip/override/dep_issue lists).
- Helper scripts in `~/projects/`: `trend-final.sh` (regen + install + all add-ons + diag, with DB-wait retries), `trend-addons.sh`, `trend-iterate.sh`, `trend-baseline.sh`.

## Regenerating recipe config

The `config/` directories are derived. If empty/stale:

```bash
cd ~/projects/trend-test          # or any installed base
lando drush php:script /app/recipes/trend_personal/_build/strip_bucket.php
# then rsync the generated recipes/trend_personal/{,trend_*/}config/ back to the main repo
```

(A bare-base `config/baseline` export must exist — regenerate with `trend-baseline.sh` if not.)

## Known gaps / follow-ups

1. **Search**: base ships `search_api` + `search_api_db` modules but no index/server/view (`views.view.search_content` was dropped — it depended on chris's Solr index). A site configures search, or a future base update adds a generic db index.
2. **~18 minor simple-config overrides** (`easy_breadcrumb.settings`, `gin.settings`, `core.date_format.*`, `system.date`, etc.) left as module defaults — see `_build/report.override.txt`. Not blocking; add `config.actions` for any that matter.
3. **`ut_base` MDC** loads from `unpkg.com` CDN in `ut_base.libraries.yml` — bundle via webpack for a self-contained theme.
4. **`_build/` in the package**: add `/_build export-ignore` to `.gitattributes` before publishing so it doesn't ship to sites.
5. A handful of non-fatal schema warnings from stale keys in chris's exported views (`workbench_*`, `events_calendar` `color_bundle`) — mostly cleaned in `strip_bucket.php`'s deep-clean; residual ones are cosmetic.

## Demo-site fixes (from testing the throwaway create-project tree)

- **theme build**: `ut_base` is a webpack theme; `dist/` is git-ignored → run `lando build` after create-project. The builder's `build_theme.sh` was fixed (it pointed at the stale `web/themes/custom/ut_material` path) → now builds `web/themes/contrib/{material_base,ut_base}`.
- **admin toolbar missing on ut_base pages**: Gin 5.x ships `gin.settings` with `classic_toolbar: new` (the experimental Navigation-module toolbar); the base doesn't install `navigation`. Fixed — base recipe now has a `gin.settings` config action pinning `classic_toolbar: vertical` (commit `18f4636`).
- **Lando proxy 404** on `<app>.lndo.site`: added an explicit `proxy: appserver:` route to the template `.lando.yml`; fix an existing app with `lando rebuild -y`.
- **MySQL 8 cert drift** (`ERROR 2026 TLS/SSL`) after repeated `lando restart`: `lando rebuild -s database -y`. Do not add SSL `pdo` options — they break the `mysql` CLI.

## Remaining phases

- **F — DONE (2026-09-04), except one manual step.** All 9 packages published to `github.com/UnsettlingTrend/` + `trend_project` template published. `composer update --dry-run` against the published repos resolves clean (trend_personal 2.0.0, ut_base 2.0.0, ut_recipe 1.0.0, ut_utilities 1.0.0). See `_build/phase_f_extract.md` for the full map. Repos:
  - `Trend-Personal` (public, reused) — recipe on branch `2.x` + tag **`2.0.0`**; old profile at tags `1.0.0–1.0.4` + branch `update-profile-2026-08`. **`main` still holds the old profile.**
  - `Base-Theme` (public, reused) — new D11 theme on branch `2.x` + tag **`2.0.0`**; old D10 theme at tags `1.0.0–1.0.13`, plus **`1.0.14`** = the one unreleased commit that was on old `main`. **`main` still holds the old D10 theme.**
  - New: `ut_utilities` (priv), `ut_recipe` (priv), `cove` (pub), `strava_api` (pub), `ut_tracking` (priv), `race_day` (priv), `ut_robinhood` (priv) — each `main` + tag **`1.0.0`**.
  - `trend_project` (priv) — the create-project template, `main`.
  - **MANUAL STEP LEFT (blocked in-session — `git push --force` and token-to-disk are gated):** point `Trend-Personal` and `Base-Theme` `main` at their `2.x` branch. From a normal terminal:
    ```
    git clone https://github.com/UnsettlingTrend/Trend-Personal && cd Trend-Personal
    git push origin origin/2.x:main --force        # old main is preserved at tag 1.0.4
    cd .. && git clone https://github.com/UnsettlingTrend/Base-Theme && cd Base-Theme
    git push origin origin/2.x:main --force        # old main is preserved at tag 1.0.14
    ```
    (Or set the default branch to `2.x` in each repo's GitHub settings and delete `main`.) Composer already resolves via the `2.0.0` tags, so this is repo hygiene, not a functional blocker.
  - **create-project needs a GitHub token** (private base deps `ut_utilities`, `ut_recipe`): `composer config --global --auth github-oauth.github.com <token>` before `composer create-project unsettlingtrend/trend_project`.
- **G** — migrate live chrisferagotti.com (stays on `standard` for now). Separate effort.

## Local env note

Docker Desktop went unstable partway through this session — the `trendtest` containers (db/pma/mailhog/node) repeatedly exited (255) and had to be brought back with `lando restart`. If validation runs fail with "Can't connect to server on 'database'", restart Docker Desktop / `lando restart`, not the recipe.
