# trend_personal recipe conversion — status

Branch: `feature/recipe-based-install`. Plan: `~/.claude/plans/glimmering-launching-allen.md`.

## Done & validated

| Phase | What | Evidence |
|---|---|---|
| A | Recipe-as-install mechanism; spikes | `drush site:install recipes/trend_personal` completes; `email` input type + `add_moderation` config action both confirmed in core 11.4.5 |
| B | `ut_base` theme (de-branded `ut_material`), `ut_utilities` (+ composer.json, role config removed), `ut_recipe` (new: FractionFilter + SDC) | all three install; `system.theme:default = ut_base`; `ut_utilities` + `social_auth` enabled |
| C | Base config extraction — 446 bundled config objects + `config.actions` for the meaningful simple-config overrides | base install **green**, front page 200, **0 config validation problems**, no watchdog errors |
| D | 6 add-on recipes (`trend_recipe/place/event/issue/journal/quote`) | **all 6 apply clean** on top of base (runs `bllpwntf3` + `blupcnd5n`) → all 9 node types, 5 vocabs, 11 paragraph types, editorial workflow extended to recipe/event/issue, **0 config validation problems**, no watchdog errors. |
| E | `trend_project` create-project template | `_build/make_trend_project.sh` builds it; verified de-personalised (no hash_salt / chrisferagotti / robinhood / strava / swiftmailer / python; `name: trend`; custom code = ut_base + ut_utilities + ut_recipe only; project-id stripped) |

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

## Remaining phases

- **F** — split `trend_personal`, `ut_base`, `ut_utilities`, `ut_recipe` into their own `gitlab.com/unsettlingtrend/` repos (`git subtree split`), tag (`2.0.0` / `1.0.0`), publish; swap the template's path repos → vcs; run `composer create-project` end-to-end.
- **G** — migrate live chrisferagotti.com (stays on `standard` for now; recipes are additive so it can converge, or be rebuilt from the template + content migration). Separate effort.

## Local env note

Docker Desktop went unstable partway through this session — the `trendtest` containers (db/pma/mailhog/node) repeatedly exited (255) and had to be brought back with `lando restart`. If validation runs fail with "Can't connect to server on 'database'", restart Docker Desktop / `lando restart`, not the recipe.
